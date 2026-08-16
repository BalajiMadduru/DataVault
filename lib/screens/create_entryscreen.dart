import 'package:flutter/material.dart';
import '../enums/report_type.dart';

class CreateEntryScreen extends StatefulWidget {
  final ReportType type;
  const CreateEntryScreen({super.key, required this.type});

  @override
  State<CreateEntryScreen> createState() => _CreateEntryScreenState();
}

class _CreateEntryScreenState extends State<CreateEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();

  final List<String> _varieties = const [
    'BB MOD',
    'Variety B',
    'Variety C',
    'Variety D',
  ];
  String? _selectedVariety;

  bool _isSaving = false;

  bool get _isSeed => widget.type == ReportType.seedPurchase;

  @override
  void initState() {
    super.initState();
    _selectedVariety = _varieties.first;
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      _dateController.text =
      '${_twoDigits(picked.day)}/${_twoDigits(picked.month)}/${picked.year}';
    }
  }

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Purchase date is required';
    }
    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(value.trim())) {
      return 'Use format dd/mm/yyyy';
    }
    return null;
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVariety == null) return;

    setState(() => _isSaving = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_isSeed ? "Seed purchase" : "Purchase"} entry created'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isSeed ? 'New Seed Purchase' : 'New Purchase Entry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Purchase Date'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _dateController,
                keyboardType: TextInputType.datetime,
                validator: _validateDate,
                decoration: _inputDecoration(
                  hint: 'dd/mm/yyyy',
                  icon: Icons.event_outlined,
                  suffix: IconButton(
                    icon: const Icon(Icons.calendar_month_rounded,
                        size: 20, color: Color(0xFF94A3B8)),
                    onPressed: _pickDate,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Variety'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedVariety,
                items: _varieties
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVariety = v),
                validator: (v) => v == null ? 'Variety is required' : null,
                decoration: _inputDecoration(
                  hint: 'Select variety',
                  icon: Icons.eco_outlined,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Create',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }
}