//
//  ViewController.swift
//  Camera2RTSP
//
//  Created by Usama Liaqat on 05/12/2024.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let cameraPublisher: CameraPublisher = CameraPublisher()
    private var publishStatus: Bool = false

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var startPublishButton: UIButton!
    @IBOutlet weak var stopPublishButton: UIButton!

    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var currentCameraPosition: AVCaptureDevice.Position = .back

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        buttonIsEnabled(button: startPublishButton, status: true, color: .systemGreen)
        buttonIsEnabled(button: stopPublishButton, status: false, color: .systemRed)

    }
    

    func setupCamera() {
        // Initialize capture session
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        // Set the input device (camera)
        setupCameraInput(position: currentCameraPosition)
        setupVideoOutput()

        // Set video output to display the camera feed
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = .resizeAspect
        videoPreviewLayer?.frame = cameraView.bounds
        if let videoLayer = videoPreviewLayer {
            cameraView.layer.addSublayer(videoLayer)
        }
        
        // Start the camera session
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
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
            try captureDevice.lockForConfiguration()
            let desiredFrameRate: Int32 = 30 // Set your desired frame rate here
            if captureDevice.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= Float64(desiredFrameRate) && Float64(desiredFrameRate) <= $0.maxFrameRate }) {
                print("Framerate is set to --- ",desiredFrameRate)
                captureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: desiredFrameRate)
                captureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: desiredFrameRate)
            } else {
                print("Desired frame rate not supported")
            }
            captureDevice.unlockForConfiguration()
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
    
    
    func setupVideoOutput() {
        // Configure video output to capture frames
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraFrameQueue"))
        
        if let captureSession = captureSession, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Unable to add video output")
        }
    }
    
    func getCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // Find and return the camera device for the specified position
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices
        return devices.first(where: { $0.position == position })
    }
    
    func buttonIsEnabled(button: UIButton, status: Bool = false, color: UIColor = .systemGray){
        button.isEnabled = status
        if(status){
            button.backgroundColor = color
        }else {
            button.backgroundColor = .systemGray
        }
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
    
    @IBAction func startPublishTapped(_ sender: UIButton) {
        DispatchQueue.global().async {
//            self.cameraPublisher.start("rtsp://10.1.10.129/usama-liaqat", withCallback:self.publishStatupUpdate)
            self.cameraPublisher.start("rtsp://sn-webrtc.snipback.com/usama-liaqat", withCallback:self.publishStatupUpdate)
        }
    }
    
    @IBAction func stopPublishTapped(_ sender: UIButton) {
        self.cameraPublisher.stop()
    }
    
    private func publishStatupUpdate(state:Bool) {
        print("Pipeline Status", state)


        DispatchQueue.main.async {
            self.buttonIsEnabled(button: self.startPublishButton, status: !state, color: .systemGreen)
            self.buttonIsEnabled(button: self.stopPublishButton, status: state, color: .systemRed)
            self.publishStatus = state
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = cameraView.bounds
    }
    
    @objc func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
       // Pass the sample buffer to cameraPublish
        if self.publishStatus {
            self.cameraPublisher.add(sampleBuffer)
        }
   }
    

    
}

