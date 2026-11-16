/// Real-world technical knowledge, troubleshooting guides, service directory,
/// and community-verified tips extracted from the Malaysia Chery Tiggo 7 PHEV Club.
class ClubKnowledgeItem {
  final String id;
  final String title;
  final String category;
  final List<String> keywords;
  final String quickAnswer;
  final String detailedAdvice;
  final String source;

  const ClubKnowledgeItem({
    required this.id,
    required this.title,
    required this.category,
    required this.keywords,
    required this.quickAnswer,
    required this.detailedAdvice,
    this.source = 'Malaysia Chery Tiggo 7 PHEV Club',
  });
}

class CheryClubKnowledge {
  /// Emergency & Specialist Contacts verified by Malaysian owners
  static const emergencyContacts = <String, String>{
    'Chery Auto Assist 24/7 Hotline': '+60 3-7989 0349',
    'Chery Auto Assist Toll-Free': '1-800-88-0349',
    'Kota Damansara (KD) SC Hotline': '010-208 9799',
    'SSH - Li Ling Insurance & Road Tax': '+60 18-268 2266',
    'Orsen Nicholas (Undercarriage & Skid Plate)': '+60 12-277 0476',
  };

  /// Structured knowledge database of common questions, quirks, and solutions
  static const List<ClubKnowledgeItem> items = [
    // 1. Charging Quirks
    ClubKnowledgeItem(
      id: 'charger_stuck',
      title: 'Charging Cable Stuck / Cannot Unplug Gun',
      category: 'Charging',
      keywords: [
        'charger stuck',
        'cable stuck',
        'unplug',
        'cabut charger',
        'cabut gun',
        'lock charger',
        'cannot pull charger',
        'charger lock',
        'kabel sangkut',
        'tarik charger',
        'stuck charger'
      ],
      quickAnswer:
          'Unlock the car doors with your key fob or the CarLinko app first! The vehicle engages an electronic anti-theft locking pin on the Type 2 / CCS2 gun whenever the car is locked.',
      detailedAdvice:
          '### How to Release a Stuck Charging Cable\n\n'
          '1. **Do Not Force or Yank the Cable:** The Chery Tiggo 7 PHEV has an electronic solenoid pin that firmly locks the charging plug to prevent unauthorized cable theft.\n'
          '2. **Unlock the Car:** Press the **Unlock** button on your key fob twice, or tap **Unlock** in TiggoMate / CarLinko. You will hear an audible click as the solenoid releases the gun.\n'
          '3. **Immediate Removal:** Pull the charging gun out within 10–15 seconds before the vehicle auto-relocks.\n'
          '4. **If Still Stuck:** Verify on the instrument cluster that charging session is stopped (or terminate session in the charging app like Gentari/JomCharge/chargEV).',
    ),

    // 2. Emergency Assistance & Accident Allowance
    ClubKnowledgeItem(
      id: 'roadside_assist',
      title: 'Chery Auto Assist 24/7 & Accident Grievances Allowance',
      category: 'Emergency',
      keywords: [
        'auto assist',
        'roadside',
        'breakdown',
        'towing',
        'kemalangan',
        'accident',
        'claim motor',
        'bantuan',
        'grievance',
        'allowance'
      ],
      quickAnswer:
          'Call Chery Auto Assist 24/7 at **+60 3-7989 0349**. If involved in an accident, file a police report and call Chery Hotline to register your case for the **RM50/day (up to 5 days) Chery Grievances Allowance** while waiting for repairs.',
      detailedAdvice:
          '### Chery 24/7 Roadside Assistance & Claims Protocol\n\n'
          '- **24/7 Roadside Assistance Hotline:** **+60 3-7989 0349**\n'
          '- **Insurance & Road Tax Desk (SSH Li Ling):** **+60 18-268 2266**\n\n'
          '**Accident / Motorcycle Collision Protocol:**\n'
          '1. **Police Report First:** Make a police report within 24 hours.\n'
          '2. **Register with Chery Hotline:** Call **03-7989 0349** to register your case before repair begins. This qualifies you for Chery\'s **RM50/day Grievances Allowance (up to 5 days)**.\n'
          '3. **Recommended Body & Paint Centre:** Chery Balakong 4S is equipped with an authorized Body & Paint workshop (typically 2–3 days turnaround for standard panels). Note that non-CKD replacement parts from China may require 1–3 months lead time.\n'
          '4. **Avoid Non-Responsive Workshops:** Owners advise caution with congested or slow repair centers (e.g. Taman Kencana Cheras) to avoid unnecessary delays.',
    ),

    // 3. Fuel Flap Stuck
    ClubKnowledgeItem(
      id: 'fuel_flap_stuck',
      title: 'Fuel Flap / Lid Stuck or Won\'t Open',
      category: 'Issues & Fixes',
      keywords: [
        'fuel flap',
        'fuel lid',
        'fuel door',
        'penutup minyak',
        'tudung minyak',
        'petrol door',
        'petrol lid',
        'minyak xleh bukak',
        'pintu minyak'
      ],
      quickAnswer:
          'This is a recognized actuator latch issue covered 100% under warranty claim at Chery SC. While awaiting the replacement actuator, do not press the flap flush shut so it doesn\'t lock tight.',
      detailedAdvice:
          '### Fuel Flap Actuator Latch Issue\n\n'
          '- **Symptom:** Pressing the fuel door release switch or pushing the flap results in intermittent failure to unlatch.\n'
          '- **Root Cause:** Defective electronic actuator solenoid pin inside the fuel door housing.\n'
          '- **Remedy:** Book an appointment at Chery SC. The service center will inspect and order a warranty replacement actuator (FOC under warranty).\n'
          '- **Temporary Workaround:** If you are waiting for parts, some club members recommend leaving the flap gently resting without snapping the latch completely flush.',
    ),

    // 4. Service Centre Updates (Puchong SC Closure)
    ClubKnowledgeItem(
      id: 'sc_updates',
      title: 'Chery Service Centre Updates & Puchong SC Closure',
      category: 'Maintenance',
      keywords: [
        'puchong sc',
        'puchong service centre',
        'kd sc',
        'kota damansara sc',
        'connaught sc',
        'tmn connaught',
        'balakong sc',
        'sc tutup'
      ],
      quickAnswer:
          'Chery Puchong Service Centre permanently ceased operations on 24 October 2026. Puchong owners are redirected to **Kota Damansara (KD) SC (010-208 9799)** or **Taman Connaught / Balakong 4S**.',
      detailedAdvice:
          '### Chery Service Centre Network Notice\n\n'
          '- **Puchong SC Closure:** The Puchong Service Centre closed permanently on 24 October 2026 due to tenancy conclusion.\n'
          '- **Alternative Official Centres:**\n'
          '  1. **Kota Damansara (KD) Service Centre:** Dedicated replacement hub. Contact: **010-208 9799**.\n'
          '  2. **Chery Taman Connaught (Cheras):** Highly rated by club members for responsive customer service and comfortable lounge.\n'
          '  3. **Chery Balakong 4S:** Full-scale 4S facility with dedicated body & paint workshops.\n'
          '  4. **Chery Bangi / Jalan 222 PJ:** Fast activation of CarLinko T-Box without waiting for 1,000 km service.',
    ),

    // 5. 12V Auxiliary Battery Warranty & Reset
    ClubKnowledgeItem(
      id: 'battery_12v_warranty',
      title: '12V Auxiliary Battery Warranty & Reset Procedure',
      category: 'Battery',
      keywords: [
        '12v battery',
        '12v warranty',
        'bateri 12v',
        'lead acid',
        'lifepo4',
        'tsapa',
        'battery reset',
        'bateri kong',
        'jump start'
      ],
      quickAnswer:
          'The factory 12V auxiliary battery warranty is **1 year or 20,000 km** (not 8 years). Whenever the 12V battery is replaced, the car **must undergo a BMS reset at Chery SC**.',
      detailedAdvice:
          '### 12V Auxiliary Battery Critical Guide\n\n'
          '- **Warranty Limitation:** The stock 12V lead-acid battery is only covered for **1 year or 20,000 km** (whichever comes first), unlike the 8-year / 160,000 km traction battery.\n'
          '- **Workload in PHEV:** In a PHEV, the 12V battery powers all computers, telematics, lighting, and CAN-bus control units continuously. High tropical ambient heat can cause health degradation after 20k–30k km.\n'
          '- **SC Battery Reset Required:** Every time a new 12V battery is installed, you must visit a Chery SC for diagnostic BMS sensor calibration. Without this reset, spurious sensor warnings or CarLinko offline flags may occur.\n'
          '- **Upgrade Option:** Some club owners upgrade to high-cycle LiFePO4 12V batteries (e.g. TSAPA) with built-in emergency self-jumpstart tools for longevity in Malaysian heat.',
    ),

    // 6. Tyre Pressure & Rotation
    ClubKnowledgeItem(
      id: 'tpms_tyre_pressure',
      title: 'Optimal TPMS Tyre Pressure & Rotation',
      category: 'Chassis',
      keywords: [
        'tyre pressure',
        'tire pressure',
        'kpa',
        'psi',
        'pam tayar',
        'tekanan tayar',
        'tyre rotation',
        'tampal tayar',
        'puncture'
      ],
      quickAnswer:
          'Factory cold spec is **230 kPa (33.4 psi)**. Club members recommend **230–240 kPa (~34 psi)** cold. Avoid 280 kPa / 38 psi which makes the ride harsh on Malaysian roads. TPMS auto-relearns after tyre rotation.',
      detailedAdvice:
          '### Tyre Pressure & Maintenance Best Practices\n\n'
          '- **Target Cold Pressure:** **230 kPa (Front & Rear)** as specified on the driver\'s B-pillar placard.\n'
          '- **Comfort Recommendation:** Pumping to **230–240 kPa (~33.5–34.8 psi)** delivers the best balance of fuel economy, handling, and bump compliance. Pressures above 270 kPa (~39 psi) make the suspension bouncy over uneven road surfaces.\n'
          '- **Tyre Rotation:** You can perform tyre rotation at any reputable independent tyre shop; the Chery TPMS system automatically detects the new wheel positions after 2–5 km of driving.\n'
          '- **Punctures & Repair Kit:** The car comes with an electric inflator and sealant in the boot. However, tyre shops dislike cleaning the liquid sealant residue. If you can still drive slowly or pump air at a nearby petrol station, a standard internal mushroom plug ("tampal dalam") is much cleaner.',
    ),

    // 7. Boot Rattle / Loose Noise
    ClubKnowledgeItem(
      id: 'boot_rattle',
      title: 'Boot Rattle / Loose Sound While Driving',
      category: 'Issues & Fixes',
      keywords: [
        'boot noise',
        'rattle',
        'loose sound',
        'bunyi boot',
        'bunyi longgar',
        'sunroof noise',
        'parcel shelf'
      ],
      quickAnswer:
          'Rattling sounds from the rear are often misdiagnosed as the boot latch. Club owners and SCs found it is almost always caused by **panoramic sunroof guide rails or loose rear parcel shelf clips**.',
      detailedAdvice:
          '### Diagnosing Rear Cabin Rattle & Squeaks\n\n'
          '- **Common Misconception:** Many owners assume the electric tailgate latch is loose when driving over bumps.\n'
          '- **Actual Culprit 1 (Sunroof Rails):** The panoramic sunroof glass track and sunshade guide rails can flex and emit a clicking/loose noise that echoes down the rear cabin. Chery SC can apply specialized anti-friction grease or adjust rail torques under warranty.\n'
          '- **Actual Culprit 2 (Parcel Shelf):** Check the rubber alignment pads on both ends of the rear luggage cover / tonneau blind. Adding a small strip of felt tape completely silences plastic-on-plastic vibration.',
    ),

    // 8. Emergency Boot Release without Power
    ClubKnowledgeItem(
      id: 'emergency_boot_release',
      title: 'How to Open Boot / Tailgate When Battery is Dead',
      category: 'Emergency',
      keywords: [
        'buka boot',
        'buka boot kalau bateri kong',
        'boot xleh bukak',
        'buka tailgate',
        'open boot dead battery',
        'open boot when battery dead',
        'buka boot bateri kong',
        'manual boot',
        'tailgate dead power',
        'buka pintu belakang'
      ],
      quickAnswer:
          'Fold down the rear passenger seats, climb inside the boot cargo area, and look for the emergency mechanical release slot on the inside of the tailgate trim. Use a key or screwdriver to slide the latch open.',
      detailedAdvice:
          '### Manual Tailgate Emergency Opening Procedure\n\n'
          'If the 12V auxiliary battery is completely dead, the electric tailgate release button and key fob will not operate.\n\n'
          '1. **Access from Cabin:** Pull the seat-back release straps on the 60:40 rear seats and fold them flat.\n'
          '2. **Climb into Luggage Area:** Reach the lower interior center of the tailgate.\n'
          '3. **Locate Emergency Plug:** Remove the small rectangular plastic access cap located directly above the mechanical lock mechanism.\n'
          '4. **Flick the Lever:** Insert your mechanical emergency key blade (stored inside the key fob) or a small tool into the slot and push the lever sideways to physically pop the tailgate open.',
    ),

    // 9. Real-World Fuel Economy & Driving Modes
    ClubKnowledgeItem(
      id: 'real_world_consumption',
      title: 'Real-World Range, Fuel Economy & Best Drive Modes',
      category: 'Powertrain',
      keywords: [
        'fuel consumption',
        'real range',
        'jimat minyak',
        'mode mana jimat',
        'hev smart eco',
        'traffic jam consumption',
        'l/100km real'
      ],
      quickAnswer:
          'Malaysian owners confirm **~850+ km** combined range on a full tank (60L) + full charge in **HEV + Smart + ECO Mode** with A/C at 25°C–26°C. In heavy traffic jams, fuel consumption drops to **~4.8–5.0 L/100km**.',
      detailedAdvice:
          '### Real-World Malaysian Driving Experience & Settings\n\n'
          '- **Optimal Daily Setup:** **HEV Mode + Smart Setting + ECO Mode**.\n'
          '- **Highway Cruising:** At 110–130 km/h on PLUS highway, the 1.5T engine engages 3DHT 3rd gear directly for maximum thermal efficiency.\n'
          '- **City Traffic Jams:** Unlike pure petrol ICE SUVs that consume 10–12 L/100km in stop-and-go jams, the Tiggo 7 PHEV creeps on electric motor power, yielding only **4.8–5.0 L/100km** even with low SoC (20–25%).\n'
          '- **A/C Temperature Tip:** Set climate to 25.0°C–26.0°C (Auto). Setting below 22°C continuously draws high compressor current and reduces pure electric range.',
    ),

    // 10. Windscreen Insurance Coverage & Sunroof
    ClubKnowledgeItem(
      id: 'windscreen_insurance',
      title: 'Windscreen Insurance Sum Insured & Sunroof Endorsement',
      category: 'Insurance',
      keywords: [
        'windscreen insurance',
        'cermin depan',
        'insurans cermin',
        'tinted claim',
        'sunroof insurance',
        'tukar cermin'
      ],
      quickAnswer:
          'Set your windscreen coverage to **RM 3,500 to RM 5,000** to fully cover OEM acoustic laminated glass + premium heat rejection tint. Ensure panoramic sunroof glass is explicitly written in the policy schedule.',
      detailedAdvice:
          '### Windscreen & Panoramic Glass Insurance Advice\n\n'
          '- **Recommended Sum Insured:** **RM 3,500 (Standard)** or **RM 5,000 (Premium Tint e.g. 3M / V-Kool / Raytech)**.\n'
          '- **Sunroof Clause:** Always verify with your insurance agent (e.g. SSH Li Ling: 018-268 2266) that the endorsement covers all window panels including the panoramic glass sunroof.\n'
          '- **Windscreen Sensor Recalibration:** When replacing a broken windscreen at specialist shops (such as Dr Cermin), ensure the ADAS forward-facing camera and rain sensor bracket are correctly calibrated.',
    ),

    // 11. Undercarriage Shield / Skid Plate
    ClubKnowledgeItem(
      id: 'undercarriage_protection',
      title: 'Undercarriage & High-Voltage Battery Shield',
      category: 'Accessories',
      keywords: [
        'skid plate',
        'undercarriage',
        'orsen',
        'pelindung bateri',
        'bawah kereta',
        'cable protection',
        'battery shield'
      ],
      quickAnswer:
          'Underbody armor is popular among Tiggo 7 PHEV owners to shield exposed high-voltage cables and the battery pack from road debris. Bolt-on shields use existing chassis screw holes without drilling. Specialist contact: Orsen Nicholas (+60 12-277 0476).',
      detailedAdvice:
          '### Tiggo 7 PHEV Underbody Cable & Battery Armor\n\n'
          '- **Why Protect:** The hybrid powertrain features high-voltage battery cables running along the vehicle underfloor. Road gravel or debris can scratch outer conduit sheathing.\n'
          '- **Orsen Nicholas Specialist (+60 12-277 0476):** Offers custom-fit alloy underbody protection plates designed specifically for Tiggo 7 PHEV chassis mounting points (no drilling required).\n'
          '- **Wading Caution:** Tiggo 7 PHEV safe wading depth is approximately 450 mm; never drive through deep floodwaters exceeding axle height.',
    ),

    // 12. DRL in Rest / Camping Mode
    ClubKnowledgeItem(
      id: 'drl_rest_mode',
      title: 'How to Turn Off DRL in Rest / Camping Mode',
      category: 'Electrical',
      keywords: [
        'drl rest mode',
        'lampu siang',
        'rest mode lampu',
        'padam drl',
        'turn off drl',
        'camp mode lights'
      ],
      quickAnswer:
          'In rest/camping mode, Daytime Running Lights (DRL) stay illuminated as long as someone is detected on the driver\'s seat. Move to the passenger or rear seat (or lift off the driver seat), and the DRL will turn off automatically.',
      detailedAdvice:
          '### Turning Off DRL While Parked / Resting\n\n'
          '- The Chery safety logic considers the vehicle active if the driver seat weight sensor is triggered.\n'
          '- To rest inside with aircond running without shining bright DRL headlights: move to the front passenger seat or rear seats. After a short delay, the exterior DRL will extinguish while cabin climate continues.',
    ),
  ];

