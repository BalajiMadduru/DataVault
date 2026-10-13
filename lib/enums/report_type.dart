enum ReportType {
  dailyPurchase('Day Wise Purchase Data'),
  dailySeed('Day Wise Seed Purchase Data'),
  weightList('Weight List Report'),
  heap('Heap Report'); // NEW

  final String label;
  const ReportType(this.label);
}