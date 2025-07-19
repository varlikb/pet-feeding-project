/*
 * ESP32 Pet Feeder
 * Author: Claude AI
 * Description: Smart pet feeder system with WiFi connectivity, load cell measurement,
 * LCD display, and Supabase integration
 */

// Libraries
#include <WiFi.h>
#include <Wire.h>
#include <LiquidCrystal.h>  // Standard LCD library instead of I2C version
#include <HX711.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <NewPing.h>
#include <ESP32Servo.h>
#include <TimeLib.h>
#include <WebServer.h>  // WebServer kütüphanesini ekle
#include "time.h"  // NTP için gerekli
#include <WiFiClientSecure.h>

// Supabase Realtime WebSocket ayarları kaldırıldı

// WebSocket nesnesi kaldırıldı

// Realtime referans sayacı kaldırıldı

// EEPROM addresses
#define EEPROM_DEVICE_KEY_ADDR 0
#define EEPROM_WIFI_SSID_ADDR 32
#define EEPROM_WIFI_PASS_ADDR 96
#define EEPROM_SETUP_FLAG_ADDR 160

// Initial AP Mode Settings
const char* AP_SSID = "PetFeeder_Setup";
const char* AP_PASSWORD = "12345678";

// Supabase Settings
const char* SUPABASE_URL = "https://gsrjfkviwjukfnzyvnws.supabase.co";
const char* SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdzcmpma3Zpd2p1a2Zuenl2bndzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY4Mzg3NjgsImV4cCI6MjA2MjQxNDc2OH0.noGHh9rvtBp0HcCh9hpxcwFDgjCQGP7IAjdu-Vnfzxg";

// Global variables
String deviceKey = "";
String wifiSSID = "";
String wifiPassword = "";
bool isSetupMode = true;
bool isConfigured = false;
bool isPaired = false;

// Constants - Daha düzenli sabitler
#define DEVICE_VERSION "1.0"
#define DEFAULT_FEED_AMOUNT 50.0
#define MAX_FEED_AMOUNT 100.0
#define MIN_FEED_AMOUNT 10.0
#define FEED_AMOUNT_STEP 10.0

// Pin Definitions - Daha düzenli pin tanımlamaları
#define SERVO_PIN 13          // Servo motor sinyal pini
#define LOADCELL_DOUT_PIN 23  // HX711 DT/DOUT
#define LOADCELL_SCK_PIN 22   // HX711 SCK
#define ULTRASONIC_TRIGGER_PIN 4  // HC-SR04 TRIG
#define ULTRASONIC_ECHO_PIN 2     // HC-SR04 ECHO
#define LCD_BUTTONS_PIN 35     // LCD butonları için analog pin

// Alternative digital button pins for testing
#define BTN_SELECT_PIN 5      // Select button (digital)
#define BTN_UP_PIN 18         // Up button (digital)
#define BTN_DOWN_PIN 19       // Down button (digital)
#define BTN_LEFT_PIN 16       // Left button (digital)
#define BTN_RIGHT_PIN 17      // Right button (digital)
#define USE_DIGITAL_BUTTONS false  // Set to false to use analog buttons

// LCD contrast control
#define LCD_CONTRAST_PIN 32   // Pin for LCD contrast control - adjust if needed

// LCD pins for direct connection
#define LCD_RS_PIN 14    // Register Select
#define LCD_EN_PIN 12    // Enable
#define LCD_D4_PIN 27    // Data pin 4
#define LCD_D5_PIN 26    // Data pin 5
#define LCD_D6_PIN 25    // Data pin 6
#define LCD_D7_PIN 33    // Data pin 7

// LCD display configuration
#define LCD_COLS 16
#define LCD_ROWS 2

// Constants
#define ULTRASONIC_MAX_DISTANCE 50 // Maximum distance in centimeters
#define FEED_HISTORY_SIZE 24 // Store last 24 hours of feeding data
#define EEPROM_SIZE 512

// Load Cell calibration factor (updated with user's calibration)
#define LOADCELL_CALIBRATION_FACTOR 221.0
#define LOADCELL_OFFSET 0  // Reset to 0 for new calibration

// Container dimensions for ultrasonic sensor (in cm)
#define CONTAINER_EMPTY_DISTANCE 21.0 // Distance when container is empty (measured by user)
#define CONTAINER_FULL_DISTANCE 0.0   // Distance when container is full

// Servo configuration
#define SERVO_FEED_SPEED 2 // degrees per step
#define SERVO_MIN_ANGLE 15
#define SERVO_MAX_ANGLE 94
#define SERVO_FEED_POSITION 85
#define SERVO_REST_POSITION 0

// Feeding parameters
#define MAX_FEED_TIME 30000 // Maximum feeding time (30 seconds)
#define WEIGHT_CHECK_INTERVAL 100 // Check weight every 100ms

  // API Endpoints - Only keep what we need
const char* FEED_HISTORY_ENDPOINT = "/rest/v1/feeding_history";
const char* DEVICES_ENDPOINT = "/rest/v1/devices";
const char* DEVICE_STATUS_ENDPOINT = "/rest/v1/device_status";  // Eklenen endpoint
const char* PAIR_DEVICE_ENDPOINT = "/rest/v1/rpc/pair_device";
const char* FEED_NOW_ENDPOINT = "/feed"; // Local endpoint for feed now command
const char* SCHEDULE_ENDPOINT = "/schedule"; // Local endpoint for schedule command
const char* HEARTBEAT_ENDPOINT = "/heartbeat"; // Local endpoint for heartbeat
const char* STATUS_ENDPOINT = "/status"; // Local endpoint for device status

// Global Objects
LiquidCrystal lcd(LCD_RS_PIN, LCD_EN_PIN, LCD_D4_PIN, LCD_D5_PIN, LCD_D6_PIN, LCD_D7_PIN);  // Standard LCD connection
Servo feedServo;
HX711 scale;
NewPing sonar(ULTRASONIC_TRIGGER_PIN, ULTRASONIC_ECHO_PIN, ULTRASONIC_MAX_DISTANCE);  

// Global Variables
String petName = "UNKNOWN";
float foodLevel = 70.0; // Default food level percentage
float lastWeight = 0.0;
unsigned long lastFoodLevelUpdate = 0;
unsigned long lastWeightUpdate = 0;
unsigned long lastScheduleCheck = 0;
int displayState = 0; // Global display state for LCD menu

// Schedule Structure
struct Schedule {
  bool active;
  int hour;
  int minute;
  float targetWeight;
} currentSchedule;

  // Timing control variables for error handling
#define ERROR_PAUSE_TIME 30000  // Pause for 30 seconds after error
unsigned long lastErrorTime = 0;
bool hasError = false;

// WebServer nesnesi
WebServer server(80);

// NTP Sunucu ayarları
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 10800;  // UTC+3 için (3 saat * 3600 saniye)
const int daylightOffset_sec = 0;

// Analog button values for the LCD keypad
// These values need to be calibrated for your specific keypad
#define BUTTON_RIGHT_VALUE 0      // ~ 0-100
#define BUTTON_UP_VALUE 800       // ~ 700-900
#define BUTTON_DOWN_VALUE 1500    // ~ 1400-1600
#define BUTTON_LEFT_VALUE 2200    // ~ 2100-2300
#define BUTTON_SELECT_VALUE 3000  // ~ 2900-3100
#define BUTTON_NONE_VALUE 4095    // No button pressed

// Button definitions
enum ButtonType {
  BUTTON_NONE,
  BUTTON_RIGHT,
  BUTTON_UP, 
  BUTTON_DOWN,
  BUTTON_LEFT,
  BUTTON_SELECT
};

  // Global Variables
  String WIFI_SSID = "";     // WiFi SSID
  String WIFI_PASSWORD = ""; // WiFi şifresi
  String DEVICE_KEY = "";    // Cihaz anahtarı

// Function declarations
void setupAP();
void handleSetup();
void connectToWiFi();
void connectToSupabase();

void saveConfiguration();
void loadConfiguration();
void showSetupInfo();
void showOperationalInfo();
void setupWiFi();
void setupLCD();
void setupLoadCell();
void setupServo();
void setupButtons(); 
void handleButtons();
void updateLCD();
void executeFeeding(float targetAmount, bool isScheduled, String feedingType);
float measureWeight();
float measureFoodLevel();
void handleManualFeed();
void blinkServoLED();
void sendPairingRequest();
void updateFeedingHistory(float amount, String feedingType);
void updateFoodLevel(float newFoodLevel);
void updateDeviceInfo();
void handleStatus();
String getCurrentTime();
void setupTime();
void handleFeed();
void showFeedingResult(float amount, bool success);
void handleSchedule();
void handleHeartbeat();
void showFoodLevelUpdate(float newLevel);
void startServo();
void stopServo();
void refreshLCD();
ButtonType readLCDButtons();
void updateFeedAmountDisplay(float amount);
void checkAndExecuteSchedule();

String getDeviceId();
void resetConfiguration();
void sendFeedingAcknowledgement(float amount);
void sendFeedingCompletionStatus(float actualAmount, bool success);
bool setupTimeWithRetries();
bool registerDeviceInDatabase();

  // Timing Constants
#define WIFI_CONNECT_TIMEOUT 20000  // 20 seconds
#define FEED_TIMEOUT 30000          // 30 seconds
#define STATUS_UPDATE_INTERVAL 300000 // 5 minutes
#define SCHEDULE_CHECK_INTERVAL 60000 // 1 minute
#define FOOD_LEVEL_UPDATE_INTERVAL 1800000 // 30 minutes

// Root CA Certificate for *.supabase.co
const char* supabase_root_ca = R"(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
)";

// WiFiClientSecure for SSL/TLS
WiFiClientSecure ssl_client;

