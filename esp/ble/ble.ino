#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#include <Adafruit_NeoPixel.h>
#include <Preferences.h>

// ---------------- LED RINGS ----------------
#define LED_COUNT_LEFT_EYE   37
#define LED_COUNT_RIGHT_EYE  37
#define LED_PIN_RIGHT_EYE    13
#define LED_PIN_LEFT_EYE     26

Adafruit_NeoPixel leftStrip  = Adafruit_NeoPixel(LED_COUNT_LEFT_EYE,  LED_PIN_LEFT_EYE,  NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel rightStrip = Adafruit_NeoPixel(LED_COUNT_RIGHT_EYE, LED_PIN_RIGHT_EYE, NEO_GRB + NEO_KHZ800);

// ---------------- INPUT PINS (turn/alarm) ----------------
#define PIN_TURN_LEFT   32
#define PIN_TURN_RIGHT  33
#define PIN_ALARM       27

// ---------------- UUIDs ----------------
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define AUTH_CHAR_UUID      "c0de0001-1fb5-459e-8fcc-c5c9c331914b"
#define PASS_CHAR_UUID      "c0de0002-1fb5-459e-8fcc-c5c9c331914b"
#define LED_CHAR_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ---------------- BLE globals ----------------
BLEServer* pServer = nullptr;
BLECharacteristic* authChar = nullptr;
BLECharacteristic* passChar = nullptr;
BLECharacteristic* ledChar  = nullptr;

bool deviceConnected = false;
bool authenticated   = false;
uint16_t g_connId    = 0;

// no-delay disconnect scheduling
bool disconnectScheduled = false;
uint32_t disconnectAtMs  = 0;

// ---------------- Preferences ----------------
Preferences prefs;
String currentPassword = "111111";

// ---------------- Protocol ----------------
namespace BleCmd {
  static const uint8_t quickDriveColor   = 0x01; // [cmd, side, r,g,b,brightness]
  static const uint8_t setDynamicEffect  = 0x02; // [cmd, effectId, speed, brightness, r,g,b]
  static const uint8_t savePowerOn       = 0x10; // [cmd, effectId, speed, brightness, r,g,b]
  static const uint8_t saveTurn          = 0x11;
  static const uint8_t saveAlarm         = 0x12;
}

namespace BleSide {
  static const uint8_t both  = 0;
  static const uint8_t left  = 1;
  static const uint8_t right = 2;
}

// ---------------- Presets ----------------
struct Preset {
  uint8_t effectId   = 0;
  uint8_t speed      = 128;
  uint8_t brightness = 255;
  uint8_t r          = 255;
  uint8_t g          = 128;
  uint8_t b          = 0;
};

// Stored presets (NVS)
Preset presetPowerOn;
Preset presetTurn;
Preset presetAlarm;

// Runtime quick
struct QuickState {
  
  uint8_t r = 255, g = 0, b = 255;
  uint8_t brightness = 200;
};
QuickState quickLeft;
QuickState quickRight;

// Runtime lighting/dynamic (0x02)
Preset lightingDynamic;

// --- last-update-wins between QuickDrive and Lighting ---
uint32_t lastQuickMs    = 0;
uint32_t lastLightingMs = 0;

// ---------------- Utility ----------------
static inline uint8_t clamp8(int v) { if (v < 0) return 0; if (v > 255) return 255; return (uint8_t)v; }

const char* cmdName(uint8_t cmd) {
  switch (cmd) {
    case BleCmd::quickDriveColor:  return "quickDriveColor(0x01)";
    case BleCmd::setDynamicEffect: return "setDynamicEffect(0x02)";
    case BleCmd::savePowerOn:      return "savePowerOn(0x10)";
    case BleCmd::saveTurn:         return "saveTurn(0x11)";
    case BleCmd::saveAlarm:        return "saveAlarm(0x12)";
    default:                       return "UNKNOWN";
  }
}

const char* sideName(uint8_t side) {
  switch (side) {
    case BleSide::both:  return "both(0)";
    case BleSide::left:  return "left(1)";
    case BleSide::right: return "right(2)";
    default:             return "side?";
  }
}

void printPacketReadable(const uint8_t* d, size_t n) {
  if (n == 0) return;
  uint8_t cmd = d[0];

  Serial.print("[BLE] RX ");
  Serial.print(cmdName(cmd));
  Serial.print(" len=");
  Serial.println((int)n);

  if (cmd == BleCmd::quickDriveColor && n >= 6) {
    Serial.print("  side="); Serial.print(sideName(d[1]));
    Serial.print("  r=");    Serial.print((int)d[2]);
    Serial.print("  g=");    Serial.print((int)d[3]);
    Serial.print("  b=");    Serial.print((int)d[4]);
    Serial.print("  br=");   Serial.println((int)d[5]);
    return;
  }

  if (cmd == BleCmd::setDynamicEffect && n >= 7) {
    Serial.print("  effectId="); Serial.print((int)d[1]);
    Serial.print("  speed=");    Serial.print((int)d[2]);
    Serial.print("  br=");       Serial.print((int)d[3]);
    Serial.print("  r=");        Serial.print((int)d[4]);
    Serial.print("  g=");        Serial.print((int)d[5]);
    Serial.print("  b=");        Serial.println((int)d[6]);
    return;
  }

  if ((cmd == BleCmd::savePowerOn || cmd == BleCmd::saveTurn || cmd == BleCmd::saveAlarm) && n >= 7) {
    Serial.print("  preset: effectId="); Serial.print((int)d[1]);
    Serial.print(" speed=");            Serial.print((int)d[2]);
    Serial.print(" br=");               Serial.print((int)d[3]);
    Serial.print(" r=");                Serial.print((int)d[4]);
    Serial.print(" g=");                Serial.print((int)d[5]);
    Serial.print(" b=");                Serial.println((int)d[6]);
    return;
  }
}

void setPixelScaled(Adafruit_NeoPixel& strip, int i, uint8_t r, uint8_t g, uint8_t b, uint8_t br) {
  uint16_t rr = (uint16_t)r * (uint16_t)br;
  uint16_t gg = (uint16_t)g * (uint16_t)br;
  uint16_t bb = (uint16_t)b * (uint16_t)br;
  strip.setPixelColor(i, strip.Color((uint8_t)(rr >> 8), (uint8_t)(gg >> 8), (uint8_t)(bb >> 8)));
}

void fillScaled(Adafruit_NeoPixel& strip, uint8_t r, uint8_t g, uint8_t b, uint8_t br) {
  for (int i = 0; i < strip.numPixels(); i++) setPixelScaled(strip, i, r, g, b, br);
}

void clearStrip(Adafruit_NeoPixel& strip) {
  for (int i = 0; i < strip.numPixels(); i++) strip.setPixelColor(i, 0);
}

void showBoth() {
  leftStrip.show();
  rightStrip.show();
}

void notifyText(BLECharacteristic* c, const char* txt) {
  c->setValue((uint8_t*)txt, strlen(txt));
  c->notify();
}

// ---------------- Persistence ----------------
void loadPreset(const char* keyPrefix, Preset& p, const Preset& def) {
  String pre = String(keyPrefix);
  p.effectId   = prefs.getUChar((pre + "_e").c_str(),  def.effectId);
  p.speed      = prefs.getUChar((pre + "_s").c_str(),  def.speed);
  p.brightness = prefs.getUChar((pre + "_br").c_str(), def.brightness);
  p.r          = prefs.getUChar((pre + "_r").c_str(),  def.r);
  p.g          = prefs.getUChar((pre + "_g").c_str(),  def.g);
  p.b          = prefs.getUChar((pre + "_b").c_str(),  def.b);
}

void savePreset(const char* keyPrefix, const Preset& p) {
  String pre = String(keyPrefix);
  prefs.putUChar((pre + "_e").c_str(),  p.effectId);
  prefs.putUChar((pre + "_s").c_str(),  p.speed);
  prefs.putUChar((pre + "_br").c_str(), p.brightness);
  prefs.putUChar((pre + "_r").c_str(),  p.r);
  prefs.putUChar((pre + "_g").c_str(),  p.g);
  prefs.putUChar((pre + "_b").c_str(),  p.b);
}

// ---------------- Effects engine (no delay) ----------------
// ---- Save/Load runtime states (quick + dynamic + last source) ----
enum LastSource : uint8_t { SRC_QUICK = 0, SRC_DYNAMIC = 1 };
LastSource lastSource = SRC_QUICK;

void saveQuickState() {
  prefs.putUChar("ql_r", quickLeft.r);
  prefs.putUChar("ql_g", quickLeft.g);
  prefs.putUChar("ql_b", quickLeft.b);
  prefs.putUChar("ql_br", quickLeft.brightness);

  prefs.putUChar("qr_r", quickRight.r);
  prefs.putUChar("qr_g", quickRight.g);
  prefs.putUChar("qr_b", quickRight.b);
  prefs.putUChar("qr_br", quickRight.brightness);

  prefs.putUChar("lastSrc", (uint8_t)lastSource);
}

void saveDynamicState() {
  prefs.putUChar("dyn_e", lightingDynamic.effectId);
  prefs.putUChar("dyn_s", lightingDynamic.speed);
  prefs.putUChar("dyn_br", lightingDynamic.brightness);
  prefs.putUChar("dyn_r", lightingDynamic.r);
  prefs.putUChar("dyn_g", lightingDynamic.g);
  prefs.putUChar("dyn_b", lightingDynamic.b);

  prefs.putUChar("lastSrc", (uint8_t)lastSource);
}

void loadQuickState() {
  quickLeft.r          = prefs.getUChar("ql_r", 255);
  quickLeft.g          = prefs.getUChar("ql_g", 0);
  quickLeft.b          = prefs.getUChar("ql_b", 255);
  quickLeft.brightness = prefs.getUChar("ql_br", 0);

  quickRight.r          = prefs.getUChar("qr_r", 255);
  quickRight.g          = prefs.getUChar("qr_g", 0);
  quickRight.b          = prefs.getUChar("qr_b", 0);
  quickRight.brightness = prefs.getUChar("qr_br", 0);

  lastSource = (LastSource)prefs.getUChar("lastSrc", (uint8_t)SRC_QUICK);
}

void loadDynamicState() {
  lightingDynamic.effectId   = prefs.getUChar("dyn_e", 0);
  lightingDynamic.speed      = prefs.getUChar("dyn_s", 128);
  lightingDynamic.brightness = prefs.getUChar("dyn_br", 0);
  lightingDynamic.r          = prefs.getUChar("dyn_r", 255);
  lightingDynamic.g          = prefs.getUChar("dyn_g", 255);
  lightingDynamic.b          = prefs.getUChar("dyn_b", 255);

  lastSource = (LastSource)prefs.getUChar("lastSrc", (uint8_t)SRC_QUICK);
}

enum ActiveMode {
  MODE_NORMAL = 0,
  MODE_TURN = 1,
  MODE_ALARM = 2
};

ActiveMode activeMode = MODE_NORMAL;

// time base
uint32_t lastFrameMs = 0;
uint32_t nowMs = 0;

// ---- RainbowEyes state (твій алгоритм) ----
int leftCounter = LED_COUNT_LEFT_EYE;
int rightCounter = LED_COUNT_RIGHT_EYE;
int32_t leftFirstPixelHue  = 0;
int32_t rightFirstPixelHue = 0;
uint32_t lastRainbowStepMs = 0;

void leftEyeStep() {
  int idx = leftCounter;
  if (idx < 0) idx = 0;
  if (idx >= LED_COUNT_LEFT_EYE) idx = LED_COUNT_LEFT_EYE - 1;

  uint32_t c = leftStrip.gamma32(
    leftStrip.ColorHSV((uint16_t)(leftFirstPixelHue - (idx * 65536L / LED_COUNT_LEFT_EYE)))
  );
  leftStrip.setPixelColor(idx, c);

  leftCounter--;
  leftFirstPixelHue += 16;

  if (leftCounter <= 0) leftCounter = LED_COUNT_LEFT_EYE - 1;
  if (leftFirstPixelHue >= 5 * 65536L) leftFirstPixelHue = 0;
}

void rightEyeStep() {
  int idx = rightCounter;
  if (idx < 0) idx = 0;
  if (idx >= LED_COUNT_RIGHT_EYE) idx = LED_COUNT_RIGHT_EYE - 1;

  uint32_t c = rightStrip.gamma32(
    rightStrip.ColorHSV((uint16_t)(rightFirstPixelHue + (idx * 65536L / LED_COUNT_RIGHT_EYE)))
  );
  rightStrip.setPixelColor(idx, c);

  rightCounter--;
  rightFirstPixelHue += 16;

  if (rightCounter <= 0) rightCounter = LED_COUNT_RIGHT_EYE - 1;
  if (rightFirstPixelHue < 0) rightFirstPixelHue = 0;
}

void RainbowEyesStep() {
  leftEyeStep();
  rightEyeStep();
}

void effectRainbowEyes(uint8_t br, uint8_t speed) {
  // TUNE_RAINBOW_SPEED: speed 0..255 -> 55..12 ms
  uint16_t stepMs = 55 - (uint16_t)speed * 43 / 255;
  if (stepMs < 12) stepMs = 12;

  if ((uint32_t)(nowMs - lastRainbowStepMs) < stepMs) return;
  lastRainbowStepMs = nowMs;

  if (br == 0) {
    clearStrip(leftStrip);
    clearStrip(rightStrip);
    return;
  }

  RainbowEyesStep();
}

void effectCircle(Adafruit_NeoPixel& strip, uint8_t r, uint8_t g, uint8_t b, uint8_t br, uint8_t speed, bool invertCircle) {
  const int n = strip.numPixels();

  // TUNE_CIRCLE_SPEED: 1400..250
  uint16_t periodMs = 1400 - (uint16_t)speed * 4;
  if (periodMs < 250) periodMs = 250;

  uint32_t t = nowMs % periodMs;
  float phase = (float)t / (float)periodMs;
  int head = (int)(phase * n) % n;

  int seg = n / 4;
  if (seg < 3) seg = 3;

  if (!invertCircle) {
    clearStrip(strip);
    for (int k = 0; k < seg; k++) {
      int idx = (head + k) % n;
      setPixelScaled(strip, idx, r, g, b, br);
    }
  } else {
    fillScaled(strip, r, g, b, br);
    for (int k = 0; k < seg; k++) {
      int idx = (head + k) % n;
      strip.setPixelColor(idx, 0);
    }
  }
}

void effectBlink(Adafruit_NeoPixel& strip, uint8_t r, uint8_t g, uint8_t b, uint8_t br, uint8_t speed) {
  // TUNE_BLINK_SPEED: 2200..350
  uint16_t periodMs = 2200 - (uint16_t)speed * 7;
  if (periodMs < 350) periodMs = 350;

  bool on = (nowMs % periodMs) < (periodMs / 2);
  if (on) fillScaled(strip, r, g, b, br);
  else clearStrip(strip);
}

void effectPulse(Adafruit_NeoPixel& strip, uint8_t r, uint8_t g, uint8_t b, uint8_t br, uint8_t speed) {
  // TUNE_PULSE_SPEED: 3200..900
  uint16_t periodMs = 3200 - (uint16_t)speed * 9;
  if (periodMs < 900) periodMs = 900;

  uint16_t t = nowMs % periodMs;
  float x = (float)t / (float)periodMs;
  float tri = (x < 0.5f) ? (x * 2.0f) : (2.0f - x * 2.0f);
  uint8_t br2 = (uint8_t)((uint16_t)br * (uint16_t)(tri * 255.0f) / 255);
  fillScaled(strip, r, g, b, br2);
}

void effectChase(Adafruit_NeoPixel& strip, uint8_t r, uint8_t g, uint8_t b, uint8_t br, uint8_t speed) {
  // TUNE_CHASE_SPEED: 900..220
  uint16_t periodMs = 900 - (uint16_t)speed * 3;
  if (periodMs < 220) periodMs = 220;

  int step = (nowMs / periodMs) % 3;

  clearStrip(strip);
  for (int i = 0; i < strip.numPixels(); i++) {
    if ((i + step) % 3 == 0) setPixelScaled(strip, i, r, g, b, br);
  }
}

void renderPresetToStrip(Adafruit_NeoPixel& strip, const Preset& p, bool invertCircle) {
  switch (p.effectId) {
    case 0: fillScaled(strip, p.r, p.g, p.b, p.brightness); break;
    case 1: effectCircle(strip, p.r, p.g, p.b, p.brightness, p.speed, invertCircle); break;
    case 2: effectBlink(strip, p.r, p.g, p.b, p.brightness, p.speed); break;
    case 3: effectPulse(strip, p.r, p.g, p.b, p.brightness, p.speed); break;
    case 4: break; // rainbow handled separately
    case 5: effectChase(strip, p.r, p.g, p.b, p.brightness, p.speed); break;
    default: fillScaled(strip, p.r, p.g, p.b, p.brightness); break;
  }
}

// ---------------- Input priority logic ----------------
bool activeHigh = true;
bool readActive(int pin) {
  int v = digitalRead(pin);
  return activeHigh ? (v == HIGH) : (v == LOW);
}

void updateModeFromPins() {
  bool alarmOn = readActive(PIN_ALARM);
  bool leftOn  = readActive(PIN_TURN_LEFT);
  bool rightOn = readActive(PIN_TURN_RIGHT);

  if (alarmOn) activeMode = MODE_ALARM;
  else if (leftOn || rightOn) activeMode = MODE_TURN;
  else activeMode = MODE_NORMAL;
}

// ---------------- PowerOn trigger on OFF->ON ----------------
bool powerOnPlaying = false;
uint32_t powerOnStartMs = 0;
bool prevLightsOn = false;

bool powerOnActive() {
  return powerOnPlaying && (millis() - powerOnStartMs) < 3000;
}

void startPowerOn() {
  powerOnPlaying = true;
  powerOnStartMs = millis();
}

// PowerOn effects:
// effectId: 0 tripleBlink, 1 fillRing, else fadeIn
bool tripleBlinkOnMs(uint32_t ms, uint16_t blinkMs = 250, uint8_t blinks = 3, uint16_t gapMs = 900) {
  uint32_t cycle = (uint32_t)blinks * (blinkMs * 2) + gapMs;
  uint32_t t = ms % cycle;
  for (uint8_t i = 0; i < blinks; i++) {
    uint32_t onStart = i * (blinkMs * 2);
    if (t >= onStart && t < onStart + blinkMs) return true;
  }
  return false;
}

void effectFillRing(Adafruit_NeoPixel& strip, uint8_t r,uint8_t g,uint8_t b,uint8_t br, uint8_t speed) {
  const int n = strip.numPixels();
  uint16_t periodMs = 2400 - (uint16_t)speed * 6;
  if (periodMs < 600) periodMs = 600;

  uint16_t t = nowMs % periodMs;
  float p = (float)t / (float)periodMs;
  int lit = (int)(p * n);

  clearStrip(strip);
  for (int i = 0; i < lit; i++) setPixelScaled(strip, i, r,g,b, br);
}

void effectFadeIn(Adafruit_NeoPixel& strip, uint8_t r,uint8_t g,uint8_t b,uint8_t br, uint8_t speed) {
  uint16_t periodMs = 2400 - (uint16_t)speed * 6;
  if (periodMs < 600) periodMs = 600;

  uint16_t t = nowMs % periodMs;
  float p = (float)t / (float)periodMs;
  uint8_t br2 = (uint8_t)((float)br * p);

  fillScaled(strip, r,g,b, br2);
}

// ---------------- Server callbacks ----------------
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server, esp_ble_gatts_cb_param_t* param) override {
    deviceConnected = true;
    authenticated = false;
    g_connId = param->connect.conn_id;
    BLEDevice::startAdvertising();
  }
  void onDisconnect(BLEServer* server) override {
    deviceConnected = false;
    authenticated = false;
  }
};

