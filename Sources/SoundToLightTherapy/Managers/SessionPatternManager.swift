import Foundation

/// Session pattern manager for saving, loading, and managing custom therapy patterns
public actor SessionPatternManager {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let patternsDirectory: URL
    private var cachedPatterns: [SessionPattern] = []
    private var isInitialized = false
    
    // MARK: - Initialization
    
    public init() throws {
        // Create patterns directory in app documents
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        patternsDirectory = documentsPath.appendingPathComponent("TherapyPatterns")
        
        // Create directory if it doesn't exist
        try fileManager.createDirectory(at: patternsDirectory, withIntermediateDirectories: true)
        
        print("✅ SessionPatternManager initialized with directory: \(patternsDirectory.path)")
    }
    
    // MARK: - Pattern Management
    
    /// Initialize the pattern manager and load existing patterns
    public func initialize() async throws {
        guard !isInitialized else { return }
        
        try await loadAllPatterns()
        
        // Create default patterns if none exist
        if cachedPatterns.isEmpty {
            try await createDefaultPatterns()
        }
        
        isInitialized = true
        print("✅ SessionPatternManager initialized with \(cachedPatterns.count) patterns")
    }
    
    /// Get all available patterns
    public func getAllPatterns() async throws -> [SessionPattern] {
        if !isInitialized {
            try await initialize()
        }
        return cachedPatterns.sorted { pattern1, pattern2 in
            // Sort by: default patterns first, then by name
            if pattern1.isDefault != pattern2.isDefault {
                return pattern1.isDefault
            }
            return pattern1.name < pattern2.name
        }
    }
    
    /// Get a specific pattern by ID
    public func getPattern(id: UUID) async throws -> SessionPattern? {
        if !isInitialized {
            try await initialize()
        }
        return cachedPatterns.first { $0.id == id }
    }
    
    /// Get patterns by name (case-insensitive search)
    public func searchPatterns(name: String) async throws -> [SessionPattern] {
        if !isInitialized {
            try await initialize()
        }
        let lowercaseName = name.lowercased()
        return cachedPatterns.filter { 
            $0.name.lowercased().contains(lowercaseName) || 
            $0.description.lowercased().contains(lowercaseName)
        }
    }
    
    /// Save a new pattern or update an existing one
    public func savePattern(_ pattern: SessionPattern) async throws {
        if !isInitialized {
            try await initialize()
        }
        
        // Validate pattern before saving
        let validation = pattern.validate()
        guard validation.isValid else {
            throw SessionPatternError.validationFailed(validation.errors)
        }
        
        // Check for name conflicts (excluding the pattern being updated)
        let existingPattern = cachedPatterns.first { $0.name == pattern.name && $0.id != pattern.id }
        if existingPattern != nil {
            throw SessionPatternError.nameAlreadyExists(pattern.name)
        }
        
        // Save to file
        let filename = "\(pattern.id.uuidString).json"
        let fileURL = patternsDirectory.appendingPathComponent(filename)
        
        do {
            let data = try JSONEncoder().encode(pattern)
            try data.write(to: fileURL)
            
            // Update cache
            if let index = cachedPatterns.firstIndex(where: { $0.id == pattern.id }) {
                cachedPatterns[index] = pattern
                print("✅ Updated pattern: \(pattern.name)")
            } else {
                cachedPatterns.append(pattern)
                print("✅ Saved new pattern: \(pattern.name)")
            }
            
        } catch {
            throw SessionPatternError.saveFailed(error)
        }
    }
    
    /// Delete a pattern by ID
    public func deletePattern(id: UUID) async throws {
        if !isInitialized {
            try await initialize()
        }
        
        guard let pattern = cachedPatterns.first(where: { $0.id == id }) else {
            throw SessionPatternError.patternNotFound(id)
        }
        
        // Prevent deletion of default patterns
        if pattern.isDefault {
            throw SessionPatternError.cannotDeleteDefault
        }
        
        // Delete file
        let filename = "\(id.uuidString).json"
        let fileURL = patternsDirectory.appendingPathComponent(filename)
        
        do {
            try fileManager.removeItem(at: fileURL)
            
            // Remove from cache
            cachedPatterns.removeAll { $0.id == id }
            print("✅ Deleted pattern: \(pattern.name)")
            
        } catch {
            throw SessionPatternError.deleteFailed(error)
        }
    }
    
    /// Duplicate a pattern with a new name
    public func duplicatePattern(id: UUID, newName: String) async throws -> SessionPattern {
        if !isInitialized {
            try await initialize()
        }
        
        guard let originalPattern = cachedPatterns.first(where: { $0.id == id }) else {
            throw SessionPatternError.patternNotFound(id)
        }
        
        // Create new pattern with updated name and new ID
        let duplicatedPattern = SessionPattern(
            name: newName,
            description: "Copy of \(originalPattern.description)",
            totalDuration: originalPattern.totalDuration,
            segments: originalPattern.segments,
            isDefault: false
        )
        
        try await savePattern(duplicatedPattern)
        return duplicatedPattern
    }
    
    /// Export pattern to JSON data
    public func exportPattern(id: UUID) async throws -> Data {
        if !isInitialized {
            try await initialize()
        }
        
        guard let pattern = cachedPatterns.first(where: { $0.id == id }) else {
            throw SessionPatternError.patternNotFound(id)
        }
        
        do {
            return try JSONEncoder().encode(pattern)
        } catch {
            throw SessionPatternError.exportFailed(error)
        }
    }
    
    /// Import pattern from JSON data
    public func importPattern(from data: Data, newName: String? = nil) async throws -> SessionPattern {
        if !isInitialized {
            try await initialize()
        }
        
        do {
            var pattern = try JSONDecoder().decode(SessionPattern.self, from: data)
            
            // Create new ID and update name if provided
            pattern = SessionPattern(
                name: newName ?? pattern.name,
                description: pattern.description,
                totalDuration: pattern.totalDuration,
                segments: pattern.segments,
                isDefault: false
            )
            
            try await savePattern(pattern)
            return pattern
            
        } catch {
            throw SessionPatternError.importFailed(error)
        }
    }
    
    /// Share pattern as formatted text for easy sharing
    public func sharePattern(id: UUID) async throws -> String {
        if !isInitialized {
            try await initialize()
        }
        
        guard let pattern = cachedPatterns.first(where: { $0.id == id }) else {
            throw SessionPatternError.patternNotFound(id)
        }
        
        var shareText = "🎵 Therapy Pattern: \(pattern.name)\n"
        shareText += "📝 Description: \(pattern.description)\n"
        shareText += "⏱️ Duration: \(formatDuration(pattern.totalDuration))\n"
        shareText += "🔢 Segments: \(pattern.segments.count)\n\n"
        shareText += "📋 Pattern Timeline:\n"
        
        for (index, segment) in pattern.segments.enumerated() {
            let startTime = formatDuration(segment.startTime)
            let endTime = formatDuration(segment.endTime)
            let intensity = Int(segment.intensity * 100)
            
            shareText += "\(index + 1). \(segment.therapyType.rawValue) (\(startTime) - \(endTime)) - \(intensity)%\n"
        }
        
        shareText += "\n🧠 Created with Sound to Light Therapy App"
        return shareText
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
    
    /// Get pattern statistics
    public func getPatternStatistics() async throws -> PatternStatistics {
        if !isInitialized {
            try await initialize()
        }
        
        let totalPatterns = cachedPatterns.count
        let defaultPatterns = cachedPatterns.filter { $0.isDefault }.count
        let customPatterns = totalPatterns - defaultPatterns
        
        let averageDuration = cachedPatterns.reduce(0) { $0 + $1.totalDuration } / Double(max(1, totalPatterns))
        
        let therapyTypeUsage = Dictionary(grouping: cachedPatterns.flatMap { $0.segments }) { $0.therapyType }
            .mapValues { $0.count }
        
        return PatternStatistics(
            totalPatterns: totalPatterns,
            defaultPatterns: defaultPatterns,
            customPatterns: customPatterns,
            averageDuration: averageDuration,
            therapyTypeUsage: therapyTypeUsage
        )
    }
    
    // MARK: - Private Methods
    
    private func loadAllPatterns() async throws {
        cachedPatterns.removeAll()
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: patternsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            for fileURL in jsonFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let pattern = try JSONDecoder().decode(SessionPattern.self, from: data)
                    cachedPatterns.append(pattern)
                } catch {
                    print("⚠️ Failed to load pattern from \(fileURL.lastPathComponent): \(error)")
                    // Continue loading other patterns
                }
            }
            
            print("✅ Loaded \(cachedPatterns.count) patterns from storage")
            
        } catch {
            print("⚠️ Failed to load patterns directory: \(error)")
            // Continue with empty cache - default patterns will be created
        }
    }
    
    private func createDefaultPatterns() async throws {
        let defaultPatterns = SessionPattern.createDefaultPatterns()
        
        for pattern in defaultPatterns {
            do {
                let filename = "\(pattern.id.uuidString).json"
                let fileURL = patternsDirectory.appendingPathComponent(filename)
                let data = try JSONEncoder().encode(pattern)
                try data.write(to: fileURL)
                cachedPatterns.append(pattern)
            } catch {
                print("⚠️ Failed to create default pattern \(pattern.name): \(error)")
            }
        }
        
        print("✅ Created \(defaultPatterns.count) default patterns")
    }
}

