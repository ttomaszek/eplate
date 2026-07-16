import SwiftUI

struct CameraScannerView: UIViewControllerRepresentable {
    // MARK: - Properties
    var isScanningActive: Bool
    var zoomFactor: CGFloat
    /// Called on confirmed scan. Parameters: region, rawPlateText, optional saved image filename.
    var onPlateScanned: (RegionModel, String, String?) -> Void

    // MARK: - UIViewControllerRepresentable Lifecycle
    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {
        uiViewController.isScanningActive = isScanningActive
        uiViewController.setZoom(zoomFactor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPlateScanned: onPlateScanned)
    }

    // MARK: - Coordinator Class
    class Coordinator: CameraScannerViewControllerDelegate {
        // MARK: - Coordinator Properties
        var onPlateScanned: (RegionModel, String, String?) -> Void

        private var lastScanTime: Date = Date.distantPast
        private let scanCooldown: TimeInterval = 3.0

        private struct CandidateDetection {
            let firstSeen: Date
            var lastSeen: Date
            var count: Int
        }

        private var candidates: [String: CandidateDetection] = [:]
        private let requiredDetections = 3
        private let stabilizationDuration: TimeInterval = 0.5

        // MARK: - Initialization
        init(onPlateScanned: @escaping (RegionModel, String, String?) -> Void) {
            self.onPlateScanned = onPlateScanned
        }

        // MARK: - CameraScannerViewControllerDelegate
        func cameraScanner(_ controller: CameraScannerViewController, didRecognizePlate plateText: String, region: RegionModel, cropData: Data?) {
            let now = Date()

            guard now.timeIntervalSince(lastScanTime) > scanCooldown else {
                controller.setViewfinderLockState(isLocked: false)
                return
            }

            candidates = candidates.filter { now.timeIntervalSince($0.value.lastSeen) < 1.2 }

            if var candidate = candidates[plateText] {
                candidate.count += 1
                candidate.lastSeen = now
                candidates[plateText] = candidate

                controller.setViewfinderLockState(isLocked: true)

                if candidate.count >= requiredDetections && now.timeIntervalSince(candidate.firstSeen) >= stabilizationDuration {
                    candidates.removeAll()
                    lastScanTime = now

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    controller.setViewfinderLockState(isLocked: false)

                    // Save the crop image to disk
                    let filename = saveCropImage(cropData)

                    DispatchQueue.main.async {
                        self.onPlateScanned(region, plateText, filename)
                    }
                }
            } else {
                candidates[plateText] = CandidateDetection(firstSeen: now, lastSeen: now, count: 1)
                controller.setViewfinderLockState(isLocked: true)
            }
        }

        // MARK: - Image Persistence
        private func saveCropImage(_ data: Data?) -> String? {
            guard let data = data else { return nil }
            let filename = "plate_\(UUID().uuidString).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            do {
                try data.write(to: url)
                return filename
            } catch {
                print("Failed to save plate image: \(error)")
                return nil
            }
        }
    }
}
