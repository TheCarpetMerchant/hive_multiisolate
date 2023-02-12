import 'dart:async';

import 'package:hive/hive.dart';

/// Use this wrapper class to access a Hive box in a secure way across multiple isolates.
class HiveMultiIsolateBox<T> {
  HiveMultiIsolateBox(
    this.boxName, {
    this.isMultiIsolate = false,
    this.lazy = false,
  });

  /// Name of the box. Passed as-is to Hive.openBox();
  final String boxName;

  /// If true, the box will be opened then closed for each operation.
  final bool isMultiIsolate;

  /// Whether to use a LazyBox or a regular box.
  final bool lazy;
  late BoxBase<T> _box;
  Completer<void>? _initCompleter;

  /// Whether a non-multiisolate box has finished opening.
  bool get isOpenedSync => _initCompleter?.isCompleted ?? false;

  /// The location of the box in the file system. In the browser, this is null.
  Future<String?> get path async {
    var box = await _getBox();
    String? path = box.path;
    if (isMultiIsolate) await box.close();
    return path;
  }

  Future<BoxBase<T>> _getBox() async {
    if (!isMultiIsolate) {
      // If the completer is complete, that means the box has been opened
      if (isOpenedSync) return _box;

      // If the completer exists but isn't completed, the box is being opened ; wait for that.
      if (_initCompleter != null) {
        await _initCompleter!.future;
        return _box;
      }

      // Create the completer and complete it when the box is opened.
      _initCompleter = Completer();
      if (lazy) {
        _box = await Hive.openLazyBox<T>(boxName);
      } else {
        _box = await Hive.openBox<T>(boxName);
      }
      _initCompleter!.complete();

      return _box;
    }

    // Try to open the box as many times as it takes, in case it's opened in another Isolate
    while (true) {
      try {
        if (lazy) {
          return await Hive.openLazyBox<T>(boxName);
        } else {
          return await Hive.openBox<T>(boxName);
        }
      } catch (e) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Box.put().
  Future<void> put(String key, T value) async {
    final box = await _getBox();
    await box.put(key, value);
    if (isMultiIsolate) await box.close();
  }

  /// Box.putAll().
  Future<void> putAll(Map<String, T> entries) async {
    final box = await _getBox();
    await box.putAll(entries);
    if (isMultiIsolate) await box.close();
  }

  /// Box.get().
  Future<T?> get(String key) async {
    final box = await _getBox();
    T? value =
        lazy ? await (box as LazyBox<T>).get(key) : (box as Box<T>).get(key);
    if (isMultiIsolate) await box.close();
    return value;
  }

  /// Box.get() for a non-multiisolate opened box.
  T? getSync(String key) {
    _verifySync();
    if (lazy) throw UnimplementedError('Cannot use getSync on a lazy box');
    return (_box as Box<T>).get(key);
  }

  /// Box.getAll().
  Future<List<T>> getAll() async {
    if (lazy) throw UnimplementedError('Cannot use getAll on a lazy box');
    final box = await _getBox() as Box<T>;
    List<T> values = box.values.toList();
    if (isMultiIsolate) await box.close();
    return values;
  }

  /// Box.getAll() for a non-multiisolate opened box.
  Iterable<T> getAllSync() {
    _verifySync();
    if (lazy) throw UnimplementedError('Cannot use getAllSync on a lazy box');
    return (_box as Box<T>).values;
  }

  /// Whether a key exists in the box.
  Future<bool> exists(String key) async {
    final box = await _getBox();
    bool value = box.containsKey(key);
    if (isMultiIsolate) await box.close();
    return value;
  }

  /// [exists] for a non-multiisolate opened box.
  bool existsSync(String key) {
    _verifySync();
    return _box.containsKey(key);
  }

  /// Box.delete().
  Future<void> delete(String key) async {
    final box = await _getBox();
    await box.delete(key);
    if (isMultiIsolate) await box.close();
  }

  /// Box.clear().
  Future<void> clear() async {
    final box = await _getBox();
    await box.clear();
    if (isMultiIsolate) await box.close();
  }

  /// If the [key] exists in the box, removes the [value] and returns false.
  /// If the [key] doesn't exists, put the [value] and returns true.
  Future<bool> toggle(String key, T value) async {
    final box = await _getBox();
    if (box.containsKey(key)) {
      await box.delete(key);
      if (isMultiIsolate) await box.close();
      return false;
    } else {
      await box.put(key, value);
      if (isMultiIsolate) await box.close();
      return true;
    }
  }

  /// [toggle] for a non-multiisolate opened box.
  Future<bool> toggleSync(String key, T value) async {
    _verifySync();
    if (_box.containsKey(key)) {
      await _box.delete(key);
      return false;
    } else {
      await _box.put(key, value);
      return true;
    }
  }

  /// Box.length.
  Future<int> count() async {
    final box = await _getBox();
    int value = box.length;
    if (isMultiIsolate) await box.close();
    return value;
  }

  /// Returns a list of the keys of this box.
  Future<List<String>> getKeys() async {
    final box = await _getBox();
    List<String> list = [];
    try {
      for (var key in box.keys) {
        list.add(key as String);
      }
    } catch (_) {}
    if (isMultiIsolate) await box.close();
    return list;
  }

  /// Box.deleteFromDisk.
  Future<void> deleteFromDisk() async {
    final box = await _getBox();

    // This close the box before deleting it
    await box.deleteFromDisk();

    // Will allow the reopening of the box
    _initCompleter = null;
  }

  /// Used to open the box and then use Sync methods.
  Future<void> open() async {
    await _getBox();
  }

  void _verifySync() {
    if (isMultiIsolate) {
      throw UnimplementedError('Cannot use sync methods on a multiIsolate box');
    }
    if (!isOpenedSync) {
      throw HiveError(
          'HiveMultiIsolateBox was not opened before a sync operation');
    }
  }
}
