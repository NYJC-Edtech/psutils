# Photo Renamer for Student Photos
# Renames photos based on namelist.csv - No external dependencies required

param(
    [switch]$Undo
)

# Exit code constants
$EXIT_SUCCESS = 0
$EXIT_ERROR = 1
$EXIT_VALIDATION = 2
$EXIT_CANCELLED = 3

# CSV file path (in same directory as script)
$CsvPath = Join-Path $PSScriptRoot "namelist.csv"

# Manifest file for tracking renames (saved in photo folder)
$ManifestFileName = ".rename_manifest.csv"

# Supported image extensions
$ImageExtensions = @('.jpg', '.jpeg', '.png')

# Helper function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

# Helper function to pause before exit
function Wait-ForExit {
    param([string]$Message = "Press Enter to exit...")
    Write-Host ""
    Write-Host $Message -ForegroundColor Gray
    Read-Host
}

# Load Windows Forms for folder dialog
Add-Type -AssemblyName System.Windows.Forms

# ============================================
# Undo Mode
# ============================================
if ($Undo) {
    Clear-Host
    Write-ColorOutput "========================================" Cyan
    Write-ColorOutput "  Undo Photo Rename" Cyan
    Write-ColorOutput "========================================" Cyan
    Write-Host ""

    # Folder selection for undo
    Write-ColorOutput "Please select the folder containing renamed photos..." Yellow
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the folder with renamed photos"
    $FolderBrowser.ShowNewFolderButton = $false

    $DialogResult = $FolderBrowser.ShowDialog()
    if ($DialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
        Wait-ForExit
        exit $EXIT_CANCELLED
    }

    $PhotoFolder = $FolderBrowser.SelectedPath
    $ManifestPath = Join-Path $PhotoFolder $ManifestFileName

    # Check for manifest
    if (-not (Test-Path $ManifestPath)) {
        Write-ColorOutput "ERROR: No rename manifest found in selected folder!" Red
        Write-ColorOutput "Expected file: $ManifestFileName" Red
        Wait-ForExit
        exit $EXIT_ERROR
    }

    # Load manifest
    Write-ColorOutput "Loading rename manifest..." Green
    $FileMapping = Import-Csv -Path $ManifestPath

    Write-Host ""
    Write-ColorOutput "========================================" Cyan
    Write-ColorOutput "  Files that will be restored:" Cyan
    Write-ColorOutput "========================================" Cyan

    foreach ($Mapping in $FileMapping) {
        Write-ColorOutput "  $($Mapping.NewName) -> $($Mapping.OldName)" White
    }

    Write-ColorOutput "========================================" Cyan
    Write-Host ""

    # Confirm undo
    $Confirm = Read-Host "Proceed with undo? (Y/N)"
    if ($Confirm -notmatch '^[Yy]') {
        Write-ColorOutput "Undo cancelled." Yellow
        Wait-ForExit
        exit $EXIT_CANCELLED
    }

    # Perform undo
    Write-Host ""
    Write-ColorOutput "Restoring original filenames..." Yellow

    $UndoSuccess = 0
    $UndoErrors = 0

    foreach ($Mapping in $FileMapping) {
        try {
            $CurrentPath = Join-Path $PhotoFolder $Mapping.NewName
            if (Test-Path $CurrentPath) {
                Rename-Item -Path $CurrentPath -NewName $Mapping.OldName -ErrorAction Stop
                $UndoSuccess++
                Write-ColorOutput "  $($Mapping.NewName) -> $($Mapping.OldName)" Green
            }
            else {
                Write-ColorOutput "  WARNING: $($Mapping.NewName) not found, skipping..." Yellow
            }
        }
        catch {
            $UndoErrors++
            Write-ColorOutput "  ERROR: Failed to restore $($Mapping.NewName)" Red
            Write-ColorOutput "    $($_.Exception.Message)" Red
        }
    }

    Write-Host ""
    Write-ColorOutput "========================================" Cyan
    Write-ColorOutput "  Undo Complete" Cyan
    Write-ColorOutput "========================================" Cyan
    Write-ColorOutput "  Files restored: $UndoSuccess" Green

    if ($UndoErrors -gt 0) {
        Write-ColorOutput "  Errors: $UndoErrors" Red
    }

    # Delete manifest
    Remove-Item -Path $ManifestPath -Force -ErrorAction SilentlyContinue
    Write-ColorOutput "  Backup folder preserved (manual deletion required)" Gray
    Write-ColorOutput "========================================" Cyan
    Write-Host ""

    Wait-ForExit
    exit $EXIT_SUCCESS
}

