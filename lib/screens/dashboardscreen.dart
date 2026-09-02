import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:datavault/screens/reports_listscreen.dart';

import '../services/apiservice.dart';
import 'loginscreen.dart';
import '../enums/report_type.dart';
import '../widgets/drawer_widget.dart';
import '../widgets/create_entry_dialog_base.dart'; // ADD THIS LINE
import 'proforma_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReportType _selectedType = ReportType.dailyPurchase;
  bool _isLoading = false;
  List<PurchaseEntry> _purchaseEntries = [];
  List<SeedEntry> _seedEntries = [];

  // Logged-in user's details, as saved in Firestore at login/signup.
  String _username = '';
  String _email = '';
  String _mobile = '';
  bool _isProfileLoading = true;

  void _handleViewProforma() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProformaListScreen(),
      ),
    );
  }


  Future<void> _loadUserProfile() async {
    final result = await ApiService.getCurrentUserProfile();
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        _username = result.data!['username'] as String? ?? '';
        _email = result.data!['email'] as String? ?? '';
        _mobile = result.data!['mobile'] as String? ?? '';
        _isProfileLoading = false;
      });
    } else {
      setState(() => _isProfileLoading = false);
    }
  }

  void _showProfileDetails() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF0F172A),
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _username.isNotEmpty ? _username : 'Your account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileDetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: _email),
            const SizedBox(height: 12),
            _ProfileDetailRow(icon: Icons.phone_outlined, label: 'Mobile', value: _mobile),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Real-time data simulation
  void _loadData() {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _purchaseEntries = _generatePurchaseData();
        _seedEntries = _generateSeedData();
        _isLoading = false;
      });
    });
  }

  List<PurchaseEntry> _generatePurchaseData() {
    final now = DateTime.now();
    return [
      PurchaseEntry(
        date: now.subtract(const Duration(hours: 1)),
        amount: 1250.50,
        category: 'Vegetables',
        quantity: 45,
        unit: 'kg',
      ),
      PurchaseEntry(
        date: now.subtract(const Duration(hours: 2)),
        amount: 890.75,
        category: 'Fruits',
        quantity: 30,
        unit: 'kg',
      ),
      PurchaseEntry(
        date: now.subtract(const Duration(hours: 3)),
        amount: 2100.00,
        category: 'Grains',
        quantity: 100,
        unit: 'kg',
      ),
      PurchaseEntry(
        date: now.subtract(const Duration(hours: 4)),
        amount: 560.25,
        category: 'Dairy',
        quantity: 25,
        unit: 'liters',
      ),
      PurchaseEntry(
        date: now.subtract(const Duration(hours: 5)),
        amount: 3200.00,
        category: 'Meat',
        quantity: 80,
        unit: 'kg',
      ),
    ];
  }

  List<SeedEntry> _generateSeedData() {
    final now = DateTime.now();
    return [
      SeedEntry(
        date: now.subtract(const Duration(hours: 1)),
        seedType: 'Wheat',
        quantity: 150,
        unit: 'kg',
        pricePerUnit: 45.50,
      ),
      SeedEntry(
        date: now.subtract(const Duration(hours: 2)),
        seedType: 'Rice',
        quantity: 200,
        unit: 'kg',
        pricePerUnit: 35.75,
      ),
      SeedEntry(
        date: now.subtract(const Duration(hours: 3)),
        seedType: 'Corn',
        quantity: 120,
        unit: 'kg',
        pricePerUnit: 28.00,
      ),
      SeedEntry(
        date: now.subtract(const Duration(hours: 4)),
        seedType: 'Soybean',
        quantity: 80,
        unit: 'kg',
        pricePerUnit: 52.25,
      ),
      SeedEntry(
        date: now.subtract(const Duration(hours: 5)),
        seedType: 'Sunflower',
        quantity: 60,
        unit: 'kg',
        pricePerUnit: 38.50,
      ),
    ];
  }

  // ============ DRAWER HANDLERS ============
  void _handleCreatePurchase() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateEntryDialog(
        type: ReportType.dailyPurchase,
        isModify: false,
      ),
    );
  }

  void _handleCreateSeed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateEntryDialog(
        type: ReportType.dailySeed,
        isModify: false,
      ),
    );
  }

  void _handleModifyPurchase() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateEntryDialog(
        type: ReportType.dailyPurchase,
        isModify: true,
      ),
    );
  }

  void _handleModifySeed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateEntryDialog(
        type: ReportType.dailySeed,
        isModify: true,
      ),
    );
  }

  void _handleViewPurchaseReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportsListScreen(
          reportType: 'purchase',
        ),
      ),
    );
  }

  void _handleViewSeedReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportsListScreen(
          reportType: 'seed',
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('You\'ll need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ApiService.logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Farmers Purchase Data',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: _username.isNotEmpty ? _username : 'Profile',
            onPressed: _showProfileDetails,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: CustomDrawer(
        selectedType: _selectedType,
        onTypeSelected: (type) {
          setState(() {
            _selectedType = type;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(type.label),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        onCreatePurchase: _handleCreatePurchase,
        onCreateSeed: _handleCreateSeed,
        onModifyPurchase: _handleModifyPurchase,
        onModifySeed: _handleModifySeed,
        onViewPurchaseReports: _handleViewPurchaseReports,
        onViewSeedReports: _handleViewSeedReports,
        onViewProforma: _handleViewProforma, // Add this line
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: _isProfileLoading
                ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            )
                : Text(
              _username.isNotEmpty ? 'Welcome, $_username' : 'Welcome back',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
              ),
            )
                : _SelectedTypeView(
              type: _selectedType,
              purchaseEntries: _purchaseEntries,
              seedEntries: _seedEntries,
              onRefresh: _loadData,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              Text(
                value.isNotEmpty ? value : '—',
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedTypeView extends StatelessWidget {
  final ReportType type;
  final List<PurchaseEntry> purchaseEntries;
  final List<SeedEntry> seedEntries;
  final VoidCallback onRefresh;

  const _SelectedTypeView({
    required this.type,
    required this.purchaseEntries,
    required this.seedEntries,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  type.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Last updated: ${DateFormat('hh:mm a').format(DateTime.now())}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 24),

            if (type == ReportType.dailyPurchase) ...[
              _PurchaseChartSection(entries: purchaseEntries),
            ] else ...[
              _SeedChartSection(entries: seedEntries),
            ],
          ],
        ),
      ),
    );
  }
}

// ============ PURCHASE CHART SECTION ============
class _PurchaseChartSection extends StatelessWidget {
  final List<PurchaseEntry> entries;

  const _PurchaseChartSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No purchase data available',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final totalAmount = entries.fold(0.0, (sum, entry) => sum + entry.amount);
    final totalQuantity = entries.fold(0.0, (sum, entry) => sum + entry.quantity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SummaryCard(
              title: 'Total Amount',
              value: '\$${totalAmount.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              color: const Color(0xFF0F172A),
            ),
            const SizedBox(width: 12),
            _SummaryCard(
              title: 'Total Quantity',
              value: '${totalQuantity.toStringAsFixed(0)} kg',
              icon: Icons.scale,
              color: const Color(0xFF38BDF8),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Distribution by Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: _buildPieSections(),
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quantity by Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BarChart(
                  BarChartData(
                    barGroups: _buildBarGroups(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < entries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  entries[index].category,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final colors = [
      const Color(0xFF38BDF8),
      const Color(0xFF818CF8),
      const Color(0xFF34D399),
      const Color(0xFFFBBF24),
      const Color(0xFFF472B6),
    ];

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final percentage = (data.amount / entries.fold(0.0, (sum, e) => sum + e.amount)) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: data.amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _buildBarGroups() {
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: data.quantity,
            color: const Color(0xFF38BDF8),
            width: 30,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }
}

// ============ SEED CHART SECTION ============
class _SeedChartSection extends StatelessWidget {
  final List<SeedEntry> entries;

  const _SeedChartSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No seed data available',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final totalQuantity = entries.fold(0.0, (sum, entry) => sum + entry.quantity);
    final totalValue = entries.fold(0.0, (sum, entry) => sum + (entry.quantity * entry.pricePerUnit));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SummaryCard(
              title: 'Total Quantity',
              value: '${totalQuantity.toStringAsFixed(0)} kg',
              icon: Icons.scale,
              color: const Color(0xFF34D399),
            ),
            const SizedBox(width: 12),
            _SummaryCard(
              title: 'Total Value',
              value: '\$${totalValue.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              color: const Color(0xFF0F172A),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seed Distribution by Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: _buildPieSections(),
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seed Quantity by Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BarChart(
                  BarChartData(
                    barGroups: _buildBarGroups(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 30,
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < entries.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  entries[index].seedType,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final colors = [
      const Color(0xFF34D399),
      const Color(0xFFFBBF24),
      const Color(0xFFF472B6),
      const Color(0xFF818CF8),
      const Color(0xFF38BDF8),
    ];

    final total = entries.fold(0.0, (sum, entry) => sum + entry.quantity);

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final percentage = (data.quantity / total) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: data.quantity,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _buildBarGroups() {
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: data.quantity,
            color: const Color(0xFF34D399),
            width: 30,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }
}

// ============ SUMMARY CARD ============
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============ DATA MODELS ============
class PurchaseEntry {
  final DateTime date;
  final double amount;
  final String category;
  final double quantity;
  final String unit;

  PurchaseEntry({
    required this.date,
    required this.amount,
    required this.category,
    required this.quantity,
    required this.unit,
  });
}

class SeedEntry {
  final DateTime date;
  final String seedType;
  final double quantity;
  final String unit;
  final double pricePerUnit;

  SeedEntry({
    required this.date,
    required this.seedType,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
  });
}