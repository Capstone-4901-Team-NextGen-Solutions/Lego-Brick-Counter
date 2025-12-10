import 'package:hive_flutter/hive_flutter.dart';
import '../models/lego_brick_model.dart';

class DatabaseService {
  static const String _boxName = 'legoBricks';
  static Box<LegoBrickModel>? _box;

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(LegoBrickModelAdapter());
    _box = await Hive.openBox<LegoBrickModel>(_boxName);
  }

  // Get the box
  static Box<LegoBrickModel> get box {
    if (_box == null || !_box!.isOpen) {
      throw Exception('DatabaseService not initialized. Call init() first.');
    }
    return _box!;
  }

  // Add a brick
  static Future<void> addBrick(LegoBrickModel brick) async {
    await box.put(brick.id, brick);
  }

  // Add multiple bricks
  static Future<void> addBricks(List<LegoBrickModel> bricks) async {
    final Map<String, LegoBrickModel> brickMap = {
      for (var brick in bricks) brick.id: brick
    };
    await box.putAll(brickMap);
  }

  // Get all bricks
  static List<LegoBrickModel> getAllBricks() {
    return box.values.toList();
  }

  // Get brick by ID
  static LegoBrickModel? getBrick(String id) {
    return box.get(id);
  }

  // Update brick
  static Future<void> updateBrick(LegoBrickModel brick) async {
    await box.put(brick.id, brick);
  }

  // Delete brick
  static Future<void> deleteBrick(String id) async {
    await box.delete(id);
  }

  // Check if brick exists
  static bool brickExists(String id) {
    return box.containsKey(id);
  }

  // Merge or add brick (if exists, increment quantity)
  static Future<void> mergeOrAddBrick(LegoBrickModel newBrick) async {
    final existing = getBrick(newBrick.id);
    if (existing != null) {
      existing.incrementQuantity(newBrick.quantity);
    } else {
      await addBrick(newBrick);
    }
  }

  // Get total brick count
  static int getTotalBrickCount() {
    return box.values.fold(0, (sum, brick) => sum + brick.quantity);
  }

  // Get unique brick types
  static int getUniqueBrickTypes() {
    return box.length;
  }

  // Search bricks by name
  static List<LegoBrickModel> searchBricks(String query) {
    final lowerQuery = query.toLowerCase();
    return box.values
        .where((brick) =>
            brick.name.toLowerCase().contains(lowerQuery) ||
            brick.id.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // Get bricks sorted by quantity
  static List<LegoBrickModel> getBricksSortedByQuantity({bool descending = true}) {
    final bricks = getAllBricks();
    bricks.sort((a, b) => descending
        ? b.quantity.compareTo(a.quantity)
        : a.quantity.compareTo(b.quantity));
    return bricks;
  }

  // Get bricks sorted by scan date
  static List<LegoBrickModel> getBricksSortedByDate({bool newest = true}) {
    final bricks = getAllBricks();
    bricks.sort((a, b) => newest
        ? b.scannedAt.compareTo(a.scannedAt)
        : a.scannedAt.compareTo(b.scannedAt));
    return bricks;
  }

  // Clear all data
  static Future<void> clearAll() async {
    await box.clear();
  }

  // Export data to JSON
  static Map<String, dynamic> exportToJson() {
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'totalBricks': getTotalBrickCount(),
      'uniqueTypes': getUniqueBrickTypes(),
      'bricks': box.values.map((brick) => {
        'id': brick.id,
        'name': brick.name,
        'color': brick.colorValue,
        'quantity': brick.quantity,
        'confidence': brick.confidence,
        'scannedAt': brick.scannedAt.toIso8601String(),
      }).toList(),
    };
  }

  // Get statistics
  static Map<String, int> getStatistics() {
    return {
      'totalBricks': getTotalBrickCount(),
      'uniqueTypes': getUniqueBrickTypes(),
      'recentScans': box.values
          .where((brick) => brick.scannedAt
              .isAfter(DateTime.now().subtract(const Duration(days: 7))))
          .length,
    };
  }

  // Close the database
  static Future<void> close() async {
    await box.close();
  }
}
