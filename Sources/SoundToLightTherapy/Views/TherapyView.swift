import Foundation
import SwiftUI

/// Main therapy view with comprehensive accessibility support
public struct TherapyView: SwiftUI.View {
    // State properties for data
    @State private var targetFrequency: Float = 10.0
    @State private var sessionDuration: TimeInterval = 300
    @State private var isSessionActive: Bool = false
    @State private var currentFrequency: Float = 0.0
    @State private var sessionProgress: Double = 0.0
    @State private var lastAnnouncedProgress: Int = -1
    @State private var isWakeLockActive: Bool = false
    
    // Enhanced therapeutic information
    @State private var therapeuticFrequency: Float = 0.0
    @State private var musicalNote: String = ""
    @State private var therapyType: String = ""
    @State private var isHarmonic: Bool = false
    @State private var confidence: Float = 0.0
    @State private var therapeuticRecommendations: [String] = []
    
    // Therapy type selection and override
    @State private var selectedTherapyType: TherapeuticFrequencyMapper.TherapyType? = nil
    @State private var isTherapyTypeOverrideEnabled: Bool = false
    @State private var showTherapyTypeSelector: Bool = false
    
    // Session pattern management
    @State private var selectedSessionPattern: SessionPattern? = nil
    @State private var showingPatternLibrary: Bool = false
    @State private var showingPatternDesigner: Bool = false
    @State private var isPatternModeEnabled: Bool = false
    @State private var isPatternAudioResponsive: Bool = false
    @State private var sessionStartTime: Date? = nil
    @State private var isSessionPaused: Bool = false

    // Shared session coordinator instance
    private let sessionCoordinator = TherapySessionCoordinator()

    #if canImport(UIKit)
    // Wake lock lifecycle manager for handling app lifecycle events
    @StateObject private var wakeLockManager = WakeLockLifecycleManager()
    #endif

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header section
                headerSection

                // Audio responsiveness display section
                audioResponseSection

                // Session control section
                sessionControlSection

                // Status display section
                statusDisplaySection

                // Session pattern selection section
                sessionPatternSelectionSection
                
                // Therapy type selection section
                therapyTypeSelectionSection
                
                // Therapeutic recommendations section
                if isSessionActive {
                    therapeuticRecommendationsSection
                }

                // Emergency stop section
                emergencyStopSection

