import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/carlinko_ble_controller.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../carlinko/vehicle_skin.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'carlinko_connect_dialog.dart';
import 'chery_service_centres_screen.dart';
import 'vehicle_radar_sheet.dart';
import 'smart_charging_sheet.dart';
import 'dart:async';
import 'app_notification.dart';
import 'smart_drive_hud.dart';
import 'location_history_sheet.dart';
import '../widgets/home_widget_service.dart';
import 'climate_control_sheet.dart';
import 'windows_control_sheet.dart';
import 'remote_engine_sheet.dart';
import 'remote_command_diagnostics_sheet.dart';
import 'car_view_carousel.dart';
import '../mytnb/mytnb_api.dart';
import 'mytnb_connect_dialog.dart';
import '../service/bluetooth_driving_tracker_service.dart';
import '../service/battery_health_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'tiggo_map_config.dart';
import 'vehicle_details_sheet.dart';

class NeoDashboard extends StatefulWidget {
  final VehicleRepository repository;
  final String ownerName;
  final String carPlateNumber;
  final String vehicleNickname;
  final double tnbTariff;
  final double fuelPrice;
  final String? vehicleSkinKey;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAssistant;
  final void Function({bool startVoice})? onOpenAssistantWithVoice;

  const NeoDashboard({
    super.key,
    required this.repository,
    required this.ownerName,
    required this.carPlateNumber,
    required this.vehicleNickname,
    required this.tnbTariff,
    required this.fuelPrice,
    this.vehicleSkinKey,
    required this.onOpenSettings,
    required this.onOpenAssistant,
    this.onOpenAssistantWithVoice,
  });

  @override
  State<NeoDashboard> createState() => _NeoDashboardState();
}

