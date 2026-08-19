import 'package:cloud_firestore/cloud_firestore.dart';

class ProformaData {
  final String id;
  final String userId;
  final String centre;
  final DateTime date;
  final String purchaseEntryId;
  final double quantity;
  final double rate;
  final double amount;
  final int farmers;
  final double moisture;
  final double moistureValue;
  final double shortage;
  final double shortageValue;
  final double padtha;
  final double padthaValue;
  final double outTurn;
  final double outTurnValue;
  final double seed;
  final double seedValue;
  final DateTime createdAt;

  ProformaData({
    required this.id,
    required this.userId,
    required this.centre,
    required this.date,
    required this.purchaseEntryId,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.farmers,
    required this.moisture,
    required this.moistureValue,
    required this.shortage,
    required this.shortageValue,
    required this.padtha,
    required this.padthaValue,
    required this.outTurn,
    required this.outTurnValue,
    required this.seed,
    required this.seedValue,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'centre': centre,
    'date': date.toIso8601String(),
    'purchaseEntryId': purchaseEntryId,
    'quantity': quantity,
    'rate': rate,
    'amount': amount,
    'farmers': farmers,
    'moisture': moisture,
    'moistureValue': moistureValue,
    'shortage': shortage,
    'shortageValue': shortageValue,
    'padtha': padtha,
    'padthaValue': padthaValue,
    'outTurn': outTurn,
    'outTurnValue': outTurnValue,
    'seed': seed,
    'seedValue': seedValue,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory ProformaData.fromJson(Map<String, dynamic> json, String id) {
    return ProformaData(
      id: id,
      userId: json['userId'] ?? '',
      centre: json['centre'] ?? '',
      date: DateTime.parse(json['date']),
      purchaseEntryId: json['purchaseEntryId'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      farmers: json['farmers'] ?? 0,
      moisture: (json['moisture'] as num?)?.toDouble() ?? 0,
      moistureValue: (json['moistureValue'] as num?)?.toDouble() ?? 0,
      shortage: (json['shortage'] as num?)?.toDouble() ?? 0,
      shortageValue: (json['shortageValue'] as num?)?.toDouble() ?? 0,
      padtha: (json['padtha'] as num?)?.toDouble() ?? 0,
      padthaValue: (json['padthaValue'] as num?)?.toDouble() ?? 0,
      outTurn: (json['outTurn'] as num?)?.toDouble() ?? 0,
      outTurnValue: (json['outTurnValue'] as num?)?.toDouble() ?? 0,
      seed: (json['seed'] as num?)?.toDouble() ?? 0,
      seedValue: (json['seedValue'] as num?)?.toDouble() ?? 0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }
}