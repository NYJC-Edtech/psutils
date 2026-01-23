# FileSqueeze Refactoring Plan

## Overview

This document outlines the refactoring priorities for FileSqueeze based on a comprehensive codebase analysis that identified **58 issues** across **8 Critical**, **18 High**, **22 Medium**, and **10 Low** severity levels.

**Analysis Date**: 2025-01-23
**Total Issues Identified**: 58
**Files Analyzed**: All Python files in `filesqueeze/`, test files, and configuration files

---

## Priority Matrix

| Priority | Issue Count | Severity | Timeline |
|----------|--------------|----------|----------|
| 🔴 Critical | 9 | Breaks functionality, security risks | This Week |
| 🟠 High | 18 | Maintenance nightmares, technical debt | This Month |
| 🟡 Medium | 22 | Quality of life, technical debt | This Quarter |
| 🟢 Low | 10 | Nice to have, cleanup | Future |

**Note**: Issue #2 (Bare Exception Handlers) is BLOCKED on issue #2.5 (Design Logging Strategy).

---

## 🔴 CRITICAL Issues (Fix Immediately)

### 1. Hardcoded Network Paths ⚠️
**Location**: `filesqueeze/config.py:24-25`, `filesqueeze/default.toml:7,9`

**Issue**:
```python
'input': 'G:/Shared drives/compressor/upload',
'output': 'G:/Shared drives/compressor/compressed',
```

**Impact**: Application FAILS for any user without this exact network drive. Not portable. Zero deployment flexibility.

**User Feedback**: Input/output directories should be specified in config, not hardcoded. Use sensible fallbacks (project or user directory).

**Fix Strategy**:
1. Use user home directory as default fallback:
   ```python
   # In default.toml
   input = "~/FileSqueeze/upload"
   output = "~/FileSqueeze/compressed"

   # Config will expand ~ during init-config
   ```
2. Environment variable support for overrides:
   ```bash
   export FILESQUEEZE_INPUT_DIR="/custom/input"
   export FILESQUEEZE_OUTPUT_DIR="/custom/output"
   ```
3. `filesqueeze init-config` creates directories in user home by default
4. Users can edit config.toml to point to network drives
5. Document in README.md

**Rationale**:
- User home directory (~) works on all systems
- Config is the single source of truth (PRD invariant)
- Environment variables allow deployment flexibility
- No hardcoding = portable codebase

