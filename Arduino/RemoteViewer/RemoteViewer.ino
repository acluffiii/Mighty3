// RemoteViewer: live camera viewer for the AI-Thinker ESP32-CAM.
//
//   http://<board-ip>/          viewer page (live video + controls)
//   http://<board-ip>:81/stream MJPEG stream (the page embeds this)
//   http://<board-ip>/capture   single JPEG snapshot
//   http://<board-ip>/status    current settings as JSON
//   http://<board-ip>/control?var=<name>&val=<n>   change a setting
//
// Board: "AI Thinker ESP32-CAM" (ESP32 core by Espressif, 2.x or 3.x).
// Setup and wiring are in README.md.

#include <WiFi.h>
#include <ESPmDNS.h>
#include "esp_camera.h"
#include "esp_http_server.h"
#include "mbedtls/base64.h"

#include "camera_pins.h"
#if __has_include("viewer_config.h")
#include "viewer_config.h"
#else
#warning "viewer_config.h not found, using viewer_config.example.h. Copy it to viewer_config.h and set your Wi-Fi."
#include "viewer_config.example.h"
#endif

static httpd_handle_t webServer = nullptr;
static httpd_handle_t streamServer = nullptr;

static String expectedAuthHeader;   // "Basic <base64(user:pass)>", empty when login is off
static String streamToken;          // random per boot; lets the page's <img> open the stream
static int flashLevel = 0;

