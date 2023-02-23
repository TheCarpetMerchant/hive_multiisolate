import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'package:hive/hive.dart';
import 'package:hive_multiisolate/hive_multiisolate.dart';
import 'package:test/test.dart';

bool hiveInitialized = false;
String hiveDir = 'D:/Tests/'; // test has problems with file access. Change this as needed when running tests
String mainIsolateId = '';

Future<void> main() async {

  verifyInitHive();
  mainIsolateId = Service.getIsolateID(Isolate.current)!;

  test('Works', () async {

    // Delete the box from the disk to get a fresh test
    await getTextBox().deleteFromDisk();
    // Make sure a file already exists
    await getTextBox().put('key', 'value');
    await getTextBox().delete('key');

    // Spawn an Isolate and try to put data into the box, in 2 isolates at the same time.
    await Future.wait([
      Isolate.run(testHiveMultiIsolate),
      testHiveMultiIsolate(),
    ]);

    // Get the box and verify everything is fine
    var myBox = getTextBox();
    expect(await myBox.count(), equals(200));
    expect(await myBox.get('key-$mainIsolateId-50'), equals('value-$mainIsolateId-50'));
  });
}

void verifyInitHive() {
  if(hiveInitialized) return;
  Hive.init(hiveDir);
  hiveInitialized = true;
}

HiveMultiIsolateBox<String> getTextBox() => HiveMultiIsolateBox<String>('test_box', isMultiIsolate: true, maxTries: 10,);

Future<bool> testHiveMultiIsolate() async {
  verifyInitHive();
  String isolateId = Service.getIsolateID(Isolate.current)!;
  print(isolateId);
  var myBox = getTextBox();
  for(int i = 0; i < 100; i++) {
    if(isolateId != mainIsolateId) print('$i');
    try {
      await myBox.put('key-$isolateId-$i', 'value-$isolateId-$i');
      print('Put in $isolateId');
    } catch(e) {
      print('Error on isolate $isolateId $i $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return true;
}
