import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/report_type.dart';
import '../services/apiservice.dart';
import '../models/report_modals.dart';  // ADD THIS - use FactoryData from here

// Import the actual implementations
import 'purchase_entry_dialog.dart';
import 'seed_entry_dialog.dart';

void debugLog(String message) {
  if (kDebugMode) {
    print(message);
  }
}

// Factory data model for seed report
class FactoryData {
  String factoryName;
  String variety;
  int progressiveRealisable;
  int progressiveSold;
  int dayUnsold;
  int kapasForm;
  int readyForm;
  int total;
  int baseRate;

  FactoryData({
    required this.factoryName,
    required this.variety,
    required this.progressiveRealisable,
    required this.progressiveSold,
    required this.dayUnsold,
    required this.kapasForm,
    required this.readyForm,
    required this.total,
    required this.baseRate,
  });

  Map<String, dynamic> toJson() => {
    'factoryName': factoryName,
    'variety': variety ?? '-',  // 👈 MUST have this fallback here too!
    'progressiveRealisable': progressiveRealisable,
    'progressiveSold': progressiveSold,
    'dayUnsold': dayUnsold,
    'kapasForm': kapasForm,
    'readyForm': readyForm,
    'total': total,
    'baseRate': baseRate,
  };

  factory FactoryData.fromJson(Map<String, dynamic> json) => FactoryData(
    factoryName: json['factoryName'] as String? ?? '',
    variety: json['variety'] as String? ?? '',
    progressiveRealisable: (json['progressiveRealisable'] as num?)?.toInt() ?? 0,
    progressiveSold: (json['progressiveSold'] as num?)?.toInt() ?? 0,
    dayUnsold: (json['dayUnsold'] as num?)?.toInt() ?? 0,
    kapasForm: (json['kapasForm'] as num?)?.toInt() ?? 0,
    readyForm: (json['readyForm'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    baseRate: (json['baseRate'] as num?)?.toInt() ?? 0,
  );
}

// Simple factory data model for purchase table view
class PurchaseFactoryData {
  String factoryName;
  int heapNo;
  double heapQty;
  int seedFarmers;
  int seedRealisable;
  int readySeedSold;
  int readySeedUnsold;
  int baseRate;

  PurchaseFactoryData({
    required this.factoryName,
    required this.heapNo,
    required this.heapQty,
    required this.seedFarmers,
    required this.seedRealisable,
    required this.readySeedSold,
    required this.readySeedUnsold,
    required this.baseRate,
  });

  Map<String, dynamic> toJson() => {
    'factoryName': factoryName,
    'heapNo': heapNo,
    'heapQty': heapQty,
    'seedFarmers': seedFarmers,
    'seed_realisable': seedRealisable,
    'readySeedSold': readySeedSold,
    'readySeedUnsold': readySeedUnsold,
    'baseRate': baseRate,
  };

  factory PurchaseFactoryData.fromJson(Map<String, dynamic> json) => PurchaseFactoryData(
    factoryName: json['factoryName'] as String? ?? '',
    heapNo: (json['heapNo'] as num?)?.toInt() ?? 0,
    heapQty: (json['heapQty'] as num?)?.toDouble() ?? 0.0,
    seedFarmers: (json['seedFarmers'] as num?)?.toInt() ?? 0,
    seedRealisable: (json['seed_realisable'] as num?)?.toInt() ?? 0,
    readySeedSold: (json['readySeedSold'] as num?)?.toInt() ?? 0,
    readySeedUnsold: (json['readySeedUnsold'] as num?)?.toInt() ?? 0,
    baseRate: (json['baseRate'] as num?)?.toInt() ?? 0,
  );
}

// Base State class for shared functionality
abstract class CreateEntryDialogState<T extends StatefulWidget> extends State<T> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> lookupFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> factoryFormKey = GlobalKey<FormState>();
  final ScrollController scrollController = ScrollController();
  final FocusNode dialogFocusNode = FocusNode();
  bool isSubmitting = false;

  // Lookup state
  bool entryFound = false;
  bool isSearching = false;
  String? docId;
  String? lookupError;

  // Header fields
  String? selectedCentre;
  final reportNoController = TextEditingController();
  final moistureController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  bool isLoadingReportNo = false;

  static const String prefKeyLastCentre = 'last_used_centre';

  final List<String> centres = [
    'Devadurga',
    'Raichur',
    'Sindhanur',
    'Lingasugur',
    'Manvi',
    'Sirwar',
  ];

  // Getters for report type info
  ReportType get reportType;
  String get reportTypeLabel;
  Color get accentColor;
  IconData get iconData;
  String get routeKey;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    dialogFocusNode.dispose();
    reportNoController.dispose();
    moistureController.dispose();
    super.dispose();
  }

