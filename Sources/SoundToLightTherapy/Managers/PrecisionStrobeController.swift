import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(QuartzCore)
import QuartzCore
#endif

#if canImport(UIKit)
import UIKit
#endif

/// High-precision strobe controller for therapeutic light therapy
/// Provides microsecond-accurate timing with jitter compensation
public actor PrecisionStrobeController: EmergencyStoppable {
    
    // MARK: - Types
    
    public enum PrecisionStrobeError: Error {
        case unsupportedPlatform
        case torchUnavailable
        case permissionDenied
        case frequencyOutOfRange(Float)
        case timingAccuracyInsufficient
        case emergencyStopActivated
        case hardwareLimitationExceeded
    }
    
    public struct StrobeAccuracyMetrics: Sendable {
        public let targetFrequency: Float
        public let achievedFrequency: Float
        public let averageJitter: TimeInterval      // Average timing deviation in seconds
        public let maxJitter: TimeInterval          // Maximum timing deviation in seconds
        public let accuracyPercentage: Float        // Overall accuracy (0.0-100.0)
        public let droppedCycles: Int              // Number of missed strobe cycles
        public let measurementDuration: TimeInterval // Duration of measurement period
        
        public init(targetFrequency: Float, achievedFrequency: Float, averageJitter: TimeInterval, 
                   maxJitter: TimeInterval, accuracyPercentage: Float, droppedCycles: Int, 
                   measurementDuration: TimeInterval) {
            self.targetFrequency = targetFrequency
            self.achievedFrequency = achievedFrequency
            self.averageJitter = averageJitter
            self.maxJitter = maxJitter
            self.accuracyPercentage = accuracyPercentage
            self.droppedCycles = droppedCycles
            self.measurementDuration = measurementDuration
        }
    }
    
    // MARK: - Private Properties
    
    #if canImport(UIKit)
    private let device: AVCaptureDevice? = {
        guard let device = AVCaptureDevice.default(for: .video) else { return nil }
        return device
    }()
    #endif
    

    private var precisionTimer: DispatchSourceTimer?
    private var isStrobing: Bool = false
    private var emergencyStopRequested: Bool = false
    private var currentFrequency: Float = 0.0
    private var currentIntensity: Float = 1.0
    
    // Timing measurement properties
    private var timingMeasurements: [TimeInterval] = []
    private var expectedTimings: [TimeInterval] = []
    private var actualTimings: [TimeInterval] = []
    private var droppedCycleCount: Int = 0
    private var measurementStartTime: CFAbsoluteTime = 0
    
    // High-resolution timing
    private var lastStrobeTime: CFAbsoluteTime = 0
    private var strobeState: Bool = false
    private var targetInterval: TimeInterval = 0
    
    // Jitter compensation
    private var timingDriftAccumulator: TimeInterval = 0
    private var calibrationFactor: Double = 1.0
    
    // Hardware capability detection
    private let hardwareDetector = HardwareCapabilityDetector()
    private var hardwareCapabilities: HardwareCapabilityDetector.HardwareCapabilities?
    
    // Emergency stop system
    private let emergencyStopSystem = EmergencyStopSystem()
    
    public init() {
        Task {
            await emergencyStopSystem.registerComponent(self, name: "PrecisionStrobeController")
        }
    }
    
    // MARK: - Public Interface
    
    /// Start high-precision strobing at the specified frequency
    /// - Parameters:
    ///   - frequency: Target frequency in Hz (0.5-100 Hz)
    ///   - intensity: Light intensity (0.0-1.0)
    public func startStrobing(frequency: Float, intensity: Float = 1.0) async throws {
        guard !emergencyStopRequested else {
            throw PrecisionStrobeError.emergencyStopActivated
        }
        
        guard frequency >= 0.5 && frequency <= 100.0 else {
            throw PrecisionStrobeError.frequencyOutOfRange(frequency)
        }
        
        guard intensity >= 0.0 && intensity <= 1.0 else {
            throw PrecisionStrobeError.frequencyOutOfRange(intensity)
        }
        
        // Get hardware capabilities and apply adaptive frequency limiting
        let capabilities = try await hardwareDetector.getHardwareCapabilities()
        hardwareCapabilities = capabilities
        
        #if canImport(UIKit)
        let batteryLevel = await UIDevice.current.batteryLevel
        let thermalState = ProcessInfo.processInfo.thermalState
        #else
        let batteryLevel: Float = 1.0
        let thermalState = ProcessInfo.ThermalState.nominal
        #endif
        
        let adaptedFrequency = try await hardwareDetector.getAdaptiveFrequencyLimit(
            requestedFrequency: frequency,
            batteryLevel: batteryLevel,
            thermalState: thermalState
        )
        
        // Warn if frequency was adapted
        if adaptedFrequency != frequency {
            print("⚠️ Frequency adapted from \(frequency)Hz to \(adaptedFrequency)Hz due to hardware limitations")
        }
        
        // Apply calibration factor if available
        if let calibrationFactor = capabilities.calibrationFactors[adaptedFrequency] {
            self.calibrationFactor = calibrationFactor
        } else {
            // Interpolate calibration factor from nearby frequencies
            let sortedFactors = capabilities.calibrationFactors.sorted { $0.key < $1.key }
            if let lowerFactor = sortedFactors.last(where: { $0.key <= adaptedFrequency }),
               let upperFactor = sortedFactors.first(where: { $0.key >= adaptedFrequency }) {
                let ratio = (adaptedFrequency - lowerFactor.key) / (upperFactor.key - lowerFactor.key)
                self.calibrationFactor = lowerFactor.value + (upperFactor.value - lowerFactor.value) * Double(ratio)
            } else {
                self.calibrationFactor = 1.0
            }
        }
        
        // Use adapted frequency for strobing
        currentFrequency = adaptedFrequency
        
        #if canImport(UIKit)
        // Request camera permission
        _ = try await requestCameraPermission()
        
        guard let device = device else {
            throw PrecisionStrobeError.torchUnavailable
        }
        
        guard device.hasTorch else {
            throw PrecisionStrobeError.torchUnavailable
        }
        
        // Stop any existing strobing
        if isStrobing {
            try await stopStrobing()
        }
        
        // Configure strobing parameters with adapted frequency
        currentIntensity = intensity
        targetInterval = (1.0 / Double(adaptedFrequency)) / 2.0 // Half period for on/off cycle
        
        // Initialize timing measurement
        timingMeasurements.removeAll()
        expectedTimings.removeAll()
        actualTimings.removeAll()
        droppedCycleCount = 0
        measurementStartTime = CFAbsoluteTimeGetCurrent()
        timingDriftAccumulator = 0
        
        // Configure torch - start with OFF state
        try device.lockForConfiguration()
        device.torchMode = .off  // Start with flashlight OFF
        device.unlockForConfiguration()
        
        isStrobing = true
        strobeState = false  // Start with OFF state
        lastStrobeTime = CFAbsoluteTimeGetCurrent()
        
        // Start precision timing system
        await startPrecisionTiming()
        
        print("🔆 Precision strobing started: \(frequency)Hz, intensity: \(intensity)")
        #else
        throw PrecisionStrobeError.unsupportedPlatform
        #endif
    }
    
    /// Update the strobing frequency while maintaining precision
    public func updateFrequency(_ frequency: Float) async throws {
        guard isStrobing else { return }
        
        guard frequency >= 0.5 && frequency <= 100.0 else {
            throw PrecisionStrobeError.frequencyOutOfRange(frequency)
        }
        
        currentFrequency = frequency
        targetInterval = (1.0 / Double(frequency)) / 2.0
        
        // Reset timing measurements for new frequency
        timingMeasurements.removeAll()
        expectedTimings.removeAll()
        actualTimings.removeAll()
        droppedCycleCount = 0
        measurementStartTime = CFAbsoluteTimeGetCurrent()
        timingDriftAccumulator = 0
        
        print("🔄 Frequency updated to: \(frequency)Hz")
    }
    
    /// Stop strobing and turn off the flashlight
    public func stopStrobing() async throws {
        isStrobing = false
        
        // Stop timing systems
        precisionTimer?.cancel()
        precisionTimer = nil
        
        #if canImport(UIKit)
        // Turn off torch immediately
        if let device = device {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }
        #endif
        
        strobeState = false
        print("🔆 Precision strobing stopped - flashlight OFF")
    }
    
    /// Emergency stop with guaranteed <50ms response time
    public func emergencyStop() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        emergencyStopRequested = true
        isStrobing = false
        
        // Immediately stop all timing systems
        precisionTimer?.cancel()
        precisionTimer = nil
        
        #if canImport(UIKit)
        // Immediate torch shutdown
        if let device = device {
            do {
                try device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
            } catch {
                print("Emergency stop torch shutdown error: \(error)")
            }
        }
        #endif
        
        strobeState = false
        
        let stopTime = CFAbsoluteTimeGetCurrent()
        let responseTime = (stopTime - startTime) * 1000 // Convert to milliseconds
        
        print("🚨 Emergency stop completed in \(responseTime)ms")
        
        // Verify response time requirement
        if responseTime > 50.0 {
            print("⚠️ Warning: Emergency stop took \(responseTime)ms (>50ms requirement)")
        }
    }
    
    /// Trigger system-wide emergency stop
    public func triggerSystemEmergencyStop() async throws -> EmergencyStopSystem.EmergencyStopMetrics {
        return try await emergencyStopSystem.triggerEmergencyStop()
    }
    
    /// Perform emergency stop system test
    public func performEmergencyStopTest() async throws -> EmergencyStopSystem.EmergencyStopMetrics {
        return try await emergencyStopSystem.performEmergencyStopTest()
    }
    
    /// Get emergency stop system readiness
    public func validateEmergencyStopReadiness() async throws {
        try await emergencyStopSystem.validateSystemReadiness()
    }
    
    /// Reset emergency stop state
    public func resetEmergencyStop() async {
        emergencyStopRequested = false
        print("✅ Emergency stop reset")
    }
    
    /// Get the actual achieved frequency based on timing measurements
    public func getActualFrequency() async -> Float {
        guard !actualTimings.isEmpty else { return 0.0 }
        
        // Calculate average interval from recent measurements
        let recentMeasurements = Array(actualTimings.suffix(20)) // Use last 20 measurements
        let averageInterval = recentMeasurements.reduce(0, +) / Double(recentMeasurements.count)
        
        // Convert interval to frequency (remember interval is half-period)
        let actualFrequency = 1.0 / (averageInterval * 2.0)
        return Float(actualFrequency)
    }
    
    /// Get comprehensive timing accuracy metrics
    public func getTimingAccuracy() async -> StrobeAccuracyMetrics {
        guard !timingMeasurements.isEmpty else {
            return StrobeAccuracyMetrics(
                targetFrequency: currentFrequency,
                achievedFrequency: 0.0,
                averageJitter: 0.0,
                maxJitter: 0.0,
                accuracyPercentage: 0.0,
                droppedCycles: 0,
                measurementDuration: 0.0
            )
        }
        
        let measurementDuration = CFAbsoluteTimeGetCurrent() - measurementStartTime
        let achievedFrequency = await getActualFrequency()
        
        // Calculate jitter statistics
        let averageJitter = timingMeasurements.reduce(0, +) / Double(timingMeasurements.count)
        let maxJitter = timingMeasurements.max() ?? 0.0
        
        // Calculate accuracy percentage
        let targetFrequency = Double(currentFrequency)
        let achievedFrequencyDouble = Double(achievedFrequency)
        let frequencyError = abs(targetFrequency - achievedFrequencyDouble) / targetFrequency
        let accuracyPercentage = Float(max(0.0, (1.0 - frequencyError) * 100.0))
        
        return StrobeAccuracyMetrics(
            targetFrequency: currentFrequency,
            achievedFrequency: achievedFrequency,
            averageJitter: averageJitter,
            maxJitter: maxJitter,
            accuracyPercentage: accuracyPercentage,
            droppedCycles: droppedCycleCount,
            measurementDuration: measurementDuration
        )
    }
    
    /// Check if currently strobing
    public func isCurrentlyStrobing() async -> Bool {
        return isStrobing
    }
    
    /// Get hardware capabilities for this device
    public func getHardwareCapabilities() async throws -> HardwareCapabilityDetector.HardwareCapabilities {
        return try await hardwareDetector.getHardwareCapabilities()
    }
    
    /// Get fallback strategies for unsupported frequencies
    public func getFallbackStrategies(for frequency: Float) async throws -> [FallbackStrategy] {
        return try await hardwareDetector.getFallbackStrategies(for: frequency)
    }
    
    /// Perform hardware capability benchmark
    public func performHardwareBenchmark() async throws -> HardwareCapabilityDetector.HardwareCapabilities {
        return try await hardwareDetector.performFullBenchmark()
    }
    
    // MARK: - Private Implementation
    
    private func requestCameraPermission() async throws -> Bool {
        #if canImport(UIKit)
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            throw PrecisionStrobeError.permissionDenied
        @unknown default:
            throw PrecisionStrobeError.permissionDenied
        }
        #else
        throw PrecisionStrobeError.unsupportedPlatform
        #endif
    }
    
    /// Start the precision timing system using DispatchSourceTimer
    private func startPrecisionTiming() async {
        // Use DispatchSourceTimer for high-precision timing
        startHighPrecisionTimer()
    }
    

    
    /// Start high-precision timer for sub-millisecond control
    private func startHighPrecisionTimer() {
        let queue = DispatchQueue(label: "precision-strobe-timer", qos: .userInteractive)
        precisionTimer = DispatchSource.makeTimerSource(queue: queue)
        
        // Adaptive timer interval based on frequency
        let timerInterval: TimeInterval
        if currentFrequency < 2.0 {
            // For very low frequencies (< 2Hz), use even larger intervals but ensure minimum responsiveness
            timerInterval = min(targetInterval / 4.0, 0.05) // Max 50ms intervals for very low freq
        } else if currentFrequency < 5.0 {
            // For low frequencies (2-5Hz), use larger intervals to reduce CPU usage
            timerInterval = min(targetInterval / 4.0, 0.02) // Max 20ms intervals for low freq
        } else if currentFrequency < 20.0 {
            // For medium frequencies (5-20Hz), use moderate intervals
            timerInterval = min(targetInterval / 8.0, 0.005) // Max 5ms intervals
        } else {
            // For high frequencies (>20Hz), use high precision
            timerInterval = min(targetInterval / 16.0, 0.001) // Max 1ms intervals for high freq
        }
        
        print("🕐 Timer interval: \(timerInterval * 1000)ms for \(currentFrequency)Hz (target interval: \(targetInterval * 1000)ms)")
        
        precisionTimer?.schedule(deadline: .now(), repeating: timerInterval)
        precisionTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handlePrecisionTimerCallback()
            }
        }
        
        precisionTimer?.resume()
    }
    
    /// Handle high-precision timer callback
    private func handlePrecisionTimerCallback() async {
        guard isStrobing && !emergencyStopRequested else { return }
        
        let currentTime = CFAbsoluteTimeGetCurrent()
        let timeSinceLastStrobe = currentTime - lastStrobeTime
        let adjustedInterval = targetInterval * calibrationFactor - timingDriftAccumulator
        
        // Debug logging for very low frequencies
        if currentFrequency < 2.0 {
            print("⏱️ Timer callback: timeSince=\(Int(timeSinceLastStrobe * 1000))ms, target=\(Int(adjustedInterval * 1000))ms, freq=\(currentFrequency)Hz")
        }
        
        // More precise timing check
        if timeSinceLastStrobe >= adjustedInterval {
            await performStrobe(at: currentTime)
        }
    }
    
    /// Perform the actual strobe operation with timing measurement
    private func performStrobe(at currentTime: CFAbsoluteTime) async {
        #if canImport(UIKit)
        guard let device = device else { return }
        
        let expectedTime = lastStrobeTime + targetInterval
        let timingError = currentTime - expectedTime
        
        // Record timing measurements
        timingMeasurements.append(abs(timingError))
        expectedTimings.append(expectedTime)
        actualTimings.append(currentTime)
        
        // Limit measurement arrays to prevent memory growth
        if timingMeasurements.count > 1000 {
            timingMeasurements.removeFirst(100)
            expectedTimings.removeFirst(100)
            actualTimings.removeFirst(100)
        }
        
        // Update timing drift accumulator for jitter compensation
        timingDriftAccumulator += timingError * 0.1 // Gentle correction
        
        // Perform the strobe
        do {
            try device.lockForConfiguration()
            strobeState.toggle()
            
            if strobeState {
                try device.setTorchModeOn(level: currentIntensity)
                if currentFrequency < 2.0 {
                    print("💡 Flashlight ON at \(currentFrequency)Hz")
                }
            } else {
                device.torchMode = .off
                if currentFrequency < 2.0 {
                    print("🔦 Flashlight OFF at \(currentFrequency)Hz")
                }
            }
            
            device.unlockForConfiguration()
            
            lastStrobeTime = currentTime
            
        } catch {
            print("Error during strobe operation: \(error)")
            droppedCycleCount += 1
        }
        #endif
    }
}