// Add new global variables for interval feeding mode
bool intervalFeedingActive = false;
unsigned long lastIntervalFeedingTime = 0;
int intervalFeedingSeconds = 60; // Default to 60 seconds (1 minute)
float intervalFeedingAmount = 50.0; // Default to 50 grams
String intervalDisplayFormat = "seconds"; // Can be "minutes" or "seconds"
bool autoResetAfterFeeding = true;
int secondsRemaining = 60; // Default to 60 seconds

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\nPet Feeder ESP32 Starting...");
  
  // SSL sertifikasını ayarla
  ssl_client.setCACert(supabase_root_ca);
  
  // Initialize EEPROM
  EEPROM.begin(512);
  
  // Initialize components
  setupLCD();
  setupLoadCell();
  setupServo();
  setupButtons();
  
  // Reset butonu kontrolü (GPIO 0 - Boot butonu)
  pinMode(0, INPUT_PULLUP);
  Serial.println("Reset button status: " + String(digitalRead(0) == LOW ? "PRESSED" : "NOT PRESSED"));
  if (digitalRead(0) == LOW) {
      lcd.clear();
      lcd.print("Resetting...");
      Serial.println("BOOT button pressed! Starting reset...");
      resetConfiguration();
      delay(1000);
  }
  
  // Load saved configuration
  loadConfiguration();
  
  // Interval feeding durumunu EEPROM'dan yükle - resetlense bile kalıcı olsun
  intervalFeedingActive = (EEPROM.read(120) == 1);
  Serial.println("Interval feeding loaded from EEPROM: " + String(intervalFeedingActive ? "ACTIVE" : "INACTIVE"));
  
  // Try to connect with saved credentials if available
  if (isConfigured && wifiSSID.length() > 0 && wifiPassword.length() > 0) {
      lcd.clear();
      lcd.print("Connecting to");
      lcd.setCursor(0, 1);
      lcd.print(wifiSSID);
      
      WiFi.mode(WIFI_STA);
      WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
      
      int attempts = 0;
      while (WiFi.status() != WL_CONNECTED && attempts < 20) {
          delay(500);
          Serial.print(".");
          attempts++;
          
          // Show progress on LCD
          lcd.setCursor(15, 1);
          lcd.print(attempts % 2 == 0 ? "." : " ");
      }
      
      if (WiFi.status() == WL_CONNECTED) {
          Serial.println("\nConnected to saved WiFi!");
          Serial.println("IP: " + WiFi.localIP().toString());
          
          lcd.clear();
          lcd.print("WiFi Connected!");
          lcd.setCursor(0, 1);
          lcd.print(WiFi.localIP());
          delay(2000);
          
          // Önce NTP zaman senkronizasyonu ve Supabase bağlantısı yap
          Serial.println("Connecting to Supabase and syncing time...");
          connectToSupabase();
          
          // HTTP endpoint'lerini ayarla
          setupEndpoints();
          
          // Setup işlemi tamamlandı, operasyonel moda geç
          isSetupMode = false;
          return;
      }
      
      Serial.println("\nFailed to connect with saved credentials");
      lcd.clear();
      lcd.print("WiFi Failed");
      lcd.setCursor(0, 1);
      lcd.print("Starting AP...");
      delay(2000);
  }
  
  // If we reach here, either there were no saved credentials
  // or connection failed, so start in AP mode
  Serial.println("Starting AP mode...");
  setupAP();
}

  // Yeni HTTP endpoint'lerini ayarla
  void setupEndpoints() {
      // Manuel besleme endpoint'i
      server.on("/feed", HTTP_POST, []() {
          Serial.println("[API] Feed request received");
          
          if (!server.hasArg("amount")) {
              Serial.println("[API] Error: Missing amount parameter");
              server.send(400, "application/json", "{\"error\":\"Missing amount parameter\"}");
              return;
          }
          
          // Ensure proper type conversion from string to float
          String amountStr = server.arg("amount");
          Serial.print("[API] Raw amount parameter: ");
          Serial.println(amountStr);
          
          float amount = amountStr.toFloat();
          Serial.print("[API] Converted amount: ");
          Serial.println(amount);
          
          if (amount <= 0 || amount > MAX_FEED_AMOUNT) {
              Serial.println("[API] Error: Invalid amount");
              server.send(400, "application/json", "{\"error\":\"Invalid amount. Must be between 1 and " + String(MAX_FEED_AMOUNT) + "\"}");
              return;
          }
          
          // Yem seviyesini kontrol et
          float currentFoodLevel = measureFoodLevel();
          // TEST İÇİN GEÇİCİ OLARAK: Yem kontrolünü devre dışı bırak
          // Gerçek sürümde, aşağıdaki kontrolü geri aç:
          /*
          if (currentFoodLevel < 5) {
              Serial.println("[API] Error: Not enough food in container");
              server.send(400, "application/json", "{\"error\":\"Not enough food in container\",\"food_level\":" + String(currentFoodLevel) + "}");
              return;
          }
          */
          
          Serial.println("[API] Current food level: " + String(currentFoodLevel) + "% - Bypassing food level check for testing");
          
          // Ölçüm yaparak mevcut ağırlığı kontrol et
          float currentWeight = measureWeight();
          if (currentWeight < 0) {
              Serial.println("[API] Error: Weight sensor error");
              server.send(400, "application/json", "{\"error\":\"Weight sensor error\"}");
              return;
          }
          
          // Başarılı yanıt döndürmeyi besleme öncesinde yapalım
          Serial.println("[API] Success: Starting feed now from app");
          server.send(200, "application/json", "{\"success\":true,\"message\":\"Feed now started\",\"amount\":" + String(amount) + ",\"type\":\"feed_now\"}");
          
          // Besleme işlemini feed_now tipi ile başlat
          executeFeeding(amount, false, "feed_now");
      });
      
      // Zamanlı besleme endpoint'i
      server.on("/schedule", HTTP_POST, []() {
          Serial.println("[API] Schedule request received");
          
          if (!server.hasArg("hour") || !server.hasArg("minute") || !server.hasArg("amount")) {
              Serial.println("[API] Error: Missing schedule parameters");
              server.send(400, "application/json", "{\"error\":\"Missing parameters. Required: hour, minute, amount\"}");
              return;
          }
          
          // Parse parameters with detailed logging
          String hourStr = server.arg("hour");
          String minuteStr = server.arg("minute");
          String amountStr = server.arg("amount");
          
          Serial.println("[API] Schedule parameters:");
          Serial.println("  Hour (raw): " + hourStr);
          Serial.println("  Minute (raw): " + minuteStr);
          Serial.println("  Amount (raw): " + amountStr);
          
          int hour = hourStr.toInt();
          int minute = minuteStr.toInt();
          float amount = amountStr.toFloat();
          
          Serial.println("[API] Converted values:");
          Serial.println("  Hour: " + String(hour));
          Serial.println("  Minute: " + String(minute));
          Serial.println("  Amount: " + String(amount));
          
          if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || amount <= 0 || amount > MAX_FEED_AMOUNT) {
              Serial.println("[API] Error: Invalid schedule parameters");
              server.send(400, "application/json", "{\"error\":\"Invalid parameters. Hour: 0-23, Minute: 0-59, Amount: 1-" + String(MAX_FEED_AMOUNT) + "\"}");
              return;
          }
          
          // Zamanlı besleme ayarını güncelle
          currentSchedule.active = true;
          currentSchedule.hour = hour;
          currentSchedule.minute = minute;
          currentSchedule.targetWeight = amount;
          
          // Disable interval feeding mode when setting a regular schedule
          intervalFeedingActive = false;
          
          Serial.println("[API] Schedule set successfully:");
          Serial.println("  Time: " + String(hour) + ":" + (minute < 10 ? "0" : "") + String(minute));
          Serial.println("  Amount: " + String(amount) + "g");
          
          // Format nice time string for output
          String timeStr = String(hour) + ":" + (minute < 10 ? "0" : "") + String(minute);
          
          server.send(200, "application/json", "{\"success\":true,\"message\":\"Schedule set\",\"time\":\"" + timeStr + "\",\"amount\":" + String(amount) + "}");
      });
      
      // Interval feeding endpoint - NEW
      server.on("/set_interval_feed", HTTP_POST, []() {
          Serial.println("[API] Interval feeding request received");
          
          if (!server.hasArg("amount")) {
              Serial.println("[API] Error: Missing amount parameter");
              server.send(400, "application/json", "{\"error\":\"Missing amount parameter\"}");
              return;
          }
          
          // Parse parameters with detailed logging
          String amountStr = server.arg("amount");
          String intervalSecondsStr = server.hasArg("interval_seconds") ? server.arg("interval_seconds") : "60";
          String intervalUnitStr = server.hasArg("interval_unit") ? server.arg("interval_unit") : "seconds";
          String displayFormatStr = server.hasArg("display_format") ? server.arg("display_format") : "seconds";
          String autoResetStr = server.hasArg("auto_reset") ? server.arg("auto_reset") : "true";
          
          Serial.println("[API] Interval feeding parameters:");
          Serial.println("  Amount (raw): " + amountStr);
          Serial.println("  Interval seconds (raw): " + intervalSecondsStr);
          Serial.println("  Interval unit (raw): " + intervalUnitStr);
          Serial.println("  Display format (raw): " + displayFormatStr);
          Serial.println("  Auto reset (raw): " + autoResetStr);
          
          float amount = amountStr.toFloat();
          int intervalSeconds = intervalSecondsStr.toInt();
          bool autoReset = (autoResetStr == "true");
          
          // Validate parameters
          if (amount <= 0 || amount > MAX_FEED_AMOUNT) {
              Serial.println("[API] Error: Invalid amount");
              server.send(400, "application/json", "{\"error\":\"Invalid amount. Must be between 1 and " + String(MAX_FEED_AMOUNT) + "\"}");
              return;
          }
          
          if (intervalSeconds <= 0 || intervalSeconds > 86400) { // Max 24 hours in seconds
              Serial.println("[API] Error: Invalid interval");
              server.send(400, "application/json", "{\"error\":\"Invalid interval. Must be between 1 and 86400 seconds\"}");
              return;
          }
          
          // Set interval feeding parameters
          intervalFeedingActive = true;
          intervalFeedingAmount = amount;
          intervalFeedingSeconds = intervalSeconds;
          intervalDisplayFormat = displayFormatStr;
          autoResetAfterFeeding = autoReset;
          lastIntervalFeedingTime = millis();
          secondsRemaining = intervalFeedingSeconds;
          
          // EEPROM'a intervalFeedingActive durumunu kaydet
          EEPROM.write(120, 1); // 1 = true
          EEPROM.commit();
          
          // Disable regular schedule when setting interval feeding
          currentSchedule.active = false;
          
          Serial.println("[API] Interval feeding set successfully:");
          Serial.println("  Interval: " + String(intervalFeedingSeconds) + " seconds");
          Serial.println("  Amount: " + String(intervalFeedingAmount) + "g");
          Serial.println("  Display format: " + intervalDisplayFormat);
          Serial.println("  Auto reset: " + String(autoResetAfterFeeding ? "true" : "false"));
          Serial.println("  Saved to EEPROM: YES");
          
          // Begin feeding immediately for the first time
          executeFeeding(intervalFeedingAmount, true, "interval");
          
          server.send(200, "application/json", "{\"success\":true,\"message\":\"Interval feeding started\",\"interval_seconds\":" + String(intervalFeedingSeconds) + ",\"amount\":" + String(intervalFeedingAmount) + "}");
      });
      
      // Interval status endpoint - NEW
      server.on("/interval_status", HTTP_GET, []() {
          Serial.println("[API] Interval status request received");
          
          // EEPROM'dan interval besleme durumunu oku - memory değişkeniyle çelişme durumunda kesin bilgi için
          bool eepromIntervalStatus = (EEPROM.read(120) == 1);
          
          // Memory ve EEPROM değerlerini senkronize et
          if (intervalFeedingActive != eepromIntervalStatus) {
              Serial.println("[API] Interval feeding state mismatch - syncing with EEPROM");
              intervalFeedingActive = eepromIntervalStatus;
          }
          
          StaticJsonDocument<512> doc;
          doc["interval_active"] = intervalFeedingActive;
          
          if (intervalFeedingActive) {
              // Calculate remaining time
              unsigned long elapsedMillis = millis() - lastIntervalFeedingTime;
              int elapsedSeconds = elapsedMillis / 1000;
              secondsRemaining = intervalFeedingSeconds - elapsedSeconds;
              
              // Ensure seconds_remaining doesn't go negative
              if (secondsRemaining < 0) {
                  secondsRemaining = 0;
              }
              
              doc["interval_seconds"] = intervalFeedingSeconds;
              doc["seconds_remaining"] = secondsRemaining;
              doc["elapsed_seconds"] = elapsedSeconds;
              doc["amount"] = intervalFeedingAmount;
              doc["display_format"] = intervalDisplayFormat;
              doc["auto_reset"] = autoResetAfterFeeding;
          } else {
              // Interval feeding is not active
              doc["seconds_remaining"] = 0;
              doc["message"] = "Interval feeding is not active";
          }
          
          String response;
          serializeJson(doc, response);
          Serial.println("[API] Interval status response: " + response);
          server.send(200, "application/json", response);
      });
      
      // Zamanlanmış beslemeyi iptal etme endpoint'i 
      server.on("/cancel-schedule", HTTP_POST, []() {
          Serial.println("\n[API] ========= SCHEDULE CANCELLATION REQUEST =========");
          Serial.println("[API] Request received from: " + server.client().remoteIP().toString());
          
          // Tüm zamanlama değişkenlerini temizle
          currentSchedule.active = false;
          intervalFeedingActive = false;
          
          // Interval ile ilgili değişkenleri sıfırla
          lastIntervalFeedingTime = 0;
          secondsRemaining = 0;
          intervalFeedingSeconds = 60; // Varsayılan değere geri döndür
          
          // Schedule bilgilerini temizle
          currentSchedule.hour = 0;
          currentSchedule.minute = 0;
          currentSchedule.targetWeight = 0;
          
          // EEPROM'a kaydet - kalıcı olmasını sağla
          EEPROM.write(120, 0); // intervalFeedingActive için adres
          EEPROM.commit();
          
          // Durumu logla
          Serial.println("[API] All schedules cancelled and reset");
          Serial.println("[API] currentSchedule.active = " + String(currentSchedule.active ? "true" : "false"));
          Serial.println("[API] intervalFeedingActive = " + String(intervalFeedingActive ? "true" : "false"));
          Serial.println("[API] Saved to EEPROM");
          Serial.println("[API] currentSchedule.hour = " + String(currentSchedule.hour));
          Serial.println("[API] currentSchedule.minute = " + String(currentSchedule.minute));
          Serial.println("[API] ================================================\n");
          
          // LCD'yi hemen güncelle
          lcd.clear();
          lcd.setCursor(0, 0);
          lcd.print("SCHEDULE");
          lcd.setCursor(0, 1);
          lcd.print("CANCELLED");
          delay(1000);
          
          // Ana menüye dön
          updateLCD();
          
          server.send(200, "application/json", "{\"success\":true,\"message\":\"Schedule cancelled and reset\"}");
      });
      
      // Cihaz durumu endpoint'i
      server.on("/status", HTTP_GET, []() {
          Serial.println("[API] Status request received");
          
          // Cihaz durumunu oluştur
          StaticJsonDocument<512> doc;
          doc["device_key"] = deviceKey;
          doc["food_level"] = foodLevel;
          doc["wifi_signal"] = WiFi.RSSI();
          doc["ip_address"] = WiFi.localIP().toString();
          doc["is_paired"] = isPaired;
          doc["ssid"] = wifiSSID;
          
          // EEPROM'dan interval besleme durumunu oku - memory değişkeniyle çelişme durumunda kesin bilgi için
          bool eepromIntervalStatus = (EEPROM.read(120) == 1);
          
          // Memory ve EEPROM değerlerini senkronize et
          if (intervalFeedingActive != eepromIntervalStatus) {
              Serial.println("[API] Interval feeding state mismatch - syncing with EEPROM");
              intervalFeedingActive = eepromIntervalStatus;
          }
          
          // If interval feeding is active, include that info too
          if (intervalFeedingActive) {
              JsonObject intervalObj = doc.createNestedObject("interval_feeding");
              intervalObj["active"] = true;
              intervalObj["interval_seconds"] = intervalFeedingSeconds;
              
              // Calculate remaining time
              unsigned long elapsedMillis = millis() - lastIntervalFeedingTime;
              int elapsedSeconds = elapsedMillis / 1000;
              secondsRemaining = intervalFeedingSeconds - elapsedSeconds;
              
              // Ensure seconds_remaining doesn't go negative
              if (secondsRemaining < 0) {
                  secondsRemaining = 0;
              }
              
              intervalObj["seconds_remaining"] = secondsRemaining;
              intervalObj["amount"] = intervalFeedingAmount;
          } else {
              // Interval feeding inactive
              JsonObject intervalObj = doc.createNestedObject("interval_feeding");
              intervalObj["active"] = false;
          }
          
          // Eğer aktif bir zamanlama varsa, onu da ekle
          if (currentSchedule.active) {
              JsonObject scheduleObj = doc.createNestedObject("schedule");
              scheduleObj["active"] = true;
              scheduleObj["hour"] = currentSchedule.hour;
              scheduleObj["minute"] = currentSchedule.minute;
              scheduleObj["amount"] = currentSchedule.targetWeight;
          } else {
              JsonObject scheduleObj = doc.createNestedObject("schedule");
              scheduleObj["active"] = false;
          }
          
          String response;
          serializeJson(doc, response);
          
          Serial.println("[API] Sending status response: " + response);
          server.send(200, "application/json", response);
      });
      
      // Heartbeat endpoint'i
      server.on("/heartbeat", HTTP_GET, []() {
          server.send(200, "text/plain", "OK");
      });
      
      // Son besleme durumunu alma endpoint'i
      server.on("/last-feeding", HTTP_GET, []() {
          StaticJsonDocument<256> doc;
          doc["last_feeding_time"] = "Bilinmiyor";  // Bu bilgiyi tutacak bir değişken eklenmeli
          doc["last_feeding_amount"] = lastWeight;
          
          String response;
          serializeJson(doc, response);
          server.send(200, "application/json", response);
      });
      
      // Ana sayfa - Basit kontrol paneli
      server.on("/", HTTP_GET, []() {
          String html = "<html><head><meta name='viewport' content='width=device-width, initial-scale=1'>";
          html += "<title>Pet Feeder Kontrol Paneli</title>";
          html += "<style>body{font-family:Arial,sans-serif;margin:20px;} ";
          html += ".button{background:#4CAF50;color:white;padding:10px 15px;border:none;border-radius:4px;cursor:pointer;margin:5px 0;}";
          html += ".status{background:#f8f9fa;padding:15px;border-radius:4px;margin:10px 0;}</style></head>";
          html += "<body><h1>Pet Feeder Kontrol Paneli</h1>";
          
          html += "<div class='status'>";
          html += "<h2>Cihaz Durumu</h2>";
          html += "<p>Yem Seviyesi: " + String(foodLevel) + "%</p>";
          html += "<p>WiFi Sinyal: " + String(WiFi.RSSI()) + " dBm</p>";
          html += "<p>IP Adresi: " + WiFi.localIP().toString() + "</p>";
          html += "</div>";
          
          html += "<div>";
          html += "<h2>Hemen Besle</h2>";
          html += "<form action='/feed' method='post'>";
          html += "<label>Miktar (g): <input type='number' name='amount' min='10' max='100' value='50'></label>";
          html += "<input type='submit' value='Besle' class='button'>";
          html += "</form>";
          html += "</div>";
          
          html += "<div>";
          html += "<h2>Zamanlı Besleme</h2>";
          html += "<form action='/schedule' method='post'>";
          html += "<label>Saat: <input type='number' name='hour' min='0' max='23' value='8'></label><br>";
          html += "<label>Dakika: <input type='number' name='minute' min='0' max='59' value='0'></label><br>";
          html += "<label>Miktar (g): <input type='number' name='amount' min='10' max='100' value='50'></label><br>";
          html += "<input type='submit' value='Ayarla' class='button'>";
          html += "</form>";
          html += "</div>";
          
          // Add interval feeding form
          html += "<div>";
          html += "<h2>Interval Feeding (Minute Mode)</h2>";
          html += "<form action='/set_interval_feed' method='post'>";
          html += "<label>Interval (seconds): <input type='number' name='interval_seconds' min='10' max='3600' value='60'></label><br>";
          html += "<label>Amount (g): <input type='number' name='amount' min='10' max='100' value='50'></label><br>";
          html += "<input type='submit' value='Start Interval Feeding' class='button'>";
          html += "</form>";
          html += "</div>";
          
          if (currentSchedule.active) {
              html += "<div class='status'>";
              html += "<h2>Aktif Zamanlama</h2>";
              html += "<p>Saat: " + String(currentSchedule.hour) + ":" + (currentSchedule.minute < 10 ? "0" : "") + String(currentSchedule.minute) + "</p>";
              html += "<p>Miktar: " + String(currentSchedule.targetWeight) + "g</p>";
              html += "<form action='/cancel-schedule' method='post'>";
              html += "<input type='submit' value='İptal Et' class='button' style='background-color:#f44336;'>";
              html += "</form>";
              html += "</div>";
          }
          
          if (intervalFeedingActive) {
              html += "<div class='status'>";
              html += "<h2>Active Interval Feeding</h2>";
              
              // Calculate remaining time
              unsigned long elapsedMillis = millis() - lastIntervalFeedingTime;
              int elapsedSeconds = elapsedMillis / 1000;
              int remainingSeconds = intervalFeedingSeconds - elapsedSeconds;
              if (remainingSeconds < 0) remainingSeconds = 0;
              
              html += "<p>Interval: " + String(intervalFeedingSeconds) + " seconds</p>";
              html += "<p>Next feeding in: " + String(remainingSeconds) + " seconds</p>";
              html += "<p>Amount: " + String(intervalFeedingAmount) + "g</p>";
              html += "<form action='/cancel-schedule' method='post'>";
              html += "<input type='submit' value='Cancel' class='button' style='background-color:#f44336;'>";
              html += "</form>";
              html += "</div>";
          }
          
          html += "</body></html>";
          server.send(200, "text/html", html);
      });
      
      server.begin();
      Serial.println("HTTP server started");
      Serial.println("Control panel available at http://" + WiFi.localIP().toString());
  }

  

  void loop() {
    if (isSetupMode) {
        server.handleClient();
    } else {
        // Her döngüde interval besleme durumunu kontrol et ve debug loglarını yaz
        static unsigned long lastIntervalStatusCheck = 0;
        if (millis() - lastIntervalStatusCheck >= 5000) { // Her 5 saniyede bir kontrol et
            lastIntervalStatusCheck = millis();
            Serial.println("\n[STATUS CHECK] =========================");
            Serial.println("[STATUS CHECK] Interval feeding active: " + String(intervalFeedingActive ? "YES" : "NO"));
            Serial.println("[STATUS CHECK] Regular schedule active: " + String(currentSchedule.active ? "YES" : "NO"));
            
            // EEPROM'da kayıtlı değerle karşılaştır
            bool eepromValue = (EEPROM.read(120) == 1);
            Serial.println("[STATUS CHECK] EEPROM interval state: " + String(eepromValue ? "YES" : "NO"));
            
            // EEPROM ve memory değerleri aynı değilse düzelt
            if (eepromValue != intervalFeedingActive) {
                Serial.println("[STATUS CHECK] *** MISMATCH DETECTED: Fixing interval state ***");
                intervalFeedingActive = eepromValue;
            }
            
            // Eğer her ikisi de inaktifse secondsRemaining sıfırlansın
            if (!intervalFeedingActive && !currentSchedule.active) {
                secondsRemaining = 0;
                Serial.println("[STATUS CHECK] No active schedules, countdown reset to 0");
            }
            
            Serial.println("[STATUS CHECK] =========================\n");
        }
        
        // Handle HTTP requests - Önce HTTP isteklerini işle çünkü iptal emirleri buradan geliyor
        server.handleClient();
        
        // Check WiFi connection
        static unsigned long lastWiFiCheck = 0;
        const unsigned long WIFI_CHECK_INTERVAL = 30000; // 30 saniye
        
        if (millis() - lastWiFiCheck >= WIFI_CHECK_INTERVAL) {
            lastWiFiCheck = millis();
            
            // Check WiFi first
            if (WiFi.status() != WL_CONNECTED) {
                Serial.println("\n[Connection] WiFi disconnected, attempting to reconnect...");
                WiFi.disconnect();
                delay(1000);
                WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
                
                // Wait for WiFi connection
                int attempts = 0;
                while (WiFi.status() != WL_CONNECTED && attempts < 10) {
                    delay(500);
                    attempts++;
                }
                
                if (WiFi.status() == WL_CONNECTED) {
                    Serial.println("[Connection] WiFi reconnected!");
                }
            }
        }
        
        // Handle manual controls for servo testing
        if (Serial.available() > 0) {
            char cmd = Serial.read();
            
            switch (cmd) {
                case '1':  // Open servo
                    Serial.println("Manual command: Opening servo");
                    startServo();
                    feedServo.write(SERVO_FEED_POSITION);
                    delay(1000);
                    stopServo();
                    break;
                    
                case '0':  // Close servo
                    Serial.println("Manual command: Closing servo");
                    startServo();
                    feedServo.write(SERVO_REST_POSITION);
                    delay(1000);
                    stopServo();
                    break;
                    
                case 'f':  // Feed with default amount
                    Serial.println("Manual command: Feeding with default amount");
                    executeFeeding(DEFAULT_FEED_AMOUNT, false, "manual");
                    break;
                    
                case 's':  // Display servo information
                    Serial.println("Servo status:");
                    Serial.println("Feed position: " + String(SERVO_FEED_POSITION));
                    Serial.println("Rest position: " + String(SERVO_REST_POSITION));
                    break;
                    
                case 'b':  // Display button ADC value
                    {
                        int adc_val = analogRead(LCD_BUTTONS_PIN);
                        Serial.println("Button ADC value: " + String(adc_val));
                    }
                    break;
                    
                // Manuel olarak schedule iptali için komut ekle
                case 'c':  // Cancel all schedules
                    Serial.println("\n*** MANUAL COMMAND: CANCELLING ALL SCHEDULES ***");
                    currentSchedule.active = false;
                    intervalFeedingActive = false;
                    lastIntervalFeedingTime = 0;
                    secondsRemaining = 0;
                    
                    // EEPROM'a kaydet
                    EEPROM.write(120, 0); // intervalFeedingActive için adres
                    EEPROM.commit();
                    Serial.println("All schedules cancelled manually");
                    Serial.println("intervalFeedingActive = " + String(intervalFeedingActive ? "true" : "false"));
                    Serial.println("Saved to EEPROM");
                    break;
            }
        }
        
        // Handle HTTP requests again to ensure we don't miss any commands
        server.handleClient();
        
        // Check scheduled feeding
        checkAndExecuteSchedule();
        
        // Handle other operational tasks - buttons and LCD updates
        handleButtons();
        
        // Update LCD once per second
        static unsigned long lastLCDUpdateTime = 0;
        if (millis() - lastLCDUpdateTime >= 1000) { // Update LCD once per second
            lastLCDUpdateTime = millis();
            updateLCD(); // Hem normal hem de interval besleme için tek bir fonksiyon kullan
        }
        
        // Check food level periodically
        static unsigned long lastFoodLevelCheck = 0;
        if (millis() - lastFoodLevelCheck >= FOOD_LEVEL_UPDATE_INTERVAL) {
            lastFoodLevelCheck = millis();
            float newFoodLevel = measureFoodLevel();
            if (abs(newFoodLevel - foodLevel) > 5.0) { // Only update if significant change
                updateFoodLevel(newFoodLevel);
            }
        }
        
        // Son bir kez daha HTTP istekleri kontrol edilsin
        server.handleClient();
    }
  }

  void setupAP() {
    WiFi.mode(WIFI_AP_STA);  // AP ve STA modunu aynı anda etkinleştir
    WiFi.softAP(AP_SSID, AP_PASSWORD);
    
    Serial.println("\nAP Mode Started");
    Serial.print("SSID: ");
    Serial.println(AP_SSID);
    Serial.print("Password: ");
    Serial.println(AP_PASSWORD);
    Serial.print("AP IP Address: ");
    Serial.println(WiFi.softAPIP());
    
    // Show AP info on LCD
    lcd.clear();
    lcd.print("Connect to WiFi:");
    lcd.setCursor(0, 1);
    lcd.print(AP_SSID);
    
    // Setup web server endpoints
    server.on("/", HTTP_GET, handleRoot);
    server.on("/setup", HTTP_GET, handleConfigPage);
    server.on("/setup", HTTP_POST, handleWiFiSetup);
    server.on("/pair-status", HTTP_GET, handlePairingStatus);
    server.on("/wifi", HTTP_POST, handleWiFiCredentials);
    server.begin();
    
    Serial.println("HTTP server started");
    Serial.println("Waiting for WiFi configuration...");
  }

  void handleRoot() {
    String deviceId = getDeviceId();
    String apIpAddress = WiFi.softAPIP().toString();
    String configURL = "http://" + apIpAddress + "/setup";
    
    String html = "<html><head>";
    // Otomatik olarak setup sayfasına yönlendir
    html += "<meta http-equiv='refresh' content='2;url=/setup'>";
    html += "</head><body style='font-family: Arial, sans-serif; margin: 20px;'>";
    html += "<h1>Pet Feeder Setup</h1>";
    html += "<p>Device ID: <strong>" + deviceId + "</strong></p>";
    html += "<p>This device is now in setup mode and has created a WiFi access point.</p>";
    html += "<p>Connect to the WiFi network named <strong>" + String(AP_SSID) + "</strong> with password <strong>" + String(AP_PASSWORD) + "</strong></p>";
    
    html += "<div style='margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-radius: 5px;'>";
    html += "<h2>Redirecting to WiFi Configuration Page...</h2>";
    html += "<p>If you are not automatically redirected, please <a href='/setup'>click here</a> to go to the WiFi setup page.</p>";
    html += "</div>";
    
    html += "<div style='margin-top: 30px; padding: 15px; background-color: #f8f9fa; border-radius: 5px;'>";
    html += "<h2>Setup Instructions:</h2>";
    html += "<ol>";
    html += "<li>Connect to the WiFi network <strong>" + String(AP_SSID) + "</strong></li>";
    html += "<li>You will be automatically redirected to the WiFi configuration page</li>";
    html += "<li>Enter your home WiFi credentials on the configuration page</li>";
    html += "<li>The device will connect to your home WiFi and update its status in the app</li>";
    html += "</ol>";
    html += "</div>";
    
    html += "</body></html>";
    server.send(200, "text/html", html);
  }

  void handleConfigPage() {
    String deviceId = getDeviceId();
    deviceKey = "PF_" + deviceId;
    
    // Save device key to EEPROM
    for (int i = 0; i < deviceKey.length(); i++) {
      EEPROM.write(EEPROM_DEVICE_KEY_ADDR + i, deviceKey[i]);
    }
    EEPROM.write(EEPROM_DEVICE_KEY_ADDR + deviceKey.length(), 0);
    EEPROM.commit();
    
    String html = "<html><body style='font-family: Arial, sans-serif; margin: 20px;'>";
    html += "<h1>WiFi Configuration</h1>";
    html += "<p>Device Key: <strong>" + deviceKey + "</strong></p>";
    html += "<p>Enter your home WiFi credentials below:</p>";
    html += "<form method='post' action='/setup' style='margin: 20px 0;'>";
    html += "<div style='margin: 10px 0;'>";
    html += "<label>WiFi SSID: <input type='text' name='ssid' placeholder='Your WiFi Name' required style='padding: 5px;'></label>";
    html += "</div>";
    html += "<div style='margin: 10px 0;'>";
    html += "<label>WiFi Password: <input type='password' name='password' placeholder='Your WiFi Password' required style='padding: 5px;'></label>";
    html += "</div>";
    html += "<input type='submit' value='Connect' style='padding: 10px; background-color: #4CAF50; color: white; border: none; border-radius: 4px; cursor: pointer;'>";
    html += "</form>";
    html += "</body></html>";
    server.send(200, "text/html", html);
  }

  void handleWiFiSetup() {
    if (!server.hasArg("ssid") || !server.hasArg("password")) {
      server.send(400, "text/plain", "Missing WiFi credentials");
      return;
    }

    String newSSID = server.arg("ssid");
    String newPassword = server.arg("password");

    Serial.println("[WiFi] Received credentials from web form:");
    Serial.println("  SSID: " + newSSID);
    Serial.println("  Password length: " + String(newPassword.length()));

    // Show status on LCD
    lcd.clear();
    lcd.print("WiFi Ayarlandi");
    lcd.setCursor(0, 1);
    lcd.print("Baglaniyor...");

    // Save WiFi credentials to EEPROM first
    saveWifiCredentials(newSSID, newPassword);

    // Send response and then try to connect
    String html = "<html><head>";
    html += "<meta http-equiv='refresh' content='5;url=/pair-status'>";
    html += "</head><body style='font-family: Arial, sans-serif; margin: 20px;'>";
    html += "<h1>Connecting to WiFi...</h1>";
    html += "<p>Attempting to connect to <strong>" + newSSID + "</strong></p>";
    html += "<p>The device is now trying to connect to your WiFi network.</p>";
    html += "<p>This page will automatically refresh to show the connection status.</p>";
    html += "<div style='margin: 20px 0; text-align: center;'>";
    html += "<img src='https://i.gifer.com/origin/b4/b4d657e7ef262b88eb5f7ac021edda87.gif' alt='Loading' style='width: 50px;'>";
    html += "</div>";
    html += "</body></html>";
    server.send(200, "text/html", html);
    
    // Now try to connect to the new WiFi after sending response
    connectToNewWiFi(newSSID, newPassword);
  }
  
  void saveWifiCredentials(String ssid, String password) {
    // Save WiFi credentials to EEPROM
    for (int i = 0; i < ssid.length(); i++) {
      EEPROM.write(EEPROM_WIFI_SSID_ADDR + i, ssid[i]);
    }
    EEPROM.write(EEPROM_WIFI_SSID_ADDR + ssid.length(), 0);

    for (int i = 0; i < password.length(); i++) {
      EEPROM.write(EEPROM_WIFI_PASS_ADDR + i, password[i]);
    }
    EEPROM.write(EEPROM_WIFI_PASS_ADDR + password.length(), 0);
    
    // Set configured flag
    EEPROM.write(EEPROM_SETUP_FLAG_ADDR, 1);
    EEPROM.commit();
    
    // Update global variables
    wifiSSID = ssid;
    wifiPassword = password;
    isConfigured = true;
    
    Serial.println("[WiFi] Credentials saved to EEPROM");
  }
  
  void connectToNewWiFi(String ssid, String password) {
    Serial.println("[WiFi] Attempting to connect to new WiFi network: " + ssid);
    
    // Disconnect from any current WiFi
    WiFi.disconnect();
    delay(1000);
    
    // Make sure we're in station + AP mode
    WiFi.mode(WIFI_AP_STA);
    delay(1000);
    
    // Connect to the new WiFi
    WiFi.begin(ssid.c_str(), password.c_str());
    
    // Wait for connection with more verbose output
    int attempts = 0;
    const int maxAttempts = 30; // Try for 30 seconds
    
    Serial.println("[WiFi] Connecting...");
    
    while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
      delay(1000);
      attempts++;
      
      // Show progress on LCD and Serial
      Serial.print(".");
      lcd.setCursor(0, 1);
      lcd.print("Attempt: ");
      lcd.print(attempts);
      lcd.print("/");
      lcd.print(maxAttempts);
      
      // Every 5 attempts, print WiFi status
      if (attempts % 5 == 0) {
        Serial.println();
        Serial.print("[WiFi] Status: ");
        Serial.println(getWiFiStatusString(WiFi.status()));
      }
    }
    
    Serial.println();
    
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("[WiFi] Successfully connected to new network!");
      Serial.println("  IP address: " + WiFi.localIP().toString());
      
      // Show success on LCD
      lcd.clear();
      lcd.print("WiFi Baglandi!");
      lcd.setCursor(0, 1);
      lcd.print(WiFi.localIP());
      
      delay(2000);
      
      // Now switch to operational mode and connect to Supabase
      isSetupMode = false;
      connectToSupabase();
    } else {
      Serial.println("[WiFi] Failed to connect to new network");
      Serial.print("[WiFi] Status: ");
      Serial.println(getWiFiStatusString(WiFi.status()));
      
      // Show error on LCD
      lcd.clear();
      lcd.print("WiFi Hatasi!");
      lcd.setCursor(0, 1);
      lcd.print(getWiFiStatusString(WiFi.status()));
      delay(2000);
      
      // Return to access point mode
      lcd.clear();
      lcd.print("AP Mode Active");
      lcd.setCursor(0, 1);
      lcd.print(WiFi.softAPIP());
    }
  }
  
  String getWiFiStatusString(int status) {
    switch (status) {
      case WL_CONNECTED: return "Connected";
      case WL_NO_SHIELD: return "No Shield";
      case WL_IDLE_STATUS: return "Idle";
      case WL_NO_SSID_AVAIL: return "No SSID Available";
      case WL_SCAN_COMPLETED: return "Scan Completed";
      case WL_CONNECT_FAILED: return "Connection Failed";
      case WL_CONNECTION_LOST: return "Connection Lost";
      case WL_DISCONNECTED: return "Disconnected";
      default: return "Unknown: " + String(status);
    }
  }

  void handlePairingStatus() {
    bool connected = WiFi.status() == WL_CONNECTED;
    String html = "<html><body style='font-family: Arial, sans-serif; margin: 20px;'>";
    
    if (connected) {
      html += "<h1 style='color: green;'>WiFi Connected Successfully!</h1>";
      html += "<p>The device has successfully connected to your WiFi network.</p>";
      html += "<p>IP Address: <strong>" + WiFi.localIP().toString() + "</strong></p>";
      html += "<p>Device Key: <strong>" + deviceKey + "</strong></p>";
      html += "<p>The pet feeder is now online and will be available in your mobile app shortly.</p>";
      
      // JavaScript ile sayfayı düzenli olarak yenile ve durumu kontrol et
      html += "<script>";
      html += "setTimeout(function() { window.location.reload(); }, 5000);"; // 5 saniyede bir sayfayı yenile
      html += "</script>";
      
      // Switch to operational mode
      isSetupMode = false;
      connectToSupabase();
    } else {
      int wifiStatus = WiFi.status();
      html += "<h1 style='color: red;'>WiFi Connection Failed</h1>";
      html += "<p>The device could not connect to the specified WiFi network.</p>";
      html += "<p>WiFi Status: <strong>" + getWiFiStatusString(wifiStatus) + "</strong></p>";
      
      // Show different messages based on status
      switch (wifiStatus) {
        case WL_NO_SSID_AVAIL:
          html += "<p>The specified WiFi network was not found. Please check the SSID.</p>";
          break;
        case WL_CONNECT_FAILED:
          html += "<p>Connection failed. This might be due to an incorrect password.</p>";
          break;
        case WL_DISCONNECTED:
          html += "<p>WiFi disconnected. The device might be out of range of the access point.</p>";
          break;
        default:
          html += "<p>Please check your WiFi credentials and try again.</p>";
          break;
      }
      
      // JavaScript ile sayfayı düzenli olarak yenile ve durumu kontrol et
      html += "<script>";
      html += "setTimeout(function() { window.location.reload(); }, 3000);"; // 3 saniyede bir sayfayı yenile
      html += "</script>";
      
      // Add retry button
      html += "<div style='margin: 20px 0;'>";
      html += "<a href='/setup' style='padding: 10px 20px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 4px;'>Try Again</a>";
      html += "</div>";
      
      // Show current WiFi settings
      html += "<div style='margin-top: 20px; padding: 15px; background-color: #f8f9fa; border-radius: 5px;'>";
      html += "<h3>Current Settings:</h3>";
      html += "<p>SSID: <strong>" + wifiSSID + "</strong></p>";
      html += "<p>Password: <strong>*****</strong></p>";
      html += "</div>";
    }
    
    html += "</body></html>";
    server.send(200, "text/html", html);
  }

  void handleWiFiCredentials() {
    Serial.println("\n[WiFi] Received WiFi credentials request");
    Serial.println("[WiFi] Method: " + server.method());
    Serial.println("[WiFi] URI: " + server.uri());
    Serial.println("[WiFi] Arguments: " + String(server.args()));
    
    // Print all headers
    Serial.println("[WiFi] Headers:");
    for (int i = 0; i < server.headers(); i++) {
      Serial.println("  " + server.headerName(i) + ": " + server.header(i));
    }
    
    // Print all arguments
    Serial.println("[WiFi] Arguments:");
    for (int i = 0; i < server.args(); i++) {
      Serial.println("  " + server.argName(i) + ": " + server.arg(i));
    }

    if (!server.hasArg("ssid") || !server.hasArg("password")) {
      Serial.println("[WiFi] Error: Missing WiFi credentials");
      server.send(400, "text/plain", "Missing WiFi credentials");
      return;
    }

    String newSSID = server.arg("ssid");
    String newPassword = server.arg("password");

    Serial.println("[WiFi] Received credentials:");
    Serial.println("  SSID: " + newSSID);
    Serial.println("  Password length: " + String(newPassword.length()));

    // Show status on LCD
    lcd.clear();
    lcd.print("WiFi Ayarlandi");
    lcd.setCursor(0, 1);
    lcd.print("Baglaniyor...");

    // Try to connect to the new WiFi while keeping AP active
    Serial.println("[WiFi] Attempting to connect to new network...");
    WiFi.begin(newSSID.c_str(), newPassword.c_str());
    
    // Wait for connection for 10 seconds
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("[WiFi] Successfully connected to new network");
      Serial.println("  IP address: " + WiFi.localIP().toString());
      
      // Save WiFi credentials to EEPROM
      Serial.println("[WiFi] Saving credentials to EEPROM...");
      for (int i = 0; i < newSSID.length(); i++) {
        EEPROM.write(EEPROM_WIFI_SSID_ADDR + i, newSSID[i]);
      }
      EEPROM.write(EEPROM_WIFI_SSID_ADDR + newSSID.length(), 0);

      for (int i = 0; i < newPassword.length(); i++) {
        EEPROM.write(EEPROM_WIFI_PASS_ADDR + i, newPassword[i]);
      }
      EEPROM.write(EEPROM_WIFI_PASS_ADDR + newPassword.length(), 0);

      // Set configured flag
      EEPROM.write(EEPROM_SETUP_FLAG_ADDR, 1);
      EEPROM.commit();
      Serial.println("[WiFi] Credentials saved to EEPROM");

      // Update global variables
      wifiSSID = newSSID;
      wifiPassword = newPassword;
      isConfigured = true;
      
      // Show success on LCD
      lcd.clear();
      lcd.print("WiFi Baglandi!");
      lcd.setCursor(0, 1);
      lcd.print(WiFi.localIP());

      // Send success response with detailed information
      String response = "WiFi credentials saved and connected successfully\n";
      response += "IP: " + WiFi.localIP().toString() + "\n";
      response += "SSID: " + newSSID;
      
      Serial.println("[WiFi] Sending success response to client");
      server.send(200, "text/plain", response);
      
      // Wait a bit before switching to operational mode
      delay(1000);
      
      // Switch to operational mode and connect to Supabase
      Serial.println("[WiFi] Switching to operational mode");
      isSetupMode = false;
      connectToSupabase();
    } else {
      Serial.println("[WiFi] Failed to connect to new network");
      
      // Show error on LCD
      lcd.clear();
      lcd.print("WiFi Hatasi!");
      lcd.setCursor(0, 1);
      lcd.print("Tekrar Deneyin");
      
      String response = "Failed to connect to WiFi\n";
      response += "SSID: " + newSSID + "\n";
      response += "Status: " + String(WiFi.status());
      
      Serial.println("[WiFi] Sending error response to client");
      server.send(400, "text/plain", response);
    }
  }

  void handleSetup() {
    if (server.hasArg("device_key")) {
      deviceKey = server.arg("device_key");
      
      // Save device key to EEPROM
      for (int i = 0; i < deviceKey.length(); i++) {
        EEPROM.write(EEPROM_DEVICE_KEY_ADDR + i, deviceKey[i]);
      }
      EEPROM.write(EEPROM_DEVICE_KEY_ADDR + deviceKey.length(), 0);
      
      // Set configured flag
      EEPROM.write(EEPROM_SETUP_FLAG_ADDR, 1);
      EEPROM.commit();
      
      isConfigured = true;
      
      String response = "<html><body style='font-family: Arial, sans-serif; margin: 20px;'>";
      response += "<h1>Device Configured Successfully!</h1>";
      response += "<p>Device Key: <strong>" + deviceKey + "</strong></p>";
      response += "<p>Please note down this device key and use it in the mobile app to continue setup.</p>";
      response += "<p style='color: #666;'>You can now close this page and use the mobile app to configure WiFi.</p>";
      response += "</body></html>";
      server.send(200, "text/html", response);
      
      // Show success on LCD
      lcd.clear();
      lcd.print("Setup Complete!");
      lcd.setCursor(0, 1);
      lcd.print("Use Mobile App");
      
      Serial.println("Device configured with key: " + deviceKey);
      Serial.println("Waiting for WiFi configuration from mobile app...");
    }
  }

  void loadConfiguration() {
    // Read configured flag
    isConfigured = EEPROM.read(EEPROM_SETUP_FLAG_ADDR) == 1;
    
    if (isConfigured) {
      // Read device key
      char key[32];
      int i;
      for (i = 0; i < 31; i++) {
        char c = EEPROM.read(EEPROM_DEVICE_KEY_ADDR + i);
        if (c == 0) break;
        key[i] = c;
      }
      key[i] = 0;
      deviceKey = String(key);
      
      // Read WiFi credentials if they exist
      char ssid[64];
      char pass[64];
      
      for (i = 0; i < 63; i++) {
        char c = EEPROM.read(EEPROM_WIFI_SSID_ADDR + i);
        if (c == 0) break;
        ssid[i] = c;
      }
      ssid[i] = 0;
      wifiSSID = String(ssid);
      
      for (i = 0; i < 63; i++) {
        char c = EEPROM.read(EEPROM_WIFI_PASS_ADDR + i);
        if (c == 0) break;
        pass[i] = c;
      }
      pass[i] = 0;
      wifiPassword = String(pass);
    }
  }

  void connectToWiFi() {
    if (wifiSSID.length() > 0 && wifiPassword.length() > 0) {
      WiFi.mode(WIFI_STA);
      WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
      
      int attempts = 0;
      while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
      }
      
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nConnected to WiFi");
        connectToSupabase();
      }
    }
  }

  void connectToSupabase() {
    Serial.println("\n[Supabase] ========= CONNECTING TO SUPABASE =========");
    
    // Clear LCD and show starting message
    lcd.clear();
    lcd.print("Connecting to");
    lcd.setCursor(0, 1);
    lcd.print("Database...");
    delay(500);
    
    // Step 1: Setup NTP time
    bool timeSet = setupTimeWithRetries();
    Serial.println("[Supabase] NTP time setup: " + String(timeSet ? "Success" : "Failed"));
    
    // Step 2: Register/check device (simplified approach)
    lcd.clear();
    lcd.print("Checking Device");
    lcd.setCursor(0, 1);
    lcd.print("Registration...");
    
    // This simplified function just checks if device exists and is paired
    isPaired = registerDeviceInDatabase();
    Serial.println("[Supabase] isPaired status: " + String(isPaired ? "TRUE" : "FALSE"));
    
    // If not in database or need to update, create simple update payload
    StaticJsonDocument<256> updateDoc;
    updateDoc["device_key"] = deviceKey;
    updateDoc["ip_address"] = WiFi.localIP().toString();
    updateDoc["wifi_signal_strength"] = WiFi.RSSI();
    updateDoc["wifi_ssid"] = wifiSSID;
    
    // First time device? Include these fields
    if (!isPaired) {
        updateDoc["is_paired"] = true; // Auto-pair for testing
        updateDoc["name"] = "Pet Feeder " + WiFi.macAddress().substring(9);
        updateDoc["food_level"] = measureFoodLevel();
        
        lcd.clear();
        lcd.print("Creating New");
        lcd.setCursor(0, 1);
        lcd.print("Device Record...");
    } else {
        lcd.clear();
        lcd.print("Updating Device");
        lcd.setCursor(0, 1);
        lcd.print("Information...");
    }
    
    // Serialize to JSON
    String payload;
    serializeJson(updateDoc, payload);
    Serial.println("[Supabase] Update payload: " + payload);
    
    // Create a new HTTP client for this request
    HTTPClient http;
    String url = String(SUPABASE_URL) + DEVICES_ENDPOINT;
    
    // If device exists, use PATCH, otherwise use POST
    if (isPaired) {
        url += "?device_key=eq." + deviceKey;
        http.begin(url);
        http.addHeader("Content-Type", "application/json");
        http.addHeader("apikey", SUPABASE_KEY);
        http.addHeader("Authorization", "Bearer " + String(SUPABASE_KEY));
        http.addHeader("Prefer", "return=minimal");
        http.setTimeout(5000);
        
        int httpCode = http.PATCH(payload);
        Serial.println("[Supabase] PATCH response: " + String(httpCode));
    } else {
        http.begin(url);
        http.addHeader("Content-Type", "application/json");
        http.addHeader("apikey", SUPABASE_KEY);
        http.addHeader("Authorization", "Bearer " + String(SUPABASE_KEY));
        http.addHeader("Prefer", "return=minimal");
        http.setTimeout(5000);
        
        int httpCode = http.POST(payload);
        Serial.println("[Supabase] POST response: " + String(httpCode));
        
        // If we successfully created the device, mark as paired
        if (httpCode >= 200 && httpCode < 300) {
            isPaired = true;
        }
    }
    
    // Make sure to clean up
    http.end();
    Serial.println("[Supabase] HTTP connection closed");
    
    // Show status on LCD
    lcd.clear();
    if (isPaired) {
        lcd.print("Device Ready!");
        lcd.setCursor(0, 1);
        lcd.print("Connection OK");
    } else {
        lcd.print("Waiting Pairing");
        lcd.setCursor(0, 1);
        lcd.print("from Mobile App");
    }
    delay(2000);
    
    // Measure food level
    lcd.clear();
    lcd.print("Measuring Food");
    lcd.setCursor(0, 1);
    lcd.print("Level...");
    
    float newFoodLevel = measureFoodLevel();
    foodLevel = newFoodLevel; // Update global variable
    Serial.println("[Supabase] Food level measured: " + String(newFoodLevel) + "%");
    
    // Instead of getting food level from database, we update database with our measured value
    Serial.println("[Supabase] Updating database with current food level");
    updateFoodLevel(newFoodLevel);
    
    // Setup HTTP endpoints
    setupEndpoints();
    
    // Switch to operational mode
    isSetupMode = false;
    
    Serial.println("[Supabase] ========= CONNECTION SETUP COMPLETE =========\n");
}

