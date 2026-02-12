# Photo Renamer PowerShell Script - Product Requirements Document

## Overview
A PowerShell script to batch-rename student photos based on a CSV reference file. Designed to run on workplace laptops with no external dependencies - uses only native PowerShell capabilities.

## Target Environment
- **OS**: Windows 10/11
- **PowerShell**: 5.1+ (native Windows PowerShell)
- **Dependencies**: None - must use only built-in cmdlets
- **Execution Context**: Run manually by school staff/IT administrators

## Input Files

### namelist.csv
Located in the same directory as the script. Format:
```
Full Name,Class
John Smith,10A
Jane Doe,10B
```

**Specifications:**
- Header row required: `Full Name,Class`
- One student per line
- No leading/trailing spaces in values
- CSV encoded in UTF-8

### Source Photos
- User-selected directory containing image files
- Supported formats: `.jpg`, `.jpeg`, `.png`
- Files are assumed to be in **ascending alphabetical order** when mapped to students

## Workflow

### 1. Script Initialization
- Load `namelist.csv` from script directory
- Display banner/title

### 2. Directory Selection
- Open native folder selection dialog using `System.Windows.Forms.FolderBrowserDialog`
- Prompt user to select folder containing photos
- Validate:
  - Folder exists
  - Folder contains files

### 3. Class Input
- Prompt user to enter the class name (e.g., "10A")
- Validate:
  - Class exists in CSV
  - Class has at least one student

### 4. File Validation
Perform all validations **before** proceeding:

| Validation | Error Action |
|------------|--------------|
| All files are images (jpg/jpeg/png) | Display list of invalid files, exit |
| Number of files = number of students in class | Show counts, ask to continue or exit |

### 5. Name Mapping
- Get all image files from selected folder
- Sort files alphabetically (ascending)
- Map to students from CSV **in the order they appear in the file** (no sorting)
- Store mapping: `OldName → NewName`

### 6. Confirmation Display
Show preview in formatted table:

```
   photo001.jpg → John Smith.jpg
   photo002.jpg → Jane Doe.jpg
   photo003.jpg → Bob Jones.jpg
```

Prompt: `Proceed with renaming? [Y/N]`

- If `N` or `No`: Exit immediately without changes
- If `Y` or `Yes`: Continue to backup and rename

### 7. Duplicate Name Check
Before renaming, check for duplicate student names within the class:
- If duplicates found: **Error and stop** - display duplicate names and exit
- This prevents accidental overwrites

### 8. Backup
- Create `original` subdirectory in selected folder
- **Copy** (not move) all original files to `original/`
- Preserve original filenames

### 9. Rename
- Rename each file to `Full Name.jpg`
- Convert original extension to `.jpg` for consistency
- Handle names with spaces properly

### 10. Completion
- Display success message with:
  - Number of files renamed
  - Backup location
- Exit

## Error Handling

| Scenario | Behavior |
|----------|----------|
| namelist.csv not found | Error message, exit |
| Class not found in CSV | Error message, exit |
| No image files in folder | Error message, exit |
| File count mismatch | Warning, option to continue or exit |
| Non-image files found | List invalid files, exit |
| Duplicate names in class | Error, list duplicates, exit |
| Backup folder already exists | Ask user to resolve first (manual deletion), exit |
| Rename fails (file locked, etc.) | Error message, keep backup |

## Output Filenames
- Format: `{Full Name}.{original_extension}`
- Examples:
  - `John Smith.jpg` (was photo001.jpg)
  - `Jane Doe.png` (was photo002.png)
  - `Bob Jones.jpeg` (was photo003.jpeg)
- Original file extensions are preserved

## UI/UX Requirements
- Clear, friendly messages for non-technical users
- Color-coded output where possible (success = green, error = red)
- Pause before exit so user can read messages
- All prompts should be clear and specific

## Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Validation failure |
| 3 | User cancelled |

## Future Enhancements (Out of Scope)
- Automatic duplicate name handling
- CSV format auto-detection
- Recursive folder scanning
- Undo functionality
