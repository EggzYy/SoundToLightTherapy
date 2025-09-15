# Implementation Plan

- [x] 1. Create core precision timing infrastructure
  - Implement high-resolution timing system using CADisplayLink and DispatchSourceTimer
  - Create microsecond-accurate strobe timing engine with jitter compensation
  - Add hardware capability detection for maximum achievable frequencies
  - _Requirements: 1.1, 1.2, 1.3, 4.1, 4.2_

- [x] 1.1 Implement PrecisionStrobeController with microsecond timing
  - Create new PrecisionStrobeController actor with high-resolution timing capabilities
  - Implement CADisplayLink-based timing for 60Hz synchronization
  - Add DispatchSourceTimer for sub-millisecond precision control
  - Create StrobeAccuracyMetrics struct for real-time timing measurement
  - _Requirements: 1.1, 1.2, 4.1_

- [x] 1.2 Add hardware capability detection and adaptive frequency limiting
  - Implement device-specific frequency capability detection
  - Create hardware performance benchmarking system
  - Add adaptive frequency limiting based on device capabilities
  - Implement fallback strategies for unsupported frequencies
  - _Requirements: 1.4, 4.2, 4.3_

- [x] 1.3 Implement emergency stop with <50ms response time
  - Create immediate flashlight shutdown mechanism
  - Add emergency stop validation with timing measurement
  - Implement safety override for all timing operations
  - Create emergency stop testing and validation system
  - _Requirements: 5.5, 4.5_

- [x] 2. Enhance frequency detection with therapeutic mapping
  - Upgrade existing FrequencyDetector with advanced FFT analysis and windowing
  - Implement therapeutic frequency mapping from any input range to 0.5-100Hz
  - Add noise floor detection and ambient sound filtering
  - Create multiple frequency detection modes (dominant, rhythmic, harmonic)
  - _Requirements: 2.1, 2.2, 2.5, 7.1, 7.2, 7.3_

- [x] 2.1 Implement advanced FFT analysis with windowing and overlap
  - Enhance existing FFT implementation with Hanning windowing
  - Add overlapping window analysis for smoother frequency tracking
  - Implement spectral peak tracking for consistent frequency identification
  - Create frequency smoothing algorithms to reduce detection jitter
  - _Requirements: 2.1, 2.3_

- [x] 2.2 Create therapeutic frequency mapping system with audio input harmonic frequency detection regarding A4 = 432Hz tuning
  - Implement TherapeuticFrequencyMapper class with brainwave categories
  - Create intelligent mapping from any input frequency to therapeutic ranges
  - Add TherapyType enum (delta, theta, alpha, beta, gamma) with frequency ranges
  - Implement frequency range validation and therapeutic recommendations
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 2.25 Implement advanced therapy session management with harmonic-based frequency transformation
  - Create therapy type selection interface for manual therapy type override
  - Implement session pattern designer with customizable therapy sequences
  - Add session pattern storage and management system with named presets
  - Fix harmonic-based therapeutic frequency calculation using detected note harmonics
  - Create real-time therapy type switching during active sessions
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 8.1, 8.2_

- [x] 2.25.1 Create therapy type selection and override system
  - Add therapy type selector UI component with color-coded options
  - Implement manual therapy type override that bypasses automatic detection
  - Create therapy type switching interface for real-time session control
  - Add therapy type lock/unlock toggle for maintaining selected type
  - _Requirements: 8.1, 8.2_

- [x] 2.25.2 Implement session pattern designer and management
  - Create SessionPattern data model with timed therapy type sequences
  - Implement pattern designer UI with drag-and-drop therapy type segments
  - Add pattern validation to ensure total duration matches session length
  - Create pattern preview functionality showing therapy type timeline
  - Implement pattern storage system with user-defined names and descriptions
  - _Requirements: 10.1, 10.3, 8.1_

- [x] 2.25.3 Add session pattern storage and preset management
  - Create SessionPatternManager for saving/loading custom patterns
  - Implement pattern library UI with search and filtering capabilities
  - Add pattern sharing functionality for exporting/importing patterns
  - Create default therapeutic patterns (e.g., "Deep Sleep", "Focus Enhancement", "Meditation")
  - Implement pattern deletion and modification capabilities
  - _Requirements: 10.3, 10.4, 8.1_

- [x] 2.25.4 Fix harmonic-based therapeutic frequency transformation
  - Correct therapeutic frequency calculation to use detected note harmonics
  - Implement proper harmonic series mapping to therapy type frequency ranges
  - Add harmonic frequency selection algorithm (fundamental, 2nd, 3rd, etc.)
  - Create harmonic-to-therapeutic frequency mapping tables for each therapy type
  - Implement frequency validation to ensure therapeutic frequencies stay within brainwave ranges
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 2.25.5 Create real-time therapy type switching and session control
  - Implement seamless therapy type transitions during active sessions
  - Add session timeline UI showing current and upcoming therapy types
  - Create automatic pattern progression with visual countdown timers
  - Implement manual pattern override and skip functionality
  - Add session pause/resume with pattern state preservation
  - _Requirements: 8.1, 8.2, 10.1_

