import SwiftUI
import AVFoundation
import Vision
import Photos
import AVKit

// Modify CameraVisionView to include the new implementation
struct CameraVisionView: View {
    @State private var detectedBodyPoints: [CGPoint] = []
    @State private var timer1: Int = 0
    @State private var timer2: Int = 0
    @State private var isCounting = false
    @State private var isBodyDetected = false
    @State private var isBodyComplete = false
    @State private var isRecording = false
    @State private var recordingMessage = ""
    @State private var videoURL: URL?
    @State private var navigateToPreview = false
    @State private var hasTurnedBody: Bool = false
    @State private var showInstructions = true
    @State private var countdownPlayer: AVAudioPlayer?
    @State private var startPlayer: AVAudioPlayer?
    
    // Optional timers
    @State private var firstTimer: Timer?
    @State private var secondTimer: Timer?
    
    // Almacena los puntos previos
    @State private var previousBodyPoints: [CGPoint] = []
    @State private var smoothedBodyPoints: [CGPoint] = []
    
    // Add new state variable
    @State private var recordingProgress: Double = 0
    @State private var canDismissInstructions = false
    @State private var buttonOpacity = 0.5
    @State private var isCountingDown: Bool = false
    
    // Add new state properties at the top with other @State variables
    @State private var fullBodyPlayer: AVAudioPlayer?
    @State private var turnBodyPlayer: AVAudioPlayer?
    @State private var jabInstructionPlayer: AVAudioPlayer?
    
    // Add these to your existing state variables
    @AppStorage("hasSeenInstructions") private var hasSeenInstructions = false
    @State private var currentInstructionStep = 1
    @State private var showInstructionsOverlay = false
    
    // Keep the state variable
    @State private var currentTurnAngle: Double = 0
    @State private var isShowingTurnAnimation: Bool = false
    
    // Add these state variables at the top
    @State private var isCameraInitialized = false
    @EnvironmentObject var userManager: UserManager
    
