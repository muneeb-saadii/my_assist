import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../main.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel tx;
  final String currentUserId;
  final bool isOnline;
  final VoidCallback onAssignToggle;
  final VoidCallback onTap;

  const TransactionTile({
    super.key,
    required this.tx,
    required this.currentUserId,
    required this.isOnline,
    required this.onAssignToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAssigned = tx.assignedTo == currentUserId;
    final fmt = NumberFormat('#,##0.00');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAssigned
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.divider,
          ),
        ),
        child: Row(
          children: [
            // ── Icon ────────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tx.isFuel
                    ? AppTheme.fuelColor.withOpacity(0.12)
                    : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                tx.isFuel
                    ? Icons.local_gas_station_rounded
                    : Icons.shopping_bag_rounded,
                color: tx.isFuel ? AppTheme.fuelColor : AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // ── Description + meta ───────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (tx.isManual)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Manual',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          tx.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '•••• ${tx.cardEnding}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM').format(tx.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textHint,
                        ),
                      ),
                      if (tx.assignedEntity != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tx.assignedEntity!,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Amount + assign button ───────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PKR ${fmt.format(tx.amount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: isOnline ? onAssignToggle : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isAssigned
                          ? AppTheme.primary.withOpacity(0.12)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAssigned ? 'Mine ✓' : 'Assign me',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isAssigned
                            ? AppTheme.primary
                            : isOnline
                                ? AppTheme.textHint
                                : AppTheme.divider,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
