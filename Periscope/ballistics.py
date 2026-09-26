"""Trajectory solver for paintball and airsoft.

Rifle calculators use G1/G7 drag tables made for pointed bullets. Paintballs
and BBs are smooth spheres flying well below the speed of sound, so this
solver uses sphere drag directly. It also models backspin lift (Magnus
effect), which is what an airsoft hop-up, or a paintball "flatline" barrel,
adds to keep the ball flying flat.

The solver is pure Python with no dependencies, so it runs on a Raspberry Pi
as-is. The standard-library `math` module is the only import besides
dataclasses/json.

Units are SI throughout (metres, seconds, kilograms), except where a name
says otherwise (`_mrad`, `_fps`, `_g`, `_mm`).
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from pathlib import Path

G = 9.80665          # gravity, m/s^2
SPHERE_CD = 0.47     # drag coefficient of a smooth sphere at these speeds (Re ~ 1e4..1e5)
FPS_TO_MS = 0.3048
DT = 0.0005          # integration step, s
MAX_FLIGHT_S = 6.0


@dataclass
class Projectile:
    """One ammo + launcher setup. Load several from profiles.json."""
    name: str
    mass_g: float                 # 0.20..0.48 for airsoft BBs, ~3.0..3.3 for .68 paintballs
    diameter_mm: float            # 5.95 for airsoft, 17.3 for .68 paintball
    muzzle_velocity_fps: float    # measure with a chronograph at the field
    sight_height_mm: float        # camera centre above the barrel centre
    zero_m: float                 # distance where the crosshair and the ball meet
    hop: float = 0.0              # backspin lift at the muzzle as a fraction of the ball's
                                  # weight: 0 = no spin, 1.0 = lift equals weight
    spin_decay_s: float = 2.0     # time for the spin to drop to ~37%
    drag_coefficient: float = SPHERE_CD

    @property
    def mass(self) -> float:
        return self.mass_g / 1000.0

    @property
    def area(self) -> float:
        r = self.diameter_mm / 2000.0
        return math.pi * r * r

    @property
    def muzzle_velocity(self) -> float:
        return self.muzzle_velocity_fps * FPS_TO_MS

    @property
    def sight_height(self) -> float:
        return self.sight_height_mm / 1000.0


@dataclass
class Atmosphere:
    temperature_c: float = 15.0
    pressure_hpa: float = 1013.25   # station pressure, as a BME280 reports it
    humidity_pct: float = 50.0

    @property
    def density(self) -> float:
        """Humid-air density in kg/m^3."""
        t = self.temperature_c
        p = self.pressure_hpa * 100.0
        # Saturation vapour pressure (Tetens), then the partial pressures of water and dry air.
        p_sat = 610.78 * 10 ** (7.5 * t / (t + 237.3))
        p_vapour = p_sat * self.humidity_pct / 100.0
        p_dry = p - p_vapour
        kelvin = t + 273.15
        return p_dry / (287.058 * kelvin) + p_vapour / (461.495 * kelvin)


@dataclass
class Solution:
    range_m: float
    drop_mrad: float        # hold this much UP (negative = hold down)
    drift_mrad: float       # hold this much INTO the wind (positive = hold right)
    drop_m: float           # ball below the crosshair at the target, metres (negative = above)
    drift_m: float          # ball left of the crosshair at the target, metres
    time_of_flight_s: float
    velocity_fps: float     # remaining speed at the target
    energy_j: float         # remaining energy at the target

    @property
    def drop_moa(self) -> float:
        return self.drop_mrad * 3.4377

    @property
    def drift_moa(self) -> float:
        return self.drift_mrad * 3.4377


@dataclass
class Shot:
    """Everything that changes from shot to shot."""
    range_m: float                  # slant range from the laser rangefinder
    incline_deg: float = 0.0        # from the IMU; + = target is uphill
    crosswind_ms: float = 0.0       # + = wind blowing from left to right
    headwind_ms: float = 0.0        # + = wind blowing toward the shooter
    atmosphere: Atmosphere = field(default_factory=Atmosphere)


# ---------------------------------------------------------------------------
# Flight model
# ---------------------------------------------------------------------------

def _fly(p: Projectile, bore_elevation: float, air_density: float,
         wind: tuple[float, float, float], stop_x: float):
    """Integrate the flight until the ball passes x = stop_x (world frame).

    World frame: x downrange (horizontal), y up, z to the right.
    Yields (t, x, y, z, vx, vy, vz) samples; the caller picks what it needs.
    """
    m = p.mass
    k = 0.5 * air_density * p.drag_coefficient * p.area / m
    v0 = p.muzzle_velocity
    # Lift is proportional to spin x airspeed, so scale it from the muzzle value.
    lift_per_speed = p.hop * G / v0

    def accel(t, vx, vy, vz):
        rx, ry, rz = vx - wind[0], vy - wind[1], vz - wind[2]
        speed = math.sqrt(rx * rx + ry * ry + rz * rz)
        ax = -k * speed * rx
        ay = -k * speed * ry - G
        az = -k * speed * rz
        if lift_per_speed:
            # Backspin axis points to the shooter's right (+z); lift = spin x velocity,
            # which is perpendicular to the airflow and points up for a level shot.
            horiz = math.hypot(rx, rz)
            if horiz > 1e-9 and speed > 1e-9:
                spin = math.exp(-t / p.spin_decay_s)
                lift = lift_per_speed * speed * spin
                # Unit vector perpendicular to v_rel, in the vertical plane containing it, pointing up.
                ux = -ry * rx / (horiz * speed)
                uy = horiz / speed
                uz = -ry * rz / (horiz * speed)
                ax += lift * ux
                ay += lift * uy
                az += lift * uz
        return ax, ay, az

    t = 0.0
    x = y = z = 0.0
    vx = v0 * math.cos(bore_elevation)
    vy = v0 * math.sin(bore_elevation)
    vz = 0.0
    h = DT
    while t < MAX_FLIGHT_S:
        yield t, x, y, z, vx, vy, vz
        if x >= stop_x or vx <= 0:
            return
        # RK4 on (position, velocity).
        a1 = accel(t, vx, vy, vz)
        v2 = (vx + a1[0] * h / 2, vy + a1[1] * h / 2, vz + a1[2] * h / 2)
        a2 = accel(t + h / 2, *v2)
        v3 = (vx + a2[0] * h / 2, vy + a2[1] * h / 2, vz + a2[2] * h / 2)
        a3 = accel(t + h / 2, *v3)
        v4 = (vx + a3[0] * h, vy + a3[1] * h, vz + a3[2] * h)
        a4 = accel(t + h, *v4)
        x += h / 6 * (vx + 2 * v2[0] + 2 * v3[0] + v4[0])
        y += h / 6 * (vy + 2 * v2[1] + 2 * v3[1] + v4[1])
        z += h / 6 * (vz + 2 * v2[2] + 2 * v3[2] + v4[2])
        vx += h / 6 * (a1[0] + 2 * a2[0] + 2 * a3[0] + a4[0])
        vy += h / 6 * (a1[1] + 2 * a2[1] + 2 * a3[1] + a4[1])
        vz += h / 6 * (a1[2] + 2 * a2[2] + 2 * a3[2] + a4[2])
        t += h


def _impact(p: Projectile, bore_to_los: float, shot: Shot):
    """Fly one shot and return where it crosses the target plane.

    The target plane is perpendicular to the line of sight at `shot.range_m`.
    Returns (drop_m, drift_m, t, speed) or None if the ball never gets there.
    Drop is measured perpendicular to the line of sight; positive = below it.
    """
    phi = math.radians(shot.incline_deg)
    cos_p, sin_p = math.cos(phi), math.sin(phi)
    # Sight sits sight_height above the bore, perpendicular to the line of sight.
    sx, sy = -p.sight_height * sin_p, p.sight_height * cos_p
    wind = (-shot.headwind_ms, 0.0, shot.crosswind_ms)
    # Distance along the line of sight from the sight; the target plane is where this = range.
    stop_x = sx + (shot.range_m + 1.0) * cos_p + 1.0

    prev = None
    for sample in _fly(p, phi + bore_to_los, shot.atmosphere.density, wind, stop_x):
        t, x, y, z, vx, vy, vz = sample
        along = (x - sx) * cos_p + (y - sy) * sin_p
        if along >= shot.range_m:
            if prev is None:
                return None
            # Interpolate between the last two samples to the target plane.
            pt, px, py, pz, pvx, pvy, pvz, palong = prev
            f = (shot.range_m - palong) / (along - palong)
            ix, iy, iz = px + f * (x - px), py + f * (y - py), pz + f * (z - pz)
            it = pt + f * (t - pt)
            ispeed = math.sqrt((pvx + f * (vx - pvx)) ** 2 + (pvy + f * (vy - pvy)) ** 2
                               + (pvz + f * (vz - pvz)) ** 2)
            above = -(ix - sx) * sin_p + (iy - sy) * cos_p
            return -above, -iz, it, ispeed
        prev = (t, x, y, z, vx, vy, vz, along)
    return None


def zero_angle(p: Projectile, atmosphere: Atmosphere | None = None) -> float:
    """Bore angle above the line of sight (radians) that puts the ball on the
    crosshair at `p.zero_m` on a level, windless shot.

    Uses the lowest angle that works, which is how a sight is actually zeroed.
    """
    shot = Shot(range_m=p.zero_m, atmosphere=atmosphere or Atmosphere())

    def miss(angle):
        hit = _impact(p, angle, shot)
        return None if hit is None else hit[0]   # drop below crosshair

    lo, hi = math.radians(-5), math.radians(15)
    d_lo = miss(lo)
    if d_lo is None or d_lo <= 0:
        raise ValueError(f"{p.name}: can't zero at {p.zero_m} m (hop too high or zero too close)")
    # Walk up until the ball lands above the crosshair, then bisect.
    step = math.radians(0.25)
    a = lo
    while True:
        b = a + step
        d_b = miss(b)
        if d_b is not None and d_b <= 0:
            break
        a = b
        if a > hi:
            raise ValueError(f"{p.name}: can't reach {p.zero_m} m; check velocity and zero")
    for _ in range(40):
        mid = (a + b) / 2
        d = miss(mid)
        if d is not None and d > 0:
            a = mid
        else:
            b = mid
    return (a + b) / 2


def solve(p: Projectile, shot: Shot, zero: float | None = None) -> Solution | None:
    """Holds for one shot. Pass `zero` (from zero_angle) to skip re-zeroing
    each call. Returns None when the ball can't reach the range."""
    if zero is None:
        zero = zero_angle(p)
    hit = _impact(p, zero, shot)
    if hit is None:
        return None
    drop, drift, t, speed = hit
    r = shot.range_m
    return Solution(
        range_m=r,
        drop_mrad=math.atan2(drop, r) * 1000.0,
        drift_mrad=math.atan2(drift, r) * 1000.0,
        drop_m=drop,
        drift_m=drift,
        time_of_flight_s=t,
        velocity_fps=speed / FPS_TO_MS,
        energy_j=0.5 * p.mass * speed * speed,
    )


