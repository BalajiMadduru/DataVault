import 'package:flutter/material.dart';

class CommonFormWidgets {
  static Widget sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static Widget sectionHeaderWithAction(
      String title, {
        required String actionLabel,
        required VoidCallback onAction,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFF0F172A)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static Widget textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: readOnly ? const TextStyle(color: Color(0xFF64748B)) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : null,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static Widget centreDropdown({
    required String? selectedCentre,
    required bool readOnly,
    required Function(String?) onChanged,
    List<String> centres = const [
      'Devadurga',
      'Raichur',
      'Sindhanur',
      'Lingasugur',
      'Manvi',
      'Sirwar',
    ],
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedCentre,
      decoration: InputDecoration(
        labelText: 'Centre',
        hintText: 'Select centre',
        prefixIcon: const Icon(Icons.location_city),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
        ),
      ),
      items: centres.map((String centre) {
        return DropdownMenuItem(
          value: centre,
          child: Text(centre),
        );
      }).toList(),
      onChanged: readOnly ? null : onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a centre';
        }
        return null;
      },
    );
  }

  static Widget varietyDropdown({
    required String? selectedVariety,
    required bool readOnly,
    required Function(String?) onChanged,
    required List<String> varieties,
    bool isRequired = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedVariety,
      decoration: InputDecoration(
        labelText: 'Variety',
        hintText: 'Select variety',
        prefixIcon: const Icon(Icons.grass),
        filled: readOnly,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
        ),
      ),
      items: varieties.map((String variety) {
        return DropdownMenuItem(
          value: variety,
          child: Text(variety),
        );
      }).toList(),
      onChanged: readOnly ? null : onChanged,
      validator: isRequired
          ? (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a variety';
        }
        return null;
      }
          : null,
    );
  }

  static Widget closeButton(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: const Icon(
          Icons.close,
          size: 20,
          color: Color(0xFF64748B),
        ),
      ),
      tooltip: 'Close',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  // Find Entry Dialog widget
  static Widget findEntryDialog({
    required String entryTypeLabel,
    required IconData headerIcon,
    required Color headerColor,
    required GlobalKey<FormState> formKey,
    required FocusNode focusNode,
    required String? selectedCentre,
    required Function(String?) onCentreChanged,
    String? selectedVariety,
    List<String> varietyOptions = const [],
    Function(String?)? onVarietyChanged,
    required TextEditingController reportNoController,
    required DateTime selectedDate,
    required VoidCallback onDateTap,
    required String? lookupError,
    required bool isSearching,
    required VoidCallback onFind,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        focusNode: focusNode,
        autofocus: true,
        child: Builder(
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: headerColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(headerIcon, color: const Color(0xFF0F172A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Find $entryTypeLabel Entry',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      CommonFormWidgets.closeButton(context),
                    ],
                  ),
                  const SizedBox(height: 20),

                  CommonFormWidgets.centreDropdown(
                    selectedCentre: selectedCentre,
                    readOnly: false,
                    onChanged: onCentreChanged,
                  ),
                  const SizedBox(height: 12),

                  if (varietyOptions.isNotEmpty && onVarietyChanged != null) ...[
                    CommonFormWidgets.varietyDropdown(
                      selectedVariety: selectedVariety,
                      readOnly: false,
                      onChanged: onVarietyChanged,
                      varieties: varietyOptions,
                    ),
                    const SizedBox(height: 12),
                  ],

                  CommonFormWidgets.textField(
                    controller: reportNoController,
                    label: 'Report No.',
                    hint: 'Enter report number',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter report number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  InkWell(
                    onTap: onDateTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF64748B)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Date: ${CommonFormWidgets.formatDate(selectedDate)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (lookupError != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lookupError!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSearching ? null : onFind,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSearching
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
                            'Find Entry',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}