    var cameraManager: CameraManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview should be the base layer
                CameraPreviewView(detectedBodyPoints: $detectedBodyPoints,
                                 smoothedBodyPoints: $smoothedBodyPoints,
                                 isBodyDetected: $isBodyDetected,
                                 isBodyComplete: $isBodyComplete,
                                 hasTurnedBody: $hasTurnedBody,
                                 isCountingDown: $isCountingDown,
                                 currentTurnAngle: $currentTurnAngle,
                                 cameraManager: cameraManager,
                                 turnBodyPlayer: turnBodyPlayer)
                    .ignoresSafeArea(.all, edges: [.horizontal])
                    .onAppear {
                        // Delay the body detection until camera is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isCameraInitialized = true
                        }
                    }
                
                // Only show body detection overlay if camera is initialized
                if isCameraInitialized {
                    // Body detection points and messages
                    ForEach(smoothedBodyPoints.indices, id: \.self) { index in
                        let point = smoothedBodyPoints[index]
                        Circle()
                            .fill(Color.red)
                            .frame(width: 15, height: 15)
                            .position(x: point.x, y: point.y)
                            .shadow(color: .black, radius: 2)
                    }
                    
                    if !isBodyDetected || !isBodyComplete {
                        bodyDetectionOverlay
                    }
                }
                
                // Updated analyzing message with progress bar
                if isCounting && timer1 < 3 {
                    VStack {
                        HStack {
                            Image(systemName: "figure.kickboxing")
                                .foregroundColor(.red)
                                .font(.system(size: 40))
                            Text("Get Ready Fighter! Stay in the camera.")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(15)
                        
                        ProgressView(value: Double(timer1), total: 3.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .padding(.top, 10)
                            .frame(width: 200)
                    }
                    .padding(.top, 50)
                }
                
                // Updated body detection message
                if !isBodyDetected || !isBodyComplete {
                    VStack {
                        Text("Step your full body into the frame, fighter! 🥊")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(15)
                    }
                    .padding(.top, 50)
                    .onAppear {
                        fullBodyPlayer?.play()
                    }
                }
                
                // Updated countdown with visual feedback
                if timer2 > 0 && timer2 <= 5 && !isRecording {
                    VStack {
                        Text("\(5 - timer2)")
                            .font(.system(size: 120, weight: .heavy))
                            .foregroundColor(.red)
                            .shadow(color: .black, radius: 2, x: 0, y: 0)
                            .transition(.scale)
                            .animation(.easeInOut, value: timer2)
                        
                        Text("Get Ready!")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                    }
                }
                
                // Updated recording message overlay
                if isRecording {
                    VStack(spacing: 15) {
                        Image(systemName: "record.circle")
                            .foregroundColor(.red)
                            .font(.system(size: 50))
                        Text(recordingMessage)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        
                        // Timer bar
                        ProgressView(value: recordingProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .frame(width: 200)
                            .animation(.linear(duration: 2.0), value: recordingProgress)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(15)
                    .padding(.top, 100)
                }
                
                // Add to CameraVisionView body, after the existing overlays
                if isBodyDetected && isBodyComplete && !hasTurnedBody {
                    VStack {
                        HStack(spacing: 15) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.white)
                                .font(.system(size: 30))

                                Text("Turn 7°")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            Text("\(currentTurnAngle, specifier: "%.0f")° angle")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(15)
                        
                        // Progress arc
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 10)
                                .frame(width: 100, height: 100)
                            
                            Circle()
                                .trim(from: 0, to: isShowingTurnAnimation ? 1 : 0)
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 2.0), value: isShowingTurnAnimation)
                        }
                    }
                    .padding(.top, 50)
                    .onAppear {
                        turnBodyPlayer?.play()
                        withAnimation {
                            isShowingTurnAnimation = true
                        }
                    }
                }
                
                // Add the info button in the top right
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            currentInstructionStep = 1
                            showInstructionsOverlay = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .padding()
                    }
                    .padding(.top, 50)
                    Spacer()
                }
                
                // Instructions overlay
                if !hasSeenInstructions || showInstructionsOverlay {
                    InstructionsOverlay(
                        currentStep: $currentInstructionStep,
                        isShowing: $showInstructionsOverlay,
                        hasSeenInstructions: $hasSeenInstructions
                    )
                }
            }
            .navigationDestination(isPresented: $navigateToPreview) {
                if let videoURL = videoURL {
                    ResultsView(videoURL: videoURL)
                        .environmentObject(UserManager.shared)
                        .onAppear {
                            // Stop camera when navigating to results
                            cameraManager.stopSession()
                        }
                } else{
                    Text("No video URL available")
                }
            }
            .onChange(of: isBodyDetected) { _ in
                print("isBodyDetected changed to: \(isBodyDetected)")
                checkBodyDetectionState()
                checkBodyAndStartTimers()
            }
            .onChange(of: isBodyComplete) { _ in
                print("isBodyComplete changed to: \(isBodyComplete)")
                checkBodyDetectionState()
                checkBodyAndStartTimers()
            }
            .onChange(of: hasTurnedBody) { _ in
                print("hasTurnedBody changed to: \(hasTurnedBody)")
                checkBodyDetectionState()
                checkBodyAndStartTimers()
            }
            .ignoresSafeArea(.all, edges: [.horizontal, .top])
            .onDisappear {
               // cleanup()
                cameraManager.stopSession()
            }
        }
         
       .navigationBarHidden(true)
       .navigationBarBackButtonHidden(true)
        .onAppear {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("VideoRecorded"), object: nil, queue: .main) { notification in
                if let url = notification.object as? URL {
                    self.videoURL = url
                    self.navigateToPreview = true
                }
            }
            setupAudioPlayers()
            
            // Always ensure we have an active session
            if !cameraManager.isActive {
                cameraManager.startSession()
            }
        }
    }
    
    // Función que actualiza y suaviza los puntos detectados
    func updateDetectedBodyPoints(newPoints: [CGPoint]) {
        guard newPoints.count == detectedBodyPoints.count else {
            smoothedBodyPoints = newPoints
            previousBodyPoints = newPoints
            return
        }
        
        // Suaviza cada punto con interpolación
        smoothedBodyPoints = zip(previousBodyPoints, newPoints).map { previous, current in
            CGPoint(x: previous.x * 0.7 + current.x * 0.3, y: previous.y * 0.7 + current.y * 0.3)
        }
        
        // Actualiza los puntos previos
        previousBodyPoints = newPoints
    }
    
    func checkBodyAndStartTimers() {
        if isBodyDetected && isBodyComplete {
            isShowingTurnAnimation = true
            // Wait for animation to complete before starting timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                hasTurnedBody = true
                startFirstTimer()
            }
            
            // Play turn audio once at start
            turnBodyPlayer?.play()
        } else {
            resetTimers()
            isShowingTurnAnimation = false
        }
    }
    
    // Start the first timer
    func startFirstTimer() {
        guard firstTimer == nil else { return }
        
        isCounting = true
        timer1 = 0
        timer2 = 0
        recordingMessage = ""
        
        firstTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timer1 < 3 {
                timer1 += 1
            } else {
                firstTimer?.invalidate()
                firstTimer = nil
                timer2 = 1  // Start at 1 to show "3"
                startSecondTimer()
            }
            
            if !isBodyDetected {
                resetTimers()
            }
        }
    }
    
    // Start the second timer
    func startSecondTimer() {
        guard secondTimer == nil else { return }
        
        timer2 = 1  // Start at 1 to show "5"
        isCountingDown = true
        
        secondTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timer2 < 6 {
                timer2 += 1
                if timer2 < 6 {
                    countdownPlayer?.play()
                } else {
                    startPlayer?.play()
                    simulateRecording()
                }
            } else {
                secondTimer?.invalidate()
                secondTimer = nil
            }
        }
    }
    
    // Simulate recording
    func simulateRecording() {
        isRecording = true
        recordingMessage = "Recording..."
        recordingProgress = 0.0
        
        jabInstructionPlayer?.play()
        cameraManager.startRecording()
        
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            withAnimation {
                recordingProgress += 0.05
            }
            
            if recordingProgress >= 1.0 {
                timer.invalidate()
                recordingMessage = "Recording finished"
                cameraManager.stopRecording()
                resetTimers()
                
                // Add a slight delay before navigation to ensure recording is saved
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.navigateToPreview = true
                }
            }
        }
    }
    
    // Reset all timers and states
    func resetTimers() {
        firstTimer?.invalidate()
        firstTimer = nil
        secondTimer?.invalidate()
        secondTimer = nil
        
        // Stop all audio players
        fullBodyPlayer?.stop()
        turnBodyPlayer?.stop()
        countdownPlayer?.stop()
        startPlayer?.stop()
        jabInstructionPlayer?.stop()
        
        // Reset all states
        isCounting = false
        isRecording = false
        timer1 = 0
        timer2 = 0
        recordingMessage = ""
        hasTurnedBody = false
        isCountingDown = false
        isShowingTurnAnimation = false
        isBodyDetected = false
        isBodyComplete = false
        
        if isRecording {
            cameraManager.stopRecording()
        }
    }
    
    // Add these new helper views and functions
    private struct InstructionRow: View {
        let number: Int
        let text: String
        let icon: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 40)
                Text("\(number). \(text)")
                    .foregroundColor(.white)
            }
        }
    }
    
    private func setupAudioPlayers() {
        // Setup countdown sound
        if let countdownURL = Bundle.main.url(forResource: "countdown", withExtension: "wav") {
            countdownPlayer = try? AVAudioPlayer(contentsOf: countdownURL)
            countdownPlayer?.prepareToPlay()
        }
        
        // Setup start sound
        if let startURL = Bundle.main.url(forResource: "start", withExtension: "wav") {
            startPlayer = try? AVAudioPlayer(contentsOf: startURL)
            startPlayer?.prepareToPlay()
        }
        
        // Setup full body sound
        if let fullBodyURL = Bundle.main.url(forResource: "FullBodyInFrame", withExtension: "wav") {
            do {
                fullBodyPlayer = try AVAudioPlayer(contentsOf: fullBodyURL)
                fullBodyPlayer?.prepareToPlay()
                print("Full Body player initialized successfully")
            } catch {
                print("Error initializing Full Body player: \(error)")
            }
        } else {
            print("Failed to find Full Body sound file")
        }
        
        // Setup turn body sound
        if let turnBodyURL = Bundle.main.url(forResource: "TurnBodySlightly", withExtension: "wav") {
            do {
                turnBodyPlayer = try AVAudioPlayer(contentsOf: turnBodyURL)
                turnBodyPlayer?.prepareToPlay()
                print("Turn Body player initialized successfully")
            } catch {
                print("Error initializing Turn Body player: \(error)")
            }
        } else {
            print("Failed to find Turn Body sound file")
        }
        
        // Setup jab instruction sound
        if let jabInstructionURL = Bundle.main.url(forResource: "JabStraightAhead", withExtension: "wav") {
            jabInstructionPlayer = try? AVAudioPlayer(contentsOf: jabInstructionURL)
            jabInstructionPlayer?.prepareToPlay()
        }
    }
    
    // Add new function to handle body detection state changes
    func checkBodyDetectionState() {
        print("checkBodyDetectionState called - isBodyDetected: \(isBodyDetected), isBodyComplete: \(isBodyComplete), hasTurnedBody: \(hasTurnedBody)")
        
        if !isBodyDetected || !isBodyComplete {
            print("Playing full body audio instruction")
            fullBodyPlayer?.play()
        } else if isBodyDetected && isBodyComplete && !hasTurnedBody {
            print("Playing turn body audio instruction")
            turnBodyPlayer?.play()
        }
    }
    
    private func resetForNextRecording() {
        // Reset all states
        isRecording = false
        isCounting = false
        timer1 = 0
        timer2 = 0
        hasTurnedBody = false
        isCountingDown = false
        recordingProgress = 0
        
        // Stop and reset camera
        cameraManager.cleanup()
       
        cameraManager.startSession()
        
        // Reset audio players
        setupAudioPlayers()
    }
    
    func cleanup() {
        resetTimers()
        cameraManager.stopSession() 
        cameraManager.cleanup()
        
    }
    
    private var bodyDetectionOverlay: some View {
        VStack {
            Text("Step your full body into the frame, fighter! 🥊")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(15)
        }
        .padding(.top, 50)
        .onAppear {
            fullBodyPlayer?.play()
        }
    }
}

struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var detectedBodyPoints: [CGPoint]
    @Binding var smoothedBodyPoints: [CGPoint]
    @Binding var isBodyDetected: Bool
    @Binding var isBodyComplete: Bool
    @Binding var hasTurnedBody: Bool
    @Binding var isCountingDown: Bool
    @Binding var currentTurnAngle: Double
    
    var cameraManager: CameraManager
    var turnBodyPlayer: AVAudioPlayer?
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraPreviewView
        var hasTurnedBodyCompleted = false
        
        // Update these values
        private let confidenceThreshold: VNConfidence = 0.3  // Increased from 0.3
        private let requiredConsecutiveFrames = 5  // Increased from 3
        private let stateChangeDebounceInterval: TimeInterval = 1.0  // Increased from 0.5
        
        // Add this missing property
        private var stableBodyDetection = false
        
        // Existing properties...
        private var recentAngles: [Double] = []
        private let angleHistoryCount = 5
        private var lastBodyStateChange = Date()
        private var consecutiveBodyDetections = 0
        private var consecutiveBodyLosses = 0
        private let requiredFramesForLoss = 10  // More frames required to lose detection than to gain it
        
        init(parent: CameraPreviewView) {
            self.parent = parent
            super.init()
        }
        
        let requiredPoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .leftWrist,
            .rightWrist,
            .leftAnkle,
            .rightAnkle
        ]
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard parent.cameraManager.isActive else { return }
            if parent.isCountingDown { return }
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let request = VNDetectHumanBodyPoseRequest { [self] request, error in
                guard let results = request.results as? [VNHumanBodyPoseObservation], error == nil else { return }
                
                var bodyDetected = false
                var bodyComplete = true
                
                for bodyObservation in results {
                    if let recognizedPoints = try? bodyObservation.recognizedPoints(.all) {
                        bodyDetected = !recognizedPoints.isEmpty
                        
                        var newPoints: [CGPoint] = []
                        for pointName in requiredPoints {
                            if let point = recognizedPoints[pointName],
                               point.confidence > confidenceThreshold {
                                let convertedPoint = convertVisionPoint(point.location, to: parent.cameraManager.previewLayer)
                                newPoints.append(convertedPoint)
                            } else {
                                bodyComplete = false
                                break
                            }
                        }
                        
                        // Update points on main thread
                        DispatchQueue.main.async {
                            self.parent.detectedBodyPoints = newPoints
                            // Use existing smoothing function
                            self.parent.smoothedBodyPoints = self.parent.applySmoothing(to: newPoints)
                        }
                        
                        // Update consecutive frame counters
                        if bodyDetected && bodyComplete {
                            consecutiveBodyDetections += 1
                            consecutiveBodyLosses = 0
                        } else {
                            consecutiveBodyLosses += 1
                            consecutiveBodyDetections = 0
                        }
                        
                        // Body turn detection with smoothing
                        if bodyComplete {
                            if let leftShoulder = recognizedPoints[.leftShoulder],
                               let rightShoulder = recognizedPoints[.rightShoulder],
                               let leftHip = recognizedPoints[.leftHip],
                               let rightHip = recognizedPoints[.rightHip] {
                                
                                let shoulderAngle = calculateAngleBetweenPoints(
                                    left: leftShoulder.location,
                                    right: rightShoulder.location
                                )
                                
                                // Add to recent angles for smoothing
                                recentAngles.append(shoulderAngle)
                                if recentAngles.count > angleHistoryCount {
                                    recentAngles.removeFirst()
                                }
                                
                                let smoothedAngle = recentAngles.reduce(0.0, +) / Double(recentAngles.count)
                                let smoothedAdjustedAngle = abs(smoothedAngle - 90)
                                
                                // Update current turn angle for progress display
                                DispatchQueue.main.async {
                                    self.parent.currentTurnAngle = smoothedAdjustedAngle
                                }
                                
                                // Update UI with debouncing
                                let now = Date()
                                if now.timeIntervalSince(lastBodyStateChange) >= stateChangeDebounceInterval {
                                    DispatchQueue.main.async {
                                        // Update stable detection state
                                        if self.consecutiveBodyDetections >= self.requiredConsecutiveFrames {
                                            self.stableBodyDetection = true
                                        } else if self.consecutiveBodyLosses >= self.requiredFramesForLoss {
                                            self.stableBodyDetection = false
                                        }
                                        
                                        // Only update UI based on stable detection
                                        self.parent.isBodyDetected = self.stableBodyDetection
                                        self.parent.isBodyComplete = self.stableBodyDetection
                                        
                                        // Keep the turn detection logic separate
                                        if let smoothedAdjustedAngle = self.calculateSmoothedAngle(from: recognizedPoints),
                                           smoothedAdjustedAngle >= 2 && smoothedAdjustedAngle <= 12 {
                                            self.parent.hasTurnedBody = true
                                        }
                                        
                                        self.lastBodyStateChange = now
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        }
        
        func calculateAngleBetweenPoints(left: CGPoint, right: CGPoint) -> CGFloat {
            let deltaY = left.y - right.y
            let deltaX = left.x - right.x
            let radians = atan2(deltaY, deltaX)
            let degrees = radians * 180 / .pi
            return degrees
        }
        
        func convertVisionPoint(_ point: CGPoint, to layer: AVCaptureVideoPreviewLayer?) -> CGPoint {
            guard let layer = layer else { return .zero }
            let convertedPoint = layer.layerPointConverted(fromCaptureDevicePoint: point)
            let reflectedX = layer.bounds.width - convertedPoint.x
            return CGPoint(x: reflectedX, y: convertedPoint.y)
        }
        
        private func calculateSmoothedAngle(from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Double? {
            if let leftShoulder = points[.leftShoulder],
               let rightShoulder = points[.rightShoulder] {
                let shoulderAngle = calculateAngleBetweenPoints(
                    left: leftShoulder.location,
                    right: rightShoulder.location
                )
                return abs(shoulderAngle - 90)
            }
            return nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        cameraManager.setupCamera(in: viewController.view, delegate: context.coordinator)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func applySmoothing(to points: [CGPoint]) -> [CGPoint] {
        guard !points.isEmpty else { return points }
        
        // If this is the first set of points, initialize smoothed points
        if smoothedBodyPoints.isEmpty {
            return points
        }
        
        // Stronger smoothing factor (increased from 0.7)
        let smoothingFactor: CGFloat = 0.8
        
        return zip(smoothedBodyPoints, points).map { previous, current in
            // Only apply smoothing if points are within a reasonable distance
            let distance = hypot(current.x - previous.x, current.y - previous.y)
            
            // If movement is very small, keep previous point to reduce jitter
            if distance < 3.0 {
                return previous
            }
            
            // If movement is large, reduce smoothing to allow faster response
            let dynamicSmoothingFactor = distance > 20.0 ? 0.5 : smoothingFactor
            
            return CGPoint(
                x: previous.x * dynamicSmoothingFactor + current.x * (1 - dynamicSmoothingFactor),
                y: previous.y * dynamicSmoothingFactor + current.y * (1 - dynamicSmoothingFactor)
            )
        }
    }
}


class CameraManager: NSObject, ObservableObject {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var movieOutput = AVCaptureMovieFileOutput()
    
    @Published var isActive = false
    @Published var setupError: Error?
    private let sessionQueue = DispatchQueue(label: "com.formfighter.sessionQueue")
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.isActive = false
            }
        }
    }
    
    func startSession() {
        guard !isActive else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isActive = true
            }
        }
    }
    
    func cleanup() {
        stopSession()
        captureSession = nil
        previewLayer = nil
    }
    
    func setupCamera(in view: UIView, delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        // Camera input configuration
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Rear camera not found")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                print("Could not add camera input.")
                return
            }
        } catch {
            print("Error adding camera input: \(error)")
            return
        }
        
        // Configure and add video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "cameraQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Could not add videoOutput to session.")
            return
        }
        
        // Configure and add output for video recording
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        } else {
            print("Could not add movieOutput to session.")
            return
        }
        
        // Configure preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer!)
        
        // Start capture session
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
            DispatchQueue.main.async {
                print("Capture session active: \(captureSession.isRunning)")
            }
        }
        
        self.captureSession = captureSession
    }
    
    // Start recording
    func startRecording() {
        // Ensure that the capture session is running
        guard let captureSession = captureSession, captureSession.isRunning else {
            print("Capture session is not active.")
            return
        }
        
        // Verify if movieOutput has active connections just before recording
        if movieOutput.connections.isEmpty {
            print("There are no active connections for recording output.")
            return
        }
        
        // If there are active connections, start recording
        let fileName = "output_\(UUID().uuidString).mov"
        let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        // Check if the file already exists and delete it
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
                print("Existing file deleted.")
            } catch {
                print("Error deleting existing file: \(error)")
            }
        }
        
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        print("Recording started, saving to: \(outputURL.absoluteString)")
    }
    
    // Stop recording
    func stopRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
    }
}

