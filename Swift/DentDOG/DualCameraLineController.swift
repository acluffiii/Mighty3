//
//  DualCameraLineController.swift
//  DentDOG 2.0
//
//  Manages simultaneous capture from the wide + ultrawide back cameras using
//  AVCaptureMultiCamSession and AVCaptureDataOutputSynchronizer.
//
//  Why simultaneous: the two cameras see the PDR line board reflection from
//  slightly different angles (~15 mm baseline on most iPhones). Lines that
//  are genuinely distorted by a dent deviate *consistently* in both views
//  (correlated signal); random sensor noise deviates *differently* (uncorrelated
//  noise). DentDoGAnalyzer.analyzeStereoLineBoard() exploits this to separate
//  real dent geometry from noise, and uses the disparity between the two
//  deviation magnitudes to estimate relative dent depth without LiDAR.
//
//  Multi-cam requires iOS 13+ hardware (A12 Bionic or later). Check
//  DualCameraLineController.isSupported before instantiating this class.
//

import AVFoundation
import CoreImage
import UIKit

final class DualCameraLineController: NSObject, ObservableObject {

    // MARK: - Static capability check

    static var isSupported: Bool { AVCaptureMultiCamSession.isMultiCamSupported }

    // MARK: - Published state

    @Published private(set) var isReady = false
    @Published private(set) var statusMessage = "Not started"

    // Expose the session for preview layer rendering in the UI.
    let session = AVCaptureMultiCamSession()

    // MARK: - Private

    private var _isConfigured = false
    private let wideOutput   = AVCaptureVideoDataOutput()
    private let ultraOutput  = AVCaptureVideoDataOutput()
    private let ciContext    = CIContext(options: [.useSoftwareRenderer: false])
    private let sessionQueue = DispatchQueue(label: "dentdog.dualcam.session")
    private let dataQueue    = DispatchQueue(label: "dentdog.dualcam.data",
                                             qos: .userInteractive)
    private var synchronizer: AVCaptureDataOutputSynchronizer?

    // FOV ratio from live device, used by the stereo analyzer for accurate crop.
    private(set) var fovRatio: Float = 0.55  // ultrawide_fov / wide_fov fallback

    // Thread-safe pending-capture slot: set on main, read/cleared on dataQueue.
    private let captureLock = NSLock()
    private var _pendingCapture: ((UIImage, UIImage, Float) -> Void)?

    // MARK: - Setup

    func configure() {
        guard Self.isSupported else {
            DispatchQueue.main.async { self.statusMessage = "Multi-cam not supported on this device." }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self, !self._isConfigured else { return }
            self._isConfigured = true
            self.session.beginConfiguration()

            // --- Wide camera ---
            guard let wideDevice = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: .back),
                  let wideInput = try? AVCaptureDeviceInput(device: wideDevice),
                  self.session.canAddInput(wideInput) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.statusMessage = "Wide camera unavailable." }
                return
            }
            self.session.addInput(wideInput)

            // --- Ultrawide camera ---
            guard let ultraDevice = AVCaptureDevice.default(
                    .builtInUltraWideCamera, for: .video, position: .back),
                  let ultraInput = try? AVCaptureDeviceInput(device: ultraDevice),
                  self.session.canAddInput(ultraInput) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.statusMessage = "Ultrawide camera unavailable." }
                return
            }
            self.session.addInput(ultraInput)

            // Capture the actual FOV values before committing so the analyzer
            // can crop ultrawide to exactly the wide camera's field of view.
            let wideFOV  = wideDevice.activeFormat.videoFieldOfView
            let ultraFOV = ultraDevice.activeFormat.videoFieldOfView
            let ratio    = ultraFOV > 0 ? wideFOV / ultraFOV : 0.55
            DispatchQueue.main.async { self.fovRatio = ratio }

            // --- Video outputs ---
            let pixFmt = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.wideOutput.videoSettings  = pixFmt
            self.ultraOutput.videoSettings = pixFmt
            self.wideOutput.alwaysDiscardsLateVideoFrames  = true
            self.ultraOutput.alwaysDiscardsLateVideoFrames = true

            guard self.session.canAddOutput(self.wideOutput),
                  self.session.canAddOutput(self.ultraOutput) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addOutput(self.wideOutput)
            self.session.addOutput(self.ultraOutput)

            // Wire outputs to the correct camera inputs via explicit connections.
            let widePorts  = wideInput.ports(for: .video,
                                              sourceDeviceType: .builtInWideAngleCamera,
                                              sourceDevicePosition: .back)
            let ultraPorts = ultraInput.ports(for: .video,
                                               sourceDeviceType: .builtInUltraWideCamera,
                                               sourceDevicePosition: .back)

            if let wp = widePorts.first {
                let conn = AVCaptureConnection(inputPorts: [wp], output: self.wideOutput)
                if self.session.canAddConnection(conn) { self.session.addConnection(conn) }
            }
            if let up = ultraPorts.first {
                let conn = AVCaptureConnection(inputPorts: [up], output: self.ultraOutput)
                if self.session.canAddConnection(conn) { self.session.addConnection(conn) }
            }

            self.session.commitConfiguration()

            // Synchronizer must be created AFTER outputs are connected.
            let sync = AVCaptureDataOutputSynchronizer(dataOutputs: [self.wideOutput, self.ultraOutput])
            sync.setDelegate(self, queue: self.dataQueue)
            self.synchronizer = sync

            self.session.startRunning()
            DispatchQueue.main.async {
                self.isReady = true
                self.statusMessage = "Ready"
            }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isReady = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isReady = false }
        }
    }

    // MARK: - Capture

    /// Triggers a single synchronized capture from both cameras.
    /// The closure is called on the main thread with (wideImage, ultraImage, fovRatio).
    func capture(onCapture: @escaping (UIImage, UIImage, Float) -> Void) {
        captureLock.withLock { _pendingCapture = onCapture }
    }
}

// MARK: - AVCaptureDataOutputSynchronizerDelegate

extension DualCameraLineController: AVCaptureDataOutputSynchronizerDelegate {

    func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        // This runs on dataQueue.
        let handler: ((UIImage, UIImage, Float) -> Void)? = captureLock.withLock {
            let h = _pendingCapture; _pendingCapture = nil; return h
        }
        guard let handler else { return }

        guard
            let wideData  = collection.synchronizedData(for: wideOutput)
                                as? AVCaptureSynchronizedSampleBufferData,
            !wideData.sampleBufferWasDropped,
            let ultraData = collection.synchronizedData(for: ultraOutput)
                                as? AVCaptureSynchronizedSampleBufferData,
            !ultraData.sampleBufferWasDropped,
            let widePixels  = CMSampleBufferGetImageBuffer(wideData.sampleBuffer),
            let ultraPixels = CMSampleBufferGetImageBuffer(ultraData.sampleBuffer)
        else { return }

        let wideCI  = CIImage(cvPixelBuffer: widePixels)
        let ultraCI = CIImage(cvPixelBuffer: ultraPixels)

        guard
            let wideCG  = ciContext.createCGImage(wideCI,  from: wideCI.extent),
            let ultraCG = ciContext.createCGImage(ultraCI, from: ultraCI.extent)
        else { return }

        let wideImg  = UIImage(cgImage: wideCG)
        let ultraImg = UIImage(cgImage: ultraCG)
        let ratio    = fovRatio  // read from main actor is safe here (Float is value type)

        DispatchQueue.main.async { handler(wideImg, ultraImg, ratio) }
    }
}
