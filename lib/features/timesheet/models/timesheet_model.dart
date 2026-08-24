import 'package:flutter/material.dart';

class TaskModel {
  final String name;
  final String subject;
  final String? project;
  final String? status;
  final String? priority;
  final String? expStartDate;
  final String? expEndDate;
  final double expectedTime;
  final double progress;
  final int isGroup;
  final String? description;

  TaskModel({
    required this.name,
    required this.subject,
    this.project,
    this.status,
    this.priority,
    this.expStartDate,
    this.expEndDate,
    this.expectedTime = 0.0,
    this.progress = 0.0,
    this.isGroup = 0,
    this.description,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      name: json['name'] ?? '',
      subject: json['subject'] ?? json['name'] ?? '',
      project: json['project'],
      status: json['status'],
      priority: json['priority'],
      expStartDate: json['exp_start_date'],
      expEndDate: json['exp_end_date'],
      expectedTime: (json['expected_time'] is num)
          ? (json['expected_time'] as num).toDouble()
          : (double.tryParse(json['expected_time']?.toString() ?? '0') ?? 0.0),
      progress: (json['progress'] is num)
          ? (json['progress'] as num).toDouble()
          : (double.tryParse(json['progress']?.toString() ?? '0') ?? 0.0),
      isGroup: json['is_group'] == 1 || json['is_group'] == true ? 1 : 0,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'subject': subject,
      if (project != null) 'project': project,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (expStartDate != null) 'exp_start_date': expStartDate,
      if (expEndDate != null) 'exp_end_date': expEndDate,
      'expected_time': expectedTime,
      'progress': progress,
      'is_group': isGroup,
      if (description != null) 'description': description,
    };
  }
}

class TimeLogModel {
  final String? name;
  String activityType;
  String fromTime;
  String toTime;
  double expectedHours;
  double hours;
  int completed; // 1 or 0
  String project;
  String? projectName;
  String task;
  int isBillable; // 1 or 0
  String description;

  TimeLogModel({
    this.name,
    this.activityType = '',
    this.fromTime = '',
    this.toTime = '',
    this.expectedHours = 0.0,
    this.hours = 0.0,
    this.completed = 0,
    this.project = '',
    this.projectName,
    this.task = '',
    this.isBillable = 1,
    this.description = '',
  });

  factory TimeLogModel.fromJson(Map<String, dynamic> json) {
    return TimeLogModel(
      name: json['name'],
      activityType: json['activity_type'] ?? '',
      fromTime: json['from_time'] ?? '',
      toTime: json['to_time'] ?? '',
      expectedHours: (json['expected_hours'] is num)
          ? (json['expected_hours'] as num).toDouble()
          : (double.tryParse(json['expected_hours']?.toString() ?? '0') ?? 0.0),
      hours: (json['hours'] is num)
          ? (json['hours'] as num).toDouble()
          : (double.tryParse(json['hours']?.toString() ?? '0') ?? 0.0),
      completed: json['completed'] == 1 || json['completed'] == true || json['completed'] == '1' ? 1 : 0,
      project: json['project'] ?? '',
      projectName: json['project_name'],
      task: json['task'] ?? '',
      isBillable: json['is_billable'] == 0 || json['is_billable'] == false || json['is_billable'] == '0' ? 0 : 1,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'activity_type': activityType,
      'from_time': fromTime,
      'to_time': toTime,
      'expected_hours': expectedHours,
      'hours': hours,
      'completed': completed,
      'project': project,
      if (projectName != null) 'project_name': projectName,
      'task': task,
      'is_billable': isBillable,
      'description': description,
    };
  }
}

class TimesheetModel {
  final String? name;
  final String namingSeries;
  final String company;
  final String status;
  final int docstatus;
  final String employee;
  final String? employeeName;
  final String? department;
  final String? startDate;
  final String? endDate;
  final double totalHours;
  final double totalBillableHours;
  final String? parentProject;
  final String? note;
  final String? modified;
  final List<TimeLogModel> timeLogs;

  TimesheetModel({
    this.name,
    this.namingSeries = 'TS-.YYYY.-',
    this.company = '',
    this.status = 'Draft',
    this.docstatus = 0,
    this.employee = '',
    this.employeeName,
    this.department,
    this.startDate,
    this.endDate,
    this.totalHours = 0.0,
    this.totalBillableHours = 0.0,
    this.parentProject,
    this.note,
    this.modified,
    this.timeLogs = const [],
  });

  factory TimesheetModel.fromJson(Map<String, dynamic> json) {
    return TimesheetModel(
      name: json['name'],
      namingSeries: json['naming_series'] ?? 'TS-.YYYY.-',
      company: json['company'] ?? '',
      status: json['status'] ?? 'Draft',
      docstatus: json['docstatus'] is int
          ? json['docstatus']
          : (json['docstatus'] != null ? int.tryParse(json['docstatus'].toString()) ?? 0 : 0),
      employee: json['employee'] ?? '',
      employeeName: json['employee_name'] ?? json['employee'] ?? '',
      department: json['department'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      totalHours: (json['total_hours'] is num)
          ? (json['total_hours'] as num).toDouble()
          : (double.tryParse(json['total_hours']?.toString() ?? '0') ?? 0.0),
      totalBillableHours: (json['total_billable_hours'] is num)
          ? (json['total_billable_hours'] as num).toDouble()
          : (double.tryParse(json['total_billable_hours']?.toString() ?? '0') ?? 0.0),
      parentProject: json['parent_project'],
      note: json['note'],
      modified: json['modified'],
      timeLogs: (json['time_logs'] as List?)
              ?.map((item) => TimeLogModel.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'naming_series': namingSeries,
      'company': company,
      'status': status,
      'docstatus': docstatus,
      'employee': employee,
      if (employeeName != null) 'employee_name': employeeName,
      if (department != null) 'department': department,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'total_hours': totalHours,
      'total_billable_hours': totalBillableHours,
      if (parentProject != null) 'parent_project': parentProject,
      if (note != null) 'note': note,
      'time_logs': timeLogs.map((tl) => tl.toJson()).toList(),
    };
  }

  Color get statusColor {
    final s = status.toLowerCase();
    if (s == 'submitted') {
      return const Color(0xFF10B981); // Emerald Green
    } else if (s == 'billed') {
      return const Color(0xFF6366F1); // Indigo / Purple
    } else if (s == 'payslip') {
      return const Color(0xFF0EA5E9); // Sky Blue
    } else if (s == 'cancelled') {
      return const Color(0xFFEF4444); // Red
    } else {
      return const Color(0xFFF59E0B); // Amber / Draft
    }
  }
}