class _NeoDashboardState extends State<NeoDashboard> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late VehicleTelemetry _telemetry;
  bool _scheduledCharging = true;
  bool _isDoorsLocked = true;
  bool _isAcActive = false;
  bool _isWindowsVented = false;
  bool _isTrunkOpen = false;
  int _carViewPage = 0; // remembered carousel page (survives card rebuilds)

  String get _selectedVehicleColorKey => VehicleSkinManager.instance.currentSkinKey;

  late AnimationController _pulseController;
  StreamSubscription<String>? _quickActionSubscription;
  Timer? _refreshTimer;

  void _handleSkinChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openVoiceAssistant({bool startVoice = true}) {
    HapticFeedback.mediumImpact();
    if (widget.onOpenAssistantWithVoice != null) {
      widget.onOpenAssistantWithVoice!(startVoice: startVoice);
    } else {
      widget.onOpenAssistant();
    }
  }

  @override
  void didUpdateWidget(covariant NeoDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vehicleSkinKey != null && widget.vehicleSkinKey != oldWidget.vehicleSkinKey) {
      VehicleSkinManager.instance.setSkin(widget.vehicleSkinKey!);
    }
  }

  @override
  void initState() {
    super.initState();
    _telemetry = widget.repository.currentTelemetry;
    _isDoorsLocked = _telemetry.doorsLocked;
    _isAcActive = _telemetry.acOn;
    _isTrunkOpen = _telemetry.trunkOpen;
    _isWindowsVented = _telemetry.windowsOpen;
    VehicleSkinManager.instance.addListener(_handleSkinChanged);
    TiggoMapConfig.init();

    // Initialize native Android Home Widget and App Shortcuts listeners
    HomeWidgetService.instance.init();
    _quickActionSubscription = HomeWidgetService.instance.onQuickAction.listen((uri) {
      if (mounted) _handleQuickActionUri(uri);
    });

    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        _syncWidgetTelemetry();
      }
    });

    widget.repository.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
          _isDoorsLocked = data.doorsLocked;
          _isAcActive = data.acOn;
          _isTrunkOpen = data.trunkOpen;
          _isWindowsVented = data.windowsOpen;
        });
        _syncWidgetTelemetry();
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Telemetry was previously only fetched once, at cold app-start --
    // nothing ever re-fetched it, so stale state (climate on/off, doors,
    // GPS) only cleared up if the user killed and reopened the app.
    // Poll while the dashboard is visible, and refresh immediately
    // whenever the app comes back to the foreground.
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (widget.repository.isVehicleBound) {
        widget.repository.refresh().catchError((e) {
          debugPrint('Periodic CarLinko refresh failed (will retry): $e');
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.repository.isVehicleBound) {
      widget.repository.refresh().catchError((e) {
        debugPrint('Resume CarLinko refresh failed: $e');
      });
    }
  }

  @override
  void dispose() {
    VehicleSkinManager.instance.removeListener(_handleSkinChanged);
    _quickActionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _updateVehicleColor(String key) async {
    HapticFeedback.selectionClick();
    await VehicleSkinManager.instance.setSkin(key);
  }

  void _showVehicleSkinStudioModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VehicleSkinStudioSheet(
        selectedSkinKey: _selectedVehicleColorKey,
        onSkinSelected: (key) {
          _updateVehicleColor(key);
        },
      ),
    );
  }


  void _openCarlinkoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccount = prefs.getString('tm_carlinko_account') ??
        widget.repository.connectedAccount ??
        '';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => CarlinkoConnectDialog(
        repository: widget.repository,
        currentAccount: savedAccount,
        onConnected: () => setState(() {}),
      ),
    );
  }

  void _showNotification(String message, {NotificationType type = NotificationType.info, IconData? icon}) {
    AppNotification.show(
      context,
      message: message,
      type: type,
      icon: icon,
    );
  }

  void _openVehicleDetailsSheet() {
    VehicleDetailsSheet.show(
      context,
      telemetry: _telemetry,
      carPlateNumber: widget.carPlateNumber,
      vehicleNickname: widget.vehicleNickname,
    );
  }

  void _openClimateControlSheet() {
    ClimateControlSheet.show(
      context,
      telemetry: _telemetry,
      repository: widget.repository,
      initialAcOn: _isAcActive,
      initialTempC: _telemetry.acTemp.toDouble(),
      initialDurationMin: _telemetry.airDurationMin > 0
          ? _telemetry.airDurationMin
          : widget.repository.vehicleCapabilities.airDurationMin,
      onApply: (acOn, tempC, durationMin, {
        bool? rapidCool,
        bool? frontDefrost,
        bool? rearDefrost,
        bool? airPurifier,
        int? fanGear,
        int? seatHeatDriver,
        int? seatVentDriver,
        int? seatHeatPass,
        int? seatVentPass,
        bool? steeringHeat,
      }) {
        final previousAc = _isAcActive;
        final previousTelemetry = _telemetry;
        setState(() {
          _isAcActive = acOn;
          _telemetry = _telemetry.copyWith(
            acOn: acOn,
            acTemp: tempC.round(),
            airDurationMin: durationMin,
            rapidCool: rapidCool,
            frontDefrost: frontDefrost,
            rearDefrost: rearDefrost,
            airPurifier: airPurifier,
            fanGear: fanGear,
            seatHeatDriver: seatHeatDriver,
            seatVentDriver: seatVentDriver,
            seatHeatPass: seatHeatPass,
            seatVentPass: seatVentPass,
            steeringHeat: steeringHeat,
          );
        });
        _syncWidgetTelemetry();

        final opcode = acOn
            ? ((rapidCool == true) ? CarLinkoOpcodes.quickCool : CarLinkoOpcodes.acOn)
            : CarLinkoOpcodes.acOff;

        if (acOn != previousAc || (acOn && (rapidCool != previousTelemetry.rapidCool))) {
          _sendCommandAndReport(
            opcode,
            successMessage: acOn
                ? '❄️ Cabin Pre-cooling (${tempC.toStringAsFixed(1)}°C, ${durationMin}m)'
                : '❄️ Climate Pre-conditioning OFF',
            failureMessage: '⚠️ Climate command failed',
            onRevert: () {
              setState(() {
                _isAcActive = previousAc;
                _telemetry = previousTelemetry;
              });
              _syncWidgetTelemetry();
            },
          );
        }

        // Dynamic Cabin Temperature Setpoint (CAN 0x7411xx: 0x80 + round(tempC * 2))
        if (acOn && (tempC.round() != previousTelemetry.acTemp || acOn != previousAc)) {
          final tempOp = CarLinkoOpcodes.acTemperature(tempC);
          _sendCommandAndReport(
            tempOp,
            successMessage: '🌡️ Cabin Target Temp: ${tempC.toStringAsFixed(1)}°C',
            failureMessage: '⚠️ Temperature setpoint command failed',
          );
        }

        // Air conditioning duration setting
        if (durationMin != previousTelemetry.airDurationMin) {
          widget.repository.setAirDuration(durationMin).catchError((_) => false);
        }

        // Front Seat Ventilation (CAN 0x74 opcodes 741Axx / 741Bxx)
        if (seatVentDriver != null && seatVentDriver != previousTelemetry.seatVentDriver) {
          final op = CarLinkoOpcodes.driverSeatVentOpcode(seatVentDriver);
          _sendCommandAndReport(
            op,
            successMessage: seatVentDriver > 0
                ? '💺 Driver Seat Vent: Level $seatVentDriver'
                : '💺 Driver Seat Vent: OFF',
            failureMessage: '⚠️ Seat ventilation command failed',
          );
        }
        if (seatVentPass != null && seatVentPass != previousTelemetry.seatVentPass) {
          final op = CarLinkoOpcodes.passengerSeatVentOpcode(seatVentPass);
          _sendCommandAndReport(
            op,
            successMessage: seatVentPass > 0
                ? '💺 Passenger Seat Vent: Level $seatVentPass'
                : '💺 Passenger Seat Vent: OFF',
            failureMessage: '⚠️ Seat ventilation command failed',
          );
        }

        // Front Seat Heating (CAN 0x74 opcodes 7415xx / 7416xx)
        if (seatHeatDriver != null && seatHeatDriver != previousTelemetry.seatHeatDriver) {
          final op = CarLinkoOpcodes.driverSeatHeatOpcode(seatHeatDriver);
          _sendCommandAndReport(
            op,
            successMessage: seatHeatDriver > 0
                ? '♨️ Driver Seat Heat: Level $seatHeatDriver'
                : '♨️ Driver Seat Heat: OFF',
            failureMessage: '⚠️ Seat heating command failed',
          );
        }
        if (seatHeatPass != null && seatHeatPass != previousTelemetry.seatHeatPass) {
          final op = CarLinkoOpcodes.passengerSeatHeatOpcode(seatHeatPass);
          _sendCommandAndReport(
            op,
            successMessage: seatHeatPass > 0
                ? '♨️ Passenger Seat Heat: Level $seatHeatPass'
                : '♨️ Passenger Seat Heat: OFF',
            failureMessage: '⚠️ Seat heating command failed',
          );
        }

        // Dedicated Rear Defogger (CAN opcode 742602 / 742600)
        if (rearDefrost != null && rearDefrost != previousTelemetry.rearDefrost) {
          _sendCommandAndReport(
            rearDefrost ? CarLinkoOpcodes.rearDefogOn : CarLinkoOpcodes.rearDefogOff,
            successMessage: rearDefrost ? '♨️ Rear Window Defogger ON' : 'Rear Defogger OFF',
            failureMessage: '⚠️ Rear defogger command failed',
          );
        }

        // Front Defroster (CAN opcode 741201 / 741200)
        if (frontDefrost != null && frontDefrost != previousTelemetry.frontDefrost) {
          _sendCommandAndReport(
            frontDefrost ? CarLinkoOpcodes.defogOn : CarLinkoOpcodes.defogOff,
            successMessage: frontDefrost ? '💨 Front Defroster ON' : 'Front Defroster OFF',
            failureMessage: '⚠️ Front defroster command failed',
          );
        }

        // Steering Wheel Heat (CAN opcode 742401 / 742400)
        if (steeringHeat != null && steeringHeat != previousTelemetry.steeringHeat) {
          _sendCommandAndReport(
            steeringHeat ? CarLinkoOpcodes.steeringHeatOn : CarLinkoOpcodes.steeringHeatOff,
            successMessage: steeringHeat ? '🔥 Heated Steering Wheel ON' : 'Heated Steering Wheel OFF',
            failureMessage: '⚠️ Heated steering wheel command failed',
          );
        }

        // Air Purifier / CN95 Filter (CAN opcode 742501 / 742500)
        if (airPurifier != null && airPurifier != previousTelemetry.airPurifier) {
          _sendCommandAndReport(
            airPurifier ? CarLinkoOpcodes.airPurifyOn : CarLinkoOpcodes.airPurifyOff,
            successMessage: airPurifier ? '🌿 Air Purifier (CN95) ON' : 'Air Purifier OFF',
            failureMessage: '⚠️ Air purifier command failed',
          );
        }
      },
    );
  }

  void _openDefrostSheet() {
    ClimateControlSheet.show(
      context,
      telemetry: _telemetry,
      repository: widget.repository,
      isDefrostMode: true,
      initialAcOn: true,
      initialTempC: 28.0,
      initialDurationMin: 10,
      initialFrontDefrost: true,
      initialRearDefrost: true,
      onApply: (acOn, tempC, durationMin, {
        bool? rapidCool,
        bool? frontDefrost,
        bool? rearDefrost,
        bool? airPurifier,
        int? fanGear,
        int? seatHeatDriver,
        int? seatVentDriver,
        int? seatHeatPass,
        int? seatVentPass,
        bool? steeringHeat,
      }) {
        final previousAc = _isAcActive;
        final previousTelemetry = _telemetry;
        setState(() {
          _isAcActive = acOn;
          _telemetry = _telemetry.copyWith(
            acOn: acOn,
            acTemp: tempC.round(),
            airDurationMin: durationMin,
            rapidCool: rapidCool,
            frontDefrost: frontDefrost,
            rearDefrost: rearDefrost,
            airPurifier: airPurifier,
            fanGear: fanGear,
            seatHeatDriver: seatHeatDriver,
            seatVentDriver: seatVentDriver,
            seatHeatPass: seatHeatPass,
            seatVentPass: seatVentPass,
            steeringHeat: steeringHeat,
          );
        });
        _syncWidgetTelemetry();

        final opcode = acOn
            ? ((rapidCool == true) ? CarLinkoOpcodes.quickCool : CarLinkoOpcodes.acOn)
            : CarLinkoOpcodes.acOff;

        if (acOn != previousAc || (acOn && (rapidCool != previousTelemetry.rapidCool))) {
          _sendCommandAndReport(
            opcode,
            successMessage: acOn
                ? '💨 Defrost ON (${tempC.toStringAsFixed(1)}°C, ${durationMin}m)'
                : '💨 Defrost OFF',
            failureMessage: '⚠️ Defrost command failed',
            onRevert: () {
              setState(() {
                _isAcActive = previousAc;
                _telemetry = previousTelemetry;
              });
              _syncWidgetTelemetry();
            },
          );
        }

        if (acOn && (tempC.round() != previousTelemetry.acTemp || acOn != previousAc)) {
          final tempOp = CarLinkoOpcodes.acTemperature(tempC);
          _sendCommandAndReport(
            tempOp,
            successMessage: '🌡️ Defrost Temp: ${tempC.toStringAsFixed(1)}°C',
            failureMessage: '⚠️ Temperature setpoint command failed',
          );
        }

        if (durationMin != previousTelemetry.airDurationMin) {
          widget.repository.setAirDuration(durationMin).catchError((_) => false);
        }

        if (frontDefrost != null && frontDefrost != previousTelemetry.frontDefrost) {
          _sendCommandAndReport(
            frontDefrost ? CarLinkoOpcodes.defogOn : CarLinkoOpcodes.defogOff,
            successMessage: frontDefrost ? '💨 Front Defroster ON' : 'Front Defroster OFF',
            failureMessage: '⚠️ Front defroster command failed',
          );
        }

        if (rearDefrost != null && rearDefrost != previousTelemetry.rearDefrost) {
          _sendCommandAndReport(
            rearDefrost ? CarLinkoOpcodes.rearDefogOn : CarLinkoOpcodes.rearDefogOff,
            successMessage: rearDefrost ? '♨️ Rear Window Defogger ON' : 'Rear Defogger OFF',
            failureMessage: '⚠️ Rear defogger command failed',
          );
        }
      },
    );
  }

  void _openWindowsControlSheet() {
    WindowsControlSheet.show(
      context,
      repository: widget.repository,
      telemetry: _telemetry,
      initialWindowsVented: _isWindowsVented,
      initialSunroofOpen: _telemetry.sunroofOpen,
      onWindowsChanged: (vented) {
        setState(() {
          _isWindowsVented = vented;
          _telemetry = _telemetry.copyWith(windowsOpen: vented);
        });
        _syncWidgetTelemetry();
      },
      onSunroofChanged: (isOpen) {
        setState(() {
          _telemetry = _telemetry.copyWith(sunroofOpen: isOpen);
        });
        _syncWidgetTelemetry();
      },
    );
  }

  // Sunroof now opens the same merged Windows & Sunroof sheet as the
  // windows pod — there is only one screen for door glass + roof glass +
  // sunshade, so the two Control Center pods both land in the same place.
  void _openSunroofControlSheet() => _openWindowsControlSheet();

  void _openWindowSunroofSheet() => _openWindowsControlSheet();

  void _openRemoteEngineSheet() {
    RemoteEngineSheet.show(
      context,
      telemetry: _telemetry,
      initialEngineOn: _telemetry.engineOn,
      onApply: (startEngine, runtimeMinutes) {
        final previousEngine = _telemetry.engineOn;
        setState(() {
          _telemetry = _telemetry.copyWith(engineOn: startEngine);
        });

        final opcode = startEngine ? CarLinkoOpcodes.engineStart : CarLinkoOpcodes.engineStop;
        _sendCommandAndReport(
          opcode,
          successMessage: startEngine
              ? '⚡ 1.5T Hybrid Engine started (${runtimeMinutes}m pre-warm)'
              : '⚡ 1.5T Hybrid Engine stopped',
          failureMessage: '⚠️ Engine command failed',
          onRevert: () {
            setState(() {
              _telemetry = _telemetry.copyWith(engineOn: previousEngine);
            });
          },
        );
      },
    );
  }

  /// Sends [command] to CarLinko and waits for the real result, instead of
  /// firing it and immediately assuming success. On failure, [onRevert]
  /// undoes whatever optimistic UI state was set and a real error is shown.
  Future<void> _sendCommandAndReport(
    String command, {
    required String successMessage,
    required String failureMessage,
    VoidCallback? onRevert,
  }) async {
    HapticFeedback.lightImpact();
    final result = await widget.repository.sendRemoteCommandWithResult(command);
    if (!mounted) return;
    if (result.success) {
      HapticFeedback.mediumImpact();
      final codeTag = (result.code != null && result.code != '0000') ? ' [${result.code}]' : '';
      _showNotification('$successMessage$codeTag • ${result.message ?? "Accepted"} (${result.latencyMs}ms)');
    } else {
      HapticFeedback.heavyImpact();
      onRevert?.call();
      final errDetail = (result.code != null && result.code!.isNotEmpty)
          ? ' [${result.code}: ${result.message ?? "Error"}]'
          : (result.message != null ? ' (${result.message})' : '');
      _showNotification('$failureMessage$errDetail', type: NotificationType.error);
    }
  }

  Future<void> _handleRemoteCommand(String action) async {
    if (!widget.repository.isVehicleBound) {
      _showNotification('⚠️ Pending Car Bind: Please connect and bind CarLinko to control vehicle.');
      _openCarlinkoConnect();
      return;
    }
    if (action == 'lock' || action == 'door_lock') {
      final willLock = action == 'door_lock' ? true : !_isDoorsLocked;
      final previous = _isDoorsLocked;
      setState(() => _isDoorsLocked = willLock);
      await _sendCommandAndReport(
        willLock ? CarLinkoOpcodes.lock : CarLinkoOpcodes.unlock,
        successMessage: willLock ? '🔒 Doors Locked' : '🔓 Doors Unlocked',
        failureMessage: '⚠️ Door command failed. Please retry.',
        onRevert: () => setState(() => _isDoorsLocked = previous),
      );
      _syncWidgetTelemetry();
    } else if (action == 'door_unlock') {
      final previous = _isDoorsLocked;
      setState(() => _isDoorsLocked = false);
      await _sendCommandAndReport(
        CarLinkoOpcodes.unlock,
        successMessage: '🔓 Doors Unlocked',
        failureMessage: '⚠️ Door command failed. Please retry.',
        onRevert: () => setState(() => _isDoorsLocked = previous),
      );
      _syncWidgetTelemetry();
    } else if (action == 'climate' || action == 'climate_on') {
      final willTurnOn = action == 'climate_on' ? true : !_isAcActive;
      final previous = _isAcActive;
      setState(() => _isAcActive = willTurnOn);
      await _sendCommandAndReport(
        willTurnOn ? CarLinkoOpcodes.acOn : CarLinkoOpcodes.acOff,
        successMessage: willTurnOn ? '❄️ Cabin Pre-cooling started (22°C)' : '❄️ Climate Pre-conditioning OFF',
        failureMessage: '⚠️ Climate command failed. Please retry.',
        onRevert: () => setState(() => _isAcActive = previous),
      );
      _syncWidgetTelemetry();
    } else if (action == 'climate_off') {
      final previous = _isAcActive;
      setState(() => _isAcActive = false);
      await _sendCommandAndReport(
        CarLinkoOpcodes.acOff,
        successMessage: '❄️ Climate Pre-conditioning OFF',
        failureMessage: '⚠️ Climate command failed. Please retry.',
        onRevert: () => setState(() => _isAcActive = previous),
      );
      _syncWidgetTelemetry();
    } else if (action == 'windows_open') {
      final previous = _isWindowsVented;
      setState(() => _isWindowsVented = true);
      await _sendCommandAndReport(
        CarLinkoOpcodes.windowsOpen,
        successMessage: '🪟 All 4 Windows opened',
        failureMessage: '⚠️ Window command failed. Please retry.',
        onRevert: () => setState(() => _isWindowsVented = previous),
      );
    } else if (action == 'windows_close') {
      final previous = _isWindowsVented;
      setState(() => _isWindowsVented = false);
      await _sendCommandAndReport(
        CarLinkoOpcodes.windowsClose,
        successMessage: '🪟 All Windows closed and secured',
        failureMessage: '⚠️ Window command failed. Please retry.',
        onRevert: () => setState(() => _isWindowsVented = previous),
      );
    } else if (action == 'windows' || action == 'windows_vent') {
      final previous = _isWindowsVented;
      final willVent = !_isWindowsVented;
      setState(() => _isWindowsVented = willVent);
      await _sendCommandAndReport(
        willVent ? CarLinkoOpcodes.windowsVent : CarLinkoOpcodes.windowsClose,
        successMessage: willVent ? '🪟 Windows vented (20mm)' : '🪟 All Windows closed',
        failureMessage: '⚠️ Window command failed. Please retry.',
        onRevert: () => setState(() => _isWindowsVented = previous),
      );
    } else if (action == 'sunroof_open') {
      await _sendCommandAndReport(
        CarLinkoOpcodes.sunroofOpen,
        successMessage: '☀️ Panoramic Sunroof opened',
        failureMessage: '⚠️ Sunroof command failed. Please retry.',
      );
    } else if (action == 'sunroof_close') {
      await _sendCommandAndReport(
        CarLinkoOpcodes.sunroofClose,
        successMessage: '☀️ Panoramic Sunroof closed',
        failureMessage: '⚠️ Sunroof command failed. Please retry.',
      );
    } else if (action == 'trunk' || action == 'trunk_open') {
      final previous = _isTrunkOpen;
      final willOpen = !_isTrunkOpen;
      setState(() => _isTrunkOpen = willOpen);
      await _sendCommandAndReport(
        willOpen ? CarLinkoOpcodes.trunkOpen : CarLinkoOpcodes.trunkClose,
        successMessage: willOpen ? '🚗 Power Tailgate opened' : '🚗 Tailgate closed',
        failureMessage: '⚠️ Trunk command failed. Please retry.',
        onRevert: () => setState(() => _isTrunkOpen = previous),
      );
    } else if (action == 'engine_start' || action == 'engine_stop') {
      final isStart = action == 'engine_start';
      await _sendCommandAndReport(
        isStart ? CarLinkoOpcodes.engineStart : CarLinkoOpcodes.engineStop,
        successMessage: isStart ? '⚡ Engine Start / Ignition command sent' : '🛑 Engine Stop command sent',
        failureMessage: '⚠️ Engine command failed. Please retry.',
      );
    } else if (action == 'defrost' || action == 'defrost_toggle') {
      final isCurrentlyActive = _telemetry.frontDefrost || _telemetry.rearDefrost;
      final willTurnOn = !isCurrentlyActive;
      final previousTelemetry = _telemetry;
      setState(() {
        _telemetry = _telemetry.copyWith(
          frontDefrost: willTurnOn,
          rearDefrost: willTurnOn,
          acOn: willTurnOn ? true : _telemetry.acOn,
        );
      });
      _syncWidgetTelemetry();
      await _sendCommandAndReport(
        willTurnOn ? CarLinkoOpcodes.defogOn : CarLinkoOpcodes.defogOff,
        successMessage: willTurnOn ? '💨 Front Defroster ON' : '💨 Defroster OFF',
        failureMessage: '⚠️ Defrost command failed. Please retry.',
        onRevert: () => setState(() => _telemetry = previousTelemetry),
      );
      if (willTurnOn) {
        await _sendCommandAndReport(
          CarLinkoOpcodes.rearDefogOn,
          successMessage: '♨️ Rear Window Defogger ON',
          failureMessage: '⚠️ Rear defogger command failed.',
        );
      } else {
        await _sendCommandAndReport(
          CarLinkoOpcodes.rearDefogOff,
          successMessage: 'Rear Defogger OFF',
          failureMessage: '⚠️ Rear defogger command failed.',
        );
      }
    } else if (action == 'schedule_charging') {
      _openSmartChargingSheet();
    } else if (action == 'check_tnb') {
      showDialog(
        context: context,
        builder: (ctx) => MyTnbConnectDialog(
          repository: MyTnbRepository(),
          currentTariff: widget.tnbTariff,
          onTariffUpdated: (r, a) {},
        ),
      );
    } else if (action == 'locate') {
      // Just open the locator — horn & flash is its own explicit action
      // inside the sheet (onHornFlash below), not something "Find Car"
      // should trigger by itself.
      VehicleRadarSheet.show(
        context,
        telemetry: _telemetry,
        repository: widget.repository,
        onHornFlash: () => _sendCommandAndReport(
          // The semantic strings ('locate', then 'vehicle_locate') both
          // failed with a real "parameter error" from CarLinko — the API
          // takes a raw opcode in a `data` field, not a command name at
          // all. Confirmed against ha-carlinko's own reference client:
          // OP_FIND_CAR = "740400".
          CarLinkoOpcodes.findCar,
          successMessage: '📢 Lights flashing & horn sounding',
          failureMessage: '⚠️ Locate command failed. Please retry.',
        ),
      );
    }
  }

  void _handleQuickActionUri(String uri) {
    if (uri.contains('/lock')) {
      _handleRemoteCommand('lock');
    } else if (uri.contains('/climate_sheet')) {
      _openClimateControlSheet();
    } else if (uri.contains('/climate')) {
      _handleRemoteCommand('climate');
    } else if (uri.contains('/charging')) {
      _openSmartChargingSheet();
    } else if (uri.contains('/radar') || uri.contains('/locate')) {
      _handleRemoteCommand('locate');
    } else if (uri.contains('/drive')) {
      SmartDriveHudSheet.show(context);
    } else if (uri.contains('/windows_sheet') || uri.contains('/sunroof')) {
      _openWindowSunroofSheet();
    } else if (uri.contains('/engine')) {
      _openRemoteEngineSheet();
    }
  }

  void _syncWidgetTelemetry() {
    final isBound = widget.repository.isVehicleBound;
    final values = HomeWidgetValues.fromTelemetry(_telemetry, isBound: isBound);
    HomeWidgetService.instance.syncWidgetTelemetry(
      vehicleName: widget.vehicleNickname.isNotEmpty ? widget.vehicleNickname : 'Tiggo 7 PHEV',
      isBound: isBound,
      batterySoc: values.batterySoc,
      batteryRange: values.batteryRange,
      fuelLevel: values.fuelLevel,
      fuelRange: values.fuelRange,
      totalRange: values.totalRange,
      isLocked: _isDoorsLocked,
      isCharging: _telemetry.isCharging,
      isClimateOn: _isAcActive,
    );
  }

  void _openSmartChargingSheet() {
    SmartChargingSheet.show(
      context,
      telemetry: _telemetry,
      isCharging: _telemetry.isCharging,
      scheduledCharging: _scheduledCharging,
      onToggleCharge: (newChargingState) {
        widget.repository.toggleCharging(newChargingState);
        _showNotification(newChargingState
            ? '⚡ AC Charging initiated (3.3 kW).'
            : '⏸ Charging paused.');
      },
      onSaveSchedule: (isScheduled, startTime, endTime, targetSoc, powerKw) {
        setState(() {
          _scheduledCharging = isScheduled;
        });
        widget.repository.setTargetSoc(targetSoc).then((ok) {
          if (ok) {
            _showNotification('🔋 Target SoC limit updated to $targetSoc% on Chery T-Box.');
          }
        }).catchError((_) {});

        final startMins = startTime.hour * 60 + startTime.minute;
        final endMins = endTime.hour * 60 + endTime.minute;
        final diffMins = endMins > startMins ? (endMins - startMins) : (24 * 60 - startMins + endMins);
        final durationHours = (diffMins / 60).round().clamp(1, 24);
        widget.repository.setBatterySchedule({
          'enabled': isScheduled,
          'hour': startTime.hour,
          'minute': startTime.minute,
          'duration': durationHours,
          'week': List<bool>.filled(7, true),
        }).then((ok) {
          if (ok) {
            _showNotification('🗓️ Cloud AC charge schedule synced (${durationHours}h window).');
          }
        }).catchError((_) {});

        final startHour = startTime.hourOfPeriod == 0 ? 12 : startTime.hourOfPeriod;
        final startMin = startTime.minute.toString().padLeft(2, '0');
        final startP = startTime.period == DayPeriod.am ? 'AM' : 'PM';
        final endHour = endTime.hourOfPeriod == 0 ? 12 : endTime.hourOfPeriod;
        final endMin = endTime.minute.toString().padLeft(2, '0');
        final endP = endTime.period == DayPeriod.am ? 'AM' : 'PM';
        if (isScheduled) {
          _showNotification(
            '⏰ Smart Charging active: $startHour:$startMin $startP – $endHour:$endMin $endP (Target: $targetSoc% SoC at ${powerKw.toStringAsFixed(1)} kW)',
          );
        } else {
          _showNotification('ℹ️ Scheduled charging turned off.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCyberDashboard(context);
  }

  String _syncAgeText() {
    final age = DateTime.now().difference(_telemetry.lastUpdated);
    if (age.inMinutes < 1) return '${age.inSeconds.clamp(0, 59)}s';
    if (age.inHours < 1) return '${age.inMinutes}m';
    return '${age.inHours}h';
  }

  /// @deprecated Legacy "Cyber" dashboard layout, superseded by
  /// [_buildSageDashboard]. Kept only because Settings exposes a
  /// "Sage Cockpit dashboard" switch that lets a user opt back into this
  /// layout; Sage is the default and the one new work should target. Do
  /// not add new features here — add them to the Sage build instead.
  Widget _buildCyberDashboard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = context.tokens;
    final bgCol = t.bg;
    final cardCol = t.resolvedContainerLow;
    final borderCol = t.border;
    final textMuted = t.ink2;
    final textPrimary = t.ink;
    final limeAccent = t.accent;
    const orangeAccent = Color(0xFFFF6E40);

    final isBound = widget.repository.isVehicleBound;
    final evRange = _telemetry.electricRangeKm;
    final fuelRange = _telemetry.fuelRangeKm;
    final fuelPct = (fuelRange / 838.0 * 100).round().clamp(0, 100);

    final totalRangeSum = (evRange + fuelRange) > 0 ? (evRange + fuelRange) : 1;
    final hasFuelRange = isBound && fuelRange > 0;
    final evFraction = hasFuelRange ? (evRange / totalRangeSum).clamp(0.05, 0.95) : 0.5;

    final totalRangeText = hasFuelRange ? '${_telemetry.totalRangeKm}' : '--';
    final evRangeText = isBound ? 'EV ${_telemetry.batteryPct}% · $evRange km' : 'EV --% · -- km';
    final fuelRangeText = hasFuelRange ? 'Fuel $fuelPct% · $fuelRange km' : 'Fuel --% · -- km';
    final evBarCol = isBound ? limeAccent : borderCol;
    final fuelBarCol = hasFuelRange ? orangeAccent : borderCol;
    const voltAccent = Color(0xFF58A6FF);

    // "LIVE" but every real reading came back empty (just a successful poll
    // with nothing in it, not an auth failure) — show that honestly instead
    // of a confident-looking "LIVE" badge over blank values.
    final looksEmptyWhileLive =
        isBound && evRange == 0 && fuelRange == 0 && _telemetry.volt12 <= 0 && _telemetry.odometerKm == 0;

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: RefreshIndicator(
          color: limeAccent,
          backgroundColor: cardCol,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            try {
              await widget.repository.refresh();
              if (context.mounted) {
                AppNotification.show(
                  context,
                  message: 'Vehicle status refreshed',
                  type: NotificationType.info,
                  icon: Icons.sync_rounded,
                );
              }
            } catch (e) {
              if (context.mounted) {
                AppNotification.show(
                  context,
                  message: 'Refresh failed: ${e.toString()}',
                  type: NotificationType.error,
                  icon: Icons.sync_problem_rounded,
                );
              }
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
            // 1. TOP HEADER: Equinox "Welcome back!" + Owner Name + Plate Badge + Status Badges + Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.vehicleNickname.isNotEmpty
                                  ? widget.vehicleNickname.toUpperCase()
                                  : 'CHERY TIGGO 7 PHEV CSH',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                                color: textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B202C) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: borderCol, width: 0.8),
                            ),
                            child: Text(
                              widget.carPlateNumber.isNotEmpty ? widget.carPlateNumber : 'VRT 3342',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: limeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Welcome, ${widget.ownerName.isNotEmpty && widget.ownerName != 'Chery Owner' ? widget.ownerName : 'MohdAfix'}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBluetoothStatusBadge(context, cardCol, borderCol, textPrimary, textMuted, limeAccent),
                    const SizedBox(width: 6),
                    _buildCellularSignalBadge(context, cardCol, borderCol, textPrimary, textMuted, limeAccent),
                    const SizedBox(width: 4),
                    // Bell icon
                    ListenableBuilder(
                      listenable: VehicleAlertsManager.instance,
                      builder: (context, _) {
                        final unread = VehicleAlertsManager.instance.unreadCount;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              tooltip: 'Vehicle Alerts & History',
                              icon: Icon(Icons.notifications_outlined, size: 21, color: textPrimary),
                              onPressed: () => VehicleAlertsSheet.show(context),
                            ),
                            if (unread > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: limeAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: bgCol, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 2),

                    // Menu icon (Burger)
                    PopupMenuButton<String>(
                      tooltip: 'Vehicle Tools & Settings',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(Icons.menu_rounded, size: 23, color: textPrimary),
                      color: cardCol,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: borderCol),
                      ),
                      onSelected: (val) {
                        switch (val) {
                          case 'voice_hud':
                            _openVoiceAssistant(startVoice: true);
                            break;
                          case 'skin_studio':
                            _showVehicleSkinStudioModal();
                            break;
                          case 'orbit_3d':
                            _show3DOrbitDialog();
                            break;
                          case 'hud':
                            SmartDriveHudSheet.show(context);
                            break;
                          case 'centres':
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const CheryServiceCentresScreen()),
                            );
                            break;
                          case 'location_history':
                            LocationHistorySheet.show(context);
                            break;
                          case 'diagnostics':
                            RemoteCommandDiagnosticsSheet.show(context, repository: widget.repository);
                            break;
                          case 'theme':
                            AppThemeController.instance.toggleTheme(context);
                            break;
                          case 'settings':
                            widget.onOpenSettings();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'voice_hud',
                          child: const Row(
                            children: [
                              Icon(Icons.graphic_eq_rounded, size: 18, color: Color(0xFF06B6D4)),
                              SizedBox(width: 10),
                              Text('AI Voice Assistant', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'skin_studio',
                          child: Row(
                            children: [
                              Icon(Icons.palette_outlined, size: 18, color: limeAccent),
                              const SizedBox(width: 10),
                              const Text('Vehicle Paint Studio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'orbit_3d',
                          child: Row(
                            children: [
                              Icon(Icons.view_in_ar_outlined, size: 18, color: textMuted),
                              const SizedBox(width: 10),
                              const Text('3D Orbit Viewer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'hud',
                          child: Row(
                            children: [
                              Icon(Icons.speed_outlined, size: 18, color: textMuted),
                              const SizedBox(width: 10),
                              const Text('Smart Drive Mode HUD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'centres',
                          child: Row(
                            children: [
                              Icon(Icons.storefront_outlined, size: 18, color: textMuted),
                              const SizedBox(width: 10),
                              const Text('Chery Service Centres', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'location_history',
                          child: Row(
                            children: [
                              Icon(Icons.location_history, size: 18, color: textMuted),
                              const SizedBox(width: 10),
                              const Text('Location History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'diagnostics',
                          child: Row(
                            children: [
                              const Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF00E5FF)),
                              const SizedBox(width: 10),
                              const Text('Remote CAN Opcode Tester', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'theme',
                          child: Row(
                            children: [
                              Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined, size: 18, color: textMuted),
                              const SizedBox(width: 10),
                              Text(isDark ? 'Light Theme' : 'Dark Theme', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined, size: 18, color: textMuted),
                              const SizedBox(width: 10),
                              const Text('Settings & Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. STATUS CAPSULE
            GestureDetector(
              onTap: _openCarlinkoConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: looksEmptyWhileLive ? const Color(0xFFFFB74D).withValues(alpha: 0.6) : borderCol,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: !isBound || looksEmptyWhileLive ? const Color(0xFFFFB74D) : limeAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              !isBound
                                  ? 'Pending Car Bind · Awaiting VIN pairing'
                                  : looksEmptyWhileLive
                                      ? 'LIVE · No data this sync'
                                      : 'LIVE · synced ${_syncAgeText()} ago',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: !isBound || looksEmptyWhileLive ? const Color(0xFFFFB74D) : textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isBound || looksEmptyWhileLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: limeAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'RECONNECT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A0B0E),
                          ),
                        ),
                      )
                    else
                      Text(
                        _telemetry.isParked ? 'P · Parked' : 'D · Driving',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. SWIPEABLE CAR VIEW CAROUSEL (Vehicle Livery → TPMS → 3D Orbit View)
            CarViewCarousel(
              telemetry: _telemetry,
              isBound: isBound,
              accentColor: limeAccent,
              selectedSkinKey: _selectedVehicleColorKey,
              initialPage: _carViewPage,
              onPageChanged: (i) => _carViewPage = i, // no setState needed
              onCarTap: _openVehicleDetailsSheet,
            ),
            const SizedBox(height: 18),

            // 4. MODERN OEM SPLIT ROW: Total Range Card + Live Location Mini Map Tile
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Card: Equinox "My Vehicle" Dual Energy Card
                  Expanded(
                    flex: 11,
                    child: GestureDetector(
                      onTap: _openVehicleDetailsSheet,
                      child: Container(
                        height: 104,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardCol,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'TOTAL RANGE',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right, size: 14, color: limeAccent),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                    children: [
                                      TextSpan(text: totalRangeText),
                                      TextSpan(
                                        text: ' km',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              isBound ? 'Everything looks good' : 'Pending car link',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),

                            // Dual Split Range Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 8,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: (evFraction * 100).round(),
                                      child: Container(color: evBarCol),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      flex: ((1.0 - evFraction) * 100).round(),
                                      child: Container(color: fuelBarCol),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Sub-row: ■ EV 24% · 22 km    ■ Fuel 71% · 664 km (Auto-scaling to prevent pixel overflow)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(color: evBarCol, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        evRangeText,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isBound ? evBarCol : textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(color: fuelBarCol, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        fuelRangeText,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: hasFuelRange ? fuelBarCol : textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right Card: Mini Live Map Tile with Real FlutterMap & Fallback (Chevy Equinox / Mazda Style)
                  Expanded(
                    flex: 6,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        VehicleRadarSheet.show(
                          context,
                          telemetry: _telemetry,
                          repository: widget.repository,
                        );
                      },
                      child: Container(
                        height: 104,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: cardCol,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderCol),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // 1. Live FlutterMap Render (Configurable Detailed Dark / Sat / Day)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ValueListenableBuilder<TiggoMapStyle>(
                                  valueListenable: TiggoMapConfig.activeStyle,
                                  builder: (context, mapStyle, _) {
                                    return mapStyle.wrapMap(
                                      FlutterMap(
                                        key: ValueKey('mini_map_${mapStyle.name}'),
                                        options: MapOptions(
                                          initialCenter: LatLng(
                                            _telemetry.hasLocation ? _telemetry.latitude : 3.1272,
                                            _telemetry.hasLocation ? _telemetry.longitude : 101.6600,
                                          ),
                                          initialZoom: 15.0,
                                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate: mapStyle.urlTemplate,
                                            userAgentPackageName: 'com.tiggomate.tiggomate_app',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // 2. Subtle translucent gradient scrim so street details shine through while pin & badge pop
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      cardCol.withValues(alpha: 0.15),
                                      Colors.transparent,
                                      cardCol.withValues(alpha: 0.45),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // 3. Center Glowing Vehicle Pin
                            Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: limeAccent.withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: limeAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: limeAccent.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.directions_car, size: 8, color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 4. Clean Overlay Metadata
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'MAP',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: limeAccent,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.near_me_rounded, size: 10, color: limeAccent),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: isBound
                                                ? (_telemetry.isParked ? const Color(0xFF4ADE80) : limeAccent)
                                                : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isBound ? (_telemetry.isParked ? 'Parked' : 'Driving') : 'Offline',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '›',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: limeAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isBound) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showRawHexDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderCol.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('Energy consumption', style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: textMuted)),
                              const SizedBox(width: 4),
                              Icon(Icons.touch_app_outlined, size: 11, color: textMuted),
                            ],
                          ),
                          Text(
                            _telemetry.energyConsumptionKwh100km != 0
                                ? '${_telemetry.energyConsumptionKwh100km.toStringAsFixed(2)} kWh/100km'
                                : '-- kWh/100km',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: evBarCol),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fuel consumption', style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: textMuted)),
                          Text(
                            _telemetry.fuelConsumptionL100km > 0
                                ? '${_telemetry.fuelConsumptionL100km.toStringAsFixed(2)} L/100km'
                                : '-- L/100km',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: fuelBarCol),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: () => _showBatteryHealthModal(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('Voltage', style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: textMuted)),
                                const SizedBox(width: 4),
                                Icon(Icons.info_outline, size: 11, color: voltAccent),
                              ],
                            ),
                            Text(
                              _telemetry.volt12 > 0
                                  ? '${_telemetry.volt12.toStringAsFixed(2)} V'
                                  : '-- V',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: voltAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.battery_charging_full, size: 12, color: textMuted),
                  const SizedBox(width: 4),
                  Text('12V Aux: -- V', style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.w700, color: textMuted)),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // 5. EQUINOX CONTROL CENTER: 8 TACTILE ACTION PODS (4x2 GRID)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control Center',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Remote controls',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  'QUICK ACTIONS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    letterSpacing: 0.8,
                    color: textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 1 (4 Pods: Doors, Climate, Windows, Trunk)
            Row(
              children: [
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'DOORS',
                    value: !isBound ? '--' : (_isDoorsLocked ? 'Locked' : 'Unlocked'),
                    isActive: isBound && _isDoorsLocked,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: () => _handleRemoteCommand('lock'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'CLIMATE',
                    value: !isBound ? '--' : (_isAcActive ? '${_telemetry.acTemp.clamp(16, 32)}°C' : 'Off → 22°'),
                    isActive: _isAcActive,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: _openClimateControlSheet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'WINDOWS',
                    value: !isBound ? '--' : (_isWindowsVented ? 'Vented' : 'Closed'),
                    isActive: _isWindowsVented,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: _openWindowsControlSheet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'TRUNK',
                    value: !isBound ? '--' : (_isTrunkOpen ? 'Open' : 'Closed'),
                    isActive: _isTrunkOpen,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: () => _handleRemoteCommand('trunk'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2 (4 Pods: Locate, Sunroof, Defrost, Engine)
            Row(
              children: [
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'LOCATE',
                    value: isBound ? 'Horn/Flash' : '--',
                    isActive: false,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: () => _handleRemoteCommand('locate'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'SUNROOF',
                    value: !isBound ? '--' : (_telemetry.sunroofOpen ? 'Open' : 'Closed'),
                    isActive: _telemetry.sunroofOpen,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: _openSunroofControlSheet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'DEFROST',
                    value: !isBound ? '--' : ((_telemetry.frontDefrost || _telemetry.rearDefrost) ? 'Active' : 'Off'),
                    isActive: _telemetry.frontDefrost || _telemetry.rearDefrost,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: _openDefrostSheet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildEquinoxRemotePod(
                    title: 'ENGINE',
                    value: !isBound ? '--' : (_telemetry.engineOn ? 'Running' : 'Pre-cool'),
                    isActive: _telemetry.engineOn,
                    limeAccent: limeAccent,
                    cardCol: cardCol,
                    borderCol: borderCol,
                    textMuted: textMuted,
                    textPrimary: textPrimary,
                    onTap: _openRemoteEngineSheet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tactile Slide to Start Ignition Slider (Modern OEM)
            _ModernSlideToStartBar(
              limeAccent: limeAccent,
              cardCol: cardCol,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textMuted: textMuted,
              onSlideComplete: () {
                HapticFeedback.heavyImpact();
                _openRemoteEngineSheet();
              },
            ),
            const SizedBox(height: 16),

            // 6. BOTTOM AI COMMAND PROMPT BAR -- deep-links into the merged
            // Assistant tab instead of opening a separate chat sheet.
            GestureDetector(
              onTap: () => _openVoiceAssistant(startVoice: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Text('›  ', style: TextStyle(color: limeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          Flexible(
                            child: Text(
                              'Ask or command — "cool cabin to 22°"',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                color: textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // DasHub-Style Voice Assistant Mic Action
                    GestureDetector(
                      onTap: () => _openVoiceAssistant(startVoice: true),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          size: 16,
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ASK',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildBluetoothStatusBadge(
    BuildContext context,
    Color cardCol,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
    Color limeAccent,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        BluetoothDrivingTrackerService.instance,
        CarLinkoBleController(),
      ]),
      builder: (context, _) {
        final ble = CarLinkoBleController();
        final isBleConnected = ble.isConnected;
        final isBleScanning = ble.isScanning;
        final isClassicConnected = BluetoothDrivingTrackerService.instance.isCarConnected;

        // Royal electric blue when BLE is actively connected (like CarLinko)
        const bleBlue = Color(0xFF2979FF);
        const cyberCyan = Color(0xFF00E5FF);
        const scanAmber = Color(0xFFFFB74D);

        final Color activeCol;
        final String label;
        final String tooltip;
        final bool isAnyConnected;

        if (isBleConnected) {
          activeCol = bleBlue;
          label = 'BLE';
          tooltip = 'Chery BLE: Connected (<10m Proximity Active) • Direct CAN Actuation Armed';
          isAnyConnected = true;
        } else if (isBleScanning) {
          activeCol = scanAmber;
          label = 'SCAN';
          tooltip = 'Chery BLE: Scanning for vehicle Nordic UART...';
          isAnyConnected = false;
        } else if (isClassicConnected) {
          activeCol = cyberCyan;
          label = 'BT';
          tooltip = 'Chery Bluetooth: Connected (${BluetoothDrivingTrackerService.instance.connectedCarName ?? 'Chery Tiggo'})';
          isAnyConnected = true;
        } else {
          activeCol = textMuted;
          label = 'BLE';
          tooltip = 'Chery BLE: Standby (Tap to Scan & Connect)';
          isAnyConnected = false;
        }

        return Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showBluetoothConnectionStatusModal(context),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: isAnyConnected
                      ? activeCol.withValues(alpha: 0.14)
                      : (isBleScanning ? scanAmber.withValues(alpha: 0.12) : cardCol),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAnyConnected
                        ? activeCol.withValues(alpha: 0.7)
                        : (isBleScanning ? scanAmber.withValues(alpha: 0.5) : borderCol),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBleScanning)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: scanAmber,
                        ),
                      )
                    else
                      Icon(
                        isAnyConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                        size: 16,
                        color: activeCol,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: activeCol,
                      ),
                    ),
                    if (isAnyConnected) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: activeCol,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCellularSignalBadge(
    BuildContext context,
    Color cardCol,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
    Color limeAccent,
  ) {
    final isBound = widget.repository.isVehicleBound;
    final isCloud = widget.repository.isCloudConnected;
    final bars = _telemetry.effectiveCellularBars;
    final hasHwSignal = _telemetry.cellularSignalBars != null;

    const cyberCyan = Color(0xFF00E5FF);
    final signalColor = bars >= 3
        ? cyberCyan
        : (bars >= 2 ? const Color(0xFFFFB74D) : (bars == 1 ? Colors.orangeAccent : textMuted));

    final tooltipMsg = isBound
        ? (hasHwSignal
            ? 'Telematics 4G LTE: ${bars}/4 bars (${_telemetry.cellularQualityLabel})${_telemetry.cellularCsq != null ? ' • CSQ ${_telemetry.cellularCsq}' : ''} • Live T-Box'
            : 'Telematics 4G LTE: Connected ($bars/4 bars) • Synced ${_syncAgeText()} ago')
        : 'Telematics: Awaiting car bind';

    return Tooltip(
      message: tooltipMsg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCellularSignalStatusModal(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: cardCol,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isBound ? signalColor.withValues(alpha: 0.45) : borderCol,
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(4, (index) {
                    final barHeight = 4.0 + (index * 2.5);
                    final isLit = index < bars;
                    return Container(
                      width: 2.3,
                      height: barHeight,
                      margin: EdgeInsets.only(right: index < 3 ? 1.5 : 0),
                      decoration: BoxDecoration(
                        color: isLit ? signalColor : textMuted.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  '4G',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isBound ? textPrimary : textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBluetoothConnectionStatusModal(BuildContext context) {
    final t = context.tokens;
    final bgCol = t.resolvedContainerLow;
    final cardCol = t.surface;
    final borderCol = t.border;
    final textPrimary = t.ink;
    final textMuted = t.ink2;
    const cyberCyan = Color(0xFF00E5FF);
    final limeAccent = t.accent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgCol,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            BluetoothDrivingTrackerService.instance,
            CarLinkoBleController(),
          ]),
          builder: (ctx, _) {
            final ble = CarLinkoBleController();
            final isBleConnected = ble.isConnected;
            final isBleScanning = ble.isScanning;
            final isClassicConnected = BluetoothDrivingTrackerService.instance.isCarConnected;
            final carName = ble.connectedDeviceName ?? BluetoothDrivingTrackerService.instance.connectedCarName ?? 'Chery Tiggo 7 Pro';

            const bleBlue = Color(0xFF2979FF);
            const scanAmber = Color(0xFFFFB74D);
            final statusColor = isBleConnected ? bleBlue : (isBleScanning ? scanAmber : (isClassicConnected ? cyberCyan : textMuted));

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderCol,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          isBleConnected || isClassicConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DUAL-LINK BLUETOOTH',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: textMuted,
                              ),
                            ),
                            Text(
                              isBleConnected
                                  ? 'Direct BLE Connected (<10m)'
                                  : (isBleScanning ? 'Scanning for Vehicle BLE...' : (isClassicConnected ? 'Classic BT Linked' : 'Bluetooth Standby')),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          isBleConnected ? 'BLE ACTIVE' : (isBleScanning ? 'SCANNING' : (isClassicConnected ? 'BT ACTIVE' : 'STANDBY')),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // BLE Connection Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isBleConnected ? bleBlue.withValues(alpha: 0.5) : borderCol,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 16, color: isBleConnected ? bleBlue : textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Chery Nordic NUS BLE',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isBleConnected ? bleBlue : textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              isBleConnected ? 'LINKED (<50ms)' : (isBleScanning ? 'SEARCHING' : 'READY'),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isBleConnected ? bleBlue : (isBleScanning ? scanAmber : textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(color: borderCol.withValues(alpha: 0.5), height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service UUID', style: TextStyle(fontSize: 12, color: textMuted)),
                            Text(
                              '6e400001 (NUS)',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: cyberCyan,
                              ),
                            ),
                          ],
                        ),
                        if (isBleConnected && ble.connectedDeviceId != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Device MAC / ID', style: TextStyle(fontSize: 12, color: textMuted)),
                              Text(
                                ble.connectedDeviceId!,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (!isBleConnected) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isBleScanning
                                      ? () => ble.stopScan()
                                      : () => ble.startScan(
                                            timeoutSeconds: 12,
                                            targetDeviceName: BluetoothDrivingTrackerService.instance.connectedCarName,
                                          ),
                                  icon: isBleScanning
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.bluetooth_searching_rounded, size: 15),
                                  label: Text(isBleScanning ? 'Stop' : 'Scan BLE'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bleBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => ble.directConnect(),
                                  icon: const Icon(Icons.flash_on_rounded, size: 15),
                                  label: const Text('Direct Connect (NUS)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: limeAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'CarLinko holds exclusive BLE link. If CarLinko is open, force-close it so the car can connect to TiggoMate.',
                                    style: const TextStyle(fontSize: 10, color: Colors.amber, height: 1.25),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ble.disconnect(),
                                  icon: const Icon(Icons.bluetooth_disabled_rounded, size: 15),
                                  label: const Text('Disconnect'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textMuted,
                                    side: BorderSide(color: borderCol),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ok = await ble.sendCommand(CarLinkoBleOpcodes.lock);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? '🔒 Doors Locked (Direct BLE)' : 'BLE Lock failed'),
                                          backgroundColor: ok ? bleBlue : Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.lock_rounded, size: 15),
                                  label: const Text('BLE Lock'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: bleBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ok = await ble.sendCommand(CarLinkoBleOpcodes.unlock);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? '🔓 Doors Unlocked (Direct BLE)' : 'BLE Unlock failed'),
                                          backgroundColor: ok ? limeAccent : Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.lock_open_rounded, size: 15),
                                  label: const Text('BLE Unlock'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: limeAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ok = await ble.sendCommand(CarLinkoBleOpcodes.trunkOpen);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? '🚗 Power Tailgate Triggered (Encrypted BLE)' : 'BLE Tailgate failed'),
                                          backgroundColor: ok ? bleBlue : Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.sensor_door_rounded, size: 15),
                                  label: const Text('BLE Tailgate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: borderCol),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ok = await ble.sendCommand(CarLinkoBleOpcodes.findCar);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? '📢 Horn & Lights Triggered (Encrypted BLE)' : 'BLE Search failed'),
                                          backgroundColor: ok ? bleBlue : Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.campaign_rounded, size: 15),
                                  label: const Text('BLE Find Car'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: borderCol),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 13, color: limeAccent),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '⚡ Direct BLE connected (<50ms). Actuation signals route directly to car via AES-256 encrypted Bluetooth.',
                                  style: TextStyle(fontSize: 10.5, color: textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isBleConnected && ble.discoveredDevices.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Divider(color: borderCol.withValues(alpha: 0.5), height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DISCOVERED BLUETOOTH DEVICES (${ble.discoveredDevices.length})',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: textMuted,
                                ),
                              ),
                              if (isBleScanning)
                                Text(
                                  'Scanning...',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: scanAmber,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: ble.discoveredDevices.length,
                              separatorBuilder: (_, __) => Divider(color: borderCol.withValues(alpha: 0.3), height: 6),
                              itemBuilder: (c, idx) {
                                final d = ble.discoveredDevices[idx];
                                final advName = d.advertisementData.advName;
                                final dName = advName.isNotEmpty ? advName : (d.device.platformName.isNotEmpty ? d.device.platformName : 'Peripheral');
                                final isLikelyCar = dName.toLowerCase().contains('chery') ||
                                    dName.toLowerCase().contains('tiggo') ||
                                    dName.toLowerCase().contains('tbox') ||
                                    dName.toLowerCase().contains('cqr') ||
                                    dName.toLowerCase().contains('vrt') ||
                                    (BluetoothDrivingTrackerService.instance.connectedCarName != null &&
                                        dName.toLowerCase().contains(BluetoothDrivingTrackerService.instance.connectedCarName!.toLowerCase()));

                                return Row(
                                  children: [
                                    Icon(
                                      isLikelyCar ? Icons.directions_car_filled_rounded : Icons.bluetooth_rounded,
                                      size: 16,
                                      color: isLikelyCar ? cyberCyan : textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isLikelyCar ? FontWeight.w700 : FontWeight.w500,
                                              color: isLikelyCar ? cyberCyan : textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${d.device.remoteId.str} • ${d.rssi} dBm',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 9.5,
                                              color: textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: () => ble.connectToDevice(d.device),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isLikelyCar ? bleBlue : borderCol,
                                          foregroundColor: isLikelyCar ? Colors.white : textPrimary,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5),
                                        ),
                                        child: const Text('Connect'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Classic BT Tracking Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Auto-Trip & Parking Drop', style: TextStyle(fontSize: 12, color: textMuted)),
                            Text(
                              isClassicConnected ? 'Monitoring · Armed' : 'Armed on Connect',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isClassicConnected ? limeAccent : textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isClassicConnected
                              ? 'Connected to $carName via Bluetooth Audio. Auto-trip log & parking GPS drop armed.'
                              : 'Pairs when driving to prevent phone Doze and track trips without cloud latency.',
                          style: TextStyle(fontSize: 11.5, color: textMuted, height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            RemoteCommandDiagnosticsSheet.show(context, repository: widget.repository);
                          },
                          icon: const Icon(Icons.terminal_rounded, size: 16),
                          label: const Text('CAN Opcode Tester'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00E5FF),
                            side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            widget.onOpenSettings();
                          },
                          icon: const Icon(Icons.settings_bluetooth_rounded, size: 16),
                          label: const Text('BT Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBleConnected ? bleBlue : (isClassicConnected ? cyberCyan : limeAccent),
                            foregroundColor: const Color(0xFF0A0B0E),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCellularSignalStatusModal(BuildContext context) {
    final t = context.tokens;
    final bgCol = t.resolvedContainerLow;
    final cardCol = t.surface;
    final borderCol = t.border;
    final textPrimary = t.ink;
    final textMuted = t.ink2;
    const cyberCyan = Color(0xFF00E5FF);
    final limeAccent = t.accent;

    final isBound = widget.repository.isVehicleBound;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgCol,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderCol,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isBound ? cyberCyan : const Color(0xFFFFB74D)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isBound ? cyberCyan : const Color(0xFFFFB74D)).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Image.asset(
                      _telemetry.networkIconAsset,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.cell_tower_rounded,
                        color: isBound ? cyberCyan : const Color(0xFFFFB74D),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'T-BOX 4G TELEMATICS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: textMuted,
                          ),
                        ),
                        Text(
                          isBound
                              ? '${_telemetry.effectiveCellularBars}/4 Bars • ${_telemetry.cellularQualityLabel}'
                              : 'Awaiting Car Bind',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isBound ? limeAccent : const Color(0xFFFFB74D)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isBound ? limeAccent : const Color(0xFFFFB74D),
                      ),
                    ),
                    child: Text(
                      isBound ? 'ONLINE' : 'UNBOUND',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isBound ? limeAccent : const Color(0xFFFFB74D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Actual Signal Strength', style: TextStyle(fontSize: 12, color: textMuted)),
                        Row(
                          children: [
                            Image.asset(
                              _telemetry.networkIconAsset,
                              width: 16,
                              height: 16,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isBound
                                  ? '${_telemetry.effectiveCellularBars}/4 Bars (${_telemetry.cellularQualityLabel})'
                                  : 'No Signal',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _telemetry.effectiveCellularBars >= 3
                                    ? cyberCyan
                                    : (_telemetry.effectiveCellularBars == 2 ? const Color(0xFFFFB74D) : textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_telemetry.cellularCsq != null) ...[
                      const SizedBox(height: 8),
                      Divider(color: borderCol.withValues(alpha: 0.5), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Modem CSQ Level', style: TextStyle(fontSize: 12, color: textMuted)),
                          Text(
                            'CSQ ${_telemetry.cellularCsq} (~${-113 + (_telemetry.cellularCsq! * 2)} dBm)',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cyberCyan,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Divider(color: borderCol.withValues(alpha: 0.5), height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hardware Source', style: TextStyle(fontSize: 12, color: textMuted)),
                        Text(
                          _telemetry.cellularSignalBars != null ? 'T-Box Live CSQ / Telematics' : 'Cloud Sync Freshness',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: borderCol.withValues(alpha: 0.5), height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cloud Sync Status', style: TextStyle(fontSize: 12, color: textMuted)),
                        Text(
                          isBound ? 'Synced ${_syncAgeText()} ago' : 'No Sync',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isBound ? limeAccent : textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: borderCol.withValues(alpha: 0.5), height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('T-Box Data Pipeline', style: TextStyle(fontSize: 12, color: textMuted)),
                        Text(
                          '73-Byte CAN Blob',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cyberCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: borderCol.withValues(alpha: 0.5), height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vehicle Plate / ID', style: TextStyle(fontSize: 12, color: textMuted)),
                        Text(
                          widget.carPlateNumber.isNotEmpty ? widget.carPlateNumber : 'VRT 3342',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        RemoteCommandDiagnosticsSheet.show(context, repository: widget.repository);
                      },
                      icon: const Icon(Icons.terminal_rounded, size: 16),
                      label: const Text('CAN Opcode Tester'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00E5FF),
                        side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          await widget.repository.refresh();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vehicle telematics refreshed via 4G cloud'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sync failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sync Telematics'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: limeAccent,
                        foregroundColor: const Color(0xFF0A0B0E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForRemoteTitle(String title, bool isActive) {
    switch (title.toUpperCase()) {
      case 'DOORS':
        return isActive ? Icons.lock_rounded : Icons.lock_open_rounded;
      case 'CLIMATE':
        return isActive ? Icons.ac_unit_rounded : Icons.mode_fan_off_rounded;
      case 'WINDOWS':
        return Icons.vertical_split_rounded;
      case 'TRUNK':
        return Icons.luggage_outlined;
      case 'LOCATE':
        return Icons.campaign_rounded;
      case 'SUNROOF':
        return Icons.wb_twilight_rounded;
      case 'DEFROST':
        return Icons.waves_rounded;
      case 'ENGINE':
        return Icons.power_settings_new_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  Widget _buildEquinoxRemotePod({
    required String title,
    required String value,
    required bool isActive,
    required Color limeAccent,
    required Color cardCol,
    required Color borderCol,
    required Color textMuted,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    final materialIcon = _iconForRemoteTitle(title, isActive);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 86,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? limeAccent.withValues(alpha: 0.7) : borderCol,
            width: isActive ? 1.3 : 0.9,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: limeAccent.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? limeAccent.withValues(alpha: 0.18)
                    : (cardCol.computeLuminance() < 0.5 ? const Color(0xFF1E232E) : const Color(0xFFE2E8F0)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? limeAccent : borderCol.withValues(alpha: 0.7),
                  width: isActive ? 1.4 : 0.8,
                ),
              ),
              child: Center(
                child: Icon(
                  materialIcon,
                  size: 17,
                  color: isActive ? limeAccent : textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 8.0,
                fontWeight: FontWeight.w500,
                color: isActive ? limeAccent : textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _show3DOrbitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: 380,
          decoration: BoxDecoration(
            color: const Color(0xFF12141A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E222B)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('3D Orbit Perspective', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: ModelViewer(
                    src: 'assets/models/tiggo7.glb',
                    alt: 'Chery Tiggo 7 PHEV CSH 3D Model',
                    ar: false,
                    autoRotate: true,
                    autoRotateDelay: 2000,
                    rotationPerSecond: '20deg',
                    cameraControls: true,
                    backgroundColor: const Color(0xFF0A0B0E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCarLinkoEnergyCard(AppColors colors) {
    return InkWell(
      onTap: () => _showRawHexDialog(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.tileBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Energy consumption',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                Text(
                  _telemetry.energyConsumptionKwh100km != 0
                      ? '${_telemetry.energyConsumptionKwh100km.toStringAsFixed(2)} kWh/100km'
                      : '-- kWh/100km',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Divider(height: 1, thickness: 0.6, color: colors.borderSubtle),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fuel consumption',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              Text(
                _telemetry.fuelConsumptionL100km > 0
                    ? '${_telemetry.fuelConsumptionL100km.toStringAsFixed(2)} L/100km'
                    : '-- L/100km',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Divider(height: 1, thickness: 0.6, color: colors.borderSubtle),
          ),
          InkWell(
            onTap: () => _showBatteryHealthModal(context),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Voltage',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline, size: 13, color: colors.evTeal),
                  ],
                ),
                Text(
                  _telemetry.volt12 > 0
                      ? '${_telemetry.volt12.toStringAsFixed(2)} V'
                      : '-- V',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  void _showBatteryHealthModal(BuildContext context) {
    final colors = AppColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final battService = BatteryHealthService.instance;
    final voltStatus = battService.getVolt12Status(_telemetry.volt12);
    final min7d = battService.getMinVolt12Last7Days(_telemetry.volt12);
    final socDrain = battService.parkedSocDrainPerDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final curLfpStatus = battService.lfpStatus;
            final curDaysSince100 = battService.daysSinceLast100;

            Color voltColor;
            switch (voltStatus) {
              case Volt12HealthStatus.healthy:
                voltColor = const Color(0xFF10B981);
                break;
              case Volt12HealthStatus.fair:
                voltColor = const Color(0xFFF59E0B);
                break;
              case Volt12HealthStatus.low:
                voltColor = const Color(0xFFF97316);
                break;
              case Volt12HealthStatus.critical:
                voltColor = const Color(0xFFEF4444);
                break;
            }

            Color lfpColor;
            switch (curLfpStatus) {
              case LfpBalanceStatus.balanced:
                lfpColor = const Color(0xFF10B981);
                break;
              case LfpBalanceStatus.dueSoon:
                lfpColor = const Color(0xFFF59E0B);
                break;
              case LfpBalanceStatus.overdue:
                lfpColor = const Color(0xFFEF4444);
                break;
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.battery_saver_rounded, color: colors.evTeal, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Battery & Cell Health Guardian',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. 12V Auxiliary Battery Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.tileBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: voltColor.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bolt, size: 18, color: voltColor),
                                const SizedBox(width: 6),
                                Text(
                                  '12V Auxiliary Battery',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: voltColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                voltStatus.label.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: voltColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Live Voltage', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  _telemetry.volt12 > 0 ? '${_telemetry.volt12.toStringAsFixed(2)} V' : '-- V',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: voltColor),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('7-Day Lowest', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  '${min7d.toStringAsFixed(2)} V',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Parked Drain', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  socDrain != null
                                      ? '${socDrain.toStringAsFixed(1)}% / day'
                                      : 'Normal (<1%)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Powers T-Box 4G modem & hybrid startup contactors. Healthy resting voltage is 12.4V - 12.8V.',
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. LFP Traction Pack Cell Balancing Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.tileBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: lfpColor.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.balance_rounded, size: 18, color: lfpColor),
                                const SizedBox(width: 6),
                                Text(
                                  'LFP Cell Balance (18.3 kWh)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: lfpColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                curLfpStatus.label.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: lfpColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Last 100% Top-Off', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  curDaysSince100 == 0 ? 'Today' : '$curDaysSince100 days ago',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: lfpColor),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.evTeal.withValues(alpha: 0.15),
                                foregroundColor: colors.evTeal,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                await battService.mark100PercentChargedNow();
                                setModalState(() {});
                                if (context.mounted) {
                                  AppNotification.show(
                                    context,
                                    message: '✅ Marked 100% LFP charge & cell balance today!',
                                    type: NotificationType.success,
                                    icon: Icons.check_circle_rounded,
                                  );
                                }
                              },
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Mark 100% Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chery Tiggo 7 PHEV uses LFP chemistry. Because LFP voltage is flat between 20-80%, charge to 100% on AC once a week so the BMS can top-balance individual cells.',
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRawHexDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hex = _telemetry.rawBlobHex ?? prefs.getString('tm_last_raw_hex') ?? '';

    if (hex.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: hex));
      if (context.mounted) {
        AppNotification.show(
          context,
          message: '📋 Hex copied to clipboard (${hex.length} chars)',
          type: NotificationType.success,
          icon: Icons.copy_rounded,
        );
      }
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.terminal, color: Color(0xFFD2F835), size: 20),
            SizedBox(width: 8),
            Text('Live T-Box Telematics Hex', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '73-byte CAN-bus telemetry payload from your car:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: SelectableText(
                hex.isNotEmpty ? hex : 'No raw hex captured yet. Pull to refresh dashboard.',
                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF38BDF8), fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          if (hex.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hex));
                Navigator.of(ctx).pop();
                AppNotification.show(
                  context,
                  message: '📋 Copied hex to clipboard!',
                  type: NotificationType.success,
                  icon: Icons.copy_rounded,
                );
              },
              icon: const Icon(Icons.copy, size: 16, color: Color(0xFFD2F835)),
              label: const Text('Copy Again', style: TextStyle(color: Color(0xFFD2F835), fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

}

/// -------------------------------------------------------------
/// OFFICIAL VEHICLE PAINT & SKIN STUDIO SHEET
/// -------------------------------------------------------------
class _VehicleSkinStudioSheet extends StatefulWidget {
  final String selectedSkinKey;
  final ValueChanged<String> onSkinSelected;

  const _VehicleSkinStudioSheet({
    required this.selectedSkinKey,
    required this.onSkinSelected,
  });

  @override
  State<_VehicleSkinStudioSheet> createState() => _VehicleSkinStudioSheetState();
}

class _VehicleSkinStudioSheetState extends State<_VehicleSkinStudioSheet> {
  late String _activeKey;

  @override
  void initState() {
    super.initState();
    _activeKey = widget.selectedSkinKey;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final activeSkin = getVehicleSkinByKey(_activeKey);

    return Container(
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF0D1219) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.palette, color: colors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle Paint & Skin Studio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Chery Tiggo 7 PHEV Malaysian Exterior Colors',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Vehicle Preview Stage
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0xFF131922) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floor shadow
                Positioned(
                  bottom: 14,
                  child: Container(
                    width: 240,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.elliptical(240, 12)),
                      gradient: RadialGradient(
                        colors: [
                          colors.isDark ? Colors.black.withValues(alpha: 0.75) : Colors.black.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  bottom: 18,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: Image.asset(
                      activeSkin.assetPath,
                      key: ValueKey(activeSkin.key),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.directions_car, size: 80, color: colors.textMuted),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${activeSkin.name} • ${activeSkin.tag}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.isDark ? Colors.white70 : const Color(0xFF374151)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3 Official Color Cards
          ...kOfficialVehicleSkins.map((skin) {
            final isSelected = skin.key == _activeKey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeKey = skin.key);
                  VehicleSkinManager.instance.setSkin(skin.key);
                  widget.onSkinSelected(skin.key);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (colors.isDark ? const Color(0xFF131D2A) : const Color(0xFFF0FDF4))
                        : (colors.isDark ? const Color(0xFF131922) : const Color(0xFFF9FAFB)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? colors.accent : colors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Swatch
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? colors.accent : (colors.isDark ? Colors.white30 : Colors.black12),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: skin.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: skin.isDualTone
                              ? Stack(
                                  children: [
                                    Container(color: skin.primaryColor),
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        height: 18,
                                        color: skin.secondaryColor,
                                      ),
                                    ),
                                  ],
                                )
                              : Container(color: skin.primaryColor),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  skin.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: colors.isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? colors.accent.withValues(alpha: 0.15) : (colors.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    skin.priceInfo,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? colors.accent : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              skin.description,
                              style: TextStyle(fontSize: 10.5, color: colors.textSecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Selection Indicator
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? colors.accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? colors.accent : colors.textMuted,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected ? Icon(Icons.check, size: 14, color: colors.onAccent) : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),

          // Confirm Button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              VehicleSkinManager.instance.setSkin(activeSkin.key);
              AppNotification.show(
                context,
                message: 'Chery Tiggo 7 PHEV skin set to ${activeSkin.name}${activeSkin.isDualTone ? " (Dual Tone)" : ""}',
                type: NotificationType.success,
                icon: Icons.palette_outlined,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: Text(
              'Set as Vehicle Skin (${activeSkin.name})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernSlideToStartBar extends StatefulWidget {
  final Color limeAccent;
  final Color cardCol;
  final Color borderCol;
  final Color textPrimary;
  final Color textMuted;
  final VoidCallback onSlideComplete;

  const _ModernSlideToStartBar({
    required this.limeAccent,
    required this.cardCol,
    required this.borderCol,
    required this.textPrimary,
    required this.textMuted,
    required this.onSlideComplete,
  });

  @override
  State<_ModernSlideToStartBar> createState() => _ModernSlideToStartBarState();
}

class _ModernSlideToStartBarState extends State<_ModernSlideToStartBar> with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late final AnimationController _resetAnimCtrl;
  late Animation<double> _resetAnim;

  @override
  void initState() {
    super.initState();
    _resetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        setState(() => _dragOffset = _resetAnim.value);
      });
  }

  @override
  void dispose() {
    _resetAnimCtrl.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_resetAnimCtrl.isAnimating) _resetAnimCtrl.stop();
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxDrag) {
    if (_dragOffset >= maxDrag * 0.75) {
      widget.onSlideComplete();
    }
    _resetAnim = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _resetAnimCtrl, curve: Curves.easeOutBack),
    );
    _resetAnimCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const knobSize = 46.0;
        final totalWidth = constraints.maxWidth;
        final maxDrag = (totalWidth - knobSize - 8).clamp(0.0, double.infinity);
        final progress = maxDrag > 0 ? (_dragOffset / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: widget.cardCol,
            borderRadius: BorderRadius.circular(AppTokens.rFull),
            border: Border.all(
              color: progress > 0.1
                  ? widget.limeAccent.withValues(alpha: 0.3 + (progress * 0.7))
                  : widget.borderCol,
              width: 1.2,
            ),
            boxShadow: progress > 0.2
                ? [
                    BoxShadow(
                      color: widget.limeAccent.withValues(alpha: 0.15 * progress),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (progress > 0)
                Container(
                  width: _dragOffset + knobSize,
                  decoration: BoxDecoration(
                    color: widget.limeAccent.withValues(alpha: 0.12 * progress),
                    borderRadius: BorderRadius.circular(AppTokens.rFull),
                  ),
                ),
              Center(
                child: Opacity(
                  opacity: (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Slide to pre-cool / start',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: widget.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.keyboard_double_arrow_right_rounded, size: 16, color: widget.limeAccent),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: _dragOffset,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, maxDrag),
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: progress > 0.5 ? widget.limeAccent : widget.cardCol,
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.limeAccent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: widget.limeAccent.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        size: 22,
                        color: progress > 0.5 ? Colors.black : widget.limeAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
