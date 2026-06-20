import AVFoundation
import SwiftUI
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    @Published var authorazitationStatus: AVAuthorizationStatus = .notDetermined
    
    //AVFoundation Components
    let session = AVCaptureSession()
}
