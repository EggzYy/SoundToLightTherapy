#if canImport(Accelerate)
import Accelerate
#endif
import Foundation

public actor FrequencyDetector {
    private let sampleRate: Double
    private let fftSize: Int
    private let therapeuticRange: ClosedRange<Double> = 2.0...40.0

    // Advanced frequency analysis
    private var recentSpectrum: [Float] = []
    private var recentDominantFreqs: [Float] = []
    private var recentMappedFreqs: [Float] = []
    private var windowHistory: [[Float]] = []
    private let historySize: Int = 10
    private let smoothingBufferSize: Int = 3

    // FFT setup
    #if canImport(Accelerate)
    private let fftSetup: FFTSetup?
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudeBuffer: [Float]
    #endif

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
        #else
        self.fftSetup = nil
        self.realBuffer = []
        self.imagBuffer = []
        self.magnitudeBuffer = []
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

        // Perform comprehensive frequency analysis
        let analysis = try performAdvancedFrequencyAnalysis(audioData)

        // Map detected frequency range to therapeutic range (2-40Hz)
        let therapeuticFreq = mapToTherapeuticRange(
            dominant: analysis.dominantFrequency,
            range: analysis.inputRange
        )

        // Calculate tempo-based frequency from historical data
        let tempoFreq = calculateTempoFrequency(analysis.dominantFrequency)

        let result = FrequencyResult(
            therapeuticFrequency: therapeuticFreq,
            dominantFrequency: analysis.dominantFrequency,
            tempoFrequency: tempoFreq,
            spectralCentroid: analysis.spectralCentroid,
            confidence: analysis.confidence,
            inputFrequencyRange: analysis.inputRange
        )

        print("🔊 Input: \(result.dominantFrequency)Hz → Therapeutic: \(result.therapeuticFrequency)Hz, Tempo: \(result.tempoFrequency)Hz")
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

        // Prepare audio data (pad or truncate to FFT size)
        var processedData = Array(audioData.prefix(fftSize))
        if processedData.count < fftSize {
            processedData.append(contentsOf: Array(repeating: 0.0, count: fftSize - processedData.count))
        }

        // Apply windowing to reduce spectral leakage
        applyHanningWindow(&processedData)

        // Copy to real buffer, clear imaginary
        realBuffer = processedData
        imagBuffer = Array(repeating: 0.0, count: fftSize)

        // Perform FFT
        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
        let log2Size = Int(log2(Float(fftSize)))
        vDSP_fft_zip(fftSetup, &splitComplex, 1, vDSP_Length(log2Size), FFTDirection(FFT_FORWARD))

        // Calculate magnitude spectrum
        let halfSize = fftSize / 2
        magnitudeBuffer = Array(repeating: 0.0, count: halfSize)

        for i in 0..<halfSize {
            let real = realBuffer[i]
            let imag = imagBuffer[i]
            magnitudeBuffer[i] = sqrt(real * real + imag * imag)
        }

        // Find dominant frequency and spectral properties
        let analysis = analyzeSpectrum(magnitudeBuffer)

        // Store for tempo analysis
        storeFrequencyHistory(analysis.dominantFrequency)

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

    private func applyHanningWindow(_ data: inout [Float]) {
        let size = data.count
        for i in 0..<size {
            let window = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(size - 1)))
            data[i] *= window
        }
    }

    private func analyzeSpectrum(_ magnitude: [Float]) -> AnalysisResult {
        let halfSize = magnitude.count
        let frequencyResolution = Float(sampleRate) / Float(fftSize)

        // Find peak frequency
        var maxMagnitude: Float = 0
        var peakIndex = 0

        for i in 1..<halfSize {  // Skip DC component
            if magnitude[i] > maxMagnitude {
                maxMagnitude = magnitude[i]
                peakIndex = i
            }
        }

        let dominantFreq = Float(peakIndex) * frequencyResolution

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
        let threshold = maxMagnitude * 0.1
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

        // Calculate confidence based on peak prominence
        let avgMagnitude = magnitude[1..<halfSize].reduce(0, +) / Float(halfSize - 1)
        let confidence = min(1.0, maxMagnitude / (avgMagnitude * 10.0))

        return AnalysisResult(
            dominantFrequency: dominantFreq,
            spectralCentroid: spectralCentroid,
            confidence: confidence,
            inputRange: (min: minFreq, max: maxFreq),
            spectrum: magnitude
        )
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
}
