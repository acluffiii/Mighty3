import AVFoundation

/// All sound is synthesized at launch into PCM buffers, so there are no audio files to ship.
/// - Engine hum: a looping 50 Hz sawtooth, pitched with a varispeed unit.
/// - Grass cutting: looping band-limited noise.
/// - Effects: short chiptune blips played on a small pool of player nodes.
final class SoundEngine {
    enum Sfx: Hashable {
        case coin, bonk, flower, power, win, buy, click
        case combo(Int)
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private let hum = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private let noise = AVAudioPlayerNode()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Sfx: AVAudioPCMBuffer] = [:]
    private var running = false
    private var humVolume: Float = 0
    private var noiseVolume: Float = 0

    var muted = false {
        didSet { engine.mainMixerNode.outputVolume = muted ? 0 : 0.9 }
    }

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        engine.attach(hum)
        engine.attach(varispeed)
        engine.attach(noise)
        engine.connect(hum, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        engine.connect(noise, to: engine.mainMixerNode, format: format)
        for _ in 0..<5 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        buildBuffers()
        do {
            try engine.start()
            running = true
            if let b = makeHum() { hum.scheduleBuffer(b, at: nil, options: .loops) }
            if let b = makeNoise() { noise.scheduleBuffer(b, at: nil, options: .loops) }
            hum.volume = 0
            noise.volume = 0
            hum.play()
            noise.play()
        } catch {
            running = false
        }
    }

    /// Called every frame. `speedFraction` is 0...1 of top speed.
    func setEngine(on: Bool, speedFraction: Double, cutting: Bool) {
        guard running else { return }
        if !engine.isRunning { try? engine.start() }
        let targetHum: Float = on ? 0.45 : 0
        let targetNoise: Float = (on && cutting) ? 0.22 : 0
        humVolume += (targetHum - humVolume) * 0.15
        noiseVolume += (targetNoise - noiseVolume) * 0.25
        hum.volume = humVolume
        noise.volume = noiseVolume
        let freq = 46 + min(max(speedFraction, 0), 1.3) * 38 - (cutting ? 5 : 0)
        varispeed.rate = Float(freq / 50)
    }

    func play(_ sfx: Sfx) {
        guard running, !muted, let buffer = buffers[sfx] else { return }
        if !engine.isRunning { try? engine.start() }
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !p.isPlaying { p.play() }
    }

    // MARK: - Synthesis

    private enum Wave { case square, triangle, saw }

    private struct Note {
        var freq: Double
        var dur: Double
        var wave: Wave
        var vol: Double
        var delay: Double = 0
        var slide: Double = 0
    }

    private func buildBuffers() {
        buffers[.coin] = render([Note(freq: 988, dur: 0.06, wave: .square, vol: 0.05),
                                 Note(freq: 1319, dur: 0.12, wave: .square, vol: 0.05, delay: 0.06)])
        buffers[.bonk] = render([Note(freq: 150, dur: 0.18, wave: .triangle, vol: 0.22, slide: 0.45)])
        buffers[.flower] = render([Note(freq: 420, dur: 0.22, wave: .saw, vol: 0.05, slide: 0.4)])
        buffers[.power] = render([523.0, 659, 784, 1047].enumerated().map { i, f in
            Note(freq: f, dur: 0.09, wave: .square, vol: 0.045, delay: Double(i) * 0.05)
        })
        buffers[.win] = render([523.0, 659, 784, 1047, 1319].enumerated().map { i, f in
            Note(freq: f, dur: 0.18, wave: .triangle, vol: 0.12, delay: Double(i) * 0.09)
        })
        buffers[.buy] = render([Note(freq: 660, dur: 0.06, wave: .square, vol: 0.06),
                                Note(freq: 990, dur: 0.12, wave: .square, vol: 0.06, delay: 0.05)])
        buffers[.click] = render([Note(freq: 720, dur: 0.03, wave: .square, vol: 0.03)])
        for n in 2...5 {
            let f = 392 * pow(1.19, Double(n))
            buffers[.combo(n)] = render([Note(freq: f, dur: 0.14, wave: .triangle, vol: 0.12),
                                         Note(freq: f * 1.5, dur: 0.14, wave: .triangle, vol: 0.08, delay: 0.07)])
        }
    }

    private func render(_ notes: [Note]) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let length = (notes.map { $0.delay + $0.dur }.max() ?? 0.1) + 0.03
        let frames = AVAudioFrameCount(length * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames
        for i in 0..<Int(frames) { data[i] = 0 }
        for note in notes {
            let start = Int(note.delay * sr)
            let count = Int(note.dur * sr)
            let vol = note.vol * 2.5
            var phase = 0.0
            for i in 0..<count where start + i < Int(frames) {
                let t = Double(i) / sr
                let freq = note.slide > 0 ? note.freq * pow(note.slide, t / note.dur) : note.freq
                phase += freq / sr
                let p = phase - floor(phase)
                let s: Double
                switch note.wave {
                case .square: s = p < 0.5 ? 1 : -1
                case .triangle: s = 4 * abs(p - 0.5) - 1
                case .saw: s = 2 * p - 1
                }
                let env = vol * pow(0.0001 / vol, t / note.dur)
                data[start + i] += Float(s * env)
            }
        }
        return buf
    }

    /// One second of a 50 Hz lowpassed sawtooth with an 18 Hz "chug". Whole cycles, so it loops cleanly.
    private func makeHum() -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let frames = AVAudioFrameCount(sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames
        let alpha = 1 - exp(-2 * Double.pi * 420 / sr)
        var lp = 0.0
        // Run the filter over one cycle first so the loop point has no jump.
        for pass in 0..<2 {
            for i in 0..<Int(frames) {
                let t = Double(i) / sr
                let p = (t * 50).truncatingRemainder(dividingBy: 1)
                lp += alpha * ((2 * p - 1) - lp)
                if pass == 1 {
                    let chug = 1 + 0.3 * sin(2 * Double.pi * 18 * t)
                    data[i] = Float(lp * chug * 0.5)
                }
            }
        }
        return buf
    }

    private func makeNoise() -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let frames = AVAudioFrameCount(sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames
        let aLow = 1 - exp(-2 * Double.pi * 1200 / sr)
        let aHigh = 1 - exp(-2 * Double.pi * 3600 / sr)
        var low = 0.0, high = 0.0
        for i in 0..<Int(frames) {
            let x = Double.random(in: -1...1)
            low += aLow * (x - low)
            high += aHigh * (x - high)
            data[i] = Float((high - low) * 1.4)   // crude band-pass around 1.2 to 3.6 kHz
        }
        return buf
    }
}
