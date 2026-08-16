class DailyPurchaseData {
  final DateTime date;
  final String centre;
  final int reportNo;
  final String variety;
  final double dayArrivalsApmc;
  final double dayArrivalsOutside;
  final double progressiveArrivalsApmc;
  final double progressiveArrivalsOutside;
  final String moisturePercentage;
  final double marketRateHighest;
  final double marketRateLowest;
  final double marketRateAverage;
  final double marketSeedRateHighest;
  final double marketSeedRateLowest;
  final double cciPurchaseQtls;
  final int cciPurchaseBales;
  final int cciKapasMoisture;
  final double mspValueDayWise;
  final double mspValueProgressive;
  final int farmersBenefittedDay;
  final int farmersBenefittedProgressive;
  final double cciRateHighest;
  final double cciRateLowest;
  final double cciRateAverage;
  final int cciSeedRate;
  final double cciOutTurn;
  final double cciShortage;
  final int cciExpenses;
  final int processingCycleDays;
  final int cciPadtha;
  final double progressivePurchaseQtls;
  final int progressivePurchaseBales;
  final int progressivePadtha;
  final int progressiveAvgRate;
  final int balesPressedToday;
  final int balesPressedProgressive;
  final int totalBalesShifted;
  final String sampleSent;
  final String heapResult;

  DailyPurchaseData({
    required this.date,
    required this.centre,
    required this.reportNo,
    required this.variety,
    required this.dayArrivalsApmc,
    required this.dayArrivalsOutside,
    required this.progressiveArrivalsApmc,
    required this.progressiveArrivalsOutside,
    required this.moisturePercentage,
    required this.marketRateHighest,
    required this.marketRateLowest,
    required this.marketRateAverage,
    required this.marketSeedRateHighest,
    required this.marketSeedRateLowest,
    required this.cciPurchaseQtls,
    required this.cciPurchaseBales,
    required this.cciKapasMoisture,
    required this.mspValueDayWise,
    required this.mspValueProgressive,
    required this.farmersBenefittedDay,
    required this.farmersBenefittedProgressive,
    required this.cciRateHighest,
    required this.cciRateLowest,
    required this.cciRateAverage,
    required this.cciSeedRate,
    required this.cciOutTurn,
    required this.cciShortage,
    required this.cciExpenses,
    required this.processingCycleDays,
    required this.cciPadtha,
    required this.progressivePurchaseQtls,
    required this.progressivePurchaseBales,
    required this.progressivePadtha,
    required this.progressiveAvgRate,
    required this.balesPressedToday,
    required this.balesPressedProgressive,
    required this.totalBalesShifted,
    required this.sampleSent,
    required this.heapResult,
  });
}

class SeedData {
  final String factoryName;
  final int heapNo;
  final double heapQty;
  final int farmersBenefitted;
  final int realisable;
  final int readySeedSold;
  final int readySeedUnsold;
  final int baseRate;

  SeedData({
    required this.factoryName,
    required this.heapNo,
    required this.heapQty,
    required this.farmersBenefitted,
    required this.realisable,
    required this.readySeedSold,
    required this.readySeedUnsold,
    required this.baseRate,
  });
}