<#
   Purpose:
      Runs one or more backup jobs using robocopy from a central $backupJobs array.

   How it works:
      - Each job defines Name, Source, optional FileMask, and one or more Destinations.
      - If FileMask is omitted or blank, "*" is used.
      - A timestamped log file is written per destination.
      - Log files older than one month are deleted at the end.

   Version History:
      v1.0.0  (2025 sometime):
         - Initial multi-job robocopy backup structure.

      v1.1.0  (2026-06-24):
         - Added per-job FileMask support and robust default to "*" when not specified.

      v1.2.0  (2026-06-24):
         - Changed masked backups to use /S (no empty folders) and kept /MIR for full backups.

      v1.3.0  (2026-06-24):
         - Added masked destination pruning so only mask-matching files and their containing folders remain.
         - Applied the same masked behavior to files at the destination root.
         
#>



# ==================================================================================================================================================
# Function to perform robocopy with standardized parameters
# ==================================================================================================================================================

# iS IT A BETTER PLAN TO COPY EVERYTHING THAT i CAN INTO MY ONEDRIVE BACKUP FOLDER FIRST, THEN MIRROR THAT TO THE EXTERNAL DRIVE?
# tHERE'S A FEW ODDITIES OF COURSE, e.G. THE ITUNES AND MOBILESYNC BACKUPS THAT LIVE ON C: DRIVE, BUT PERHAPS IT'S WORTH DOING.
# pERHAPS THIS IS WHAT i COULD USE MY PERSONAL VAULT FOR.
# mIGHT NEED TO GET A SECOND SSD DRIVE TO MAKE THIS MORE PRACTICAL.


# ==================================================================================================================================================
# Keep destination aligned to only files matching the mask (and folders containing them).
function Sync-MaskedDestination {
   param(
      [string]$Source,
      [string]$Destination,
      [string]$FileMask
   )

   if (-not (Test-Path -LiteralPath $Destination)) {
      return
   }

   $sourceRoot = [System.IO.Path]::GetFullPath($Source)
   $destinationRoot = [System.IO.Path]::GetFullPath($Destination)

   $matchedRelativePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
   Get-ChildItem -Path $sourceRoot -Recurse -File -Filter $FileMask -ErrorAction SilentlyContinue | ForEach-Object {
      $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $_.FullName)
      [void]$matchedRelativePaths.Add($relativePath)
   }

   # Remove destination files that are not present in the source masked set (including root files).
   Get-ChildItem -Path $destinationRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
      $relativePath = [System.IO.Path]::GetRelativePath($destinationRoot, $_.FullName)
      if (-not $matchedRelativePaths.Contains($relativePath)) {
         Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
      }
   }

   # Remove folders bottom-up so only folders containing matched files remain.
   Get-ChildItem -Path $destinationRoot -Recurse -Directory -ErrorAction SilentlyContinue |
      Sort-Object { $_.FullName.Length } -Descending |
      ForEach-Object {
         $hasContent = Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1
         if (-not $hasContent) {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
         }
      }
}

# ==================================================================================================================================================


function Invoke-RobocopyBackup {
   param(
      [string]$Source,
      [string]$Destination,
      [string]$LogFile,
      [string]$FileMask = "*"
   )
   
   # Ensure destination directory exists
   $destParent = Split-Path $Destination -Parent
   New-Item -Path $destParent -ItemType Directory -Force | Out-Null
   
   # Ensure log directory exists\
   $logParent = Split-Path $LogFile -Parent
   New-Item -Path $logParent -ItemType Directory -Force | Out-Null
   
   # For full backups, mirror source and destination.
   # For masked backups, copy matching files recursively, then prune destination to masked content only.
   if ($FileMask -eq "*") {
      robocopy $Source $Destination $FileMask /z /v /mir /mt /XA:SH /log:$LogFile /tee
   }
   else {
      robocopy $Source $Destination $FileMask /z /v /s /mt /XA:SH /log:$LogFile /tee
      Sync-MaskedDestination -Source $Source -Destination $Destination -FileMask $FileMask
   }
}
function Get-TimestampedLogFile {
   param(
      [string]$LogFile
   )
   $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
   $base = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
   $ext = [System.IO.Path]::GetExtension($LogFile)
   $dir = Split-Path $LogFile -Parent
   return Join-Path $dir "${base}_${timestamp}${ext}"
}

