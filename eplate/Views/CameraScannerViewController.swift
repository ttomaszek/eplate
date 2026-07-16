import UIKit
import AVFoundation
import Vision

// MARK: - Delegate Protocol
protocol CameraScannerViewControllerDelegate: AnyObject {
    func cameraScanner(_ controller: CameraScannerViewController, didRecognizePlate plateText: String, region: RegionModel, cropData: Data?)
}

// MARK: - Controller Class
class CameraScannerViewController: UIViewController {
    // MARK: - Properties
    weak var delegate: CameraScannerViewControllerDelegate?
    var isScanningActive: Bool = true
    
    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoDataOutputQueue = DispatchQueue(label: "com.eplate.videoDataOutputQueue", qos: .userInteractive)
    
    private var textRecognitionRequest: VNRecognizeTextRequest?
    
    private var normalizedCutoutRect: CGRect = .zero
    private var cutoutView: UIView?
    private var overlayLayer: CAShapeLayer?
    private var targetBracketsView: TargetBracketsView?
    private var currentVideoSize = CGSize(width: 720, height: 1280)
    
    private var lastLockUpdate = Date.distantPast
    private var isCurrentlyLocked = false
    /// Holds the cropped JPEG data from the most recent frame that produced a match.
    private var capturedCropData: Data?
    /// Pixel buffer of the frame currently being processed by Vision (set before perform, read in completion).
    private var pendingPixelBuffer: CVPixelBuffer?
    /// Reusable Core Image rendering context.
    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupVision()
        setupOverlay()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        layoutOverlay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    // MARK: - Public Interface

    /// Applies a zoom factor (1.0 – 5.0) to the capture device.
    /// Uses optical lens switching when available, then digital zoom.
    func setZoom(_ factor: CGFloat) {
        guard let device = captureDevice else { return }
        do {
            try device.lockForConfiguration()
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            device.videoZoomFactor = max(1.0, min(factor, maxZoom))
            device.unlockForConfiguration()
        } catch {
            print("Could not set zoom: \(error)")
        }
    }

    func setViewfinderLockState(isLocked: Bool) {
        if isLocked {
            lastLockUpdate = Date()
        }
        guard isCurrentlyLocked != isLocked else { return }
        isCurrentlyLocked = isLocked
        
        DispatchQueue.main.async { [weak self] in
            self?.targetBracketsView?.setLockState(isLocked: isLocked)
        }
    }
    
    // MARK: - Private Setup Methods
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720
        
