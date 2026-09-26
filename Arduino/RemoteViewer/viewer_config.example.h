#pragma once

// Copy this file to viewer_config.h and fill in your values.
// viewer_config.h is gitignored so your Wi-Fi password never gets committed.

// Your home Wi-Fi. If it can't connect within WIFI_CONNECT_TIMEOUT_MS,
// the board starts its own access point instead (see AP_* below).
#define WIFI_SSID        "your-wifi-name"
#define WIFI_PASSWORD    "your-wifi-password"
#define WIFI_CONNECT_TIMEOUT_MS 20000

// Fallback access point, used when home Wi-Fi isn't reachable.
// Connect your phone to this network, then open http://192.168.4.1
#define AP_SSID          "RemoteViewer"
#define AP_PASSWORD      "viewer1234"   // must be 8+ characters

// Hostname: open http://remoteviewer.local on the same network.
#define MDNS_HOSTNAME    "remoteviewer"

// Login for the web page (user "viewer"). Leave empty ("") to disable
// the login. Set one if you forward the port to the internet.
#define VIEWER_USER      "viewer"
#define VIEWER_PASSWORD  "change-me"
