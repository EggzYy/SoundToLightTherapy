# Design Document

## Overview

This design document outlines the architecture for transforming the SoundToLightTherapy iOS app into a medically accurate stroboscopic light therapy system. The solution addresses the core issue where the current app does not provide true Hz-accurate strobing (e.g., 30 Hz should equal exactly 30 complete on/off cycles per second). The enhanced system will deliver precise frequency-based light therapy through improved timing algorithms, hardware optimization, and comprehensive safety features.

## Architecture

### High-Level Architecture

```mermaid
graph TB
    A[Audio Input] --> B[Enhanced Frequency Detector]
    B --> C[Therapeutic Frequency Mapper]
    C --> D[Precision Strobe Controller]
    D --> E[Hardware Flashlight Interface]
    
    F[Safety Monitor] --> D
    G[Calibration Engine] --> D
    H[Session Manager] --> I[Data Logger]
    D --> H
    
    J[UI Controller] --> K[Real-time Display]
    H --> J
    D --> J
    
    L[Export Engine] --> M[Session Data]
    I --> L
```

### Core Components

1. **Enhanced Frequency Detector**: Advanced FFT-based audio analysis with therapeutic frequency mapping
2. **Precision Strobe Controller**: High-accuracy timing engine for flashlight control
3. **Safety Monitor**: Real-time safety checks and photosensitivity protection
4. **Calibration Engine**: Hardware timing validation and correction
5. **Session Manager**: Comprehensive session tracking and data collection
6. **Therapeutic Frequency Mapper**: Intelligent mapping of audio frequencies to therapeutic ranges

## Components and Interfaces

### 1. Enhanced Frequency Detector

**Purpose**: Provide accurate, real-time frequency detection with therapeutic relevance

**Key Improvements**:
- Implement windowed FFT with overlap for smoother frequency tracking
- Add spectral peak tracking for consistent frequency identification
- Include noise floor detection to filter out ambient noise
- Support multiple frequency extraction methods (dominant, harmonic, rhythmic)

**Interface**:
```swift
public actor EnhancedFrequencyDetector {
    func detectTherapeuticFrequency(from audioData: [Float]) async throws -> TherapeuticFrequencyResult
    func calibrateNoiseFloor() async throws
    func setDetectionMode(_ mode: FrequencyDetectionMode) async
}

public struct TherapeuticFrequencyResult {
    let targetFrequency: Float          // Mapped therapeutic frequency (0.5-100 Hz)
    let sourceFrequency: Float          // Original detected frequency
    let confidence: Float               // Detection confidence (0.0-1.0)
    let therapeuticCategory: TherapyType // Alpha, Beta, Gamma, etc.
    let recommendedDuration: TimeInterval // Suggested therapy duration
}

public enum FrequencyDetectionMode {
    case dominant        // Use strongest frequency component
    case rhythmic       // Extract rhythmic/tempo information
    case harmonic       // Focus on harmonic content
    case adaptive       // Automatically choose best method
}
```

### 2. Precision Strobe Controller

**Purpose**: Deliver microsecond-accurate flashlight strobing at therapeutic frequencies

**Key Features**:
- High-resolution timing using CADisplayLink and DispatchSourceTimer
- Hardware capability detection and adaptive frequency limiting
- Jitter compensation and timing drift correction
- Emergency stop with <50ms response time

**Interface**:
```swift
public actor PrecisionStrobeController {
    func startStrobing(frequency: Float, intensity: Float) async throws
    func updateFrequency(_ frequency: Float) async throws
    func stopStrobing() async throws
    func emergencyStop() async throws
    func getActualFrequency() async -> Float
    func getTimingAccuracy() async -> StrobeAccuracyMetrics
}

public struct StrobeAccuracyMetrics {
    let targetFrequency: Float
    let achievedFrequency: Float
    let averageJitter: TimeInterval      // Average timing deviation
    let maxJitter: TimeInterval          // Maximum timing deviation
    let accuracyPercentage: Float        // Overall accuracy (0.0-100.0)
    let droppedCycles: Int              // Number of missed strobe cycles
}
```

### 3. Safety Monitor

**Purpose**: Ensure safe operation and prevent photosensitive reactions