// MARK: - Supporting Types

/// Pattern statistics for analytics
public struct PatternStatistics: Sendable {
    public let totalPatterns: Int
    public let defaultPatterns: Int
    public let customPatterns: Int
    public let averageDuration: TimeInterval
    public let therapyTypeUsage: [TherapeuticFrequencyMapper.TherapyType: Int]
    
    public init(
        totalPatterns: Int,
        defaultPatterns: Int,
        customPatterns: Int,
        averageDuration: TimeInterval,
        therapyTypeUsage: [TherapeuticFrequencyMapper.TherapyType: Int]
    ) {
        self.totalPatterns = totalPatterns
        self.defaultPatterns = defaultPatterns
        self.customPatterns = customPatterns
        self.averageDuration = averageDuration
        self.therapyTypeUsage = therapyTypeUsage
    }
}

/// Session pattern management errors
public enum SessionPatternError: Error, LocalizedError {
    case validationFailed([SessionPattern.ValidationError])
    case nameAlreadyExists(String)
    case patternNotFound(UUID)
    case cannotDeleteDefault
    case saveFailed(Error)
    case deleteFailed(Error)
    case exportFailed(Error)
    case importFailed(Error)
    case initializationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "Pattern validation failed: \(errors.map { $0.rawValue }.joined(separator: ", "))"
        case .nameAlreadyExists(let name):
            return "A pattern with the name '\(name)' already exists"
        case .patternNotFound(let id):
            return "Pattern with ID \(id) not found"
        case .cannotDeleteDefault:
            return "Cannot delete default patterns"
        case .saveFailed(let error):
            return "Failed to save pattern: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete pattern: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to export pattern: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Failed to import pattern: \(error.localizedDescription)"
        case .initializationFailed(let error):
            return "Failed to initialize pattern manager: \(error.localizedDescription)"
        }
    }
}