// ---------------- AUTH callbacks ----------------
class AuthCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    std::string rx = c->getValue();
    String entered = String(rx.c_str());
    entered.trim();

    if (entered.length() == 0) { notifyText(c, "BAD"); return; }

    if (entered == currentPassword) {
      authenticated = true;
      notifyText(c, "OK");
    } else {
      authenticated = false;
      notifyText(c, "BAD");
      if (pServer && deviceConnected) {
        disconnectScheduled = true;
        disconnectAtMs = millis() + 120;
      }
    }
  }
  void onRead(BLECharacteristic* c) override {
    c->setValue(authenticated ? "OK" : "NOAUTH");
  }
};

// ---------------- PASS change callbacks ----------------
class PassCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    if (!authenticated) { notifyText(c, "NOAUTH"); return; }

    std::string rx = c->getValue();
    String newPass = String(rx.c_str());
    newPass.trim();

    if (newPass.length() < 3) { notifyText(c, "BAD"); return; }

    currentPassword = newPass;
    prefs.putString("pwd", currentPassword);
    notifyText(c, "SAVED");
  }
  void onRead(BLECharacteristic* c) override { c->setValue(currentPassword.c_str()); }
};

// ---------------- LED callbacks ----------------
class LedCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    if (!authenticated) { Serial.println("[BLE] RX ignored: NOAUTH"); return; }

    std::string v = c->getValue();
    if (v.size() < 1) return;

    const uint8_t* d = (const uint8_t*)v.data();
    const size_t n = v.size();

    printPacketReadable(d, n);

    uint8_t cmd = d[0];

    if (cmd == BleCmd::quickDriveColor) {
      if (n < 6) return;
      uint8_t side = d[1];
      uint8_t r = d[2], g = d[3], b = d[4], br = d[5];

      if (side == BleSide::left) {
        quickLeft.r = r; quickLeft.g = g; quickLeft.b = b; quickLeft.brightness = br;
      } else if (side == BleSide::right) {
        quickRight.r = r; quickRight.g = g; quickRight.b = b; quickRight.brightness = br;
      } else {
        quickLeft.r = r;  quickLeft.g = g;  quickLeft.b = b;  quickLeft.brightness = br;
quickRight.r = r; quickRight.g = g; quickRight.b = b; quickRight.brightness = br;

      }

      lastQuickMs = millis();
      lastSource = SRC_QUICK;
      saveQuickState();
      return;
    }

    if (cmd == BleCmd::setDynamicEffect) {
      if (n < 7) return;
      lightingDynamic.effectId   = d[1];
      lightingDynamic.speed      = d[2];
      lightingDynamic.brightness = d[3];
      lightingDynamic.r          = d[4];
      lightingDynamic.g          = d[5];
      lightingDynamic.b          = d[6];

      lastLightingMs = millis();
      lastSource = SRC_DYNAMIC;
      saveDynamicState();
      return;
    }

    if (cmd == BleCmd::savePowerOn || cmd == BleCmd::saveTurn || cmd == BleCmd::saveAlarm) {
      if (n < 7) return;

      Preset p;
      p.effectId   = d[1];
      p.speed      = d[2];
      p.brightness = d[3];
      p.r          = d[4];
      p.g          = d[5];
      p.b          = d[6];

      if (cmd == BleCmd::savePowerOn) {
        presetPowerOn = p;
        savePreset("pwr", presetPowerOn);
        Serial.println("[BLE] preset saved: POWER-ON");
      } else if (cmd == BleCmd::saveTurn) {
        presetTurn = p;
        savePreset("turn", presetTurn);
        Serial.println("[BLE] preset saved: TURN");
      } else if (cmd == BleCmd::saveAlarm) {
        presetAlarm = p;
        savePreset("alm", presetAlarm);
        Serial.println("[BLE] preset saved: ALARM");
      }
      return;
    }
  }

  void onRead(BLECharacteristic* c) override {
    c->setValue(authenticated ? "OK" : "NOAUTH");
  }
};

