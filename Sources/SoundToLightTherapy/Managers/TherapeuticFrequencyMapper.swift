import Foundation

/// Therapeutic frequency mapping system with harmonic detection based on A4 = 432Hz tuning
public actor TherapeuticFrequencyMapper {
    
    // MARK: - Types
    
    /// Brainwave frequency categories for therapeutic applications
    public enum TherapyType: String, CaseIterable, Sendable {
        case delta = "Delta"
        case theta = "Theta"
        case alpha = "Alpha"
        case beta = "Beta"
        case gamma = "Gamma"
        
        /// Frequency range for each therapy type (in Hz)
        public var frequencyRange: ClosedRange<Float> {
            switch self {
            case .delta:
                return 0.5...4.0    // Deep sleep, healing, regeneration
            case .theta:
                return 4.0...8.0    // Deep meditation, creativity, memory
            case .alpha:
                return 8.0...13.0   // Relaxation, focus, learning
            case .beta:
                return 13.0...30.0  // Active thinking, concentration
            case .gamma:
                return 30.0...100.0 // High-level cognitive processing
            }
        }
        
        /// Therapeutic benefits description
        public var benefits: String {
            switch self {
            case .delta:
                return "Deep sleep, healing, regeneration, immune system boost"
            case .theta:
                return "Deep meditation, creativity, memory consolidation, emotional healing"
            case .alpha:
                return "Relaxation, stress reduction, enhanced learning, mental clarity"
            case .beta:
                return "Active concentration, problem solving, analytical thinking"
            case .gamma:
                return "High-level awareness, cognitive enhancement, consciousness expansion"
            }
        }
        
        /// Recommended session duration
        public var recommendedDuration: TimeInterval {
            switch self {
            case .delta:
                return 20 * 60  // 20 minutes
            case .theta:
                return 15 * 60  // 15 minutes
            case .alpha:
                return 10 * 60  // 10 minutes
            case .beta:
                return 8 * 60   // 8 minutes
            case .gamma:
                return 5 * 60   // 5 minutes
            }
        }
    }
    
    /// Musical note representation for harmonic analysis
    public enum MusicalNote: String, CaseIterable, Sendable {
        case C, CSharp = "C#", D, DSharp = "D#", E, F, FSharp = "F#", G, GSharp = "G#", A, ASharp = "A#", B
        
        /// Semitone offset from A
        public var semitonesFromA: Int {
            switch self {
            case .C: return -9
            case .CSharp: return -8
            case .D: return -7
            case .DSharp: return -6
            case .E: return -5
            case .F: return -4
            case .FSharp: return -3
            case .G: return -2
            case .GSharp: return -1
            case .A: return 0
            case .ASharp: return 1
            case .B: return 2
            }
        }
    }
    
    /// Harmonic analysis result
    public struct HarmonicAnalysis: Sendable {
        public let fundamentalFrequency: Float
        public let closestNote: MusicalNote
        public let octave: Int
        public let centsDeviation: Float  // Deviation in cents from perfect pitch
        public let harmonicSeries: [Float]  // First 8 harmonics
        public let isHarmonic: Bool  // True if frequency is close to a harmonic
        public let harmonicConfidence: Float  // 0.0-1.0 confidence in harmonic detection
    }
    
    /// Therapeutic mapping result
    public struct TherapeuticMapping: Sendable {
        public let inputFrequency: Float
        public let therapeuticFrequency: Float
        public let therapyType: TherapyType
        public let harmonicAnalysis: HarmonicAnalysis
        public let mappingConfidence: Float
        public let recommendations: [String]
    }
    
    // MARK: - Constants
    
    /// A4 reference frequency (432Hz tuning instead of standard 440Hz)
    private let referenceA4: Float = 432.0
    
    /// Therapeutic frequency range
    private let therapeuticRange: ClosedRange<Float> = 0.5...100.0
    
    /// Harmonic detection tolerance (in cents)
    private let harmonicTolerance: Float = 50.0  // ±50 cents
    
    // MARK: - Public Interface
    
    public init() {
        print("✅ TherapeuticFrequencyMapper initialized with A4 = \(referenceA4)Hz")
    }
    
    /// Map input frequency to therapeutic frequency with harmonic analysis
    public func mapToTherapeutic(frequency: Float, confidence: Float = 1.0) async -> TherapeuticMapping {
        return await mapToTherapeutic(frequency: frequency, confidence: confidence, overrideTherapyType: nil)
    }
    
    /// Map input frequency to therapeutic frequency with optional therapy type override
    public func mapToTherapeutic(
        frequency: Float, 
        confidence: Float = 1.0, 
        overrideTherapyType: TherapyType? = nil
    ) async -> TherapeuticMapping {
        // Perform harmonic analysis first
        let harmonicAnalysis = analyzeHarmonics(frequency: frequency)
        
        // Use override therapy type if provided, otherwise determine from frequency
        let therapyType = overrideTherapyType ?? determineTherapyType(for: frequency)
        
        // Debug logging
        if let override = overrideTherapyType {
            print("🎯 Using therapy type override: \(override.rawValue) for \(frequency)Hz")
        } else {
            print("🔄 Auto-detected therapy type: \(therapyType.rawValue) for \(frequency)Hz")
        }
        
        // Map to therapeutic range with therapy type preference
        let therapeuticFreq = mapToTherapeuticRange(
            frequency: frequency,
            harmonicAnalysis: harmonicAnalysis,
            therapyType: therapyType
        )
        
        // Validate and clamp result to therapy type range
        let clampedTherapeuticFreq: Float
        if !therapyType.frequencyRange.contains(therapeuticFreq) {
            print("⚠️ WARNING: Therapeutic frequency \(therapeuticFreq)Hz is outside \(therapyType.rawValue) range \(therapyType.frequencyRange)")
            clampedTherapeuticFreq = max(therapyType.frequencyRange.lowerBound, 
                                       min(therapyType.frequencyRange.upperBound, therapeuticFreq))
            print("🔧 Clamped to: \(clampedTherapeuticFreq)Hz")
        } else {
            clampedTherapeuticFreq = therapeuticFreq
            print("✅ Therapeutic frequency \(therapeuticFreq)Hz is within \(therapyType.rawValue) range \(therapyType.frequencyRange)")
        }
        
        // Ensure frequency is never below the minimum supported by the strobe controller (0.5Hz)
        let finalTherapeuticFreq = max(0.5, clampedTherapeuticFreq)
        if finalTherapeuticFreq != clampedTherapeuticFreq {
            print("🔧 Adjusted frequency from \(clampedTherapeuticFreq)Hz to \(finalTherapeuticFreq)Hz (minimum 0.5Hz)")
        }
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            therapyType: therapyType,
            harmonicAnalysis: harmonicAnalysis,
            confidence: confidence,
            isOverride: overrideTherapyType != nil
        )
        
        // Calculate mapping confidence
        let mappingConfidence = calculateMappingConfidence(
            inputFrequency: frequency,
            harmonicAnalysis: harmonicAnalysis,
            inputConfidence: confidence
        )
        
        return TherapeuticMapping(
            inputFrequency: frequency,
            therapeuticFrequency: finalTherapeuticFreq,
            therapyType: therapyType,
            harmonicAnalysis: harmonicAnalysis,
            mappingConfidence: mappingConfidence,
            recommendations: recommendations
        )
    }
    
    /// Get therapy type for a specific frequency
    public func getTherapyType(for frequency: Float) async -> TherapyType {
        return determineTherapyType(for: frequency)
    }
    
    /// Get all available therapy types with their ranges
    public func getAllTherapyTypes() async -> [(TherapyType, ClosedRange<Float>)] {
        return TherapyType.allCases.map { ($0, $0.frequencyRange) }
    }
    
    /// Validate if frequency is within therapeutic range
    public func isTherapeuticFrequency(_ frequency: Float) async -> Bool {
        return therapeuticRange.contains(frequency)
    }
    
    // MARK: - Harmonic Analysis
    
    private func analyzeHarmonics(frequency: Float) -> HarmonicAnalysis {
        // Find the closest musical note
        let (closestNote, octave, centsDeviation) = findClosestNote(frequency: frequency)
        
        // Calculate fundamental frequency (closest note frequency)
        let fundamentalFreq = calculateNoteFrequency(note: closestNote, octave: octave)
        
        // Generate harmonic series
        let harmonicSeries = generateHarmonicSeries(fundamental: fundamentalFreq)
        
        // Check if input frequency is close to any harmonic
        let (isHarmonic, harmonicConfidence) = checkHarmonicMatch(
            frequency: frequency,
            harmonicSeries: harmonicSeries
        )
        
        return HarmonicAnalysis(
            fundamentalFrequency: fundamentalFreq,
            closestNote: closestNote,
            octave: octave,
            centsDeviation: centsDeviation,
            harmonicSeries: harmonicSeries,
            isHarmonic: isHarmonic,
            harmonicConfidence: harmonicConfidence
        )
    }
    
    private func findClosestNote(frequency: Float) -> (MusicalNote, Int, Float) {
        // Calculate semitones from A4 (432Hz)
        let semitonesFromA4 = 12.0 * log2(frequency / referenceA4)
        let roundedSemitones = round(semitonesFromA4)
        
        // Calculate octave (A4 is octave 4)
        let octave = 4 + Int(roundedSemitones / 12.0)
        
        // Calculate note within octave
        let noteIndex = Int(roundedSemitones.truncatingRemainder(dividingBy: 12))
        let adjustedNoteIndex = noteIndex >= 0 ? noteIndex : noteIndex + 12
        
        // Find the note (A is at index 0 in our semitone calculation)
        let noteFromA = MusicalNote.allCases.first { $0.semitonesFromA == adjustedNoteIndex - 9 }
        let closestNote = noteFromA ?? .A
        
        // Calculate cents deviation
        let exactNoteFreq = calculateNoteFrequency(note: closestNote, octave: octave)
        let centsDeviation = 1200.0 * log2(frequency / exactNoteFreq)
        
        return (closestNote, octave, centsDeviation)
    }
    
    private func calculateNoteFrequency(note: MusicalNote, octave: Int) -> Float {
        let semitonesFromA4 = note.semitonesFromA + (octave - 4) * 12
        return referenceA4 * pow(2.0, Float(semitonesFromA4) / 12.0)
    }
    
    private func generateHarmonicSeries(fundamental: Float) -> [Float] {
        return (1...8).map { harmonic in
            fundamental * Float(harmonic)
        }
    }
    
    private func checkHarmonicMatch(frequency: Float, harmonicSeries: [Float]) -> (Bool, Float) {
        var bestDeviation: Float = Float.infinity
        
        for harmonic in harmonicSeries {
            let deviation = abs(1200.0 * log2(frequency / harmonic)) // Deviation in cents
            if deviation < bestDeviation {
                bestDeviation = deviation
            }
        }
        
        let isHarmonic = bestDeviation <= harmonicTolerance
        let confidence = isHarmonic ? max(0.0, 1.0 - (bestDeviation / harmonicTolerance)) : 0.0
        
        return (isHarmonic, confidence)
    }
    
    // MARK: - Therapeutic Mapping
    
    private func determineTherapyType(for frequency: Float) -> TherapyType {
        // For input frequencies, we need to map them intelligently to therapy types
        // Most audio frequencies will be much higher than therapeutic ranges
        
        // If frequency is already in therapeutic range, find the matching type
        if therapeuticRange.contains(frequency) {
            for therapyType in TherapyType.allCases {
                if therapyType.frequencyRange.contains(frequency) {
                    return therapyType
                }
            }
        }
        
        // For higher frequencies, use intelligent mapping based on musical/harmonic content
        // Lower frequencies (20-200Hz) -> Delta/Theta (relaxation)
        // Mid frequencies (200-800Hz) -> Alpha (learning/focus)  
        // Higher frequencies (800-2000Hz) -> Beta (active thinking)
        // Very high frequencies (2000Hz+) -> Gamma (high cognition)
        
        if frequency < 200.0 {
            return .theta  // Low frequencies are naturally calming
        } else if frequency < 800.0 {
            return .alpha  // Mid frequencies good for focus
        } else if frequency < 2000.0 {
            return .beta   // Higher frequencies for active states
        } else {
            return .gamma  // Very high frequencies for peak performance
        }
    }
    
    private func mapToTherapeuticRange(
        frequency: Float,
        harmonicAnalysis: HarmonicAnalysis,
        therapyType: TherapyType
    ) -> Float {
        // If frequency is already in the specific therapy type range, return as-is
        if therapyType.frequencyRange.contains(frequency) {
            return frequency
        }
        
        // Try harmonic-based mapping first, with therapy type preference
        if harmonicAnalysis.isHarmonic && harmonicAnalysis.harmonicConfidence > 0.5 {
            return mapHarmonicToTherapeuticType(
                frequency: frequency,
                harmonicAnalysis: harmonicAnalysis,
                preferredTherapyType: therapyType
            )
        }
        
        // Fallback to proportional mapping within the specific therapy type range
        return mapProportionalToTherapyType(frequency: frequency, therapyType: therapyType)
    }
    
    private func mapHarmonicToTherapeutic(
        frequency: Float,
        harmonicAnalysis: HarmonicAnalysis
    ) -> Float {
        let fundamental = harmonicAnalysis.fundamentalFrequency
        
        // Generate extended harmonic series including sub-harmonics for therapeutic mapping
        let extendedHarmonics = generateExtendedHarmonicSeries(fundamental: fundamental)
        
        // Find the best harmonic that falls within therapeutic range
        let bestTherapeuticHarmonic = findBestTherapeuticHarmonic(
            harmonics: extendedHarmonics,
            targetRange: therapeuticRange
        )
        
        if let therapeuticHarmonic = bestTherapeuticHarmonic {
            print("🎵 Using harmonic \(therapeuticHarmonic.harmonicNumber) of \(fundamental)Hz: \(therapeuticHarmonic.frequency)Hz")
            return therapeuticHarmonic.frequency
        }
        
        // Fallback: use proportional mapping if no suitable harmonic found
        print("⚠️ No suitable harmonic found for \(fundamental)Hz, using proportional mapping")
        return mapToRange(
            value: fundamental,
            fromRange: 20.0...20000.0,  // Audible range
            toRange: therapeuticRange
        )
    }
    
    /// Generate extended harmonic series including sub-harmonics for therapeutic frequencies
    private func generateExtendedHarmonicSeries(fundamental: Float) -> [TherapeuticHarmonic] {
        var harmonics: [TherapeuticHarmonic] = []
        
        // Generate sub-harmonics (fundamental divided by integers) - these are the key for therapeutic frequencies
        for divisor in 1...64 {
            let subHarmonic = fundamental / Float(divisor)
            if subHarmonic >= therapeuticRange.lowerBound {
                harmonics.append(TherapeuticHarmonic(
                    frequency: subHarmonic,
                    harmonicNumber: -divisor, // Negative for sub-harmonics
                    fundamental: fundamental,
                    isSubHarmonic: true
                ))
            }
        }
        
        // Generate overtones (fundamental multiplied by integers) - rarely used for therapy but included for completeness
        for multiplier in 1...8 {
            let overtone = fundamental * Float(multiplier)
            if overtone <= therapeuticRange.upperBound {
                harmonics.append(TherapeuticHarmonic(
                    frequency: overtone,
                    harmonicNumber: multiplier,
                    fundamental: fundamental,
                    isSubHarmonic: false
                ))
            }
        }
        
        return harmonics.sorted { $0.frequency < $1.frequency }
    }
    
    /// Find the best harmonic that falls within the therapeutic range
    private func findBestTherapeuticHarmonic(
        harmonics: [TherapeuticHarmonic],
        targetRange: ClosedRange<Float>
    ) -> TherapeuticHarmonic? {
        
        // Filter harmonics within therapeutic range
        let validHarmonics = harmonics.filter { targetRange.contains($0.frequency) }
        
        guard !validHarmonics.isEmpty else { return nil }
        
        // Prefer sub-harmonics as they're more therapeutically relevant
        let subHarmonics = validHarmonics.filter { $0.isSubHarmonic }
        if !subHarmonics.isEmpty {
            // Choose the sub-harmonic closest to the middle of therapeutic range
            let targetFreq = (targetRange.lowerBound + targetRange.upperBound) / 2.0
            return subHarmonics.min { abs($0.frequency - targetFreq) < abs($1.frequency - targetFreq) }
        }
        
        // Fallback to any valid harmonic
        let targetFreq = (targetRange.lowerBound + targetRange.upperBound) / 2.0
        return validHarmonics.min { abs($0.frequency - targetFreq) < abs($1.frequency - targetFreq) }
    }
    
    /// Map harmonic frequency to specific therapy type range
    private func mapHarmonicToTherapeuticType(
        frequency: Float,
        harmonicAnalysis: HarmonicAnalysis,
        preferredTherapyType: TherapyType
    ) -> Float {
        let fundamental = harmonicAnalysis.fundamentalFrequency
        
        // Generate extended harmonic series
        let extendedHarmonics = generateExtendedHarmonicSeries(fundamental: fundamental)
        
        // First, try to find a harmonic within the preferred therapy type range
        let preferredRange = preferredTherapyType.frequencyRange
        if let preferredHarmonic = findBestTherapeuticHarmonic(
            harmonics: extendedHarmonics,
            targetRange: preferredRange
        ) {
            print("🎯 Found harmonic \(preferredHarmonic.harmonicNumber) for \(preferredTherapyType.rawValue): \(preferredHarmonic.frequency)Hz")
            return preferredHarmonic.frequency
        }
        
        // If no harmonic fits the preferred type, find the best harmonic in any therapeutic range
        if let anyTherapeuticHarmonic = findBestTherapeuticHarmonic(
            harmonics: extendedHarmonics,
            targetRange: therapeuticRange
        ) {
            print("🎵 Using best available harmonic \(anyTherapeuticHarmonic.harmonicNumber): \(anyTherapeuticHarmonic.frequency)Hz")
            // Scale to preferred therapy type range
            return scaleToTherapyTypeRange(anyTherapeuticHarmonic.frequency, therapyType: preferredTherapyType)
        }
        
        // Fallback: use proportional mapping
        print("⚠️ No suitable harmonic found, using proportional mapping to \(preferredTherapyType.rawValue)")
        return mapProportionalToTherapyType(frequency: frequency, therapyType: preferredTherapyType)
    }
    
    /// Represents a harmonic frequency with its relationship to the fundamental
    private struct TherapeuticHarmonic {
        let frequency: Float
        let harmonicNumber: Int  // Positive for overtones, negative for sub-harmonics
        let fundamental: Float
        let isSubHarmonic: Bool
    }
    
    private func mapProportionalToTherapyType(frequency: Float, therapyType: TherapyType) -> Float {
        // Map frequency to the specific therapy type range
        let therapyRange = therapyType.frequencyRange
        
        // Use logarithmic mapping for better frequency distribution
        let logFreq = log10(Double(frequency))
        let logMin = log10(20.0)  // Minimum audible frequency
        let logMax = log10(20000.0)  // Maximum audible frequency
        
        let normalizedPosition = Float((logFreq - logMin) / (logMax - logMin))
        let clampedPosition = max(0.0, min(1.0, normalizedPosition))
        
        let therapeuticFreq = therapyRange.lowerBound + 
                             (therapyRange.upperBound - therapyRange.lowerBound) * clampedPosition
        
        return therapeuticFreq
    }
    
    private func mapToRange(value: Float, fromRange: ClosedRange<Float>, toRange: ClosedRange<Float>) -> Float {
        let normalizedValue = (value - fromRange.lowerBound) / (fromRange.upperBound - fromRange.lowerBound)
        let clampedValue = max(0.0, min(1.0, normalizedValue))
        return toRange.lowerBound + (toRange.upperBound - toRange.lowerBound) * clampedValue
    }
    
    /// Scale a frequency to fit within a specific therapy type range
    private func scaleToTherapyTypeRange(_ frequency: Float, therapyType: TherapyType) -> Float {
        let therapyRange = therapyType.frequencyRange
        
        // If already in range, return as-is
        if therapyRange.contains(frequency) {
            return frequency
        }
        
        // Scale from therapeutic range to therapy type range
        return mapToRange(
            value: frequency,
            fromRange: therapeuticRange,
            toRange: therapyRange
        )
    }
    
    // MARK: - Recommendations and Confidence
    
    private func generateRecommendations(
        therapyType: TherapyType,
        harmonicAnalysis: HarmonicAnalysis,
        confidence: Float,
        isOverride: Bool = false
    ) -> [String] {
        var recommendations: [String] = []
        
        // Basic therapy type recommendation
        let typePrefix = isOverride ? "Manual Override: " : "Auto-Detected: "
        recommendations.append("\(typePrefix)\(therapyType.rawValue) (\(therapyType.benefits))")
        recommendations.append("Recommended Duration: \(Int(therapyType.recommendedDuration / 60)) minutes")
        
        // Harmonic-based recommendations
        if harmonicAnalysis.isHarmonic {
            recommendations.append("Harmonic frequency detected - enhanced therapeutic effect expected")
            recommendations.append("Musical note: \(harmonicAnalysis.closestNote.rawValue)\(harmonicAnalysis.octave)")
            
            if abs(harmonicAnalysis.centsDeviation) < 10 {
                recommendations.append("Excellent pitch accuracy - optimal therapeutic resonance")
            } else if abs(harmonicAnalysis.centsDeviation) < 30 {
                recommendations.append("Good pitch accuracy - effective therapeutic resonance")
            }
        }
        
        // Confidence-based recommendations
        if confidence > 0.8 {
            recommendations.append("High signal quality - stable therapeutic effect")
        } else if confidence > 0.5 {
            recommendations.append("Moderate signal quality - consider improving audio source")
        } else {
            recommendations.append("Low signal quality - may affect therapeutic effectiveness")
        }
        
        // Frequency-specific recommendations
        switch therapyType {
        case .delta:
            recommendations.append("Best used before sleep or during deep relaxation")
        case .theta:
            recommendations.append("Ideal for meditation, creativity sessions, or memory work")
        case .alpha:
            recommendations.append("Perfect for study sessions, stress relief, or light meditation")
        case .beta:
            recommendations.append("Use during work, problem-solving, or active concentration")
        case .gamma:
            recommendations.append("Short sessions recommended - powerful cognitive enhancement")
        }
        
        return recommendations
    }
    
    private func calculateMappingConfidence(
        inputFrequency: Float,
        harmonicAnalysis: HarmonicAnalysis,
        inputConfidence: Float
    ) -> Float {
        var confidence = inputConfidence
        
        // Boost confidence for harmonic frequencies
        if harmonicAnalysis.isHarmonic {
            confidence *= (1.0 + harmonicAnalysis.harmonicConfidence * 0.3)
        }
        
        // Boost confidence for frequencies already in therapeutic range
        if therapeuticRange.contains(inputFrequency) {
            confidence *= 1.2
        }
        
        // Reduce confidence for very high or very low frequencies
        if inputFrequency < 50.0 || inputFrequency > 8000.0 {
            confidence *= 0.8
        }
        
        return min(1.0, confidence)
    }
}