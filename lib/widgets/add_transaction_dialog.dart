import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../main.dart';

class AddTransactionDialog extends StatefulWidget {
  const AddTransactionDialog({super.key});

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isFuel = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = context.read<AuthProvider>().currentUser!;
      await context.read<TransactionProvider>().addManualTransaction(
        merchant: _merchantCtrl.text.trim(),
        cardEnding: _cardCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.trim()),
        date: _selectedDate,
        isFuel: _isFuel,
        currentUser: user,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_card_rounded,
                        color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Transaction',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Manual entry',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // ── Merchant ───────────────────────────────────────────
              _FieldLabel('Merchant / Description'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _merchantCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Access Pharmacy',
                  prefixIcon: Icon(Icons.store_rounded,
                      color: AppTheme.textHint, size: 20),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? 'Enter merchant name' : null,
              ),
              const SizedBox(height: 16),

              // ── Amount ─────────────────────────────────────────────
              _FieldLabel('Amount (PKR)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  hintText: 'e.g. 45000',
                  prefixIcon: Icon(Icons.attach_money_rounded,
                      color: AppTheme.textHint, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Card ending ────────────────────────────────────────
              _FieldLabel('Card Last 4 Digits'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _cardCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  hintText: 'e.g. 2578',
                  prefixIcon: Icon(Icons.credit_card_rounded,
                      color: AppTheme.textHint, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter last 4 digits';
                  if (v.length != 4) return 'Must be exactly 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Date picker ────────────────────────────────────────
              _FieldLabel('Date'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppTheme.textHint, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textHint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Fuel toggle ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isFuel
                      ? AppTheme.fuelColor.withOpacity(0.07)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isFuel
                        ? AppTheme.fuelColor.withOpacity(0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_gas_station_rounded,
                      color: _isFuel
                          ? AppTheme.fuelColor
                          : AppTheme.textHint,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Fuel transaction',
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textPrimary),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: _isFuel,
                      onChanged: (v) => setState(() => _isFuel = v),
                      activeColor: AppTheme.fuelColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Add Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
      letterSpacing: 0.4,
    ),
  );
}