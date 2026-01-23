# FileSqueeze Product Requirements Document (PRD)

**Version**: 1.0
**Last Updated**: 2025-01-23
**Status**: Active

---

## Executive Summary

FileSqueeze is an automated file compression utility designed for Windows environments that monitors directories and compresses videos, PDFs, and images using external tools (FFmpeg, Ghostscript, Tesseract). The application runs as a background Windows service with a system tray interface, providing hands-off compression for network drives and local filesystems.

**Target Users**:
- Organizations with large media files (training videos, scanned documents, presentations)
- IT departments managing shared drives with storage constraints
- Users who need automatic, hands-off file compression

**Key Value Proposition**:
- **Automated**: Drop files in a folder, FileSqueeze handles the rest
- **Smart**: Detects file types, applies optimal compression settings
- **Non-destructive**: Original files preserved or moved based on configuration
- **Transparent**: System tray interface shows real-time status

---

## Product Goals

### Primary Goals
1. **Reduce storage footprint** by 50-90% through automatic compression
2. **Zero-user-intervention workflow** - "fire and forget" operation
3. **Maintain acceptable quality** with configurable compression settings
4. **Support network drives** (Google Shared Drives, Dropbox, OneDrive)

### Secondary Goals
1. Provide clear visibility into compression operations
2. Enable batch processing of existing files
3. Support OCR for scanned PDFs
4. Offer flexible configuration for different use cases

---

## Core Features

### 1. Watch Mode (Primary Feature)
FileSqueeze monitors an input directory and automatically compresses new files.

**Behavior**:
- Real-time file system monitoring via watchdog
- Periodic polling (every 5 minutes) as fallback
- Initial scan on startup for existing files
- Automatic file type detection
- Compressed files moved to output directory
- Original files deleted after successful compression

**File Types Supported**:
- Videos: mp4, wmv, avi, mkv, mov, flv
- Documents: pdf
- Images: jpg, jpeg, png, pptx

### 2. Service Mode (Windows)
FileSqueeze runs as a background Windows service with system tray icon.

**Behavior**:
- Starts automatically on boot (optional)
- System tray icon shows service status
- Status window displays:
  - Service state (running/stopped)
  - Uptime
  - Processing statistics (completed/failed counts)
  - Input/output directories
  - Currently processing files (real-time)
  - Auto-refreshes every 1 second

**User Interactions**:
- Double-click tray icon: Open status window
- Right-click tray icon: Context menu (Start, Stop, Status, Quit)

### 3. Compression Pipeline

#### Video Compression (FFmpeg)
- **Codec**: H.264 (libx264)
- **Quality**: CRF 23 (default, range 0-51)
- **Preset**: medium (balance speed/compression)
- **Audio**: AAC, 128kbps
- **Scaling**: Optional width/height limits

#### PDF Compression (Ghostscript)
- **Quality Levels**:
  - screen: 72 dpi (lowest quality, smallest size)
  - ebook: 150 dpi (good for on-screen reading)
  - printer: 300 dpi (good for printing)
  - prepress: 300 dpi, color preserving (highest quality)
- **Smart Detection**: Automatically detects scanned vs generated PDFs

#### Image Compression (FFmpeg/libx264)
- JPEG quality: 85%
- PNG optimization
- Metadata preservation

#### OCR (Tesseract - Optional)
- Adds searchable text layer to scanned PDFs
- DPI: 300 (configurable)
- Languages: English (default, extensible)

### 4. Batch Processing
Process entire directories of existing files.

**Command**: `filesqueeze scan <input_dir> <output_dir>`

**Behavior**:
- Recursively finds all supported file types
- Processes files in parallel (configurable thread count)
- Shows progress indicator
- Generates summary report

### 5. Configuration Management

**Configuration File**: `~/.config/filesqueeze/config.toml`

**Settings**:
- Directory paths (input, output)
- Compression settings (CRF, quality presets)
- File detection rules (extensions, age, size)
- Service settings (polling interval, auto-start)
- Binary paths (FFmpeg, Ghostscript, Tesseract)

**Configuration Loading Priority**:
1. CLI arguments
2. Project config (./filesqueeze.toml)
3. User config (~/.config/filesqueeze/config.toml)
4. Built-in defaults

---

## System Invariants

These are non-negotiable behavioral guarantees that FileSqueeze MUST uphold.

### Service Launch Behavior

**When launched from Start Menu or command line:**
- ✅ System tray icon appears immediately
- ✅ Status window opens automatically to show service status

**Rationale**: Users launching FileSqueeze expect immediate visual feedback that the service is running.

