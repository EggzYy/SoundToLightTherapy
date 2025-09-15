#if canImport(Accelerate)
import Accelerate
#endif
import Foundation

public actor FrequencyDetector {
    private let sampleRate: Double
    private let fftSize: Int
    private let therapeuticRange: ClosedRange<Double> = 2.0...40.0

    // Advanced frequency analysis with overlapping windows
    private var recentSpectrum: [Float] = []
    private var recentDominantFreqs: [Float] = []
    private var recentMappedFreqs: [Float] = []
    private var windowHistory: [[Float]] = []
    private let historySize: Int = 10
    private let smoothingBufferSize: Int = 3
    
    // Overlapping window analysis
    private let overlapFactor: Float = 0.5  // 50% overlap
    private var audioBuffer: [Float] = []
    private var previousWindow: [Float] = []
    private var spectralPeaks: [SpectralPeak] = []
    private var smoothedSpectrum: [Float] = []
    
    // Noise floor detection and filtering (user-configurable)
    private var noiseFloor: Float = 0.0
    private var noiseFloorHistory: [Float] = []
    private var silenceCounter: Int = 0
    private let maxSilenceFrames: Int = 5
    
    // User-configurable settings
    private var isNoiseFloorCalibrationEnabled: Bool = true
    private var isAmbientSoundFilteringEnabled: Bool = true
    private var adaptiveThresholdEnabled: Bool = true
    private var environmentalSensitivity: Float = 1.0 // 0.5 = less sensitive, 2.0 = more sensitive
    
    // Advanced windowing
    private var hanningWindow: [Float] = []
    private var blackmanWindow: [Float] = []
    private var hammingWindow: [Float] = []

    // FFT setup
    #if canImport(Accelerate)
    private let fftSetup: FFTSetup?
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudeBuffer: [Float]
    private var previousMagnitudeBuffer: [Float]
    #endif
    
    // Spectral peak tracking
    private struct SpectralPeak: Sendable {
        let frequency: Float
        let magnitude: Float
        let bin: Int
        let confidence: Float
        let timestamp: TimeInterval
    }
    
    // Frequency smoothing
    private struct FrequencyTracker: Sendable {
        var frequency: Float
        var confidence: Float
        var stability: Float
        var lastUpdate: TimeInterval
    }
    
    private var frequencyTracker: FrequencyTracker?
    
    // Therapeutic frequency mapping
    private let therapeuticMapper = TherapeuticFrequencyMapper()
    private var currentTherapyTypeOverride: TherapeuticFrequencyMapper.TherapyType? = nil

    public struct FrequencyDetectionConfiguration: Sendable {
        let sampleRate: Double
        let fftSize: Int
        let frequencyRange: ClosedRange<Double>

        public static let `default` = FrequencyDetectionConfiguration(
            sampleRate: 44100.0,
            fftSize: 1024,
            frequencyRange: 0.5...40.0
        )
    }

    public struct FrequencyResult: Sendable {
        public let therapeuticFrequency: Float  // Mapped to 2-40Hz range
        public let dominantFrequency: Float     // Original detected frequency
        public let tempoFrequency: Float        // Tempo-based frequency component
        public let spectralCentroid: Float     // Overall frequency "color"
        public let confidence: Float
        public let inputFrequencyRange: (min: Float, max: Float)
        public let therapeuticMapping: TherapeuticFrequencyMapper.TherapeuticMapping?  // Enhanced therapeutic analysis
    }

    public enum FrequencyDetectionError: Error {
        case invalidBuffer
        case fftSetupFailed
        case frequencyOutOfRange
        case unsupportedPlatform
        case lowConfidence
        case belowNoiseFloor
    }

    public init(configuration: FrequencyDetectionConfiguration = .default) {
        self.sampleRate = configuration.sampleRate
        self.fftSize = configuration.fftSize

        #if canImport(Accelerate)
        // Initialize FFT setup
        let log2Size = Int(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(vDSP_Length(log2Size), FFTRadix(kFFTRadix2))

        // Initialize buffers
        self.realBuffer = Array(repeating: 0.0, count: fftSize)
        self.imagBuffer = Array(repeating: 0.0, count: fftSize)
        self.magnitudeBuffer = Array(repeating: 0.0, count: fftSize / 2)
        self.previousMagnitudeBuffer = Array(repeating: 0.0, count: fftSize / 2)
        
        // Pre-compute window functions for better performance
        self.hanningWindow = Self.computeHanningWindow(size: fftSize)
        self.blackmanWindow = Self.computeBlackmanWindow(size: fftSize)
        self.hammingWindow = Self.computeHammingWindow(size: fftSize)
        
        // Initialize audio buffer for overlapping analysis
        self.audioBuffer = Array(repeating: 0.0, count: fftSize * 2)
        self.smoothedSpectrum = Array(repeating: 0.0, count: fftSize / 2)
        #else
        self.fftSetup = nil
        self.realBuffer = []
        self.imagBuffer = []
        self.magnitudeBuffer = []
        self.previousMagnitudeBuffer = []
        self.hanningWindow = []
        self.blackmanWindow = []
        self.hammingWindow = []
        self.audioBuffer = []
        self.smoothedSpectrum = []
        #endif

        print("✅ FrequencyDetector initialized - Sample rate: \(sampleRate), FFT size: \(fftSize)")
    }

    public func detectFrequency(from audioData: [Float]) async throws -> Float {
        let result = try await detectFrequencyWithConfidence(from: audioData)
        return result.therapeuticFrequency
    }

    public func detectFrequencyWithConfidence(from audioData: [Float]) async throws -> FrequencyResult {
        print("🎵 FrequencyDetector processing \(audioData.count) audio samples...")

        // Input validation
        guard !audioData.isEmpty else {
            print("❌ FrequencyDetector: Empty audio buffer")
            throw FrequencyDetectionError.invalidBuffer
        }

        // Check for silence or very low signal first - made less sensitive
        let rmsLevel = calculateRMS(audioData)
        let isLowSignal = rmsLevel < 0.0001 // Much lower RMS threshold (was 0.001)
        
        if isLowSignal {
            silenceCounter += 1
            print("🔇 Very low signal detected (RMS: \(rmsLevel)) - silence count: \(silenceCounter)")
            
            if silenceCounter >= maxSilenceFrames && isAmbientSoundFilteringEnabled {
                // Return low confidence result for sustained silence (if filtering enabled)
                throw FrequencyDetectionError.belowNoiseFloor
            }
        } else {
            silenceCounter = 0 // Reset silence counter on good signal
        }

        // Perform comprehensive frequency analysis
        let analysis = try performAdvancedFrequencyAnalysis(audioData)
        
        // Update noise floor estimation (if enabled)
        if isNoiseFloorCalibrationEnabled {
            updateNoiseFloor(analysis.spectrum)
        }
        
        // Filter out high-frequency noise (above 8000 Hz is likely electrical noise)
        let maxValidFrequency: Float = 8000.0
        var filteredAnalysis = analysis
        
        if analysis.dominantFrequency > maxValidFrequency {
            print("⚠️ Filtering high-frequency noise: \(analysis.dominantFrequency)Hz > \(maxValidFrequency)Hz")
            // Find the strongest peak below the threshold
            filteredAnalysis = findValidFrequencyPeak(analysis, maxFrequency: maxValidFrequency)
        }
        
        // Additional confidence check against noise floor - adjustable based on environmental sensitivity
        let confidenceThreshold = adaptiveThresholdEnabled ? (0.05 / environmentalSensitivity) : 0.05
        if filteredAnalysis.confidence < confidenceThreshold && isAmbientSoundFilteringEnabled {
            print("⚠️ Very low confidence signal: \(filteredAnalysis.confidence) (threshold: \(confidenceThreshold))")
            throw FrequencyDetectionError.lowConfidence
        }

        // Enhanced therapeutic mapping with harmonic analysis
        let therapeuticMapping = await therapeuticMapper.mapToTherapeutic(
            frequency: filteredAnalysis.dominantFrequency,
            confidence: filteredAnalysis.confidence,
            overrideTherapyType: currentTherapyTypeOverride
        )
        
        // Use the enhanced therapeutic frequency
        let therapeuticFreq = therapeuticMapping.therapeuticFrequency

        // Calculate tempo-based frequency from historical data
        let tempoFreq = calculateTempoFrequency(filteredAnalysis.dominantFrequency)

        let result = FrequencyResult(
            therapeuticFrequency: therapeuticFreq,
            dominantFrequency: filteredAnalysis.dominantFrequency,
            tempoFrequency: tempoFreq,
            spectralCentroid: filteredAnalysis.spectralCentroid,
            confidence: filteredAnalysis.confidence,
            inputFrequencyRange: filteredAnalysis.inputRange,
            therapeuticMapping: therapeuticMapping
        )

        // Enhanced logging with therapeutic information
        if let mapping = result.therapeuticMapping {
            let noteInfo = "\(mapping.harmonicAnalysis.closestNote.rawValue)\(mapping.harmonicAnalysis.octave)"
            let therapyType = mapping.therapyType.rawValue
            let harmonicInfo = mapping.harmonicAnalysis.isHarmonic ? " (Harmonic)" : ""
            
            print("🔊 Input: \(result.dominantFrequency)Hz → Therapeutic: \(result.therapeuticFrequency)Hz")
            print("🎵 Musical: \(noteInfo)\(harmonicInfo) | Therapy: \(therapyType) | Confidence: \(result.confidence)")
        } else {
            print("🔊 Input: \(result.dominantFrequency)Hz → Therapeutic: \(result.therapeuticFrequency)Hz (Confidence: \(result.confidence))")
        }
        
        return result
    }

    // MARK: - Advanced Frequency Analysis

    private struct AnalysisResult {
        let dominantFrequency: Float
        let spectralCentroid: Float
        let confidence: Float
        let inputRange: (min: Float, max: Float)
        let spectrum: [Float]
    }

    private func performAdvancedFrequencyAnalysis(_ audioData: [Float]) throws -> AnalysisResult {
        #if canImport(Accelerate)
        guard let fftSetup = fftSetup else {
            throw FrequencyDetectionError.fftSetupFailed
        }

        // Update audio buffer with overlapping windows
        let overlapSize = Int(Float(fftSize) * overlapFactor)
        let newDataSize = min(audioData.count, fftSize - overlapSize)
        
        // Shift existing data for overlap
        if audioBuffer.count >= fftSize {
            for i in 0..<overlapSize {
                audioBuffer[i] = audioBuffer[i + newDataSize]
            }
        }
        
        // Add new audio data
        let startIndex = max(0, overlapSize)
        let endIndex = min(audioBuffer.count, startIndex + newDataSize)
        for i in 0..<min(newDataSize, endIndex - startIndex) {
            if i < audioData.count && startIndex + i < audioBuffer.count {
                audioBuffer[startIndex + i] = audioData[i]
            }
        }
        
        // Perform multiple overlapping FFT analyses for better frequency resolution
        let numWindows = 3
        var combinedSpectrum = Array(repeating: Float(0.0), count: fftSize / 2)
        
        for windowIndex in 0..<numWindows {
            let windowOffset = windowIndex * (fftSize / (numWindows + 1))
            let windowEnd = min(windowOffset + fftSize, audioBuffer.count)
            let windowSize = windowEnd - windowOffset
            
            guard windowSize >= fftSize / 2 else { continue }
            
            // Extract window data
            var windowData = Array(audioBuffer[windowOffset..<min(windowOffset + fftSize, audioBuffer.count)])
            
            // Pad if necessary
            while windowData.count < fftSize {
                windowData.append(0.0)
            }
            
            // Apply advanced windowing (use Blackman for better frequency resolution)
            applyWindow(&windowData, window: blackmanWindow)
            
            // Perform FFT
            let spectrum = try performSingleFFT(windowData, fftSetup: fftSetup)
            
            // Accumulate spectra with weighting
            let weight = Float(1.0) / Float(numWindows)
            for i in 0..<spectrum.count {
                combinedSpectrum[i] += spectrum[i] * weight
            }
        }
        
        // Apply spectral smoothing
        smoothedSpectrum = applySpectralSmoothing(combinedSpectrum)
        
        // Track spectral peaks across frames
        updateSpectralPeaks(smoothedSpectrum)
        
        // Find dominant frequency using peak tracking
        let analysis = analyzeSpectrumWithPeakTracking(smoothedSpectrum)
        
        // Store for tempo analysis and frequency smoothing
        storeFrequencyHistory(analysis.dominantFrequency)
        updateFrequencyTracker(analysis)
        
        return analysis

        #else
        // Fallback for platforms without Accelerate
        return AnalysisResult(
            dominantFrequency: 440.0,
            spectralCentroid: 440.0,
            confidence: 0.5,
            inputRange: (min: 100.0, max: 1000.0),
            spectrum: []
        )
        #endif
    }
    
    #if canImport(Accelerate)
    private func performSingleFFT(_ windowData: [Float], fftSetup: FFTSetup) throws -> [Float] {
        // Copy to real buffer, clear imaginary
        realBuffer = windowData
        imagBuffer = Array(repeating: 0.0, count: fftSize)
        
        // Perform FFT using proper buffer pointer management
        let log2Size = Int(log2(Float(fftSize)))
        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &splitComplex, 1, vDSP_Length(log2Size), FFTDirection(FFT_FORWARD))
            }
        }
        
        // Calculate magnitude spectrum
        let halfSize = fftSize / 2
        var spectrum = Array(repeating: Float(0.0), count: halfSize)
        
        for i in 0..<halfSize {
            let real = realBuffer[i]
            let imag = imagBuffer[i]
            spectrum[i] = sqrt(real * real + imag * imag)
        }
        
        return spectrum
    }
    #endif
    
    private func applySpectralSmoothing(_ spectrum: [Float]) -> [Float] {
        var smoothed = spectrum
        let smoothingKernel: [Float] = [0.25, 0.5, 0.25] // Simple 3-point smoothing
        
        for i in 1..<(spectrum.count - 1) {
            smoothed[i] = spectrum[i-1] * smoothingKernel[0] +
                         spectrum[i] * smoothingKernel[1] +
                         spectrum[i+1] * smoothingKernel[2]
        }
        
        return smoothed
    }
    
    private func updateSpectralPeaks(_ spectrum: [Float]) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        var newPeaks: [SpectralPeak] = []
        let frequencyResolution = Float(sampleRate) / Float(fftSize)
        
        // Find local maxima in spectrum
        for i in 2..<(spectrum.count - 2) {
            let magnitude = spectrum[i]
            
            // Check if this is a local maximum
            if magnitude > spectrum[i-1] && magnitude > spectrum[i+1] &&
               magnitude > spectrum[i-2] && magnitude > spectrum[i+2] {
                
                let frequency = Float(i) * frequencyResolution
                let confidence = calculatePeakConfidence(spectrum, peakIndex: i)
                
                let peak = SpectralPeak(
                    frequency: frequency,
                    magnitude: magnitude,
                    bin: i,
                    confidence: confidence,
                    timestamp: currentTime
                )
                
                newPeaks.append(peak)
            }
        }
        
        // Sort by magnitude and keep top peaks
        newPeaks.sort { $0.magnitude > $1.magnitude }
        spectralPeaks = Array(newPeaks.prefix(10)) // Keep top 10 peaks
    }
    
    private func calculatePeakConfidence(_ spectrum: [Float], peakIndex: Int) -> Float {
        let peakMagnitude = spectrum[peakIndex]
        
        // Calculate local noise floor around the peak
        let windowSize = 5
        let startIndex = max(0, peakIndex - windowSize)
        let endIndex = min(spectrum.count, peakIndex + windowSize + 1)
        
        var localSum: Float = 0
        var count = 0
        
        for i in startIndex..<endIndex {
            if i != peakIndex {
                localSum += spectrum[i]
                count += 1
            }
        }
        
        let localAverage = count > 0 ? localSum / Float(count) : 0.001
        let snr = peakMagnitude / (localAverage + 0.001)
        
        return min(1.0, snr / 10.0) // Normalize SNR to 0-1 range (was 20.0, now 10.0 for higher confidence)
    }

    // MARK: - Window Functions
    
    private static func computeHanningWindow(size: Int) -> [Float] {
        var window = Array<Float>(repeating: 0.0, count: size)
        for i in 0..<size {
            window[i] = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(size - 1)))
        }
        return window
    }
    
    private static func computeBlackmanWindow(size: Int) -> [Float] {
        var window = Array<Float>(repeating: 0.0, count: size)
        for i in 0..<size {
            let n = Float(i) / Float(size - 1)
            window[i] = 0.42 - 0.5 * cos(2.0 * Float.pi * n) + 0.08 * cos(4.0 * Float.pi * n)
        }
        return window
    }
    
    private static func computeHammingWindow(size: Int) -> [Float] {
        var window = Array<Float>(repeating: 0.0, count: size)
        for i in 0..<size {
            window[i] = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(size - 1))
        }
        return window
    }
    
    private func applyWindow(_ data: inout [Float], window: [Float]) {
        guard data.count == window.count else { return }
        for i in 0..<data.count {
            data[i] *= window[i]
        }
    }
    
    private func applyHanningWindow(_ data: inout [Float]) {
        applyWindow(&data, window: hanningWindow)
    }

    private func analyzeSpectrumWithPeakTracking(_ magnitude: [Float]) -> AnalysisResult {
        let halfSize = magnitude.count
        let frequencyResolution = Float(sampleRate) / Float(fftSize)

        // Use tracked peaks for more stable frequency detection
        var dominantFreq: Float = 0
        var maxConfidence: Float = 0
        var bestPeakMagnitude: Float = 0
        
        if !spectralPeaks.isEmpty {
            // Find the most confident peak
            for peak in spectralPeaks {
                if peak.confidence > maxConfidence {
                    maxConfidence = peak.confidence
                    dominantFreq = peak.frequency
                    bestPeakMagnitude = peak.magnitude
                }
            }
        }
        
        // Fallback to traditional peak finding if no tracked peaks
        if dominantFreq == 0 {
            var maxMagnitude: Float = 0
            var peakIndex = 0

            for i in 1..<halfSize {  // Skip DC component
                if magnitude[i] > maxMagnitude {
                    maxMagnitude = magnitude[i]
                    peakIndex = i
                }
            }
            
            dominantFreq = Float(peakIndex) * frequencyResolution
            bestPeakMagnitude = maxMagnitude
        }

        // Apply frequency smoothing using tracker
        if let tracker = frequencyTracker {
            let timeDiff = CFAbsoluteTimeGetCurrent() - tracker.lastUpdate
            let maxFreqChange = Float(50.0 * timeDiff) // Max 50Hz/second change
            
            // Limit frequency jumps for smoother tracking
            let frequencyDiff = abs(dominantFreq - tracker.frequency)
            if frequencyDiff > maxFreqChange && tracker.confidence > 0.5 {
                // Gradually move toward new frequency
                let blendFactor = min(1.0, maxFreqChange / frequencyDiff)
                dominantFreq = tracker.frequency + (dominantFreq - tracker.frequency) * blendFactor
            }
        }

        // Calculate spectral centroid (frequency "center of mass")
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0

        for i in 1..<halfSize {
            let freq = Float(i) * frequencyResolution
            let mag = magnitude[i]
            weightedSum += freq * mag
            totalMagnitude += mag
        }

        let spectralCentroid = totalMagnitude > 0 ? weightedSum / totalMagnitude : dominantFreq

        // Find frequency range (where magnitude is above 10% of peak)
        let threshold = bestPeakMagnitude * 0.1
        var minFreqIndex = halfSize
        var maxFreqIndex = 0

        for i in 1..<halfSize {
            if magnitude[i] > threshold {
                minFreqIndex = min(minFreqIndex, i)
                maxFreqIndex = max(maxFreqIndex, i)
            }
        }

        let minFreq = Float(minFreqIndex) * frequencyResolution
        let maxFreq = Float(maxFreqIndex) * frequencyResolution

        // Enhanced confidence calculation using peak tracking and stability
        var confidence = maxConfidence
        
        // Boost confidence for stable frequencies
        if let tracker = frequencyTracker {
            let stabilityBonus = tracker.stability * 0.3
            confidence = min(1.0, confidence + stabilityBonus)
        }
        
        // Require minimum signal strength to avoid noise - made more lenient
        let minimumSignalThreshold: Float = 0.001 // Lowered from 0.01 to 0.001
        let signalStrength = bestPeakMagnitude
        
        // Reduce confidence if signal is too weak - but less aggressively
        if signalStrength < minimumSignalThreshold {
            confidence *= (signalStrength / minimumSignalThreshold) * 0.5 // Less aggressive reduction
        }
        
        // Calculate peak prominence for additional confidence
        let avgMagnitude = magnitude[1..<halfSize].reduce(0, +) / Float(halfSize - 1)
        let peakProminence = bestPeakMagnitude / (avgMagnitude + 0.001)
        
        // Boost confidence for clear, prominent signals - made less strict
        if peakProminence > 5.0 && signalStrength > minimumSignalThreshold {
            confidence = min(1.0, confidence * 1.2) // Bigger boost for valid signals
        }

        return AnalysisResult(
            dominantFrequency: dominantFreq,
            spectralCentroid: spectralCentroid,
            confidence: confidence,
            inputRange: (min: minFreq, max: maxFreq),
            spectrum: magnitude
        )
    }
    
    private func updateFrequencyTracker(_ analysis: AnalysisResult) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        if var tracker = frequencyTracker {
            let timeDiff = currentTime - tracker.lastUpdate
            let frequencyDiff = abs(analysis.dominantFrequency - tracker.frequency)
            
            // Update stability based on frequency consistency
            let stabilityDecay: Float = 0.95
            let stabilityGain: Float = frequencyDiff < 2.0 ? 0.1 : -0.2
            
            tracker.stability = max(0.0, min(1.0, tracker.stability * stabilityDecay + stabilityGain))
            
            // Update frequency with smoothing
            let smoothingFactor: Float = min(1.0, Float(timeDiff) * 5.0) // Adapt to timing
            tracker.frequency = tracker.frequency * (1.0 - smoothingFactor) + analysis.dominantFrequency * smoothingFactor
            tracker.confidence = analysis.confidence
            tracker.lastUpdate = currentTime
            
            self.frequencyTracker = tracker
        } else {
            // Initialize tracker
            self.frequencyTracker = FrequencyTracker(
                frequency: analysis.dominantFrequency,
                confidence: analysis.confidence,
                stability: 0.5,
                lastUpdate: currentTime
            )
        }
    }

    // MARK: - Frequency Mapping and Tempo Detection

    private func mapToTherapeuticRange(dominant: Float, range: (min: Float, max: Float)) -> Float {
        // Map any input frequency range to therapeutic 2-40Hz range
        let inputRange = range.max - range.min
        let therapeuticMin: Float = 2.0
        let therapeuticMax: Float = 40.0
        let therapeuticRange = therapeuticMax - therapeuticMin

        // Avoid division by zero
        guard inputRange > 0 else {
            return (therapeuticMin + therapeuticMax) / 2.0  // Return middle of therapeutic range
        }

        // Normalize the dominant frequency within input range (0-1)
        let normalizedPosition = (dominant - range.min) / inputRange

        // Map to therapeutic range
        let therapeuticFreq = therapeuticMin + (normalizedPosition * therapeuticRange)

        // Ensure result is within bounds
        let clampedFreq = max(therapeuticMin, min(therapeuticMax, therapeuticFreq))

        print("📊 Mapping: \(dominant)Hz (range: \(range.min)-\(range.max)Hz) → \(clampedFreq)Hz")
        return clampedFreq
    }

    private func storeFrequencyHistory(_ frequency: Float) {
        recentDominantFreqs.append(frequency)

        // Keep history size manageable
        if recentDominantFreqs.count > historySize {
            recentDominantFreqs.removeFirst()
        }
    }

    private func calculateTempoFrequency(_ currentFreq: Float) -> Float {
        guard recentDominantFreqs.count > 3 else {
            return currentFreq  // Not enough history for tempo analysis
        }

        // Analyze sinusoidal movement of frequency over time
        let windowSize = min(5, recentDominantFreqs.count)
        let recentWindow = Array(recentDominantFreqs.suffix(windowSize))

        // Calculate frequency modulation rate (tempo)
        var modulationEvents = 0
        var lastTrend = 0  // -1 = decreasing, 0 = stable, 1 = increasing

        for i in 1..<recentWindow.count {
            let diff = recentWindow[i] - recentWindow[i-1]
            let currentTrend = diff > 1.0 ? 1 : (diff < -1.0 ? -1 : 0)

            // Count trend reversals (tempo beats)
            if currentTrend != 0 && lastTrend != 0 && currentTrend != lastTrend {
                modulationEvents += 1
            }
            lastTrend = currentTrend
        }

        // Convert modulation events to frequency
        // Each pair of trend reversals = 1 complete cycle
        let windowDuration = Float(windowSize) * 0.1  // Assuming ~100ms per sample
        let tempoFreq = Float(modulationEvents) / (windowDuration * 2.0)  // *2 for full cycle

        // Map tempo to therapeutic range (2-10Hz for tempo effects)
        let clampedTempo = max(2.0, min(10.0, tempoFreq))

        print("🎵 Tempo analysis: \(modulationEvents) events → \(clampedTempo)Hz")
        return clampedTempo
    }
    
    // MARK: - Therapeutic Analysis
    
    /// Get therapeutic recommendations for the current frequency
    public func getTherapeuticRecommendations(for frequency: Float, confidence: Float = 1.0) async -> TherapeuticFrequencyMapper.TherapeuticMapping {
        return await therapeuticMapper.mapToTherapeutic(frequency: frequency, confidence: confidence, overrideTherapyType: currentTherapyTypeOverride)
    }
    
    /// Get all available therapy types
    public func getAvailableTherapyTypes() async -> [(TherapeuticFrequencyMapper.TherapyType, ClosedRange<Float>)] {
        return await therapeuticMapper.getAllTherapyTypes()
    }
    
    /// Check if frequency is within therapeutic range
    public func isTherapeuticFrequency(_ frequency: Float) async -> Bool {
        return await therapeuticMapper.isTherapeuticFrequency(frequency)
    }
    
    // MARK: - Noise Floor Detection and Signal Validation
    
    private func calculateRMS(_ audioData: [Float]) -> Float {
        guard !audioData.isEmpty else { return 0.0 }
        
        let sumOfSquares = audioData.reduce(0) { $0 + ($1 * $1) }
        return sqrt(sumOfSquares / Float(audioData.count))
    }
    
    private func updateNoiseFloor(_ spectrum: [Float]) {
        // Calculate noise floor as the median of the lower 25% of spectrum values
        let sortedSpectrum = spectrum.sorted()
        let lowerQuartileSize = spectrum.count / 4
        let lowerQuartile = Array(sortedSpectrum.prefix(lowerQuartileSize))
        
        let currentNoiseFloor = lowerQuartile.reduce(0, +) / Float(lowerQuartile.count)
        
        // Update noise floor with exponential smoothing
        if noiseFloor == 0.0 {
            noiseFloor = currentNoiseFloor
        } else {
            noiseFloor = noiseFloor * 0.9 + currentNoiseFloor * 0.1
        }
        
        // Keep history for trend analysis
        noiseFloorHistory.append(currentNoiseFloor)
        if noiseFloorHistory.count > 20 {
            noiseFloorHistory.removeFirst()
        }
    }
    
    private func findValidFrequencyPeak(_ analysis: AnalysisResult, maxFrequency: Float) -> AnalysisResult {
        let frequencyResolution = Float(sampleRate) / Float(fftSize)
        let maxBin = Int(maxFrequency / frequencyResolution)
        
        // Find the strongest peak below the frequency threshold
        var bestMagnitude: Float = 0
        var bestIndex = 0
        
        for i in 1..<min(maxBin, analysis.spectrum.count) {
            if analysis.spectrum[i] > bestMagnitude {
                bestMagnitude = analysis.spectrum[i]
                bestIndex = i
            }
        }
        
        let validFrequency = Float(bestIndex) * frequencyResolution
        
        // Recalculate confidence for the valid frequency
        let localConfidence = calculatePeakConfidence(analysis.spectrum, peakIndex: bestIndex)
        
        // If no valid peak found, return very low confidence
        if bestMagnitude < noiseFloor * 3.0 {
            return AnalysisResult(
                dominantFrequency: 0.0,
                spectralCentroid: analysis.spectralCentroid,
                confidence: 0.0,
                inputRange: analysis.inputRange,
                spectrum: analysis.spectrum
            )
        }
        
        return AnalysisResult(
            dominantFrequency: validFrequency,
            spectralCentroid: analysis.spectralCentroid,
            confidence: localConfidence,
            inputRange: analysis.inputRange,
            spectrum: analysis.spectrum
        )
    }
    
    /// Set therapy type override (nil to disable override)
    public func setTherapyTypeOverride(_ therapyType: TherapeuticFrequencyMapper.TherapyType?) async {
        currentTherapyTypeOverride = therapyType
        if let override = therapyType {
            print("🎯 Therapy type override set to: \(override.rawValue)")
        } else {
            print("🔄 Therapy type override disabled - using auto-detection")
        }
    }
    
    /// Get current therapy type override
    public func getCurrentTherapyTypeOverride() async -> TherapeuticFrequencyMapper.TherapyType? {
        return currentTherapyTypeOverride
    }
    
    // MARK: - Noise Floor and Filtering Configuration
    
    /// Enable or disable automatic noise floor calibration
    public func setNoiseFloorCalibration(enabled: Bool) async {
        print("🎛️ FrequencyDetector: setNoiseFloorCalibration called with enabled=\(enabled)")
        isNoiseFloorCalibrationEnabled = enabled
        if enabled {
            print("✅ Noise floor calibration enabled")
        } else {
            print("🔇 Noise floor calibration disabled")
            // Reset noise floor when disabled
            noiseFloor = 0.0
            noiseFloorHistory.removeAll()
        }
    }
    
    /// Enable or disable ambient sound filtering
    public func setAmbientSoundFiltering(enabled: Bool) async {
        isAmbientSoundFilteringEnabled = enabled
        if enabled {
            print("✅ Ambient sound filtering enabled")
        } else {
            print("🔇 Ambient sound filtering disabled")
        }
    }
    
    /// Enable or disable adaptive threshold adjustment
    public func setAdaptiveThreshold(enabled: Bool) async {
        adaptiveThresholdEnabled = enabled
        if enabled {
            print("✅ Adaptive threshold adjustment enabled")
        } else {
            print("🔇 Adaptive threshold adjustment disabled")
        }
    }
    
    /// Set environmental sensitivity (0.5 = less sensitive, 2.0 = more sensitive)
    public func setEnvironmentalSensitivity(_ sensitivity: Float) async {
        environmentalSensitivity = max(0.1, min(3.0, sensitivity))
        print("🎛️ Environmental sensitivity set to \(environmentalSensitivity)")
    }
    
    /// Get current noise floor detection settings
    public func getNoiseFloorSettings() async -> NoiseFloorSettings {
        return NoiseFloorSettings(
            calibrationEnabled: isNoiseFloorCalibrationEnabled,
            filteringEnabled: isAmbientSoundFilteringEnabled,
            adaptiveThresholdEnabled: adaptiveThresholdEnabled,
            environmentalSensitivity: environmentalSensitivity,
            currentNoiseFloor: noiseFloor,
            noiseFloorHistory: noiseFloorHistory
        )
    }
    
    /// Manually trigger noise floor calibration
    public func calibrateNoiseFloor() async {
        print("🔧 FrequencyDetector: calibrateNoiseFloor called")
        guard isNoiseFloorCalibrationEnabled else {
            print("⚠️ Noise floor calibration is disabled")
            return
        }
        
        print("🔧 Starting manual noise floor calibration...")
        noiseFloor = 0.0
        noiseFloorHistory.removeAll()
        silenceCounter = 0
        print("✅ Noise floor calibration reset - will recalibrate on next audio input")
    }
    
    /// Noise floor settings structure
    public struct NoiseFloorSettings: Sendable {
        public let calibrationEnabled: Bool
        public let filteringEnabled: Bool
        public let adaptiveThresholdEnabled: Bool
        public let environmentalSensitivity: Float
        public let currentNoiseFloor: Float
        public let noiseFloorHistory: [Float]
        
        public init(
            calibrationEnabled: Bool,
            filteringEnabled: Bool,
            adaptiveThresholdEnabled: Bool,
            environmentalSensitivity: Float,
            currentNoiseFloor: Float,
            noiseFloorHistory: [Float]
        ) {
            self.calibrationEnabled = calibrationEnabled
            self.filteringEnabled = filteringEnabled
            self.adaptiveThresholdEnabled = adaptiveThresholdEnabled
            self.environmentalSensitivity = environmentalSensitivity
            self.currentNoiseFloor = currentNoiseFloor
            self.noiseFloorHistory = noiseFloorHistory
        }
    }
}
