import 'dart:async';
import 'package:flutter/material.dart' hide debugPrint;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';
import '../models/app_user.dart';
import '../utils/sms_parser.dart';

enum IntervalFilter { all, last, current }
enum SyncStatus { idle, syncing, synced, offline, error }
enum SortField { date, amount }
enum SortOrder { asc, desc }

class TransactionProvider extends ChangeNotifier {
  final _db = FirebaseDatabase.instance.ref('transactions');

  List<TransactionModel> _allTransactions = [];
  List<String> _availableCards = [];
  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.idle;

  IntervalFilter _intervalFilter = IntervalFilter.current;
  Set<String> _selectedCards = {};
  String _selectedEntity = 'all';

  List<TransactionModel> get allTransactions => _allTransactions;
  List<String> get availableCards => _availableCards;
  bool get isOnline => _isOnline;
  SyncStatus get syncStatus => _syncStatus;
  IntervalFilter get intervalFilter => _intervalFilter;
  Set<String> get selectedCards => _selectedCards;
  String get selectedEntity => _selectedEntity;

  final _manualDb = FirebaseDatabase.instance.ref('manual_transactions');
  SortField _sortField = SortField.date;
  SortOrder _sortOrder = SortOrder.desc;

  SortField get sortField => _sortField;
  SortOrder get sortOrder => _sortOrder;

  void setSortField(SortField f) { _sortField = f; notifyListeners(); }
  void setSortOrder(SortOrder o) { _sortOrder = o; notifyListeners(); }
  void toggleSortOrder() {
    _sortOrder = _sortOrder == SortOrder.desc ? SortOrder.asc : SortOrder.desc;
    notifyListeners();
  }

  void setIntervalFilter(IntervalFilter f) {
    _intervalFilter = f;
    notifyListeners();
  }

  void setSelectedCards(Set<String> cards) {
    _selectedCards = Set.from(cards);
    notifyListeners();
  }

  void toggleCard(String card) {
    if (_selectedCards.contains(card)) {
      _selectedCards.remove(card);
    } else {
      _selectedCards.add(card);
    }
    notifyListeners();
  }

  void setEntity(String entity) {
    _selectedEntity = entity;
    notifyListeners();
  }

  List<TransactionModel> getFiltered(AppUser currentUser) {
    var list = List<TransactionModel>.from(_allTransactions);

    if (!currentUser.isAdmin) {
      list = list
          .where((t) => t.assignedTo == null || t.assignedTo == currentUser.id)
          .toList();
    } else {
      if (_selectedEntity != 'all') {
        list = list.where((t) => t.assignedEntity == _selectedEntity).toList();
      }
    }

    if (_selectedCards.isNotEmpty) {
      list = list.where((t) => _selectedCards.contains(t.cardEnding)).toList();
    }

    final now = DateTime.now();
    if (_intervalFilter == IntervalFilter.current) {
      // Current: from most recent 20th up to today
      final from = now.day >= 20
          ? DateTime(now.year, now.month, 20)
          : DateTime(now.year, now.month - 1, 20);
      list = list.where((t) => !t.date.isBefore(from)).toList();
    } else if (_intervalFilter == IntervalFilter.last) {
      // Last: from second-last 20th up to last 20th (exclusive)
      final DateTime lastCutoff;
      final DateTime prevCutoff;
      if (now.day >= 20) {
        // e.g. today is 24 Jun → current starts 20 Jun, last is 20 May–20 Jun
        lastCutoff = DateTime(now.year, now.month, 20);
        prevCutoff = DateTime(now.year, now.month - 1, 20);
      } else {
        // e.g. today is 10 Jun → current starts 20 May, last is 20 Apr–20 May
        lastCutoff = DateTime(now.year, now.month - 1, 20);
        prevCutoff = DateTime(now.year, now.month - 2, 20);
      }
      list = list
          .where((t) =>
      !t.date.isBefore(prevCutoff) && t.date.isBefore(lastCutoff))
          .toList();
    }
    // IntervalFilter.all — no date restriction
    /*final now = DateTime.now();
    if (_intervalFilter == IntervalFilter.current) {
      final from = now.day >= 20
          ? DateTime(now.year, now.month, 20)
          : DateTime(now.year, now.month - 1, 20);
      list = list.where((t) => t.date.isAfter(from)).toList();
    } else if (_intervalFilter == IntervalFilter.last) {
      final twoMonthsCutoff = DateTime(now.year, now.month - 2, 20);
      final lastMonthCutoff = DateTime(now.year, now.month - 1, 20);
      list = list
          .where((t) =>
      t.date.isAfter(twoMonthsCutoff) &&
          t.date.isBefore(lastMonthCutoff))
          .toList();
    }*/

    // list.sort((a, b) => b.date.compareTo(a.date));
    list.sort((a, b) {
      int cmp;
      if (_sortField == SortField.date) {
        cmp = a.date.compareTo(b.date);
      } else {
        cmp = a.amount.compareTo(b.amount);
      }
      return _sortOrder == SortOrder.desc ? -cmp : cmp;
    });
    return list;
  }

