import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../main.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/transaction_detail_dialog.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/stats_section.dart';
import '../widgets/toggle_row.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().listenToFirebase();
    });
  }

  Future<void> _sync() async {
    final user = context.read<AuthProvider>().currentUser!;
    await context.read<TransactionProvider>().syncFromSms(user);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<TransactionProvider>();
    final user = auth.currentUser!;
    final filtered = provider.getFiltered(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits'),
        actions: [
          if (provider.syncStatus == SyncStatus.syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                provider.syncStatus == SyncStatus.offline
                    ? Icons.wifi_off_rounded
                    : Icons.sync_rounded,
                color: provider.syncStatus == SyncStatus.offline
                    ? AppTheme.error
                    : AppTheme.primary,
              ),
              onPressed: _sync,
              tooltip: 'Sync from SMS (14250)',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Offline warning banner ──────────────────────────────────
          if (!provider.isOnline)
            Container(
              width: double.infinity,
              color: AppTheme.warning.withOpacity(0.12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      color: AppTheme.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline — showing cached data. Assign me is disabled.',
                      style:
                          TextStyle(color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Interval filter ───────────────────────────────────
                _SectionLabel('Interval'),
                const SizedBox(height: 8),
                ToggleRow(
                  options: const ['All', 'Last', 'Current'],
                  selected: provider.intervalFilter.index,
                  onSelect: (i) => provider
                      .setIntervalFilter(IntervalFilter.values[i]),
                ),
                const SizedBox(height: 16),

                // ── Entity filter (admin only) ────────────────────────
                if (user.isAdmin) ...[
                  _SectionLabel('Entity'),
                  const SizedBox(height: 8),
                  ToggleRow(
                    options: const ['All', 'Entity1', 'Entity2'],
                    selected: ['all', 'Entity1', 'Entity2']
                        .indexOf(provider.selectedEntity)
                        .clamp(0, 2),
                    onSelect: (i) => provider
                        .setEntity(['all', 'Entity1', 'Entity2'][i]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Card checkboxes ───────────────────────────────────
                if (provider.availableCards.isNotEmpty) ...[
                  _SectionLabel('Cards'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: provider.availableCards.map((card) {
                      final selected =
                          provider.selectedCards.contains(card);
                      return FilterChip(
                        label: Text('•••• $card'),
                        selected: selected,
                        onSelected: (_) => provider.toggleCard(card),
                        selectedColor:
                            AppTheme.primary.withOpacity(0.15),
                        checkmarkColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.divider,
                        ),
                        backgroundColor: AppTheme.surface,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Stats cards ───────────────────────────────────────
                StatsSection(
                  transactions: filtered,
                  selectedCards: provider.availableCards
                      .where((c) => provider.selectedCards.contains(c))
                      .toList(),
                  isAdmin: user.isAdmin,   // ← add this
                ),
                const SizedBox(height: 16),

                // ── Transaction list ──────────────────────────────────
                // ── Transactions header with add + sort ───────────────
                Row(
                  children: [
                    Expanded(
                      child: _SectionLabel('Transactions (${filtered.length})'),
                    ),
                    // Sort field toggle
                    GestureDetector(
                      onTap: () {
                        final current = provider.sortField;
                        provider.setSortField(
                          current == SortField.date ? SortField.amount : SortField.date,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              provider.sortField == SortField.date
                                  ? Icons.calendar_today_rounded
                                  : Icons.attach_money_rounded,
                              size: 13,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              provider.sortField == SortField.date ? 'Date' : 'Amount',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Sort order toggle
                    GestureDetector(
                      onTap: () => provider.toggleSortOrder(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          provider.sortOrder == SortOrder.desc
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Add manual transaction button
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => const AddTransactionDialog(),
                      ),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: AppTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No transactions found',
                        style: TextStyle(color: AppTheme.textHint),
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (tx) => TransactionTile(
                      tx: tx,
                      currentUserId: user.id,
                      isOnline: provider.isOnline,
                      onAssignToggle: () =>
                          provider.toggleAssign(tx, user),
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => TransactionDetailDialog(
                          tx: tx,
                          user: user,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      );
}
