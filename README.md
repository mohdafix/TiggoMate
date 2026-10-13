# TiggoMate 🚗⚡

> **AI-Powered Personal Car Assistant for the Malaysian-Market Chery Tiggo 7 PHEV CSH**

TiggoMate is a production-minded, Android-first Flutter application engineered specifically for owners of the Malaysian-market **Chery Tiggo 7 PHEV CSH** (Plug-in Hybrid Dedicated Hybrid Transmission).

---

## 1. Product Principles & Honest Data Guarantee

- **Malaysian Tiggo 7 PHEV CSH Grounding:** Specifically understands the Right-Hand Drive (RHD) Malaysian-market Tiggo 7 PHEV with Chery Super Hybrid (CSH) architecture, 1.5L TCI dedicated hybrid engine, 3-speed Dedicated Hybrid Transmission (3DHT), and 19.27 kWh traction battery.
- **Strict Provenance & Honest Connection State:** The app **never invents vehicle readings** or claims a connection that does not exist. Prior to CarLinko dealer activation, it displays an honest "Not Connected" state.
- **5 Provenance Categories:** Every data reading is strictly classified into:
  1. `LIVE VERIFIED` — Telematics received directly from a connected vehicle.
  2. `CACHED (STALE)` — Historical reading from a previous session.
  3. `MANUAL ENTRY` — User-entered values (e.g. recorded odometer).
  4. `SIMULATED DATA (DEV)` — Explicitly labelled mock telemetry for development & UI demonstration.
  5. `UNAVAILABLE` — Honest missing/disconnected state.
- **Secure Backend API Secrets:** Zero AI or telematics API secrets are hardcoded in the mobile app. All OpenRouter and Home Assistant credentials remain on the secure backend proxy.
- **Deterministic Math:** Energy and fuel cost calculations use deterministic mathematical formulas with explicit units and assumptions—never AI-hallucinated figures.

---

## 2. Target Vehicle Profile (Default Values)

| Parameter | Specification | Documentation Grounding |
| :--- | :--- | :--- |
| **Manufacturer** | Chery | Verified Malaysian Specification |
| **Model** | Tiggo 7 PHEV CSH | Dedicated Hybrid Architecture |
| **Market** | Malaysia (RHD) | Official Chery Malaysia handbook |
| **Powertrain** | Plug-in Hybrid (CSH) | 1.5L TCI Engine + Dual Motors + 3DHT |
| **Combined Output** | 326 PS / 545 Nm | Official Malaysian Specs |
| **Traction Battery** | 19.27 kWh | ~80–100 km EV Range (NEDC 100 km) |
| **Preferred Driving Mode** | AUTO | Default intelligent hybrid mode |
| **Tyre Size & Pressure** | 225/55 R18 (230 kPa cold) | Factory specifications |
| **First Service Milestone** | 1,000 km or 1 Month | Dealer check & **CarLinko eSIM activation** |
| **Regular Service Interval**| 10,000 km or 6 Months | 0W-20 dedicated hybrid oil |

---

## 3. Architecture & Tech Stack

```
Presentation (Material 3 Automotive Dark UI)
     │
Riverpod Providers & State Notifiers (app_providers.dart)
     │
Use Cases & Orchestrators (AssistantOrchestrator, CostCalculator)
     │
Repositories (Vehicle, Maintenance, Energy, Knowledge, Assistant)
     │
Data Sources (VehicleDataSource, MockVehicleDataSource, CarLinkoDataSource, LocalStorageDataSource)
     │
Secure Backend Proxy (backend/server.js)
```

- **Framework:** Flutter 3.44.8 / Dart 3.12.2
- **State Management:** Riverpod (`flutter_riverpod: ^2.6.1`)
- **Navigation:** `go_router: ^14.8.1` with persistent bottom navigation shell
- **Local Persistence:** `shared_preferences: ^2.5.3` with JSON serializable models
- **RAG Knowledge Base:** Offline document indexing with keyword & tag scoring, excerpt extraction, and page citations
- **AI Integration:** Abstract AI service communicating with OpenRouter (`openai/gpt-4o-mini`) via backend proxy

---

## 4. Main Navigation & Screens

1. **Home (`/`)**:
   - Vehicle nickname, plate identifier, and connection status banner.
   - Last-known odometer display.
   - Battery and petrol gauges shown **only** when live or explicitly simulated data exists.
   - 1,000 km CarLinko activation reminder card.
   - Quick Actions: Ask AI, Record Odo, Add Fuel, Record Charge.
