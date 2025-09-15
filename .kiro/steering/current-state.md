---
inclusion: always
---

# Sound to Light Therapy App - Development Guide

**Platform**: iOS (Swift/SwiftUI)  
**Build**: `./fix-permissions.sh` (NEVER use `swift build`)

## Critical Build Rules

- **ALWAYS use `./fix-permissions.sh`** for building - `swift build` will fail
- Build warnings are expected (mostly unused variables) - ignore them
- Test on device after significant changes

## Architecture Overview

### Core Components
- **TherapyView** - Main scrollable UI with 10 sections
- **TherapySessionCoordinator** - Central session management (actor)
- **FrequencyDetector** - Audio analysis with FFT and A4=432Hz tuning
- **PrecisionStrobeController** - Microsecond-accurate light control
- **SessionPatternManager** - Pattern storage and validation
- **TherapeuticFrequencyMapper** - Frequency-to-therapy mapping

### Key Models
- **SessionPattern** - Pattern data with validation system
- **TherapySegment** - Individual pattern segments
- **NoiseFloorSettings** - Audio processing configuration

## Code Patterns & Style

### Threading & Async
- Use `actor` for all thread-safe managers
- Wrap async calls from UI in `Task{}`
- Real-time updates every 250ms during sessions

### Naming Conventions
- Managers end with "Manager" or "Controller"
- Views end with "View"
- Models are simple nouns
- Use descriptive method names

### UI Patterns
- **Scrollable interface required** - content exceeds screen height
- Use collapsible sections for complex settings
- Maintain consistent color coding (green=active, red=emergency)
- State synchronization between UI and backend critical

## File Structure

```
Sources/SoundToLightTherapy/
├── Views/
│   ├── TherapyView.swift                    # Main scrollable UI
│   ├── SessionPatternLibraryView.swift      # Pattern browser
│   └── SessionPatternDesignerView.swift     # Pattern editor
├── Managers/
│   ├── TherapySessionCoordinator.swift      # Session management (actor)
│   ├── FrequencyDetector.swift             # Audio analysis (actor)
│   ├── SessionPatternManager.swift         # Pattern storage (actor)
│   ├── TherapeuticFrequencyMapper.swift    # Frequency mapping
│   └── PrecisionStrobeController.swift     # Light control (actor)
├── Models/
│   └── SessionPattern.swift                # Pattern data model
└── Utilities/ (accessibility support files)
```

## Session Types & Data Flow

### Three Session Modes
1. **Pure Audio-Responsive** - Frequencies from audio input only
2. **Fixed Pattern** - Predetermined frequencies, no audio
3. **Audio-Responsive Pattern** - Pattern guides therapy types, audio provides frequencies

### Data Flow Chain
```
Audio → AudioCaptureManager → FrequencyDetector → 
TherapeuticFrequencyMapper → TherapySessionCoordinator → 
PrecisionStrobeController → Flashlight
```

## Current Implementation Status

### Completed Features ✅
- Precision timing infrastructure with microsecond accuracy
- Advanced FFT audio analysis with confidence scoring
- Complete pattern system with designer UI
- Session management with pause/resume/skip
- User-configurable audio processing settings
- Scrollable UI with 10 main sections

### Key Configuration Options
- Audio processing: Noise floor calibration, ambient filtering, adaptive threshold
- Environmental sensitivity: 0.5x to 2.0x multiplier
- Session duration: 60-600 seconds (non-pattern mode)
- Pattern mode with audio-responsive toggle

## Development Guidelines

### Adding New Features
- Add debug logging with `print()` statements
- Follow actor pattern for thread-safe components
- Test all three session types when making changes
- Verify state synchronization between UI and backend

### UI Development
- Remember interface is scrollable - test content fits
- Use consistent section styling
- Add loading states for async operations
- Test on different screen sizes

### Testing Approach
- Console logging for debugging
- Verify pause/resume functionality
- Check emergency stop response time (<50ms)
- Test pattern validation system

## Known Limitations & Considerations

- SwiftCrossUI compatibility maintained
- Memory optimized for real-time audio processing
- Actor-based architecture prevents race conditions
- Build warnings are normal and can be ignored

## Remaining Tasks (Not Implemented)

- Multiple frequency detection modes (Task 2.4)
- Safety monitoring with epilepsy-risk detection (Task 3.x)
- Hardware calibration engine (Task 4.x)
- Enhanced session metrics and history (Task 5.x)
- Additional UI enhancements (Task 6.x)