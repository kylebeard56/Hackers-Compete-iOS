//
//  QRScannerView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/8/26.
//

import SwiftUI
import AVFoundation

enum QRScanResult {
    case success(URL)
    case failure(QRScanError)
}

enum QRScanError: Error {
    case invalidQR
    case cameraUnavailable
    
    var description: String {
        switch self {
        case .invalidQR:
            return "This QR code is invalid."
        case .cameraUnavailable:
            return "Your camera is unavailable."
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    let onResult: (QRScanResult) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onResult = onResult
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onResult: ((QRScanResult) -> Void)?

    private let session = AVCaptureSession()
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCamera()
    }

    private func configureCamera() {
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            onResult?(.failure(.cameraUnavailable))
            return
        }

        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue: .main)

        session.addInput(input)
        session.addOutput(output)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            !didScan,
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let string = object.stringValue,
            let url = URL(string: string)
        else {
            return
        }

        didScan = true
        session.stopRunning()

        onResult?(.success(url))
    }
}
