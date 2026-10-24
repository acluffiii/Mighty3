# DentDOG App Store preview video

`DentDOG-AppPreview-886x1920.mp4` is ready for App Store Connect → App Previews and Screenshots → iPhone → App Previews.

- 17.2 s, 886×1920 portrait, 30 fps, H.264 High, silent stereo AAC 44.1 kHz
- Cut from the screen recording `SHORTAPPSTOREDENTDOG.mov`. It shows only DentDOG's own screens: splash, card deck, panel map, camera, scope grid, and the share-estimate menu. No home screen, Photos app, share sheet, contact names, or dent-detection results.
- `DentDOG-AppPreview-contact-sheet.jpg`: every half-second of the video, for a quick review.
- The source recording was 296×640, so the video is enlarged 3× and looks a little soft. A new full-resolution screen recording would give a sharp version.

## Rebuilding

`build_preview.py` makes the video from a screen recording (needs ffmpeg):

```bash
python3 build_preview.py path/to/recording.mov DentDOG-AppPreview-886x1920.mp4
```

The cut points in `segs` are times in the original recording. Change them for a new recording.
