enum ReportType {
  dailyPurchase('Day Wise Purchase Data'),
  dailySeed('Day Wise Seed Purchase Data');  // Changed from 'seedPurchase' to 'dailySeed'

  final String label;
  const ReportType(this.label);
}