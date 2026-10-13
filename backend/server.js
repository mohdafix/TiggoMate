/**
 * TiggoMate Secure Backend Proxy
 *
 * Responsibilities:
 * 1. AI Proxy: Holds OPENROUTER_API_KEY / OPENAI_API_KEY securely. Client never touches LLM secrets.
 * 2. CarLinko Bridge: Relays Home Assistant ha-carlinko entities via authenticated HA REST API.
 *    Client never receives HA long-lived access tokens.
 */

const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// Strict rate limiting to prevent abuse
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', apiLimiter);

// 1. Health Check
app.get('/api/v1/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'tiggomate-backend',
    features: {
      aiProxy: !!process.env.OPENROUTER_API_KEY,
      carlinkoBridge: !!process.env.HA_BASE_URL && !!process.env.HA_ACCESS_TOKEN,
    },
  });
});

// 2. Secure AI Proxy (OpenRouter / GPT-4o-mini)
app.post('/api/v1/chat', async (req, res) => {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return res.status(503).json({
      error: 'AI backend credentials unconfigured. Set OPENROUTER_API_KEY on server.',
    });
  }

  const { model = 'openai/gpt-4o-mini', messages, temperature = 0.2 } = req.body;

  if (!messages || !Array.isArray(messages)) {
    return res.status(400).json({ error: 'Valid messages array is required.' });
  }

  try {
    const fetch = (await import('node-fetch')).default;
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
        'HTTP-Referer': 'https://tiggomate.app',
        'X-Title': 'TiggoMate Chery Assistant',
      },
      body: JSON.stringify({
        model,
        messages,
        temperature,
      }),
    });

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    console.error('AI Proxy Error:', error);
    return res.status(500).json({ error: 'Internal error communicating with AI provider.' });
  }
});

// 3. CarLinko Telematics Relay via Home Assistant ha-carlinko integration
// Chery vehicle -> CarLinko Cloud -> Home Assistant ha-carlinko -> HA REST API -> TiggoMate Backend -> Flutter App
app.get('/api/v1/carlinko/telemetry', async (req, res) => {
  const haUrl = process.env.HA_BASE_URL;
  const haToken = process.env.HA_ACCESS_TOKEN;

  if (!haUrl || !haToken) {
    return res.json({
      status: 'not_configured',
      message: 'Home Assistant bridge not configured on backend. Real vehicle activation pending 1,000 km inspection.',
      isSimulated: false,
      telemetry: null,
    });
  }

  try {
    const fetch = (await import('node-fetch')).default;

    // Fetch entity states from Home Assistant
    // Maps community ha-carlinko sensor names
    const entities = [
      'sensor.tiggo_7_battery_level',
      'sensor.tiggo_7_fuel_level',
      'sensor.tiggo_7_odometer',
      'sensor.tiggo_7_electric_range',
      'sensor.tiggo_7_total_range',
      'binary_sensor.tiggo_7_charging_status',
    ];

    const fetchEntity = async (entityId) => {
      try {
        const r = await fetch(`${haUrl}/api/states/${entityId}`, {
          headers: { Authorization: `Bearer ${haToken}` },
        });
        if (r.ok) return await r.json();
      } catch (_) {}
      return null;
    };

    const states = await Promise.all(entities.map(fetchEntity));
    const [battery, fuel, odo, evRange, totalRange, charging] = states;

    const parseNum = (entity) => {
      if (!entity || entity.state === 'unavailable' || entity.state === 'unknown') return null;
      const n = parseFloat(entity.state);
      return isNaN(n) ? null : n;
    };

    const telemetry = {
      timestamp: new Date().toISOString(),
      source: 'live_carlinko_ha_relay',
      batteryPercentage: parseNum(battery),
      fuelPercentage: parseNum(fuel),
      odometerKm: parseNum(odo),
      estimatedElectricRangeKm: parseNum(evRange),
      estimatedTotalRangeKm: parseNum(totalRange),
      isCharging: charging ? charging.state === 'on' : null,
    };

    return res.json({
      status: 'connected',
      message: 'Live vehicle telemetry retrieved via ha-carlinko bridge.',
      isSimulated: false,
      telemetry,
    });
  } catch (error) {
    console.error('CarLinko Relay Error:', error);
    return res.status(502).json({
      status: 'gateway_error',
      message: 'Unable to reach Home Assistant CarLinko integration.',
      error: error.message,
    });
  }
});

app.listen(PORT, () => {
  console.log(`TiggoMate backend proxy running on port ${PORT}`);
});
