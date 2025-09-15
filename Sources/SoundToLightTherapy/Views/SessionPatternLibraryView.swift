import Foundation
import SwiftUI

/// Session pattern library with search, filtering, and management capabilities
public struct SessionPatternLibraryView: SwiftUI.View {
    
    // MARK: - State Properties
    
    @State private var patterns: [SessionPattern] = []
    @State private var filteredPatterns: [SessionPattern] = []
    @State private var searchText: String = ""
    @State private var selectedFilter: PatternFilter = .all
    @State private var selectedPattern: SessionPattern? = nil
    @State private var showingPatternDetails = false
    @State private var showingPatternDesigner = false
    @State private var showingDeleteConfirmation = false
    @State private var patternToDelete: SessionPattern? = nil
    @State private var showingExportOptions = false
    @State private var showingImportOptions = false
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    // Pattern management
    @State private var patternManager: SessionPatternManager? = nil
    @State private var patternStatistics: PatternStatistics? = nil
    
    // Callbacks
    public let onPatternSelected: ((SessionPattern) -> Void)?
    public let onClose: (() -> Void)?
    
    public init(
        onPatternSelected: ((SessionPattern) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.onPatternSelected = onPatternSelected
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection
            
            // Search and filter section
            searchAndFilterSection
            
            // Statistics section
            if let stats = patternStatistics {
                statisticsSection(stats)
            }
            
            // Patterns grid
            if isLoading {
                loadingSection
            } else if filteredPatterns.isEmpty {
                emptyStateSection
            } else {
                patternsGridSection
            }
            
            // Action buttons
            actionButtonsSection
        }
        .padding()
        .frame(maxWidth: 1000)
        .background(Color(hue: 0.6, saturation: 0.05, brightness: 0.98, opacity: 1.0))
        .onAppear {
            initializeAndLoadPatterns()
        }
        .onChange(of: searchText) {
            filterPatterns()
        }
        .onChange(of: selectedFilter) {
            filterPatterns()
        }
        .sheet(isPresented: $showingPatternDesigner) {
            SessionPatternDesignerView(
                existingPattern: selectedPattern,
                onSave: { pattern in
                    showingPatternDesigner = false
                    loadPatterns()
                },
                onCancel: {
                    showingPatternDesigner = false
                    selectedPattern = nil
                }
            )
        }
        .alert("Delete Pattern", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                patternToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let pattern = patternToDelete {
                    deletePattern(pattern)
                }
            }
        } message: {
            if let pattern = patternToDelete {
                Text("Are you sure you want to delete '\(pattern.name)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack {
            HStack {
                Text("🎵 Session Pattern Library")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if let onClose = onClose {
                    Button("Close") {
                        onClose()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
            }
            
            Text("Manage and select therapeutic session patterns")
                .font(.subheadline)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                .multilineTextAlignment(.center)
        }
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                TextField("Search patterns...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
                }
            }
            
            // Filter options
            HStack {
                Text("Filter:")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                
                ForEach(PatternFilter.allCases, id: \.self) { filter in
                    Button(filter.displayName) {
                        selectedFilter = filter
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                    .cornerRadius(4)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private func statisticsSection(_ stats: PatternStatistics) -> some View {
        HStack(spacing: 20) {
            statisticItem("Total", value: "\(stats.totalPatterns)")
            statisticItem("Default", value: "\(stats.defaultPatterns)")
            statisticItem("Custom", value: "\(stats.customPatterns)")
            statisticItem("Avg Duration", value: formatDuration(stats.averageDuration))
            
            Spacer()
        }
        .padding()
        .background(Color(hue: 0.2, saturation: 0.1, brightness: 0.95, opacity: 1.0))
        .cornerRadius(8)
    }
    
    private func statisticItem(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text(label)
                .font(.caption)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading patterns...")
                .font(.headline)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
        }
        .frame(height: 200)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Text("📭")
                .font(.system(size: 60))
            
            Text("No patterns found")
                .font(.headline)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            
            if searchText.isEmpty && selectedFilter == .all {
                Text("Create your first pattern to get started")
                    .font(.subheadline)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                
                Button("Create Pattern") {
                    selectedPattern = nil
                    showingPatternDesigner = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            } else {
                Text("Try adjusting your search or filter")
                    .font(.subheadline)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            }
        }
        .frame(height: 200)
    }
    
    private var patternsGridSection: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(filteredPatterns) { pattern in
                    patternCard(pattern)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 500)
    }
    
    private func patternCard(_ pattern: SessionPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if pattern.isDefault {
                        Text("Default Pattern")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Action menu
                Menu {
                    Button("Select") {
                        onPatternSelected?(pattern)
                    }
                    
                    Button("Edit") {
                        selectedPattern = pattern
                        showingPatternDesigner = true
                    }
                    
                    Button("Duplicate") {
                        duplicatePattern(pattern)
                    }
                    
                    Button("Export") {
                        exportPattern(pattern)
                    }
                    
                    if !pattern.isDefault {
                        Button("Delete", role: .destructive) {
                            patternToDelete = pattern
                            showingDeleteConfirmation = true
                        }
                    }
                } label: {
                    Text("⋯")
                        .font(.title2)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                }
            }
            
            // Description
            Text(pattern.description)
                .font(.caption)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Pattern info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Duration:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    Text(formatDuration(pattern.totalDuration))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Segments:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    Text("\(pattern.segments.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            // Therapy types preview
            HStack(spacing: 4) {
                ForEach(Array(Set(pattern.segments.map { $0.therapyType })).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { therapyType in
                    Text(therapyType.rawValue)
                        .font(.system(size: 10))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(therapyTypeColor(therapyType).opacity(0.3))
                        .foregroundColor(therapyTypeColor(therapyType))
                        .cornerRadius(3)
                }
                Spacer()
            }
            
            // Timeline preview
            patternTimelinePreview(pattern)
            
            // Select button
            Button("Select Pattern") {
                onPatternSelected?(pattern)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func patternTimelinePreview(_ pattern: SessionPattern) -> some View {
        HStack(spacing: 0) {
            ForEach(pattern.segments.indices, id: \.self) { index in
                let segment = pattern.segments[index]
                let widthRatio = segment.duration / pattern.totalDuration
                
                Rectangle()
                    .fill(therapyTypeColor(segment.therapyType))
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: widthRatio, anchor: .leading)
            }
        }
        .cornerRadius(4)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button("Create New") {
                selectedPattern = nil
                showingPatternDesigner = true
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Import") {
                showingImportOptions = true
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Refresh") {
                loadPatterns()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(8)
            
            Spacer()
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeAndLoadPatterns() {
        Task {
            do {
                patternManager = try SessionPatternManager()
                try await patternManager?.initialize()
                await loadPatterns()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to initialize: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func loadPatterns() {
        Task {
            do {
                await MainActor.run {
                    isLoading = true
                    errorMessage = nil
                }
                
                let loadedPatterns = try await patternManager?.getAllPatterns() ?? []
                let stats = try await patternManager?.getPatternStatistics()
                
                await MainActor.run {
                    patterns = loadedPatterns
                    patternStatistics = stats
                    filterPatterns()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load patterns: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func filterPatterns() {
        var filtered = patterns
        
        // Apply search filter
        if !searchText.isEmpty {
            let lowercaseSearch = searchText.lowercased()
            filtered = filtered.filter { pattern in
                pattern.name.lowercased().contains(lowercaseSearch) ||
                pattern.description.lowercased().contains(lowercaseSearch)
            }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .default:
            filtered = filtered.filter { $0.isDefault }
        case .custom:
            filtered = filtered.filter { !$0.isDefault }
        case .short:
            filtered = filtered.filter { $0.totalDuration <= 600 } // 10 minutes or less
        case .long:
            filtered = filtered.filter { $0.totalDuration > 600 }
        }
        
        filteredPatterns = filtered
    }
    
    private func deletePattern(_ pattern: SessionPattern) {
        Task {
            do {
                try await patternManager?.deletePattern(id: pattern.id)
                await loadPatterns()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete pattern: \(error.localizedDescription)"
                }
            }
        }
        patternToDelete = nil
    }
    
    private func duplicatePattern(_ pattern: SessionPattern) {
        Task {
            do {
                let newName = "Copy of \(pattern.name)"
                _ = try await patternManager?.duplicatePattern(id: pattern.id, newName: newName)
                await loadPatterns()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to duplicate pattern: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportPattern(_ pattern: SessionPattern) {
        Task {
            do {
                let data = try await patternManager?.exportPattern(id: pattern.id)
                let shareText = try await patternManager?.sharePattern(id: pattern.id)
                
                // TODO: Implement actual file sharing (requires platform-specific implementation)
                // For now, we'll just log the shareable text
                if let shareText = shareText {
                    print("✅ Pattern ready for sharing:")
                    print(shareText)
                }
                
                print("✅ Exported pattern: \(pattern.name)")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to export pattern: \(error.localizedDescription)"
                }
            }
        }
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

// MARK: - Supporting Types

/// Pattern filter options
public enum PatternFilter: String, CaseIterable, Sendable {
    case all = "All"
    case `default` = "Default"
    case custom = "Custom"
    case short = "Short"
    case long = "Long"
    
    public var displayName: String {
        return rawValue
    }
}