// Simplified device registration function - only checks if exists and returns isPaired
bool registerDeviceInDatabase() {
    Serial.println("[Supabase] Checking device in database...");
    
    HTTPClient http;
    String url = String(SUPABASE_URL) + DEVICES_ENDPOINT + "?device_key=eq." + deviceKey;
    
    // Set timeout for HTTP request
    http.setTimeout(3000);
    
    // Start HTTP request
    http.begin(url);
    http.addHeader("apikey", SUPABASE_KEY);
    http.addHeader("Authorization", "Bearer " + String(SUPABASE_KEY));
    
    // Execute GET request
    int httpCode = http.GET();
    
    // Handle response
    bool deviceExists = false;
    bool deviceIsPaired = false;
    
    if (httpCode == 200) {
        String response = http.getString();
        Serial.println("[Supabase] Response: " + response);
        
        deviceExists = (response.length() > 2); // "[]" is 2 chars
        
        if (deviceExists) {
            // Parse JSON to check if paired
            StaticJsonDocument<512> doc;
            DeserializationError error = deserializeJson(doc, response);
            
            if (!error) {
                JsonArray array = doc.as<JsonArray>();
                if (array.size() > 0) {
                    if (array[0].containsKey("is_paired")) {
                        deviceIsPaired = array[0]["is_paired"].as<bool>();
                        Serial.println("[Supabase] Device is_paired = " + String(deviceIsPaired ? "TRUE" : "FALSE"));
                    }
                }
            }
        }
    } else {
        Serial.println("[Supabase] Failed to get device: " + String(httpCode));
    }
    
    // Always close connection
    http.end();
    Serial.println("[Supabase] HTTP connection closed");
    
    return deviceIsPaired;
}

  void updateDeviceInfo() {
    // This function is now empty as the device info is updated through the setup process
  }

  void handleStatus() {
    // This function is now empty as the status is handled through the setup process
  }

  void showSetupInfo() {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Setup Mode");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.softAPIP());
    delay(2000);
  }

  void showOperationalInfo() {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Device: ");
    lcd.print(deviceKey);
    lcd.setCursor(0, 1);
    lcd.print(WiFi.status() == WL_CONNECTED ? "Connected" : "No WiFi");
    delay(2000);
  }

