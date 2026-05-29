import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkflowActionBar extends StatelessWidget {
  final List<String> workflowActions;
  final String currentState;
  final int docStatus;
  final bool isLoading;
  final ValueChanged<String> onAction;

  const WorkflowActionBar({
    super.key,
    required this.workflowActions,
    required this.currentState,
    required this.docStatus,
    required this.isLoading,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (workflowActions.isEmpty || docStatus != 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: workflowActions.map((action) {
          final config = _getActionConfig(action);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: config.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: config.color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: isLoading ? null : () => onAction(action),
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(config.icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          config.label.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  _ActionConfig _getActionConfig(String action) {
    final actLower = action.toLowerCase();
    if (actLower.contains('review')) {
      return _ActionConfig('Review', const Color(0xFF2563EB), Icons.send_rounded);
    } else if (actLower.contains('verify') || actLower.contains('verified')) {
      return _ActionConfig('Verify', const Color(0xFF0D9488), Icons.verified_rounded);
    } else if (actLower.contains('approve') || actLower.contains('approved')) {
      return _ActionConfig('Approve', const Color(0xFF16A34A), Icons.check_circle_rounded);
    } else if (actLower.contains('reject') || actLower.contains('rejected')) {
      return _ActionConfig('Reject', const Color(0xFFDC2626), Icons.cancel_rounded);
    } else if (actLower.contains('submit')) {
      return _ActionConfig('Submit', const Color(0xFF4F46E5), Icons.upload_rounded);
    } else if (actLower.contains('cancel') || actLower.contains('cancelled')) {
      return _ActionConfig('Cancel', const Color(0xFFEA580C), Icons.block_rounded);
    } else {
      return _ActionConfig(action, const Color(0xFF4B5563), Icons.help_outline_rounded);
    }
  }
}

class _ActionConfig {
  final String label;
  final Color color;
  final IconData icon;

  _ActionConfig(this.label, this.color, this.icon);
}
