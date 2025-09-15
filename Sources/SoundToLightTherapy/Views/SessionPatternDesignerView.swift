import Foundation
import SwiftUI

/// Session pattern designer with drag-and-drop therapy type segments
public struct SessionPatternDesignerView: SwiftUI.View {
    
    // MARK: - State Properties
    
    @State private var patternName: String = ""
    @State private var patternDescription: String = ""
    @State private var totalDuration: TimeInterval = 600  // 10 minutes default
    @State private var segments: [SessionPattern.TherapySegment] = []
    @State private var selectedSegmentId: UUID? = nil
    @State private var showingValidation = false
    @State private var validationResult: SessionPattern.ValidationResult? = nil
    @State private var showingSaveDialog = false
    @State private var showingPreview = false
    @State private var isEditing = false
    
    // Pattern management
    @State private var patternManager: SessionPatternManager? = nil
    @State private var existingPattern: SessionPattern? = nil
    
    // Drag and drop state
    @State private var draggedSegment: SessionPattern.TherapySegment? = nil
    @State private var dropTargetIndex: Int? = nil
    
    // UI state
    @State private var showingTherapyTypeSelector = false
    @State private var selectedTherapyType: TherapeuticFrequencyMapper.TherapyType = .alpha
    
    // Callbacks
    public let onSave: ((SessionPattern) -> Void)?
    public let onCancel: (() -> Void)?
    