void setupWiFi() {
  if (WIFI_SSID.isEmpty() || WIFI_PASSWORD.isEmpty()) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Bilgisi Yok!");
    lcd.setCursor(0, 1);
      lcd.print("Supabase Bekliyor");
    return;
  }

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WiFi Baglaniyor");
  lcd.setCursor(0, 1);
  lcd.print(WIFI_SSID);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID.c_str(), WIFI_PASSWORD.c_str());
  
  unsigned long startAttemptTime = millis();
  
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < WIFI_CONNECT_TIMEOUT) {
    delay(500);
    lcd.setCursor((millis() / 500) % 13, 1);
    lcd.print(".");
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Baglandi!");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP().toString());
    
    if (!isPaired) {
      sendPairingRequest();
    }
    
    delay(2000);
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Cihaz Hazir!");
    lcd.setCursor(0, 1);
    lcd.print("Feed Now: SELECT");
  } else {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Hatasi!");
    lcd.setCursor(0, 1);
      lcd.print("Tekrar Denenecek");
    delay(2000);
  }
}

  void setupLCD() {
    lcd.begin(LCD_COLS, LCD_ROWS);
    delay(100); // Give LCD time to initialize
    
    // Set LCD contrast to maximum for better visibility
    if (LCD_CONTRAST_PIN != 0) {
      pinMode(LCD_CONTRAST_PIN, OUTPUT);
      analogWrite(LCD_CONTRAST_PIN, 255); // Maximum contrast (0-255)
      Serial.println("LCD contrast set to maximum");
    }
    
    // Print with solid text
    lcd.clear();
    lcd.print("PETFEEDER V1.0");  // All caps for better visibility
    lcd.setCursor(0, 1);
    lcd.print("STARTING...");
    delay(2000);  // Longer delay to see startup message
    
    // Force refresh the display
    refreshLCD();
  }

  void setupButtons() {
    // Analog buton pini giriş olarak tanımla
    pinMode(LCD_BUTTONS_PIN, INPUT);
    
    // Always initialize digital buttons for more reliability
    pinMode(BTN_SELECT_PIN, INPUT_PULLUP);
    pinMode(BTN_UP_PIN, INPUT_PULLUP);
    pinMode(BTN_DOWN_PIN, INPUT_PULLUP);
    pinMode(BTN_LEFT_PIN, INPUT_PULLUP);
    pinMode(BTN_RIGHT_PIN, INPUT_PULLUP);
    
    Serial.println("Buttons initialized");
    Serial.println("Using digital buttons: " + String(USE_DIGITAL_BUTTONS ? "YES" : "NO"));
    
    // Print button pin assignments for reference
    Serial.println("Button pin assignments:");
    Serial.println("SELECT: GPIO " + String(BTN_SELECT_PIN));
    Serial.println("UP: GPIO " + String(BTN_UP_PIN));
    Serial.println("DOWN: GPIO " + String(BTN_DOWN_PIN));
    Serial.println("LEFT: GPIO " + String(BTN_LEFT_PIN));
    Serial.println("RIGHT: GPIO " + String(BTN_RIGHT_PIN));
  }

  // LCD butonlarından hangisine basıldığını döndüren fonksiyon
  ButtonType readLCDButtons() {
    // Use digital pins for buttons if enabled
    if (USE_DIGITAL_BUTTONS) {
      if (digitalRead(BTN_SELECT_PIN) == LOW) {
        Serial.println("Digital SELECT button pressed");
        return BUTTON_SELECT;
      }
      if (digitalRead(BTN_UP_PIN) == LOW) return BUTTON_UP;
      if (digitalRead(BTN_DOWN_PIN) == LOW) return BUTTON_DOWN;
      if (digitalRead(BTN_LEFT_PIN) == LOW) return BUTTON_LEFT;
      if (digitalRead(BTN_RIGHT_PIN) == LOW) return BUTTON_RIGHT;
      return BUTTON_NONE;
    }
    
    // If digital buttons are disabled, use analog input
    int adc_key_in = analogRead(LCD_BUTTONS_PIN);
    
    // Special case for no button pressed
    if (adc_key_in >= 4000) {
      return BUTTON_NONE;
    }

    // For debugging: print the analog value when any button is pressed
    static int lastPrintedValue = -1;
    if (adc_key_in < 3800 && abs(adc_key_in - lastPrintedValue) > 100) {
      Serial.print("Button Analog Value: ");
      Serial.println(adc_key_in);
      lastPrintedValue = adc_key_in;
    }
    
    // Implement multiple readings for stability
    static ButtonType lastStableButton = BUTTON_NONE;
    static int consistentReadings = 0;
    
    // Determine current button from ADC value
    ButtonType currentReading;
    
    // Use more reliable thresholds with hysteresis to prevent false positives
    // Adjusted threshold values for ESP32's ADC based on observed values
    if (adc_key_in < 130) currentReading = BUTTON_RIGHT;    // 0-130 (RIGHT button has lower values)
    else if (adc_key_in < 500) currentReading = BUTTON_UP;  // 131-500 (UP button observed at ~289)
    else if (adc_key_in < 2000) currentReading = BUTTON_DOWN; // 501-2000
    else if (adc_key_in < 2800) currentReading = BUTTON_LEFT; // 2001-2800
    else currentReading = BUTTON_SELECT; // Anything above 2800 that's not NONE (4000+) is SELECT
    
    // Check if reading is stable
    if (currentReading == lastStableButton) {
      consistentReadings++;
      // We need at least 2 consistent readings to confirm button press
      if (consistentReadings >= 2) {
        return currentReading;
      }
    } else {
      // Reset counter for new button
      lastStableButton = currentReading;
      consistentReadings = 1;
      
      // Don't immediately return a new button to avoid bouncing
      return BUTTON_NONE;
    }
    
    return BUTTON_NONE;
  }

  void handleButtons() {
    // Add small delay before reading button to stabilize ADC
    delayMicroseconds(500);
    
    ButtonType button = readLCDButtons();
    static ButtonType lastButton = BUTTON_NONE;
    static unsigned long lastButtonChangeTime = 0;
    static unsigned long buttonPressTime = 0;
    static bool buttonProcessed = false;
    static int lastAnalogValue = -1; // Keep track of the last analog value
    
    // Handle button press with proper debouncing
    if (button != BUTTON_NONE) {
      unsigned long currentTime = millis();
      
      // Print button debug info to serial
      static unsigned long lastButtonDebugTime = 0;
      if (currentTime - lastButtonDebugTime > 500) {
        String buttonName = "";
        switch (button) {
          case BUTTON_RIGHT: buttonName = "RIGHT"; break;
          case BUTTON_UP: buttonName = "UP"; break;
          case BUTTON_DOWN: buttonName = "DOWN"; break;
          case BUTTON_LEFT: buttonName = "LEFT"; break;
          case BUTTON_SELECT: buttonName = "SELECT"; break;
          default: buttonName = "UNKNOWN"; break;
        }
        
        Serial.print("Button pressed: ");
        Serial.print(buttonName);
        Serial.print(" (ADC Value: ");
        Serial.print(analogRead(LCD_BUTTONS_PIN));
        Serial.println(")");
        lastButtonDebugTime = currentTime;
      }
      
      // If button changed, enforce a minimum debounce period
      if (button != lastButton) {
        if (currentTime - lastButtonChangeTime < 200) {
          // Ignore rapid button changes (debounce)
          return;
        }
        lastButtonChangeTime = currentTime;
        lastButton = button;
        buttonPressTime = currentTime;
        buttonProcessed = false;
      }
      
      // Process button if it's been held long enough after initial debounce
      if (!buttonProcessed && (currentTime - buttonPressTime > 100)) {
        // Process the button action
        switch (button) {
          case BUTTON_SELECT:
            Serial.println("SELECT button action - Starting manual feed");
            handleManualFeed();
            buttonProcessed = true;
            break;
            
          case BUTTON_UP:
            Serial.println("UP button action - Rotating servo clockwise");
            startServo();
            feedServo.write(SERVO_FEED_POSITION);
            delay(500);
            stopServo();
            buttonProcessed = true;
            break;
            
          case BUTTON_DOWN:
            Serial.println("DOWN button action - Rotating servo counter-clockwise");
            startServo();
            feedServo.write(SERVO_REST_POSITION);
            delay(500);
            stopServo();
            buttonProcessed = true;
            break;
            
          case BUTTON_LEFT:
            Serial.println("LEFT button action - Previous menu");
            displayState = (displayState + 2) % 3;  // Move left (add 2 and mod 3)
            updateLCD();
            buttonProcessed = true;
            break;
            
          case BUTTON_RIGHT:
            Serial.println("RIGHT button action - Next menu");
            displayState = (displayState + 1) % 3;  // Move right (add 1 and mod 3)
            updateLCD();
            buttonProcessed = true;
            break;
        }
      }
    } else {
      // Wait a minimum time after button release before accepting new button
      if (lastButton != BUTTON_NONE && millis() - lastButtonChangeTime < 300) {
        // Still in cooldown period after button release
        return;
      }
      
      // No button is pressed
      lastButton = BUTTON_NONE;
      buttonProcessed = false;
      
      // Only print the analog value if it has changed significantly and less frequently
      // This reduces the serial output when no buttons are pressed
      static unsigned long lastAnalogDebugTime = 0;
      if (millis() - lastAnalogDebugTime > 5000) { // Only check every 5 seconds
        int currentAnalogValue = analogRead(LCD_BUTTONS_PIN);
        if (abs(currentAnalogValue - lastAnalogValue) > 100) { // Only print if value changed significantly
          Serial.print("Analog Button Value: ");
          Serial.println(currentAnalogValue);
          lastAnalogValue = currentAnalogValue;
        }
        lastAnalogDebugTime = millis();
      }
    }
  }

  // Update LCD function to use the global displayState
  void updateLCD() {
    static unsigned long lastDisplayChange = 0;
    const unsigned long DISPLAY_TIMEOUT = 10000; // Timeout to return to main screen
    
    // Auto return to main screen after timeout
    if (displayState != 0 && millis() - lastDisplayChange > DISPLAY_TIMEOUT) {
      displayState = 0;
      Serial.println("Display timeout - returning to main screen");
    }
    
    // Update the display based on current state
    lcd.clear();
    
    // Ensure LCD contrast is at maximum
    if (LCD_CONTRAST_PIN != 0) {
      analogWrite(LCD_CONTRAST_PIN, 255);
    }
    
    // Debug info only in serial, not on LCD
    static unsigned long lastPairedDebugTime = 0;
    if (millis() - lastPairedDebugTime > 5000) { // Every 5 seconds
      Serial.print("Current isPaired status in updateLCD: ");
      Serial.println(isPaired ? "TRUE" : "FALSE");
      lastPairedDebugTime = millis();
    }
    
    switch (displayState) {
      case 0: // Main screen - Food level and schedule info
        lcd.setCursor(0, 0);
        lcd.print("FOOD: ");
        lcd.print(int(foodLevel));
        lcd.print("%");
        
        if (WiFi.status() == WL_CONNECTED) {
          lcd.print(" WiFi");
        }
        
        lcd.setCursor(0, 1);
        
        // Interval feeding countdown display in main menu (priority)
        if (intervalFeedingActive) {
          // Calculate seconds remaining
          unsigned long elapsedMillis = millis() - lastIntervalFeedingTime;
          int elapsedSeconds = elapsedMillis / 1000;
          int remainingSeconds = intervalFeedingSeconds - elapsedSeconds;
          if (remainingSeconds < 0) remainingSeconds = 0;
          
          // Uygun format ile göster
          lcd.print("Feed in ");
          
          // Formata göre gösterimi düzenle
          if (remainingSeconds < 60) {
            // Sadece saniye kaldıysa
            lcd.print(remainingSeconds);
            lcd.print("s");
          } else if (remainingSeconds < 3600) {
            // Dakika ve saniye kaldıysa
            int minutes = remainingSeconds / 60;
            int seconds = remainingSeconds % 60;
            lcd.print(minutes);
            lcd.print("m");
            lcd.print(seconds);
            lcd.print("s");
          } else {
            // Saat, dakika kaldıysa
            int hours = remainingSeconds / 3600;
            int minutes = (remainingSeconds % 3600) / 60;
            lcd.print(hours);
            lcd.print("h");
            lcd.print(minutes);
            lcd.print("m");
          }
        }
        // Regular schedule countdown
        else if (currentSchedule.active) {
          // Calculate time until next feeding
          struct tm timeinfo;
          if (getLocalTime(&timeinfo)) {
            int currentHour = timeinfo.tm_hour;
            int currentMin = timeinfo.tm_min;
            int scheduledHour = currentSchedule.hour;
            int scheduledMin = currentSchedule.minute;
            
            int minsUntilFeed = (scheduledHour - currentHour) * 60 + (scheduledMin - currentMin);
            if (minsUntilFeed < 0) {
              minsUntilFeed += 24 * 60; // Add a day if time has passed
            }
            
            int hoursUntilFeed = minsUntilFeed / 60;
            int minsRemaining = minsUntilFeed % 60;
            
            lcd.print("Feed in ");
            lcd.print(hoursUntilFeed);
            lcd.print("h");
            lcd.print(minsRemaining);
            lcd.print("m");
          } else {
            lcd.print("Schedule Set");
          }
        } else {
          lcd.print("No Schedule");
        }
        break;
        
      case 1: // Second screen - Today's feeding info
        lcd.setCursor(0, 0);
        lcd.print("24h FEEDING:");
        lcd.setCursor(0, 1);
        
        // For now we'll just show the last feeding amount
        // In a full implementation, you would sum up all feedings in the last 24h
        lcd.print(lastWeight);
        lcd.print("g last feed");
        break;
        
      case 2: // Third screen - Battery level (simulated)
        lcd.setCursor(0, 0);
        lcd.print("BATTERY LEVEL:");
        lcd.setCursor(0, 1);
        
        // Simulate battery level (random between 50-100%)
        static int batteryLevel = 85; // Starting battery level
        
        // Every 10 minutes, decrease battery by 1%
        static unsigned long lastBatteryUpdate = 0;
        if (millis() - lastBatteryUpdate > 600000) {
          batteryLevel -= 1;
          if (batteryLevel < 50) batteryLevel = 85; // Reset to simulate charging
          lastBatteryUpdate = millis();
        }
        
        lcd.print(batteryLevel);
        lcd.print("% ");
        
        // Display battery bars
        int bars = map(batteryLevel, 0, 100, 0, 10);
        for (int i = 0; i < bars; i++) {
          lcd.print("|");
        }
        break;
    }
    
    lastDisplayChange = millis();  // Update the last display change time
    
    // Force refresh the display
    refreshLCD();
  }

  // Improve the formatting of countdown for interval mode displays
  String formatIntervalTime(int seconds) {
    if (seconds < 60) {
      // Sadece saniye kaldıysa
      return String(seconds) + "s";
    } else if (seconds < 3600) {
      // Dakika ve saniye kaldıysa
      int minutes = seconds / 60;
      int remainingSeconds = seconds % 60;
      return String(minutes) + "m" + String(remainingSeconds) + "s";
    } else {
      // Saat ve dakika kaldıysa
      int hours = seconds / 3600;
      int minutes = (seconds % 3600) / 60;
      return String(hours) + "h" + String(minutes) + "m";
    }
  }

  // Add this new function to refresh the LCD periodically
  void refreshLCD() {
    // If using contrast control, ensure it stays at maximum
    if (LCD_CONTRAST_PIN != 0) {
      analogWrite(LCD_CONTRAST_PIN, 255);
    }
    
    // Toggle backlight if available (some LCDs have backlight control)
    // This may help with visibility
    static bool backlightState = true;
    backlightState = !backlightState;
    
    // If your LCD has backlight control, you can uncomment and use this
    // digitalWrite(LCD_BACKLIGHT_PIN, backlightState ? HIGH : LOW);
    
    // Short delay to let the LCD refresh
    delay(50);
  }