**Implementation**:
- The `filesqueeze service run` command starts the tray icon AND automatically opens the status window
- Status window shows: service state, directories, statistics, processing files

### Single Instance Enforcement

**Invariant**: Only one FileSqueeze service instance can run at a time.

**Behavior**:
- Attempting to start a second instance displays helpful error message
- Error message mentions FileSqueeze is already running
- Error message suggests checking system tray
- Prevents conflicts from multiple services watching same directories

**Implementation**:
- Windows named mutex: `Global\FileSqueeze_SingleInstanceMutex`
- Check on service startup, raise RuntimeError if already exists
- Mutex automatically released when service exits

### Singleton Status Window

**Invariant**: Clicking tray icon repeatedly opens only ONE status window.

**Behavior**:
- First click: Opens status window
- Subsequent clicks: Bring existing window to foreground (TODO)
- Prevents window clutter from multiple status windows

**Implementation**:
- TrayService tracks `_status_window` instance
- `_on_show_status()` checks if window exists before creating
- Window cleared from `_status_window` after closing

### Windows Integration

**Invariant**: AppUserModelID must be set BEFORE tray icon creation.

**Rationale**: Ensures Windows properly identifies and remembers FileSqueeze across restarts.

**Implementation**:
- Set `com.filesqueeze.FilesqueezeService` as AppUserModelID
- Must happen in `start()` method before `pystray.Icon()` creation
- Logged at INFO level for verification

### Configuration Management

**Invariant**: User config at `~/.config/filesqueeze/config.toml` is the single source of truth.

**Behavior**:
- Tilde paths expanded once at config generation (`filesqueeze init-config`)
- Runtime uses absolute paths, no re-expansion
- Configuration changes require service restart

**Implementation**:
- `cmd_init_config` expands `~` to absolute paths
- Config class stores absolute paths
- No tilde expansion at runtime

### Log File Location

**Invariant**: Logs MUST go to user config directory, NEVER project directory.

**Location**: `~/.config/filesqueeze/filesqueeze.log`

**Rationale**:
- Keeps project directory clean
- Follows XDG Base Directory specification
- Prevents permission issues on system installs

**Implementation**:
- Logger.setup() defaults to user config location
- Explicit log_file path required
- No fallback to project directory

### Installation Experience

**Invariant**: Installation MUST be user-friendly and non-destructive.

**Uninstallation Behavior**:
- Prompt format: `[Y/n]` (uppercase indicates default)
- Stop all running FileSqueeze processes
- Preserve user configuration files
- Enable fresh installation without errors

**Installation Behavior**:
- Check Python version (3.11+ required)
- Create Start Menu shortcuts
- Generate user configuration file
- Detect external binaries (FFmpeg, Ghostscript, Tesseract)
- Show clear next steps to user

### Status Window UI

**Invariant**: Status window MUST show required information with 1-second refresh.

**Required Sections**:
1. Service state (Running/Stopped)
2. Uptime (time since service started)
3. Statistics (completed/failed counts)
4. Directories (input/output paths)
5. Processing (currently processing files, real-time)

**Refresh Rate**: 1 second (1000ms)

**Implementation**:
- `StatusWindow` class accepts `refresh_interval` parameter
- `update_display()` method refreshes all sections
- Timer-based refresh using tkinter's `.after()`

---

## Technical Requirements

### External Dependencies

**Required**:
- Python 3.11+
- FFmpeg (for video/image compression)
- Ghostscript (for PDF compression)

**Optional**:
- Tesseract OCR (for scanned PDFs)

### Python Dependencies

**Core**:
- watchdog (file system monitoring)
- pystray (system tray icon)
- PIL/Pillow (image handling)
- tomli/tomli-w (TOML configuration)
- typing-extensions (type hints)

### Platform Support

**Primary**: Windows 10/11
- System tray integration
- Windows service installation
- Named mutex for single-instance

**Secondary**: Linux/macOS (best-effort)
- Command-line interface only
- No system tray
- No service mode

---

## User Stories

### Primary User Stories

1. **As an IT manager**, I want FileSqueeze to automatically compress videos uploaded to our shared drive so that we can save storage space without manual intervention.

2. **As a teacher**, I want to drop my lesson videos into a folder and have them automatically compressed so that I don't have to manually process each video.

3. **As an admin**, I want to see the current status of FileSqueeze in the system tray so that I can verify it's working.

4. **As a user**, I want to open the status window to see what files are being processed so that I know FileSqueeze is working.

### Secondary User Stories

5. **As a power user**, I want to configure compression settings so that I can balance quality and file size.

6. **As a user with scanned documents**, I want FileSqueeze to add OCR text so that my PDFs are searchable.

