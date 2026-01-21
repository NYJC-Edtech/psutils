Add-Type -AssemblyName System.Windows.Forms

function Test-ValidDirectory {
    param([string]$Path)

    # Check if path is empty or whitespace
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @{
            Valid = $false
            Message = "No directory path provided. Please provide a valid folder path."
        }
    }

    # Check if path exists
    if (-not (Test-Path -Path $Path)) {
        return @{
            Valid = $false
            Message = "The directory '$Path' does not exist. Please check the path and try again."
        }
    }

    # Check if it's actually a directory (not a file)
    $item = Get-Item -Path $Path -ErrorAction SilentlyContinue
    if ($item -and -not $item.PSIsContainer) {
        return @{
            Valid = $false
            Message = "'$Path' is a file, not a directory. Please provide a folder path."
        }
    }

    # Check if directory contains any Word documents
    $wordFiles = Get-ChildItem -Path $Path -Filter *.doc? -File -ErrorAction SilentlyContinue
    if (-not $wordFiles) {
        return @{
            Valid = $false
            Message = "No Word documents (.doc or .docx files) found in '$Path'. Please select a folder containing Word documents."
        }
    }

    return @{
        Valid = $true
        Message = ""
        FileCount = ($wordFiles | Measure-Object).Count
    }
}

function Show-FolderDialog {
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select a folder containing Word documents"
    $folderBrowser.ShowNewFolderButton = $false

    if ($folderBrowser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    return $folderBrowser.SelectedPath
}

# Main script logic
$documents_path = $null
$nonInteractive = $false

# Parse arguments for flags and directory
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    if ($arg -eq "-Force" -or $arg -eq "-NonInteractive" -or $arg -eq "-f") {
        $nonInteractive = $true
    } elseif ($null -eq $documents_path) {
        $documents_path = $arg
    }
}

# Validate the provided directory if we have one
if ($documents_path) {
    $validation = Test-ValidDirectory -Path $documents_path

    if ($validation.Valid) {
        Write-Host "✓ Valid directory found: $documents_path" -ForegroundColor Green
        Write-Host "✓ Found $($validation.FileCount) Word document(s) to convert" -ForegroundColor Green
    } else {
        Write-Host "✗ Error: $($validation.Message)" -ForegroundColor Red

        if ($nonInteractive) {
            Write-Host "Exiting (non-interactive mode)." -ForegroundColor Red
            exit 1
        }

        Write-Host ""
        Write-Host "Would you like to select a different folder?" -ForegroundColor Yellow

        $retry = [System.Windows.Forms.MessageBox]::Show(
            "The provided directory is not valid.`n`n$($validation.Message)`n`nWould you like to select a different folder?",
            "Invalid Directory",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        if ($retry -eq [System.Windows.Forms.DialogResult]::Yes) {
            $documents_path = Show-FolderDialog
        } else {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 1
        }
    }
}

# If no valid directory yet, show folder browser (unless non-interactive)
if ($null -eq $documents_path) {
    if ($nonInteractive) {
        Write-Host "✗ Error: No directory path provided and running in non-interactive mode." -ForegroundColor Red
        Write-Host "Usage: .\doc2pdf.ps1 [-Force] <directory_path>" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Please select a folder containing Word documents..." -ForegroundColor Cyan
    $documents_path = Show-FolderDialog

    if ($null -eq $documents_path) {
        Write-Host "No folder selected. Exiting." -ForegroundColor Yellow
        exit 1
    }

    # Validate the selected directory
    $validation = Test-ValidDirectory -Path $documents_path
    if (-not $validation.Valid) {
        Write-Host "✗ Error: $($validation.Message)" -ForegroundColor Red

        $tryAgain = [System.Windows.Forms.MessageBox]::Show(
            $validation.Message,
            "Invalid Folder",
            [System.Windows.Forms.MessageBoxButtons]::RetryCancel,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        if ($tryAgain -eq [System.Windows.Forms.DialogResult]::Retry) {
            $documents_path = Show-FolderDialog
            if ($null -eq $documents_path) {
                Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 1
        }
    }

    # Re-validate after retry
    $validation = Test-ValidDirectory -Path $documents_path
    if (-not $validation.Valid) {
        Write-Host "✗ Error: $($validation.Message)" -ForegroundColor Red
        Write-Host "Unable to continue. Exiting." -ForegroundColor Red
        exit 1
    }

    Write-Host "✓ Found $($validation.FileCount) Word document(s) to convert" -ForegroundColor Green
}

# Final confirmation before proceeding
if ($nonInteractive) {
    Write-Host "Running in non-interactive mode. Starting conversion..." -ForegroundColor Cyan
} else {
    $confirmation = @"
This script will:
• Convert ALL .doc and .docx files in: $documents_path
• Save the PDFs in the SAME folder

Microsoft Word will be opened invisibly during the process.

Found $($validation.FileCount) document(s) to convert.

Do you want to continue?
"@

    $result = [System.Windows.Forms.MessageBox]::Show(
        $confirmation,
        "Word to PDF Conversion",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        exit 1
    }
}

# Start Word
$word_app = New-Object -ComObject Word.Application

# Set visibility based on mode
if ($nonInteractive) {
    $word_app.Visible = $false
    $word_app.DisplayAlerts = 0  # wdAlertsNone - suppress all alerts in non-interactive mode
} else {
    $word_app.Visible = $true
    # Keep alerts enabled in interactive mode so user can see and respond to dialogs
}

try {
    # Find .doc and .docx files
    Get-ChildItem -Path $documents_path -Filter *.doc? -File | ForEach-Object {

        Write-Host "Converting $($_.Name)..." -ForegroundColor Cyan

        try {
            # Open document with parameters to suppress dialogs in non-interactive mode
            # Parameters: FileName, ConfirmConversions, ReadOnly
            $openConfirmConversions = $false
            $openReadOnly = $true

            if ($nonInteractive) {
                # Non-interactive: suppress all dialogs, open as read-only if needed
                $document = $word_app.Documents.Open($_.FullName, $openConfirmConversions, $openReadOnly)
            } else {
                # Interactive: let Word show any dialogs
                $document = $word_app.Documents.Open($_.FullName)
            }

            Write-Host "  Document opened successfully" -ForegroundColor Green

            $pdfPath = Join-Path $_.DirectoryName ($_.BaseName + ".pdf")
            Write-Host "  Target PDF: $pdfPath" -ForegroundColor Gray

            # Use SaveAs with proper type casting
            Write-Host "  Saving as PDF..." -ForegroundColor Gray
            $wdFormatPDF = 17
            $pdfPathRef = [string]$pdfPath
            $formatRef = [int]$wdFormatPDF

            # In non-interactive mode, overwrite existing PDFs without prompting
            if ($nonInteractive) {
                $document.SaveAs([ref]$pdfPathRef, [ref]$formatRef)
            } else {
                # Interactive mode: let Word handle overwrite prompts
                $document.SaveAs([ref]$pdfPathRef, [ref]$formatRef)
            }

            Write-Host "  ✓ Conversion complete" -ForegroundColor Green

            $document.Close()
        }
        catch {
            Write-Host "  ✗ Error converting $($_.Name): $($_.Exception.Message)" -ForegroundColor Red
            if ($document) {
                $document.Close($false)
            }
        }
    }
}
finally {
    # Always quit Word
    $word_app.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word_app) | Out-Null
}

Write-Host "Conversion complete."