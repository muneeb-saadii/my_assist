import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class SmsParser {
  static const List<String> fuelKeywords = [
    'PSO',
    'TOTAL',
    'SHELL',
    'ATTOCK',
    'HASCOL',
  ];

  /// Parses an SMS body into a [TransactionModel].
  /// Returns null if the message cannot be parsed (missing card or amount).
  static TransactionModel? parse(String body, int timestampMs) {
    try {
      // ── Card ending: "ending with XXXX" or "ending XXXX" ──────────────
      final cardRegex =
          RegExp(r'ending\s+(?:with\s+)?(\d{4})', caseSensitive: false);
      final cardMatch = cardRegex.firstMatch(body);
      if (cardMatch == null) return null;
      final cardEnding = cardMatch.group(1)!;

      // ── Amount: "PKR-XX,XXX.XX" / "PKR XX,XXX" / "Rs.XX,XXX" ─────────
      final amountRegex = RegExp(
        r'(?:PKR|Rs\.?)\s*[-]?\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      );
      final amountMatch = amountRegex.firstMatch(body);
      final amountStr =
          amountMatch?.group(1)?.replaceAll(',', '') ?? '0';
      final amount = double.tryParse(amountStr) ?? 0;

      // ── Merchant: "charged at MERCHANT for" ───────────────────────────
      final merchantRegex =
          RegExp(r'charged\s+at\s+(.+?)\s+for', caseSensitive: false);
      final merchantMatch = merchantRegex.firstMatch(body);
      final merchant = merchantMatch?.group(1)?.trim() ?? 'Unknown';

      // ── Date: "07/Jun/2026" or "07-Jun-2026" ──────────────────────────
      DateTime date;
      final dateRegex =
          RegExp(r'(\d{2})[\/\-](\w{3})[\/\-](\d{4})');
      final dateMatch = dateRegex.firstMatch(body);
      if (dateMatch != null) {
        try {
          date = DateFormat('dd/MMM/yyyy').parse(
            '${dateMatch.group(1)}/${dateMatch.group(2)}/${dateMatch.group(3)}',
          );
        } catch (_) {
          date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        }
      } else {
        date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      }

      // ── Fuel detection ─────────────────────────────────────────────────
      final upperBody = body.toUpperCase();
      final isFuel = fuelKeywords.any((k) => upperBody.contains(k));

      // ── Trimmed description ────────────────────────────────────────────
      final desc =
          merchant.length > 30 ? '${merchant.substring(0, 30)}...' : merchant;

      // ── Unique ID (card + date millis + amount) ────────────────────────
      final id =
          'tx_${cardEnding}_${date.millisecondsSinceEpoch}_${amount.toInt()}';

      return TransactionModel(
        id: id,
        rawMessage: body,
        description: desc,
        cardEnding: cardEnding,
        amount: amount,
        date: date,
        merchant: merchant,
        isFuel: isFuel,
      );
    } catch (e) {
      debugPrint('SmsParser error: $e');
      return null;
    }
  }
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);