**Key Features**:
- Real-time frequency monitoring for epilepsy-triggering ranges (15-25 Hz)
- Session duration limits with automatic breaks
- User acknowledgment system for safety warnings
- Emergency stop functionality

**Interface**:
```swift
public actor SafetyMonitor {
    func validateFrequency(_ frequency: Float) async throws -> SafetyValidation
    func checkSessionDuration(_ duration: TimeInterval) async throws
    func requireSafetyAcknowledgment() async throws -> Bool
    func enableSafetyMode(_ enabled: Bool) async
}

public struct SafetyValidation {
    let isFrequencySafe: Bool
    let warnings: [SafetyWarning]
    let recommendedAction: SafetyAction
}

public enum SafetyWarning {
    case epilepsyRisk(frequency: Float)
    case extendedSession(duration: TimeInterval)
    case highIntensity(level: Float)
    case batteryLow
}
```

### 4. Calibration Engine

**Purpose**: Validate and correct timing accuracy for therapeutic precision

**Key Features**:
- Hardware timing measurement using high-resolution counters
- Automatic calibration factor calculation
- Performance benchmarking across different frequencies
- Calibration data persistence

**Interface**:
```swift
public actor CalibrationEngine {
    func performFullCalibration() async throws -> CalibrationResults
    func validateFrequency(_ frequency: Float) async throws -> FrequencyValidation
    func getCalibrationFactors() async -> CalibrationFactors
    func resetCalibration() async throws
}

public struct CalibrationResults {
    let maxAccurateFrequency: Float      // Highest frequency with >95% accuracy
    let timingCorrections: [Float: TimeInterval] // Frequency-specific corrections
    let hardwareCapabilities: HardwareSpecs
    let recommendedFrequencyRanges: [ClosedRange<Float>]
}
```

### 5. Session Manager

**Purpose**: Comprehensive session tracking, data collection, and export

**Key Features**:
- Real-time session metrics collection
- Frequency accuracy tracking
- Session history management
- Data export in multiple formats

**Interface**:
```swift
public actor SessionManager {
    func startSession(configuration: SessionConfiguration) async throws
    func updateSessionMetrics(_ metrics: SessionMetrics) async
    func endSession() async throws -> SessionSummary
    func exportSessionData(format: ExportFormat) async throws -> Data
    func getSessionHistory() async -> [SessionSummary]
}

public struct SessionConfiguration {
    let targetFrequencyRange: ClosedRange<Float>
    let maxDuration: TimeInterval
    let safetyMode: Bool
    let calibrationRequired: Bool
}

public struct SessionSummary {
    let sessionId: UUID
    let startTime: Date
    let duration: TimeInterval
    let frequencyStats: FrequencyStatistics
    let accuracyMetrics: StrobeAccuracyMetrics
    let safetyEvents: [SafetyEvent]
}
```

## Data Models

### Core Data Structures

```swift
// Therapeutic frequency categories based on brainwave research
public enum TherapyType: CaseIterable {
    case delta      // 0.5-4 Hz - Deep sleep, healing
    case theta      // 4-8 Hz - Meditation, creativity
    case alpha      // 8-13 Hz - Relaxation, focus
    case beta       // 13-30 Hz - Active thinking, alertness
    case gamma      // 30-100 Hz - Cognitive enhancement, awareness
    
    var frequencyRange: ClosedRange<Float> {
        switch self {
        case .delta: return 0.5...4.0
        case .theta: return 4.0...8.0
        case .alpha: return 8.0...13.0
        case .beta: return 13.0...30.0
        case .gamma: return 30.0...100.0
        }
    }
}

// Real-time session metrics
public struct SessionMetrics {
    let timestamp: Date
    let targetFrequency: Float
    let achievedFrequency: Float
    let strobeAccuracy: Float
    let audioLevel: Float
    let batteryLevel: Float
}

// Frequency analysis results
public struct FrequencyStatistics {
    let averageFrequency: Float
    let frequencyRange: ClosedRange<Float>
    let dominantTherapyType: TherapyType
    let frequencyStability: Float        // Measure of frequency consistency
    let therapeuticEffectiveness: Float  // Calculated therapeutic value
}
```

## Error Handling

### Comprehensive Error Management

