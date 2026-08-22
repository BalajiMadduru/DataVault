import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/apiservice.dart';
import '../models/report_modals.dart';
import 'proforma_view_screen.dart';

class ProformaListScreen extends StatefulWidget {
  const ProformaListScreen({super.key});

  @override
  State<ProformaListScreen> createState() => _ProformaListScreenState();
}

enum _DateFilterMode { single, range }

class _ProformaListScreenState extends State<ProformaListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _proformas = [];
  List<Map<String, dynamic>> _filteredProformas = [];
  String? _error;
  bool _isDeleting = false;

  // Filters
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  _DateFilterMode _filterMode = _DateFilterMode.single;
  String? _selectedCentreFilter;
  String? _selectedVarietyFilter;

  bool get _isDateFilterActive => _filterStartDate != null || _filterEndDate != null;

  bool get _isFilterActive =>
      _isDateFilterActive || _selectedCentreFilter != null || _selectedVarietyFilter != null;

  @override
  void initState() {
    super.initState();
    _loadProformas();
  }

  Future<void> _loadProformas() async {
    setState(() => _isLoading = true);

    final response = await ApiService.getProformas();

    if (!mounted) return;

    if (response.success && response.data != null) {
      setState(() {
        _proformas = List<Map<String, dynamic>>.from(
          response.data!['proformas'] as List,
        );
        _isLoading = false;
      });
      _applyFilters();
    } else {
      setState(() {
        _error = response.message;
        _isLoading = false;
      });
    }
  }

  // ========================================================================
  // HELPER METHODS - Extract purchaseEntryId from proforma
  // ========================================================================

  String? _getPurchaseEntryId(Map<String, dynamic> proforma) {
    // Try to get from top-level field first (older schema)
    if (proforma.containsKey('purchaseEntryId')) {
      final id = proforma['purchaseEntryId']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }

    // Try to get from entries map (newer schema)
    final entries = proforma['entries'];
    if (entries is Map<String, dynamic>) {
      // Get the first key from the entries map (this is the purchaseEntryId)
      if (entries.isNotEmpty) {
        return entries.keys.first.toString();
      }
    }

    // Try to get from entries as List (fallback)
    if (entries is List && entries.isNotEmpty) {
      final firstEntry = entries.first as Map<String, dynamic>?;
      if (firstEntry != null && firstEntry.containsKey('purchaseEntryId')) {
        return firstEntry['purchaseEntryId']?.toString();
      }
    }

    return null;
  }

  // Safe date parsing helper
  DateTime? _safeParseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  String _safeFormatDate(String? dateStr, {String defaultValue = 'N/A'}) {
    final date = _safeParseDate(dateStr);
    if (date == null) return defaultValue;
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatFilterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ========================================================================
  // FILTER METHODS
  // ========================================================================

  void _applyFilters() {
    setState(() {
      _filteredProformas = _proformas.where((proforma) {
        // Date filter
        final rawDate = proforma['date']?.toString();
        if (rawDate == null || rawDate.isEmpty) return false;

        final proformaDate = _safeParseDate(rawDate);
        if (proformaDate == null) return false;

        final normalizedDate = DateTime(proformaDate.year, proformaDate.month, proformaDate.day);

        if (_filterStartDate != null) {
          final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
          if (normalizedDate.isBefore(start)) return false;
        }

        if (_filterEndDate != null) {
          final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
          if (normalizedDate.isAfter(end)) return false;
        }

        // Centre filter
        if (_selectedCentreFilter != null && _selectedCentreFilter!.isNotEmpty) {
          final centre = proforma['centre']?.toString().toLowerCase() ?? '';
          if (centre != _selectedCentreFilter!.toLowerCase()) return false;
        }

        // Variety filter
        if (_selectedVarietyFilter != null && _selectedVarietyFilter!.isNotEmpty) {
          final variety = proforma['variety']?.toString().toLowerCase() ?? '';
          if (variety != _selectedVarietyFilter!.toLowerCase()) return false;
        }

        return true;
      }).toList();
    });
  }

  void _setFilterMode(_DateFilterMode mode) {
    if (_filterMode == mode) return;
    setState(() {
      _filterMode = mode;
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _applyFilters();
  }

  void _clearDateFilter() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _applyFilters();
  }

  void _clearCentreFilter() {
    setState(() => _selectedCentreFilter = null);
    _applyFilters();
  }

  void _clearVarietyFilter() {
    setState(() => _selectedVarietyFilter = null);
    _applyFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
      _selectedCentreFilter = null;
      _selectedVarietyFilter = null;
    });
    _applyFilters();
  }

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _filterStartDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked;
        _filterEndDate = picked;
      });
      _applyFilters();
    }
  }

  Future<void> _selectDateRange() async {
    final initialRange = _filterStartDate != null && _filterEndDate != null
        ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _openDatePicker() {
    if (_filterMode == _DateFilterMode.single) {
      _selectSingleDate();
    } else {
      _selectDateRange();
    }
  }

  // ========================================================================
  // DELETE PROFORMA METHOD
  // ========================================================================

  Future<void> _deleteProforma(Map<String, dynamic> proforma, int index) async {
    final docId = proforma['id']?.toString();
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Proforma ID not found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Proforma',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this proforma?',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Centre: ${proforma['centre'] ?? 'Unknown'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'Date: ${_safeFormatDate(proforma['date'])}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Quantity: ${proforma['quantity'] ?? 0} Quintals',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Seed Value: ₹${(proforma['seedValue'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final response = await ApiService.deleteProforma(docId);

      if (!mounted) {
        setState(() => _isDeleting = false);
        return;
      }

      if (response.success) {
        // Remove the proforma from both the source and filtered lists,
        // matched by id rather than index (index is only valid within
        // the currently-filtered list, not the underlying data).
        setState(() {
          _proformas.removeWhere((p) => p['id']?.toString() == docId);
          _filteredProformas.removeWhere((p) => p['id']?.toString() == docId);
          _isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Proforma deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error deleting proforma: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewProforma(String purchaseEntryId) {
    if (purchaseEntryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid proforma data - missing purchase entry ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProformaViewScreen(
          purchaseEntryId: purchaseEntryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proforma Reports'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProformas,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProformas,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : _filteredProformas.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isFilterActive ? Icons.search_off_rounded : Icons.picture_as_pdf,
                    size: 64,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isFilterActive ? 'No Proformas Match Your Filters' : 'No Proformas Generated Yet',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFilterActive
                        ? 'Try changing your filters'
                        : 'Generate a proforma from the Purchase Entry dialog',
                    style: const TextStyle(color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  if (_isFilterActive) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _clearAllFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                      ),
                      child: const Text('Clear All Filters'),
                    ),
                  ],
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredProformas.length,
              itemBuilder: (context, index) {
                final proforma = _filteredProformas[index];
                final dateStr = proforma['date']?.toString();
                final date = _safeParseDate(dateStr);

                // Extract purchaseEntryId from the proforma
                final purchaseEntryId = _getPurchaseEntryId(proforma) ?? '';
                final centre = proforma['centre'] ?? 'Unknown';
                final quantity = proforma['quantity'] ?? 0;
                final seedValue = proforma['seedValue'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf,
                        color: Color(0xFF059669),
                      ),
                    ),
                    title: Text(
                      'Centre: $centre',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${date != null ? DateFormat('dd/MM/yyyy').format(date) : 'N/A'}',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Quantity: $quantity Quintals',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Seed Value: ₹${(seedValue).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: purchaseEntryId.isNotEmpty
                              ? () => _viewProforma(purchaseEntryId)
                              : null,
                          tooltip: 'View Proforma',
                        ),
                        // DELETE ICON
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade400,
                            size: 20,
                          ),
                          onPressed: _isDeleting ? null : () => _deleteProforma(proforma, index),
                          tooltip: 'Delete Proforma',
                        ),
                      ],
                    ),
                    onTap: purchaseEntryId.isNotEmpty
                        ? () => _viewProforma(purchaseEntryId)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // FILTER BAR - Date (single/range), Centre, Variety
  // ========================================================================
  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Mode Chips
          Row(
            children: [
              _ModeChip(
                label: 'Single Date',
                selected: _filterMode == _DateFilterMode.single,
                onTap: () => _setFilterMode(_DateFilterMode.single),
              ),
              const SizedBox(width: 8),
              _ModeChip(
                label: 'Date Range',
                selected: _filterMode == _DateFilterMode.range,
                onTap: () => _setFilterMode(_DateFilterMode.range),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Centre + Variety Filter Dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCentreFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All Centres',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    isDense: true,
                    suffixIcon: _selectedCentreFilter != null
                        ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _clearCentreFilter,
                      padding: EdgeInsets.zero,
                    )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Centres'),
                    ),
                    ...ReportConstants.centres.map((centre) {
                      return DropdownMenuItem<String>(
                        value: centre,
                        child: Text(centre),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCentreFilter = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedVarietyFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All Varieties',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    isDense: true,
                    suffixIcon: _selectedVarietyFilter != null
                        ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _clearVarietyFilter,
                      padding: EdgeInsets.zero,
                    )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Varieties'),
                    ),
                    ...ReportConstants.varieties.map((variety) {
                      return DropdownMenuItem<String>(
                        value: variety,
                        child: Text(variety),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedVarietyFilter = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Date Picker
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openDatePicker,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDateFilterActive ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: _isDateFilterActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isDateFilterActive && _filterStartDate != null
                                ? (_filterMode == _DateFilterMode.single
                                ? _formatFilterDate(_filterStartDate!)
                                : '${_formatFilterDate(_filterStartDate!)} - ${_formatFilterDate(_filterEndDate!)}')
                                : (_filterMode == _DateFilterMode.single ? 'Select date' : 'Select date range'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _isDateFilterActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isDateFilterActive) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearDateFilter,
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF64748B),
                  tooltip: 'Clear date filter',
                ),
              ],
            ],
          ),
          // Active filters summary
          if (_isFilterActive) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_selectedCentreFilter != null)
                  _FilterChip(
                    label: 'Centre: $_selectedCentreFilter',
                    onPressed: _clearCentreFilter,
                  ),
                if (_selectedVarietyFilter != null)
                  _FilterChip(
                    label: 'Variety: $_selectedVarietyFilter',
                    onPressed: _clearVarietyFilter,
                  ),
                if (_isDateFilterActive)
                  _FilterChip(
                    label: _filterMode == _DateFilterMode.single
                        ? 'Date: ${_formatFilterDate(_filterStartDate!)}'
                        : '${_formatFilterDate(_filterStartDate!)} - ${_formatFilterDate(_filterEndDate!)}',
                    onPressed: _clearDateFilter,
                  ),
                _FilterChip(
                  label: 'Clear All',
                  onPressed: _clearAllFilters,
                  isClearAll: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isClearAll;

  const _FilterChip({
    required this.label,
    required this.onPressed,
    this.isClearAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isClearAll ? Colors.red.shade50 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClearAll ? Colors.red.shade200 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isClearAll ? Colors.red.shade700 : const Color(0xFF334155),
              fontWeight: isClearAll ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onPressed,
            child: Icon(
              Icons.close,
              size: 14,
              color: isClearAll ? Colors.red.shade700 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}