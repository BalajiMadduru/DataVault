enum ReportType {
  dailyPurchase('Day Wise Purchase Data'),
  seedPurchase('Day Wise Seed Purchase Data');

  final String label;
  const ReportType(this.label);
}