# Requirements Document

## Introduction

This specification defines the requirements for transforming the SoundToLightTherapy iOS app into a medically accurate stroboscopic light therapy application. The current app captures microphone input and attempts to convert audio frequencies to flashlight patterns, but it does not provide true Hz-accurate stroboscopic therapy. The enhanced app will deliver precise frequency-based light therapy where 1 Hz equals exactly 1 complete on/off cycle per second, enabling therapeutic applications for neurological conditions, meditation, and brainwave entrainment.

## Requirements

### Requirement 1: Accurate Frequency-to-Strobe Conversion

**User Story:** As a therapy user, I want the flashlight to strobe at exactly the detected audio frequency, so that I receive precise therapeutic light stimulation.

#### Acceptance Criteria

1. WHEN audio input is detected at X Hz THEN the flashlight SHALL strobe at exactly X Hz (X complete on/off cycles per second)
2. WHEN the app displays "30 Hz" THEN the flashlight SHALL complete exactly 30 full on/off cycles within 1 second
3. WHEN the app displays "100 Hz" THEN the flashlight SHALL complete exactly 100 full on/off cycles within 1 second
4. IF the detected frequency exceeds hardware limitations THEN the system SHALL cap the output at maximum achievable frequency and display a warning
5. WHEN no audio is detected THEN the flashlight SHALL remain off or maintain the last stable frequency

### Requirement 2: Real-Time Audio Frequency Detection

**User Story:** As a therapy user, I want the app to accurately detect audio frequencies in real-time, so that the light therapy responds immediately to sound input.

#### Acceptance Criteria

1. WHEN microphone input contains audio THEN the system SHALL detect the dominant frequency within 100ms
2. WHEN multiple frequencies are present THEN the system SHALL identify the most prominent frequency for therapy
3. WHEN audio frequency changes THEN the flashlight strobe rate SHALL update within 200ms
4. IF audio input is below noise threshold THEN the system SHALL ignore the input and maintain previous frequency
5. WHEN audio contains frequencies outside therapeutic range (0.5-100 Hz) THEN the system SHALL map them to therapeutic equivalents

### Requirement 3: Therapeutic Frequency Range Support

**User Story:** As a healthcare practitioner, I want the app to support medically relevant frequency ranges, so that I can provide evidence-based light therapy treatments.

#### Acceptance Criteria

1. WHEN the system operates THEN it SHALL support frequencies from 0.5 Hz to 100 Hz
2. WHEN frequencies below 0.5 Hz are detected THEN the system SHALL map them to 0.5 Hz minimum
3. WHEN frequencies above 100 Hz are detected THEN the system SHALL either map them proportionally or cap at 100 Hz
4. WHEN operating in therapeutic mode THEN the system SHALL prioritize frequencies in the 1-40 Hz range for optimal therapeutic effect
5. WHEN gamma wave frequencies (30-100 Hz) are detected THEN the system SHALL provide high-precision strobing

### Requirement 4: Hardware Performance Optimization

**User Story:** As a user, I want the flashlight to respond at high frequencies without lag or inconsistency, so that the therapy is effective and reliable.

#### Acceptance Criteria

1. WHEN strobing at frequencies up to 40 Hz THEN the flashlight SHALL maintain consistent timing with less than 5ms jitter
2. WHEN strobing at frequencies above 40 Hz THEN the system SHALL attempt maximum hardware capability and report actual achieved frequency
3. WHEN the device cannot achieve the target frequency THEN the system SHALL display the actual achieved frequency to the user
4. IF hardware limitations prevent accurate strobing THEN the system SHALL provide haptic feedback as a supplementary therapeutic modality
5. WHEN battery level is low THEN the system SHALL warn the user that strobe accuracy may be affected

### Requirement 5: Safety and Medical Compliance

**User Story:** As a user with photosensitive conditions, I want the app to include safety warnings and limits, so that I can use light therapy safely.

