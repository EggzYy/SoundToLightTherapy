import Foundation

#if canImport(UIKit)
    import UIKit
#endif

/// Manages screen wake lock to prevent device from sleeping during therapy sessions
public actor ScreenWakeLock {
    public static let shared = ScreenWakeLock()

    private var isWakeLockActive: Bool = false
    private var sessionCount: Int = 0  // Track active sessions

    private init() {}

    public enum WakeLockError: Error {
        case unsupportedPlatform
        case alreadyActive
        case notActive
    }

    /// Enable wake lock to prevent screen from sleeping
    public func enableWakeLock() async throws {
        #if canImport(UIKit)
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            isWakeLockActive = true
            sessionCount += 1

            print("🔆 Screen wake lock enabled (active sessions: \(sessionCount))")

            // Generate haptic feedback to confirm wake lock activation
            _ = await HapticFeedbackSupport.generate(.lightImpact, respectReducedMotion: true)
        #else
            throw WakeLockError.unsupportedPlatform
        #endif
    }

    /// Disable wake lock to allow normal screen sleeping
    public func disableWakeLock() async throws {
        guard sessionCount > 0 else {
            throw WakeLockError.notActive
        }

        sessionCount -= 1

        // Only disable wake lock if no active sessions remain
        if sessionCount == 0 {
            #if canImport(UIKit)
                await MainActor.run {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                isWakeLockActive = false
                print("🔆 Screen wake lock disabled (no active sessions)")
            #else
                throw WakeLockError.unsupportedPlatform
            #endif
        } else {
            print("🔆 Wake lock still active (remaining sessions: \(sessionCount))")
        }
    }

    /// Force disable wake lock regardless of session count
    public func forceDisableWakeLock() async {
        #if canImport(UIKit)
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        #endif
        isWakeLockActive = false
        sessionCount = 0
        print("🔆 Screen wake lock force disabled")
    }

    /// Check if wake lock is currently active
    public func isActive() async -> Bool {
        return isWakeLockActive
    }

    /// Get current session count
    public func getSessionCount() async -> Int {
        return sessionCount
    }

    /// Handle app going to background - temporarily disable wake lock
    public func handleAppDidEnterBackground() async {
        if isWakeLockActive {
            #if canImport(UIKit)
                await MainActor.run {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            #endif
            print("🔆 Wake lock paused (app in background)")
        }
    }

    /// Handle app returning to foreground - restore wake lock if needed
    public func handleAppWillEnterForeground() async {
        if sessionCount > 0 {
            #if canImport(UIKit)
                await MainActor.run {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            #endif
            isWakeLockActive = true
            print("🔆 Wake lock restored (app in foreground)")
        }
    }
}

// MARK: - App Lifecycle Support

#if canImport(UIKit)
    import Combine

    /// Handles app lifecycle events for wake lock management
    public class WakeLockLifecycleManager: ObservableObject {
        private var cancellables = Set<AnyCancellable>()

        public init() {
            setupAppLifecycleObservers()
        }

        private func setupAppLifecycleObservers() {
            // Handle app going to background
            NotificationCenter.default
                .publisher(for: UIApplication.didEnterBackgroundNotification)
                .sink { _ in
                    Task {
                        await ScreenWakeLock.shared.handleAppDidEnterBackground()
                    }
                }
                .store(in: &cancellables)

            // Handle app returning to foreground
            NotificationCenter.default
                .publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { _ in
                    Task {
                        await ScreenWakeLock.shared.handleAppWillEnterForeground()
                    }
                }
                .store(in: &cancellables)

            // Handle app termination - cleanup wake lock
            NotificationCenter.default
                .publisher(for: UIApplication.willTerminateNotification)
                .sink { _ in
                    Task {
                        await ScreenWakeLock.shared.forceDisableWakeLock()
                    }
                }
                .store(in: &cancellables)
        }
    }
#endif
