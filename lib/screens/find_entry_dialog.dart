import 'package:flutter/material.dart';
import '../widgets/common_form_widgets.dart';

class FindEntryDialog extends StatelessWidget {
  final String entryTypeLabel;
  final IconData headerIcon;
  final Color headerColor;
  final GlobalKey<FormState> formKey;
  final FocusNode focusNode;
  final String? selectedCentre;
  final Function(String?) onCentreChanged;
  final TextEditingController reportNoController;
  final DateTime selectedDate;
  final VoidCallback onDateTap;
  final String? lookupError;
  final bool isSearching;
  final VoidCallback onFind;

  const FindEntryDialog({
    super.key,
    required this.entryTypeLabel,
    required this.headerIcon,
    required this.headerColor,
    required this.formKey,
    required this.focusNode,
    required this.selectedCentre,
    required this.onCentreChanged,
    required this.reportNoController,
    required this.selectedDate,
    required this.onDateTap,
    required this.lookupError,
    required this.isSearching,
    required this.onFind,
  });

  @override
  Widget build(BuildContext context) {
    return CommonFormWidgets.findEntryDialog(
      entryTypeLabel: entryTypeLabel,
      headerIcon: headerIcon,
      headerColor: headerColor,
      formKey: formKey,
      focusNode: focusNode,
      selectedCentre: selectedCentre,
      onCentreChanged: onCentreChanged,
      reportNoController: reportNoController,
      selectedDate: selectedDate,
      onDateTap: onDateTap,
      lookupError: lookupError,
      isSearching: isSearching,
      onFind: onFind,
    );
  }
}