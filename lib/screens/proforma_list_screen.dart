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
  // HELPER METHODS
  // ========================================================================

  String? _getProformaId(Map<String, dynamic> proforma) {
    return proforma['id']?.toString();
  }

  DateTime? _safeParseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  String _formatFilterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateRange(Map<String, dynamic> proforma) {
    final start = proforma['dateRangeStart']?.toString();
    final end = proforma['dateRangeEnd']?.toString();

    if (start != null && end != null) {
      final startDate = _safeParseDate(start);
      final endDate = _safeParseDate(end);
      if (startDate != null && endDate != null) {
        if (startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day) {
          return DateFormat('dd/MM/yyyy').format(startDate);
        }
        return '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}';
      }
    }
    return 'Multiple dates';
  }

  // ========================================================================
  // FILTER METHODS
  // ========================================================================

  void _applyFilters() {
    setState(() {
      _filteredProformas = _proformas.where((proforma) {
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

        if (_selectedCentreFilter != null && _selectedCentreFilter!.isNotEmpty) {
          final centre = proforma['centre']?.toString().toLowerCase() ?? '';
          if (centre != _selectedCentreFilter!.toLowerCase()) return false;
        }

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

  void _viewProforma(Map<String, dynamic> proforma) {
    final proformaId = proforma['id']?.toString();
    if (proformaId == null || proformaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid proforma data'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProformaViewScreen(
          proformaId: proformaId,
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
                final proformaId = _getProformaId(proforma) ?? '';
                final centre = proforma['centre'] ?? 'Unknown';
                final variety = proforma['variety'] ?? 'Unknown';
                final quantity = proforma['quantity'] ?? 0;
                final bales = proforma['bales'] ?? 0;
                final entryCount = proforma['entryCount'] ?? 0;

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
                      '$centre - $variety',
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
                          'Entries: $entryCount | Period: ${_formatDateRange(proforma)}',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Total Quantity: $quantity Quintals',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        Text(
                          'Total Bales: $bales',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: proformaId.isNotEmpty
                          ? () => _viewProforma(proforma)
                          : null,
                      tooltip: 'View Proforma',
                    ),
                    onTap: proformaId.isNotEmpty
                        ? () => _viewProforma(proforma)
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
  // FILTER BAR
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