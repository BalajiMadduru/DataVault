import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../enums/report_type.dart';
import '../services/apiservice.dart';
import '../widgets/preview_dialog.dart';

/// Lists reports for a given type: 'purchase' | 'seed' | 'weightList'.
class ReportsListScreen extends StatefulWidget {
  final String reportType;

  const ReportsListScreen({super.key, required this.reportType});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

/// A group of purchase entries that share centre + date + reportNo.
class _PurchaseGroup {
  final String centre;
  final String date;
  final String reportNo;
  final List<Map<String, dynamic>> entries;

  _PurchaseGroup({
    required this.centre,
    required this.date,
    required this.reportNo,
    required this.entries,
  });

  /// Unique key used to identify this group.
  String get key => '$centre|$date|$reportNo';

  /// Comma-separated, sorted list of varieties present in this group.
  String get varietiesLabel {
    final vs = <String>{};
    for (final e in entries) {
      final v = (e['variety'] ?? '').toString().trim();
      if (v.isNotEmpty) vs.add(v);
    }
    final list = vs.toList()..sort();
    return list.join(', ');
  }

  /// The entry used as the base for the preview. We prefer one with the most
  /// populated factories list, falling back to the first entry.
  Map<String, dynamic> get primaryEntry {
    if (entries.isEmpty) return {};
    Map<String, dynamic> best = entries.first;
    int bestScore = _factoryCount(best);
    for (final e in entries.skip(1)) {
      final s = _factoryCount(e);
      if (s > bestScore) {
        best = e;
        bestScore = s;
      }
    }
    return best;
  }

  static int _factoryCount(Map<String, dynamic> e) {
    final f = e['factories'];
    if (f is List) return f.length;
    return 0;
  }

