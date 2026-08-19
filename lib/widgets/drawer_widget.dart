import 'package:flutter/material.dart';
import '../enums/report_type.dart';

class CustomDrawer extends StatefulWidget {
  final ReportType selectedType;
  final Function(ReportType) onTypeSelected;
  final VoidCallback onCreatePurchase;
  final VoidCallback onCreateSeed;
  final VoidCallback onModifyPurchase;
  final VoidCallback onModifySeed;
  final VoidCallback onViewPurchaseReports;
  final VoidCallback onViewSeedReports;
  final VoidCallback? onViewProforma;

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
    this.onViewProforma,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool _isPurchaseExpanded = true;
  bool _isSeedExpanded = false;
  bool _isReportsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF0F172A),
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF1E293B),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.assignment_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select report type',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Expandable Sections
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),

                    // ============ DAILY PURCHASE SECTION ============
                    _buildExpandableSection(
                      title: 'Daily Purchase',
                      icon: Icons.shopping_basket_rounded,
                      isExpanded: _isPurchaseExpanded,
                      onTap: () {
                        setState(() {
                          _isPurchaseExpanded = !_isPurchaseExpanded;
                          // Optionally collapse others
                          // _isSeedExpanded = false;
                          // _isReportsExpanded = false;
                        });
                      },
                      children: [
                        _buildSubItem(
                          context: context,
                          title: 'Create Purchase Entry',
                          icon: Icons.add_circle_outline,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreatePurchase();
                          },
                        ),
                        _buildSubItem(
                          context: context,
                          title: 'Modify Purchase Entry',
                          icon: Icons.edit_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onModifyPurchase();
                          },
                        ),
                      ],
                    ),

                    // ============ DAILY SEED SECTION ============
                    _buildExpandableSection(
                      title: 'Daily Seed',
                      icon: Icons.eco_rounded,
                      isExpanded: _isSeedExpanded,
                      onTap: () {
                        setState(() {
                          _isSeedExpanded = !_isSeedExpanded;
                          // Optionally collapse others
                          // _isPurchaseExpanded = false;
                          // _isReportsExpanded = false;
                        });
                      },
                      children: [
                        _buildSubItem(
                          context: context,
                          title: 'Create Seed Entry',
                          icon: Icons.add_circle_outline,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreateSeed();
                          },
                        ),
                        _buildSubItem(
                          context: context,
                          title: 'Modify Seed Entry',
                          icon: Icons.edit_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onModifySeed();
                          },
                        ),
                      ],
                    ),

                    // ============ REPORTS SECTION ============
                    _buildExpandableSection(
                      title: 'Reports',
                      icon: Icons.list_alt,
                      isExpanded: _isReportsExpanded,
                      onTap: () {
                        setState(() {
                          _isReportsExpanded = !_isReportsExpanded;
                          // Optionally collapse others
                          // _isPurchaseExpanded = false;
                          // _isSeedExpanded = false;
                        });
                      },
                      children: [
                        _buildSubItem(
                          context: context,
                          title: 'View Purchase Reports',
                          icon: Icons.visibility_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onViewPurchaseReports();
                          },
                        ),
                        _buildSubItem(
                          context: context,
                          title: 'View Seed Reports',
                          icon: Icons.visibility_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onViewSeedReports();
                          },
                        ),
                        if (widget.onViewProforma != null)
                          _buildSubItem(
                            context: context,
                            title: 'Proforma Reports',
                            icon: Icons.picture_as_pdf,
                            onTap: () {
                              Navigator.pop(context);
                              widget.onViewProforma!();
                            },
                            accentColor: const Color(0xFF059669),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        // Main section header
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Icon(
              icon,
              color: Colors.grey[400],
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[400],
            ),
            onTap: onTap,
            tileColor: Colors.transparent,
            hoverColor: const Color(0xFF1E293B),
            focusColor: const Color(0xFF1E293B),
            splashColor: Colors.grey[800]?.withOpacity(0.3),
          ),
        ),
        // Children (sub-items)
        if (isExpanded)
          Container(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: children,
            ),
          ),
        const Divider(color: Color(0xFF1E293B), height: 1),
      ],
    );
  }

  Widget _buildSubItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          size: 20,
          color: accentColor ?? Colors.grey[500],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: accentColor ?? Colors.grey[400],
            fontSize: 13,
          ),
        ),
        onTap: onTap,
        tileColor: Colors.transparent,
        hoverColor: const Color(0xFF1E293B),
        focusColor: const Color(0xFF1E293B),
        splashColor: accentColor != null
            ? accentColor.withOpacity(0.2)
            : Colors.grey[800]?.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
      ),
    );
  }
}