# Preload game art

| File | Use |
| --- | --- |
| `home_screen.png` / `.svg` | 1080×1920 home screen background without text, so you can put your own UI on top |
| `home_screen_titled.png` / `.svg` | Same art with a "PRELOAD / RUSH HOUR" title and a "TAP TO START" button (placeholder text) |
| `app_icon.png` / `.svg` | 1024×1024 app icon: square, no transparency, ready for the App Store or Play Store |
| `app_icon_512/192/180/120.png` | Smaller icon sizes |

All art is vector. To change it (colors, title text, layout), edit `src/generate.js` and run:

```sh
cd src && NODE_PATH=$(npm root -g) node generate.js
```

This needs `playwright` installed globally. Title font: Lexend Bold (SIL Open Font License), in `src/Lexend-Bold.ttf`.

Art style: flat editorial illustration with no outlines, tonal shading, a soft blue backdrop with pale shapes, and a film-grain overlay.
