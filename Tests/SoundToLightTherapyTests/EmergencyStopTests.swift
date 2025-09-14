import XCTest
@testable import SoundToLightTherapy

/// Comprehensive test suite for emergency stop system
/// Validates <50ms response time requirement and safety functionality
final class EmergencyStopTests: XCTestCase {
    
    var emergencyStopSystem: EmergencyStopSystem!
    var precisionStrobeController: PrecisionStrobeController!
    
    override func setUp() async throws {
        try await super.setUp()
        emergencyStopSystem = EmergencyStopSystem()
        precisionStrobeController = PrecisionStrobeController()
        
        // Validate system readiness before testing
        try await emergencyStopSystem.validateSystemReadiness()
    }
    
    override func tearDown() async throws {
        // Ensure emergency stop is reset after each test
        await emergencyStopSystem.resetEmergencyStop()
        try await super.tearDown()
    }
    
    // MARK: - Response Time Tests
    
    func testEmergencyStopResponseTime() async throws {
        // Test that emergency stop completes within 50ms requirement
        let metrics = try await emergencyStopSystem.performEmergencyStopTest()
        
        XCTAssertLessThan(metrics.responseTime, 50.0, 
                         "Emergency stop took \(metrics.responseTime)ms, exceeding 50ms requirement")
        XCTAssertTrue(metrics.validationResults.responseTimeValid, 
                     "Emergency stop response time validation failed")
        
        print("✅ Emergency stop response time: \(metrics.responseTime)ms")
    }
    
