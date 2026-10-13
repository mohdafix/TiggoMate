import 'dart:async';
import '../models/telemetry.dart';
import 'vehicle_data_source.dart';

/// Future adapter for CarLinko telematics via Home Assistant / TiggoMate backend bridge.
///
/// Intended Architecture:
/// Chery vehicle → CarLinko cloud → Home Assistant integration (ha-carlinko)
///               → authenticated HA REST/WebSocket API → TiggoMate secure backend
///               → Flutter application.
///
/// REFERENCE COMMUNITY PROJECT:
/// - Home Assistant integration: https://github.com/thititongumpun/ha-carlinko
/// - Community thread: https://community.home-assistant.io/t/custom-integration-carlinko-for-chery-jaecoo-carlinko-app/1022895
///
/// SAFETY & DESIGN RULES:
/// - Keep all CarLinko credentials and HA access tokens on the backend server.
/// - Never store or request CarLinko credentials directly inside this mobile client.
/// - Do not assume all sensors work for the Malaysian CSH PHEV model until tested in person.
/// - Always return honest [ConnectionStateEnum.notActivated] until the 1,000 km service activation is verified.
class CarLinkoVehicleDataSource implements VehicleDataSource {
  final String? backendBridgeUrl;
  final String? authToken;

  CarLinkoVehicleDataSource({this.backendBridgeUrl, this.authToken});

  @override
  Future<VehicleConnectionStatus> getConnectionStatus() async {
    // Current reality: Owner has not yet activated CarLinko.
    // CarLinko activation is scheduled for the 1,000 km inspection.
    return VehicleConnectionStatus(
      state: ConnectionStateEnum.notActivated,
      providerName: 'CarLinko Cloud (ha-carlinko bridge)',
      statusDescription:
          'CarLinko telematics not yet activated on vehicle eSIM. Scheduled for activation at Chery 1,000 km initial service.',
      lastChecked: DateTime.now(),
      isSimulated: false,
      endpointInfo:
          backendBridgeUrl ?? 'https://api.tiggomate.app/v1/carlinko (planned)',
    );
  }

  @override
  Stream<VehicleTelemetry> watchTelemetry() {
    // Returns disconnected stream with honest status
    return Stream.value(
      VehicleTelemetry.disconnected(
        statusMessage:
            'CarLinko telematics awaiting 1,000 km dealer activation',
      ),
    );
  }

  @override
  Future<VehicleCapabilities> getCapabilities() async {
    return VehicleCapabilities.notActivated();
  }
}
