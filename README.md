# PowerShell Utilities

A collection of PowerShell scripts for automation and productivity.

## Scripts

### any2pdf/doc2pdf.ps1
Batch convert Word documents (.doc, .docx) to PDF.

**Features:**
- Interactive and non-interactive modes
- User-friendly validation and error messages
- Automatic Word document detection
- Folder browser integration
- Defensive validation for non-technical users

**Usage:**

```powershell
# Interactive mode (with confirmation dialogs)
.\any2pdf\doc2pdf.ps1 "path\to\folder"

# Non-interactive mode (no prompts, suitable for automation)
.\any2pdf\doc2pdf.ps1 -Force "path\to\folder"

# No arguments - shows folder browser dialog
.\any2pdf\doc2pdf.ps1
```

**Flags:**
- `-Force` or `-f` - Run in non-interactive mode (suppresses all dialogs)

**Requirements:**
- Microsoft Word installed
- Windows PowerShell 5.1+ or PowerShell 7+

## Installation

1. Clone this repository or download the scripts
2. Run scripts from the repository root

## Development

Scripts are designed with:
- Defensive validation for non-technical users
- Clear, informative error messages
- Support for both interactive and automated use cases
- Proper COM object cleanup and error handling

## License

MIT License - See LICENSE file for details
