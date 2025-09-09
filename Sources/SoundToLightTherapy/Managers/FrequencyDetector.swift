#if canImport(Accelerate)
    import Accelerate
#endif

public actor FrequencyDetector {
    #if canImport(Accelerate)
        private var fftSetup: vDSP.FFT<DSPSplitComplex>?
    #endif
    private let sampleRate: Double
    private let fftSize: Int
    private let frequencyRange: ClosedRange<Double>

    // Frequency smoothing and confidence tracking
    private var recentFrequencies: [Float] = []
    private let smoothingBufferSize: Int = 5
    private let confidenceThreshold: Float = 0.3
    private let noiseFloor: Float = 0.001

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
        public let frequency: Float
        public let confidence: Float
        public let isSmoothed: Bool
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
        self.frequencyRange = configuration.frequencyRange
    }

    #if canImport(Accelerate)
        private func setupFFT() {
            let log2n = vDSP_Length(log2(Double(fftSize)))
            guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)
            else {
                print("Error: Failed to setup FFT")
                return
            }
            fftSetup = fft
        }
    #endif

    public func detectFrequency(from audioData: [Float]) async throws -> Float {
        let result = try await detectFrequencyWithConfidence(from: audioData)
        return result.frequency
    }

    public func detectFrequencyWithConfidence(from audioData: [Float]) async throws
        -> FrequencyResult
    {
        #if canImport(Accelerate)
            if fftSetup == nil {
                setupFFT()
            }

            guard let fft = fftSetup else {
                throw FrequencyDetectionError.fftSetupFailed
            }

            guard audioData.count >= fftSize else {
                throw FrequencyDetectionError.invalidBuffer
            }

            // Apply Hanning window to reduce spectral leakage
            let windowedData = applyHanningWindow(to: audioData)

            // Perform FFT
            var realParts = [Float](repeating: 0, count: fftSize)
            var imagParts = [Float](repeating: 0, count: fftSize)

            // Use withUnsafeMutablePointer to ensure the pointers are valid during the FFT operation
            realParts.withUnsafeMutableBufferPointer { realBuffer in
                imagParts.withUnsafeMutableBufferPointer { imagBuffer in
                    windowedData.withUnsafeBufferPointer { windowBuffer in
                        var splitComplex = DSPSplitComplex(
                            realp: realBuffer.baseAddress!,
                            imagp: imagBuffer.baseAddress!
                        )
                        // Copy windowed data to real parts for FFT input
                        realBuffer.baseAddress?.update(
                            from: windowBuffer.baseAddress!, count: windowBuffer.count)
                        fft.forward(input: splitComplex, output: &splitComplex)
                    }
                }
            }

            // CRITICAL FIX: Calculate proper FFT magnitudes using sqrt(real² + imaginary²)
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<magnitudes.count {
                let real = realParts[i]
                let imag = imagParts[i]
                magnitudes[i] = sqrt(real * real + imag * imag)
            }

            // Apply noise filtering
            let filteredMagnitudes = applyNoiseFiltering(magnitudes: magnitudes)

            // Find peak frequency with confidence
            let (peakFrequency, confidence, maxMagnitude) = findPeakFrequencyWithConfidence(
                from: filteredMagnitudes)

            // Check if signal is above noise floor
            guard maxMagnitude > noiseFloor else {
                throw FrequencyDetectionError.belowNoiseFloor
            }

            // Check confidence threshold
            guard confidence >= confidenceThreshold else {
                throw FrequencyDetectionError.lowConfidence
            }

            // Validate frequency is within therapeutic range
            guard frequencyRange.contains(Double(peakFrequency)) else {
                throw FrequencyDetectionError.frequencyOutOfRange
            }

            // Apply frequency smoothing
            let smoothedFrequency = applyFrequencySmoothing(frequency: peakFrequency)
            let isSmoothed = abs(smoothedFrequency - peakFrequency) > 0.1

            let result = FrequencyResult(
                frequency: smoothedFrequency,
                confidence: confidence,
                isSmoothed: isSmoothed
            )

            print(
                "Detected frequency: \(result.frequency) Hz (confidence: \(result.confidence), smoothed: \(result.isSmoothed))"
            )
            return result
        #else
            print("Warning: Frequency detection not supported on this platform")
            throw FrequencyDetectionError.unsupportedPlatform
        #endif
    }

    #if canImport(Accelerate)
        private func applyHanningWindow(to data: [Float]) -> [Float] {
            var window = [Float](repeating: 0, count: data.count)
            vDSP_hann_window(&window, vDSP_Length(data.count), Int32(vDSP_HANN_NORM))

            var windowedData = [Float](repeating: 0, count: data.count)
            vDSP_vmul(data, 1, window, 1, &windowedData, 1, vDSP_Length(data.count))

            return windowedData
        }

        private func findPeakFrequency(from magnitudes: [Float]) -> Float {
            var maxMagnitude: Float = 0
            var peakIndex: vDSP_Length = 0

            vDSP_maxvi(magnitudes, 1, &maxMagnitude, &peakIndex, vDSP_Length(magnitudes.count))

            let frequency = Float(peakIndex) * Float(sampleRate) / Float(fftSize)
            return frequency
        }

        private func findPeakFrequencyWithConfidence(from magnitudes: [Float]) -> (
            frequency: Float, confidence: Float, maxMagnitude: Float
        ) {
            var maxMagnitude: Float = 0
            var peakIndex: vDSP_Length = 0

            vDSP_maxvi(magnitudes, 1, &maxMagnitude, &peakIndex, vDSP_Length(magnitudes.count))

            let frequency = Float(peakIndex) * Float(sampleRate) / Float(fftSize)

            // Calculate confidence based on peak-to-average ratio
            var totalMagnitude: Float = 0
            vDSP_sve(magnitudes, 1, &totalMagnitude, vDSP_Length(magnitudes.count))
            let averageMagnitude = totalMagnitude / Float(magnitudes.count)

            let confidence = maxMagnitude / (averageMagnitude + 0.001)  // Avoid division by zero
            let normalizedConfidence = min(1.0, confidence / 10.0)  // Normalize to 0-1 range

            return (frequency, normalizedConfidence, maxMagnitude)
        }

        private func applyNoiseFiltering(magnitudes: [Float]) -> [Float] {
            // Apply simple threshold-based noise filtering
            return magnitudes.map { magnitude in
                magnitude > noiseFloor ? magnitude : 0.0
            }
        }

        private func applyFrequencySmoothing(frequency: Float) -> Float {
            // Add current frequency to recent frequencies buffer
            recentFrequencies.append(frequency)

            // Keep only recent frequencies within buffer size
            if recentFrequencies.count > smoothingBufferSize {
                recentFrequencies.removeFirst()
            }

            // Return smoothed frequency (simple moving average)
            let sum = recentFrequencies.reduce(0, +)
            return sum / Float(recentFrequencies.count)
        }
    #endif
}
