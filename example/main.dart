import 'package:hive_multiisolate/hive_multiisolate.dart';

void main() async {
  var myBox = HiveMultiIsolateBox<String>('boxName', isMultiIsolate: true);

  // Just use the box as you would a normal Hive box, except it's async for all operations.
  await myBox.put('key', 'value');
  print(await myBox.get('key'));

  // You can have sync boxes by leaving isMultiIsolate as false.
  var syncBox = HiveMultiIsolateBox<String>('syncBox');
  await syncBox.open();
  await syncBox.put('key', 'value');
  print(syncBox.getSync('key'));
}