// ---------------- Render ----------------
bool quickWins() {
  if (lastQuickMs == 0 && lastLightingMs == 0) return true;
  return lastQuickMs >= lastLightingMs;
}

bool lightsOnInNormal() {
  if (quickWins()) {
    return (quickLeft.brightness > 0) || (quickRight.brightness > 0);
  } else {
    return lightingDynamic.brightness > 0;
  }
}

void renderNormal() {
  bool lightsOn = lightsOnInNormal();

  // ✅ rising edge => start power-on
  if (!prevLightsOn && lightsOn) startPowerOn();
  prevLightsOn = lightsOn;

  // якщо power-on активний — показуємо його
  if (powerOnActive()) {
    uint8_t type = presetPowerOn.effectId;

    if (type == 0) {
      bool on = tripleBlinkOnMs(nowMs - powerOnStartMs, 250, 3, 900);
      if (on) {
        fillScaled(leftStrip, presetPowerOn.r, presetPowerOn.g, presetPowerOn.b, presetPowerOn.brightness);
        fillScaled(rightStrip, presetPowerOn.r, presetPowerOn.g, presetPowerOn.b, presetPowerOn.brightness);
      } else {
        clearStrip(leftStrip);
        clearStrip(rightStrip);
      }
    } else if (type == 1) {
      effectFillRing(leftStrip,  presetPowerOn.r,presetPowerOn.g,presetPowerOn.b,presetPowerOn.brightness, presetPowerOn.speed);
      effectFillRing(rightStrip, presetPowerOn.r,presetPowerOn.g,presetPowerOn.b,presetPowerOn.brightness, presetPowerOn.speed);
    } else {
      effectFadeIn(leftStrip,  presetPowerOn.r,presetPowerOn.g,presetPowerOn.b,presetPowerOn.brightness, presetPowerOn.speed);
      effectFadeIn(rightStrip, presetPowerOn.r,presetPowerOn.g,presetPowerOn.b,presetPowerOn.brightness, presetPowerOn.speed);
    }

    showBoth();
    return;
  }

  // звичайний показ
  if (quickWins()) {
    fillScaled(leftStrip,  quickLeft.r,  quickLeft.g,  quickLeft.b,  quickLeft.brightness);
    fillScaled(rightStrip, quickRight.r, quickRight.g, quickRight.b, quickRight.brightness);
    showBoth();
    return;
  } else {
    if (lightingDynamic.effectId == 4) {
      effectRainbowEyes(lightingDynamic.brightness, lightingDynamic.speed);
      showBoth();
      return;
    }
    renderPresetToStrip(leftStrip,  lightingDynamic, false);
    renderPresetToStrip(rightStrip, lightingDynamic, false);
    showBoth();
    return;
  }
}

