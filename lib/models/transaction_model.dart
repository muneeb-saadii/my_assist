class TransactionModel {
  final String id;
  final String rawMessage;
  final String description;
  final String cardEnding;
  final double amount;
  final DateTime date;
  final String merchant;
  final bool isFuel;
  String? assignedTo;
  String? assignedEntity;

  TransactionModel({
    required this.id,
    required this.rawMessage,
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
        'rawMessage': rawMessage,
        'description': description,
        'cardEnding': cardEnding,
        'amount': amount,
        'date': date.toIso8601String(),
        'merchant': merchant,
        'isFuel': isFuel,
        'assignedTo': assignedTo,
        'assignedEntity': assignedEntity,
      };

  factory TransactionModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return TransactionModel(
      id: id,
      rawMessage: map['rawMessage']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      cardEnding: map['cardEnding']?.toString() ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      merchant: map['merchant']?.toString() ?? '',
      isFuel: map['isFuel'] == true,
      assignedTo: map['assignedTo']?.toString(),
      assignedEntity: map['assignedEntity']?.toString(),
    );
  }

  TransactionModel copyWith({
    String? assignedTo,
    String? assignedEntity,
  }) {
    return TransactionModel(
      id: id,
      rawMessage: rawMessage,
      description: description,
      cardEnding: cardEnding,
      amount: amount,
      date: date,
      merchant: merchant,
      isFuel: isFuel,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedEntity: assignedEntity ?? this.assignedEntity,
    );
  }
}