// Servo Functions
void setupServo() {
  // Sadece pin modunu ayarla
  pinMode(SERVO_PIN, OUTPUT);
  Serial.println("Servo pin initialized");
}

void startServo() {
  // Configure PWM for servo
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  feedServo.setPeriodHertz(50); // Standard 50Hz servo frequency
  
  // Attach servo with specific pulse widths
  feedServo.attach(SERVO_PIN, 500, 2400); // Common values for most servos
  
  // Stop servo
  feedServo.write(90); // Middle position
  delay(100); // Short stabilization wait
}

void stopServo() {
  feedServo.write(90); // Middle position to stop
  delay(100); // Short wait for it to stop
  feedServo.detach(); // Disable servo
}

// Modified executeFeeding function to handle interval feeding properly
void executeFeeding(float targetAmount, bool isScheduled, String feedingType) {
  Serial.println("\n[Feeding] ========= STARTING FEED OPERATION =========");
  Serial.println("[Feeding] Target amount: " + String(targetAmount) + "g");
  Serial.println("[Feeding] Is scheduled: " + String(isScheduled));
  Serial.println("[Feeding] Feeding type: " + feedingType);

  // Special handling for interval feeding
  bool isIntervalFeeding = (feedingType == "interval");
  if (isIntervalFeeding) {
    Serial.println("[Feeding] Interval feeding mode active");
  }

  // Show feeding status on LCD
  lcd.clear();
  lcd.setCursor(0, 0);
  if (feedingType == "feed_now") {
    lcd.print("APP FEED NOW");
  } else if (isIntervalFeeding) {
    lcd.print("INTERVAL FEED");
  } else if (isScheduled) {
    lcd.print("SCHEDULED FEED");
  } else {
    lcd.print("MANUAL FEED");
  }
  lcd.setCursor(0, 1);
  lcd.print("TARGET: ");
  lcd.print(targetAmount);
  lcd.print("g");

  // Get initial weight from load cell
  scale.tare(); // Tare scale to ensure accurate measurement
  delay(500);   // Give time for the scale to stabilize
  
  float startWeight = measureWeight();
  float currentWeight = startWeight;
  float dispensedAmount = 0;
  unsigned long startTime = millis();
  bool feedingComplete = false;

  Serial.println("[Feeding] Initial weight: " + String(startWeight) + "g");

  // Start servo
  Serial.println("[Feeding] Starting servo");
  startServo();

  // Main feeding loop - dispense food until target weight is reached
  while (!feedingComplete && (millis() - startTime < MAX_FEED_TIME)) {
    // Set servo to continuous rotation mode (like when DOWN button is pressed)
    // For a modified servo operating as DC motor, a value below 90 causes continuous rotation
    Serial.println("[Feeding] Rotating servo continuously");
    feedServo.write(60);  // Value below 90 for continuous rotation (adjust if needed)
    
    // Measure new weight from load cell while servo continues to rotate
    float totalWeight = 0;
    int validReadings = 0;
    
    // Take several measurements while servo continues to rotate
    for (int i = 0; i < 5; i++) {
      float w = scale.get_units();
      if (w >= 0) { // Only count valid (non-negative) readings
        totalWeight += w;
        validReadings++;
      }
      delay(50);
    }
    
    // Calculate average of valid readings
    if (validReadings > 0) {
      currentWeight = totalWeight / validReadings;
      dispensedAmount = currentWeight - startWeight;
    }
    
    Serial.println("[Feeding] Current weight: " + String(currentWeight, 1) + "g");
    Serial.println("[Feeding] Dispensed amount: " + String(dispensedAmount, 1) + "g");

    // Update LCD with progress
    lcd.setCursor(0, 1);
    lcd.print("DISPENSED: ");
    lcd.print(dispensedAmount, 1);
    lcd.print("g   ");

    // Check if we've reached the target with a small tolerance
    if (dispensedAmount >= (targetAmount - 0.5)) {
      Serial.println("[Feeding] Target amount reached!");
      feedingComplete = true;
    }
  }

  // Stop servo by setting to 90 degrees (neutral position)
  Serial.println("[Feeding] Stopping servo");
  feedServo.write(90);  // Stop rotation
  delay(200);  // Short delay to allow servo to stop
  stopServo();

  // Calculate actual amount dispensed from load cell
  float finalWeight = measureWeight();
  float actualAmount = finalWeight - startWeight;

  Serial.println("[Feeding] Final weight: " + String(finalWeight, 1) + "g");
  Serial.println("[Feeding] Actual amount dispensed: " + String(actualAmount, 1) + "g");

  // Reset interval feeding timer if this was an interval feeding
  if (isIntervalFeeding && autoResetAfterFeeding) {
    Serial.println("[Feeding] Resetting interval timer after successful feeding");
    lastIntervalFeedingTime = millis();
  }

  // Show feeding result
  showFeedingResult(actualAmount, feedingComplete);
  delay(2000);
  
  // Update food level with more visible feedback
  lcd.clear();
  lcd.print("MEASURING");
  lcd.setCursor(0, 1);
  lcd.print("FOOD LEVEL...");
  
  float newFoodLevel = measureFoodLevel();
  Serial.println("[Feeding] New food level: " + String(newFoodLevel) + "%");
  
  // Update food level in database and local storage
  updateFoodLevel(newFoodLevel);
  
  // Show updated food level
  showFoodLevelUpdate(newFoodLevel);

  // Update feeding history with actual amount measured
  Serial.println("[Feeding] Updating feeding history");
  lcd.clear();
  lcd.print("SAVING FEEDING");
  lcd.setCursor(0, 1);
  lcd.print("HISTORY...");
  
  // Determine feeding type for history
  String historyFeedingType;
  if (feedingType == "feed_now") {
    historyFeedingType = "feed_now"; // Orijinal değeri kullan
    Serial.println("[Feeding] Type detected: FEED_NOW - Setting history type to: feed_now");
  } else if (isIntervalFeeding) {
    historyFeedingType = "scheduled"; // Interval besleme de scheduled olarak kaydedilecek
    Serial.println("[Feeding] Type detected: INTERVAL - Setting history type to: scheduled (interval mode)");
  } else if (isScheduled) {
    historyFeedingType = "scheduled";
    Serial.println("[Feeding] Type detected: SCHEDULED - Setting history type to: scheduled");
  } else {
    historyFeedingType = "manual";
    Serial.println("[Feeding] Type detected: DEFAULT/MANUAL - Setting history type to: manual");
  }
  
  Serial.println("[Feeding] Final feeding type for database: " + historyFeedingType);
  
  updateFeedingHistory(actualAmount, historyFeedingType);
  delay(1000);
  
  Serial.println("[Feeding] ========= FEED OPERATION COMPLETE =========\n");
}