```swift
public enum StroboscopicTherapyError: Error {
    case hardwareUnavailable
    case frequencyOutOfRange(Float)
    case timingAccuracyInsufficient(achieved: Float, required: Float)
    case safetyViolation(SafetyWarning)
    case calibrationRequired
    case sessionDurationExceeded
    case batteryTooLow
    case audioInputFailed
    case emergencyStopActivated
}

// Error recovery strategies
public protocol ErrorRecoveryStrategy {
    func canRecover(from error: StroboscopicTherapyError) -> Bool
    func recover(from error: StroboscopicTherapyError) async throws
}
```

## Testing Strategy

### 1. Unit Testing

**Frequency Detection Testing**:
- Test FFT accuracy with known sine wave inputs
- Validate frequency mapping algorithms
- Test noise floor detection and filtering
- Verify therapeutic frequency categorization

**Strobe Timing Testing**:
- Measure actual strobe timing against expected values
- Test timing accuracy across different frequencies
- Validate jitter compensation algorithms
- Test emergency stop response times

### 2. Integration Testing

**End-to-End Therapy Sessions**:
- Test complete audio-to-strobe pipeline
- Validate session data collection and export
- Test safety monitoring during active sessions
- Verify calibration integration with strobe control

### 3. Hardware Performance Testing

**Device-Specific Testing**:
- Test maximum achievable frequencies on different iPhone models
- Measure battery impact of high-frequency strobing
- Test thermal performance during extended sessions
- Validate flashlight hardware limitations

### 4. Safety Testing

**Photosensitivity Protection**:
- Test epilepsy-risk frequency detection and warnings
- Validate emergency stop functionality
- Test session duration limits and break prompts
- Verify safety mode frequency limitations

### 5. Accuracy Validation

**Therapeutic Precision Testing**:
- Use external light sensors to measure actual strobe timing
- Compare achieved frequencies with target frequencies
- Test frequency stability over extended periods
- Validate calibration accuracy improvements

## Implementation Phases

### Phase 1: Core Timing Engine (High Priority)
- Implement PrecisionStrobeController with microsecond timing
- Add hardware capability detection
- Implement emergency stop functionality
- Basic accuracy measurement and reporting

### Phase 2: Enhanced Frequency Detection (High Priority)
- Upgrade FrequencyDetector with advanced FFT analysis
- Add therapeutic frequency mapping
- Implement noise floor detection
- Add multiple detection modes (dominant, rhythmic, harmonic)

### Phase 3: Safety and Calibration (Medium Priority)
- Implement SafetyMonitor with photosensitivity protection
- Add CalibrationEngine for timing validation
- Implement safety warnings and user acknowledgment
- Add session duration monitoring

### Phase 4: Data Collection and Export (Medium Priority)
- Enhance SessionManager with comprehensive metrics
- Add real-time session data logging
- Implement data export functionality
- Add session history and trend analysis

### Phase 5: UI Enhancement and User Experience (Low Priority)
- Update UI with real-time accuracy displays
- Add calibration and validation interfaces
- Implement session statistics visualization
- Add therapeutic frequency recommendations

## Performance Considerations

### Timing Optimization
- Use CADisplayLink for 60Hz refresh rate synchronization
- Implement DispatchSourceTimer for sub-millisecond precision
- Minimize memory allocations in real-time processing loops
- Use actor isolation to prevent timing interference

### Battery Optimization
- Implement adaptive intensity based on battery level
- Add low-power mode for extended sessions
- Monitor thermal state and adjust performance accordingly
- Provide battery usage estimates for different frequencies

### Memory Management
- Use circular buffers for audio data processing
- Implement efficient FFT with pre-allocated buffers
- Minimize object creation in real-time loops
- Use value types for performance-critical data structures

## Security and Privacy

### Data Protection
- Store session data locally with encryption
- Implement secure data export with user consent
- Avoid cloud storage of sensitive health data
- Provide data deletion options for privacy compliance

### Medical Compliance
- Include appropriate medical disclaimers
- Implement safety warnings for photosensitive users
- Provide clear usage guidelines and limitations
- Support healthcare provider data sharing (with consent)

This design provides a comprehensive foundation for creating a medically accurate stroboscopic light therapy application that addresses all the identified requirements while maintaining safety, precision, and usability.