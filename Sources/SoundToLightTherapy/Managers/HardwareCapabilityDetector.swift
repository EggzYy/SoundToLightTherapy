import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Hardware capability detection and performance benchmarking for therapeutic strobing
public actor HardwareCapabilityDetector {
    
    // MARK: - Types
    
    public struct HardwareCapabilities: Sendable {
        public let deviceModel: String
        public let maxAccurateFrequency: Float          // Highest frequency with >95% accuracy
        public let maxAttemptableFrequency: Float       // Highest frequency device can attempt
        public let recommendedFrequencyRanges: [ClosedRange<Float>]
        public let torchResponseTime: TimeInterval      // Average torch on/off response time
        public let batteryImpactFactor: Float          // Relative battery drain (1.0 = baseline)
        public let thermalLimitations: ThermalProfile
        public let calibrationFactors: [Float: Double] // Frequency-specific timing corrections
        public let benchmarkDate: Date
        
        public init(deviceModel: String, maxAccurateFrequency: Float, maxAttemptableFrequency: Float,
                   recommendedFrequencyRanges: [ClosedRange<Float>], torchResponseTime: TimeInterval,
                   batteryImpactFactor: Float, thermalLimitations: ThermalProfile,
                   calibrationFactors: [Float: Double], benchmarkDate: Date) {
            self.deviceModel = deviceModel
            self.maxAccurateFrequency = maxAccurateFrequency
            self.maxAttemptableFrequency = maxAttemptableFrequency
            self.recommendedFrequencyRanges = recommendedFrequencyRanges
            self.torchResponseTime = torchResponseTime
            self.batteryImpactFactor = batteryImpactFactor
            self.thermalLimitations = thermalLimitations
            self.calibrationFactors = calibrationFactors
            self.benchmarkDate = benchmarkDate
        }
    }
    
    public struct ThermalProfile: Sendable {
        public let maxContinuousFrequency: Float        // Max frequency for extended sessions
        public let thermalThrottleThreshold: Float      // Frequency to reduce when device heats up
        public let cooldownRecommendation: TimeInterval // Recommended break duration
        
        public init(maxContinuousFrequency: Float, thermalThrottleThreshold: Float, cooldownRecommendation: TimeInterval) {
            self.maxContinuousFrequency = maxContinuousFrequency
            self.thermalThrottleThreshold = thermalThrottleThreshold
            self.cooldownRecommendation = cooldownRecommendation
        }
    }
    
    public struct BenchmarkResult: Sendable {
        public let testFrequency: Float
        public let achievedAccuracy: Float              // Percentage accuracy (0-100)
        public let averageResponseTime: TimeInterval
        public let jitterMeasurement: TimeInterval
        public let sustainabilityScore: Float           // How well device sustains this frequency
        public let batteryDrainRate: Float             // Relative battery usage
        
        public init(testFrequency: Float, achievedAccuracy: Float, averageResponseTime: TimeInterval,
                   jitterMeasurement: TimeInterval, sustainabilityScore: Float, batteryDrainRate: Float) {
            self.testFrequency = testFrequency
            self.achievedAccuracy = achievedAccuracy
            self.averageResponseTime = averageResponseTime
            self.jitterMeasurement = jitterMeasurement
            self.sustainabilityScore = sustainabilityScore
            self.batteryDrainRate = batteryDrainRate
        }
    }
    
    public enum CapabilityError: Error {
        case benchmarkFailed
        case torchUnavailable
        case insufficientBatteryLevel
        case thermalThrottling
        case unsupportedDevice
    }
    
    // MARK: - Private Properties
    
    #if canImport(UIKit)
    private let device: AVCaptureDevice? = {
        guard let device = AVCaptureDevice.default(for: .video) else { return nil }
        return device
    }()
    #endif
    
    private var cachedCapabilities: HardwareCapabilities?
    private let benchmarkFrequencies: [Float] = [1.0, 5.0, 10.0, 20.0, 30.0, 40.0, 60.0, 80.0, 100.0]
    
    // Device-specific known capabilities (fallback data)
    private let knownDeviceCapabilities: [String: HardwareCapabilities] = [
        "iPhone15,2": HardwareCapabilities( // iPhone 14 Pro
            deviceModel: "iPhone 14 Pro",
            maxAccurateFrequency: 60.0,
            maxAttemptableFrequency: 100.0,
            recommendedFrequencyRanges: [1.0...40.0, 50.0...60.0],
            torchResponseTime: 0.002,
            batteryImpactFactor: 1.2,
            thermalLimitations: ThermalProfile(maxContinuousFrequency: 40.0, thermalThrottleThreshold: 50.0, cooldownRecommendation: 30.0),
            calibrationFactors: [10.0: 1.0, 20.0: 0.98, 40.0: 0.95, 60.0: 0.90],
            benchmarkDate: Date()
        ),
        "iPhone14,2": HardwareCapabilities( // iPhone 13 Pro
            deviceModel: "iPhone 13 Pro",
            maxAccurateFrequency: 50.0,
            maxAttemptableFrequency: 80.0,
            recommendedFrequencyRanges: [1.0...40.0],
            torchResponseTime: 0.003,
            batteryImpactFactor: 1.3,
            thermalLimitations: ThermalProfile(maxContinuousFrequency: 35.0, thermalThrottleThreshold: 45.0, cooldownRecommendation: 45.0),
            calibrationFactors: [10.0: 1.0, 20.0: 0.97, 40.0: 0.92],
            benchmarkDate: Date()
        )
    ]
    
    public init() {}
    
    // MARK: - Public Interface
    
    /// Get hardware capabilities for the current device
    /// Performs benchmarking if no cached data is available
    public func getHardwareCapabilities() async throws -> HardwareCapabilities {
        if let cached = cachedCapabilities {
            // Check if cached data is recent (within 24 hours)
            if Date().timeIntervalSince(cached.benchmarkDate) < 86400 {
                return cached
            }
        }
        
        // Perform fresh benchmark
        return try await performFullBenchmark()
    }
    
    /// Perform comprehensive hardware benchmarking
    public func performFullBenchmark() async throws -> HardwareCapabilities {
        #if canImport(UIKit)
        guard let device = device else {
            throw CapabilityError.torchUnavailable
        }
        
        guard device.hasTorch else {
            throw CapabilityError.torchUnavailable
        }
        
        // Check battery level before benchmarking
        let batteryLevel = await UIDevice.current.batteryLevel
        if batteryLevel < 0.3 && batteryLevel != -1.0 { // -1.0 means unknown
            throw CapabilityError.insufficientBatteryLevel
        }
        
        print("🔧 Starting hardware capability benchmark...")
        
        var benchmarkResults: [BenchmarkResult] = []
        var calibrationFactors: [Float: Double] = [:]
        
        // Test each frequency
        for frequency in benchmarkFrequencies {
            do {
                let result = try await benchmarkFrequency(frequency)
                benchmarkResults.append(result)
                
                // Calculate calibration factor
                let targetInterval = 1.0 / Double(frequency)
                let achievedInterval = 1.0 / Double(result.testFrequency)
                calibrationFactors[frequency] = targetInterval / achievedInterval
                
                print("📊 Frequency \(frequency)Hz: \(result.achievedAccuracy)% accuracy")
                
                // Brief pause between tests to prevent thermal buildup
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
            } catch {
                print("⚠️ Benchmark failed for \(frequency)Hz: \(error)")
                // Continue with other frequencies
            }
        }
        
        // Analyze results and determine capabilities
        let capabilities = analyzeResults(benchmarkResults, calibrationFactors: calibrationFactors)
        
        // Cache the results
        cachedCapabilities = capabilities
        
        print("✅ Hardware benchmark completed")
        print("📈 Max accurate frequency: \(capabilities.maxAccurateFrequency)Hz")
        print("🎯 Recommended ranges: \(capabilities.recommendedFrequencyRanges)")
        
        return capabilities
        
        #else
        throw CapabilityError.unsupportedDevice
        #endif
    }
    
    /// Get adaptive frequency limit based on current conditions
    public func getAdaptiveFrequencyLimit(requestedFrequency: Float, batteryLevel: Float, thermalState: ProcessInfo.ThermalState) async throws -> Float {
        let capabilities = try await getHardwareCapabilities()
        
        var adaptedFrequency = requestedFrequency
        
        // Apply hardware limitations
        adaptedFrequency = min(adaptedFrequency, capabilities.maxAccurateFrequency)
        
        // Apply battery-based limitations
        if batteryLevel < 0.2 {
            adaptedFrequency = min(adaptedFrequency, 20.0) // Conservative limit for low battery
        } else if batteryLevel < 0.5 {
            adaptedFrequency = min(adaptedFrequency, capabilities.maxAccurateFrequency * 0.8)
        }
        
        // Apply thermal limitations
        switch thermalState {
        case .critical:
            throw CapabilityError.thermalThrottling
        case .serious:
            adaptedFrequency = min(adaptedFrequency, capabilities.thermalLimitations.thermalThrottleThreshold * 0.5)
        case .fair:
            adaptedFrequency = min(adaptedFrequency, capabilities.thermalLimitations.thermalThrottleThreshold)
        case .nominal:
            // No additional thermal limitations
            break
        @unknown default:
            adaptedFrequency = min(adaptedFrequency, capabilities.thermalLimitations.maxContinuousFrequency)
        }
        
        return adaptedFrequency
    }
    
    /// Get fallback strategies for unsupported frequencies
    public func getFallbackStrategies(for frequency: Float) async throws -> [FallbackStrategy] {
        let capabilities = try await getHardwareCapabilities()
        var strategies: [FallbackStrategy] = []
        
        if frequency > capabilities.maxAccurateFrequency {
            // Frequency too high for accurate strobing
            strategies.append(.reduceToMaxAccurate(capabilities.maxAccurateFrequency))
            strategies.append(.harmonicDivision(frequency / 2.0))
            strategies.append(.hapticSupplement(frequency))
        }
        
        if frequency < 0.5 {
            // Frequency too low
            strategies.append(.increaseToMinimum(0.5))
            strategies.append(.harmonicMultiplication(frequency * 2.0))
        }
        
        // Check if frequency is in recommended ranges
        let inRecommendedRange = capabilities.recommendedFrequencyRanges.contains { range in
            range.contains(frequency)
        }
        
        if !inRecommendedRange {
            // Find nearest recommended frequency
            if let nearestRange = capabilities.recommendedFrequencyRanges.min(by: { range1, range2 in
                let dist1 = min(abs(frequency - range1.lowerBound), abs(frequency - range1.upperBound))
                let dist2 = min(abs(frequency - range2.lowerBound), abs(frequency - range2.upperBound))
                return dist1 < dist2
            }) {
                let nearestFreq = frequency < nearestRange.lowerBound ? nearestRange.lowerBound : nearestRange.upperBound
                strategies.append(.moveToRecommendedRange(nearestFreq))
            }
        }
        
        return strategies
    }
    
    /// Clear cached capabilities to force re-benchmarking
    public func clearCache() async {
        cachedCapabilities = nil
        print("🗑️ Hardware capability cache cleared")
    }
    
    // MARK: - Private Implementation
    
    /// Benchmark a specific frequency
    private func benchmarkFrequency(_ frequency: Float) async throws -> BenchmarkResult {
        #if canImport(UIKit)
        guard let device = device else {
            throw CapabilityError.torchUnavailable
        }
        
        let testDuration: TimeInterval = 2.0 // 2 seconds of testing
        let _ = Int(Double(frequency) * testDuration) // Expected cycles for reference
        
        var actualTimings: [TimeInterval] = []
        var responseTimings: [TimeInterval] = []
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var lastToggleTime = startTime
        var toggleState = false
        let targetInterval = 1.0 / (Double(frequency) * 2.0) // Half period for on/off
        
        // Configure torch
        try device.lockForConfiguration()
        device.torchMode = .off
        device.unlockForConfiguration()
        
        // Perform timed strobing test
        while CFAbsoluteTimeGetCurrent() - startTime < testDuration {
            let currentTime = CFAbsoluteTimeGetCurrent()
            
            if currentTime - lastToggleTime >= targetInterval {
                let toggleStartTime = CFAbsoluteTimeGetCurrent()
                
                // Toggle torch
                try device.lockForConfiguration()
                toggleState.toggle()
                
                if toggleState {
                    try device.setTorchModeOn(level: 1.0)
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
                
                let toggleEndTime = CFAbsoluteTimeGetCurrent()
                
                // Record timings
                actualTimings.append(currentTime - lastToggleTime)
                responseTimings.append(toggleEndTime - toggleStartTime)
                
                lastToggleTime = currentTime
            }
            
            // Small delay to prevent excessive CPU usage
            try await Task.sleep(nanoseconds: 100_000) // 0.1ms
        }
        
        // Turn off torch
        try device.lockForConfiguration()
        device.torchMode = .off
        device.unlockForConfiguration()
        
        // Analyze results
        let averageInterval = actualTimings.reduce(0, +) / Double(actualTimings.count)
        let achievedFrequency = 1.0 / (averageInterval * 2.0)
        let accuracyPercentage = Float(min(100.0, (1.0 - abs(Double(frequency) - achievedFrequency) / Double(frequency)) * 100.0))
        
        let averageResponseTime = responseTimings.reduce(0, +) / Double(responseTimings.count)
        
        // Calculate jitter
        let targetIntervalValue = targetInterval
        let jitterMeasurements = actualTimings.map { abs($0 - targetIntervalValue) }
        let averageJitter = jitterMeasurements.reduce(0, +) / Double(jitterMeasurements.count)
        
        // Calculate sustainability score based on consistency
        let intervalVariance = actualTimings.map { pow($0 - averageInterval, 2) }.reduce(0, +) / Double(actualTimings.count)
        let sustainabilityScore = Float(max(0.0, 100.0 - (intervalVariance * 10000.0))) // Scale variance to 0-100
        
        return BenchmarkResult(
            testFrequency: Float(achievedFrequency),
            achievedAccuracy: accuracyPercentage,
            averageResponseTime: averageResponseTime,
            jitterMeasurement: averageJitter,
            sustainabilityScore: sustainabilityScore,
            batteryDrainRate: 1.0 // Placeholder - would need longer test to measure
        )
        
        #else
        throw CapabilityError.unsupportedDevice
        #endif
    }
    
    /// Analyze benchmark results to determine hardware capabilities
    private func analyzeResults(_ results: [BenchmarkResult], calibrationFactors: [Float: Double]) -> HardwareCapabilities {
        let deviceModel = getDeviceModel()
        
        // Find maximum accurate frequency (>95% accuracy)
        let accurateResults = results.filter { $0.achievedAccuracy >= 95.0 }
        let maxAccurateFrequency = accurateResults.map { $0.testFrequency }.max() ?? 20.0
        
        // Find maximum attemptable frequency (>80% accuracy)
        let attemptableResults = results.filter { $0.achievedAccuracy >= 80.0 }
        let maxAttemptableFrequency = attemptableResults.map { $0.testFrequency }.max() ?? 40.0
        
        // Determine recommended frequency ranges
        var recommendedRanges: [ClosedRange<Float>] = []
        var rangeStart: Float?
        
        for result in results.sorted(by: { $0.testFrequency < $1.testFrequency }) {
            if result.achievedAccuracy >= 90.0 && result.sustainabilityScore >= 80.0 {
                if rangeStart == nil {
                    rangeStart = result.testFrequency
                }
            } else {
                if let start = rangeStart {
                    let previousResult = results.last { $0.testFrequency < result.testFrequency && $0.achievedAccuracy >= 90.0 }
                    let end = previousResult?.testFrequency ?? start
                    if end > start {
                        recommendedRanges.append(start...end)
                    }
                    rangeStart = nil
                }
            }
        }
        
        // Close final range if needed
        if let start = rangeStart {
            let lastGoodResult = results.last { $0.achievedAccuracy >= 90.0 }
            let end = lastGoodResult?.testFrequency ?? start
            recommendedRanges.append(start...end)
        }
        
        // Calculate average response time
        let averageResponseTime = results.map { $0.averageResponseTime }.reduce(0, +) / Double(results.count)
        
        // Determine thermal profile based on high-frequency performance
        let _ = results.filter { $0.testFrequency >= 40.0 } // High frequency results for reference
        let thermalProfile = ThermalProfile(
            maxContinuousFrequency: min(maxAccurateFrequency, 40.0),
            thermalThrottleThreshold: maxAccurateFrequency * 0.8,
            cooldownRecommendation: maxAccurateFrequency > 50.0 ? 60.0 : 30.0
        )
        
        return HardwareCapabilities(
            deviceModel: deviceModel,
            maxAccurateFrequency: maxAccurateFrequency,
            maxAttemptableFrequency: maxAttemptableFrequency,
            recommendedFrequencyRanges: recommendedRanges.isEmpty ? [1.0...20.0] : recommendedRanges,
            torchResponseTime: averageResponseTime,
            batteryImpactFactor: 1.0 + Float(maxAccurateFrequency / 100.0), // Higher frequencies = more battery usage
            thermalLimitations: thermalProfile,
            calibrationFactors: calibrationFactors,
            benchmarkDate: Date()
        )
    }
    
    /// Get device model identifier
    private func getDeviceModel() -> String {
        #if canImport(UIKit)
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingCString: ptr)
            }
        }
        return modelCode ?? "Unknown"
        #else
        return "Simulator"
        #endif
    }
}

// MARK: - Supporting Types

public enum FallbackStrategy: Sendable {
    case reduceToMaxAccurate(Float)
    case harmonicDivision(Float)
    case harmonicMultiplication(Float)
    case hapticSupplement(Float)
    case increaseToMinimum(Float)
    case moveToRecommendedRange(Float)
    
    public var description: String {
        switch self {
        case .reduceToMaxAccurate(let freq):
            return "Reduce to maximum accurate frequency: \(freq)Hz"
        case .harmonicDivision(let freq):
            return "Use harmonic division: \(freq)Hz"
        case .harmonicMultiplication(let freq):
            return "Use harmonic multiplication: \(freq)Hz"
        case .hapticSupplement(let freq):
            return "Supplement with haptic feedback at \(freq)Hz"
        case .increaseToMinimum(let freq):
            return "Increase to minimum frequency: \(freq)Hz"
        case .moveToRecommendedRange(let freq):
            return "Move to recommended frequency: \(freq)Hz"
        }
    }
}