# Accessibility Testing Guide

## Overview
This guide provides comprehensive instructions for testing accessibility features in the SoundToLightTherapy app. It covers both automated XCTest-based testing and manual verification procedures to ensure WCAG 2.1 compliance and iOS accessibility guidelines.

## Table of Contents
1. [Automated Testing with XCTest](#automated-testing-with-xctest)
2. [Manual Testing Procedures](#manual-testing-procedures)
3. [Cross-Platform Testing](#cross-platform-testing)
4. [CI/CD Integration](#cicd-integration)
5. [Troubleshooting Common Issues](#troubleshooting-common-issues)
6. [Testing Tools and Resources](#testing-tools-and-resources)

## Automated Testing with XCTest

### Test Suite Structure
The accessibility tests are located in [`SoundToLightTherapy/Tests/SoundToLightTherapyTests/AccessibilityTests.swift`](SoundToLightTherapy/Tests/SoundToLightTherapyTests/AccessibilityTests.swift) and cover:

- **VoiceOverSupport**: Accessibility trait configuration
- **DynamicTypeSupport**: Font scaling and text readability
- **ReducedMotionSupport**: Motion reduction handling
- **ColorContrastSupport**: WCAG 2.1 compliance verification
- **HapticFeedbackSupport**: Haptic feedback generation
- **Integration Tests**: Cross-feature compatibility
- **Performance Tests**: Efficiency measurements

### Running Automated Tests

#### On Linux/macOS:
```bash
cd SoundToLightTherapy
swift test
```

#### On iOS Simulator:
```bash
cd SoundToLightTherapy
swift test --destination 'platform=iOS Simulator,name=iPhone 15'
```

#### Specific Test Filtering:
```bash
# Run only color contrast tests
swift test --filter "ColorContrast"

# Run only VoiceOver tests
swift test --filter "VoiceOver"

# Run performance tests only
swift test --filter "Performance"
```

### Test Coverage Verification
The test suite includes 16 comprehensive tests covering:

1. VoiceOver accessibility configuration
2. Dynamic Type font scaling
3. Reduced motion detection
4. Color contrast ratio calculations
5. WCAG 2.1 compliance verification
6. Haptic feedback generation
7. Cross-platform compatibility
8. Performance benchmarking

## Manual Testing Procedures

### VoiceOver Testing
1. **Enable VoiceOver**: Settings → Accessibility → VoiceOver → toggle On
2. **Navigate App**: Use single-finger swipe gestures to navigate
3. **Verify Elements**:
   - All interactive elements announce meaningful labels
   - Buttons provide clear action hints
   - Images have descriptive alternative text
   - Form fields announce expected input types

### Dynamic Type Testing
1. **Adjust Text Size**: Settings → Display & Brightness → Text Size
2. **Test All Sizes**: From Extra Small to Accessibility Extra Extra Extra Large
3. **Check Layout**:
   - No text truncation or overlapping
   - Touch targets remain accessible (min 44x44 points)
   - Scroll views function properly

### Reduced Motion Testing
1. **Enable Reduce Motion**: Settings → Accessibility → Motion → Reduce Motion
2. **Verify Animations**:
   - Parallax effects are disabled
   - Transitions are simplified or removed
   - Essential feedback remains available

### Color Contrast Testing
1. **Visual Inspection**: Verify all text meets WCAG standards:
   - Normal text: 4.5:1 minimum contrast
   - Large text: 3.0:1 minimum contrast
   - Non-text elements: 3.0:1 minimum contrast
2. **Color Deficiency Simulation**: Use Xcode Accessibility Inspector to test:
   - Deuteranopia (red-green)
   - Protanopia (red)
   - Tritanopia (blue-yellow)

### Haptic Feedback Testing
1. **Test on Physical Devices**: Different iPhone models vary in haptic capabilities
2. **Verify Feedback Types**:
   - Success, warning, error notifications
   - Selection feedback
   - Impact feedback (light, medium, heavy)
3. **Check Context Appropriateness**: Feedback should match user actions

## Cross-Platform Testing

### iOS-Specific Features
- Test UIAccessibility APIs (`UIAccessibility.isVoiceOverRunning`)
- Verify iOS-specific haptic feedback
- Check platform-specific accessibility settings

### Cross-Platform Compatibility
- Verify graceful degradation on non-iOS platforms
- Test SwiftCrossUI backend compatibility
- Ensure consistent experience across platforms

### Platform Conditionals in Code
```swift
#if os(iOS)
// iOS-specific code
#else
// Cross-platform fallback
#endif
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Accessibility Tests

on: [push, pull_request]

jobs:
  accessibility-tests:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Accessibility Tests
      run: |
        cd SoundToLightTherapy
        swift test --filter "Accessibility"
```

### Xcode Cloud Configuration
1. Add accessibility test target to build scheme
2. Configure test plans to include accessibility tests
3. Set up periodic accessibility regression testing

### Test Result Reporting
- Integrate with tools like Xcode Test Reports
- Generate JUnit XML reports for CI systems
- Set up alerts for accessibility test failures

## Troubleshooting Common Issues

### Compilation Errors
**Issue**: `No such module 'SoundToLightTherapy'`
**Solution**: Run `swift package resolve` and `swift build` before testing

**Issue**: Method signature mismatches
**Solution**: Update test calls to match actual utility API signatures

### Platform-Specific Failures
**Issue**: Tests fail on non-iOS platforms
**Solution**: Use conditional compilation (`#if os(iOS)`) for iOS-only tests

**Issue**: Haptic feedback tests fail on simulator
**Solution**: Use conditional checks or mock haptic feedback in tests

### Performance Test Flakiness
**Issue**: High relative standard deviation in performance tests
**Solution**: Increase `maxPercentRelativeStandardDeviation` or optimize test setup

## Testing Tools and Resources

### Xcode Tools
- **Accessibility Inspector**: Visual accessibility auditing
- **VoiceOver**: Screen reader testing
- **Environment Overrides**: Simulate accessibility settings

### Third-Party Tools
- **WCAG Contrast Checker**: Color contrast verification
- **VoiceOver Practice**: Screen reader proficiency training
- **Color Oracle**: Color deficiency simulation

### Reference Materials
- [Apple Accessibility Programming Guide](https://developer.apple.com/accessibility/)
- [WCAG 2.1 Specification](https://www.w3.org/TR/WCAG21/)
- [SwiftCrossUI Documentation](https://github.com/stackotter/swift-cross-ui)

## Testing Schedule

### Regular Testing Cadence
- **Daily**: Automated test runs on CI/CD
- **Weekly**: Manual accessibility smoke tests
- **Monthly**: Comprehensive accessibility audit
- **Per Release**: Full regression testing

### Release Checklist
- [ ] All automated accessibility tests pass
- [ ] Manual VoiceOver testing completed
- [ ] Dynamic Type scaling verified
- [ ] Color contrast meets WCAG 2.1
- [ ] Reduced motion behavior confirmed
- [ ] Cross-platform compatibility verified

## Version History
- **v1.0**: Initial accessibility testing guide
- **Date**: September 6, 2025
- **Author**: SoundToLightTherapy Team

## Support
For accessibility-related issues or questions, contact:
- **Development Team**: [team@email.com]
- **Accessibility Specialist**: [specialist@email.com]
- **Quality Assurance**: [qa@email.com]