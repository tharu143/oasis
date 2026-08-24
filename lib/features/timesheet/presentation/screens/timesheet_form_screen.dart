import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:oasis/core/api/api_client.dart';
import 'package:oasis/core/constants/app_colors.dart';
import '../../models/timesheet_model.dart';
import 'timesheet_detail_screen.dart';

class TimesheetFormScreen extends StatefulWidget {
  final TimesheetModel? timesheet;
  const TimesheetFormScreen({super.key, this.timesheet});

  @override
  State<TimesheetFormScreen> createState() => _TimesheetFormScreenState();
}

class _TimesheetFormScreenState extends State<TimesheetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  bool _isSaving = false;

  // Header Controllers & Values
  final String _namingSeries = 'TS-.YYYY.-';
  String _company = '';
  String _employee = '';
  String _employeeName = '';
  String _parentProject = '';
  String _parentProjectName = '';
  late TextEditingController _noteController;

  // Role permissions: whether user is manager or standard employee
  bool _isManager = false;

  // Child Table (time_logs)
  List<TimeLogModel> _timeLogs = [];

  // Dropdown cached lists
  List<Map<String, dynamic>> _employeeList = [];
  List<String> _activityTypes = [];
  List<Map<String, dynamic>> _projectsList = [];
  final Map<String, List<Map<String, dynamic>>> _tasksByProject = {};

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.timesheet?.note ?? '');
    _initData();
    _fetchDropdownOptions();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _initData() {
    if (widget.timesheet != null) {
      final ts = widget.timesheet!;
      _company = ts.company;
      _employee = ts.employee;
      _employeeName = ts.employeeName ?? ts.employee;
      _parentProject = ts.parentProject ?? '';
      _parentProjectName = ts.parentProject ?? '';
      _timeLogs = ts.timeLogs.map((tl) => TimeLogModel.fromJson(tl.toJson())).toList();
    } else {
      // Start with 1 empty time log row
      _addEmptyTimeLogRow();
    }
  }

  void _addEmptyTimeLogRow() {
    final now = DateTime.now();
    final fromTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final toTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now.add(const Duration(hours: 4)));

    _timeLogs.add(
      TimeLogModel(
        activityType: _activityTypes.isNotEmpty ? _activityTypes.first : 'Execution',
        fromTime: fromTimeStr,
        toTime: toTimeStr,
        expectedHours: 4.0,
        hours: 4.0,
        completed: 1,
        project: _parentProject,
        projectName: _parentProjectName,
        task: '',
        isBillable: 1,
        description: '',
      ),
    );
  }

  Future<void> _fetchDropdownOptions() async {
    setState(() => _isLoading = true);
    try {
      // 1. Employees & Role check
      try {
        final empRes = await _apiClient.get('oasis_mobile.api.timesheet.get_employee_list');
        final dynamic empMsg = empRes['message'] ?? empRes['data'] ?? empRes;

        if (empRes['is_manager'] != null) {
          _isManager = empRes['is_manager'] == true;
        } else if (empMsg is Map && empMsg['is_manager'] != null) {
          _isManager = empMsg['is_manager'] == true;
        }

        dynamic listData;
        if (empMsg is Map && empMsg['data'] is List) {
          listData = empMsg['data'];
        } else if (empMsg is List) {
          listData = empMsg;
        } else if (empRes['data'] is List) {
          listData = empRes['data'];
        }

        if (listData is List) {
          _employeeList = listData.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        // If not editing, auto-select current employee context
        if (widget.timesheet == null && _employeeList.isNotEmpty) {
          final first = _employeeList.first;
          _employee = first['name'] ?? '';
          _employeeName = first['employee_name'] ?? _employee;
          _company = first['company'] ?? 'Oasis Trading and Importing HVAC';
        }
      } catch (e) {
        debugPrint('Employees fetch error: $e');
      }

      // 2. Activity Types
      try {
        final actRes = await _apiClient.get('oasis_mobile.api.timesheet.get_activity_types');
        final dynamic actMsg = actRes['message'] ?? actRes['data'] ?? actRes;
        dynamic actList;
        if (actMsg is Map && actMsg['data'] is List) {
          actList = actMsg['data'];
        } else if (actMsg is List) {
          actList = actMsg;
        } else if (actRes['data'] is List) {
          actList = actRes['data'];
        }

        if (actList is List) {
          _activityTypes = actList.map((e) {
            if (e is Map) {
              return (e['activity_type'] ?? e['name'] ?? '').toString();
            }
            return e.toString();
          }).where((s) => s.isNotEmpty).toList();
        }
      } catch (e) {
        debugPrint('Activity types fetch error: $e');
      }

      // Fallback activities if empty
      if (_activityTypes.isEmpty) {
        _activityTypes = ['Execution', 'Planning', 'Design', 'Meeting', 'Site Visit', 'Documentation'];
      }

      // 3. Projects
      try {
        final projRes = await _apiClient.get('oasis_mobile.api.timesheet.get_projects_list');
        final dynamic projMsg = projRes['message'] ?? projRes['data'] ?? projRes;
        dynamic projList;
        if (projMsg is Map && projMsg['data'] is List) {
          projList = projMsg['data'];
        } else if (projMsg is List) {
          projList = projMsg;
        } else if (projRes['data'] is List) {
          projList = projRes['data'];
        }

        if (projList is List) {
          _projectsList = projList.map((p) => Map<String, dynamic>.from(p)).toList();
        }
      } catch (e) {
        debugPrint('Projects fetch error: $e');
      }

      // If time logs were added before activity types loaded, update default activity type
      for (var row in _timeLogs) {
        if (row.activityType.isEmpty && _activityTypes.isNotEmpty) {
          row.activityType = _activityTypes.first;
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTasksForProject(String project) async {
    if (project.isEmpty) return [];
    if (_tasksByProject.containsKey(project)) return _tasksByProject[project]!;

    try {
      final res = await _apiClient.get(
        'oasis_mobile.api.timesheet.get_tasks_list',
        params: {'project': project},
      );
      final dynamic taskMsg = res['message'] ?? res['data'] ?? res;
      dynamic taskList;
      if (taskMsg is Map && taskMsg['data'] is List) {
        taskList = taskMsg['data'];
      } else if (taskMsg is List) {
        taskList = taskMsg;
      } else if (res['data'] is List) {
        taskList = res['data'];
      }

      if (taskList is List) {
        final tasks = taskList.map((t) => Map<String, dynamic>.from(t)).toList();
        _tasksByProject[project] = tasks;
        return tasks;
      }
    } catch (e) {
      debugPrint('Error fetching tasks for $project: $e');
    }
    return [];
  }

  double get _totalHours => _timeLogs.fold(0.0, (sum, item) => sum + item.hours);
  double get _totalBillableHours =>
      _timeLogs.where((i) => i.isBillable == 1).fold(0.0, (sum, item) => sum + item.hours);

  Future<void> _pickDateTime(BuildContext ctx, {required bool isFrom, required TimeLogModel row}) async {
    final initialDate = DateTime.tryParse(isFrom ? row.fromTime : row.toTime) ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: ctx,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (dateCtx, child) {
        return Theme(
          data: Theme.of(dateCtx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0284C7)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    if (!ctx.mounted) return;
    final pickedTime = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (timeCtx, child) {
        return Theme(
          data: Theme.of(timeCtx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0284C7)),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    final resultDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
      0,
    );

    final formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(resultDateTime);

    setState(() {
      if (isFrom) {
        row.fromTime = formatted;
      } else {
        row.toTime = formatted;
      }

      // Auto-calculate hours if both from and to are set
      if (row.fromTime.isNotEmpty && row.toTime.isNotEmpty) {
        final f = DateTime.tryParse(row.fromTime);
        final t = DateTime.tryParse(row.toTime);
        if (f != null && t != null && t.isAfter(f)) {
          final diff = t.difference(f).inMinutes / 60.0;
          row.hours = double.parse(diff.toStringAsFixed(2));
          row.expectedHours = row.hours;
        }
      }
    });
  }

  // ── Searchable Picker Modal Bottom Sheet ─────────────────────────────────
  void _showSearchablePicker({
    required String title,
    required List<Map<String, dynamic>> items,
    required String valueKey,
    required String labelKey,
    String? subtitleKey,
    required ValueChanged<Map<String, dynamic>> onSelected,
    bool allowNone = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchablePickerSheet(
        title: title,
        items: items,
        valueKey: valueKey,
        labelKey: labelKey,
        subtitleKey: subtitleKey,
        allowNone: allowNone,
        onSelected: onSelected,
      ),
    );
  }

  // Quick Modal for Adding New Activity Type On-The-Fly
  Future<void> _showAddActivityTypeDialog(TimeLogModel row) async {
    final nameController = TextEditingController();
    final bool? created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_task_rounded, color: Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Add Activity Type',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter new activity name to register in Frappe:',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: _inputDecoration(hint: 'e.g. Quality Inspection'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              try {
                await _apiClient.post('oasis_mobile.api.timesheet.create_activity_type', {
                  'activity_type_name': newName,
                });
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx, true);
                }
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text('Error adding activity: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Create & Use',
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (created == true && nameController.text.trim().isNotEmpty) {
      final newAct = nameController.text.trim();
      setState(() {
        if (!_activityTypes.contains(newAct)) {
          _activityTypes.add(newAct);
        }
        row.activityType = newAct;
      });
    }
  }

  Future<void> _saveTimesheet() async {
    if (!_formKey.currentState!.validate()) return;
    if (_timeLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time log row.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payloadData = {
        'naming_series': _namingSeries,
        'company': _company.isNotEmpty ? _company : 'Oasis Trading and Importing HVAC',
        'employee': _employee,
        if (_parentProject.isNotEmpty) 'parent_project': _parentProject,
        'note': _noteController.text.trim(),
        'time_logs': _timeLogs.map((tl) => tl.toJson()).toList(),
      };

      if (widget.timesheet != null && widget.timesheet!.name != null) {
        // Edit / Update
        await _apiClient.post('oasis_mobile.api.timesheet.update_timesheet', {
          'name': widget.timesheet!.name,
          'data': payloadData,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Timesheet updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new
        final res = await _apiClient.post('oasis_mobile.api.timesheet.create_timesheet', {
          'data': payloadData,
        });

        final dynamic body = res['message'] ?? res['data'] ?? res;
        final doc = (body is Map && body['data'] != null)
            ? TimesheetModel.fromJson(Map<String, dynamic>.from(body['data']))
            : (res['data'] != null ? TimesheetModel.fromJson(Map<String, dynamic>.from(res['data'])) : null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Timesheet created successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          if (doc != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => TimesheetDetailScreen(timesheet: doc)),
            );
          } else {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving timesheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.timesheet != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Timesheet' : 'New Timesheet',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveTimesheet,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                  )
                : const Icon(Icons.save_rounded, color: Color(0xFF0284C7), size: 18),
            label: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 20),
                    _buildHoursBanner(),
                    const SizedBox(height: 24),
                    _buildTimeLogsHeader(),
                    const SizedBox(height: 12),
                    ..._timeLogs.asMap().entries.map((entry) {
                      return _buildTimeLogRowEditor(entry.key, entry.value);
                    }),
                    const SizedBox(height: 12),
                    _buildAddRowButton(),
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveTimesheet,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
          label: Text(
            isEditing ? 'Update Timesheet' : 'Create Timesheet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Header Information',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _namingSeries,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Employee Field (Role-Based: Searchable Modal for Manager, Locked for Employee)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Employee *',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (!_isManager)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF10B981)),
                      const SizedBox(width: 3),
                      Text(
                        'Logged-in User',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          if (_isManager)
            _buildSearchableTrigger(
              value: _employee.isNotEmpty
                  ? (_employeeName.isNotEmpty ? '$_employeeName ($_employee)' : _employee)
                  : null,
              hint: 'Search & Select Employee...',
              icon: Icons.person_search_rounded,
              onTap: () {
                _showSearchablePicker(
                  title: 'Select Employee',
                  items: _employeeList,
                  valueKey: 'name',
                  labelKey: 'employee_name',
                  subtitleKey: 'designation',
                  onSelected: (selected) {
                    setState(() {
                      _employee = selected['name'] ?? '';
                      _employeeName = selected['employee_name'] ?? _employee;
                      _company = selected['company'] ?? _company;
                    });
                  },
                );
              },
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 18, color: Color(0xFF0284C7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _employeeName.isNotEmpty
                          ? '$_employeeName ($_employee)'
                          : (_employee.isNotEmpty ? _employee : 'Assigning Employee...'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const Icon(Icons.lock_rounded, size: 14, color: AppColors.textLight),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // 2. Parent Project Searchable Trigger
          Text(
            'Parent Project (Optional)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _buildSearchableTrigger(
            value: _parentProject.isNotEmpty
                ? (_parentProjectName.isNotEmpty ? '$_parentProjectName ($_parentProject)' : _parentProject)
                : null,
            hint: 'Search & Select Project...',
            icon: Icons.folder_open_rounded,
            onTap: () {
              _showSearchablePicker(
                title: 'Select Parent Project',
                items: _projectsList,
                valueKey: 'name',
                labelKey: 'project_name',
                subtitleKey: 'company',
                allowNone: true,
                onSelected: (selected) {
                  setState(() {
                    _parentProject = selected['name'] ?? '';
                    _parentProjectName = selected['project_name'] ?? _parentProject;
                    for (var r in _timeLogs) {
                      if (r.project.isEmpty && _parentProject.isNotEmpty) {
                        r.project = _parentProject;
                        r.projectName = _parentProjectName;
                      }
                    }
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHoursBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                'Total Hours',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${_totalHours.toStringAsFixed(1)} hrs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          Container(height: 30, width: 1, color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
          Column(
            children: [
              Text(
                'Billable Hours',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${_totalBillableHours.toStringAsFixed(1)} hrs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLogsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'TIME LOGS (${_timeLogs.length})',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textLight,
            letterSpacing: 1.1,
          ),
        ),
        Text(
          'Tap fields to search & edit',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeLogRowEditor(int index, TimeLogModel row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row title and delete button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Row #${index + 1}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              if (_timeLogs.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() {
                      _timeLogs.removeAt(index);
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove Row',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Activity Type Dropdown with Quick Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity Type *',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              InkWell(
                onTap: () => _showAddActivityTypeDialog(row),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 13, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(
                        '+ New Activity',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildSearchableTrigger(
            value: row.activityType.isNotEmpty ? row.activityType : null,
            hint: 'Select Activity Type...',
            icon: Icons.category_outlined,
            onTap: () {
              final items = _activityTypes.map((act) => {'name': act, 'label': act}).toList();
              _showSearchablePicker(
                title: 'Select Activity Type',
                items: items,
                valueKey: 'name',
                labelKey: 'label',
                onSelected: (selected) {
                  setState(() {
                    row.activityType = selected['name'] ?? '';
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // From Time & To Time Pickers
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From Time *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickDateTime(context, isFrom: true, row: row),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.fromTime.isNotEmpty ? row.fromTime : 'Pick From',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: row.fromTime.isNotEmpty ? AppColors.textPrimary : AppColors.textLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To Time *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickDateTime(context, isFrom: false, row: row),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.toTime.isNotEmpty ? row.toTime : 'Pick To',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: row.toTime.isNotEmpty ? AppColors.textPrimary : AppColors.textLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hours and Expected Hours
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actual Hours *',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: row.hours.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(hint: '0.0'),
                      onChanged: (val) {
                        setState(() {
                          row.hours = double.tryParse(val) ?? 0.0;
                        });
                      },
                      validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected Hours',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: row.expectedHours.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(hint: '0.0'),
                      onChanged: (val) {
                        row.expectedHours = double.tryParse(val) ?? 0.0;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Project Selector (Searchable Modal)
          Text(
            'Project',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          _buildSearchableTrigger(
            value: row.project.isNotEmpty
                ? (row.projectName != null && row.projectName!.isNotEmpty
                    ? '${row.projectName} (${row.project})'
                    : row.project)
                : null,
            hint: 'Search & Select Project...',
            icon: Icons.folder_open_rounded,
            onTap: () {
              _showSearchablePicker(
                title: 'Select Project',
                items: _projectsList,
                valueKey: 'name',
                labelKey: 'project_name',
                subtitleKey: 'company',
                allowNone: true,
                onSelected: (selected) {
                  setState(() {
                    row.project = selected['name'] ?? '';
                    row.projectName = selected['project_name'] ?? row.project;
                    row.task = ''; // Reset task when project changes
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Task Selector (Searchable Modal with full API params & auto project linking)
          Text(
            'Task (Optional / Search Any Task)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          _buildSearchableTrigger(
            value: row.task.isNotEmpty ? row.task : null,
            hint: row.project.isNotEmpty ? 'Select Task for ${row.project}...' : 'Search & Select Task...',
            icon: Icons.assignment_outlined,
            onTap: () async {
              // Fetch tasks using the upgraded API
              List<Map<String, dynamic>> tasks = [];
              if (row.project.isNotEmpty) {
                tasks = await _fetchTasksForProject(row.project);
              } else {
                try {
                  final res = await _apiClient.get(
                    'oasis_mobile.api.timesheet.get_tasks_list',
                    params: {'limit_page_length': '100'},
                  );
                  final dynamic taskMsg = res['message'] ?? res['data'] ?? res;
                  dynamic taskList = (taskMsg is Map && taskMsg['data'] is List)
                      ? taskMsg['data']
                      : (taskMsg is List ? taskMsg : (res['data'] is List ? res['data'] : []));
                  if (taskList is List) {
                    tasks = taskList.map((t) => Map<String, dynamic>.from(t)).toList();
                  }
                } catch (e) {
                  debugPrint('Error fetching all tasks: $e');
                }
              }

              if (!mounted) return;

              if (tasks.isEmpty) {
                _showManualTextInputDialog(
                  title: 'Enter Task ID / Name',
                  initialValue: row.task,
                  onSaved: (val) => setState(() => row.task = val),
                );
              } else {
                _showSearchablePicker(
                  title: row.project.isNotEmpty ? 'Select Task (${row.project})' : 'Select Task',
                  items: tasks,
                  valueKey: 'name',
                  labelKey: 'subject',
                  subtitleKey: 'status',
                  allowNone: true,
                  onSelected: (selected) {
                    setState(() {
                      row.task = selected['name'] ?? '';
                      // Auto-link project if task has project assigned and row project was empty
                      if (selected['project'] != null && selected['project'].toString().isNotEmpty && row.project.isEmpty) {
                        row.project = selected['project'];
                        final matchProj = _projectsList.firstWhere(
                          (p) => p['name'] == row.project,
                          orElse: () => {'project_name': row.project},
                        );
                        row.projectName = matchProj['project_name'] ?? row.project;
                      }
                      // Auto-suggest expected hours if available
                      if (selected['expected_time'] != null) {
                        final exp = double.tryParse(selected['expected_time'].toString()) ?? 0.0;
                        if (exp > 0 && row.hours == 4.0) {
                          row.expectedHours = exp;
                        }
                      }
                    });
                  },
                );
              }
            },
          ),
          const SizedBox(height: 12),

          // Billable & Completed Switches
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: row.isBillable == 1,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        setState(() => row.isBillable = (val == true) ? 1 : 0);
                      },
                    ),
                    Text(
                      'Billable',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: row.completed == 1,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (val) {
                        setState(() => row.completed = (val == true) ? 1 : 0);
                      },
                    ),
                    Text(
                      'Completed',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Detailed Activity Description (Multi-line Big Text Box)
          Text(
            'Activity Description *',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: row.description,
            minLines: 3,
            maxLines: 6,
            decoration: _inputDecoration(
              hint: 'Enter detailed work activity description (e.g. Completed installation of control board and tested wiring connections)...',
            ),
            onChanged: (val) => row.description = val.trim(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchableTrigger({
    required String? value,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0284C7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? value : hint,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                  color: hasValue ? AppColors.textPrimary : AppColors.textLight,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  void _showManualTextInputDialog({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSaved,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: _inputDecoration(hint: 'Type here...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              onSaved(controller.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            child: Text('Save', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRowButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _addEmptyTimeLogRow();
        });
      },
      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0284C7)),
      label: Text(
        'Add Another Time Log',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0284C7),
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Remarks / Daily Notes',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteController,
            minLines: 3,
            maxLines: 5,
            decoration: _inputDecoration(
              hint: 'Enter any overall notes or summary for this day\'s timesheet...',
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textLight),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
    );
  }
}

// ── Enhanced Searchable Picker Bottom Sheet ──────────────────────────────────
class _SearchablePickerSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String valueKey;
  final String labelKey;
  final String? subtitleKey;
  final bool allowNone;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    required this.valueKey,
    required this.labelKey,
    this.subtitleKey,
    this.allowNone = false,
    required this.onSelected,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(widget.items);
      } else {
        _filtered = widget.items.where((item) {
          final val = (item[widget.valueKey] ?? '').toString().toLowerCase();
          final label = (item[widget.labelKey] ?? '').toString().toLowerCase();
          final sub = widget.subtitleKey != null ? (item[widget.subtitleKey!] ?? '').toString().toLowerCase() : '';
          return val.contains(q) || label.contains(q) || sub.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 20),
                  hintText: 'Search here...',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textLight),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Items List
          Expanded(
            child: _filtered.isEmpty && !widget.allowNone
                ? Center(
                    child: Text(
                      'No matching results found',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: (widget.allowNone ? 1 : 0) + _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, index) {
                      if (widget.allowNone && index == 0) {
                        return ListTile(
                          title: Text(
                            'None (Clear Selection)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[400],
                            ),
                          ),
                          onTap: () {
                            widget.onSelected({'name': '', widget.labelKey: ''});
                            Navigator.pop(context);
                          },
                        );
                      }

                      final itemIndex = widget.allowNone ? index - 1 : index;
                      final item = _filtered[itemIndex];
                      final value = (item[widget.valueKey] ?? '').toString();
                      final label = (item[widget.labelKey] ?? value).toString();
                      final subtitle = widget.subtitleKey != null ? (item[widget.subtitleKey!] ?? '').toString() : '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Text(
                          label.isNotEmpty ? label : value,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: (value != label && value.isNotEmpty) || subtitle.isNotEmpty
                            ? Text(
                                [if (value != label && value.isNotEmpty) value, if (subtitle.isNotEmpty) subtitle].join(' • '),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
                        onTap: () {
                          widget.onSelected(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