2. **AI Assistant (`/assistant`)**:
   - Natural language chat grounded in Malaysian Tiggo 7 PHEV documentation.
   - Tool execution pills (`search_vehicle_manual`, `get_next_service_due`, etc.).
   - Verified source citations with document titles and page numbers.
   - Suggested follow-up prompt chips.
   - Android speech-recognition interface with graceful text fallback and TTS audio toggle.
3. **My Car (`/my-car`)**:
   - Editable vehicle profile (plate number, nickname, odometer, tyre details).
   - Connectivity status details for CarLinko and OBD-II.
   - Verified powertrain technical specifications.
   - Energy and fuel consumption summary.
4. **Maintenance (`/maintenance`)**:
   - Configurable service intervals (mileage & date-based).
   - 1,000 km dealer inspection milestone tracker.
   - Tyre rotation & alignment log.
   - Road tax & insurance policy expiry reminders.
   - Full service history log with cost tracking.
5. **Energy & Trip Cost Calculator (`/energy-calculator`)**:
   - Deterministic calculations for TNB residential electricity tariffs and Malaysian petrol (RON95/RON97).
   - AC charging onboard charger (OBC) conversion loss factor.
   - Cost per km, cost per 100 km, and savings versus petrol baseline.
6. **Settings & Privacy (`/settings`)**:
   - Simulated Data Mode toggle.
   - Backend proxy URL configuration.
   - Knowledge base index status.
   - JSON data export to clipboard.
   - Local cache clearing.

---

## 5. Getting Started & Running

### Prerequisites
- Flutter SDK 3.44+ / Dart 3.12+
- Android Studio / Android SDK (for Android build)

### Running the Flutter App
```bash
# Clone the repository
cd c:\Project\TiggoMate

# Fetch dependencies
cmd /c flutter pub get

# Run static analysis
cmd /c flutter analyze

# Run automated unit and widget test suite
cmd /c flutter test

# Launch debug app on connected Android device / emulator
cmd /c flutter run
```

---

## 6. Secure Backend Proxy Setup

The backend proxy keeps OpenRouter API keys and Home Assistant credentials safe from mobile app decompilation.

```bash
cd backend
npm install
cp .env.example .env
```

Configure `.env`:
```env
PORT=8080
OPENROUTER_API_KEY=your_openrouter_api_key_here
HA_BASE_URL=http://your-homeassistant-ip:8123
HA_ACCESS_TOKEN=your_home_assistant_long_lived_access_token_here
```

Start the backend:
```bash
npm start
```

---

## 7. Proposed CarLinko & OBD-II Integration Strategy

### Current Status: Pre-1,000 km Service
- The owner has not yet activated CarLinko. Dealer onboarding occurs during the 1,000 km initial inspection.
- The app currently displays `CarLinko: Not Activated`.
- Development and UI preview can be toggled using **Simulated Data Mode** in Settings, which clearly badges all telemetry as `SIMULATED DATA (DEV)`.

### Future Real-Data Integration Architecture
```
Chery Tiggo 7 PHEV
       │ 4G eSIM
Chery CarLinko Cloud
       │
Home Assistant Custom Integration (ha-carlinko)
https://github.com/thititongumpun/ha-carlinko
       │ Authenticated REST API (HA Long-Lived Token)
TiggoMate Secure Backend Proxy (backend/server.js)
       │ Sanitized & Normalized JSON Stream
TiggoMate Flutter App (CarLinkoVehicleDataSource)
```

### Safety Rules for OBD-II Module:
- Pure read-only diagnostics for standard SAE J1979 parameters.
- Never write to ECU, attempt DTC clearing, immobilizer modification, or drive-mode tampering.

---

## 8. Test Suite Summary

- `test/unit/cost_calculator_test.dart`: Verifies deterministic cost calculations, TNB tariff handling, OBC charging losses, and input validation.
- `test/unit/telemetry_provenance_test.dart`: Verifies the 5 reading categories, honest disconnected state, and simulated data labelling.
- `test/unit/assistant_tools_test.dart`: Verifies all 11 typed tool definitions, odometer validation, and manual citation retrieval.
- `test/widget_test.dart`: Verifies app launch, honest empty state banners, and responsive bottom navigation bar tab switching.
