import SwiftUI
import AVFoundation

struct ScannerView: View {
    var isScanningActive: Bool
    var onPlateScanned: (RegionModel, String, String?) -> Void

    // MARK: - State
    @State private var isFlashlightOn = false
    @State private var zoomFactor: CGFloat = 1.0
    @State private var pinchStartZoom: CGFloat = 1.0
    @State private var showZoomBadge = false
    @State private var zoomBadgeTask: Task<Void, Never>? = nil

    private let zoomPresets: [CGFloat] = [1.0, 2.0, 3.0]
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 5.0

    var body: some View {
        ZStack {
            // Live Camera Feed + pinch gesture
            CameraScannerView(
                isScanningActive: isScanningActive,
                zoomFactor: zoomFactor,
                onPlateScanned: onPlateScanned
            )
            .ignoresSafeArea()
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newZoom = (pinchStartZoom * value).clamped(to: minZoom...maxZoom)
                        zoomFactor = newZoom
                        flashZoomBadge()
                    }
                    .onEnded { value in
                        pinchStartZoom = zoomFactor
                    }
            )

            // HUD & Controls Overlay
            VStack {
                // Top App Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rejestrator")
                            .font(.system(.title))
                            .fontWeight(.black)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color(red: 0.0, green: 0.6, blue: 0.95)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 0)

                        Text("POLSKI SKANER TABLIC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .kerning(1.5)
                    }

                    Spacer()

                    // Flashlight Toggle Button
                    Button(action: toggleFlashlight) {
                        Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title3)
                            .foregroundColor(isFlashlightOn ? .blue : .white)
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isFlashlightOn ? Color.cyan.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                Spacer()

                // Zoom badge — appears briefly on zoom change
                if showZoomBadge {
                    Text(zoomLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .padding(.bottom, 10)
                }

                // Guidance Instructions
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder")
                            .foregroundColor(.cyan)
                            .font(.callout)

                        Text("Umieść tablicę wewnątrz ramki")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())

                    Text("Skanowanie nastąpi automatycznie")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))

                    // Zoom preset buttons
                    zoomPresetsRow
                }
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showZoomBadge)
        .onDisappear {
            if isFlashlightOn {
                setTorch(on: false)
                isFlashlightOn = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if isFlashlightOn {
                setTorch(on: false)
                isFlashlightOn = false
            }
        }
    }

    // MARK: - Zoom Presets Row

    private var zoomPresetsRow: some View {
        HStack(spacing: 10) {
            ForEach(zoomPresets, id: \.self) { preset in
                let isActive = abs(zoomFactor - preset) < 0.15
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        zoomFactor = preset
                        pinchStartZoom = preset
                        flashZoomBadge()
                    }
                } label: {
                    Text("\(Int(preset))×")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .black : .white)
                        .frame(width: 44, height: 44)
                        .background(isActive ? Color.white : Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isActive ? 0 : 0.3), lineWidth: 1)
                        )
                        .scaleEffect(isActive ? 1.1 : 1.0)
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
            }
        }
    }

    // MARK: - Helpers

    private var zoomLabel: String {
        let rounded = (zoomFactor * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))×" : String(format: "%.1f×", rounded)
    }

    private func flashZoomBadge() {
        zoomBadgeTask?.cancel()
        showZoomBadge = true
        zoomBadgeTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation { showZoomBadge = false }
                }
            }
        }
    }

    private func toggleFlashlight() {
        isFlashlightOn.toggle()
        setTorch(on: isFlashlightOn)
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to configure flashlight: \(error)")
        }
    }
}

// MARK: - Comparable clamped helper
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ScannerView(isScanningActive: true) { _, _, _ in }
        .background(.black)
}
