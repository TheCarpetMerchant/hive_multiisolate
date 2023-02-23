import 'dart:async';

import 'package:hive/hive.dart';

/// Use this wrapper class to access a Hive box in a secure way across multiple isolates.
class HiveMultiIsolateBox<T> {
  HiveMultiIsolateBox(
    this.boxName, {
    this.isMultiIsolate = false,
    this.lazy = false,
    this.maxTries,
    this.retryDelay = const Duration(milliseconds: 100),
  });

  /// Name of the box. Passed as-is to Hive.openBox();
  final String boxName;

  /// If true, the box will be opened then closed for each operation.
  final bool isMultiIsolate;

  /// Whether to use a LazyBox or a regular box.
  final bool lazy;

  /// The number of time we should try to open the box.
  /// If null, tries will be infinite.
  final int? maxTries;

  /// The amount of time to wait between each attempt to open the box.
  final Duration retryDelay;

  late BoxBase<T> _box;
  Completer<void>? _initCompleter;

  /// Whether a non-multiisolate box has finished opening.
  bool get isOpenedSync => _initCompleter?.isCompleted ?? false;

  /// The location of the box in the file system. In the browser, this is null.
  Future<String?> get path async {
    var box = await _getBox();
    String? path = box.path;
    await _closeBox(box);
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
    int tries = 0;
    while (true) {
      tries++;
      try {
        if (lazy) {
          return await Hive.openLazyBox<T>(boxName);
        } else {
          return await Hive.openBox<T>(boxName);
        }
      } catch (e) {
        if (maxTries != null) {
          if (tries >= maxTries!) {
            throw Exception('Could not open box $boxName :\n$e');
          }
        }
      }
      await Future<void>.delayed(retryDelay);
    }
  }

  /// Box.add().
  Future<int> add(T value) async {
    final box = await _getBox();
    final idx = await box.add(value);
    await _closeBox(box);
    return idx;
  }

  /// Box.addAll().
  Future<Iterable<int>> addAll(Iterable<T> values) async {
    final box = await _getBox();
    final indexes = await box.addAll(values);
    await _closeBox(box);
    return indexes;
  }

  /// Box.put().
  Future<void> put(String key, T value) async {
    final box = await _getBox();
    await box.put(key, value);
    await _closeBox(box);
  }

  /// Box.putAll().
  Future<void> putAll(Map<String, T> entries) async {
    final box = await _getBox();
    await box.putAll(entries);
    await _closeBox(box);
  }

  /// Box.get().
  Future<T?> get(String key) async {
    final box = await _getBox();
    T? value =
        lazy ? await (box as LazyBox<T>).get(key) : (box as Box<T>).get(key);
    await _closeBox(box);
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
    await _closeBox(box);
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
    await _closeBox(box);
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
    await _closeBox(box);
  }

  /// Box.clear().
  Future<void> clear() async {
    final box = await _getBox();
    await box.clear();
    await _closeBox(box);
  }

  /// If the [key] exists in the box, removes the [value] and returns false.
  /// If the [key] doesn't exists, put the [value] and returns true.
  Future<bool> toggle(String key, T value) async {
    final box = await _getBox();
    if (box.containsKey(key)) {
      await box.delete(key);
      await _closeBox(box);
      return false;
    } else {
      await box.put(key, value);
      await _closeBox(box);
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
    await _closeBox(box);
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
    await _closeBox(box);
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

  /// Since Hive closes the file, then deletes it, another isolate can get the
  /// lock before we can delete the lock file, raising an exception.
  Future<void> _closeBox(BoxBase<T> box) async {
    if (isMultiIsolate) {
      try {
        await box.close();
      } catch (e) {
        // Nothing
      }
    }
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
