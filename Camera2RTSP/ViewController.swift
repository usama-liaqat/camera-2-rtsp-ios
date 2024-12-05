//
//  ViewController.swift
//  Camera2RTSP
//
//  Created by Usama Liaqat on 05/12/2024.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var switchCameraButton: UIButton!

    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var currentCameraPosition: AVCaptureDevice.Position = .back

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    func setupCamera() {
        // Initialize capture session
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        // Set the input device (camera)
        setupCameraInput(position: currentCameraPosition)
        
        // Set video output to display the camera feed
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = .resizeAspect
        videoPreviewLayer?.frame = cameraView.bounds
        if let videoLayer = videoPreviewLayer {
            cameraView.layer.addSublayer(videoLayer)
        }
        
        // Start the camera session
        captureSession.startRunning()
    }
    
    func setupCameraInput(position: AVCaptureDevice.Position) {
            // Remove previous input if exists
        if let currentInput = captureSession?.inputs.first {
            captureSession?.removeInput(currentInput)
        }
        
        // Get the desired camera based on position (front or back)
        guard let captureDevice = getCameraDevice(for: position) else {
            print("Failed to access camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            } else {
                print("Unable to add input")
            }
        } catch {
            print("Error setting up camera input: \(error)")
        }
    }
    
    func getCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // Find and return the camera device for the specified position
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices
        return devices.first(where: { $0.position == position })
    }
    
    @IBAction func switchCameraTapped(_ sender: UIButton) {
        // Toggle between front and back camera
        if currentCameraPosition == .back {
            currentCameraPosition = .front
        } else {
            currentCameraPosition = .back
        }
        
        // Reconfigure camera input to switch cameras
        setupCameraInput(position: currentCameraPosition)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = cameraView.bounds
    }
    

}

