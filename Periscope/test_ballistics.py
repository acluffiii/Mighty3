import math
import unittest

from ballistics import (Atmosphere, Projectile, Shot, _impact, calibrate_hop,
                        load_profiles, solve, zero_angle)

PROFILES = load_profiles()


class VacuumTest(unittest.TestCase):
    def test_matches_closed_form_without_drag(self):
        p = Projectile("vacuum", mass_g=3, diameter_mm=17.3, muzzle_velocity_fps=285,
                       sight_height_mm=0, zero_m=20, drag_coefficient=0.0)
        v = p.muzzle_velocity
        zero = zero_angle(p)
        # Exact: the lower angle that lands at (20, 0).
        self.assertAlmostEqual(zero, 0.5 * math.asin(9.80665 * 20 / v ** 2), places=6)
        for r in (10, 30, 50):
            y = r * math.tan(zero) - 9.80665 * r * r / (2 * v * v * math.cos(zero) ** 2)
            s = solve(p, Shot(r), zero)
            self.assertAlmostEqual(s.drop_m, -y, places=3)


class SolverTest(unittest.TestCase):
    def test_zero_range_needs_no_hold(self):
        for p in PROFILES.values():
            s = solve(p, Shot(p.zero_m))
            self.assertAlmostEqual(s.drop_m, 0.0, places=4, msg=p.name)

    def test_drop_grows_past_zero(self):
        for p in PROFILES.values():
            zero = zero_angle(p)
            holds = [solve(p, Shot(p.zero_m + d), zero).drop_mrad for d in (5, 10, 15)]
            self.assertEqual(holds, sorted(holds), msg=p.name)
            self.assertGreater(holds[0], 0, msg=p.name)

    def test_crosswind_pushes_ball_downwind(self):
        p = PROFILES["paintball_68"]
        s = solve(p, Shot(30, crosswind_ms=3))       # wind from the left
        self.assertLess(s.drift_m, -0.05)            # ball lands right of the crosshair
        self.assertLess(s.drift_mrad, 0)             # so hold left
        mirrored = solve(p, Shot(30, crosswind_ms=-3))
        self.assertAlmostEqual(mirrored.drift_m, -s.drift_m, places=6)

    def test_headwind_adds_drop(self):
        p = PROFILES["airsoft_028"]
        calm = solve(p, Shot(40))
        headwind = solve(p, Shot(40, headwind_ms=4))
        self.assertGreater(headwind.drop_m, calm.drop_m)

    def test_uphill_and_downhill_drop_less_than_level(self):
        p = PROFILES["paintball_68"]
        zero = zero_angle(p)
        level = solve(p, Shot(40), zero).drop_m
        up = solve(p, Shot(40, incline_deg=25), zero).drop_m
        down = solve(p, Shot(40, incline_deg=-25), zero).drop_m
        self.assertLess(up, level)
        self.assertLess(down, level)

    def test_hop_flattens_trajectory(self):
        base = PROFILES["airsoft_028"]
        no_hop = Projectile(**{**base.__dict__, "hop": 0.0})
        self.assertLess(solve(base, Shot(50)).drop_m, solve(no_hop, Shot(50)).drop_m)

    def test_out_of_range_returns_none(self):
        self.assertIsNone(solve(PROFILES["paintball_68"], Shot(400)))

    def test_calibrate_hop_recovers_true_value(self):
        p = PROFILES["airsoft_028"]
        zero = zero_angle(p)
        truth = Projectile(**{**p.__dict__, "hop": 0.7})
        observed = _impact(truth, zero, Shot(45))[0]
        self.assertAlmostEqual(calibrate_hop(p, 45, observed), 0.7, places=3)


class AtmosphereTest(unittest.TestCase):
    def test_standard_dry_air(self):
        self.assertAlmostEqual(Atmosphere(15, 1013.25, 0).density, 1.225, places=3)

    def test_thinner_air_means_less_drop(self):
        p = PROFILES["paintball_68"]
        sea = Atmosphere(15, 1013.25, 50)
        mountain = Atmosphere(15, 800, 50)
        self.assertLess(solve(p, Shot(40, atmosphere=mountain), zero_angle(p, mountain)).drop_m,
                        solve(p, Shot(40, atmosphere=sea), zero_angle(p, sea)).drop_m)


if __name__ == "__main__":
    unittest.main()