- [ ] 2.3 Add noise floor detection and ambient sound filtering
  - Implement automatic noise floor calibration
  - Create ambient sound filtering to ignore background noise (selectable by user)
  - Add confidence scoring for frequency detection reliability
  - Implement adaptive threshold adjustment based on environment
  - _Requirements: 2.4, 7.4_

- [ ] 2.4 Implement multiple frequency detection modes
  - Create FrequencyDetectionMode enum with different analysis strategies as optional tool
  - Implement dominant frequency detection for pure tones to tool as selectable
  - Add rhythmic frequency extraction for music and complex audio to tool as selectable
  - Create harmonic analysis mode for musical content to tool as selectable
  - Add adaptive mode that automatically selects best detection method to tool as selectable
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 3. Implement safety monitoring and photosensitivity protection
  - Create SafetyMonitor actor with real-time frequency validation
  - Add epilepsy-risk frequency detection (15-25 Hz warning system)
  - Implement session duration limits with automatic break prompts
  - Create user safety acknowledgment system with medical disclaimers
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 3.1 Create SafetyMonitor with real-time frequency validation
  - Implement SafetyMonitor actor with continuous frequency monitoring
  - Create SafetyValidation struct with warnings and recommendations
  - Add real-time safety checks during active strobing sessions
  - Implement safety override mechanisms for dangerous frequencies
  - _Requirements: 5.1, 5.2_

- [ ] 3.2 Implement epilepsy-risk frequency detection and warnings
  - Create specific monitoring for 15-25 Hz frequency range
  - Add immediate warning display when epilepsy-risk frequencies detected
  - Implement automatic frequency adjustment or session pause for safety
  - Create user override option with additional safety confirmations
  - _Requirements: 5.2_

- [ ] 3.3 Add session duration monitoring with break prompts
  - Implement automatic session duration tracking
  - Add configurable session limits based on safety mode settings
  - Implement forced session termination for extended use
  - _Requirements: 5.3_

- [ ] 3.4 Create safety acknowledgment system with medical disclaimers
  - Implement first-launch safety warning with required acknowledgment
  - Create medical disclaimer screens with photosensitivity warnings
  - Add safety mode toggle with frequency limitations (max 20 Hz)
  - Implement session-specific safety confirmations for high-risk frequencies
  - _Requirements: 5.1, 5.4_

- [ ] 4. Create calibration engine for timing validation and correction
  - Implement CalibrationEngine actor with hardware timing measurement
  - Add automatic calibration factor calculation for frequency correction
  - Create calibration validation system with known test frequencies
  - Implement calibration data persistence and automatic correction application
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 4.1 Implement hardware timing measurement system
  - Create high-resolution timing measurement using system counters
  - Implement actual vs. expected frequency comparison algorithms
  - Add jitter measurement and statistical analysis
  - Create hardware performance profiling for different device models
  - _Requirements: 9.1, 9.2_

- [ ] 4.2 Add automatic calibration factor calculation
  - Implement calibration algorithms that measure timing deviations
  - Create frequency-specific correction factors for improved accuracy
  - Add automatic calibration factor application during strobing
  - Implement calibration factor validation and quality assessment
  - _Requirements: 9.3, 6.4_

- [ ] 4.3 Create calibration validation with test frequencies
  - Implement known test frequency generation (1Hz, 10Hz, 40Hz, 100Hz)
  - Add calibration validation mode with accuracy measurement
  - Create calibration quality scoring and pass/fail criteria
  - Implement calibration recommendations based on hardware capabilities
  - _Requirements: 9.1, 9.4_

- [ ] 4.4 Implement calibration data persistence and correction
  - Create calibration data storage with device-specific profiles
  - Add automatic calibration factor loading on app startup
  - Implement calibration data validation and corruption detection
  - Create calibration reset and re-calibration functionality
  - _Requirements: 9.5_

- [ ] 5. Enhance session management with comprehensive data collection
  - Upgrade existing TherapySessionCoordinator with detailed metrics collection
  - Implement real-time session data logging with frequency accuracy tracking
  - Create SessionManager actor for session history and data export
  - Add comprehensive session statistics and trend analysis
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 5.1 Upgrade session coordinator with detailed metrics collection
  - Enhance existing TherapySessionCoordinator with SessionMetrics logging
  - Add real-time frequency accuracy tracking during sessions
  - Implement comprehensive session state management
  - Create session event logging for safety events and user actions
  - _Requirements: 10.1, 10.2_

- [ ] 5.2 Implement real-time session data logging
  - Create continuous session metrics collection (frequency, accuracy, timing)
  - Add timestamp-based data logging with microsecond precision
  - Implement efficient data storage using circular buffers
  - Create session data validation and integrity checking
  - _Requirements: 6.1, 6.2, 10.2_

- [ ] 5.3 Create SessionManager for history and data export
  - Implement SessionManager actor with session history management
  - Add data export functionality in CSV and JSON formats
  - Create session summary generation with key therapeutic metrics
  - Implement session comparison and trend analysis features
  - _Requirements: 10.3, 10.4, 10.5_

