import Foundation

/// Session pattern data model with timed therapy type sequences
public struct SessionPattern: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let totalDuration: TimeInterval
    public let segments: [TherapySegment]
    public let createdAt: Date
    public let modifiedAt: Date
    public let isDefault: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        totalDuration: TimeInterval,
        segments: [TherapySegment],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.totalDuration = totalDuration
        self.segments = segments
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isDefault = isDefault
    }
    
    /// Therapy segment within a session pattern
    public struct TherapySegment: Codable, Identifiable, Sendable {
        public let id: UUID
        public let therapyType: TherapeuticFrequencyMapper.TherapyType
        public let duration: TimeInterval
        public let startTime: TimeInterval
        public let targetFrequency: Float?  // Optional specific frequency within therapy type range
        public let intensity: Float  // 0.0-1.0 intensity level
        public let transitionType: TransitionType
        
        public init(
            id: UUID = UUID(),
            therapyType: TherapeuticFrequencyMapper.TherapyType,
            duration: TimeInterval,
            startTime: TimeInterval,
            targetFrequency: Float? = nil,
            intensity: Float = 1.0,
            transitionType: TransitionType = .smooth
        ) {
            self.id = id
            self.therapyType = therapyType
            self.duration = duration
            self.startTime = startTime
            self.targetFrequency = targetFrequency
            self.intensity = intensity
            self.transitionType = transitionType
        }
        
        /// End time of the segment
        public var endTime: TimeInterval {
            return startTime + duration
        }
        
        /// Check if a given time falls within this segment
        public func contains(time: TimeInterval) -> Bool {
            return time >= startTime && time < endTime
        }
    }
    
    /// Transition type between therapy segments
    public enum TransitionType: String, Codable, CaseIterable, Sendable {
        case immediate = "Immediate"
        case smooth = "Smooth"
        case fade = "Fade"
        
        /// Duration of the transition in seconds
        public var duration: TimeInterval {
            switch self {
            case .immediate:
                return 0.0
            case .smooth:
                return 2.0
            case .fade:
                return 5.0
            }
        }
        
        /// Description of the transition
        public var description: String {
            switch self {
            case .immediate:
                return "Instant change between therapy types"
            case .smooth:
                return "Gradual 2-second transition"
            case .fade:
                return "Slow 5-second fade transition"
            }
        }
    }
    
    /// Validation result for session patterns
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errors: [ValidationError]
        public let warnings: [ValidationWarning]
        
        public init(isValid: Bool, errors: [ValidationError], warnings: [ValidationWarning]) {
            self.isValid = isValid
            self.errors = errors
            self.warnings = warnings
        }
    }
    
    /// Validation errors for session patterns
    public enum ValidationError: String, Sendable {
        case emptySegments = "Pattern must contain at least one therapy segment"
        case durationMismatch = "Total segment duration does not match pattern duration"
        case overlappingSegments = "Therapy segments cannot overlap"
        case gapInSegments = "Gaps found between therapy segments"
        case invalidDuration = "Pattern duration must be between 1 minute and 60 minutes"
        case segmentTooShort = "Therapy segments must be at least 30 seconds long"
        case invalidFrequency = "Target frequency is outside therapy type range"
        case invalidIntensity = "Intensity must be between 0.0 and 1.0"
    }
    
    /// Validation warnings for session patterns
    public enum ValidationWarning: String, Sendable {
        case shortSegment = "Segment shorter than 1 minute may be less effective"
        case longSegment = "Segment longer than 10 minutes may cause fatigue"
        case frequentTransitions = "Many transitions may be disruptive"
        case highIntensityGamma = "High intensity gamma therapy should be used cautiously"
        case noAlphaTheta = "Pattern lacks relaxing Alpha or Theta segments"
    }
    
    /// Validate the session pattern
    public func validate() -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Check for empty segments
        if segments.isEmpty {
            errors.append(.emptySegments)
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Check duration validity
        if totalDuration < 60 || totalDuration > 3600 {  // 1 minute to 60 minutes
            errors.append(.invalidDuration)
        }
        
        // Check segment durations and overlaps
        var totalSegmentDuration: TimeInterval = 0
        var sortedSegments = segments.sorted { $0.startTime < $1.startTime }
        
        for (index, segment) in sortedSegments.enumerated() {
            // Check minimum segment duration
            if segment.duration < 30 {  // 30 seconds minimum
                errors.append(.segmentTooShort)
            }
            
            // Check segment duration warnings
            if segment.duration < 60 {
                warnings.append(.shortSegment)
            } else if segment.duration > 600 {  // 10 minutes
                warnings.append(.longSegment)
            }
            
            // Check intensity
            if segment.intensity < 0.0 || segment.intensity > 1.0 {
                errors.append(.invalidIntensity)
            }
            
            // Check target frequency if specified
            if let targetFreq = segment.targetFrequency {
                if !segment.therapyType.frequencyRange.contains(targetFreq) {
                    errors.append(.invalidFrequency)
                }
            }
            
            // Check for high intensity gamma warning
            if segment.therapyType == .gamma && segment.intensity > 0.8 {
                warnings.append(.highIntensityGamma)
            }
            
            // Check for overlaps with next segment
            if index < sortedSegments.count - 1 {
                let nextSegment = sortedSegments[index + 1]
                if segment.endTime > nextSegment.startTime {
                    errors.append(.overlappingSegments)
                } else if segment.endTime < nextSegment.startTime {
                    errors.append(.gapInSegments)
                }
            }
            
            totalSegmentDuration += segment.duration
        }
        
        // Check total duration match
        let tolerance: TimeInterval = 1.0  // 1 second tolerance
        if abs(totalSegmentDuration - totalDuration) > tolerance {
            errors.append(.durationMismatch)
        }
        
        // Check for frequent transitions warning
        if Double(segments.count) > totalDuration / 120 {  // More than 1 transition per 2 minutes
            warnings.append(.frequentTransitions)
        }
        
        // Check for relaxing segments
        let hasAlphaOrTheta = segments.contains { $0.therapyType == .alpha || $0.therapyType == .theta }
        if !hasAlphaOrTheta && totalDuration > 300 {  // Sessions longer than 5 minutes
            warnings.append(.noAlphaTheta)
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    /// Get the active therapy segment at a specific time
    public func getActiveSegment(at time: TimeInterval) -> TherapySegment? {
        return segments.first { $0.contains(time: time) }
    }
    
    /// Get the next therapy segment after a specific time
    public func getNextSegment(after time: TimeInterval) -> TherapySegment? {
        return segments
            .filter { $0.startTime > time }
            .min { $0.startTime < $1.startTime }
    }
    
    /// Get progress through the pattern (0.0-1.0)
    public func getProgress(at time: TimeInterval) -> Double {
        let clampedTime = max(0, min(totalDuration, time))
        return clampedTime / totalDuration
    }
    
    /// Create a copy with updated modification date
    public func updated(
        name: String? = nil,
        description: String? = nil,
        segments: [TherapySegment]? = nil
    ) -> SessionPattern {
        return SessionPattern(
            id: self.id,
            name: name ?? self.name,
            description: description ?? self.description,
            totalDuration: segments?.reduce(0) { $0 + $1.duration } ?? self.totalDuration,
            segments: segments ?? self.segments,
            createdAt: self.createdAt,
            modifiedAt: Date(),
            isDefault: self.isDefault
        )
    }
}

// MARK: - Default Patterns

extension SessionPattern {
    /// Create default therapeutic patterns
    public static func createDefaultPatterns() -> [SessionPattern] {
        return [
            createDeepSleepPattern(),
            createFocusEnhancementPattern(),
            createMeditationPattern(),
            createEnergyBoostPattern(),
            createStressReliefPattern()
        ]
    }
    
    /// Deep Sleep pattern - primarily Delta with Theta transition
    public static func createDeepSleepPattern() -> SessionPattern {
        let segments = [
            TherapySegment(
                therapyType: .alpha,
                duration: 120,  // 2 minutes
                startTime: 0,
                intensity: 0.8,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .theta,
                duration: 300,  // 5 minutes
                startTime: 120,
                intensity: 0.9,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .delta,
                duration: 900,  // 15 minutes
                startTime: 420,
                intensity: 1.0,
                transitionType: .fade
            )
        ]
        
        return SessionPattern(
            name: "Deep Sleep",
            description: "Progressive relaxation pattern for deep, restorative sleep",
            totalDuration: 1320,  // 22 minutes
            segments: segments,
            isDefault: true
        )
    }
    
    /// Focus Enhancement pattern - Alpha and Beta combination
    public static func createFocusEnhancementPattern() -> SessionPattern {
        let segments = [
            TherapySegment(
                therapyType: .alpha,
                duration: 180,  // 3 minutes
                startTime: 0,
                intensity: 0.7,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .beta,
                duration: 420,  // 7 minutes
                startTime: 180,
                intensity: 0.8,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .alpha,
                duration: 120,  // 2 minutes
                startTime: 600,
                intensity: 0.6,
                transitionType: .fade
            )
        ]
        
        return SessionPattern(
            name: "Focus Enhancement",
            description: "Optimize concentration and mental clarity for work or study",
            totalDuration: 720,  // 12 minutes
            segments: segments,
            isDefault: true
        )
    }
    
    /// Meditation pattern - Theta focused with Alpha bookends
    public static func createMeditationPattern() -> SessionPattern {
        let segments = [
            TherapySegment(
                therapyType: .alpha,
                duration: 120,  // 2 minutes
                startTime: 0,
                intensity: 0.6,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .theta,
                duration: 600,  // 10 minutes
                startTime: 120,
                intensity: 0.9,
                transitionType: .fade
            ),
            TherapySegment(
                therapyType: .alpha,
                duration: 180,  // 3 minutes
                startTime: 720,
                intensity: 0.5,
                transitionType: .fade
            )
        ]
        
        return SessionPattern(
            name: "Meditation",
            description: "Deep meditative state with enhanced creativity and insight",
            totalDuration: 900,  // 15 minutes
            segments: segments,
            isDefault: true
        )
    }
    
    /// Energy Boost pattern - Beta and Gamma for alertness
    public static func createEnergyBoostPattern() -> SessionPattern {
        let segments = [
            TherapySegment(
                therapyType: .beta,
                duration: 240,  // 4 minutes
                startTime: 0,
                intensity: 0.7,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .gamma,
                duration: 180,  // 3 minutes
                startTime: 240,
                intensity: 0.8,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .beta,
                duration: 180,  // 3 minutes
                startTime: 420,
                intensity: 0.6,
                transitionType: .smooth
            )
        ]
        
        return SessionPattern(
            name: "Energy Boost",
            description: "Quick energy and alertness enhancement for peak performance",
            totalDuration: 600,  // 10 minutes
            segments: segments,
            isDefault: true
        )
    }
    
    /// Stress Relief pattern - Alpha and Theta for relaxation
    public static func createStressReliefPattern() -> SessionPattern {
        let segments = [
            TherapySegment(
                therapyType: .beta,
                duration: 60,   // 1 minute
                startTime: 0,
                intensity: 0.5,
                transitionType: .smooth
            ),
            TherapySegment(
                therapyType: .alpha,
                duration: 420,  // 7 minutes
                startTime: 60,
                intensity: 0.8,
                transitionType: .fade
            ),
            TherapySegment(
                therapyType: .theta,
                duration: 300,  // 5 minutes
                startTime: 480,
                intensity: 0.7,
                transitionType: .fade
            ),
            TherapySegment(
                therapyType: .alpha,
                duration: 120,  // 2 minutes
                startTime: 780,
                intensity: 0.5,
                transitionType: .fade
            )
        ]
        
        return SessionPattern(
            name: "Stress Relief",
            description: "Comprehensive stress reduction and deep relaxation",
            totalDuration: 900,  // 15 minutes
            segments: segments,
            isDefault: true
        )
    }
}