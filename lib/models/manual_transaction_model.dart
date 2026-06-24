import 'package:my_assist/models/transaction_model.dart';

class ManualTransactionModel {
  final String id;
  final String description;
  final String cardEnding;
  final double amount;
  final DateTime date;
  final String merchant;
  final bool isFuel;
  String? assignedTo;
  String? assignedEntity;
  final bool isManual = true;

  ManualTransactionModel({
    required this.id,
    required this.description,
    required this.cardEnding,
    required this.amount,
    required this.date,
    required this.merchant,
    required this.isFuel,
    this.assignedTo,
    this.assignedEntity,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'cardEnding': cardEnding,
    'amount': amount,
    'date': date.toIso8601String(),
    'merchant': merchant,
    'isFuel': isFuel,
    'assignedTo': assignedTo,
    'assignedEntity': assignedEntity,
    'isManual': true,
  };

  factory ManualTransactionModel.fromMap(
      String id, Map<dynamic, dynamic> map) {
    return ManualTransactionModel(
      id: id,
      description: map['description']?.toString() ?? '',
      cardEnding: map['cardEnding']?.toString() ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date:
      DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      merchant: map['merchant']?.toString() ?? '',
      isFuel: map['isFuel'] == true,
      assignedTo: map['assignedTo']?.toString(),
      assignedEntity: map['assignedEntity']?.toString(),
    );
  }

  // Convert to TransactionModel for unified list display
  TransactionModel toTransactionModel() {
    return TransactionModel(
      id: id,
      rawMessage: '[Manual Entry] $merchant — PKR $amount',
      description: description,
      cardEnding: cardEnding,
      amount: amount,
      date: date,
      merchant: merchant,
      isFuel: isFuel,
      assignedTo: assignedTo,
      assignedEntity: assignedEntity,
      isManual: true,
    );
  }
}