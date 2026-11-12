import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chery CarLinko Nordic UART Service (NUS) GATT definitions
class CarLinkoBleUuids {
  CarLinkoBleUuids._();

  static final Guid serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid txCharUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'); // Write
  static final Guid rxCharUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'); // Notify
}

/// CarLinko BLE Opcode mapping (SF-prefixed binary/hex commands)
class CarLinkoBleOpcodes {
  CarLinkoBleOpcodes._();

  static const String lock = 'SF010000';
  static const String unlock = 'SF020000';
  static const String trunkOpen = 'SF030000';
  static const String findCar = 'SF040000';
  static const String windowsClose = 'SF050000';
  static const String windowsOpen = 'SF060000';
  static const String windowsVent = 'SF0E0000';
  static const String sunroofClose = 'SF0F0000';
  static const String sunroofOpen = 'SF0F0100';
  static const String sunroofTilt = 'SF0F0200';
  static const String acOff = 'SF100000';
  static const String acOn = 'SF100100';
  static const String defogOff = 'SF120000';
  static const String defogOn = 'SF120100';
  static const String quickCool = 'SF200000';
  static const String quickHeat = 'SF190000';
  static const String stopCharging = 'SF270100';

  /// Maps a cloud 74xxxx opcode to its BLE SFxxxx equivalent
  static String? fromCloudOpcode(String cloudOpcode) {
    final clean = cloudOpcode.toUpperCase().trim();
    switch (clean) {
      case '740100': return lock;
      case '740200': return unlock;
      case '740300':
      case '740358': return trunkOpen;
      case '740400': return findCar;
      case '740500': return windowsClose;
      case '740600': return windowsOpen;
      case '740E00': return windowsVent;
      case '740F00': return sunroofClose;
      case '740F01': return sunroofOpen;
      case '740F02': return sunroofTilt;
      case '741000': return acOff;
      case '741001': return acOn;
      case '741200': return defogOff;
      case '741201': return defogOn;
      case '742001': return quickCool;
      case '741F01': return quickHeat;
      case '742701': return stopCharging;
      default:
        // Generic fallback: if starts with 74, try replacing with SF
        if (clean.startsWith('74') && clean.length == 6) {
          return 'SF${clean.substring(2)}00';
        }
        return null;
    }
  }
}

enum BleLinkState {
  disconnected,
  scanning,
  connecting,
  connected,
  unsupported,
  unauthorized,
}

/// Singleton manager for Bluetooth Low Energy direct vehicle connectivity.
/// Ports CarLinko's Nordic UART Service communication for zero-latency vehicle actuation.
class CarLinkoBleController extends ChangeNotifier {
  static final CarLinkoBleController _instance = CarLinkoBleController._internal();
  factory CarLinkoBleController() => _instance;
  CarLinkoBleController._internal();

  /// Known Chery vehicle BLE MAC address (confirmed live: FC:E2:A5:45:06:67)
  static const String defaultVehicleMac = 'FC:E2:A5:45:06:67';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txChar;
  BluetoothCharacteristic? _rxChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<List<int>>? _rxSub;

  final List<ScanResult> _discoveredDevices = [];
  List<ScanResult> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  BleLinkState _state = BleLinkState.disconnected;
  BleLinkState get state => _state;
  bool get isConnected => _state == BleLinkState.connected && _txChar != null;
  bool get isScanning => _state == BleLinkState.scanning;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  String? _connectedDeviceId;
  String? get connectedDeviceId => _connectedDeviceId;

  int _rssi = 0;
  int get rssi => _rssi;

  String? _lastRxResponse;
  String? get lastRxResponse => _lastRxResponse;

  String? _lastError;
  String? get lastError => _lastError;

  final List<String> _activityLog = [];
  List<String> get activityLog => List.unmodifiable(_activityLog);

  void _log(String msg) {
    final entry = '[${DateTime.now().toIso8601String().substring(11, 19)}] $msg';
    _activityLog.insert(0, entry);
    if (_activityLog.length > 50) {
      _activityLog.removeLast();
    }
    debugPrint('BLE: $msg');
    notifyListeners();
  }

