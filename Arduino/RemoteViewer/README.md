# RemoteViewer

A live camera viewer on an **AI-Thinker ESP32-CAM**. Open the board's address in
any browser (phone or computer) to watch live video, take snapshots, and adjust
the camera. This project is separate from DentDOG.

## What it does

- Live MJPEG video in the browser, with Pause, Snapshot and Fullscreen buttons
- Controls for resolution, JPEG quality, brightness, contrast, flip, mirror, and the
  on-board flash LED
- Joins your Wi-Fi. If it can't, it starts its own hotspot (`RemoteViewer`), so it
  works anywhere
- `http://remoteviewer.local` on your network, so you don't need to find the IP
- Password login on the page (on by default)

## Hardware

| Part | Notes |
|---|---|
| AI-Thinker ESP32-CAM (OV2640) | ~$10; usually sold with the camera attached |
| USB programmer | An "ESP32-CAM-MB" base board is easiest (plug in and go). A 3.3 V FTDI/USB-serial adapter also works |
| 5 V supply, at least 1 A | A weak supply causes "Brownout detector was triggered" resets |

If you use an FTDI adapter instead of the MB board:

```
FTDI        ESP32-CAM
5V    --->  5V
GND   --->  GND
TX    --->  U0R (GPIO3)
RX    --->  U0T (GPIO1)
             GPIO0 --> GND   (only while uploading, remove afterwards)
```

## Setup

1. **Install the board package.** In Arduino IDE: *File > Preferences > Additional
   boards manager URLs*, add
   `https://espressif.github.io/arduino-esp32/package_esp32_index.json`.
   Then in *Tools > Board > Boards Manager*, install **esp32 by Espressif**.
2. **Open** `RemoteViewer/RemoteViewer.ino`.
3. **Configure.** Copy `viewer_config.example.h` to `viewer_config.h` (same folder)
   and set your Wi-Fi name/password and a viewer password. `viewer_config.h` is
   gitignored.
4. **Select the board.** *Tools > Board > esp32 > AI Thinker ESP32-CAM*, then pick
   the port.
5. **Upload.** With an FTDI adapter, hold GPIO0 to GND and press RESET before the
   upload. Remove the jumper afterwards.
6. **Open the Serial Monitor** at 115200 baud and press RESET. It prints the address,
   for example:
   ```
   Connected. Open http://192.168.1.42  or  http://remoteviewer.local
   ```
7. Open that address and log in as `viewer` with the password you set.

## Endpoints

| URL | What it returns |
|---|---|
| `/` | Viewer page |
| `:81/stream` | MJPEG stream, e.g. for VLC, Home Assistant or OBS (log in, or use the page's token) |
| `/capture` | One JPEG snapshot |
| `/status` | Current settings as JSON |
| `/control?var=<name>&val=<n>` | Change a setting: `framesize`, `quality`, `brightness`, `contrast`, `vflip`, `hmirror`, `flash` |

The video uses its own port (81) because a stream never finishes. On the same
port it would block the page and the controls.

## Viewing from outside your home

The board works on your local network out of the box. To watch from elsewhere,
pick one:

- **VPN (recommended):** install Tailscale or WireGuard on your router, or on an
  always-on computer at home, and connect your phone to it. Nothing is exposed to
  the internet.
- **Port forwarding:** on your router, forward external ports 80 and 81 to the
  board's IP, using the same port numbers because the page loads the stream from
  `:81`. Give the board a DHCP reservation so its IP doesn't change. Set a strong
  `VIEWER_PASSWORD` first: this uses plain HTTP, so the password is not
  encrypted in transit.

## Troubleshooting

- **`Camera init failed: 0x105` / `0x20001`:** reseat the camera ribbon cable (the
  black latch must be closed), and check that the board is set to *AI Thinker
  ESP32-CAM*.
- **Brownout resets:** use a better 5 V supply or a shorter USB cable.
- **Choppy video:** lower the resolution or raise the Quality number. Keep the
  board close to the router.
- **A second viewer just shows "Connecting…":** the stream serves one viewer at a
  time. Close the other tab or device and it will connect.