  double getTotalAmount(List<TransactionModel> list) =>
      list.fold(0, (sum, t) => sum + t.amount);

  double getCardTotal(List<TransactionModel> list, String cardEnding) =>
      list
          .where((t) => t.cardEnding == cardEnding)
          .fold(0, (sum, t) => sum + t.amount);

  int getFuelCount(List<TransactionModel> list) =>
      list.where((t) => t.isFuel).length;

  double getFuelTotal(List<TransactionModel> list) =>
      list.where((t) => t.isFuel).fold(0, (sum, t) => sum + t.amount);

  // ── SMS Sync using flutter_sms_inbox ─────────────────────────────────
  Future<void> syncFromSms(AppUser currentUser) async {
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    try {
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        _syncStatus = SyncStatus.error;
        notifyListeners();
        return;
      }

      final query = SmsQuery();
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        address: '14250',
        count: 500,
      );

      final parsed = <TransactionModel>[];
      for (final msg in messages) {
        final body = msg.body ?? '';
        if (!body.toLowerCase().contains('creditcard')) continue;
        final tx = SmsParser.parse(
          body,
          msg.date?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
        );
        if (tx != null) parsed.add(tx);
      }

      if (parsed.isEmpty) {
        _syncStatus = SyncStatus.synced;
        notifyListeners();
        return;
      }

      // Fetch existing IDs to avoid overwriting already-assigned transactions
      final snapshot = await _db.get();
      final existingIds = <String>{};
      if (snapshot.exists && snapshot.value != null) {
        final map = snapshot.value as Map<dynamic, dynamic>;
        existingIds.addAll(map.keys.map((k) => k.toString()));
      }

      int newCount = 0;
      for (final tx in parsed) {
        if (existingIds.contains(tx.id)) {
          // Already exists — preserve existing assignment
          continue;
        }

        // New transaction — auto-assign to whoever is currently syncing
        final assigned = tx.copyWith(
          assignedTo: currentUser.id,
          assignedEntity: currentUser.entity,
        );
        await _db.child(assigned.id).set(assigned.toMap());
        newCount++;
      }

