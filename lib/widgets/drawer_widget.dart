import 'package:flutter/material.dart';
import '../enums/report_type.dart';
import 'drawer_expandabletile.dart';

class CustomDrawer extends StatefulWidget {
  final ReportType selectedType;
  final ValueChanged<ReportType> onTypeSelected;
  final VoidCallback onCreatePurchase;
  final VoidCallback onCreateSeed;
  final VoidCallback onModifyPurchase;
  final VoidCallback onModifySeed;
  final VoidCallback onViewPurchaseReports;
  final VoidCallback onViewSeedReports;

  const CustomDrawer({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    required this.onCreatePurchase,
    required this.onCreateSeed,
    required this.onModifyPurchase,
    required this.onModifySeed,
    required this.onViewPurchaseReports,
    required this.onViewSeedReports,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool _isPurchaseExpanded = false;
  bool _isSeedExpanded = false;
  bool _isReportsExpanded = false;

  void _togglePurchaseExpanded() {
    setState(() {
      _isPurchaseExpanded = !_isPurchaseExpanded;
      if (_isPurchaseExpanded) {
        _isSeedExpanded = false;
        _isReportsExpanded = false;
      }
    });
  }

  void _toggleSeedExpanded() {
    setState(() {
      _isSeedExpanded = !_isSeedExpanded;
      if (_isSeedExpanded) {
        _isPurchaseExpanded = false;
        _isReportsExpanded = false;
      }
    });
  }

  void _toggleReportsExpanded() {
    setState(() {
      _isReportsExpanded = !_isReportsExpanded;
      if (_isReportsExpanded) {
        _isPurchaseExpanded = false;
        _isSeedExpanded = false;
      }
    });
  }

  void _executeAction(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // DATA ENTRY Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'DATA ENTRY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  // Day Wise Purchase Data - Expandable
                  ExpandableTile(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Day Wise Purchase Data',
                    isExpanded: _isPurchaseExpanded,
                    onTap: _togglePurchaseExpanded,
                    children: [
                      SubTile(
                        icon: Icons.add_rounded,
                        title: 'Create',
                        onTap: () => _executeAction(widget.onCreatePurchase),
                      ),
                      SubTile(
                        icon: Icons.edit_rounded,
                        title: 'Modify',
                        onTap: () => _executeAction(widget.onModifyPurchase),
                      ),
                    ],
                  ),

                  // Day Wise Seed Purchase Data - Expandable
                  ExpandableTile(
                    icon: Icons.eco_rounded,
                    title: 'Day Wise Seed Purchase Data',
                    isExpanded: _isSeedExpanded,
                    onTap: _toggleSeedExpanded,
                    children: [
                      SubTile(
                        icon: Icons.add_rounded,
                        title: 'Create',
                        onTap: () => _executeAction(widget.onCreateSeed),
                      ),
                      SubTile(
                        icon: Icons.edit_rounded,
                        title: 'Modify',
                        onTap: () => _executeAction(widget.onModifySeed),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),

                  // REPORTS Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'REPORTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  ExpandableTile(
                    icon: Icons.assessment_rounded,
                    title: 'View Reports',
                    isExpanded: _isReportsExpanded,
                    onTap: _toggleReportsExpanded,
                    children: [
                      SubTile(
                        icon: Icons.shopping_basket_rounded,
                        title: 'Purchase Reports',
                        onTap: () => _executeAction(widget.onViewPurchaseReports),
                      ),
                      SubTile(
                        icon: Icons.eco_rounded,
                        title: 'Seed Reports',
                        onTap: () => _executeAction(widget.onViewSeedReports),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workflo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Farmers Purchase Data',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}