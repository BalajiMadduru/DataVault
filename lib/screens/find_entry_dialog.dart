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
  final String? selectedVariety;
  final List<String> varietyOptions;
  final Function(String?)? onVarietyChanged;

  /// Report number search field (hidden when [showReportNo] is false).
  final TextEditingController? reportNoController;
  final bool showReportNo;

  /// Lot number search field (shown only when a controller is supplied).
  final TextEditingController? lotNoController;
  final String lotNoLabel;
  final String lotNoHint;
  final String lotNoRequiredMessage;

  /// Date picker row (hidden when [showDate] is false).
  final bool showDate;
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
    this.selectedVariety,
    this.varietyOptions = const [],
    this.onVarietyChanged,
    this.reportNoController,
    this.showReportNo = true,
    this.lotNoController,
    this.lotNoLabel = 'Lot No.',
    this.lotNoHint = 'Enter lot number',
    this.lotNoRequiredMessage = 'Please enter lot number',
    this.showDate = true,
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
      selectedVariety: selectedVariety,
      varietyOptions: varietyOptions,
      onVarietyChanged: onVarietyChanged,
      reportNoController: reportNoController,
      showReportNo: showReportNo,
      lotNoController: lotNoController,
      lotNoLabel: lotNoLabel,
      lotNoHint: lotNoHint,
      lotNoRequiredMessage: lotNoRequiredMessage,
      showDate: showDate,
      selectedDate: selectedDate,
      onDateTap: onDateTap,
      lookupError: lookupError,
      isSearching: isSearching,
      onFind: onFind,
    );
  }
}