// Extension to handle recording and save video to photo library
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            Logger.log(message: "Recording error: \(error.localizedDescription)", event: .error)
            Logger.recordError(error, context: ["recording_url": outputFileURL.absoluteString])
        } else {
            if FileManager.default.fileExists(atPath: outputFileURL.path) {
                Logger.log(message: "Video recording completed successfully", event: .debug)
                // Post notification with the URL
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("VideoRecorded"), object: outputFileURL)
                }
            } else {
                Logger.log(message: "Video file not created correctly", event: .error)
            }
        }
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// First, create an instruction model to hold our data
struct Instruction {
    let number: Int
    let text: String
    let icon: String
}

// Create a separate InstructionsOverlay view
struct InstructionsOverlay: View {
    @Binding var currentStep: Int
    @Binding var isShowing: Bool
    @Binding var hasSeenInstructions: Bool
    
    let instructions = [
        Instruction(number: 1, text: "Turn on audio on 🔊", icon: "speaker.wave.2.fill"),
        Instruction(number: 2, text: "only one person in camera", icon: "person.fill"),
        Instruction(number: 3, text: "Record in a well lit room", icon: "light.min"),
        Instruction(number: 4, text: "Stand 6-8 feet from camera", icon: "person.and.arrow.left.and.arrow.right"),
        Instruction(number: 5, text: "Show your full body in frame", icon: "figure.stand"),
        Instruction(number: 6, text: "Turn your body 7 degrees stance", icon: "arrow.triangle.2.circlepath"),
        Instruction(number: 7, text: "Hold still for recording", icon: "video.fill"),
        Instruction(number: 8, text: "Perform ONE jab", icon: "figure.boxing")
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Add some top spacing
                Spacer().frame(height: 100)  // Adjust this value to move the title lower
                
                // Header with close button
                HStack {
                    Text("How to Record Your Form")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            isShowing = false
                            hasSeenInstructions = true
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Current instruction
                if let instruction = instructions[safe: currentStep - 1] {
                    VStack(spacing: 30) {
                        Image(systemName: instruction.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text(instruction.text)
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .transition(.opacity)
                }
                
                Spacer()
                
                // Progress indicators
                HStack(spacing: 8) {
                    ForEach(1...instructions.count, id: \.self) { step in
                        Circle()
                            .fill(step == currentStep ? Color.red : Color.gray)
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Navigation buttons
                HStack(spacing: 20) {
                    Button("Skip") {
                        withAnimation {
                            isShowing = false
                            hasSeenInstructions = true
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(10)
                    
                    Button(currentStep == instructions.count ? "Done" : "Next") {
                        withAnimation {
                            if currentStep == instructions.count {
                                isShowing = false
                                hasSeenInstructions = true
                            } else {
                                currentStep += 1
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .transition(.opacity)
    }
}