**Files to Modify**:
- `filesqueeze/default.toml` (use ~/FileSqueeze/* paths)
- `filesqueeze/config.py` (support env var overrides)
- `filesqueeze/cli.py` (init-config should create directories)
- `README.md` (document configuration)

**Tests**:
- Verify default config uses ~/FileSqueeze paths
- Test environment variable overrides work
- Integration test: service starts with default user directory paths
- Test: init-config creates directories in user home

---

### 2. Bare Exception Handlers 🚨 (BLOCKED - Requires Logging Strategy First)
**Locations**: 11 instances across codebase
- `filesqueeze/ocr.py:78` - `except Exception:`
- `filesqueeze/handlers.py:27,77,157,208` - `except Exception:`
- `filesqueeze/doctor.py:56` - `except:`

**Issue**:
```python
except Exception:
    state.metadata['error'] = "Error during document analysis"
```
Silences unexpected errors, makes debugging impossible.

**Impact**: Runtime errors get swallowed, impossible to debug production issues.

**User Feedback**: Design a coherent logging strategy before tackling bare exception handlers.

**BLOCKED ON**: Issue #2.5 - Design Logging Strategy

**Planned Fix Strategy** (after logging strategy is defined):
1. Replace with specific exceptions:
   ```python
   except (subprocess.TimeoutExpired, FileNotFoundError) as e:
       logger.error(f"Document analysis failed: {e}", exc_info=True)
       state.metadata['error'] = str(e)
   ```
2. Create custom exception classes in `filesqueeze/exceptions.py`:
   ```python
   class FileSqueezeError(Exception): pass
   class ProcessingError(FileSqueezeError): pass
   class BinaryNotFoundError(FileSqueezeError): pass
   ```
3. Follow logging strategy for error handling policy

**Files to Modify**:
- `filesqueeze/handlers.py` (4 locations)
- `filesqueeze/ocr.py` (1 location)
- `filesqueeze/doctor.py` (1 location)
- `filesqueeze/exceptions.py` (NEW)

**Tests**:
- Unit tests for each exception type
- Integration test: errors are properly logged
- Test: invalid binaries show helpful error messages

---

### 2.5. Design Logging Strategy 🔵 (NEW - Prerequisite for #2)
**Location**: Project-wide

**Issue**: No coherent logging strategy exists. Current logging is ad-hoc and inconsistent.

**Impact**: Cannot properly fix bare exception handlers without knowing how to log errors.

**Requirements**:
1. **Log Levels**: When to use DEBUG, INFO, WARNING, ERROR, CRITICAL
2. **Log Format**: Consistent format across all modules
3. **Error Logging**: exc_info=True for exceptions, structured error messages
4. **User-Facing Errors**: When to show errors to user vs log only
5. **Context**: Include relevant context (file path, operation, etc.)
6. **Performance**: Avoid excessive logging in hot paths

**Design Tasks**:
1. Audit current logging usage across codebase
2. Define logging level usage guidelines
3. Create logging utility functions for common patterns
4. Document error handling policy
5. Update bare exception handlers after strategy is defined

**Files to Create**:
- `filesqueeze/logging.py` - Logging utilities and helpers
- `docs/LOGGING.md` - Logging strategy documentation

**Files to Update**:
- All files with bare exception handlers (after strategy defined)

**Deliverable**:
- Documented logging strategy
- Logging utility functions
- Examples of proper error logging

---

### 3. Private Member Access Violation 🔓
**Location**: `filesqueeze/handlers.py:95,224`

**Issue**:
```python
output_path = state._State__data.get('output_path')
```
Breaks encapsulation, fragile to State class changes.

**Impact**: HIGH - Code will break if State implementation changes; violates OOP principles.

**Fix Strategy**:
1. Add getter methods to State class (`filesqueeze/service.py`):
   ```python
   def get_output_path(self) -> Optional[Path]:
       return self.__data.get('output_path')

   def get_input_path(self) -> Optional[Path]:
       return self.__data.get('input_path')
   ```
2. Update handlers.py to use public interface:
   ```python
   output_path = state.get_output_path()
   ```

**Files to Modify**:
- `filesqueeze/service.py` (State class)
- `filesqueeze/handlers.py` (callers)

**Tests**:
- Test: getters return correct values
- Integration test: handlers work with State API
- Test: State class encapsulation is preserved

---

### 4. Missing Configuration Validation ✅
**Location**: `filesqueeze/config.py:68-176`

**Issue**: No validation of config values. Users can set:
- `crf = -1` (should be 0-51 for videos)
- `threads = -1` (should be positive)
- `min_age_seconds = -10` (should be non-negative)
- Invalid paths

**Impact**: Invalid configs cause cryptic runtime errors instead of clear validation messages.

**User Feedback**: Don't use pydantic (unnecessary dependency). Use dataclasses instead. This requires restructuring config as a module directory.

**Fix Strategy**:
1. Convert `config.py` to `config/` module directory:
   ```
   filesqueeze/
     config/
       __init__.py       # Public Config class
       schema.py         # Dataclass definitions with validation
       loader.py         # Config loading logic
       defaults.py       # Default values
   ```

2. Create dataclass schemas with validation:
   ```python
   # schema.py
   from dataclasses import dataclass, field
   from pathlib import Path
   from typing import Optional

   @dataclass
   class VideoConfig:
       crf: int = field(default=23)
       threads: int = field(default=4)
       preset: str = field(default="medium")

       def __post_init__(self):
           if not 0 <= self.crf <= 51:
               raise ValueError(f"CRF must be 0-51, got {self.crf}")
           if self.threads < 1:
               raise ValueError(f"Threads must be positive, got {self.threads}")

   @dataclass
   class FileDetectionConfig:
       min_age_seconds: int = field(default=5)
       min_size_bytes: int = field(default=1024)
       extensions: list[str] = field(default_factory=list)

       def __post_init__(self):
           if self.min_age_seconds < 0:
               raise ValueError(f"min_age_seconds must be non-negative")
           if self.min_size_bytes < 0:
               raise ValueError(f"min_size_bytes must be non-negative")
   ```

3. Config class validates on load:
   ```python
   # __init__.py
   class Config:
       def __init__(self, config_path: Optional[str] = None):
           loaded = loader.load(config_path)
           self.video = VideoConfig(**loaded['video'])
           self.file_detection = FileDetectionConfig(**loaded['file_detection'])
           # ... etc
   ```

**Rationale**:
- Dataclasses: built-in, no dependencies, fast
- Module structure: clear separation of concerns
- Validation: __post_init__ validates on construction
- Type safety: mypy can validate dataclass fields

**Files to Create**:
- `filesqueeze/config/__init__.py` - Public API
- `filesqueeze/config/schema.py` - Dataclass schemas
- `filesqueeze/config/loader.py` - TOML loading logic
- `filesqueeze/config/defaults.py` - Default constants

**Files to Modify**:
- `filesqueeze/config.py` - Delete, replace with module
- `pyproject.toml` - No changes needed (dataclasses built-in)

**Tests**:
- Unit tests for each schema class validation
- Integration test: invalid config raises clear error
- Test: all default values pass validation
- Test: config module imports work (backward compat)

---

## 🟠 HIGH PRIORITY Issues (Fix This Month)

### 5. Duplicate Binary Detection Functions
**Location**:
- `filesqueeze/video.py:12-44`
- `filesqueeze/document.py:12-53, 56-88`

**Issue**: `get_ffmpeg_path()` duplicated (35 lines × 2 files)

**Impact**: Maintenance nightmare; bug fixes must be applied twice.

**Fix Strategy**:
1. Create `filesqueeze/binaries.py` module:
   ```python
   class BinaryManager:
       @staticmethod
       def get_ffmpeg_path() -> Optional[Path]:
           # Consolidated logic here

       @staticmethod
       def get_ghostscript_path() -> Optional[Path]:

       @staticmethod
       def get_tesseract_path() -> Optional[Path]:
   ```
2. Update video.py and document.py to use:
   ```python
   from filesqueeze.binaries import BinaryManager
   ffmpeg_path = BinaryManager.get_ffmpeg_path()
   ```

**Files to Modify**:
- `filesqueeze/binaries.py` (NEW)
- `filesqueeze/video.py` (remove duplicate, import BinaryManager)
- `filesqueeze/document.py` (remove duplicate, import BinaryManager)

**Tests**:
- Test: BinaryManager finds system binaries
- Test: BinaryManager falls back to PATH
- Test: video.py/document.py use shared module

---

### 6. File Type Logic Duplication
**Locations**:
- `filesqueeze/cli.py:237-256`
- `filesqueeze/service.py:280-291`
- `filesqueeze/output.py:55-64`

**Issue**:
```python
if ext in ['mp4', 'wmv', 'avi', 'mkv', 'mov', 'flv']:
    type_dir = 'video'
elif ext == 'pdf':
    type_dir = 'document'
elif ext in ['jpg', 'jpeg', 'png']:
    type_dir = 'image'
```
Duplicated in 3 places.

**Impact**: Adding new file type requires changes in multiple locations.

**Fix Strategy**:
1. Create `filesqueeze/file_types.py`:
   ```python
   class FileTypeRegistry:
       VIDEO = ['mp4', 'wmv', 'avi', 'mkv', 'mov', 'flv']
       DOCUMENT = ['pdf']
       IMAGE = ['jpg', 'jpeg', 'png']

       @classmethod
       def get_category(cls, ext: str) -> str:
           ext = ext.lstrip('.')
           if ext in cls.VIDEO:
               return 'video'
           elif ext in cls.DOCUMENT:
               return 'document'
           elif ext in cls.IMAGE:
               return 'image'
           else:
               return 'unknown'
   ```
2. Replace duplicated logic with:
   ```python
   file_type = FileTypeRegistry.get_category(ext)
   ```

**Files to Modify**:
- `filesqueeze/file_types.py` (NEW)
- `filesqueeze/cli.py`
- `filesqueeze/service.py`
- `filesqueeze/output.py`

**Tests**:
- Unit test: FileTypeRegistry.get_category() for all extensions
- Test: Unknown extension returns 'unknown'
- Integration: CLI and service use consistent categorization

---

### 7. Inconsistent Error Handling Patterns
**Locations**: 6 different patterns across codebase

**Issue**:
- `service.py:139` - Returns False on error
- `handlers.py:193` - Logs error, continues
- `video.py:124` - Raises RuntimeError
- `cli.py:169` - Prints and exits

**Impact**: Unpredictable error handling; some errors get swallowed.

**Fix Strategy**:
1. Establish error handling policy:
   - **Recoverable errors**: Log + return error code
   - **Critical errors**: Log + raise custom exception
   - **Never**: Silently ignore
2. Create custom exceptions in `filesqueeze/exceptions.py`
3. Refactor all error handling to follow policy

**Files to Modify**:
- `filesqueeze/exceptions.py` (NEW)
- `filesqueeze/service.py`
- `filesqueeze/handlers.py`
- `filesqueeze/cli.py`

**Tests**:
- Test: Each exception type is raised appropriately
- Integration: Errors are logged with context
- Test: Error handling policy is consistent

---

### 8. Magic Numbers (15+ instances)
**Locations**:
- Timeouts: 300s, 1800s (video.py:247, document.py:144, ocr.py:119,182)
- File sizes: 1024, 4096 (scanner.py:79, video.py:263, document.py:309)
- Refresh rate: 2000ms (gui.py:32, tray.py:219)

**Impact**: Cannot tune behavior without code changes.

**Fix Strategy**:
1. Add to configuration:
   ```toml
   [processing]
   video_timeout_seconds = 1800
   pdf_timeout_seconds = 300
   ocr_timeout_seconds = 300

   [file_detection]
   min_age_seconds = 60
   min_size_bytes = 1024

   [gui]
   refresh_interval_ms = 2000
   ```
2. Replace hardcoded values with config reads:
   ```python
   timeout=self.config.processing.video_timeout_seconds
   ```

**Files to Modify**:
- `filesqueeze/config.py` (DEFAULTS dict)
- `filesqueeze/default.toml`
- `filesqueeze/video.py`
- `filesqueeze/document.py`
- `filesqueeze/ocr.py`
- `filesqueeze/scanner.py`
- `filesqueeze/gui.py`
- `filesqueeze/tray.py`

**Tests**:
- Unit tests: Config has all required timeouts
- Test: Processing uses configured timeouts
- Integration: GUI uses configured refresh rate

---

### 9. Platform-Specific Code Scattered
**Locations**:
- `filesqueeze/service.py:76-141` (Platform checks)
- `filesqueeze/tray.py:156-181` (Windows-only code)
- `filesqueeze/video.py:251` (CREATE_NO_WINDOW flag)
- `filesqueeze/ocr.py:120` (creationflags)

**Issue**: Windows PowerShell calls, subprocess flags mixed with business logic.

**Impact**: Difficult to test; platform-specific logic not isolated.

**Fix Strategy**:
1. Create `filesqueeze/platform.py`:
   ```python
   class PlatformService(ABC):
       @abstractmethod
       def show_notification(self, title: str, message: str) -> bool: ...

       @abstractmethod
       def open_folder(self, path: Path) -> None: ...

   class WindowsPlatformService(PlatformService):
       def show_notification(self, title, message):
           # PowerShell logic here

       def open_folder(self, path):
           # os.startfile() logic
   ```
2. Replace platform-specific code with PlatformService calls

**Files to Modify**:
- `filesqueeze/platform.py` (NEW)
- `filesqueeze/service.py`
- `filesqueeze/tray.py`
- `filesqueeze/video.py`
- `filesqueeze/ocr.py`

**Tests**:
- Mock PlatformService for testing
- Test: Windows code uses WindowsPlatformService
- Test: Fallback to default implementation

---

### 10. God Object: Config Class
**Location**: `filesqueeze/config.py:18-176` (158 lines)

**Issue**: Config class does too much:
- Loading from multiple sources
- Merging with deep copy
- Dot notation access
- Path properties
- Configuration validation

**Impact**: Difficult to test individual concerns.

**Fix Strategy**:
1. Split into focused classes:
   - `ConfigLoader` - loads and merges configs
   - `ConfigAccessor` - provides dot notation access via properties
   - `Config` - simple data holder
2. Each class has single responsibility

**Files to Modify**:
- `filesqueeze/config.py` (split into multiple classes)
- All files that import Config (may need imports adjusted)

**Tests**:
- Unit tests for each Config class responsibility
- Integration: Config loading works end-to-end
- Test: Dot notation access works correctly

---

### 11. Missing Retry Logic for Transient Failures
**Location**: `filesqueeze/service.py:278-332`

**Issue**: Network operations (file access on network drives) can fail transiently with no retry.

**Impact**: Unnecessary failures on temporary network glitches.

**Fix Strategy**:
1. Create retry decorator:
   ```python
   def retry(max_attempts=3, delay=1.0, backoff=exponential):
       def decorator(f):
           @wraps(f)
           def wrapper(*args, **kwargs):
               for attempt in range(max_attempts):
                   try:
                       return f(*args, **kwargs)
                   except (FileNotFoundError, ConnectionError, TimeoutError) as e:
                       if attempt == max_attempts - 1:
                           raise
                       time.sleep(delay * (2 ** attempt))
           return wrapper
       return decorator

   @retry(max_attempts=3, delay=1.0)
   def _process_file(self, filepath: Path):
       ...
   ```

**Files to Modify**:
- `filesqueeze/utils.py` (add retry decorator)
- `filesqueeze/service.py` (apply to _process_file)

**Tests**:
- Mock transient failure scenarios
- Test: Retry happens on failure
- Test: Max retries exhausted raises exception

---

## 🟡 MEDIUM PRIORITY Issues

### 12. Configuration in Two Places
**Location**:
- `filesqueeze/config.py:22-66` (Python DEFAULTS dict)
- `filesqueeze/default.toml:1-102` (TOML file)

**Issue**: Default configuration exists in TWO places; can diverge.

**Fix Strategy**: Use TOML as single source of truth, load it in Config.

### 13. TODO Comments for Incomplete Cleanup
**Location**: `filesqueeze/handlers.py:210,238`

**Issue**: `# TODO: clean up outfile` - indicates incomplete error paths.

**Fix**: Implement proper cleanup using context managers or try-finally.

### 14. Redundant run() Method
**Location**: `filesqueeze/service.py:494-502, 564-572`

**Issue**: run() method defined twice with identical code.

**Fix**: Remove duplicate definition.

### 15. Configuration Loading Not Documented
**Location**: `filesqueeze/config.py:68-100`

**Issue**: Config cascade order (CLI → project → user → defaults) not documented.

**Fix**: Add comprehensive docstring explaining precedence.

---

## 🟢 LOW PRIORITY Issues

### 16-20. Miscellaneous
- Unused imports
- Commented-out code
- Hardcoded notification text (internationalization)
- Missing environment variable support
- Subprocess error handling standardization

---

## Implementation Order

### Phase 1: Critical Foundation (Week 1-2)
**Goal**: Fix blocking issues that prevent reliable operation

**BLOCKING DEPENDENCY**: Issue #2.5 (Design Logging Strategy) MUST be completed before Issue #2 (Bare Exception Handlers).

1. ✅ Fix private member access in handlers.py (Issue #3)
2. ✅ Design logging strategy (Issue #2.5) - **PREREQUISITE**
3. ✅ Replace hardcoded paths with user directory + env vars (Issue #1)
4. ✅ Restructure config as module with dataclass validation (Issue #4)
5. ✅ Add custom exception classes (part of Issue #2)
6. ✅ Fix bare exception handlers using logging strategy (Issue #2)

**Deliverable**:
- Application works on any system without hardcoded paths
- Clear error messages with proper logging
- Config validation prevents invalid values
- Encapsulation respected throughout codebase
- Coherent logging strategy established

### Phase 2: Deduplication (Week 2-3)
**Goal**: Remove code duplication, improve maintainability

6. ✅ Extract binary detection to shared module
7. ✅ Create FileTypeRegistry abstraction
8. ✅ Standardize error handling patterns
9. ✅ Move magic numbers to configuration

**Deliverable**:
- Single source of truth for binary detection
- Consistent file type categorization
- Uniform error handling across codebase

### Phase 3: Architecture (Week 3-4)
**Goal**: Improve code organization and testability

10. ✅ Create platform abstraction layer
11. ✅ Split Config class into focused classes
12. ✅ Add retry logic for transient failures
13. ✅ Remove duplicate run() method

**Deliverable**:
- Platform-specific code isolated
- Cleaner Config class with single responsibilities
- Resilient file processing with retries

### Phase 4: Quality of Life (Week 4)
**Goal**: Cleanup and polish

14. ✅ Consolidate configuration sources
15. ✅ Fix TODO comments (add proper cleanup)
16. ✅ Remove unused imports
17. ✅ Document configuration loading

**Deliverable**:
- Single source of truth for configuration
- No TODO comments for incomplete work
- Clean, maintainable codebase

---

## Success Criteria

Each refactoring phase is complete when:
- ✅ All integration tests pass
- ✅ No new test failures introduced
- ✅ Code compiles without warnings
- ✅ Documentation updated
- ✅ Git commit with clear message describing changes

**Overall Goal**: Reduce technical debt from 58 issues to <10 issues while maintaining 100% test pass rate and improving code quality.

---

## Notes

- All changes should preserve backward compatibility where possible
- Breaking changes require migration guide in README.md
- Integration tests are our safety net - run after every change
- Commit frequently with clear atomic changes
- Update this plan as issues are resolved

**Last Updated**: 2025-01-23
**Status**: Ready to begin Phase 1
