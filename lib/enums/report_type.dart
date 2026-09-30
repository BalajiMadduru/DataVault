enum ReportType {
  dailyPurchase('Day Wise Purchase Data'),
  dailySeed('Day Wise Seed Purchase Data'),  // Changed from 'seedPurchase' to 'dailySeed'
  weightList('Weight List Report'); // NEW

  final String label;
  const ReportType(this.label);
}