      debugPrint('Sync complete: $newCount new, ${parsed.length - newCount} skipped (user: ${currentUser.entity})');
      _isOnline = true;
      _syncStatus = SyncStatus.synced;
    } catch (e) {
      _isOnline = false;
      _syncStatus = SyncStatus.offline;
      debugPrint('SMS sync error: $e');
    }

    notifyListeners();
  }

  // ── Firebase real-time listener ───────────────────────────────────────

  StreamSubscription? _sub;
  StreamSubscription? _manualSub;

  void listenToFirebase() {
    _sub?.cancel();
    _manualSub?.cancel();

    // Listen to SMS transactions
    _sub = _db.onValue.listen(
          (event) {
        final data = event.snapshot.value;
        _smsTransactions = data == null
            ? []
            : (data as Map<dynamic, dynamic>)
            .entries
            .map((e) => TransactionModel.fromMap(
            e.key.toString(), e.value as Map<dynamic, dynamic>))
            .toList();
        _mergeAndNotify();
      },
      onError: (_) {
        _isOnline = false;
        _syncStatus = SyncStatus.offline;
        notifyListeners();
      },
    );

    // Listen to manual transactions
    _manualSub = _manualDb.onValue.listen(
          (event) {
        final data = event.snapshot.value;
        _manualTransactions = data == null
            ? []
            : (data as Map<dynamic, dynamic>)
            .entries
            .map((e) => TransactionModel.fromMap(
            e.key.toString(), e.value as Map<dynamic, dynamic>))
            .toList();
        _mergeAndNotify();
      },
    );
  }

  List<TransactionModel> _smsTransactions = [];
  List<TransactionModel> _manualTransactions = [];

  void _mergeAndNotify() {
    _allTransactions = [..._smsTransactions, ..._manualTransactions];
    _availableCards = _allTransactions
        .map((t) => t.cardEnding)
        .toSet()
        .toList()
      ..sort();
    if (_selectedCards.isEmpty && _availableCards.isNotEmpty) {
      _selectedCards = Set.from(_availableCards);
    }
    _isOnline = true;
    notifyListeners();
  }


  Future<void> toggleAssign(TransactionModel tx, AppUser user) async {
    final isAssigned = tx.assignedTo == user.id;
    await _db.child(tx.id).update({
      'assignedTo': isAssigned ? null : user.id,
      'assignedEntity': isAssigned ? null : user.entity,
    });
  }

  Future<void> addManualTransaction({
    required String merchant,
    required String cardEnding,
    required double amount,
    required DateTime date,
    required bool isFuel,
    required AppUser currentUser,
  }) async {
    final id = 'manual_${currentUser.id}_${date.millisecondsSinceEpoch}_${amount.toInt()}';
    final desc = merchant.length > 30 ? '${merchant.substring(0, 30)}...' : merchant;

    final tx = TransactionModel(
      id: id,
      rawMessage: '[Manual Entry]',
      description: desc,
      cardEnding: cardEnding,
      amount: amount,
      date: date,
      merchant: merchant,
      isFuel: isFuel,
      isManual: true,
      assignedTo: currentUser.id,
      assignedEntity: currentUser.entity,
    );

    await _manualDb.child(id).set(tx.toMap());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _manualSub?.cancel();
    super.dispose();
  }
}

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:telephony/telephony.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../models/transaction_model.dart';
// import '../models/app_user.dart';
// import '../utils/sms_parser.dart';
//
// enum IntervalFilter { all, last, current }
//
// enum SyncStatus { idle, syncing, synced, offline, error }
//
// class TransactionProvider extends ChangeNotifier {
//   final _db = FirebaseDatabase.instance.ref('transactions');
//   final _telephony = Telephony.instance;
//
//   List<TransactionModel> _allTransactions = [];
//   List<String> _availableCards = [];
//   bool _isOnline = true;
//   SyncStatus _syncStatus = SyncStatus.idle;
//
//   // Active filters
//   IntervalFilter _intervalFilter = IntervalFilter.current;
//   Set<String> _selectedCards = {};
//   String _selectedEntity = 'all';
//
//   // ── Getters ───────────────────────────────────────────────────────────
//
//   List<TransactionModel> get allTransactions => _allTransactions;
//   List<String> get availableCards => _availableCards;
//   bool get isOnline => _isOnline;
//   SyncStatus get syncStatus => _syncStatus;
//   IntervalFilter get intervalFilter => _intervalFilter;
//   Set<String> get selectedCards => _selectedCards;
//   String get selectedEntity => _selectedEntity;
//
//   // ── Filter setters ────────────────────────────────────────────────────
//
//   void setIntervalFilter(IntervalFilter f) {
//     _intervalFilter = f;
//     notifyListeners();
//   }
//
//   void setSelectedCards(Set<String> cards) {
//     _selectedCards = Set.from(cards);
//     notifyListeners();
//   }
//
//   void toggleCard(String card) {
//     if (_selectedCards.contains(card)) {
//       _selectedCards.remove(card);
//     } else {
//       _selectedCards.add(card);
//     }
//     notifyListeners();
//   }
//
//   void setEntity(String entity) {
//     _selectedEntity = entity;
//     notifyListeners();
//   }
//
//   // ── Filtered transactions ─────────────────────────────────────────────
//
//   List<TransactionModel> getFiltered(AppUser currentUser) {
//     var list = List<TransactionModel>.from(_allTransactions);
//
//     // Non-admin sees only their own assigned transactions
//     if (!currentUser.isAdmin) {
//       list = list
//           .where((t) => t.assignedTo == null || t.assignedTo == currentUser.id)
//           .toList();
//     } else {
//       // Admin entity filter
//       if (_selectedEntity != 'all') {
//         list = list
//             .where((t) => t.assignedEntity == _selectedEntity)
//             .toList();
//       }
//     }
//
//     // Card filter
//     if (_selectedCards.isNotEmpty) {
//       list = list.where((t) => _selectedCards.contains(t.cardEnding)).toList();
//     }
//
//     // Interval filter
//     final now = DateTime.now();
//     if (_intervalFilter == IntervalFilter.current) {
//       final cutoffDay = 20;
//       final from = now.day >= cutoffDay
//           ? DateTime(now.year, now.month, cutoffDay)
//           : DateTime(now.year, now.month - 1, cutoffDay);
//       list = list.where((t) => t.date.isAfter(from)).toList();
//     } else if (_intervalFilter == IntervalFilter.last) {
//       final twoMonthsCutoff = DateTime(now.year, now.month - 2, 20);
//       final lastMonthCutoff = DateTime(now.year, now.month - 1, 20);
//       list = list
//           .where((t) =>
//               t.date.isAfter(twoMonthsCutoff) &&
//               t.date.isBefore(lastMonthCutoff))
//           .toList();
//     }
//     // IntervalFilter.all — no date restriction
//
//     list.sort((a, b) => b.date.compareTo(a.date));
//     return list;
//   }
//
//   // ── Stats helpers ─────────────────────────────────────────────────────
//
//   double getTotalAmount(List<TransactionModel> list) =>
//       list.fold(0, (sum, t) => sum + t.amount);
//
//   double getCardTotal(List<TransactionModel> list, String cardEnding) =>
//       list
//           .where((t) => t.cardEnding == cardEnding)
//           .fold(0, (sum, t) => sum + t.amount);
//
//   int getFuelCount(List<TransactionModel> list) =>
//       list.where((t) => t.isFuel).length;
//
//   double getFuelTotal(List<TransactionModel> list) =>
//       list.where((t) => t.isFuel).fold(0, (sum, t) => sum + t.amount);
//
//   // ── SMS sync ──────────────────────────────────────────────────────────
//
//   Future<void> syncFromSms() async {
//     _syncStatus = SyncStatus.syncing;
//     notifyListeners();
//
//     try {
//       final status = await Permission.sms.request();
//       if (!status.isGranted) {
//         _syncStatus = SyncStatus.error;
//         notifyListeners();
//         return;
//       }
//
//       final messages = await _telephony.getInboxSms(
//         addressFilter: SmsFilter.where(SmsColumn.ADDRESS).equals('14250'),
//         columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
//       );
//
//       final parsed = <TransactionModel>[];
//       for (final msg in messages) {
//         final body = msg.body ?? '';
//         if (!body.toLowerCase().contains('creditcard')) continue;
//         final tx = SmsParser.parse(body, msg.date ?? 0);
//         if (tx != null) parsed.add(tx);
//       }
//
//       // Upload to Firebase — uses transaction ID as key to prevent duplicates
//       for (final tx in parsed) {
//         await _db.child(tx.id).set(tx.toMap());
//       }
//
//       _isOnline = true;
//       _syncStatus = SyncStatus.synced;
//     } catch (e) {
//       _isOnline = false;
//       _syncStatus = SyncStatus.offline;
//       debugPrint('SMS sync error: $e');
//     }
//
//     notifyListeners();
//   }
//
//   // ── Firebase real-time listener ───────────────────────────────────────
//
//   StreamSubscription? _sub;
//
//   void listenToFirebase() {
//     _sub?.cancel();
//     _sub = _db.onValue.listen(
//       (event) {
//         final data = event.snapshot.value;
//         if (data == null) {
//           _allTransactions = [];
//           notifyListeners();
//           return;
//         }
//
//         final map = data as Map<dynamic, dynamic>;
//         _allTransactions = map.entries
//             .map((e) => TransactionModel.fromMap(
//                 e.key.toString(), e.value as Map<dynamic, dynamic>))
//             .toList();
//
//         _availableCards = _allTransactions
//             .map((t) => t.cardEnding)
//             .toSet()
//             .toList()
//           ..sort();
//
//         // Auto-select all cards on first load
//         if (_selectedCards.isEmpty && _availableCards.isNotEmpty) {
//           _selectedCards = Set.from(_availableCards);
//         }
//
//         _isOnline = true;
//         notifyListeners();
//       },
//       onError: (e) {
//         _isOnline = false;
//         _syncStatus = SyncStatus.offline;
//         // debugPrint('Firebase listen error: $e');
//         notifyListeners();
//       },
//     );
//   }
//
//   // ── Assign me toggle ──────────────────────────────────────────────────
//
//   Future<void> toggleAssign(TransactionModel tx, AppUser user) async {
//     final isAssigned = tx.assignedTo == user.id;
//     await _db.child(tx.id).update({
//       'assignedTo': isAssigned ? null : user.id,
//       'assignedEntity': isAssigned ? null : user.entity,
//     });
//   }
//
//   @override
//   void dispose() {
//     _sub?.cancel();
//     super.dispose();
//   }
// }