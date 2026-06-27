import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_assist/models/app_user.dart';
import '../models/transaction_model.dart';
import '../main.dart';

class StatsSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final List<String> selectedCards;
  final bool isAdmin;

  const StatsSection({
    super.key,
    required this.transactions,
    required this.selectedCards,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final total = transactions.fold<double>(0, (s, t) => s + t.amount);
    final fuelList = transactions.where((t) => t.isFuel).toList();
    final fuelTotal = fuelList.fold<double>(0, (s, t) => s + t.amount);
    final fuelCount = fuelList.length;

    // Entity totals
    final entity1Total = transactions
        .where((t) => t.assignedEntity == StaticUsers.users[0].entity)
        .fold<double>(0, (s, t) => s + t.amount);
    final entity2Total = transactions
        .where((t) => t.assignedEntity == StaticUsers.users[1].entity)
        .fold<double>(0, (s, t) => s + t.amount);
    final unassignedTotal = transactions
        .where((t) => t.assignedEntity == null)
        .fold<double>(0, (s, t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Row 1: Total + Fuel ──────────────────────────────────────
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

        // ── Row 2: Entity totals (admin only) ────────────────────────
        if (isAdmin) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Saadi Spend',
                  value: 'PKR ${fmt.format(entity1Total)}',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Daniel Spend',
                  value: 'PKR ${fmt.format(entity2Total)}',
                  icon: Icons.person_outline_rounded,
                  color: const Color(0xFFEC4899),
                ),
              ),
            ],
          ),
          if (unassignedTotal > 0) ...[
            const SizedBox(height: 10),
            _StatCard(
              label: 'Unassigned',
              value: 'PKR ${fmt.format(unassignedTotal)}',
              icon: Icons.help_outline_rounded,
              color: AppTheme.textHint,
            ),
          ],
        ],

        // ── Row 3: Per-card totals (dynamic) ─────────────────────────
        if (selectedCards.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _RowLabel('By Card'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: selectedCards.map((card) {
              final cardTotal = transactions
                  .where((t) => t.cardEnding == card)
                  .fold<double>(0, (s, t) => s + t.amount);
              final cardFuelTotal = transactions
                  .where((t) => t.cardEnding == card && t.isFuel)
                  .fold<double>(0, (s, t) => s + t.amount);
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 52) / 2,
                child: _CardStatCard(
                  cardEnding: card,
                  total: cardTotal,
                  fuelTotal: cardFuelTotal,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Single stat card ──────────────────────────────────────────────────────

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

// ── Per-card stat card with fuel breakdown ────────────────────────────────

class _CardStatCard extends StatelessWidget {
  final String cardEnding;
  final double total;
  final double fuelTotal;

  const _CardStatCard({
    required this.cardEnding,
    required this.total,
    required this.fuelTotal,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: AppTheme.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•••• $cardEnding',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MiniRow('Total', 'PKR ${fmt.format(total)}', AppTheme.accent),
          if (fuelTotal > 0)
            _MiniRow(
                'Fuel', 'PKR ${fmt.format(fuelTotal)}', AppTheme.fuelColor),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String text;
  const _RowLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
      letterSpacing: 0.4,
    ),
  );
}