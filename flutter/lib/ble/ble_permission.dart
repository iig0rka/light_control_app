import 'package:permission_handler/permission_handler.dart';

class BlePermissions {
  static Future<bool> ensure() async {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();

    // для старих Android
    final location = await Permission.locationWhenInUse.request();

    return scan.isGranted && connect.isGranted && location.isGranted;
  }
}