#define PART_BOUNDARY "rvframeboundary"
static const char *STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char *STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char *STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static const char INDEX_HTML[] PROGMEM = R"rawliteral(<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Remote Viewer</title>
<style>
:root{--bg:#111418;--panel:#1c2128;--text:#e6e8eb;--muted:#8b949e;--accent:#3b82f6}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:15px system-ui,-apple-system,sans-serif}
header{display:flex;align-items:center;justify-content:space-between;padding:12px 16px}
h1{font-size:17px;margin:0}
#dot{display:inline-block;width:9px;height:9px;border-radius:50%;background:#e5534b;margin-right:6px}
#dot.live{background:#3fb950}
#view{position:relative;background:#000;max-width:960px;margin:0 auto}
#stream{display:block;width:100%;height:auto;min-height:180px}
#msg{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:var(--muted)}
.bar{display:flex;gap:8px;flex-wrap:wrap;padding:12px 16px;max-width:960px;margin:0 auto}
button{flex:1;min-width:110px;padding:10px;border:0;border-radius:8px;background:var(--panel);color:var(--text);font:inherit;cursor:pointer}
button.primary{background:var(--accent);color:#fff}
.controls{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;padding:0 16px 24px;max-width:960px;margin:0 auto}
label{display:flex;flex-direction:column;gap:6px;background:var(--panel);padding:10px 12px;border-radius:8px;color:var(--muted);font-size:13px}
label.check{flex-direction:row;align-items:center;justify-content:space-between}
select,input[type=range]{width:100%}
select{padding:6px;border-radius:6px;background:var(--bg);color:var(--text);border:1px solid #30363d}
</style></head><body>
<header><h1><span id="dot"></span>Remote Viewer</h1><span id="info" style="color:var(--muted);font-size:13px"></span></header>
<div id="view"><img id="stream" alt=""><div id="msg">Connecting&hellip;</div></div>
<div class="bar">
  <button class="primary" id="toggle">Pause</button>
  <button id="snap">Snapshot</button>
  <button id="full">Fullscreen</button>
</div>
<div class="controls">
  <label>Resolution
    <select data-var="framesize">
      <option value="13">UXGA 1600x1200</option><option value="12">SXGA 1280x1024</option>
      <option value="11">HD 1280x720</option><option value="10">XGA 1024x768</option>
      <option value="9">SVGA 800x600</option><option value="8">VGA 640x480</option>
      <option value="6">CIF 400x296</option><option value="5">QVGA 320x240</option>
    </select></label>
  <label>Quality (lower = sharper, slower)<input type="range" data-var="quality" min="10" max="63"></label>
  <label>Brightness<input type="range" data-var="brightness" min="-2" max="2"></label>
  <label>Contrast<input type="range" data-var="contrast" min="-2" max="2"></label>
  <label>Flash LED<input type="range" data-var="flash" min="0" max="255"></label>
  <label class="check">Flip vertical<input type="checkbox" data-var="vflip"></label>
  <label class="check">Mirror<input type="checkbox" data-var="hmirror"></label>
</div>
<script>
const img=document.getElementById('stream'),msg=document.getElementById('msg'),dot=document.getElementById('dot');
const streamUrl=`${location.protocol}//${location.hostname}:81/stream?token=%TOKEN%`;
let playing=false;
function start(){img.src=streamUrl+'&t='+Date.now();playing=true;document.getElementById('toggle').textContent='Pause'}
function stop(){img.src='';window.stop&&window.stop();playing=false;dot.className='';msg.textContent='Paused';msg.style.display='flex';document.getElementById('toggle').textContent='Play'}
img.onload=()=>{dot.className='live';msg.style.display='none'};
img.onerror=()=>{if(!playing)return;dot.className='';msg.textContent='Stream lost, retrying…';msg.style.display='flex';setTimeout(()=>playing&&start(),2000)};
document.getElementById('toggle').onclick=()=>playing?stop():start();
document.getElementById('snap').onclick=()=>{const a=document.createElement('a');a.href='/capture?t='+Date.now();a.download='snapshot-'+new Date().toISOString().replace(/[:.]/g,'-')+'.jpg';a.click()};
document.getElementById('full').onclick=()=>{const v=document.getElementById('view');(v.requestFullscreen||v.webkitRequestFullscreen).call(v)};
document.querySelectorAll('[data-var]').forEach(el=>{
  el.addEventListener('change',()=>{
    const val=el.type==='checkbox'?(el.checked?1:0):el.value;
    fetch(`/control?var=${el.dataset.var}&val=${val}`);
  });
});
fetch('/status').then(r=>r.json()).then(s=>{
  document.querySelectorAll('[data-var]').forEach(el=>{
    const v=s[el.dataset.var];if(v===undefined)return;
    if(el.type==='checkbox')el.checked=!!v;else el.value=v;
  });
  document.getElementById('info').textContent=`${s.ip} · ${s.rssi} dBm`;
});
start();
</script></body></html>)rawliteral";

// ---------- auth ----------

static void buildAuth() {
  if (strlen(VIEWER_PASSWORD) == 0) return;
  String creds = String(VIEWER_USER) + ":" + VIEWER_PASSWORD;
  unsigned char out[128];
  size_t outLen = 0;
  if (mbedtls_base64_encode(out, sizeof(out) - 1, &outLen,
                            (const unsigned char *)creds.c_str(), creds.length()) == 0) {
    out[outLen] = '\0';
    expectedAuthHeader = String("Basic ") + (const char *)out;
  }
}

static bool hasValidLogin(httpd_req_t *req) {
  if (expectedAuthHeader.isEmpty()) return true;
  char header[160];
  return httpd_req_get_hdr_value_str(req, "Authorization", header, sizeof(header)) == ESP_OK &&
         expectedAuthHeader == header;
}

static bool hasValidToken(httpd_req_t *req) {
  char query[96], token[40];
  return httpd_req_get_url_query_str(req, query, sizeof(query)) == ESP_OK &&
         httpd_query_key_value(query, "token", token, sizeof(token)) == ESP_OK &&
         streamToken == token;
}

// Sends a 401 and returns false when the request isn't logged in.
static bool requireLogin(httpd_req_t *req) {
  if (hasValidLogin(req)) return true;
  httpd_resp_set_status(req, "401 Unauthorized");
  httpd_resp_set_hdr(req, "WWW-Authenticate", "Basic realm=\"RemoteViewer\"");
  httpd_resp_send(req, "Login required", HTTPD_RESP_USE_STRLEN);
  return false;
}

// ---------- handlers ----------

static esp_err_t indexHandler(httpd_req_t *req) {
  if (!requireLogin(req)) return ESP_OK;
  String page(INDEX_HTML);
  page.replace("%TOKEN%", streamToken);
  httpd_resp_set_type(req, "text/html");
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");
  return httpd_resp_send(req, page.c_str(), page.length());
}

static esp_err_t captureHandler(httpd_req_t *req) {
  if (!requireLogin(req)) return ESP_OK;
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }
  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Content-Disposition", "inline; filename=snapshot.jpg");
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");
  esp_err_t res = httpd_resp_send(req, (const char *)fb->buf, fb->len);
  esp_camera_fb_return(fb);
  return res;
}

static esp_err_t streamHandler(httpd_req_t *req) {
  if (!hasValidToken(req) && !requireLogin(req)) return ESP_OK;

  esp_err_t res = httpd_resp_set_type(req, STREAM_CONTENT_TYPE);
  if (res != ESP_OK) return res;
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");

  char partHeader[64];
  while (res == ESP_OK) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Frame capture failed");
      res = ESP_FAIL;
      break;
    }
    size_t headerLen = snprintf(partHeader, sizeof(partHeader), STREAM_PART, fb->len);
    res = httpd_resp_send_chunk(req, STREAM_BOUNDARY, strlen(STREAM_BOUNDARY));
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, partHeader, headerLen);
    if (res == ESP_OK) res = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);
    esp_camera_fb_return(fb);
  }
  return res;  // a send error just means the viewer disconnected
}

static esp_err_t statusHandler(httpd_req_t *req) {
  if (!requireLogin(req)) return ESP_OK;
  sensor_t *s = esp_camera_sensor_get();
  IPAddress ip = WiFi.getMode() == WIFI_AP ? WiFi.softAPIP() : WiFi.localIP();
  char json[256];
  snprintf(json, sizeof(json),
           "{\"framesize\":%u,\"quality\":%u,\"brightness\":%d,\"contrast\":%d,"
           "\"vflip\":%u,\"hmirror\":%u,\"flash\":%d,\"rssi\":%d,\"ip\":\"%s\"}",
           s->status.framesize, s->status.quality, s->status.brightness, s->status.contrast,
           s->status.vflip, s->status.hmirror, flashLevel,
           WiFi.getMode() == WIFI_AP ? 0 : WiFi.RSSI(), ip.toString().c_str());
  httpd_resp_set_type(req, "application/json");
  return httpd_resp_send(req, json, HTTPD_RESP_USE_STRLEN);
}