        // Prefer the camera system that supports optical zoom (triple/dual-camera iPhones)
        let preferredDeviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredDeviceTypes,
            mediaType: .video,
            position: .back
        )
        guard let device = discoverySession.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to access rear camera.")
            return
        }
        self.captureDevice = device
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            if let connection = output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        
        // Lock camera focus, exposure, and set 60 FPS frame rate
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // 60 FPS Format Search
            var bestFormat: AVCaptureDevice.Format? = nil
            var bestFrameRateRange: AVFrameRateRange? = nil
            
            for format in device.formats {
                let desc = format.formatDescription
                let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
                
                if dimensions.width >= 1280 && dimensions.height >= 720 {
                    for range in format.videoSupportedFrameRateRanges {
                        if range.maxFrameRate >= 60.0 {
                            if bestFormat == nil {
                                bestFormat = format
                                bestFrameRateRange = range
                            } else if let currentBest = bestFormat {
                                let currentBestDim = CMVideoFormatDescriptionGetDimensions(currentBest.formatDescription)
                                if dimensions.width < currentBestDim.width {
                                    bestFormat = format
                                    bestFrameRateRange = range
                                }
                            }
                        }
                    }
                }
            }
            
            if let targetFormat = bestFormat, let targetRange = bestFrameRateRange {
                device.activeFormat = targetFormat
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            } else {
                if let fallbackFormat = device.formats.first(where: { format in
                    format.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 60.0 })
                }) {
                    device.activeFormat = fallbackFormat
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        
        self.captureSession = session
        self.previewLayer = preview
    }
    
    private func setupVision() {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self, error == nil,
                  let pixelBuffer = self.pendingPixelBuffer else { return }
            self.processRecognizedText(request: request, pixelBuffer: pixelBuffer)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en", "pl"]
        request.usesLanguageCorrection = false
        self.textRecognitionRequest = request
    }
    
    private func setupOverlay() {
        let overlay = CAShapeLayer()
        overlay.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        view.layer.addSublayer(overlay)
        self.overlayLayer = overlay
        
        let brackets = TargetBracketsView()
        view.addSubview(brackets)
        self.targetBracketsView = brackets
    }
    
    private func layoutOverlay() {
        guard let overlay = overlayLayer, let preview = previewLayer else { return }
        
        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height
        
        let boxWidth = viewWidth * 0.85
        let boxHeight = boxWidth * 0.28
        let boxRect = CGRect(x: (viewWidth - boxWidth)/2, y: (viewHeight - boxHeight)/2 - 30, width: boxWidth, height: boxHeight)
        
        let path = UIBezierPath(rect: view.bounds)
        let cutoutPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 16)
        path.append(cutoutPath)
        overlay.path = path.cgPath
        overlay.fillRule = .evenOdd
        
        targetBracketsView?.frame = boxRect.insetBy(dx: -4, dy: -4)
        
        self.normalizedCutoutRect = calculateNormalizedVisionRect(from: boxRect)
    }
    
    private func calculateNormalizedVisionRect(from viewRect: CGRect) -> CGRect {
        let viewSize = view.bounds.size
        let videoSize = currentVideoSize
        
        let scale = max(viewSize.width / videoSize.width, viewSize.height / videoSize.height)
        let scaledWidth = videoSize.width * scale
        let scaledHeight = videoSize.height * scale
        
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2
        
        let localX = viewRect.origin.x - offsetX
        let localY = viewRect.origin.y - offsetY
        
        let normX = localX / scaledWidth
        let normY = localY / scaledHeight
        let normWidth = viewRect.size.width / scaledWidth
        let normHeight = viewRect.size.height / scaledHeight
        
        let visionX = normX
        let visionY = 1.0 - normY - normHeight
        
        let clampedX = max(0.0, min(visionX, 1.0))
        let clampedY = max(0.0, min(visionY, 1.0))
        let clampedWidth = max(0.0, min(normWidth, 1.0 - clampedX))
        let clampedHeight = max(0.0, min(normHeight, 1.0 - clampedY))
        
        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }
    
    private func processRecognizedText(request: VNRequest, pixelBuffer: CVPixelBuffer) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string

            if let result = PlateDatabase.shared.match(plateText: text) {
                // Crop viewfinder rect from current frame and store as low-res JPEG
                capturedCropData = cropViewfinderRegion(from: pixelBuffer)
                delegate?.cameraScanner(self, didRecognizePlate: result.correctedText, region: result.region, cropData: capturedCropData)
                break
            }
        }
    }

    /// Crops the pixel buffer to the viewfinder rectangle and returns JPEG data.
    private func cropViewfinderRegion(from pixelBuffer: CVPixelBuffer) -> Data? {
        let imgW = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imgH = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let roi = normalizedCutoutRect

        // normalizedCutoutRect uses Vision coordinates (origin at bottom-left, y increases upward).
        // CIImage also uses bottom-left origin — so we can multiply directly.
        let cropRect = CGRect(
            x: roi.origin.x * imgW,
            y: roi.origin.y * imgH,
            width: roi.width * imgW,
            height: roi.height * imgH
        )
        guard cropRect.width > 4, cropRect.height > 4,
              cropRect.maxX <= imgW, cropRect.maxY <= imgH else { return nil }

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .cropped(to: cropRect)

        // Scale down so width is at most 640 px (keeps it readable but compact)
        let scale = min(1.0, 640.0 / cropRect.width)
        if scale < 1.0 {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        // createCGImage requires `from` to match the actual CIImage extent
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        // CIImage origin is bottom-left but UIImage default is top-left;
        // rendering from extent already flips correctly via Core Graphics, so orientation is .up
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            .jpegData(compressionQuality: 0.6)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isScanningActive else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = textRecognitionRequest else { return }
        
        // Self-correcting timeout: if we haven't received a lock update in 1.0s, unlock the viewfinder
        if isCurrentlyLocked && Date().timeIntervalSince(lastLockUpdate) > 1.0 {
            setViewfinderLockState(isLocked: false)
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let size = CGSize(width: width, height: height)
        if currentVideoSize != size {
            currentVideoSize = size
            DispatchQueue.main.async { [weak self] in
                self?.layoutOverlay()
            }
        }
        
        let roi = normalizedCutoutRect
        if roi.width > 0 && roi.height > 0 &&
           roi.origin.x >= 0 && roi.origin.y >= 0 &&
           (roi.origin.x + roi.width) <= 1.001 &&
           (roi.origin.y + roi.height) <= 1.001 {
            request.regionOfInterest = roi
        } else {
            request.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        // Store before perform() — Vision calls the completion synchronously on this queue,
        // so pendingPixelBuffer is guaranteed to be set when processRecognizedText reads it.
        pendingPixelBuffer = pixelBuffer
        do {
            try handler.perform([textRecognitionRequest!])
        } catch {
            print("Vision request execution failed: \(error)")
        }
        pendingPixelBuffer = nil  // clear after completion has fired
    }
}
