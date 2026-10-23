import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oasis/core/constants/app_colors.dart';

/// Helper to navigate to any detail screen across the app based on DocType and Name
void navigateToDocDetail(BuildContext context, {required String doctype, required String docname}) {
  final cleanName = docname.trim();
  final cleanDoctype = doctype.trim();

  if (cleanName.isEmpty) return;

  switch (cleanDoctype) {
    case 'Sales Invoice':
      Navigator.pushNamed(context, '/sales-invoice-detail', arguments: cleanName);
      break;
    case 'Sales Order':
      Navigator.pushNamed(context, '/sales-order-detail', arguments: cleanName);
      break;
    case 'Delivery Note':
      Navigator.pushNamed(context, '/delivery-note-detail', arguments: cleanName);
      break;
    case 'Purchase Order':
      Navigator.pushNamed(context, '/purchase-order-detail', arguments: cleanName);
      break;
    case 'Payment Entry':
      Navigator.pushNamed(context, '/payment-entry-detail', arguments: cleanName);
      break;
    case 'Journal Entry':
      Navigator.pushNamed(context, '/journal-entry-detail', arguments: cleanName);
      break;
    case 'Material Request':
      Navigator.pushNamed(context, '/material-request-detail', arguments: cleanName);
      break;
    case 'Timesheet':
      Navigator.pushNamed(context, '/timesheet-detail', arguments: cleanName);
      break;
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation not configured for $cleanDoctype ($cleanName)'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

/// A clickable link widget with link icon, ripple effect and styling
class DocLinkText extends StatelessWidget {
  final String doctype;
  final String docname;
  final TextStyle? style;
  final bool showIcon;

  const DocLinkText({
    super.key,
    required this.doctype,
    required this.docname,
    this.style,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    if (docname.trim().isEmpty) {
      return Text('-', style: style ?? GoogleFonts.plusJakartaSans(color: AppColors.textSecondary));
    }

    final defaultStyle = GoogleFonts.plusJakartaSans(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );

    return InkWell(
      onTap: () => navigateToDocDetail(context, doctype: doctype, docname: docname),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                docname,
                style: style ?? defaultStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showIcon) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new_rounded,
                size: 13,
                color: style?.color ?? AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
