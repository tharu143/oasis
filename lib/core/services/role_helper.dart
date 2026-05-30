import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Determines the role-based workflow state and messaging for a logged-in user.
///
/// Priority order (highest wins):
///   1. Oasis Manager → "Verified By Finance Team" (pending MD approval)
///   2. Accounts User/Manager → "Pending" (pending finance verification)
///   3. Default (Sales User, Purchase User, etc.) → "Draft" (pending review)
class RoleHelper {
  /// Returns the workflow state the current user needs to act on,
  /// based on their highest-priority role.
  static String getActionState(List<String> roles) {
    if (_isOasisMgr(roles)) return 'Verified By Finance Team';
    if (_isAccounts(roles)) return 'Pending';
    return 'Draft';
  }

  /// Human-readable label for the action state.
  static String getActionLabel(List<String> roles) {
    if (_isOasisMgr(roles)) return 'Pending MD Approval';
    if (_isAccounts(roles)) return 'Pending Finance Verification';
    return 'Pending Review';
  }

  /// Short description shown in the Action Required banner.
  static String getActionSubtitle(List<String> roles) {
    if (_isOasisMgr(roles)) {
      return 'Finance has verified these. Your approval is needed.';
    }
    if (_isAccounts(roles)) {
      return 'These are waiting for your Finance verification.';
    }
    return 'These drafts need to be sent for review.';
  }

  /// Short "X docs to review" text for module dashboards.
  static String getActionDescription(List<String> roles, int count, String docLabel) {
    if (_isOasisMgr(roles)) {
      return 'You have $count $docLabel pending your MD approval';
    }
    if (_isAccounts(roles)) {
      return 'You have $count $docLabel awaiting Finance verification';
    }
    return 'You have $count $docLabel to send for review';
  }

  static Color getActionColor(List<String> roles) {
    if (_isOasisMgr(roles)) return const Color(0xFF16A34A);
    if (_isAccounts(roles)) return const Color(0xFF0D9488);
    return const Color(0xFF2563EB); // primary blue for sales
  }

  static IconData getActionIcon(List<String> roles) {
    if (_isOasisMgr(roles)) return Icons.admin_panel_settings_rounded;
    if (_isAccounts(roles)) return Icons.verified_user_rounded;
    return Icons.rate_review_rounded;
  }

  // ─── Role checks ─────────────────────────────────────────────────────────

  static bool _isOasisMgr(List<String> roles) {
    return roles.any((r) {
      final l = r.toLowerCase();
      return l == 'oasis mgr' ||
          l == 'oasis manager' ||
          l.contains('oasis') && l.contains('mgr');
    });
  }

  static bool _isAccounts(List<String> roles) {
    // Only pure accounts roles — NOT sales/purchase managers who also have accounts
    final hasAccountsRole = roles.any((r) {
      final l = r.toLowerCase();
      return l == 'accounts user' || l == 'accounts manager';
    });
    // If the user ALSO has a Sales/Purchase role, Sales/Purchase takes priority
    final hasSalesPurchaseRole = roles.any((r) {
      final l = r.toLowerCase();
      return l == 'sales user' ||
          l == 'sales manager' ||
          l == 'purchase user' ||
          l == 'purchase manager';
    });
    // Accounts role only applies if they don't have a Sales/Purchase role
    return hasAccountsRole && !hasSalesPurchaseRole;
  }

  /// Load roles from SharedPreferences and return the action state.
  static Future<String> getActionStateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('roles') ?? [];
    return getActionState(roles);
  }

  /// Load roles from SharedPreferences and return the full RoleInfo.
  static Future<RoleInfo> getRoleInfoFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('roles') ?? [];
    return RoleInfo(
      roles: roles,
      actionState: getActionState(roles),
      actionLabel: getActionLabel(roles),
      actionSubtitle: getActionSubtitle(roles),
      actionColor: getActionColor(roles),
      actionIcon: getActionIcon(roles),
    );
  }
}

/// Convenience value object holding all role-derived display info.
class RoleInfo {
  final List<String> roles;
  final String actionState;
  final String actionLabel;
  final String actionSubtitle;
  final Color actionColor;
  final IconData actionIcon;

  const RoleInfo({
    required this.roles,
    required this.actionState,
    required this.actionLabel,
    required this.actionSubtitle,
    required this.actionColor,
    required this.actionIcon,
  });
}