void renderTurn() {
  bool leftOn  = readActive(PIN_TURN_LEFT);
  bool rightOn = readActive(PIN_TURN_RIGHT);

  Preset p = presetTurn;
  p.r = 255; p.g = 128; p.b = 0;

  if (leftOn) {
    if (p.effectId == 4) effectRainbowEyes(p.brightness, p.speed);
    else renderPresetToStrip(leftStrip, p, true);
  } else clearStrip(leftStrip);

  if (rightOn) {
    if (p.effectId == 4) effectRainbowEyes(p.brightness, p.speed);
    else renderPresetToStrip(rightStrip, p, true);
  } else clearStrip(rightStrip);

  showBoth();
}

void renderAlarm() {
  Preset p = presetAlarm;
  p.r = 255; p.g = 128; p.b = 0;

  if (p.effectId == 4) {
    effectRainbowEyes(p.brightness, p.speed);
    showBoth();
    return;
  }

  renderPresetToStrip(leftStrip,  p, true);
  renderPresetToStrip(rightStrip, p, true);
  showBoth();
}

void loopRender() {
  updateModeFromPins();

  if (activeMode == MODE_ALARM) { renderAlarm(); return; }
  if (activeMode == MODE_TURN)  { renderTurn();  return; }

  renderNormal();
}

