# PowerShell Utilities

A collection of PowerShell scripts for school/education administration tasks.

## Repository Structure

```
psutils/
├── any2pdf/
│   └── doc2pdf.ps1          # Convert documents to PDF
└── ct_photo_renamer/
    ├── Rename-StudentPhotos.ps1    # Batch rename student photos
    ├── docs/
    │   ├── PRD.md                   # Product requirements document
    │   └── Screenshot*.png          # Usage screenshots
    └── namelist.csv                 # Student name reference (not tracked)
```

## Scripts

### ct_photo_renamer / Rename-StudentPhotos.ps1

Batch-renames student photos based on a CSV reference file. Designed for school staff to rename photos with the format `{Class}_{FullName}.{ext}`.

**Features:**
- GUI folder selection dialog
- CSV-based name mapping
- Automatic backup creation
- Undo functionality (`-Undo` switch)
- Input validation and error handling

**Requirements:**
- Windows 10/11
- PowerShell 5.1+
- `namelist.csv` in script directory with format:
  ```csv
  Full Name,Class
  John Smith,10A
  Jane Doe,10B
  ```

**Usage:**
```powershell
# Rename photos
.\Rename-StudentPhotos.ps1

# Undo a rename operation
.\Rename-StudentPhotos.ps1 -Undo
```

**Documentation:** See [ct_photo_renamer/docs/PRD.md](ct_photo_renamer/docs/PRD.md) for detailed requirements and workflow.

### any2pdf / doc2pdf.ps1

Convert documents to PDF format.

**Usage:**
```powershell
.\doc2pdf.ps1
```

## Setup

1. Clone this repository:
   ```powershell
   git clone https://github.com/NYJC-Edtech/psutils.git
   cd psutils
   ```

2. For `ct_photo_renamer`, create a `namelist.csv` file in the script directory.

## License

See LICENSE file for details.

## Contributing

This is an internal NYJC EdTech project. For questions or issues, please contact the IT department.