#### Acceptance Criteria

1. WHEN the app launches THEN it SHALL display photosensitivity warnings and require user acknowledgment
2. WHEN frequencies in the 15-25 Hz range are detected THEN the system SHALL display epilepsy warnings
3. WHEN continuous strobing exceeds 10 minutes THEN the system SHALL prompt the user to take a break
4. IF the user enables safety mode THEN the system SHALL limit maximum frequency to 20 Hz
5. WHEN emergency stop is activated THEN all light output SHALL cease immediately within 50ms

### Requirement 6: Precision Timing and Measurement

**User Story:** As a researcher, I want precise timing measurements and frequency validation, so that I can verify therapeutic effectiveness and conduct studies.

#### Acceptance Criteria

1. WHEN the system operates THEN it SHALL log actual strobe timing with microsecond precision
2. WHEN displaying frequency information THEN the system SHALL show both target and achieved frequencies
3. WHEN session data is recorded THEN it SHALL include frequency accuracy statistics and timing deviations
4. IF timing drift occurs THEN the system SHALL automatically recalibrate and log the correction
5. WHEN exporting session data THEN it SHALL include frequency histograms and accuracy metrics

### Requirement 7: Audio Input Processing Enhancement

**User Story:** As a user, I want the app to work with various audio sources (music, tones, environmental sounds), so that I can use different types of audio for therapy.

#### Acceptance Criteria

1. WHEN processing music input THEN the system SHALL extract the dominant rhythmic frequency for strobing
2. WHEN processing pure tones THEN the system SHALL directly map the tone frequency to strobe rate
3. WHEN processing complex audio THEN the system SHALL use spectral analysis to identify therapeutic frequencies
4. IF multiple strong frequencies are detected THEN the system SHALL allow user selection or use the most therapeutically relevant frequency
5. WHEN audio input is inconsistent THEN the system SHALL provide frequency smoothing options

### Requirement 8: User Interface and Feedback

**User Story:** As a user, I want clear visual feedback about frequency detection and strobe accuracy, so that I can monitor the therapy effectiveness.

#### Acceptance Criteria

1. WHEN audio is being processed THEN the UI SHALL display real-time frequency detection with visual indicators
2. WHEN strobing is active THEN the UI SHALL show target frequency, achieved frequency, and accuracy percentage
3. WHEN frequency changes occur THEN the UI SHALL provide smooth visual transitions and haptic feedback
4. IF strobe accuracy falls below 95% THEN the system SHALL display a warning indicator
5. WHEN session is complete THEN the UI SHALL display session statistics including average frequency accuracy

### Requirement 9: Calibration and Validation

**User Story:** As a user, I want to calibrate and validate the strobe accuracy, so that I can ensure the therapy is working correctly.

#### Acceptance Criteria

1. WHEN calibration mode is activated THEN the system SHALL provide test frequencies with known timing for validation
2. WHEN running calibration THEN the system SHALL measure and report actual strobe timing against expected timing
3. WHEN calibration detects timing issues THEN the system SHALL provide automatic correction factors
4. IF hardware cannot achieve required accuracy THEN the system SHALL recommend alternative therapy modes
5. WHEN validation is complete THEN the system SHALL store calibration data for future sessions

### Requirement 10: Session Management and Data Export

**User Story:** As a healthcare provider, I want to track therapy sessions and export data, so that I can monitor patient progress and adjust treatments.

#### Acceptance Criteria

1. WHEN a therapy session starts THEN the system SHALL record session metadata including date, duration, and frequency ranges
2. WHEN session is active THEN the system SHALL continuously log frequency data and strobe accuracy
3. WHEN session ends THEN the system SHALL generate a summary report with key metrics
4. IF data export is requested THEN the system SHALL provide CSV or JSON format with detailed timing data
5. WHEN reviewing session history THEN the user SHALL be able to view trends and accuracy improvements over time