  Future<void> loadDefaultCentre() async {
    if (selectedCentre != null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefKeyLastCentre);
    if (!mounted) return;
    if (saved != null && centres.contains(saved)) {
      setState(() {
        selectedCentre = saved;
      });
    }
  }

  Future<void> rememberCentre(String centre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyLastCentre, centre);
  }

  String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Future<void> autoGenerateReportNo() async {
    if (selectedCentre == null || selectedCentre!.isEmpty) return;

    setState(() {
      isLoadingReportNo = true;
    });

    final normalizedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    try {
      final response = await ApiService.getNextReportNo(
        type: routeKey,
        centre: selectedCentre!,
        date: normalizedDate,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        final nextReportNo = response.data!['nextReportNo'] as int?;
        if (nextReportNo != null) {
          setState(() {
            reportNoController.text = nextReportNo.toString();
          });
        }
      }
    } catch (e) {
      debugLog('❌ Error generating report number: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReportNo = false;
        });
      }
    }
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> onCentreSelected(String centre) async {
    await autoGenerateReportNo();
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      await onDateChanged(picked);
      await autoGenerateReportNo();
    }
  }

  Future<void> onDateChanged(DateTime date) async {}

  Future<void> findEntry() async {
    if (!lookupFormKey.currentState!.validate()) return;
    if (selectedCentre == null) return;

    final reportNo = int.tryParse(reportNoController.text);
    if (reportNo == null) return;

    setState(() {
      isSearching = true;
      lookupError = null;
    });

    final normalizedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final response = await ApiService.findEntry(
      type: routeKey,
      centre: selectedCentre!,
      reportNo: reportNo,
      date: normalizedDate,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      final entry = Map<String, dynamic>.from(
        response.data!['entry'] as Map,
      );
      setState(() {
        isSearching = false;
        lookupError = null;
        docId = entry['id']?.toString();
        entryFound = true;
      });
      loadExistingData(entry);
    } else {
      setState(() {
        isSearching = false;
        lookupError = response.message;
      });
    }
  }

  void resetLookup() {
    setState(() {
      entryFound = false;
      docId = null;
      lookupError = null;
    });
  }

  // Abstract methods
  void loadExistingData(Map<String, dynamic> data);
  void showCelebration();
  void submitForm();

  // Reusable Widgets
  Widget buildCloseButton() {
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

  Widget buildSectionHeader(String title) {
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

  Widget buildSectionHeaderWithAction(
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

  Widget buildTextField({
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

  Widget buildCentreDropdown({bool readOnly = false}) {
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
      onChanged: readOnly
          ? null
          : (value) {
        setState(() {
          selectedCentre = value;
        });
        if (value != null) {
          rememberCentre(value);
          onCentreSelected(value);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a centre';
        }
        return null;
      },
    );
  }
}

// Main Dialog Widget - factory/container
class CreateEntryDialog extends StatelessWidget {
  final ReportType type;
  final bool isModify;
  final Map<String, dynamic>? existingData;

  const CreateEntryDialog({
    super.key,
    required this.type,
    this.isModify = false,
    this.existingData,
  });

  @override
  Widget build(BuildContext context) {
    if (type == ReportType.dailyPurchase) {
      return PurchaseEntryDialog(  // Changed from PurchaseCreateEntryDialog
        isModify: isModify,
        existingData: existingData,
      );
    } else {
      return SeedEntryDialog(  // Changed from SeedCreateEntryDialog
        isModify: isModify,
        existingData: existingData,
      );
    }
  }
}