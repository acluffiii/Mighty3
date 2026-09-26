"""Where to draw the impact dot on the display.

The fixed crosshair marks where the barrel is pointing (after zeroing). The
impact dot marks where the ball will actually land, so the shooter puts the
dot on the target:

- the ball drops below the crosshair, so the dot moves DOWN
- wind from the left pushes the ball right, so the dot moves RIGHT
- if the unit is tilted (canted), "down" for gravity is no longer straight
  down on the screen, so the dot's offset is rotated to match

This only works when the camera is rigidly mounted to the marker and zeroed to
it. If the camera and the marker can move independently, the display can't
know where the marker points and the dot means nothing.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from ballistics import Solution


@dataclass
class CameraView:
    """One camera as it appears on the display, after any scaling or zoom."""
    name: str
    width_px: int          # displayed image width
    height_px: int         # displayed image height
    hfov_deg: float        # horizontal field of view of the displayed image
    boresight_x_px: float = 0.0   # where the zeroed barrel points, relative to image centre
    boresight_y_px: float = 0.0   # (set during zeroing; each camera needs its own)

    @property
    def focal_px(self) -> float:
        """Pinhole focal length in pixels (assumes a rectilinear lens)."""
        return (self.width_px / 2) / math.tan(math.radians(self.hfov_deg) / 2)

    @property
    def px_per_mrad(self) -> float:
        """Pixels per milliradian near the centre of the image."""
        return self.focal_px / 1000.0

    def zoomed(self, factor: float) -> "CameraView":
        """The same camera with a digital zoom (centre crop, scaled back up)."""
        hfov = 2 * math.degrees(math.atan(math.tan(math.radians(self.hfov_deg) / 2) / factor))
        return CameraView(f"{self.name} x{factor:g}", self.width_px, self.height_px, hfov,
                          self.boresight_x_px * factor, self.boresight_y_px * factor)


@dataclass
class DotPosition:
    x: float               # pixels from the left edge
    y: float               # pixels from the top edge
    on_screen: bool


def crosshair(view: CameraView) -> tuple[float, float]:
    """Pixel position of the fixed (zeroed) crosshair."""
    return view.width_px / 2 + view.boresight_x_px, view.height_px / 2 + view.boresight_y_px


def impact_dot(solution: Solution, view: CameraView, cant_deg: float = 0.0) -> DotPosition:
    """Screen position of the predicted point of impact.

    cant_deg comes from the IMU: positive = unit rolled clockwise as the user
    sees it (right side down).
    """
    # Ball offset from the crosshair in gravity-aligned angles:
    # +right = ball lands right, +down = ball lands low.
    right = -solution.drift_mrad / 1000.0
    down = solution.drop_mrad / 1000.0

    # Rolling the unit clockwise makes the scene, and gravity's "down", appear
    # rotated counter-clockwise on screen. Screen y points down.
    c = math.radians(cant_deg)
    screen_right = right * math.cos(c) + down * math.sin(c)
    screen_down = -right * math.sin(c) + down * math.cos(c)

    cx, cy = crosshair(view)
    f = view.focal_px
    x = cx + f * math.tan(screen_right)
    y = cy + f * math.tan(screen_down)
    on_screen = 0 <= x < view.width_px and 0 <= y < view.height_px
    return DotPosition(x, y, on_screen)


# Starting values for the cameras in the parts list, shown full-screen on a
# 1920x1080 eyepiece. Measure your own FOV for the lens and sensor mode you use.
DEFAULT_VIEWS = {
    "day_wide": CameraView("Camera Module 3 Wide", 1920, 1080, 102.0),
    "day_standard": CameraView("Camera Module 3", 1920, 1080, 66.0),
    "night": CameraView("IMX462 starlight", 1920, 1080, 90.0),
    "thermal": CameraView("Lepton 3.5 (upscaled, 4:3)", 1440, 1080, 57.0),
}