# ==================================================================================================================================================
# Define sources and their destinations/logs in a single data structure
# ==================================================================================================================================================
$backupJobs = @(
   @{
      Name         = "Crookshanks Drivers"
      Source       = "D:\Crookshanks Docs and Drivers"
      Destinations = @(
         @{
            Path = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Crookshanks Docs and Drivers"
            Log  = Get-TimestampedLogFile "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Logs\Crookshanks Docs and Drivers.log"
         },
         @{
            Path = "F:\My Backups\Crookshanks Docs and Drivers"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Crookshanks Docs and Drivers.log"
         }
      )
   },
   @{
      Name         = "Radio"
      Source       = "D:\Radio"
      Destinations = @(
         @{
            Path = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Radio"
            Log  = Get-TimestampedLogFile "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Logs\Radio.log"
         },
         @{
            Path = "F:\My Backups\Radio"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Radio.log"
         }
      )
   },
   @{
      Name         = "ios"
      Source       = "D:\ios"
      FileMask     = "*ioscode.zip"
      Destinations = @(
         @{
            Path = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Librios\ios"
            Log  = Get-TimestampedLogFile "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Logs\Librios\ios.log"
         }<#,
         @{
            Path = "F:\My Backups\Librios\ios"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Librios\ios.log"
         }#>
      )
   },
   @{
      Name         = "Librios OneDrive"
      Source       = "C:\OneDrive - Librios"
      Destinations = @(
         @{
            Path = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Librios\OneDrive"
            Log  = Get-TimestampedLogFile "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Logs\Librios\OneDrive.log"
         },
         @{
            Path = "F:\My Backups\Librios\OneDrive"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Librios\OneDrive.log"
         }
      )
   },
   @{
      Name         = "Librios Teams"
      Source       = "C:\Librios"
      Destinations = @(
         @{
            Path = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Librios\Teams"
            Log  = Get-TimestampedLogFile "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Logs\Librios\Teams.log"
         },
         @{
            Path = "F:\My Backups\Librios\Teams"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Librios\Teams.log"
         }
      )
   },
   @{
      Name         = "Apple - iTunes"
      Source       = "D:\iTunes"
      Destinations = @(
         # I don't do this anymore because the HDD space on C is not enough to be comfortable.
         #@{
         #   Path = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Apple\iTunes"
         #   Log  = Get-TimestampedLogFile "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Logs\Apple\iTunes.log"
         #},
         @{
            Path = "F:\My Backups\Apple\iTunes"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Apple\iTunes.log"
         }
      )
   },
   @{
      Name         = "Apple - MobileSync"
      Source       = "C:\Users\Neville Mooney.CROOKSHANKS\AppData\Roaming\Apple Computer\MobileSync"
      Destinations = @(
         ## I don't do this anymore because the HDD space on C is not enough to be comfortable.
         #@{
         #   Path = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Apple\MobileSync"
         #   Log  = Get-TimestampedLogFile "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive\My Backups\Logs\Apple\MobileSync.log"
         #},
         @{
            Path = "F:\My Backups\Apple\MobileSync"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Apple\MobileSync.log"
         }
      )
   }
)


# ==================================================================================================================================================
# Perform backups for each source and destination
# ==================================================================================================================================================
foreach ($job in $backupJobs) {
   foreach ($dest in $job.Destinations) {
      $fileMask = if ([string]::IsNullOrWhiteSpace([string]$job.FileMask)) { "*" } else { $job.FileMask }
      Write-Host "Backing up '$($job.Name)' from '$($job.Source)' to '$($dest.Path)', Mask:'$fileMask', Log:'$($dest.Log)...'"
      Invoke-RobocopyBackup -Source $job.Source -Destination $dest.Path -LogFile $dest.Log -FileMask $fileMask | Out-Null
      Write-Host "Backup completed."
   }
}
# ==================================================================================================================================================


# Remove log files older than 1 month from all log directories
$logDirs = $backupJobs | ForEach-Object {
   $_.Destinations | ForEach-Object {
      Split-Path $_.Log -Parent
   }
} | Select-Object -Unique

foreach ($dir in $logDirs) {
   Get-ChildItem -Path $dir -Filter *.log -File | Where-Object {
      $_.LastWriteTime -lt (Get-Date).AddMonths(-1)
   } | Remove-Item -Force
}