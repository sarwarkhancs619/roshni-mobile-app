import 'package:hive_flutter/hive_flutter.dart';

class HiveStorage {
  static const String friendsBoxName = 'friends';
  static const String attendanceBoxName = 'attendance';
  static const String activitiesBoxName = 'activities';
  static const String iepBoxName = 'iep';
  static const String medicalBoxName = 'medical';
  static const String usersBoxName = 'users';
  static const String permissionsBoxName = 'permissions';
  static const String documentsBoxName = 'documents';

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Open local cache boxes
    await Hive.openBox(friendsBoxName);
    await Hive.openBox(attendanceBoxName);
    await Hive.openBox(activitiesBoxName);
    await Hive.openBox(iepBoxName);
    await Hive.openBox(medicalBoxName);
    await Hive.openBox(usersBoxName);
    await Hive.openBox(permissionsBoxName);
    await Hive.openBox(documentsBoxName);
  }

  // Generic methods to read/write from Hive
  static Box getBox(String boxName) {
    return Hive.box(boxName);
  }

  static Future<void> write(String boxName, String key, dynamic value) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }

  static dynamic read(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  static List<dynamic> readAll(String boxName) {
    final box = Hive.box(boxName);
    return box.values.toList();
  }

  static Future<void> delete(String boxName, String key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  static Future<void> clearAll() async {
    await Hive.box(friendsBoxName).clear();
    await Hive.box(attendanceBoxName).clear();
    await Hive.box(activitiesBoxName).clear();
    await Hive.box(iepBoxName).clear();
    await Hive.box(medicalBoxName).clear();
    await Hive.box(usersBoxName).clear();
    await Hive.box(permissionsBoxName).clear();
  }
}
