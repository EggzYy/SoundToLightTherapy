import Foundation
import SoundToLightTherapy

/// Test harness for Phase 1 integration testing
actor IntegrationTest {
    private let sessionCoordinator = TherapySessionCoordinator()
    
    func testTherapySessionFlow() async {
        print("=== Starting Therapy Session Integration Test ===")
        
        // Test session start
        do {
            print("Attempting to start therapy session...")
            try await sessionCoordinator.startSession()
            print("✓ Therapy session started successfully")
            
            // Simulate some processing time
            print("Simulating therapy session for 5 seconds...")
            try await Task.sleep(nanoseconds: 5_000_000_000)
            
            // Test session stop
            print("Stopping therapy session...")
            await sessionCoordinator.stopSession()
            print("✓ Therapy session stopped successfully")
            
        } catch TherapySessionCoordinator.TherapySessionError.sessionAlreadyActive {
            print("⚠️ Session already active error")
        } catch TherapySessionCoordinator.TherapySessionError.audioCaptureFailed {
            print("⚠️ Audio capture failed (expected on Linux)")
        } catch TherapySessionCoordinator.TherapySessionError.frequencyDetectionFailed {
            print("⚠️ Frequency detection failed (expected on Linux)")
        } catch TherapySessionCoordinator.TherapySessionError.flashlightControlFailed {
            print("⚠️ Flashlight control failed (expected on Linux)")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
        
        print("=== Integration Test Complete ===")
    }
    
    func testIndividualManagers() async {
        print("\n=== Testing Individual Managers ===")
        
        // Test AudioCaptureManager
        let audioManager = AudioCaptureManager()
        do {
            _ = try await audioManager.startCapture()
            print("✓ Audio capture started")
            await audioManager.stopCapture()
            print("✓ Audio capture stopped")
        } catch AudioCaptureManager.AudioCaptureError.unsupportedPlatform {
            print("⚠️ Audio capture not supported on this platform (expected)")
        } catch {
            print("❌ Audio capture error: \(error)")
        }
        
        // Test FrequencyDetector
        let frequencyDetector = FrequencyDetector()
        let testAudioData = [Float](repeating: 0.5, count: 1024)
        do {
            let frequency = try await frequencyDetector.detectFrequency(from: testAudioData)
            print("✓ Frequency detection: \(frequency) Hz")
        } catch FrequencyDetector.FrequencyDetectionError.unsupportedPlatform {
            print("⚠️ Frequency detection not supported on this platform (expected)")
        } catch {
            print("❌ Frequency detection error: \(error)")
        }
        
        // Test FlashlightController
        let flashlightController = FlashlightController()
        do {
            try await flashlightController.setFlashlight(false)
            print("✓ Flashlight control: off")
        } catch FlashlightController.FlashlightError.unsupportedPlatform {
            print("⚠️ Flashlight control not supported on this platform (expected)")
        } catch {
            print("❌ Flashlight control error: \(error)")
        }
        
        print("=== Individual Manager Test Complete ===")
    }
    
    func testReducedMotionSupport() async {
        print("\n=== Testing Reduced Motion Support ===")
        
        // Test initial state
        let initialReducedMotion = await ReducedMotionSupport.isReducedMotionEnabled
        print("Initial reduced motion state: \(initialReducedMotion)")
        
        // Test observation of changes
        var observedChanges = 0
        
        let observationTask = await ReducedMotionSupport.observeReducedMotionChanges { isEnabled in
            Task { @MainActor in
                observedChanges += 1
                print("Reduced motion change observed: \(isEnabled) (change #\(observedChanges))")
            }
        }
        
        // Simulate a change in reduced motion preference
        print("Simulating reduced motion change...")
        let simulationTask = await ReducedMotionSupport.simulateReducedMotion(!initialReducedMotion)
        
        // Wait a bit for the change to be detected (polling every second on Linux)
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Check if change was observed
        if observedChanges > 0 {
            print("✓ Dynamic preference change handling working correctly")
            print("Final reduced motion state: \(await ReducedMotionSupport.isReducedMotionEnabled)")
        } else {
            print("⚠️ No changes observed (may be expected on this platform)")
        }
        
        // Clean up
        simulationTask.cancel()
        observationTask.cancel()
        
        print("=== Reduced Motion Support Test Complete ===")
    }

    func testColorContrastCompliance() async {
        print("\n=== Testing Color Contrast Compliance ===")

        // Test color combinations from TherapyView
        let therapyViewCombinations: [(foreground: AccessibleColor,
                                      background: AccessibleColor,
                                      level: WCAGContrastLevel)] = [
            // Start button: textLight on primaryBlue
            (foreground: ColorContrastSupport.AccessiblePalettes.textLight,
             background: ColorContrastSupport.AccessiblePalettes.primaryBlue,
             level: .normalText),
            
            // Stop button: textLight on primaryRed
            (foreground: ColorContrastSupport.AccessiblePalettes.textLight,
             background: ColorContrastSupport.AccessiblePalettes.primaryRed,
             level: .normalText),
            
            // Status active: primaryGreenForLightBackground on backgroundLight (light background)
            (foreground: ColorContrastSupport.AccessiblePalettes.primaryGreenForLightBackground,
             background: ColorContrastSupport.AccessiblePalettes.backgroundLight,
             level: .normalText),
            
            // Status inactive: primaryRedForLightBackground on backgroundLight (light background)
            (foreground: ColorContrastSupport.AccessiblePalettes.primaryRedForLightBackground,
             background: ColorContrastSupport.AccessiblePalettes.backgroundLight,
             level: .normalText),
            
            // Also test with dark background for status: primaryGreenForDarkBackground on backgroundDark
            (foreground: ColorContrastSupport.AccessiblePalettes.primaryGreenForDarkBackground,
             background: ColorContrastSupport.AccessiblePalettes.backgroundDark,
             level: .normalText),
            
            // primaryRedForDarkBackground on backgroundDark
            (foreground: ColorContrastSupport.AccessiblePalettes.primaryRedForDarkBackground,
             background: ColorContrastSupport.AccessiblePalettes.backgroundDark,
             level: .normalText)
        ]

        // Test color combinations from DynamicTypeTestView
        let dynamicTypeCombinations: [(foreground: AccessibleColor,
                                      background: AccessibleColor,
                                      level: WCAGContrastLevel)] = [
            // Primary blue text on light background
            (foreground: ColorContrastSupport.AccessiblePalettes.primaryBlue,
             background: ColorContrastSupport.AccessiblePalettes.backgroundLight,
             level: .normalText),
            
            // Text dark on light background
            (foreground: ColorContrastSupport.AccessiblePalettes.textDark,
             background: ColorContrastSupport.AccessiblePalettes.backgroundLight,
             level: .normalText)
        ]

        // Combine all combinations
        let allCombinations = therapyViewCombinations + dynamicTypeCombinations

        // Generate compliance report
        let report = ColorContrastSupport.generateComplianceReport(combinations: allCombinations)
        print(report)

        // Check if all combinations are compliant
        var allCompliant = true
        for combination in allCombinations {
            let result = ColorContrastSupport.testColorCompliance(
                foreground: combination.foreground,
                background: combination.background,
                level: combination.level
            )
            if !result.isCompliant {
                allCompliant = false
                print("❌ FAIL: \(String(format: "%.2f", result.ratio)):1 ratio for foreground RGB(\(combination.foreground.red), \(combination.foreground.green), \(combination.foreground.blue)) on background RGB(\(combination.background.red), \(combination.background.green), \(combination.background.blue))")
            }
        }

        if allCompliant {
            print("✓ All color combinations meet WCAG 2.1 contrast requirements")
        } else {
            print("⚠️ Some color combinations do not meet WCAG 2.1 contrast requirements")
        }

        print("=== Color Contrast Compliance Test Complete ===")
    }
}

// Test runner function (no longer @main since this is a library target)
struct TestRunner {
    static func runTests() async {
        let test = IntegrationTest()
        await test.testIndividualManagers()
        await test.testTherapySessionFlow()
        await test.testReducedMotionSupport()
        await test.testColorContrastCompliance()
    }
}