7. **As an admin**, I want to install FileSqueeze as a Windows service so that it starts automatically on boot.

---

## Non-Functional Requirements

### Performance

- **Startup**: Service starts within 5 seconds
- **File Detection**: New files detected within 5 seconds (local) or 5 minutes (network)
- **Compression Speed**: Depends on file size and settings (typical: 1-10 MB/s)
- **Memory Usage**: < 100 MB idle, < 500 MB during compression
- **CPU Usage**: Low when idle, high during compression (expected)

### Reliability

- **Uptime**: Service should run indefinitely without crashes
- **Error Recovery**: Log errors, continue processing other files
- **Network Resilience**: Handle temporary network drive disconnections gracefully
- **File Safety**: Never delete original file unless compression succeeds

### Usability

- **Installation**: One-click installer for non-technical users
- **Configuration**: Sensible defaults, optional advanced config
- **Status Visibility**: Real-time status window with auto-refresh
- **Error Messages**: Clear, actionable error messages

### Security

- **No Remote Code Execution**: All compression local
- **Privilege Level**: User-space application, no admin required
- **File Access**: Only accesses configured input/output directories
- **Log Safety**: No sensitive information in logs

---

## Testing Requirements

### Integration Tests

All integration tests MUST follow these principles:

1. **No mocking**: Test against real system behavior
2. **Interface over implementation**: Test what the system does, not how
3. **Behavior-focused**: Verify observable user-facing behavior
4. **Document invariants first**: Add to PRD before testing

### Test Coverage

**Current Coverage**: 20/39 tests automated (51%)

**Fully Automated**:
- ✅ Installation script behavior (7/7 tests)
- ✅ Log file location and tilde expansion (3/3 tests)
- ✅ Configuration management (2/2 tests)
- ✅ Singleton status window enforcement (3/3 tests)
- ✅ AppUserModelID code structure (1/2 tests)
- ✅ User config preservation (1/3 tests)
- ✅ Single-instance enforcement (2/3 tests)

**Requires Infrastructure**:
- GUI rendering tests (pywinauto framework needed)
- Process cleanup during uninstall (needs full installation)
- Window focus/visibility behavior
- App identity persistence across reboots (manual test)

### Test Execution

```bash
# Run all tests
pytest tests/integration/

# Run specific test file
pytest tests/integration/test_invariants.py -v

# Run specific test
pytest tests/integration/test_invariants.py::TestServiceExecutionInvariants::test_service_launch_opens_status_window -v

# Run tests in isolation (for mutex tests)
pytest tests/integration/test_single_instance.py -v
```

---

## Future Enhancements (Out of Scope)

### Potential Features
1. **Linux/macOS System Tray**: Native system tray integration for non-Windows platforms
2. **Web Interface**: Browser-based status dashboard
3. **Compression Profiles**: Named presets for different use cases (e.g., "YouTube", "Archive")
4. **Custom Filters**: Regex-based file filtering rules
5. **Notification System**: Windows toast notifications on completion/error
6. **Compression History**: Database of all compressed files with before/after sizes
7. **Batch Scheduling**: Schedule batch processing for specific times
8. **Plugin System**: Extensible compression pipeline for custom file types

### Technical Debt
- Add comprehensive type hints (mypy compliance)
- Improve test coverage to 80%+
- Add performance benchmarks
- Implement comprehensive logging strategy
- Add telemetry/usage tracking (opt-in)

---

## Success Metrics

### Quantitative Metrics

- **Storage Reduction**: Average 50-90% file size reduction
- **Reliability**: 99% uptime, < 1% crash rate
- **Performance**: 95% of files processed within 10 minutes of upload
- **User Satisfaction**: < 5% support request rate

### Qualitative Metrics

- **Ease of Installation**: Non-technical users can install in < 5 minutes
- **Clarity of Status**: Users can understand what's happening at a glance
- **Error Transparency**: Users know what went wrong and how to fix it

---

## Appendix: Glossary

- **CRF**: Constant Rate Factor - FFmpeg quality setting (0-51, lower = better quality)
- **OCR**: Optical Character Recognition - Adding searchable text to images
- **Watchdog**: Python library for file system event monitoring
- **Pystray**: Python library for Windows system tray icons
- **TOML**: Configuration file format (Tom's Obvious Minimal Language)
- **AppUserModelID**: Windows application identifier for taskbar grouping
- **Mutex**: Mutual exclusion object for single-instance enforcement

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-23 | Initial PRD created from integration tests and README documentation |

---

**Document Status**: ✅ Active - This document reflects the current FileSqueeze implementation and requirements.
