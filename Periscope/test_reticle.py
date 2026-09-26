import math
import unittest

from ballistics import Shot, load_profiles, solve
from reticle import CameraView, crosshair, impact_dot

VIEW = CameraView("test", 1920, 1080, 66.0)
P = load_profiles()["paintball_68"]


def solution(drop_mrad=0.0, drift_mrad=0.0):
    s = solve(P, Shot(P.zero_m))
    s.drop_mrad, s.drift_mrad = drop_mrad, drift_mrad
    return s


class ReticleTest(unittest.TestCase):
    def test_no_hold_sits_on_crosshair(self):
        dot = impact_dot(solution(), VIEW)
        self.assertEqual((round(dot.x, 6), round(dot.y, 6)), crosshair(VIEW))

    def test_drop_moves_dot_down(self):
        dot = impact_dot(solution(drop_mrad=10), VIEW)
        self.assertAlmostEqual(dot.x, 960)
        self.assertAlmostEqual(dot.y - 540, VIEW.focal_px * math.tan(0.010))

    def test_wind_from_left_moves_dot_right(self):
        s = solve(P, Shot(30, crosswind_ms=3))
        dot = impact_dot(s, VIEW)
        self.assertGreater(dot.x, 960)   # ball lands right
        self.assertGreater(dot.y, 540)   # and low (past zero)

    def test_cant_rotates_offset(self):
        # Rolled 90 deg clockwise: gravity's down now points to screen right.
        dot = impact_dot(solution(drop_mrad=10), VIEW, cant_deg=90)
        self.assertAlmostEqual(dot.y, 540, places=6)
        self.assertGreater(dot.x, 960)
        # Small cant keeps the offset's length.
        a = impact_dot(solution(drop_mrad=10, drift_mrad=-5), VIEW, cant_deg=7)
        b = impact_dot(solution(drop_mrad=10, drift_mrad=-5), VIEW)
        self.assertAlmostEqual(math.hypot(a.x - 960, a.y - 540), math.hypot(b.x - 960, b.y - 540), delta=0.5)

    def test_boresight_offset_moves_everything(self):
        view = CameraView("offset", 1920, 1080, 66.0, boresight_x_px=12, boresight_y_px=-8)
        dot = impact_dot(solution(drop_mrad=5), view)
        base = impact_dot(solution(drop_mrad=5), VIEW)
        self.assertAlmostEqual(dot.x - base.x, 12)
        self.assertAlmostEqual(dot.y - base.y, -8)

    def test_off_screen_is_flagged(self):
        self.assertFalse(impact_dot(solution(drop_mrad=900), VIEW).on_screen)

    def test_zoom_increases_resolution(self):
        self.assertAlmostEqual(VIEW.zoomed(2).px_per_mrad, 2 * VIEW.px_per_mrad, places=6)


if __name__ == "__main__":
    unittest.main()