void checkAndExecuteSchedule() {
  // Debug output for interval feeding state
  static unsigned long lastIntervalDebugTime = 0;
  if (millis() - lastIntervalDebugTime > 10000) { // Her 10 saniyede bir
    lastIntervalDebugTime = millis();
    Serial.println("[Schedule] Interval feeding active: " + String(intervalFeedingActive ? "YES" : "NO"));
    Serial.println("[Schedule] Regular schedule active: " + String(currentSchedule.active ? "YES" : "NO"));
    
    // Herhangi bir schedule aktif değilse, geri sayım sıfırlansın
    if (!intervalFeedingActive && !currentSchedule.active) {
      secondsRemaining = 0;
      Serial.println("[Schedule] No active schedules, countdown reset to 0");
    }
  }

  // Check for interval feeding first - eğer değişken false ise hiçbir şey yapma
  if (intervalFeedingActive) {
    unsigned long currentTime = millis();
    unsigned long elapsedMillis = currentTime - lastIntervalFeedingTime;
    int elapsedSeconds = elapsedMillis / 1000;
    
    // Debug output for interval feeding
    static unsigned long lastDebugTime = 0;
    if (currentTime - lastDebugTime > 5000) { // Print debug info every 5 seconds
      lastDebugTime = currentTime;
      Serial.println("[Interval] Time since last feeding: " + String(elapsedSeconds) + " seconds");
      Serial.println("[Interval] Interval setting: " + String(intervalFeedingSeconds) + " seconds");
      Serial.println("[Interval] Amount: " + String(intervalFeedingAmount) + "g");
      
      // Calculate and display seconds remaining
      secondsRemaining = intervalFeedingSeconds - elapsedSeconds;
      if (secondsRemaining < 0) secondsRemaining = 0;
      
      Serial.println("[Interval] Seconds remaining: " + String(secondsRemaining) + "s");
    }
    
    // Check if it's time for the next interval feeding
    if (elapsedSeconds >= intervalFeedingSeconds) {
      Serial.println("[Interval] Interval feeding time reached!");
      
      // Execute the feeding
      executeFeeding(intervalFeedingAmount, true, "interval");
      
      // Reset timer
      lastIntervalFeedingTime = millis();
    }
    
    return; // Skip regular schedule check if interval feeding is active
  } else if (lastIntervalFeedingTime != 0) {
    // Interval feeding aktif değilse ve son besleme zamanı sıfırlanmamışsa
    Serial.println("[Interval] Interval feeding inactive, resetting lastIntervalFeedingTime");
    lastIntervalFeedingTime = 0;
    secondsRemaining = 0;
  }

  // Regular schedule check - değişken false ise hiçbir şey yapma
  if (!currentSchedule.active) {
    return; // No active schedule
  }
  
  // Only check every minute to save resources
  static unsigned long lastCheckTime = 0;
  if (millis() - lastCheckTime < SCHEDULE_CHECK_INTERVAL) {
    return;
  }
  lastCheckTime = millis();
  
  // Get current time
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }
  
  // Check if it's time to feed
  if (timeinfo.tm_hour == currentSchedule.hour && timeinfo.tm_min == currentSchedule.minute) {
    Serial.println("Scheduled feeding time reached!");
    
    // Execute the feeding
    executeFeeding(currentSchedule.targetWeight, true, "scheduled");
    
    // Disable the schedule if it's a one-time schedule
    // Uncomment if you want one-time schedules
    // currentSchedule.active = false;
  }
}