def calibrate_hop(p: Projectile, range_m: float, observed_drop_m: float,
                  atmosphere: Atmosphere | None = None) -> float:
    """Find the hop value that matches a real test shot.

    Zero the sight first, then shoot at `range_m` on a calm day and measure how
    far below the crosshair the group lands (negative if above). Returns the hop
    value to save in the profile. The sight's zero angle stays fixed while hop
    changes, the same as turning the hop dial without touching the sight.
    """
    atmosphere = atmosphere or Atmosphere()
    zero = zero_angle(p, atmosphere)
    shot = Shot(range_m=range_m, atmosphere=atmosphere)

    def drop_for(hop):
        trial = Projectile(**{**p.__dict__, "hop": hop})
        hit = _impact(trial, zero, shot)
        return math.inf if hit is None else hit[0]

    lo, hi = 0.0, 3.0
    if not (drop_for(hi) <= observed_drop_m <= drop_for(lo)):
        raise ValueError("observed drop is outside what hop 0..3 can produce")
    for _ in range(40):
        mid = (lo + hi) / 2
        if drop_for(mid) > observed_drop_m:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def load_profiles(path: str | Path = Path(__file__).with_name("profiles.json")) -> dict[str, Projectile]:
    data = json.loads(Path(path).read_text())
    return {key: Projectile(**value) for key, value in data.items()}