# ============================================
# Display banner
# ============================================
Clear-Host
Write-ColorOutput "========================================" Cyan
Write-ColorOutput "  Student Photo Renamer" Cyan
Write-ColorOutput "========================================" Cyan
Write-Host ""

# ============================================
# 1. Load CSV
# ============================================
if (-not (Test-Path $CsvPath)) {
    Write-ColorOutput "ERROR: namelist.csv not found in script directory!" Red
    Write-ColorOutput "Expected location: $CsvPath" Red
    Wait-ForExit
    exit $EXIT_ERROR
}

Write-ColorOutput "Loading namelist.csv..." Green
try {
    # Use PowerShell's native CSV import which handles quoted fields with commas
    $AllStudents = Import-Csv -Path $CsvPath -Header @('FullName', 'Class') | Where-Object { $_.FullName -ne 'FullName' }
    Write-ColorOutput "  Loaded $($AllStudents.Count) students from CSV." Green
}
catch {
    Write-ColorOutput "ERROR: Failed to parse namelist.csv" Red
    Write-ColorOutput $_.Exception.Message Red
    Wait-ForExit
    exit $EXIT_ERROR
}

# ============================================
# 2. Folder Selection Dialog
# ============================================
Write-Host ""
Write-ColorOutput "Please select the folder containing student photos..." Yellow

$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$FolderBrowser.Description = "Select the folder containing student photos"
$FolderBrowser.ShowNewFolderButton = $false

$DialogResult = $FolderBrowser.ShowDialog()

if ($DialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-ColorOutput "Folder selection cancelled." Yellow
    Wait-ForExit
    exit $EXIT_CANCELLED
}

$PhotoFolder = $FolderBrowser.SelectedPath
Write-ColorOutput "  Selected: $PhotoFolder" Green

# ============================================
# 3. Get all files and validate
# ============================================
Write-Host ""
Write-ColorOutput "Scanning for image files..." Yellow

$AllFiles = Get-ChildItem -Path $PhotoFolder -File

if ($AllFiles.Count -eq 0) {
    Write-ColorOutput "ERROR: No files found in selected folder!" Red
    Wait-ForExit
    exit $EXIT_VALIDATION
}

# Check for non-image files
$InvalidFiles = $AllFiles | Where-Object {
    $_.Extension -notin $ImageExtensions
}

if ($InvalidFiles) {
    Write-ColorOutput "ERROR: Found non-image files in the folder:" Red
    $InvalidFiles | ForEach-Object {
        Write-ColorOutput "  - $($_.Name)" Red
    }
    Write-ColorOutput "Only .jpg, .jpeg, and .png files are supported." Red
    Wait-ForExit
    exit $EXIT_VALIDATION
}

$ImageFiles = $AllFiles | Sort-Object Name
Write-ColorOutput "  Found $($ImageFiles.Count) image files." Green

# ============================================
# 4. Class input
# ============================================
Write-Host ""
$ClassName = Read-Host "Enter the class name (e.g., 2626)"

if ([string]::IsNullOrWhiteSpace($ClassName)) {
    Write-ColorOutput "ERROR: Class name cannot be empty!" Red
    Wait-ForExit
    exit $EXIT_VALIDATION
}

# Validate class exists in CSV
$ClassStudents = $AllStudents | Where-Object { $_.Class -eq $ClassName }

if (-not $ClassStudents) {
    Write-ColorOutput "ERROR: Class '$ClassName' not found in CSV!" Red
    Write-ColorOutput "Available classes in CSV:" Yellow
    $AllClasses = $AllStudents | Select-Object -ExpandProperty Class -Unique | Sort-Object
    $AllClasses | ForEach-Object { Write-ColorOutput "  - $_" Gray }
    Wait-ForExit
    exit $EXIT_VALIDATION
}