- [ ] 5.4 Add session statistics and therapeutic effectiveness tracking
  - Implement FrequencyStatistics calculation with therapeutic categorization
  - Add session effectiveness scoring based on frequency accuracy and stability
  - Create therapeutic progress tracking across multiple sessions
  - Implement personalized therapy recommendations based on session history
  - _Requirements: 6.3, 10.5_

- [ ] 6. Update user interface with real-time accuracy displays
  - Enhance existing TherapyView with precision timing displays
  - Add real-time frequency accuracy indicators and visual feedback
  - Implement calibration interface for user-initiated timing validation
  - Create session statistics visualization with therapeutic insights
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 6.1 Enhance TherapyView with precision timing displays
  - Update existing UI to show target vs. achieved frequency in real-time
  - Add timing accuracy percentage display with color-coded indicators
  - Implement visual strobe timing indicator for user feedback
  - Create frequency stability meter showing detection consistency
  - _Requirements: 8.1, 8.2_

- [ ] 6.2 Add real-time accuracy indicators and visual feedback
  - Implement accuracy warning indicators when precision falls below 95%
  - Add visual feedback for frequency changes and therapeutic transitions
  - Create haptic feedback integration for frequency change notifications
  - Implement audio level indicators showing microphone input strength
  - _Requirements: 8.3, 8.4_

- [ ] 6.3 Implement calibration interface for user validation
  - Create calibration screen with step-by-step timing validation process
  - Add calibration progress indicators and result displays
  - Implement calibration quality assessment with pass/fail indicators
  - Create calibration recommendations and troubleshooting guidance
  - _Requirements: 9.1, 9.2, 9.5_

- [ ] 6.4 Create session statistics visualization
  - Implement session summary screen with therapeutic effectiveness metrics
  - Add frequency distribution charts showing therapy type usage
  - Create accuracy trend graphs across multiple sessions
  - Implement therapeutic progress indicators and recommendations
  - _Requirements: 8.5, 10.5_

- [ ] 7. Integrate all components and perform end-to-end testing
  - Wire together all new components with existing app architecture
  - Implement comprehensive error handling and recovery strategies
  - Create end-to-end integration tests for complete therapy workflows
  - Add performance optimization for real-time operation
  - _Requirements: All requirements integration_

- [ ] 7.1 Wire components with existing app architecture
  - Integrate PrecisionStrobeController with existing FlashlightController
  - Connect enhanced FrequencyDetector with TherapySessionCoordinator
  - Integrate SafetyMonitor with session management and UI components
  - Connect CalibrationEngine with strobe controller and session manager
  - _Requirements: Integration of all components_

- [ ] 7.2 Implement comprehensive error handling and recovery
  - Create StroboscopicTherapyError enum with all possible error conditions
  - Implement ErrorRecoveryStrategy protocol with automatic recovery mechanisms
  - Add graceful degradation for hardware limitation scenarios
  - Create user-friendly error messages with actionable recovery steps
  - _Requirements: Error handling for all requirements_

- [ ] 7.3 Create end-to-end integration tests
  - Implement complete therapy session testing from audio input to strobe output
  - Add timing accuracy validation tests with known frequency inputs
  - Create safety system testing with epilepsy-risk frequency scenarios
  - Implement calibration system testing with hardware timing validation
  - _Requirements: Testing coverage for all requirements_

- [ ] 7.4 Add performance optimization for real-time operation
  - Optimize memory allocation patterns in real-time processing loops
  - Implement efficient actor communication for minimal latency
  - Add thermal monitoring and performance adjustment for extended sessions
  - Create battery usage optimization with adaptive intensity control
  - _Requirements: 4.1, 4.5, performance optimization_

- [ ] 8. Create comprehensive documentation and user guides
  - Write user manual with therapeutic frequency guidelines and safety information
  - Create developer documentation for future maintenance and enhancements
  - Add in-app help system with interactive tutorials and troubleshooting
  - Implement accessibility documentation for users with disabilities
  - _Requirements: Documentation and user guidance_

- [ ] 8.1 Write user manual with therapeutic guidelines
  - Create comprehensive user guide explaining therapeutic frequency ranges
  - Add safety guidelines and photosensitivity warnings
  - Document calibration procedures and accuracy validation steps
  - Include troubleshooting guide for common issues and solutions
  - _Requirements: User education and safety_

- [ ] 8.2 Create developer documentation
  - Document all new APIs and architectural changes
  - Create code examples for extending therapeutic functionality
  - Add performance tuning guidelines for different device models
  - Document testing procedures and validation methodologies
  - _Requirements: Maintainability and extensibility_

- [ ] 8.3 Add in-app help system with interactive tutorials
  - Implement contextual help system integrated with UI components
  - Create interactive calibration tutorial with step-by-step guidance
  - Add safety tutorial explaining photosensitivity risks and precautions
  - Implement therapeutic frequency education with brainwave explanations
  - _Requirements: User onboarding and education_