def main(argv: list[str] | None = None) -> None:
    import argparse

    profiles = load_profiles()
    ap = argparse.ArgumentParser(description="Paintball / airsoft hold calculator")
    ap.add_argument("--profile", default=next(iter(profiles)), choices=sorted(profiles))
    ap.add_argument("--range", type=float, help="range in metres (omit for a range table)")
    ap.add_argument("--incline", type=float, default=0.0, help="degrees, + = uphill")
    ap.add_argument("--crosswind", type=float, default=0.0, help="m/s, + = left to right")
    ap.add_argument("--headwind", type=float, default=0.0, help="m/s, + = toward you")
    ap.add_argument("--temp", type=float, default=15.0, help="deg C")
    ap.add_argument("--pressure", type=float, default=1013.25, help="hPa")
    ap.add_argument("--humidity", type=float, default=50.0, help="%%")
    args = ap.parse_args(argv)

    p = profiles[args.profile]
    atmosphere = Atmosphere(args.temp, args.pressure, args.humidity)
    zero = zero_angle(p, atmosphere)
    ranges = [args.range] if args.range else [r for r in range(5, 101, 5)]

    print(f"{p.name}  (zero {p.zero_m:g} m, hop {p.hop:g})")
    print(f"{'range':>6} {'hold':>9} {'wind':>9} {'drop':>8} {'time':>6} {'speed':>6} {'energy':>7}")
    print(f"{'m':>6} {'mrad':>9} {'mrad':>9} {'cm':>8} {'s':>6} {'fps':>6} {'J':>7}")
    for r in ranges:
        shot = Shot(r, args.incline, args.crosswind, args.headwind, atmosphere)
        s = solve(p, shot, zero)
        if s is None:
            print(f"{r:6.0f}  out of range")
            break
        print(f"{r:6.0f} {s.drop_mrad:+9.1f} {s.drift_mrad:+9.1f} {s.drop_m * 100:+8.1f} "
              f"{s.time_of_flight_s:6.2f} {s.velocity_fps:6.0f} {s.energy_j:7.2f}")


if __name__ == "__main__":
    main()
