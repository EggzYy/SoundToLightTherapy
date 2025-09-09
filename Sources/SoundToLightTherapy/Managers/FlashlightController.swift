#if canImport(UIKit)
import UIKit
import AVFoundation
#endif

public actor FlashlightController {
    public enum FlashlightError: Error {
        case unsupportedPlatform
        case torchUnavailable
        case permissionDenied
    }

    private var isTorchOn: Bool = false

    #if canImport(UIKit)
    private let device: AVCaptureDevice? = {
        guard let device = AVCaptureDevice.default(for: .video) else { return nil }
        return device
    }()
    #endif

    public init() {}

    public func requestCameraPermission() async throws -> Bool {
        #if canImport(UIKit)
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            throw FlashlightError.permissionDenied
        @unknown default:
            throw FlashlightError.permissionDenied
        }
        #else
        throw FlashlightError.unsupportedPlatform
        #endif
    }

    public func toggleFlashlight() async throws -> Bool {
        #if canImport(UIKit)
        // Request camera permission first
        _ = try await requestCameraPermission()

        guard let device = device else {
            throw FlashlightError.torchUnavailable
        }

        guard device.hasTorch else {
            throw FlashlightError.torchUnavailable
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = isTorchOn ? .off : .on
            isTorchOn.toggle()
            device.unlockForConfiguration()

            return isTorchOn
        } catch {
            throw FlashlightError.permissionDenied
        }
        #else
        throw FlashlightError.unsupportedPlatform
        #endif
    }

    public func setFlashlight(_ on: Bool) async throws {
        #if canImport(UIKit)
        // Request camera permission first
        _ = try await requestCameraPermission()

        guard let device = device else {
            throw FlashlightError.torchUnavailable
        }

        guard device.hasTorch else {
            throw FlashlightError.torchUnavailable
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            isTorchOn = on
            device.unlockForConfiguration()

            // Generate haptic feedback for flashlight state change
            if on {
                _ = await HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)
            } else {
                _ = await HapticFeedbackSupport.generate(.lightImpact, respectReducedMotion: true)
            }
        } catch {
            throw FlashlightError.permissionDenied
        }
        #else
        throw FlashlightError.unsupportedPlatform
        #endif
    }

    public func getFlashlightState() async -> Bool {
        return isTorchOn
    }

    public func pulseFlashlight(duration: Double, frequency: Float) async throws {
        #if canImport(UIKit)
        // Request camera permission first
        _ = try await requestCameraPermission()

        guard let device = device else {
            throw FlashlightError.torchUnavailable
        }

        guard device.hasTorch else {
            throw FlashlightError.torchUnavailable
        }

        // Generate haptic feedback at the start of pulsing
        _ = await HapticFeedbackSupport.generate(.selection, respectReducedMotion: true)

        let pulseInterval = 1.0 / Double(frequency)
        let totalPulses = Int(duration / pulseInterval)

        for _ in 0..<totalPulses {
            try await setFlashlight(true)
            try await Task.sleep(nanoseconds: UInt64(pulseInterval / 2 * 1_000_000_000))
            try await setFlashlight(false)
            try await Task.sleep(nanoseconds: UInt64(pulseInterval / 2 * 1_000_000_000))
        }
        #else
        throw FlashlightError.unsupportedPlatform
        #endif
    }
}