static esp_err_t controlHandler(httpd_req_t *req) {
  if (!requireLogin(req)) return ESP_OK;
  char query[64], var[24], valStr[8];
  if (httpd_req_get_url_query_str(req, query, sizeof(query)) != ESP_OK ||
      httpd_query_key_value(query, "var", var, sizeof(var)) != ESP_OK ||
      httpd_query_key_value(query, "val", valStr, sizeof(valStr)) != ESP_OK) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "need var and val");
    return ESP_FAIL;
  }
  int val = atoi(valStr);
  sensor_t *s = esp_camera_sensor_get();
  int err = 0;

  if (!strcmp(var, "framesize")) {
    if (val < 0 || val > FRAMESIZE_UXGA) err = -1;
    else err = s->set_framesize(s, (framesize_t)val);
  } else if (!strcmp(var, "quality")) err = s->set_quality(s, constrain(val, 10, 63));
  else if (!strcmp(var, "brightness")) err = s->set_brightness(s, constrain(val, -2, 2));
  else if (!strcmp(var, "contrast")) err = s->set_contrast(s, constrain(val, -2, 2));
  else if (!strcmp(var, "vflip")) err = s->set_vflip(s, val ? 1 : 0);
  else if (!strcmp(var, "hmirror")) err = s->set_hmirror(s, val ? 1 : 0);
  else if (!strcmp(var, "flash")) {
    flashLevel = constrain(val, 0, 255);
    analogWrite(FLASH_LED_GPIO, flashLevel);
  } else err = -1;

  if (err) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "bad var or val");
    return ESP_FAIL;
  }
  return httpd_resp_send(req, "OK", HTTPD_RESP_USE_STRLEN);
}

// ---------- setup ----------

static bool startCamera() {
  camera_config_t config = {};
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode = CAMERA_GRAB_LATEST;  // always serve the newest frame, never a stale one

  if (psramFound()) {
    config.frame_size = FRAMESIZE_VGA;
    config.jpeg_quality = 12;
    config.fb_count = 2;
    config.fb_location = CAMERA_FB_IN_PSRAM;
  } else {
    config.frame_size = FRAMESIZE_QVGA;
    config.jpeg_quality = 15;
    config.fb_count = 1;
    config.fb_location = CAMERA_FB_IN_DRAM;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }
  return true;
}

static void startWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);  // modem sleep causes stutter in the stream
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.printf("Connecting to %s", WIFI_SSID);

  unsigned long started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < WIFI_CONNECT_TIMEOUT_MS) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("Connected. Open http://%s  or  http://%s.local\n",
                  WiFi.localIP().toString().c_str(), MDNS_HOSTNAME);
  } else {
    Serial.println("Wi-Fi not reachable, starting access point instead");
    WiFi.disconnect(true);
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASSWORD);
    Serial.printf("Join Wi-Fi \"%s\" (password \"%s\"), then open http://%s\n",
                  AP_SSID, AP_PASSWORD, WiFi.softAPIP().toString().c_str());
  }

  if (MDNS.begin(MDNS_HOSTNAME)) MDNS.addService("http", "tcp", 80);
}

static void route(httpd_handle_t server, const char *path, esp_err_t (*handler)(httpd_req_t *)) {
  httpd_uri_t uri = {};
  uri.uri = path;
  uri.method = HTTP_GET;
  uri.handler = handler;
  httpd_register_uri_handler(server, &uri);
}

static void startServers() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;

  if (httpd_start(&webServer, &config) == ESP_OK) {
    route(webServer, "/", indexHandler);
    route(webServer, "/capture", captureHandler);
    route(webServer, "/status", statusHandler);
    route(webServer, "/control", controlHandler);
  }

  // The stream never returns while a viewer is watching, so it gets its own
  // server; otherwise the page and controls would hang behind it.
  config.server_port = 81;
  config.ctrl_port += 1;
  if (httpd_start(&streamServer, &config) == ESP_OK) {
    route(streamServer, "/stream", streamHandler);
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\nRemoteViewer starting");

  pinMode(FLASH_LED_GPIO, OUTPUT);
  digitalWrite(FLASH_LED_GPIO, LOW);

  if (!startCamera()) {
    Serial.println("Check the camera ribbon cable and the board selection, then reset.");
    return;
  }

  buildAuth();
  streamToken = String(esp_random(), HEX) + String(esp_random(), HEX);

  startWiFi();
  startServers();
}

void loop() {
  delay(10000);  // everything runs in the HTTP server tasks; Wi-Fi reconnects on its own
}
