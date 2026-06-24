import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../main.dart';

class StatsSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final List<String> selectedCards;

  const StatsSection({
    super.key,
    required this.transactions,
    required this.selectedCards,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final total =
        transactions.fold<double>(0, (s, t) => s + t.amount);
    final fuelList = transactions.where((t) => t.isFuel).toList();
    final fuelTotal =
        fuelList.fold<double>(0, (s, t) => s + t.amount);
    final fuelCount = fuelList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1 — total + fuel
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Spend',
                value: 'PKR ${fmt.format(total)}',
                icon: Icons.account_balance_wallet_rounded,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Fuel ($fuelCount txns)',
                value: 'PKR ${fmt.format(fuelTotal)}',
                icon: Icons.local_gas_station_rounded,
                color: AppTheme.fuelColor,
              ),
            ),
          ],
        ),

        // Row 2 — per-card totals (dynamic)
        if (selectedCards.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: selectedCards.map((card) {
              final cardTotal = transactions
                  .where((t) => t.cardEnding == card)
                  .fold<double>(0, (s, t) => s + t.amount);
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 52) / 2,
                child: _StatCard(
                  label: 'Card •••• $card',
                  value: 'PKR ${fmt.format(cardTotal)}',
                  icon: Icons.credit_card_rounded,
                  color: AppTheme.accent,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