                // Settings section
                settingsSection
            }
            .padding()
            .frame(maxWidth: 600)
        }
        .background(accessibleColorToColor(ColorContrastSupport.AccessiblePalettes.backgroundLight))
        // TODO: Add accessibility support when SwiftCrossUI implements accessibility APIs
        // TODO: Add onChange support when SwiftCrossUI supports it
        // Removed onChange calls due to SwiftCrossUI compatibility issues
    }

    // MARK: - View Components
    private var headerSection: some View {
        VStack {
            Text("Sound to Light Therapy")
                .font(.title)
            // TODO: Add accessibility traits when SwiftCrossUI supports them

            Text("Convert audio frequencies to light patterns")
                .font(.subheadline)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            // TODO: Add accessibility label when SwiftCrossUI supports them
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var audioResponseSection: some View {
        VStack(spacing: 15) {
            Text("🎵 Audio-Responsive Light Therapy")
                .font(.headline)
                .foregroundColor(.blue)

            if isPatternModeEnabled && isPatternAudioResponsive {
                Text("Pattern guides therapy types, frequencies sync to audio")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            } else if isPatternModeEnabled {
                Text("Pattern runs with fixed frequencies")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .multilineTextAlignment(.center)
            } else {
                Text("Flashlight automatically syncs to detected audio frequencies")
                    .font(.subheadline)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    .multilineTextAlignment(.center)
            }

            // Enhanced real-time audio analysis display
            VStack(spacing: 8) {
                // Input frequency with musical note
                HStack {
                    Text("Input Audio:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.1f", currentFrequency)) Hz")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        if !musicalNote.isEmpty {
                            Text("(\(musicalNote))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                        }
                        
                        if isHarmonic {
                            Text("🎵")
                                .font(.caption)
                        }
                    }
                }

                // Therapeutic output frequency
                HStack {
                    Text("Therapeutic Output:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    Text("\(String(format: "%.1f", therapeuticFrequency)) Hz")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                // Therapy type
                if !therapyType.isEmpty {
                    HStack {
                        Text("Therapy Type:")
                            .font(.caption)
                            .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                        Spacer()
                        Text(therapyType)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(therapyTypeColor(therapyType))
                    }
                }

                // Audio activity indicator with confidence
                HStack {
                    Text("Signal Quality:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(confidenceColor(confidence))
                            .frame(width: 12, height: 12)
                            .scaleEffect(confidence > 0.3 ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: confidence)
                        
                        Text("\(Int(confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(confidenceColor(confidence))
                    }
                }
            }
            .padding(.horizontal)
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var sessionControlSection: some View {
        VStack(spacing: 12) {
            // Main control buttons
            HStack(spacing: 20) {
                Button("Start Session") {
                    Task {
                        await startSession()
                    }
                }
                .disabled(isSessionActive)
                // TODO: Add accessibility labels and hints when SwiftCrossUI supports them
                .withHapticFeedback(.mediumImpact, respectReducedMotion: true)

                Button("Stop Session") {
                    Task {
                        await stopSession()
                    }
                }
                .disabled(!isSessionActive)
                // TODO: Add accessibility labels and hints when SwiftCrossUI supports them
                .withHapticFeedback(.lightImpact, respectReducedMotion: true)
            }
            
            // Session control buttons (pause/resume/skip) - only show during active sessions
            if isSessionActive {
                HStack(spacing: 16) {
                    Button(isSessionPaused ? "Resume" : "Pause") {
                        Task {
                            if isSessionPaused {
                                await resumeSession()
                            } else {
                                await pauseSession()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSessionPaused ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(8)
                    .withHapticFeedback(.lightImpact, respectReducedMotion: true)
                    
                    // Skip button only for pattern sessions
                    if isPatternModeEnabled {
                        Button("Skip Segment") {
                            Task {
                                await skipToNextSegment()
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                        .withHapticFeedback(.lightImpact, respectReducedMotion: true)
                    }
                }
                .font(.caption)
            }
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var statusDisplaySection: some View {
        VStack(spacing: 10) {
            Text("Session Status: \(sessionStatusText)")
                .font(.headline)
                .foregroundColor(sessionStatusColor)
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            Text("Current Frequency: \(String(format: "%.1f", currentFrequency)) Hz")
                .font(.body)
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            Text("Progress: \(Int(sessionProgress * 100))%")
                .font(.body)
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            ProgressView(value: sessionProgress)
            // TODO: Add accessibility support for progress view when SwiftCrossUI supports them
            
            // Pattern progress display
            if isSessionActive && isPatternModeEnabled, let pattern = selectedSessionPattern {
                patternProgressDisplay(pattern)
            }

            // Wake lock status indicator
            HStack {
                Text("Screen Lock:")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                Spacer()
                Text(isWakeLockActive ? "🔓 Disabled" : "🔒 Enabled")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isWakeLockActive ? .green : Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            }
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }
    
    private func patternProgressDisplay(_ pattern: SessionPattern) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🎵 Pattern: \(pattern.name)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            // Current segment info
            if let currentSegment = getCurrentActiveSegment(pattern: pattern) {
                HStack {
                    Text("Current:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    
                    Text(currentSegment.therapyType.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(therapyTypeColor(currentSegment.therapyType.rawValue))
                    
                    Spacer()
                    
                    let segmentProgress = getSegmentProgress(segment: currentSegment)
                    Text("\(Int(segmentProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                }
                
                // Segment progress bar
                ProgressView(value: getSegmentProgress(segment: currentSegment))
                    .progressViewStyle(LinearProgressViewStyle(tint: therapyTypeColor(currentSegment.therapyType.rawValue)))
                    .frame(height: 4)
            }
            
            // Next segment preview
            if let nextSegment = getNextSegment(pattern: pattern) {
                HStack {
                    Text("Next:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    
                    Text(nextSegment.therapyType.rawValue)
                        .font(.caption)
                        .foregroundColor(therapyTypeColor(nextSegment.therapyType.rawValue))
                    
                    Spacer()
                    
                    let timeToNext = getTimeToNextSegment(pattern: pattern)
                    Text("in \(formatDuration(timeToNext))")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                }
            }
        }
        .padding()
        .background(Color(hue: 0.8, saturation: 0.1, brightness: 0.95, opacity: 1.0))
        .cornerRadius(8)
    }
    
    private func getCurrentActiveSegment(pattern: SessionPattern) -> SessionPattern.TherapySegment? {
        guard let startTime = sessionStartTime else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return pattern.getActiveSegment(at: elapsed)
    }
    
    private func getNextSegment(pattern: SessionPattern) -> SessionPattern.TherapySegment? {
        guard let startTime = sessionStartTime else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return pattern.getNextSegment(after: elapsed)
    }
    
    private func getSegmentProgress(segment: SessionPattern.TherapySegment) -> Double {
        guard let startTime = sessionStartTime else { return 0.0 }
        let elapsed = Date().timeIntervalSince(startTime)
        let segmentElapsed = elapsed - segment.startTime
        return max(0.0, min(1.0, segmentElapsed / segment.duration))
    }
    
    private func getTimeToNextSegment(pattern: SessionPattern) -> TimeInterval {
        guard let startTime = sessionStartTime,
              let nextSegment = getNextSegment(pattern: pattern) else { return 0.0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0.0, nextSegment.startTime - elapsed)
    }
    
    private var sessionStatusText: String {
        if !isSessionActive {
            return "Inactive"
        } else if isSessionPaused {
            return "Paused"
        } else {
            return "Active"
        }
    }
    
    private var sessionStatusColor: Color {
        if !isSessionActive {
            return Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0)
        } else if isSessionPaused {
            return Color.orange
        } else {
            return Color.green
        }
    }
    
    private var sessionPatternSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎵 Session Pattern")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button(action: {
                    showingPatternLibrary = true
                }) {
                    Text("Browse")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            VStack(spacing: 8) {
                // Pattern mode toggle
                HStack {
                    Text("Pattern Mode:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    
                    Spacer()
                    
                    Button(action: {
                        isPatternModeEnabled.toggle()
                        if !isPatternModeEnabled {
                            selectedSessionPattern = nil
                        }
                    }) {
                        Text(isPatternModeEnabled ? "ON" : "OFF")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(isPatternModeEnabled ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isPatternModeEnabled ? Color.green : Color.gray.opacity(0.3))
                            .cornerRadius(6)
                    }
                }
                
                // Audio responsive toggle for pattern mode
                if isPatternModeEnabled {
                    HStack {
                        Text("Audio Responsive:")
                            .font(.caption)
                            .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                        
                        Spacer()
                        
                        Button(action: {
                            isPatternAudioResponsive.toggle()
                        }) {
                            Text(isPatternAudioResponsive ? "ON" : "OFF")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isPatternAudioResponsive ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(isPatternAudioResponsive ? Color.blue : Color.gray.opacity(0.3))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Audio responsive explanation
                    if isPatternAudioResponsive {
                        Text("Pattern guides therapy types, frequencies respond to audio input")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("Pattern runs with fixed frequencies, independent of audio")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // Selected pattern display
                if isPatternModeEnabled {
                    if let pattern = selectedSessionPattern {
                        selectedPatternDisplay(pattern)
                    } else {
                        Button("Select Pattern") {
                            showingPatternLibrary = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(hue: 0.3, saturation: 0.1, brightness: 0.95, opacity: 1.0))
        .cornerRadius(8)
        .sheet(isPresented: $showingPatternLibrary) {
            SessionPatternLibraryView(
                onPatternSelected: { pattern in
                    selectedSessionPattern = pattern
                    showingPatternLibrary = false
                },
                onClose: {
                    showingPatternLibrary = false
                }
            )
        }
        .sheet(isPresented: $showingPatternDesigner) {
            SessionPatternDesignerView(
                onSave: { pattern in
                    selectedSessionPattern = pattern
                    showingPatternDesigner = false
                },
                onCancel: {
                    showingPatternDesigner = false
                }
            )
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }
    
    private func selectedPatternDisplay(_ pattern: SessionPattern) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.name)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text(pattern.description)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(pattern.totalDuration))
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("\(pattern.segments.count) segments")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                }
            }
            
            // Pattern timeline preview
            HStack(spacing: 0) {
                ForEach(pattern.segments.indices, id: \.self) { index in
                    let segment = pattern.segments[index]
                    let widthRatio = segment.duration / pattern.totalDuration
                    
                    Rectangle()
                        .fill(therapyTypeColor(segment.therapyType.rawValue))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: widthRatio, anchor: .leading)
                }
            }
            .cornerRadius(3)
            
            // Action buttons
            HStack(spacing: 8) {
                Button("Change") {
                    showingPatternLibrary = true
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
                
                Button("Edit") {
                    showingPatternDesigner = true
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)
                
                Button("Clear") {
                    selectedSessionPattern = nil
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(6)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private var therapyTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎯 Therapy Type Control")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button(action: {
                    showTherapyTypeSelector.toggle()
                }) {
                    Text(showTherapyTypeSelector ? "Hide" : "Select")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            if showTherapyTypeSelector {
                VStack(spacing: 8) {
                    // Override toggle
                    HStack {
                        Text("Manual Override:")
                            .font(.caption)
                            .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                        
                        Spacer()
                        
                        Button(action: {
                            isTherapyTypeOverrideEnabled.toggle()
                            Task {
                                if isTherapyTypeOverrideEnabled {
                                    await sessionCoordinator.setTherapyTypeOverride(selectedTherapyType)
                                } else {
                                    await sessionCoordinator.setTherapyTypeOverride(nil)
                                }
                            }
                        }) {
                            Text(isTherapyTypeOverrideEnabled ? "ON" : "OFF")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isTherapyTypeOverrideEnabled ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(isTherapyTypeOverrideEnabled ? Color.green : Color.gray.opacity(0.3))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Therapy type buttons
                    if isTherapyTypeOverrideEnabled {
                        therapyTypeButtonsGrid
                    }
                }
            }
        }
        .padding()
        .background(Color(hue: 0.8, saturation: 0.1, brightness: 0.95, opacity: 1.0))
        .cornerRadius(8)
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }
    
    private var therapyTypeButtonsGrid: some View {
        VStack(spacing: 8) {
            Text("Select Therapy Type:")
                .font(.caption)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            
            // First row: Delta, Theta, Alpha
            HStack(spacing: 8) {
                therapyTypeButton(.delta)
                therapyTypeButton(.theta)
                therapyTypeButton(.alpha)
            }
            
            // Second row: Beta, Gamma
            HStack(spacing: 8) {
                therapyTypeButton(.beta)
                therapyTypeButton(.gamma)
                Spacer() // Balance the row
            }
        }
    }
    
    private func therapyTypeButton(_ type: TherapeuticFrequencyMapper.TherapyType) -> some View {
        Button(action: {
            selectedTherapyType = type
            Task {
                await sessionCoordinator.setTherapyTypeOverride(type)
            }
        }) {
            VStack(spacing: 4) {
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(selectedTherapyType == type ? .white : therapyTypeColor(type.rawValue))
                
                Text("\(String(format: "%.1f", type.frequencyRange.lowerBound))-\(String(format: "%.0f", type.frequencyRange.upperBound))Hz")
                    .font(.system(size: 10))
                    .foregroundColor(selectedTherapyType == type ? .white.opacity(0.8) : Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                selectedTherapyType == type 
                    ? therapyTypeColor(type.rawValue)
                    : therapyTypeColor(type.rawValue).opacity(0.2)
            )
            .cornerRadius(8)
        }
    }
    
    private var therapeuticRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🧠 Therapeutic Analysis")
                .font(.headline)
                .foregroundColor(.purple)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if therapeuticRecommendations.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.purple)
                                .fontWeight(.bold)
                            Text("Analyzing audio signal...")
                                .font(.caption)
                                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    } else {
                        ForEach(Array(therapeuticRecommendations.prefix(3).enumerated()), id: \.offset) { index, recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.purple)
                                    .fontWeight(.bold)
                                Text(recommendation)
                                    .font(.caption)
                                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 80)
        }
        .padding()
        .background(Color(hue: 0.8, saturation: 0.1, brightness: 0.95, opacity: 1.0))
        .cornerRadius(8)
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var emergencyStopSection: some View {
        Button("EMERGENCY STOP") {
            Task {
                await emergencyStop()
            }
        }
        .foregroundColor(.white)
        .background(Color.red)
        .cornerRadius(8)
        // TODO: Add accessibility labels, hints, and identifiers when SwiftCrossUI supports them
        .withHapticFeedback(.error, respectReducedMotion: false)  // Always provide haptic for emergency
    }

    private var settingsSection: some View {
        VStack {
            Text("Session Duration: \(Int(sessionDuration)) seconds")
                .font(.headline)
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            Slider(value: $sessionDuration, in: 60.0...600.0)
                // TODO: Add accessibility support for slider when SwiftCrossUI supports them
                .withHapticFeedback(.selection, respectReducedMotion: true)

            HStack {
                Text("60 sec")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                // TODO: Add accessibility label when SwiftCrossUI supports them

                Spacer()

                Text("600 sec")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                // TODO: Add accessibility label when SwiftCrossUI supports them
            }
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    // MARK: - Session Management
    private func startSession() async {
        do {
            if isPatternModeEnabled, let pattern = selectedSessionPattern {
                if isPatternAudioResponsive {
                    // Start audio-responsive pattern session
                    try await sessionCoordinator.startAudioResponsivePatternSession(pattern: pattern)
                    print("✅ Audio-responsive pattern session started: \(pattern.name)")
                } else {
                    // Start fixed pattern-based session
                    try await sessionCoordinator.startPatternBasedSession(pattern: pattern)
                    print("✅ Fixed pattern session started: \(pattern.name)")
                }
            } else {
                // Start audio-responsive session
                try await sessionCoordinator.startAudioResponsiveSession(duration: sessionDuration)
                print("✅ Audio-responsive therapy session started")
            }
            
            isSessionActive = true
            sessionStartTime = Date()

            // Start updating UI with real-time data
            Task {
                await updateSessionDataLoop()
            }

            // Generate haptic feedback for session start
            _ = HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)
        } catch {
            print("❌ Failed to start session: \(error)")
            // Generate error haptic feedback
            _ = HapticFeedbackSupport.generate(.error, respectReducedMotion: true)
        }
    }

    private func stopSession() async {
        await sessionCoordinator.stopSession()
        isSessionActive = false
        sessionStartTime = nil
        print("🛑 Therapy session stopped")
        // Generate haptic feedback for session stop
        _ = HapticFeedbackSupport.generate(.lightImpact, respectReducedMotion: true)
    }

    private func emergencyStop() async {
        await sessionCoordinator.stopSession()
        isSessionActive = false
        sessionStartTime = nil

        // Force disable wake lock for emergency stop
        await ScreenWakeLock.shared.forceDisableWakeLock()

        await AccessibilityAnnouncer.shared.announceEmergencyStop()
        // Always generate strong haptic for emergency stop
        _ = HapticFeedbackSupport.generate(.heavyImpact, respectReducedMotion: false)
    }
    
    private func pauseSession() async {
        do {
            try await sessionCoordinator.pauseSession()
            isSessionPaused = true
            print("⏸️ Session paused")
        } catch {
            print("❌ Failed to pause session: \(error)")
        }
    }
    
    private func resumeSession() async {
        do {
            try await sessionCoordinator.resumeSession()
            isSessionPaused = false
            print("▶️ Session resumed")
        } catch {
            print("❌ Failed to resume session: \(error)")
        }
    }
    
    private func skipToNextSegment() async {
        do {
            try await sessionCoordinator.skipToNextSegment()
            print("⏭️ Skipped to next segment")
        } catch {
            print("❌ Failed to skip segment: \(error)")
        }
    }

    private func announceProgressIfNeeded(_ progress: Double) async {
        let currentPercent = Int(progress * 100)
        // Announce progress every 25% to avoid overwhelming VoiceOver users
        if currentPercent != lastAnnouncedProgress && currentPercent % 25 == 0 {
            lastAnnouncedProgress = currentPercent
            await AccessibilityAnnouncer.shared.announceSessionProgress(progress)
        }
    }

    private func updateSessionDataLoop() async {
        while isSessionActive {
            await updateSessionState()
            try? await Task.sleep(nanoseconds: 250_000_000) // Update every 250ms
        }
    }

    private func updateSessionState() async {
        let activeState = await sessionCoordinator.getSessionState()
        isSessionActive = activeState

        if activeState {
            currentFrequency = await sessionCoordinator.getCurrentFrequency()
            sessionProgress = await sessionCoordinator.getAdjustedSessionProgress()
            isSessionPaused = await sessionCoordinator.isSessionPaused()
            
            // Get enhanced therapeutic information
            if currentFrequency > 0 {
                let therapeuticMapping = await sessionCoordinator.getTherapeuticRecommendations(
                    for: currentFrequency, 
                    confidence: 1.0
                )
                
                therapeuticFrequency = therapeuticMapping.therapeuticFrequency
                musicalNote = "\(therapeuticMapping.harmonicAnalysis.closestNote.rawValue)\(therapeuticMapping.harmonicAnalysis.octave)"
                therapyType = therapeuticMapping.therapyType.rawValue
                isHarmonic = therapeuticMapping.harmonicAnalysis.isHarmonic
                confidence = therapeuticMapping.mappingConfidence
                therapeuticRecommendations = therapeuticMapping.recommendations
            }
            
            // Sync therapy type override state (but not during pattern sessions)
            let isPatternSession = await sessionCoordinator.isPatternBasedSession()
            if !isPatternSession {
                let currentOverride = await sessionCoordinator.getCurrentTherapyTypeOverride()
                if currentOverride != selectedTherapyType {
                    selectedTherapyType = currentOverride
                }
                isTherapyTypeOverrideEnabled = (currentOverride != nil)
            }

            // Announce progress if needed
            await announceProgressIfNeeded(sessionProgress)
        }

        // Update wake lock status
        isWakeLockActive = await ScreenWakeLock.shared.isActive()
    }

    // MARK: - Color Helpers
    private func accessibleColorToColor(_ accessibleColor: AccessibleColor) -> Color {
        return Color(
            red: Double(accessibleColor.red),
            green: Double(accessibleColor.green),
            blue: Double(accessibleColor.blue),
            opacity: Double(accessibleColor.alpha)
        )
    }
    
    private func therapyTypeColor(_ therapyType: String) -> Color {
        switch therapyType {
        case "Delta":
            return Color.purple  // Deep sleep, healing
        case "Theta":
            return Color.blue    // Meditation, creativity
        case "Alpha":
            return Color.green   // Relaxation, learning
        case "Beta":
            return Color.orange  // Active thinking
        case "Gamma":
            return Color.red     // High-level cognition
        default:
            return Color.gray
        }
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.7 {
            return Color.green      // High confidence
        } else if confidence > 0.4 {
            return Color.orange     // Medium confidence
        } else if confidence > 0.1 {
            return Color.yellow     // Low confidence
        } else {
            return Color.gray       // Very low confidence
        }
    }
}