Write-ColorOutput "  Found $($ClassStudents.Count) students in class $ClassName." Green

# ============================================
# 5. Validate file count matches student count
# ============================================
Write-Host ""

if ($ImageFiles.Count -ne $ClassStudents.Count) {
    Write-ColorOutput "WARNING: File count mismatch!" Yellow
    Write-ColorOutput "  Image files: $($ImageFiles.Count)" Yellow
    Write-ColorOutput "  Students in class: $($ClassStudents.Count)" Yellow
    Write-Host ""

    $Continue = Read-Host "Continue anyway? (Y/N)"
    if ($Continue -notmatch '^[Yy]') {
        Write-ColorOutput "Cancelled by user." Yellow
        Wait-ForExit
        exit $EXIT_CANCELLED
    }
}

# ============================================
# 6. Build name mapping (alphabetical files, CSV order for names)
# ============================================
$FileMapping = [System.Collections.Generic.List[PSCustomObject]]::new()

# Class students are kept in CSV order (no sorting)
$StudentIndex = 0

foreach ($File in $ImageFiles) {
    if ($StudentIndex -lt $ClassStudents.Count) {
        $Student = $ClassStudents[$StudentIndex]
        $Extension = $File.Extension

        # Create mapping object - format: Class_Name.ext
        $FileMapping.Add([PSCustomObject]@{
            OldName    = $File.Name
            NewName    = "${ClassName}_$($Student.FullName)$Extension"
            OldPath    = $File.FullName
            NewPath    = Join-Path $PhotoFolder "${ClassName}_$($Student.FullName)$Extension"
        })

        $StudentIndex++
    }
}

# ============================================
# 7. Check for duplicate target names
# ============================================
$DuplicateNames = $FileMapping | Group-Object -Property NewName | Where-Object { $_.Count -gt 1 }

if ($DuplicateNames) {
    Write-ColorOutput "ERROR: Duplicate student names found in class!" Red
    Write-ColorOutput "The following names would cause conflicts:" Red
    $DuplicateNames | ForEach-Object {
        Write-ColorOutput "  - $($_.Name)" Red
    }
    Write-ColorOutput "Please resolve duplicate names in the CSV before continuing." Red
    Wait-ForExit
    exit $EXIT_VALIDATION
}

# ============================================
# 8. Display mapping for confirmation
# ============================================
Write-Host ""
Write-ColorOutput "========================================" Cyan
Write-ColorOutput "  File Mapping Preview" Cyan
Write-ColorOutput "========================================" Cyan

# Calculate padding for alignment
$MaxOldNameLength = ($FileMapping | ForEach-Object { $_.OldName.Length } | Measure-Object -Maximum).Maximum

foreach ($Mapping in $FileMapping) {
    $PaddedOldName = $Mapping.OldName.PadRight($MaxOldNameLength)
    Write-ColorOutput "  $PaddedOldName -> $($Mapping.NewName)" White
}

Write-ColorOutput "========================================" Cyan
Write-Host ""

# ============================================
# 9. User confirmation
# ============================================
$Confirm = Read-Host "Proceed with renaming? (Y/N)"

if ($Confirm -notmatch '^[Yy]') {
    Write-ColorOutput "Operation cancelled. No files were modified." Yellow
    Wait-ForExit
    exit $EXIT_CANCELLED
}

# ============================================
# 10. Check for existing backup folder
# ============================================
$BackupFolder = Join-Path $PhotoFolder "original"

if (Test-Path $BackupFolder) {
    Write-ColorOutput "ERROR: Backup folder 'original' already exists!" Red
    Write-ColorOutput "Please delete or move the existing 'original' folder and try again." Red
    Wait-ForExit
    exit $EXIT_ERROR
}

# ============================================
# 11. Create backup
# ============================================
Write-Host ""
Write-ColorOutput "Creating backup..." Yellow

