import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'lego_brick_model.g.dart';

@HiveType(typeId: 0)
class LegoBrickModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  double? confidence;

  @HiveField(5)
  DateTime scannedAt;

  LegoBrickModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.quantity,
    this.confidence,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();

  Color get color => Color(colorValue);

  // ignore: deprecated_member_use
  set color(Color newColor) {
    colorValue = newColor.value;
  }

  // Convert from the existing LegoBrick class
  // ignore: deprecated_member_use
  factory LegoBrickModel.fromLegoBrick(dynamic brick) {
    return LegoBrickModel(
      id: brick.id,
      name: brick.name,
      colorValue: (brick.color as Color).value,
      quantity: brick.quantity,
      confidence: brick.confidence,
    );
  }

  // Update quantity
  void updateQuantity(int newQuantity) {
    quantity = newQuantity;
    save(); // Hive auto-save
  }

  // Increment quantity
  void incrementQuantity([int amount = 1]) {
    quantity += amount;
    save();
  }

  @override
  String toString() {
    return 'LegoBrick(id: $id, name: $name, quantity: $quantity, confidence: $confidence)';
  }
}
