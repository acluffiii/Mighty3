import subprocess, sys
V, OUT = sys.argv[1], sys.argv[2]
X = 0.3  # crossfade length
# (start, end, extra hold seconds) taken from the source recording; last entry is the end card (still frame)
segs = [(1.75, 4.15, 0), (4.30, 9.15, 0), (11.70, 13.45, 0), (43.20, 45.40, 1.5), (47.60, 49.10, 1.5)]
end_card = (3.0, 3.0)
look = "fps=30,scale=888:1920:flags=lanczos,crop=886:1920,unsharp=5:5:0.5,setsar=1,format=yuv420p"
f, lens = [], []
for i, (a, b, h) in enumerate(segs):
    f.append(f"[0:v]trim=start={a}:end={b},setpts=PTS-STARTPTS,{look},tpad=stop_mode=clone:stop_duration={h}[s{i}]")
    lens.append(b - a + h)
t, d = end_card
n = len(segs)
f.append(f"[0:v]trim=start={t}:duration=0.05,setpts=PTS-STARTPTS,{look},tpad=stop_mode=clone:stop_duration={d},trim=duration={d}[s{n}]")
lens.append(d)
prev, acc = "s0", lens[0]
for i in range(1, n + 1):
    out = f"x{i}"
    f.append(f"[{prev}][s{i}]xfade=transition=fade:duration={X}:offset={acc - X:.3f}[{out}]")
    acc = acc - X + lens[i]; prev = out
total = acc
f.append(f"anullsrc=channel_layout=stereo:sample_rate=44100,atrim=duration={total:.3f}[a]")
cmd = ["ffmpeg", "-y", "-v", "error", "-i", V, "-filter_complex", ";".join(f), "-map", f"[{prev}]", "-map", "[a]",
       "-c:v", "libx264", "-profile:v", "high", "-level", "4.2", "-pix_fmt", "yuv420p", "-r", "30", "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
       "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2", "-movflags", "+faststart", "-t", f"{total:.3f}", OUT]
subprocess.run(cmd, check=True)
print(f"planned duration {total:.2f}s")
