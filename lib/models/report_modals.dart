import 'package:flutter/foundation.dart' show kDebugMode;

void debugLog(String message) {
  if (kDebugMode) {
    print(message);
  }
}

/// Factory data model used by the Seed report (Ginning & Pressing factories).
///
/// "Day's unsold cotton seed in Quintals" is a grouped column made up of
/// kapasForm + readyForm (= total) — there's no separate standalone value
/// for it.
class FactoryData {
  String factoryName;
  String variety;
  int progressiveRealisable;
  int progressiveSold;
  int kapasForm;
  int readyForm;
  int total;
  int baseRate; // "Day's Budgeted Rate"
  double avgProgressiveBudgetedRate;

  FactoryData({
    required this.factoryName,
    required this.variety,
    required this.progressiveRealisable,
    required this.progressiveSold,
    required this.kapasForm,
    required this.readyForm,
    required this.total,
    required this.baseRate,
    required this.avgProgressiveBudgetedRate,
  });

  Map<String, dynamic> toJson() => {
    'factoryName': factoryName,
    'variety': variety ?? '-',
    'progressiveRealisable': progressiveRealisable,
    'progressiveSold': progressiveSold,
    'kapasForm': kapasForm,
    'readyForm': readyForm,
    'total': total,
    'baseRate': baseRate,
    'avgProgressiveBudgetedRate': avgProgressiveBudgetedRate,
  };

  factory FactoryData.fromJson(Map<String, dynamic> json) => FactoryData(
    factoryName: json['factoryName'] ?? '',
    variety: json['variety'] ?? '',
    progressiveRealisable: json['progressiveRealisable'] ?? 0,
    progressiveSold: json['progressiveSold'] ?? 0,
    kapasForm: json['kapasForm'] ?? 0,
    readyForm: json['readyForm'] ?? 0,
    total: json['total'] ?? 0,
    baseRate: json['baseRate'] ?? 0,
    avgProgressiveBudgetedRate: (json['avgProgressiveBudgetedRate'] ?? 0).toDouble(),
  );
}

/// Factory data model used by the Purchase report table
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

  factory PurchaseFactoryData.fromJson(Map<String, dynamic> json) =>
      PurchaseFactoryData(
        factoryName: json['factoryName'] ?? '',
        heapNo: json['heapNo'] ?? 0,
        heapQty: (json['heapQty'] ?? 0).toDouble(),
        seedFarmers: json['seedFarmers'] ?? 0,
        seedRealisable: json['seed_realisable'] ?? 0,
        readySeedSold: json['readySeedSold'] ?? 0,
        readySeedUnsold: json['readySeedUnsold'] ?? 0,
        baseRate: json['baseRate'] ?? 0,
      );
}

/// Static lists shared by both dialogs
class ReportConstants {
  static const List<String> varieties = [
    'BB MOD',
    'H-4',
    'DCH-32',
    'Suvin',
    'J-34',
    'LRA',
  ];

  static const List<String> centres = [
    'Devadurga',
    'Raichur',
    'Sindhanur',
    'Lingasugur',
    'Manvi',
    'Sirwar',
  ];

  static const String prefKeyLastCentre = 'last_used_centre';
}