// Sensor Functions
void setupLoadCell() {
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(LOADCELL_CALIBRATION_FACTOR);
  scale.set_offset(LOADCELL_OFFSET);
  
  // Tare on startup
  scale.tare();
  Serial.println("Load cell initialized with calibration factor: " + String(LOADCELL_CALIBRATION_FACTOR));
}

float measureWeight() {
  // Get average of 10 readings for more accuracy
  float weight = 0;
  for (int i = 0; i < 10; i++) {
    weight += scale.get_units();
    delay(10);
  }
  weight /= 10;
  
  // Ensure non-negative weight
  if (weight < 0) weight = 0;
  
  Serial.print("Measured weight: ");
  Serial.print(weight, 1);  // Show one decimal place
  Serial.println(" g");
  
  return weight;
}

float measureFoodLevel() {
  // Get average of 5 readings for stability
  float distance = 0;
  int validReadings = 0;
  
  // Perform multiple readings to get a stable value
  for (int i = 0; i < 5; i++) {
    // Direct HC-SR04 measurement as in the user's test code
    digitalWrite(ULTRASONIC_TRIGGER_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(ULTRASONIC_TRIGGER_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(ULTRASONIC_TRIGGER_PIN, LOW);
    
    // Measure echo duration
    long duration = pulseIn(ULTRASONIC_ECHO_PIN, HIGH, 30000); // 30ms timeout
    
    // Calculate distance
    float reading = duration * 0.034 / 2; // Speed of sound = 0.034 cm/µs
    
    // Only include valid readings within expected range
    if (reading > 0) { 
      distance += reading;
      validReadings++;
    }
    delay(50); // Short delay between readings
  }
  
  // If we got valid readings, average them
  if (validReadings > 0) {
    distance /= validReadings;
  } else {
    // If all readings failed, use maximum distance
    distance = CONTAINER_EMPTY_DISTANCE;
  }
  
  // Make sure distance doesn't exceed empty container distance
  if (distance > CONTAINER_EMPTY_DISTANCE) {
    distance = CONTAINER_EMPTY_DISTANCE;
  }
  
  // Print detailed debug info
  Serial.println("\n===== FOOD LEVEL MEASUREMENT =====");
  Serial.print("Raw distance measured: ");
  Serial.print(distance);
  Serial.println(" cm");
  Serial.print("Empty container distance: ");
  Serial.print(CONTAINER_EMPTY_DISTANCE);
  Serial.println(" cm");
  Serial.print("Full container distance: ");
  Serial.print(CONTAINER_FULL_DISTANCE);
  Serial.println(" cm");
  
  // Calculate food level percentage
  // Map the distance: CONTAINER_EMPTY_DISTANCE (21.0 cm) = 0%, CONTAINER_FULL_DISTANCE (0 cm) = 100%
  float usableRange = CONTAINER_EMPTY_DISTANCE - CONTAINER_FULL_DISTANCE;
  float levelPercentage = ((CONTAINER_EMPTY_DISTANCE - distance) / usableRange) * 100.0;
  
  // Constrain values to 0-100%
  if (levelPercentage > 100) levelPercentage = 100;
  if (levelPercentage < 0) levelPercentage = 0;
  
  Serial.print("Calculated food level: ");
  Serial.print(levelPercentage);
  Serial.println("%");
  Serial.println("==================================\n");
  
  return levelPercentage;
}

void showFeedingResult(float amount, bool success) {
  lcd.clear();
  lcd.setCursor(0, 0);
  
  if (success) {
    lcd.print("FEEDING COMPLETE!");
    lcd.setCursor(0, 1);
    lcd.print(amount, 1);
    lcd.print("g DISPENSED");
  } else {
    lcd.print("FEEDING ERROR!");
    lcd.setCursor(0, 1);
    lcd.print("TRY AGAIN");
  }
  
  delay(2000);
}

// Database Functions 
void updateFeedingHistory(float amount, String feedingType) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot update feeding history - WiFi not connected");
    lcd.clear();
    lcd.print("WIFI ERROR");
    lcd.setCursor(0, 1);
    lcd.print("HISTORY NOT SAVED");
    delay(2000);
    return;
  }

  Serial.println("[Database] Updating feeding history with type: " + feedingType);
  
  HTTPClient http;
  
  // Create JSON document for the feeding history
  StaticJsonDocument<256> doc;
  doc["device_key"] = deviceKey;
  doc["amount"] = amount;
  doc["feeding_time"] = getCurrentTime();
  doc["feeding_type"] = feedingType;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.println("[Database] Feeding history payload: " + jsonString);
  
  // Send POST request to add feeding history
  String url = String(SUPABASE_URL) + FEED_HISTORY_ENDPOINT;
  Serial.println("[Database] Sending request to URL: " + url);
  http.begin(url);
  http.addHeader("Content-Type", "application/json"); 
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_KEY));
  
  // Tam isteğin içeriğini göster
  Serial.println("[Database] ===== COMPLETE HTTP REQUEST START =====");
  Serial.println("[Database] URL: " + url);
  Serial.println("[Database] Headers:");
  Serial.println("  Content-Type: application/json");
  Serial.println("  apikey: " + String(SUPABASE_KEY).substring(0, 10) + "...");
  Serial.println("  Authorization: Bearer " + String(SUPABASE_KEY).substring(0, 10) + "...");
  Serial.println("[Database] Body: " + jsonString);
  Serial.println("[Database] ===== COMPLETE HTTP REQUEST END =====");
  
  Serial.println("[Database] Headers added, sending POST request with payload");
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("[Database] Feed history updated successfully");
    Serial.println("[Database] Response code: " + String(httpResponseCode));
    Serial.println("[Database] Full Response body: " + response);
    
    // Başarılı mı, yoksa yanıtta error var mı kontrol et
    if (response.indexOf("error") >= 0) {
      Serial.println("[Database] WARNING: Response contains error message!");
    }
    
    // Update local variable for last feeding
    lastWeight = amount;
    
    // Show success on LCD
    lcd.clear();
    lcd.print("HISTORY SAVED");
    lcd.setCursor(0, 1);
    lcd.print(amount);
    lcd.print("g ");
    if (feedingType == "feed_now") {
      lcd.print("APP");
    } else if (feedingType == "scheduled") {
      lcd.print("SCHED");
    } else {
      lcd.print("MANUAL");
    }
    delay(1500);
  } else {
    Serial.println("Error updating feed history");
    Serial.println("Error: " + http.errorToString(httpResponseCode));
    
    // Show error on LCD
    lcd.clear();
    lcd.print("DATABASE ERROR");
    lcd.setCursor(0, 1);
    lcd.print("CODE: ");
    lcd.print(httpResponseCode);
    delay(1500);
  }
  
  http.end();
}

