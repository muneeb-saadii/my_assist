import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';
import '../models/app_user.dart';
import '../utils/sms_parser.dart';

enum IntervalFilter { all, last, current }
enum SyncStatus { idle, syncing, synced, offline, error }

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
    }

    list.sort((a, b) => b.date.compareTo(a.date));
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

  Future<void> syncFromSms() async {
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
        address: '14250',         // sender filter
        count: 500,               // fetch up to 500 messages
      );

      final parsed = <TransactionModel>[];
      for (final msg in messages) {
        final body = msg.body ?? '';
        if (!body.toLowerCase().contains('creditcard')) continue;
        final tx = SmsParser.parse(
          body,
          msg.date?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        );
        if (tx != null) parsed.add(tx);
      }

      // Upload to Firebase — ID is deterministic so no duplicates
      for (final tx in parsed) {
        await _db.child(tx.id).set(tx.toMap());
      }

      _isOnline = true;
      _syncStatus = SyncStatus.synced;
      // debugPrint('Synced ${parsed.length} transactions from SMS');
    } catch (e) {
      _isOnline = false;
      _syncStatus = SyncStatus.offline;
      // debugPrint('SMS sync error: $e');
    }

    notifyListeners();
  }

  // ── Firebase real-time listener ───────────────────────────────────────

  StreamSubscription? _sub;

  void listenToFirebase() {
    _sub?.cancel();
    _sub = _db.onValue.listen(
          (event) {
        final data = event.snapshot.value;
        if (data == null) {
          _allTransactions = [];
          notifyListeners();
          return;
        }

        final map = data as Map<dynamic, dynamic>;
        _allTransactions = map.entries
            .map((e) => TransactionModel.fromMap(
            e.key.toString(), e.value as Map<dynamic, dynamic>))
            .toList();

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
      },
      onError: (e) {
        _isOnline = false;
        _syncStatus = SyncStatus.offline;
        // debugPrint('Firebase listen error: $e');
        notifyListeners();
      },
    );
  }

  Future<void> toggleAssign(TransactionModel tx, AppUser user) async {
    final isAssigned = tx.assignedTo == user.id;
    await _db.child(tx.id).update({
      'assignedTo': isAssigned ? null : user.id,
      'assignedEntity': isAssigned ? null : user.entity,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
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