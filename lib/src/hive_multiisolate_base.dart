import 'dart:async';

import 'package:hive/hive.dart';


class HiveMultiIsolateBox<T> {

  HiveMultiIsolateBox(this.boxName, {this.isMultiIsolate = false});

  final String boxName;
  final bool isMultiIsolate;
  late Box<T> _box;
  Completer<void>? _initCompleter;

  Future<String?> get path async {
    var box = await _getBox();
    String? path = box.path;
    if(isMultiIsolate) await box.close();
    return path;
  }

  Future<Box<T>> _getBox() async {
    if(!isMultiIsolate) {

      // If the completer is complete, that means the box has been opened
      if(_initCompleter?.isCompleted ?? false) return _box;

      // If the completer exists but isn't completed, the box is being opened ; wait for that.
      if(_initCompleter != null) {
        await _initCompleter!.future;
        return _box;
      }

      // Create the completer and complete it when the box is opened.
      _initCompleter = Completer();
      _box = await Hive.openBox<T>(boxName);
      _initCompleter!.complete();

      return _box;
    }

    // Try to open the box as many times as it takes, in case it's opened in another Isolate
    while(true) {
      try {
        return await Hive.openBox<T>(boxName);
      } catch(e) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> put(String key, T value) async {
    final Box<T> box = await _getBox();
    await box.put(key, value);
    if(isMultiIsolate) await box.close();
  }

  Future<T?> get(String key) async {
    final Box<T> box = await _getBox();
    T? value = box.get(key);
    if(isMultiIsolate) await box.close();
    return value;
  }

  T? getSync(String key) {
    if(!isMultiIsolate) throw Exception('Cannot use getSync on a multiIsolate box');
    return _box.get(key);
  }

  Future<List<T>> getAll() async {
    final Box<T> box = await _getBox();
    List<T> values = box.values.toList();
    if(isMultiIsolate) await box.close();
    return values;
  }

  Future<int> length() async {
    final Box<T> box = await _getBox();
    int length = box.length;
    if(isMultiIsolate) await box.close();
    return length;
  }

  Iterable<T> getAllSync() {
    if(!isMultiIsolate) throw Exception('Cannot use getSync on a multiIsolate box');
    return _box.values;
  }

  Future<bool> exists(String key) async {
    final Box<T> box = await _getBox();
    bool value = box.containsKey(key);
    if(isMultiIsolate) await box.close();
    return value;
  }

  bool existsSync(String key) {
    if(!isMultiIsolate) throw Exception('Cannot use sync methods on a multiIsolate box');
    return _box.containsKey(key);
  }

  Future<void> delete(String key) async {
    final Box<T> box = await _getBox();
    await box.delete(key);
    if(isMultiIsolate) await box.close();
  }

  Future<void> clear() async {
    final Box<T> box = await _getBox();
    await box.clear();
    if(isMultiIsolate) await box.close();
  }

  Future<bool> toggle(String key, T value) async {
    Box<T> box = await _getBox();
    if(box.containsKey(key)) {
      await box.delete(key);
      if(isMultiIsolate) await box.close();
      return false;
    } else {
      await box.put(key,value);
      if(isMultiIsolate) await box.close();
      return true;
    }
  }

  Future<int> count() async {
    Box<T> box = await _getBox();
    int value = box.length;
    if(isMultiIsolate) await box.close();
    return value;
  }

  Future<List<String>> getKeys() async {
    Box<T> box = await _getBox();
    List<String> list = [];
    try {
      for(var key in box.keys) {
        list.add(key as String);
      }
    } catch(_) {}
    if(isMultiIsolate) await box.close();
    return list;
  }

  Future<void> deleteFromDisk() async {
    Box<T> box = await _getBox();

    // This close the box before deleting it
    await box.deleteFromDisk();

    // Will allow the reopening of the box
    _initCompleter = null;
  }
}