void updateFoodLevel(float newFoodLevel) {
  // Update local food level
  foodLevel = newFoodLevel;
  
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot update food level in database - WiFi not connected");
    return;
  }
  
  HTTPClient http;
  
  // Create JSON document for the food level update
  StaticJsonDocument<256> doc;
  doc["device_key"] = deviceKey;
  doc["food_level"] = newFoodLevel;
  doc["updated_at"] = getCurrentTime();
  
  String jsonString;
  serializeJson(doc, jsonString);

  // Send PATCH request to update device
  http.begin(String(SUPABASE_URL) + DEVICES_ENDPOINT + "?device_key=eq." + deviceKey);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_KEY));
  http.addHeader("Prefer", "return=minimal");
  
  int httpResponseCode = http.PATCH(jsonString);
  
  if (httpResponseCode > 0) {
    Serial.println("Food level updated successfully in database");
  } else {
    Serial.println("Error updating food level in database");
    Serial.println("Error: " + http.errorToString(httpResponseCode));
  }
  
  http.end();
}

void sendFeedingCompletionStatus(float actualAmount, bool success) {
  // This function just logs feeding status, but could send to cloud
  Serial.println("[Feeding] Completed with status: " + String(success ? "SUCCESS" : "FAILURE"));
  Serial.println("[Feeding] Amount dispensed: " + String(actualAmount) + "g");
}

// Time Functions
String getCurrentTime() {
  struct tm timeinfo;
  char timeStr[32];
  
  if(!getLocalTime(&timeinfo)) {
    Serial.println("Failed to get time!");
    return "Unknown";
  }
  
  strftime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", &timeinfo);
  return String(timeStr);
}

void handleManualFeed() {
  Serial.println("Manual feed function started");
  float feedAmount = DEFAULT_FEED_AMOUNT;
  bool inManualFeedMenu = true;  // Stay in this menu until exit
  bool startFeeding = false;     // Flag to start feeding process
  
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("FEED AMOUNT:");
  lcd.setCursor(0, 1);
  lcd.print(feedAmount);
  lcd.print("g  <> EXIT");
  
  // Important: Wait for button release before continuing
  delay(500);
  while (readLCDButtons() != BUTTON_NONE) {
    delay(50);
  }
  
  // Keep in manual feed menu until exit
  unsigned long startTime = millis();
  
  Serial.println("Manual Feed Menu: UP/DOWN adjust amount, LEFT/RIGHT exit, SELECT confirm");
  
  while (inManualFeedMenu && (millis() - startTime < 20000)) { // 20 second timeout
    ButtonType button = readLCDButtons();
    
    // Avoid repeated button actions - use local variables not static
    ButtonType lastButton = BUTTON_NONE;
    static unsigned long lastButtonTime = 0;
    
    if (button != BUTTON_NONE && 
        (button != lastButton || millis() - lastButtonTime > 500)) {
      
      lastButton = button;
      lastButtonTime = millis();
      
      // Debug button press
      Serial.print("Manual Feed Menu Button: ");
      switch (button) {
        case BUTTON_UP: Serial.println("UP"); break;
        case BUTTON_DOWN: Serial.println("DOWN"); break;
        case BUTTON_SELECT: Serial.println("SELECT"); break;
        case BUTTON_LEFT: Serial.println("LEFT"); break;
        case BUTTON_RIGHT: Serial.println("RIGHT"); break;
        default: Serial.println("UNKNOWN"); break;
      }
      
      // Handle button based on function
      switch (button) {
        case BUTTON_UP:
          // Increase amount by 10, max 100
          feedAmount = min(feedAmount + FEED_AMOUNT_STEP, MAX_FEED_AMOUNT);
          Serial.println("Increased feed amount to: " + String(feedAmount) + "g");
          updateFeedAmountDisplay(feedAmount);
          startTime = millis(); // Reset timeout
          break;
          
        case BUTTON_DOWN:
          // Decrease amount by 10, min 10
          feedAmount = max(feedAmount - FEED_AMOUNT_STEP, MIN_FEED_AMOUNT);
          Serial.println("Decreased feed amount to: " + String(feedAmount) + "g");
          updateFeedAmountDisplay(feedAmount);
          startTime = millis(); // Reset timeout
          break;
          
        case BUTTON_LEFT:
        case BUTTON_RIGHT:
          // Exit to main menu
          Serial.println("Exiting manual feed menu");
          inManualFeedMenu = false;
          break;
          
        case BUTTON_SELECT:
          // Confirm and start feeding
          Serial.println("Feed amount confirmed: " + String(feedAmount) + "g");
          startFeeding = true;
          inManualFeedMenu = false;
          break;
      }
      
      // Small delay to prevent CPU hogging
      delay(300); // Longer delay to avoid false triggers
    } else if (button == BUTTON_NONE) {
      // Nothing to do when no button is pressed
    }
    
    // Small delay between checks
    delay(50);
  }
  
  // Check if we need to start feeding
  if (startFeeding) {
    // Confirm and start feeding
    lcd.clear();
    lcd.print("FEEDING...");
    lcd.setCursor(0, 1);
    lcd.print(feedAmount);
    lcd.print("g");
    
    executeFeeding(feedAmount, false, "manual");
  } else {
    // If we exited without feeding
    Serial.println("Manual feed canceled");
    lcd.clear();
    lcd.print("FEED CANCELED");
    delay(1000);
    updateLCD(); // Return to main display
  }
}

void updateFeedAmountDisplay(float amount) {
  lcd.setCursor(0, 1);
  lcd.print("                "); // Clear line
  lcd.setCursor(0, 1);
  lcd.print(amount);
  lcd.print("g  <> EXIT");
}

// Device ID Functions
String getDeviceId() {
  uint64_t chipId = ESP.getEfuseMac(); // ESP32 için benzersiz ID
  char deviceId[13];
  snprintf(deviceId, sizeof(deviceId), "%04X%08X", (uint16_t)(chipId >> 32), (uint32_t)chipId);
  return String(deviceId);
}

void resetConfiguration() {
  Serial.println("\n*** FACTORY RESET STARTED ***");
  
  // First disconnect from any WiFi
  WiFi.disconnect(true);  // true = disconnect and clear credentials
  WiFi.mode(WIFI_OFF);
  delay(500);
  
  // Clear all EEPROM data
  Serial.println("Erasing all EEPROM data (512 bytes)...");
  for (int i = 0; i < 512; i++) {
    EEPROM.write(i, 0xFF);  // Use 0xFF instead of 0 for more reliable erasure
  }
  
  // Be extra sure to clear specific credential locations
  Serial.println("Double-checking WiFi credential memory areas...");
  for (int i = EEPROM_WIFI_SSID_ADDR; i < EEPROM_WIFI_SSID_ADDR + 64; i++) {
    EEPROM.write(i, 0xFF);
  }
  for (int i = EEPROM_WIFI_PASS_ADDR; i < EEPROM_WIFI_PASS_ADDR + 64; i++) {
    EEPROM.write(i, 0xFF);
  }
  
  // Clear setup flag to force reconfiguration
  EEPROM.write(EEPROM_SETUP_FLAG_ADDR, 0xFF);
  
  // Commit changes and verify
  bool committed = EEPROM.commit();
  Serial.println("EEPROM commit result: " + String(committed ? "SUCCESS" : "FAILED"));
  
  // Reset interval feeding status
  EEPROM.write(120, 0);
  EEPROM.commit();
  
  // Reset global variables
  deviceKey = "";
  wifiSSID = "";
  wifiPassword = "";
  isConfigured = false;
  isSetupMode = true;
  intervalFeedingActive = false;
  
  // Show reset confirmation on LCD
  lcd.clear();
  lcd.print("RESET COMPLETE");
  lcd.setCursor(0, 1);
  lcd.print("RESTARTING...");
  Serial.println("Reset complete, restarting device...");
  delay(2000);
  
  // Restart ESP32
  ESP.restart();
}

// Add the setupTimeWithRetries function that was accidentally removed
bool setupTimeWithRetries() {
  // Try to get time from NTP server with multiple retries
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  
  int retries = 0;
  const int maxRetries = 3;
  struct tm timeinfo;
  
  while (!getLocalTime(&timeinfo) && retries < maxRetries) {
    Serial.println("Failed to obtain time, retrying...");
    retries++;
    delay(1000);
  }
  
  if (retries < maxRetries) {
    Serial.println("Time obtained successfully");
    return true;
  } else {
    Serial.println("Failed to obtain time after multiple attempts");
    return false;
  }
}

// Add a new function to show food level updates on LCD
void showFoodLevelUpdate(float newLevel) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("FOOD LEVEL:");
  lcd.setCursor(0, 1);
  lcd.print(newLevel, 1);
  lcd.print("% UPDATED");
  delay(2000);
}