try {
    New-Item -Path $BackupFolder -ItemType Directory -Force | Out-Null

    foreach ($File in $ImageFiles) {
        $BackupPath = Join-Path $BackupFolder $File.Name
        Copy-Item -Path $File.FullName -Destination $BackupPath -Force
    }

    Write-ColorOutput "  Backed up $($ImageFiles.Count) files to 'original' folder." Green
}
catch {
    Write-ColorOutput "ERROR: Failed to create backup!" Red
    Write-ColorOutput $_.Exception.Message Red
    Wait-ForExit
    exit $EXIT_ERROR
}

# ============================================
# 12. Rename files
# ============================================
Write-Host ""
Write-ColorOutput "Renaming files..." Yellow

$RenameSuccess = 0
$RenameErrors = 0

foreach ($Mapping in $FileMapping) {
    try {
        Rename-Item -Path $Mapping.OldPath -NewName $Mapping.NewName -ErrorAction Stop
        $RenameSuccess++
        Write-ColorOutput "  $($Mapping.OldName) -> $($Mapping.NewName)" Green
    }
    catch {
        $RenameErrors++
        Write-ColorOutput "  ERROR: Failed to rename $($Mapping.OldName)" Red
        Write-ColorOutput "    $($_.Exception.Message)" Red
    }
}

# Save manifest for undo functionality
$ManifestPath = Join-Path $PhotoFolder $ManifestFileName
$FileMapping | Export-Csv -Path $ManifestPath -NoTypeInformation

# ============================================
# 13. Completion summary
# ============================================
Write-Host ""
Write-ColorOutput "========================================" Cyan
Write-ColorOutput "  Operation Complete" Cyan
Write-ColorOutput "========================================" Cyan
Write-ColorOutput "  Files renamed: $RenameSuccess" Green

if ($RenameErrors -gt 0) {
    Write-ColorOutput "  Errors: $RenameErrors" Red
}

Write-ColorOutput "  Backup location: $BackupFolder" Gray
Write-ColorOutput "========================================" Cyan
Write-Host ""

# ============================================
# 14. Undo option
# ============================================
Write-ColorOutput "Do you want to check the results?" Yellow
$CheckResult = Read-Host "Press Enter to open folder, or type 'N' to skip"

if ($CheckResult -notmatch '^[Nn]') {
    explorer.exe $PhotoFolder
}

Write-Host ""
$UndoChoice = Read-Host "Undo the rename operation? (Y/N)"

if ($UndoChoice -match '^[Yy]') {
    Write-Host ""
    Write-ColorOutput "Undoing renames..." Yellow

    $UndoSuccess = 0
    $UndoErrors = 0

    foreach ($Mapping in $FileMapping) {
        try {
            # Get current file path (may have been renamed)
            $CurrentPath = Join-Path $PhotoFolder $Mapping.NewName
            if (Test-Path $CurrentPath) {
                Rename-Item -Path $CurrentPath -NewName $Mapping.OldName -ErrorAction Stop
                $UndoSuccess++
                Write-ColorOutput "  $($Mapping.NewName) -> $($Mapping.OldName)" Green
            }
            else {
                Write-ColorOutput "  WARNING: $($Mapping.NewName) not found, skipping..." Yellow
            }
        }
        catch {
            $UndoErrors++
            Write-ColorOutput "  ERROR: Failed to undo $($Mapping.NewName)" Red
            Write-ColorOutput "    $($_.Exception.Message)" Red
        }
    }

    Write-Host ""
    Write-ColorOutput "========================================" Cyan
    Write-ColorOutput "  Undo Complete" Cyan
    Write-ColorOutput "========================================" Cyan
    Write-ColorOutput "  Files restored: $UndoSuccess" Green

    if ($UndoErrors -gt 0) {
        Write-ColorOutput "  Errors: $UndoErrors" Red
    }

    # Delete manifest
    Remove-Item -Path $ManifestPath -Force -ErrorAction SilentlyContinue
    Write-ColorOutput "  Backup folder preserved at: $BackupFolder" Gray
    Write-ColorOutput "========================================" Cyan
    Write-Host ""
}
else {
    Write-ColorOutput "To undo later, run: .\Rename-StudentPhotos.ps1 -Undo" Gray
}

Write-Host ""
Wait-ForExit
exit $EXIT_SUCCESS
