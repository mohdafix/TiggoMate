import 'package:uuid/uuid.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/assistant_message.dart';
import '../../data/models/knowledge_document.dart';
import '../../data/models/telemetry.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import 'ai_service.dart';
import 'tools/assistant_tools.dart';

enum AssistantIntent {
  autoModeOperation,
  engineStartReasons,
  longJourneyBattery,
  warningLights,
  energyCostComparison,
  tripCostCalculation,
  maintenanceSchedule,
  telemetryQuery,
  connectionStatus,
  preDriveChecklist,
  recordOdometer,
  generalTiggoQuery,
}

class AssistantOrchestrator {
  final AssistantToolRegistry toolRegistry;
  final KnowledgeRepository knowledgeRepository;
  final VehicleRepository vehicleRepository;
  final AiService? aiService;
  final _uuid = const Uuid();

  AssistantOrchestrator({
    required this.toolRegistry,
    required this.knowledgeRepository,
    required this.vehicleRepository,
    this.aiService,
  });

  /// Orchestrates the entire pipeline:
  /// User input → Intent classification → Context retrieval → Knowledge search → Tool execution → Grounded response
  Future<AssistantMessage> processUserQuery({
    required String userQuery,
    String modelName = 'openai/gpt-4o-mini',
  }) async {
    final intent = _classifyIntent(userQuery);
    final knowledgeResults = knowledgeRepository.search(userQuery, limit: 3);
    final citations = <DocumentCitation>[];

    for (final result in knowledgeResults) {
      citations.add(
        result.chunk.toCitation(matchedExcerpt: result.matchedSnippet),
      );
    }

    final toolsExecuted = <ToolExecutionRecord>[];
    String groundedResponseText = '';
    List<String> suggestedFollowUps = [];
    bool isLiveReadingDependent = false;

    switch (intent) {
      case AssistantIntent.autoModeOperation:
        groundedResponseText = _buildAutoModeResponse(citations);
        suggestedFollowUps = [
          'Why hasn\'t my petrol engine started at this battery level?',
          'How should I manage the battery on a long journey?',
          'What is the difference between EV and HEV mode?',
        ];
        break;

      case AssistantIntent.engineStartReasons:
        // Check live vehicle reading status
        final readingResult = await toolRegistry.getLatestVehicleReadings({});
        toolsExecuted.add(readingResult.toRecord({}));
        isLiveReadingDependent = true;

        groundedResponseText = _buildEngineStartResponse(
          readingResult,
          citations,
        );
        suggestedFollowUps = [
          'What does AUTO mode do?',
          'How should I manage the battery on a highway?',
          'What is the 3DHT transmission?',
        ];
        break;

      case AssistantIntent.longJourneyBattery:
        groundedResponseText = _buildLongJourneyResponse(citations);
        suggestedFollowUps = [
          'How much does it cost to drive 100 km using electricity versus petrol?',
          'What is the recommended tyre pressure for a full load?',
          'Where is the AC charging port located?',
        ];
        break;

      case AssistantIntent.warningLights:
        groundedResponseText = _buildWarningLightsResponse(citations);
        suggestedFollowUps = [
          'What does the green READY light mean?',
          'What should I do if the 12V battery is low?',
          'How do I check my tyre pressure?',
        ];
        break;

      case AssistantIntent.energyCostComparison:
        final toolResult = await toolRegistry.calculateEnergyCost({});
        toolsExecuted.add(toolResult.toRecord({}));

        groundedResponseText = _buildEnergyCostResponse(toolResult, citations);
        suggestedFollowUps = [
          'How should I manage the battery on a long journey?',
          'What is the AC charging time for Tiggo 7 PHEV?',
          'Can I enter my own electricity tariff?',
        ];
        break;

      case AssistantIntent.tripCostCalculation:
        final toolResult = await toolRegistry.calculateTripCost({
          'distanceKm': _extractDistance(userQuery) ?? 100.0,
        });
        toolsExecuted.add(toolResult.toRecord({}));

        groundedResponseText = _buildTripCostResponse(toolResult, citations);
        suggestedFollowUps = [
          'Calculate trip cost for 350 km',
          'How much do I save with electricity vs petrol?',
        ];
        break;

      case AssistantIntent.maintenanceSchedule:
        final nextDueResult = await toolRegistry.getNextServiceDue({});
        toolsExecuted.add(nextDueResult.toRecord({}));

        groundedResponseText = _buildMaintenanceResponse(
          nextDueResult,
          citations,
        );
        suggestedFollowUps = [
          'What happens during the 1,000 km initial service?',
          'When should CarLinko be activated?',
          'What tyre rotation interval is recommended?',
        ];
        break;

      case AssistantIntent.telemetryQuery:
      case AssistantIntent.connectionStatus:
        final statusResult = await toolRegistry.getVehicleConnectionStatus({});
        toolsExecuted.add(statusResult.toRecord({}));

        final readingResult = await toolRegistry.getLatestVehicleReadings({});
        toolsExecuted.add(readingResult.toRecord({}));
        isLiveReadingDependent = true;

        groundedResponseText = _buildConnectionResponse(
          statusResult,
          readingResult,
        );
        suggestedFollowUps = [
          'When will CarLinko be activated on my car?',
          'Can I enable simulated data for demonstration?',
          'How do I manually record my odometer?',
        ];
        break;

      case AssistantIntent.preDriveChecklist:
        groundedResponseText = _buildPreDriveChecklist(citations);
        suggestedFollowUps = [
          'What is the recommended tyre pressure for Malaysian highways?',
          'How should I manage the battery on a long journey?',
        ];
        break;

      case AssistantIntent.recordOdometer:
        final odo = _extractOdometer(userQuery);
        if (odo != null) {
          final writeResult = await toolRegistry.recordOdometer({'value': odo});
          toolsExecuted.add(writeResult.toRecord({'value': odo}));
          if (writeResult.success) {
            groundedResponseText =
                '✅ Successfully recorded your vehicle odometer reading to **${Formatters.formatDistance(odo)}**.\n\n'
                'This value has been saved in your persistent local ownership records.';
          } else {
            groundedResponseText = '⚠️ ${writeResult.errorMessage}';
          }
        } else {
          groundedResponseText =
              'To record your odometer reading, please specify the mileage (e.g., *"Record odometer 950 km"*).';
        }
        suggestedFollowUps = ['What is my next service due?'];
        break;

      case AssistantIntent.generalTiggoQuery:
        groundedResponseText = _buildGeneralKnowledgeResponse(
          userQuery,
          knowledgeResults,
          citations,
        );
        suggestedFollowUps = [
          'What does AUTO mode do?',
          'What is the battery capacity of the Tiggo 7 PHEV?',
          'How do I activate CarLinko?',
        ];
        break;
    }

    return AssistantMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: groundedResponseText,
      timestamp: DateTime.now(),
      citations: citations,
      toolsExecuted: toolsExecuted,
      suggestedFollowUps: suggestedFollowUps,
      isLiveReadingDependent: isLiveReadingDependent,
    );
  }

  AssistantIntent _classifyIntent(String text) {
    final q = text.toLowerCase();
    if (q.contains('auto mode') || (q.contains('auto') && q.contains('mode'))) {
      return AssistantIntent.autoModeOperation;
    }
    if (q.contains('engine') &&
        (q.contains('start') || q.contains('petrol') || q.contains('run'))) {
      return AssistantIntent.engineStartReasons;
    }
    if (q.contains('long journey') ||
        q.contains('highway') ||
        q.contains('long drive') ||
        q.contains('manage the battery')) {
      return AssistantIntent.longJourneyBattery;
    }
    if (q.contains('warning light') ||
        q.contains('indicator') ||
        q.contains('fault') ||
        q.contains('ready light')) {
      return AssistantIntent.warningLights;
    }
    if (q.contains('cost to drive 100 km') ||
        q.contains('electricity versus petrol') ||
        (q.contains('cost') && q.contains('100 km'))) {
      return AssistantIntent.energyCostComparison;
    }
    if (q.contains('trip cost') || q.contains('calculate cost')) {
      return AssistantIntent.tripCostCalculation;
    }
    if (q.contains('service') ||
        q.contains('maintenance') ||
        q.contains('oil change') ||
        q.contains('interval')) {
      return AssistantIntent.maintenanceSchedule;
    }
    if (q.contains('carlinko') ||
        q.contains('connect') ||
        q.contains('telemetry') ||
        q.contains('battery level') ||
        q.contains('live')) {
      return AssistantIntent.telemetryQuery;
    }
    if (q.contains('before a long drive') ||
        q.contains('checklist') ||
        q.contains('check before')) {
      return AssistantIntent.preDriveChecklist;
    }
    if (q.contains('record odometer') ||
        q.contains('update mileage') ||
        q.contains('set odometer')) {
      return AssistantIntent.recordOdometer;
    }
    return AssistantIntent.generalTiggoQuery;
  }

  String _buildAutoModeResponse(List<DocumentCitation> citations) {
    return '### Understanding AUTO Mode on Chery Tiggo 7 PHEV CSH\n\n'
        '**AUTO Mode** is the default recommended hybrid operating mode for your Tiggo 7 PHEV in Malaysia.\n\n'
        'Here is how it intelligently manages power:\n\n'
        '- **Electric-First Logic:** At low to moderate city speeds, the system prioritizes the dual electric motors using energy from the 19.27 kWh traction battery. The car moves smoothly and silently.\n'
        '- **Intelligent Engine Engagement:** The 1.5L turbocharged engine does **not** engage simply because speed increases. It automatically turns on when:\n'
        '  1. **High Power Request:** Heavy acceleration or overtaking kicks down the throttle.\n'
        '  2. **SOC Threshold:** Traction battery drops below the system threshold (~20%–25% state of charge).\n'
        '  3. **High Cabin Heating / AC Load:** Demands exceed pure high-voltage electrical compressor thresholds.\n'
        '  4. **Steep Inclines:** Continuous high torque is required.\n'
        '- **3-Speed DHT Coordination:** When the engine starts, Chery\'s Dedicated Hybrid Transmission (3DHT) can run the engine in *series mode* (generating power for the motors) or *parallel direct-drive* through its 3 physical gears for peak highway efficiency.\n\n'
        '> **Recommendation:** Leave the car in AUTO mode for daily driving in Malaysian traffic. It delivers optimal fuel economy without requiring manual intervention.';
  }

  String _buildEngineStartResponse(
    ToolCallResult readingResult,
    List<DocumentCitation> citations,
  ) {
    final isSim =
        readingResult.data is Map &&
        (readingResult.data as Map)['provenance'] ==
            ReadingSource.simulated.name;

    String liveStatusNotice = '';
    if (!isSim) {
      liveStatusNotice =
          '> ⚠️ **Live Vehicle Telemetry Notice:**\n'
          '> TiggoMate is **not currently connected** to live telemetry from your car. CarLinko activation is pending your upcoming 1,000 km service inspection. Therefore, I cannot inspect your car\'s instantaneous battery level or ECU sensors directly right now.\n\n';
    } else {
      liveStatusNotice =
          '> ℹ️ **Simulated Data Active:** Showing simulated battery at 78%.\n\n';
    }

    return '$liveStatusNotice'
        '### When Does the Petrol Engine Operate in the Tiggo 7 PHEV?\n\n'
        'In the Chery Tiggo 7 PHEV CSH, the 1.5T petrol engine operates based on strict algorithmic thresholds rather than traditional engine-only behavior:\n\n'
        '1. **Battery State of Charge (SOC):**\n'
        '   - If your battery is above **~20% to 25%**, the vehicle will run almost entirely on electric motors in city conditions.\n'
        '   - If you are at a lower battery level and the engine *has not started*, the vehicle is likely cruising under low load or coasting with regenerative braking.\n'
        '2. **Power Demand (Throttle Input):**\n'
        '   - Gentle accelerator input draws only from the electric motors.\n'
        '   - Once throttle pedal travel crosses ~70%–80% (kickdown), the engine fires immediately within ~0.2 seconds to provide parallel boost.\n'
        '3. **Catalytic Converter Heating & System Preservation:**\n'
        '   - If the engine has not fired for weeks, the hybrid controller will occasionally fire the engine briefly to circulate oil and purge fuel vapours.\n'
        '4. **Cabin Climate Control:**\n'
        '   - In extreme temperature demands, the engine may assist auxiliary thermal management.';
  }

  String _buildLongJourneyResponse(List<DocumentCitation> citations) {
    return '### Battery Management Strategy on Long Journeys (e.g. PLUS Highway)\n\n'
        'To get the best efficiency and longevity on a long interstate journey across Malaysia:\n\n'
        '1. **Do Not Exhaust Battery to 0% on Highways:**\n'
        '   - Cruising at 110–120 km/h in pure EV mode drains the 19.27 kWh battery in approximately 50–60 km due to high aerodynamic drag.\n'
        '2. **Engage AUTO or HEV Mode at the Highway On-Ramp:**\n'
        '   - On open expressways, the 1.5T engine is in its highest thermal efficiency band through the 3rd gear of the 3DHT.\n'
        '   - Running HEV preserves your battery charge for when you really need it.\n'
        '3. **Preserve a 40%–50% Battery Reserve:**\n'
        '   - Save your electric charge for heavy city traffic at your destination or steep hill climbs (such as Genting or Cameron Highlands).\n'
        '4. **Regenerative Braking Utilization:**\n'
        '   - Keep energy recuperation on Standard or High when navigating downhill gradients to recharge the pack without using petrol.';
  }

  String _buildWarningLightsResponse(List<DocumentCitation> citations) {
    return '### Instrument Cluster Warning Lights & Hybrid System Indicators\n\n'
        'Here are the key indicators for the Malaysian Chery Tiggo 7 PHEV:\n\n'
        '- 🟢 **Green "READY" Light:** The high-voltage contactors are safely closed. The car is fully powered and ready to drive silently on electric propulsion.\n'
        '- 🟠 **Amber High-Voltage / Powertrain Warning:** A non-critical hybrid anomaly has been detected. Power may be limited ("turtle mode"). Safely pull over, turn the car off, wait 5 minutes, and restart.\n'
        '- 🔴 **Red High-Voltage Hazard Symbol:** High-voltage interlock or insulation fault. **Do not touch orange high-voltage cables.** Safely stop and call Chery Roadside Assistance.\n'
        '- 🔋 **12V Auxiliary Battery Light:** The 12V battery powers the car\'s computer modules and closes the high-voltage contactors. If the 12V battery is dead, the car will **not start**, even if your 19.27 kWh traction battery is 100% full.\n'
        '- ⚠️ **TPMS Light:** Illuminates when cold tyre pressure drops below 20% of the 230 kPa setpoint.';
  }

  String _buildEnergyCostResponse(
    ToolCallResult toolResult,
    List<DocumentCitation> citations,
  ) {
    final data = toolResult.data as Map<String, dynamic>? ?? {};
    final evCost = (data['pureEvCost100KmRm'] as num?)?.toDouble() ?? 9.93;
    final petrolCost =
        (data['purePetrolCost100KmRm'] as num?)?.toDouble() ?? 13.33;
    final savings = (data['savingsPer100KmRm'] as num?)?.toDouble() ?? 3.40;
    final pct = (data['savingsPercent'] as num?)?.toDouble() ?? 25.5;

    return '### Cost Comparison: Driving 100 km (Electricity vs. Petrol)\n\n'
        'Based on verified Malaysian energy tariffs and Tiggo 7 PHEV specifications:\n\n'
        '| Metric | Pure Electric Drive | Pure Petrol Drive (Depleted Battery) |\n'
        '| :--- | :--- | :--- |\n'
        '| **Consumption** | ~17.5 kWh / 100 km (+10% charging loss) | ~6.5 L / 100 km |\n'
        '| **Energy Rate** | RM 0.516 / kWh (TNB residential tier) | RM 2.05 / L (Malaysian RON95) |\n'
        '| **Cost per 100 km** | **${Formatters.formatCurrency(evCost)}** | **${Formatters.formatCurrency(petrolCost)}** |\n'
        '| **Savings** | **${Formatters.formatCurrency(savings)} (${pct.toStringAsFixed(1)}% savings)** | Baseline |\n\n'
        '💡 **Key Takeaways:**\n'
        '- Charging at home on off-peak or lower TNB tiers reduces the cost even further (down to ~RM 4.20 per 100 km).\n'
        '- Regular daily charging for city commutes minimizes your fuel expenditure significantly.';
  }

  String _buildTripCostResponse(
    ToolCallResult toolResult,
    List<DocumentCitation> citations,
  ) {
    final data = toolResult.data as Map<String, dynamic>? ?? {};
    final dist = (data['distanceKm'] as num?)?.toDouble() ?? 100.0;
    final total = (data['totalCostRm'] as num?)?.toDouble() ?? 0.0;
    final perKm = (data['costPerKmRm'] as num?)?.toDouble() ?? 0.0;
    final per100Km = (data['costPer100KmRm'] as num?)?.toDouble() ?? 0.0;
    final assumptions = (data['assumptions'] as List<dynamic>?) ?? [];

    final buffer = StringBuffer();
    buffer.writeln(
      '### Trip Cost Calculation for ${dist.toStringAsFixed(1)} km\n',
    );
    buffer.writeln(
      '- **Total Trip Cost:** ${Formatters.formatCurrency(total)}',
    );
    buffer.writeln('- **Cost per km:** ${Formatters.formatCurrency(perKm)}');
    buffer.writeln(
      '- **Cost per 100 km:** ${Formatters.formatCurrency(per100Km)}\n',
    );
    buffer.writeln('**Assumptions & Parameters:**');
    for (final a in assumptions) {
      buffer.writeln('- $a');
    }
    return buffer.toString();
  }

  String _buildMaintenanceResponse(
    ToolCallResult toolResult,
    List<DocumentCitation> citations,
  ) {
    final data = toolResult.data as Map<String, dynamic>? ?? {};
    final serviceName =
        data['serviceName'] as String? ?? '1,000 km Initial Inspection';
    final targetKm = (data['targetKm'] as num?)?.toDouble() ?? 1000.0;
    final remainingKm = (data['remainingKm'] as num?)?.toDouble() ?? 150.0;
    final isFirst = data['isFirstMilestone'] as bool? ?? true;

    return '### Maintenance Schedule & Next Service Reminder\n\n'
        '- **Next Scheduled Service:** **$serviceName**\n'
        '- **Milestone Target:** ${Formatters.formatDistance(targetKm)}\n'
        '- **Remaining Distance:** **${Formatters.formatDistance(remainingKm)}**\n\n'
        '${isFirst ? '⚠️ **Crucial Milestone for CarLinko:**\n'
                  'Your initial 1,000 km inspection is where the Chery authorized dealer performs safety checks, inspects hybrid fluid circuits, and **activates your CarLinko telematics eSIM**. Once activated, live vehicle data can be synced!\n\n' : ''}'
        '**Official Service Intervals in Malaysia:**\n'
        '- **Initial Inspection:** 1,000 km or 1 month (complimentary dealer check)\n'
        '- **Regular Intervals:** Every 10,000 km or 6 months (whichever comes first)\n'
        '- **Engine Oil Spec:** Fully synthetic 0W-20 dedicated hybrid engine oil\n'
        '- **Tyre Rotation:** Every 10,000 km';
  }

  String _buildConnectionResponse(
    ToolCallResult statusResult,
    ToolCallResult readingResult,
  ) {
    final statusData = statusResult.data as Map<String, dynamic>? ?? {};
    final isSim = statusData['isSimulated'] as bool? ?? false;
    final currentOdo = vehicleRepository.currentProfile.currentOdometerKm;

    if (isSim) {
      return '### Connection Status: Simulated Development Mode\n\n'
          '⚠️ **Simulated Telemetry is currently ACTIVE** for demonstration and offline testing.\n\n'
          '- **Connection Provider:** Mock Vehicle Telemetry Engine\n'
          '- **Simulated Battery SOC:** 78%\n'
          '- **Simulated Fuel Level:** 85%\n'
          '- **Simulated Electric Range:** 68 km\n'
          '- **Current Odometer:** ${Formatters.formatDistance(currentOdo)}\n\n'
          'You can disable simulated mode anytime in Settings to return to the honest disconnected state.';
    }

    return '### Connection Status: Not Activated (Honest Status)\n\n'
        '- **Provider:** CarLinko Malaysia Telematics (Pending)\n'
        '- **Status:** **Vehicle connection not activated**\n'
        '- **Last-Known Odometer (Manual):** ${Formatters.formatDistance(currentOdo)}\n'
        '- **Battery SOC & Fuel Level:** *No reading available (Not connected)*\n\n'
        '**Why is live data not available?**\n'
        'In accordance with our product principles, TiggoMate **never fabricates live vehicle readings** or claims a connection that does not exist. Your Chery Tiggo 7 PHEV eSIM will be activated by the dealer during your **1,000 km service inspection**.\n\n'
        'Once activated, TiggoMate will connect via the secure backend bridge.';
  }

  String _buildPreDriveChecklist(List<DocumentCitation> citations) {
    return '### Pre-Drive Checklist for Tiggo 7 PHEV CSH\n\n'
        '1. **Tyre Pressures:** Check cold tyre pressures (recommended **230 kPa / 33 psi** front & rear, or **250 kPa / 36 psi** under full family load).\n'
        '2. **Charging Port & Flap:** Ensure the Type 2 AC charging cable is disconnected and both charging/fuel flaps are securely latched.\n'
        '3. **Instrument Cluster Ready State:** Look for the green **"READY"** lamp before shifting from Park to Drive.\n'
        '4. **Drive Mode Selection:** Ensure **AUTO** mode is selected for smart hybrid fuel management.\n'
        '5. **Screen & Camera Sensors:** Keep the front ADAS camera (behind rear-view mirror) and 360-degree cameras clean from road grime.';
  }

  String _buildGeneralKnowledgeResponse(
    String userQuery,
    List<KnowledgeSearchResult> results,
    List<DocumentCitation> citations,
  ) {
    if (results.isEmpty) {
      return 'I do not have verified Malaysian documentation for this specific query. '
          'As an assistant dedicated to the **Chery Tiggo 7 PHEV CSH**, I only provide facts grounded in verified documentation rather than inventing vehicle specifications.\n\n'
          'Would you like to ask about hybrid driving modes, battery management, charging, maintenance schedules, or tyre specifications?';
    }

    final top = results.first.chunk;
    return '### ${top.title}\n\n'
        '${top.content}\n\n'
        '*Source: ${top.documentName}, Page ${top.pageNumber ?? 1}*';
  }

  double? _extractDistance(String text) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:km|kilometres|kilometers)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  double? _extractOdometer(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }
}