// ---------------- Setup / loop ----------------
void setup() {
  Serial.begin(115200);

  leftStrip.begin();
  rightStrip.begin();
  leftStrip.show();
  rightStrip.show();

  pinMode(PIN_TURN_LEFT,  INPUT);
  pinMode(PIN_TURN_RIGHT, INPUT);
  pinMode(PIN_ALARM,      INPUT);

  prefs.begin("ble", false);
  currentPassword = prefs.getString("pwd", "111111");

  Preset defPwr;  defPwr.effectId=0; defPwr.speed=128; defPwr.brightness=255; defPwr.r=255; defPwr.g=152; defPwr.b=0;
  Preset defTurn; defTurn.effectId=1; defTurn.speed=200; defTurn.brightness=255; defTurn.r=255; defTurn.g=128; defTurn.b=0;
  Preset defAlm;  defAlm.effectId=2; defAlm.speed=220; defAlm.brightness=255; defAlm.r=255; defAlm.g=128; defAlm.b=0;

  loadPreset("pwr",  presetPowerOn, defPwr);
  loadPreset("turn", presetTurn,    defTurn);
  loadPreset("alm",  presetAlarm,   defAlm);

    // restore last runtime state
  loadQuickState();
  loadDynamicState();

  // Відновлюємо таймінги так, щоб переможець був lastSource
  if (lastSource == SRC_QUICK) {
    lastQuickMs = millis();
    lastLightingMs = 0;
  } else {
    lastLightingMs = millis();
    lastQuickMs = 0;
  }

  // Якщо після рестору світло вже "ON" — одразу запускаємо power-on один раз
  prevLightsOn = false;           // force rising edge
  if (lightsOnInNormal()) startPowerOn();


  BLEDevice::init("ovr4k_flutter_dev");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* service = pServer->createService(SERVICE_UUID);

  authChar = service->createCharacteristic(
    AUTH_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_READ  |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  authChar->addDescriptor(new BLE2902());
  authChar->setCallbacks(new AuthCallbacks());
  authChar->setValue("NOAUTH");

  passChar = service->createCharacteristic(
    PASS_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_READ  |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  passChar->addDescriptor(new BLE2902());
  passChar->setCallbacks(new PassCallbacks());
  passChar->setValue("READY");

  ledChar = service->createCharacteristic(
    LED_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  ledChar->addDescriptor(new BLE2902());
  ledChar->setCallbacks(new LedCallbacks());
  ledChar->setValue("READY");

  service->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(false);
  adv->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("BLE started, waiting...");
}

void loop() {
  nowMs = millis();

  if (disconnectScheduled && (int32_t)(nowMs - disconnectAtMs) >= 0) {
    disconnectScheduled = false;
    if (pServer && deviceConnected) pServer->disconnect(g_connId);
  }

  if ((uint32_t)(nowMs - lastFrameMs) < 16) return;
  lastFrameMs = nowMs;

  loopRender();
}