  /// Merge this group's entries into one preview-ready map.
  ///
  /// Strategy: start from the primary entry, then for every other entry in
  /// the group, inject its own-variety data into `otherVarietiesProgressive`
  /// so the preview can render all varieties side-by-side.
  Map<String, dynamic> toPreviewData() {
    final base = Map<String, dynamic>.from(primaryEntry);
    final primaryVariety =
    (base['variety'] ?? '').toString().trim().toLowerCase();

    final merged = <String, Map<String, dynamic>>{};

    final existing = base['otherVarietiesProgressive'];
    if (existing is Map) {
      existing.forEach((k, v) {
        if (v is Map) {
          merged[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    const copyFields = [
      'farmersDay',
      'arrivalsBales',
      'cciPurchaseQtls',
      'cciPurchaseBales',
      'avgKapasRate',
      'moisture',
      'budgetedLint',
      'budgetedShortage',
      'cottonSeedPct',
      'cottonSeedRate',
      'processingCycle',
      'proformaExpenses',
      'budgetedPadtha',
      'dayPressedBales',
      'marketHighestRate',
      'marketLowestRate',
      'cciHighestRate',
      'cciLowestRate',
      'progPressedBales',
      'progPurchaseQtls',
      'progPurchaseBales',
      'progFarmers',
      'factories',
    ];

    for (final e in entries) {
      final vRaw = (e['variety'] ?? '').toString().trim();
      if (vRaw.isEmpty) continue;
      if (vRaw.toLowerCase() == primaryVariety) continue;

      // Use the raw variety (as stored) so the preview lookup `_v()` still
      // finds it — but the preview's `_varieties` list is fixed to
      // ['BB MOD', 'BB SPL MOD', 'MECH'], so case-insensitive matching
      // only matters when the typed casing differs from those.
      final bucket = merged.putIfAbsent(vRaw, () => <String, dynamic>{});
      for (final f in copyFields) {
        if (e.containsKey(f)) bucket[f] = e[f];
      }
    }

    base['otherVarietiesProgressive'] = merged;
    return base;
  }
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  List<Map<String, dynamic>> _items = [];
  List<_PurchaseGroup> _purchaseGroups = [];
  bool _isLoading = true;
  String? _error;
  String? _deletingId;

  bool get _isPurchase => widget.reportType == 'purchase';

  String get _title {
    switch (widget.reportType) {
      case 'purchase':
        return 'Purchase Reports';
      case 'seed':
        return 'Seed Reports';
      case 'weightList':
        return 'Weight List Reports';
      default:
        return 'Reports';
    }
  }

  ReportType get _reportTypeEnum {
    switch (widget.reportType) {
      case 'purchase':
        return ReportType.dailyPurchase;
      case 'seed':
        return ReportType.dailySeed;
      case 'weightList':
        return ReportType.weightList;
      default:
        return ReportType.dailyPurchase;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _fetch();
    if (!mounted) return;

    setState(() {
      _items = result.items;
      _error = result.error;
      _purchaseGroups = _isPurchase ? _groupPurchases(result.items) : [];
      _isLoading = false;
    });
  }

  Future<({List<Map<String, dynamic>> items, String? error})> _fetch() async {
    ApiResponse response;
    switch (widget.reportType) {
      case 'purchase':
        response = await ApiService.getPurchaseEntries();
        break;
      case 'seed':
        response = await ApiService.getSeedEntries();
        break;
      case 'weightList':
        response = await ApiService.getWeightListEntries();
        break;
      default:
        return (
        items: <Map<String, dynamic>>[],
        error: '$_title are not connected to the API yet.'
        );
    }

    if (response.success && response.data != null) {
      final list = (response.data!['entries'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return (items: list, error: null);
    }
    return (items: <Map<String, dynamic>>[], error: response.message);
  }

  // ------------------------------------------------------------
  // GROUPING (purchase only)
  // ------------------------------------------------------------

  List<_PurchaseGroup> _groupPurchases(List<Map<String, dynamic>> items) {
    final map = <String, _PurchaseGroup>{};

    for (final e in items) {
      final centre = (e['centre'] ?? '').toString();
      final dateRaw = e['date']?.toString() ?? '';
      final dateKey = _normalizeDateKey(dateRaw);
      final reportNo = (e['reportNo'] ?? '').toString();
      final variety = (e['variety'] ?? '').toString().trim();

      // Case-insensitive key so varieties typed with different casing
      // (e.g. "bb mod" vs "BB MOD") collapse into a single report group.
      final key =
          '${centre.trim().toLowerCase()}|$dateKey|$reportNo|${variety.toLowerCase()}';

      final g = map.putIfAbsent(
        key,
            () => _PurchaseGroup(
          centre: centre,
          date: dateRaw,
          reportNo: reportNo,
          entries: [],
        ),
      );
      g.entries.add(e);
    }

    final groups = map.values.toList();

    // Newest first (by date, then report no).
    groups.sort((a, b) {
      final da = DateTime.tryParse(a.date);
      final db = DateTime.tryParse(b.date);
      if (da != null && db != null && da != db) return db.compareTo(da);
      final ra = int.tryParse(a.reportNo) ?? 0;
      final rb = int.tryParse(b.reportNo) ?? 0;
      return rb.compareTo(ra);
    });

    return groups;
  }

  String _normalizeDateKey(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.year}-${d.month}-${d.day}';
  }

  // ------------------------------------------------------------
  // FORMAT HELPERS
  // ------------------------------------------------------------

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  // ------------------------------------------------------------
  // OPEN PREVIEW
  // ------------------------------------------------------------

  void _openPreview(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (_) => PreviewDialog(
        type: _reportTypeEnum,
        data: entry,
      ),
    );
  }

  void _openPurchaseGroup(_PurchaseGroup g) {
    showDialog(
      context: context,
      builder: (_) => PreviewDialog(
        type: ReportType.dailyPurchase,
        data: g.toPreviewData(),
      ),
    );
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------

  Future<void> _confirmAndDelete(Map<String, dynamic> e) async {
    final id = (e['id'] ?? e['_id'])?.toString();
    if (id == null || id.isEmpty) return;

    final centre = (e['centre'] ?? '—').toString();
    final variety = (e['variety'] ?? '').toString();
    final date = _fmtDate(e['date']);
    final reportNo = (e['reportNo'] ?? '').toString();

    final label = [
      if (centre.isNotEmpty) centre,
      if (variety.isNotEmpty) variety,
      if (reportNo.isNotEmpty) 'Report No: $reportNo',
      if (date.isNotEmpty) date,
    ].join('  •  ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildDeleteDialog(
        title: 'Delete Report',
        message:
        'This will permanently delete the report below. This action cannot be undone.',
        label: label,
        extraNote: widget.reportType == 'purchase'
            ? 'Any proforma entry linked to this purchase will also be removed.'
            : null,
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = id);

    final ApiResponse response;
    if (widget.reportType == 'weightList') {
      response = await ApiService.deleteWeightListEntry(id);
    } else {
      response = await ApiService.deleteEntry(id);
    }

    if (!mounted) return;

    setState(() => _deletingId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.success
            ? 'Report deleted'
            : 'Delete failed: ${response.message}'),
        backgroundColor: response.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    if (response.success) _load();
  }

  /// Delete an entire purchase group — all entries sharing centre+date+reportNo.
  Future<void> _confirmAndDeleteGroup(_PurchaseGroup g) async {
    final ids = <String>[];
    for (final e in g.entries) {
      final id = (e['id'] ?? e['_id'])?.toString();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return;

    final varietyCount = g.entries.length;
    final varietyNames = g.varietiesLabel.isEmpty ? '—' : g.varietiesLabel;

    final label = [
      if (g.centre.isNotEmpty) g.centre,
      if (g.reportNo.isNotEmpty) 'Report No: ${g.reportNo}',
      if (_fmtDate(g.date).isNotEmpty) _fmtDate(g.date),
      'Varieties: $varietyNames',
    ].join('  •  ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildDeleteDialog(
        title: 'Delete Report',
        message:
        'This will permanently delete the report and all $varietyCount '
            'variety entr${varietyCount == 1 ? 'y' : 'ies'} in it. '
            'This action cannot be undone.',
        label: label,
        extraNote:
        'Any proforma entries linked to these purchases will also be removed.',
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = g.key);
    String? failure;

    for (final id in ids) {
      final res = await ApiService.deleteEntry(id);
      if (!res.success) {
        failure = res.message;
        break;
      }
    }

    if (!mounted) return;

    setState(() => _deletingId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure ?? 'Report deleted'),
        backgroundColor: failure == null ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    if (failure == null) _load();
  }

  Widget _buildDeleteDialog({
    required String title,
    required String message,
    required String label,
    String? extraNote,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade700, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (extraNote != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    extraNote,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Delete',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(_error!)
          : _isPurchase
          ? _buildPurchaseList()
          : _buildSimpleList(),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(msg, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PURCHASE — grouped list
  // ------------------------------------------------------------

  Widget _buildPurchaseList() {
    if (_purchaseGroups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No reports found.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _purchaseGroups.length,
      itemBuilder: (context, index) {
        final g = _purchaseGroups[index];
        final isDeleting = _deletingId == g.key;
        final varietyLabel = g.varietiesLabel;
        final dateStr = _fmtDate(g.date);

        final subtitleParts = <String>[
          if (dateStr.isNotEmpty) dateStr,
          if (varietyLabel.isNotEmpty) varietyLabel,
        ];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child:
              Icon(Icons.description_outlined, color: Color(0xFF0F172A)),
            ),
            title: Text(
              g.centre.isEmpty
                  ? 'Report No: ${g.reportNo}'
                  : '${g.centre} — Report No: ${g.reportNo}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: subtitleParts.isEmpty
                ? null
                : Text(
              subtitleParts.join('  •  '),
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDeleting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _confirmAndDeleteGroup(g),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: isDeleting ? null : () => _openPurchaseGroup(g),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // SEED + WEIGHT LIST — one card per entry (unchanged)
  // ------------------------------------------------------------

  Widget _buildSimpleList() {
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No reports found.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final e = _items[index];
        final centre = (e['centre'] ?? '—').toString();
        final variety = (e['variety'] ?? '').toString();
        final date = _fmtDate(e['date']);
        final id = (e['id'] ?? e['_id'])?.toString();
        final reportNo = (e['reportNo'] ?? '').toString();

        final isDeleting = id != null && id == _deletingId;

        final subtitleParts = <String>[
          if (date.isNotEmpty) date,
          if (reportNo.isNotEmpty) 'Report No: $reportNo',
        ];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: widget.reportType == 'weightList'
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFD1FAE5),
              child: Icon(
                widget.reportType == 'weightList'
                    ? Icons.scale_rounded
                    : Icons.eco_rounded,
                color: const Color(0xFF0F172A),
              ),
            ),
            title: Text(
              variety.isEmpty ? centre : '$centre — $variety',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: subtitleParts.isEmpty
                ? null
                : Text(
              subtitleParts.join('  •  '),
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDeleting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _confirmAndDelete(e),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: isDeleting ? null : () => _openPreview(e),
          ),
        );
      },
    );
  }
}