    func testMultipleEmergencyStopsConsistency() async throws {
        // Test that multiple emergency stops maintain consistent response times
        var responseTimes: [TimeInterval] = []
        
        for i in 1...5 {
            let metrics = try await emergencyStopSystem.performEmergencyStopTest()
            responseTimes.append(metrics.responseTime)
            
            XCTAssertLessThan(metrics.responseTime, 50.0, 
                             "Emergency stop #\(i) took \(metrics.responseTime)ms")
            
            // Reset between tests
            await emergencyStopSystem.resetEmergencyStop()
            
            // Brief delay between tests
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        let averageTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let maxTime = responseTimes.max() ?? 0
        
        XCTAssertLessThan(averageTime, 30.0, "Average response time should be well under 50ms")
        XCTAssertLessThan(maxTime, 50.0, "Maximum response time exceeded requirement")
        
        print("📊 Average response time: \(averageTime)ms, Max: \(maxTime)ms")
    }
    
    // MARK: - Component Integration Tests
    
    func testPrecisionStrobeControllerEmergencyStop() async throws {
        // Test emergency stop integration with precision strobe controller
        
        // Start strobing at a test frequency
        try await precisionStrobeController.startStrobing(frequency: 10.0, intensity: 0.5)
        
        // Verify strobing is active
        let isStrobing = await precisionStrobeController.isCurrentlyStrobing()
        XCTAssertTrue(isStrobing, "Strobe controller should be active before emergency stop")
        
        // Trigger emergency stop
        let metrics = try await precisionStrobeController.triggerSystemEmergencyStop()
        
        // Verify response time
        XCTAssertLessThan(metrics.responseTime, 50.0, 
                         "Emergency stop response time exceeded requirement")
        
        // Verify strobing stopped
        let isStrobingAfter = await precisionStrobeController.isCurrentlyStrobing()
        XCTAssertFalse(isStrobingAfter, "Strobe controller should be stopped after emergency stop")
        
        // Verify torch shutdown
        XCTAssertTrue(metrics.validationResults.torchShutdownVerified, 
                     "Torch shutdown should be verified")
        
        print("✅ Precision strobe controller emergency stop: \(metrics.responseTime)ms")
    }
    
    func testEmergencyStopDuringHighFrequencyStrobing() async throws {
        // Test emergency stop effectiveness during high-frequency strobing
        
        try await precisionStrobeController.startStrobing(frequency: 60.0, intensity: 1.0)
        
        // Let it strobe for a brief period
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Trigger emergency stop
        let startTime = CFAbsoluteTimeGetCurrent()
        let metrics = try await precisionStrobeController.triggerSystemEmergencyStop()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let actualResponseTime = (endTime - startTime) * 1000
        
        XCTAssertLessThan(actualResponseTime, 50.0, 
                         "High-frequency emergency stop took \(actualResponseTime)ms")
        XCTAssertLessThan(metrics.responseTime, 50.0, 
                         "Reported response time: \(metrics.responseTime)ms")
        
        print("✅ High-frequency emergency stop: \(actualResponseTime)ms")
    }
    
    // MARK: - Validation Tests
    
    func testEmergencyStopValidation() async throws {
        // Test comprehensive validation of emergency stop effectiveness
        
        let metrics = try await emergencyStopSystem.performEmergencyStopTest()
        
        // Verify all validation criteria
        XCTAssertTrue(metrics.validationResults.torchShutdownVerified, 
                     "Torch shutdown validation failed")
        XCTAssertTrue(metrics.validationResults.timersStoppedVerified, 
                     "Timer shutdown validation failed")
        XCTAssertTrue(metrics.validationResults.responseTimeValid, 
                     "Response time validation failed")
        XCTAssertTrue(metrics.validationResults.allComponentsResponded, 
                     "Component response validation failed")
        
        // Verify components were actually shutdown
        XCTAssertTrue(metrics.componentsShutdown.contains("torch"), 
                     "Torch should be in shutdown components list")
        
        print("✅ Emergency stop validation passed")
    }
    
    func testEmergencyStopSystemReadiness() async throws {
        // Test system readiness validation
        
        try await emergencyStopSystem.validateSystemReadiness()
        
        // If we reach here without throwing, the system is ready
        XCTAssertTrue(true, "Emergency stop system should be ready")
        
        print("✅ Emergency stop system readiness validated")
    }
    
    // MARK: - Performance Tests
    
    func testEmergencyStopPerformanceUnderLoad() async throws {
        // Test emergency stop performance when system is under load
        
        // Create multiple concurrent tasks to simulate system load
        let loadTasks = (1...10).map { _ in
            Task {
                for _ in 1...100 {
                    // Simulate CPU load
                    let _ = (1...1000).reduce(0, +)
                }
            }
        }
        
        // Start strobing
        try await precisionStrobeController.startStrobing(frequency: 40.0)
        
        // Trigger emergency stop under load
        let metrics = try await precisionStrobeController.triggerSystemEmergencyStop()
        
        // Cancel load tasks
        loadTasks.forEach { $0.cancel() }
        
        // Verify performance under load
        XCTAssertLessThan(metrics.responseTime, 50.0, 
                         "Emergency stop under load took \(metrics.responseTime)ms")
        
        print("✅ Emergency stop under load: \(metrics.responseTime)ms")
    }
    
    func testEmergencyStopHistoryTracking() async throws {
        // Test that emergency stop history is properly tracked
        
        let initialHistory = await emergencyStopSystem.getEmergencyStopHistory()
        let initialCount = initialHistory.count
        
        // Perform multiple emergency stops
        for _ in 1...3 {
            _ = try await emergencyStopSystem.performEmergencyStopTest()
            await emergencyStopSystem.resetEmergencyStop()
        }
        
        let finalHistory = await emergencyStopSystem.getEmergencyStopHistory()
        XCTAssertEqual(finalHistory.count, initialCount + 3, 
                      "Emergency stop history should track all stops")
        
        // Test average response time calculation
        let averageTime = await emergencyStopSystem.getAverageResponseTime()
        XCTAssertGreaterThan(averageTime, 0, "Average response time should be calculated")
        XCTAssertLessThan(averageTime, 50.0, "Average response time should meet requirement")
        
        print("✅ Emergency stop history tracking validated")
    }
    
    // MARK: - Edge Case Tests
    
    func testEmergencyStopWhenNotStrobing() async throws {
        // Test emergency stop when no strobing is active
        
        let isStrobing = await precisionStrobeController.isCurrentlyStrobing()
        XCTAssertFalse(isStrobing, "Should not be strobing initially")
        
        // Emergency stop should still work
        let metrics = try await emergencyStopSystem.performEmergencyStopTest()
        
        XCTAssertLessThan(metrics.responseTime, 50.0, 
                         "Emergency stop when idle took \(metrics.responseTime)ms")
        
        print("✅ Emergency stop when idle: \(metrics.responseTime)ms")
    }
    
    func testRepeatedEmergencyStops() async throws {
        // Test that repeated emergency stops don't degrade performance
        
        var responseTimes: [TimeInterval] = []
        
        for i in 1...10 {
            let metrics = try await emergencyStopSystem.performEmergencyStopTest()
            responseTimes.append(metrics.responseTime)
            
            XCTAssertLessThan(metrics.responseTime, 50.0, 
                             "Emergency stop #\(i) exceeded time limit")
            
            await emergencyStopSystem.resetEmergencyStop()
        }
        
        // Verify no performance degradation
        let firstHalf = Array(responseTimes.prefix(5))
        let secondHalf = Array(responseTimes.suffix(5))
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        // Second half should not be significantly slower (allow 20% variance)
        XCTAssertLessThan(secondAverage, firstAverage * 1.2, 
                         "Performance should not degrade with repeated use")
        
        print("✅ Repeated emergency stops performance validated")
    }
}

// MARK: - Performance Measurement Extensions

extension EmergencyStopTests {
    
    /// Measure precise timing for emergency stop operations
    func measureEmergencyStopTiming(_ operation: () async throws -> Void) async rethrows -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (endTime - startTime) * 1000 // Convert to milliseconds
    }
}