  /// Compiles a comprehensive knowledge block for the AI Copilot system prompt
  static String get knowledgePromptBlock {
    final buffer = StringBuffer();
    buffer.writeln('MALAYSIA CHERY TIGGO 7 PHEV CLUB — REAL-WORLD OWNER KNOWLEDGE & TROUBLESHOOTING:');
    buffer.writeln('Use the following community-verified Malaysian owner knowledge, quirks, and emergency contacts to provide authoritative, highly grounded answers:');
    buffer.writeln('');

    buffer.writeln('Emergency & Official Contacts:');
    emergencyContacts.forEach((k, v) {
      buffer.writeln('- $k: $v');
    });
    buffer.writeln('');

    buffer.writeln('Community Solutions & Proven Answers:');
    for (final item in items) {
      buffer.writeln('### ${item.title} (${item.category}):');
      buffer.writeln('- Summary: ${item.quickAnswer}');
      buffer.writeln('- Details: ${item.detailedAdvice.replaceAll('\n', ' ')}');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Attempts to match a user query against the club database for offline responses
  static ClubKnowledgeItem? matchQuestion(String query) {
    final q = query.toLowerCase();
    ClubKnowledgeItem? bestItem;
    int bestScore = 0;

    for (final item in items) {
      int score = 0;
      for (final kw in item.keywords) {
        final kwLower = kw.toLowerCase();
        if (q.contains(kwLower)) {
          // Multi-word phrase matches score much higher than single words
          score += kwLower.length * (kwLower.contains(' ') ? 4 : 1);
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestItem = item;
      }
    }
    return bestScore > 0 ? bestItem : null;
  }
}