  /// Initialize and restore last paired vehicle device if available.
  Future<void> init() async {
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        _state = BleLinkState.unsupported;
        _log('BLE not supported on this hardware');
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.unauthorized) {
        _state = BleLinkState.unauthorized;
        _log('Bluetooth permission unauthorized');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      var lastDevId = prefs.getString('tm_ble_last_device_id');
      if (lastDevId == null || lastDevId.isEmpty || lastDevId == '3E:31:C6:10:57:BE') {
        lastDevId = defaultVehicleMac;
        await prefs.setString('tm_ble_last_device_id', defaultVehicleMac);
      }
      _connectedDeviceId = lastDevId;
      _log('Vehicle BLE target MAC initialized: $lastDevId');
    } catch (e) {
      _log('Init error: $e');
    }
  }

  /// Direct connection by MAC/Device ID without waiting for advertising beacons
  Future<bool> directConnect({String? macAddress}) async {
    if (_state == BleLinkState.connected) {
      _log('Already connected via BLE');
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var targetMac = macAddress ?? prefs.getString('tm_ble_last_device_id') ?? defaultVehicleMac;
      if (targetMac == '3E:31:C6:10:57:BE') {
        targetMac = defaultVehicleMac;
        await prefs.setString('tm_ble_last_device_id', defaultVehicleMac);
      }
      _log('Direct GATT connect to vehicle MAC ($targetMac)...');
      final device = BluetoothDevice.fromId(targetMac);
      return await connectToDevice(device);
    } catch (e) {
      _lastError = e.toString();
      _log('Direct connect failed: $e');
      return false;
    }
  }

  /// Start scanning for the vehicle's BLE peripheral
  Future<void> startScan({int timeoutSeconds = 12, String? targetDeviceName}) async {
    if (_state == BleLinkState.connected) {
      _log('Already connected to vehicle BLE');
      return;
    }

    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _log('Bluetooth adapter is off (${adapterState.name}). Please enable Bluetooth.');
        _state = BleLinkState.disconnected;
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      var lastDevId = prefs.getString('tm_ble_last_device_id') ?? defaultVehicleMac;
      if (lastDevId == '3E:31:C6:10:57:BE') lastDevId = defaultVehicleMac;

      // 1. Check if vehicle is already connected to the phone OS
      try {
        final sysConnected = await FlutterBluePlus.systemDevices([CarLinkoBleUuids.serviceUuid, Guid('1800')]);
        for (final d in sysConnected) {
          final id = d.remoteId.str.toUpperCase();
          _log('OS connected peripheral: ${d.platformName} ($id)');
          if (id == defaultVehicleMac.toUpperCase() || id == lastDevId.toUpperCase()) {
            _log('Found vehicle among OS connected devices! Auto-linking...');
            await connectToDevice(d);
            return;
          }
        }
      } catch (e) {
        _log('System devices query note: $e');
      }

      // 2. Check bonded devices
      try {
        final bonded = await FlutterBluePlus.bondedDevices;
        for (final d in bonded) {
          final id = d.remoteId.str.toUpperCase();
          if (id == defaultVehicleMac.toUpperCase() || id == lastDevId.toUpperCase()) {
            _log('Found vehicle among paired bonded devices: ${d.platformName} ($id)');
          }
        }
      } catch (_) {}

      _state = BleLinkState.scanning;
      _discoveredDevices.clear();
      _log('Scanning for nearby BLE devices (looking for Chery / T-Box)...');
      notifyListeners();

      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          final existingIdx = _discoveredDevices.indexWhere((d) => d.device.remoteId == r.device.remoteId);
          if (existingIdx >= 0) {
            _discoveredDevices[existingIdx] = r;
          } else {
            _discoveredDevices.add(r);
          }
          notifyListeners();

          final adv = r.advertisementData;
          final name = adv.advName.isNotEmpty ? adv.advName : r.device.platformName;
          final devIdStr = r.device.remoteId.str.toUpperCase();
          final isSavedDevice = (devIdStr == lastDevId.toUpperCase() || devIdStr == defaultVehicleMac.toUpperCase());
          final matchesService = adv.serviceUuids.contains(CarLinkoBleUuids.serviceUuid);
          final lowerName = name.toLowerCase();
          final matchesName = (targetDeviceName != null && targetDeviceName.isNotEmpty && lowerName.contains(targetDeviceName.toLowerCase())) ||
              lowerName.contains('chery') ||
              lowerName.contains('tiggo') ||
              lowerName.contains('tbox') ||
              lowerName.contains('t-box') ||
              lowerName.contains('carlink') ||
              lowerName.contains('cqr') ||
              lowerName.contains('vrt') ||
              lowerName.contains('3342');

          if (isSavedDevice || matchesService || matchesName) {
            _log('Auto-matched vehicle device: "$name" ($devIdStr) RSSI: ${r.rssi}');
            await stopScan();
            await connectToDevice(r.device);
            return;
          }
        }
      });

      // Start unfiltered scan so Android BLE stack does not drop 128-bit NUS devices
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
      );

      // Also listen to scan isScanning stream to transition state when scan finishes
      FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _state == BleLinkState.scanning) {
          _state = BleLinkState.disconnected;
          _log('Scan completed (${_discoveredDevices.length} devices detected)');
          notifyListeners();
        }
      });
    } catch (e) {
      _lastError = e.toString();
      _state = BleLinkState.disconnected;
      _log('Scan failed: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;
      if (_state == BleLinkState.scanning) {
        _state = BleLinkState.disconnected;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Connect to a specific BluetoothDevice
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _state = BleLinkState.connecting;
      _log('Connecting to ${device.platformName} (${device.remoteId.str})...');
      notifyListeners();

      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      _connectedDevice = device;
      _connectedDeviceId = device.remoteId.str;
      _connectedDeviceName = device.platformName.isNotEmpty ? device.platformName : 'Chery T-Box';

      // Persist last device ID for seamless reconnect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tm_ble_last_device_id', device.remoteId.str);
      await prefs.setString('tm_ble_last_device_name', _connectedDeviceName!);

      // Discover GATT services
      _log('Discovering GATT services...');
      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid == CarLinkoBleUuids.serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == CarLinkoBleUuids.txCharUuid) {
              _txChar = c;
            } else if (c.uuid == CarLinkoBleUuids.rxCharUuid) {
              _rxChar = c;
            }
          }
        }
      }

      // Fallback: If 6e400001 service not matched directly, inspect all services for serial I/O
      if (_txChar == null) {
        for (final s in services) {
          for (final c in s.characteristics) {
            if (_txChar == null && (c.properties.write || c.properties.writeWithoutResponse)) {
              _txChar = c;
              _log('Bound fallback BLE TX characteristic: ${c.uuid}');
            }
            if (_rxChar == null && (c.properties.notify || c.properties.indicate)) {
              _rxChar = c;
              _log('Bound fallback BLE RX characteristic: ${c.uuid}');
            }
          }
        }
      }

      if (_txChar == null) {
        _log('Warning: No writable BLE characteristic found on device');
      }

      if (_rxChar != null) {
        try {
          await _rxChar!.setNotifyValue(true);
          _rxSub = _rxChar!.onValueReceived.listen((data) {
            final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            final ascii = String.fromCharCodes(data.where((b) => b >= 32 && b <= 126));
            _lastRxResponse = '$hex ($ascii)';
            _log('RX: $hex');
          });
        } catch (e) {
          _log('Failed to subscribe to RX notify: $e');
        }
      }

      _state = BleLinkState.connected;
      _log('Connected via BLE to $_connectedDeviceName! Direct actuation ready.');

      // Listen for disconnection
      _connStateSub?.cancel();
      _connStateSub = device.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected) {
          _log('Vehicle BLE disconnected');
          _cleanupConnection();
        }
      });

      // Poll RSSI
      try {
        _rssi = await device.readRssi();
      } catch (_) {}

      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _log('Connection failed: $e');
      _cleanupConnection();
      return false;
    }
  }

  void _cleanupConnection() {
    _state = BleLinkState.disconnected;
    _txChar = null;
    _rxChar = null;
    _rxSub?.cancel();
    _connStateSub?.cancel();
    _connectedDevice = null;
    notifyListeners();
  }

  /// Disconnect manually
  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _cleanupConnection();
    _log('Disconnected by user');
  }

  /// Encrypts an opcode payload with CarLinko's AES-256-CBC cipher (Key: qwertyuiopasdfghjklzxcvbnm123456, IV: qwertyuiopasdfgh)
  static Uint8List encryptCarLinkoPayload(String opcode) {
    const keyStr = 'qwertyuiopasdfghjklzxcvbnm123456';
    const ivStr = 'qwertyuiopasdfgh';
    final keyBytes = Uint8List.fromList(utf8.encode(keyStr));
    final ivBytes = Uint8List.fromList(utf8.encode(ivStr));
    final plainBytes = Uint8List.fromList(utf8.encode(opcode));

    // PKCS7 padding to 16 bytes
    final padLen = 16 - (plainBytes.length % 16);
    final padded = Uint8List(plainBytes.length + padLen);
    padded.setRange(0, plainBytes.length, plainBytes);
    padded.fillRange(plainBytes.length, padded.length, padLen);

    final cbc = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(keyBytes), ivBytes));
    final cipherText = Uint8List(padded.length);
    for (var offset = 0; offset < padded.length; offset += 16) {
      cbc.processBlock(padded, offset, cipherText, offset);
    }
    return cipherText;
  }

  /// Send an actuation command directly over BLE Nordic UART.
  /// If [encrypted] is true (default), encrypts with CarLinko AES-256-CBC cipher.
  Future<bool> sendCommand(String opcode, {bool encrypted = true}) async {
    if (!isConnected || _txChar == null) {
      _log('Cannot send BLE command: not connected');
      return false;
    }

    try {
      final cleanOpcode = opcode.trim();
      _log('TX BLE Command: $cleanOpcode (encrypted: $encrypted)');

      final Uint8List bytes;
      if (encrypted) {
        bytes = encryptCarLinkoPayload(cleanOpcode);
        _log('AES-CBC payload (${bytes.length}B): ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
      } else {
        bytes = Uint8List.fromList(utf8.encode(cleanOpcode));
      }

      final withoutResponse = !_txChar!.properties.write && _txChar!.properties.writeWithoutResponse;
      await _txChar!.write(bytes, withoutResponse: withoutResponse);
      _log('Command $cleanOpcode dispatched successfully over BLE (<50ms latency)');
      return true;
    } catch (e) {
      _lastError = e.toString();
      _log('Failed to send BLE command: $e');
      return false;
    }
  }
}
