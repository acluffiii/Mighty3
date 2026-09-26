# Periscope: trajectory solver

This is the trajectory calculator for the digital periscope (high-res, night and
thermal cameras, rangefinder, eyeglass display), set up for **paintball and
airsoft**. The camera, display and button software will be added to this folder
later.

## Why not a rifle calculator

Rifle calculators use G1/G7 drag tables made for pointed bullets. Paintballs and
BBs are round balls at low speed, so they need a different model:

- **Drag:** sphere drag (Cd ≈ 0.47). Balls lose speed fast. A paintball loses
  about a third of its speed by 20 m.
- **Backspin lift (Magnus effect):** this is what an airsoft hop-up does, and a
  paintball "flatline" barrel works the same way. Lift is modelled from spin ×
  airspeed, with the spin slowly dying off.
- **Wind:** handled in 3D, including headwind and tailwind. BBs are very
  sensitive to wind: a 3 m/s crosswind moves a 0.28 g BB about 1 m at 40 m.
- **Uphill and downhill shots:** handled using the incline angle.
- **Air density:** calculated from temperature, pressure and humidity, as read
  from a BME280 sensor.

It's pure Python with no dependencies, so it runs on the Raspberry Pi as-is.
One solution takes about 20 ms.

## Use

```
python3 ballistics.py --profile airsoft_028               # range table, 5–100 m
python3 ballistics.py --profile paintball_68 --range 30 --crosswind 3
python3 -m unittest -v test_ballistics
```

The output columns are:

- **hold:** how far to aim up, in mrad
- **wind:** how far to aim into the wind, in mrad (+ = aim right)
- **drop:** where the ball lands below the crosshair, in cm
- **time:** time of flight
- **speed and energy:** what's left at the target

At close range the hold is negative (aim low) because the camera sits above the
barrel. `sight_height_mm` accounts for this.

## Impact dot on the display

`reticle.py` turns a solution into a screen position:

- The fixed **crosshair** shows where the zeroed barrel points.
- The **impact dot** shows where the ball will land. Put the dot on the target.
- Drop moves the dot down. Wind from the left moves it right.
- When the unit is tilted (cant, read from the IMU), the offset rotates so it
  still follows gravity.
- Each camera has its own field of view and its own boresight offset, which is
  set when you zero that camera.
- When the hold is larger than the view, the dot is flagged as off-screen.

This only works when the camera is **rigidly mounted to the marker and zeroed to
it**.

Screen resolution near the centre, on a 1920×1080 eyepiece:

| View | px per mrad | with 2× digital zoom |
|---|---|---|
| Camera Module 3 Wide (102°) | 0.8 | 1.6 |
| Camera Module 3 standard (66°) | 1.5 | 3.0 |
| IMX462 night (~90°) | 1.0 | 1.9 |
| Lepton 3.5 thermal (57°) | 1.3 | 2.7 |

At 30 m, 1 mrad is 3 cm, which is well under a paintball's spread. The Lepton's
own pixels are about 6 mrad each, though, so the thermal image is soft even
though the dot is placed precisely.

## Set up your own profile

Edit `profiles.json`. The numbers there are starting points, not measurements.

1. **Muzzle velocity:** use the chronograph reading from the field, with the
   paint or BB weight you actually use.
2. **`sight_height_mm`:** measure from the centre of the barrel to the centre of
   the camera lens.
3. **`zero_m`:** adjust the crosshair on the display until shots hit it at this
   distance.
4. **Airsoft `hop`:** set your hop-up dial as usual. Then shoot a group at about
   40 m on a calm day and measure how far below the crosshair it lands. Then run:
   ```python
   from ballistics import load_profiles, calibrate_hop
   p = load_profiles()["airsoft_028"]
   print(calibrate_hop(p, 40, observed_drop_m=0.35))
   ```
   Save the result as `hop`. Repeat this whenever you touch the hop-up dial or
   change BB weight.

## Limits

- The solver predicts where the **centre of the group** lands. Paintballs and BBs
  spread widely from shot to shot, often ±20–50 cm at 30–40 m. That spread
  usually matters more than any calculation error.
- Wind is entered by hand. Gusts at the target are the biggest unknown.

## Hardware notes for paintball and airsoft

- **Rangefinder:** shots are within 60–80 m, so a **Benewake TF02-Pro** (40 m)
  or a 100 m-class module is enough. Skip the long-range units.
- **Eye protection comes first.** The eyeglass display is **not** eye protection.
  It has to fit inside your rated full-seal goggles (ASTM F1776 for paintball),
  or be built into a goggle system. Never lift your goggles on the field to use
  it.
- **Check field rules.** Many fields ban lasers of any kind (including
  rangefinders), thermal or night vision, or electronics on markers, and some
  allow them only in certain game types. Ask before bringing this.