    public init(
        existingPattern: SessionPattern? = nil,
        onSave: ((SessionPattern) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.existingPattern = existingPattern
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state from existing pattern
        if let pattern = existingPattern {
            self._patternName = State(initialValue: pattern.name)
            self._patternDescription = State(initialValue: pattern.description)
            self._totalDuration = State(initialValue: pattern.totalDuration)
            self._segments = State(initialValue: pattern.segments)
            self._isEditing = State(initialValue: true)
        }
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection
            
            // Pattern info section
            patternInfoSection
            
            // Timeline section
            timelineSection
            
            // Therapy type selector
            if showingTherapyTypeSelector {
                therapyTypeSelectorSection
            }
            
            // Segments list
            segmentsListSection
            
            // Action buttons
            actionButtonsSection
            
            // Validation results
            if showingValidation, let validation = validationResult {
                validationSection(validation)
            }
            
            // Preview
            if showingPreview {
                previewSection
            }
        }
        .padding()
        .frame(maxWidth: 800)
        .background(Color(hue: 0.6, saturation: 0.05, brightness: 0.98, opacity: 1.0))
        .onAppear {
            initializePatternManager()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack {
            Text(isEditing ? "Edit Session Pattern" : "Create Session Pattern")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text("Design custom therapy sequences with precise timing")
                .font(.subheadline)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                .multilineTextAlignment(.center)
        }
    }
    
    private var patternInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📝 Pattern Information")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name:")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                
                TextField("Enter pattern name", text: $patternName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description:")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                
                TextField("Enter pattern description", text: $patternDescription)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Duration: \(formatDuration(totalDuration))")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                
                Slider(value: $totalDuration, in: 60...3600, step: 30) // 1 minute to 1 hour
                    .onChange(of: totalDuration) {
                        adjustSegmentsToFitDuration()
                    }
                
                HStack {
                    Text("1 min")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    Text("60 min")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⏱️ Timeline Preview")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button("Add Segment") {
                    showingTherapyTypeSelector.toggle()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(8)
            }
            
            // Timeline visualization
            timelineVisualization
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private var timelineVisualization: some View {
        VStack(spacing: 8) {
            // Time markers
            HStack {
                ForEach(0..<Int(totalDuration / 60) + 1, id: \.self) { minute in
                    if minute % max(1, Int(totalDuration / 600)) == 0 {  // Show markers based on duration
                        VStack {
                            Text("\(minute)m")
                                .font(.caption2)
                                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                            Rectangle()
                                .fill(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                                .frame(width: 1, height: 8)
                        }
                        if minute < Int(totalDuration / 60) {
                            Spacer()
                        }
                    }
                }
            }
            
            // Segments visualization
            HStack(spacing: 0) {
                ForEach(segments.indices, id: \.self) { index in
                    let segment = segments[index]
                    let widthRatio = segment.duration / totalDuration
                    
                    Rectangle()
                        .fill(therapyTypeColor(segment.therapyType))
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: widthRatio, anchor: .leading)
                        .overlay(
                            Text(segment.therapyType.rawValue)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 1)
                        )
                        .onTapGesture {
                            selectedSegmentId = segment.id
                        }
                        .overlay(
                            selectedSegmentId == segment.id ? 
                            Rectangle()
                                .stroke(Color.yellow, lineWidth: 3)
                            : nil
                        )
                }
                
                // Empty space if segments don't fill duration
                let usedDuration = segments.reduce(0) { $0 + $1.duration }
                if usedDuration < totalDuration {
                    let remainingRatio = (totalDuration - usedDuration) / totalDuration
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: remainingRatio, anchor: .leading)
                        .overlay(
                            Text("Empty")
                                .font(.caption2)
                                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                        )
                }
            }
            .cornerRadius(4)
        }
    }
    
    private var therapyTypeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎯 Add Therapy Segment")
                .font(.headline)
                .foregroundColor(.green)
            
            // Therapy type selection
            VStack(spacing: 8) {
                Text("Select Therapy Type:")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(TherapeuticFrequencyMapper.TherapyType.allCases, id: \.self) { therapyType in
                        therapyTypeSelectionButton(therapyType)
                    }
                }
            }
            
            HStack {
                Button("Add Segment") {
                    addSegment(therapyType: selectedTherapyType)
                    showingTherapyTypeSelector = false
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Cancel") {
                    showingTherapyTypeSelector = false
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(hue: 0.3, saturation: 0.1, brightness: 0.95, opacity: 1.0))
        .cornerRadius(8)
    }
    
    private func therapyTypeSelectionButton(_ therapyType: TherapeuticFrequencyMapper.TherapyType) -> some View {
        Button(action: {
            selectedTherapyType = therapyType
        }) {
            VStack(spacing: 4) {
                Text(therapyType.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(selectedTherapyType == therapyType ? .white : therapyTypeColor(therapyType))
                
                Text("\(String(format: "%.1f", therapyType.frequencyRange.lowerBound))-\(String(format: "%.0f", therapyType.frequencyRange.upperBound))Hz")
                    .font(.system(size: 10))
                    .foregroundColor(selectedTherapyType == therapyType ? .white.opacity(0.8) : Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                selectedTherapyType == therapyType 
                    ? therapyTypeColor(therapyType)
                    : therapyTypeColor(therapyType).opacity(0.2)
            )
            .cornerRadius(8)
        }
    }
    
    private var segmentsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📋 Therapy Segments")
                .font(.headline)
                .foregroundColor(.orange)
            
            if segments.isEmpty {
                Text("No segments added yet. Use 'Add Segment' to create your therapy pattern.")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(segments.indices, id: \.self) { index in
                            segmentRow(segments[index], index: index)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private func segmentRow(_ segment: SessionPattern.TherapySegment, index: Int) -> some View {
        HStack(spacing: 12) {
            // Therapy type indicator
            Rectangle()
                .fill(therapyTypeColor(segment.therapyType))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(segment.therapyType.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(therapyTypeColor(segment.therapyType))
                    
                    Spacer()
                    
                    Text(formatDuration(segment.duration))
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                }
                
                Text("Start: \(formatDuration(segment.startTime)) | Intensity: \(Int(segment.intensity * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button("Edit") {
                    selectedSegmentId = segment.id
                    // TODO: Show segment editor
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
                
                Button("Delete") {
                    deleteSegment(at: index)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
            }
        }
        .padding()
        .background(selectedSegmentId == segment.id ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onTapGesture {
            selectedSegmentId = segment.id
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button("Validate") {
                validatePattern()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Preview") {
                showingPreview.toggle()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Spacer()
            
            Button("Cancel") {
                onCancel?()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            
            Button("Save Pattern") {
                savePattern()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(patternName.isEmpty ? Color.gray : Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(patternName.isEmpty)
        }
    }
    
    private func validationSection(_ validation: SessionPattern.ValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(validation.isValid ? "✅ Validation Passed" : "❌ Validation Failed")
                    .font(.headline)
                    .foregroundColor(validation.isValid ? .green : .red)
                
                Spacer()
                
                Button("Dismiss") {
                    showingValidation = false
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
            }
            
            if !validation.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    ForEach(validation.errors, id: \.rawValue) { error in
                        Text("• \(error.rawValue)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !validation.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    ForEach(validation.warnings, id: \.rawValue) { warning in
                        Text("• \(warning.rawValue)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(validation.isValid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("👁️ Pattern Preview")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Spacer()
                
                Button("Hide") {
                    showingPreview = false
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pattern: \(patternName.isEmpty ? "Unnamed Pattern" : patternName)")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    Text("Duration: \(formatDuration(totalDuration))")
                        .font(.caption)
                    
                    Text("Segments: \(segments.count)")
                        .font(.caption)
                    
                    Divider()
                    
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]
                        HStack {
                            Text("\(formatDuration(segment.startTime)) - \(formatDuration(segment.endTime))")
                                .font(.caption)
                                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                            
                            Text(segment.therapyType.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(therapyTypeColor(segment.therapyType))
                            
                            Spacer()
                            
                            Text("\(Int(segment.intensity * 100))%")
                                .font(.caption)
                                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color(hue: 0.8, saturation: 0.1, brightness: 0.95, opacity: 1.0))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func initializePatternManager() {
        Task {
            do {
                patternManager = try SessionPatternManager()
                try await patternManager?.initialize()
            } catch {
                print("❌ Failed to initialize pattern manager: \(error)")
            }
        }
    }
    
    private func addSegment(therapyType: TherapeuticFrequencyMapper.TherapyType) {
        let startTime = segments.reduce(0) { $0 + $1.duration }
        let remainingDuration = totalDuration - startTime
        let segmentDuration = min(max(60, remainingDuration / 3), remainingDuration) // At least 1 minute, max 1/3 of remaining
        
        let newSegment = SessionPattern.TherapySegment(
            therapyType: therapyType,
            duration: segmentDuration,
            startTime: startTime,
            intensity: 0.8
        )
        
        segments.append(newSegment)
        selectedSegmentId = newSegment.id
    }
    
    private func deleteSegment(at index: Int) {
        guard index < segments.count else { return }
        
        segments.remove(at: index)
        
        // Recalculate start times
        var currentTime: TimeInterval = 0
        for i in 0..<segments.count {
            segments[i] = SessionPattern.TherapySegment(
                id: segments[i].id,
                therapyType: segments[i].therapyType,
                duration: segments[i].duration,
                startTime: currentTime,
                targetFrequency: segments[i].targetFrequency,
                intensity: segments[i].intensity,
                transitionType: segments[i].transitionType
            )
            currentTime += segments[i].duration
        }
        
        selectedSegmentId = nil
    }
    
    private func adjustSegmentsToFitDuration() {
        guard !segments.isEmpty else { return }
        
        let currentTotalDuration = segments.reduce(0) { $0 + $1.duration }
        
        if currentTotalDuration != totalDuration {
            let scaleFactor = totalDuration / currentTotalDuration
            var currentTime: TimeInterval = 0
            
            for i in 0..<segments.count {
                let newDuration = segments[i].duration * scaleFactor
                segments[i] = SessionPattern.TherapySegment(
                    id: segments[i].id,
                    therapyType: segments[i].therapyType,
                    duration: newDuration,
                    startTime: currentTime,
                    targetFrequency: segments[i].targetFrequency,
                    intensity: segments[i].intensity,
                    transitionType: segments[i].transitionType
                )
                currentTime += newDuration
            }
        }
    }
    
    private func validatePattern() {
        let pattern = createPatternFromCurrentState()
        validationResult = pattern.validate()
        showingValidation = true
    }
    
    private func savePattern() {
        let pattern = createPatternFromCurrentState()
        
        Task {
            do {
                try await patternManager?.savePattern(pattern)
                onSave?(pattern)
            } catch {
                print("❌ Failed to save pattern: \(error)")
                // TODO: Show error alert
            }
        }
    }
    
    private func createPatternFromCurrentState() -> SessionPattern {
        return SessionPattern(
            id: existingPattern?.id ?? UUID(),
            name: patternName,
            description: patternDescription,
            totalDuration: totalDuration,
            segments: segments,
            createdAt: existingPattern?.createdAt ?? Date(),
            modifiedAt: Date(),
            isDefault: false
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func therapyTypeColor(_ therapyType: TherapeuticFrequencyMapper.TherapyType) -> Color {
        switch therapyType {
        case .delta:
            return Color.purple
        case .theta:
            return Color.blue
        case .alpha:
            return Color.green
        case .beta:
            return Color.orange
        case .gamma:
            return Color.red
        }
    }
}