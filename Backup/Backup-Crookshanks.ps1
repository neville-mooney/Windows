# ==================================================================================================================================================
# Function to perform robocopy with standardized parameters
# ==================================================================================================================================================

# iS IT A BETTER PLAN TO COPY EVERYTHING THAT i CAN INTO MY ONEDRIVE BACKUP FOLDER FIRST, THEN MIRROR THAT TO THE EXTERNAL DRIVE?
# tHERE'S A FEW ODDITIES OF COURSE, e.G. THE ITUNES AND MOBILESYNC BACKUPS THAT LIVE ON C: DRIVE, BUT PERHAPS IT'S WORTH DOING.
# pERHAPS THIS IS WHAT i COULD USE MY PERSONAL VAULT FOR.
# mIGHT NEED TO GET A SECOND SSD DRIVE TO MAKE THIS MORE PRACTICAL.


function Invoke-RobocopyBackup {
   param(
      [string]$Source,
      [string]$Destination,
      [string]$LogFile
   )
   
   # Ensure destination directory exists
   $destParent = Split-Path $Destination -Parent
   New-Item -Path $destParent -ItemType Directory -Force | Out-Null
   
   # Ensure log directory exists
   $logParent = Split-Path $LogFile -Parent
   New-Item -Path $logParent -ItemType Directory -Force | Out-Null
   
   # Perform robocopy
   robocopy $Source $Destination /z /v /mir /mt /XA:SH /log:$LogFile /tee
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
      Name         = "Librios OneDrive"
      Source       = "C:\Users\Neville Mooney.CROOKSHANKS\OneDrive - Librios"
      Destinations = @(
         @{
            Path = "C:\OneDrive\My Backups\Librios\OneDrive"
            Log  = Get-TimestampedLogFile "C:\OneDrive\My Backups\Logs\Librios\OneDrive.log"
         },
         @{
            Path = "F:\My Backups\Librios\OneDrive"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Librios\OneDrive.log"
         }
      )
   },
   @{
      Name         = "Librios Teams"
      Source       = "C:\Users\Neville Mooney.CROOKSHANKS\Librios"
      Destinations = @(
         @{
            Path = "C:\OneDrive\My Backups\Librios\Teams"
            Log  = Get-TimestampedLogFile "C:\OneDrive\My Backups\Logs\Librios\Teams.log"
         },
         @{
            Path = "F:\My Backups\Librios\Teams"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Librios\Teams.log"
         }
      )
   },
   @{
      Name         = "ios"
      Source       = "D:\ios"
      Destinations = @(
         @{
            Path = "C:\OneDrive\My Backups\Librios\ios"
            Log  = Get-TimestampedLogFile "C:\OneDrive\My Backups\Logs\Librios\ios.log"
         },
         @{
            Path = "F:\My Backups\Librios\ios"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Librios\ios.log"
         }
      )
   },
   @{
      Name         = "Radio"
      Source       = "D:\Radio"
      Destinations = @(
         @{
            Path = "C:\OneDrive\My Backups\Radio"
            Log  = Get-TimestampedLogFile "C:\OneDrive\My Backups\Logs\Radio.log"
         },
         @{
            Path = "F:\My Backups\Radio"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Radio.log"
         }
      )
   },
   @{
      Name         = "Apple - iTunes"
      Source       = "D:\iTunes"
      Destinations = @(
         <# I don't do this anymore because the HDD space on C is not enough to be comfortable.
         @{
            Path = "C:\OneDrive\My Backups\Apple\iTunes"
            Log  = Get-TimestampedLogFile "C:\OneDrive\My Backups\Logs\Apple\iTunes.log"
         },#>
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
         <# I don't do this anymore because the HDD space on C is not enough to be comfortable.
         @{
            Path = "C:\OneDrive\My Backups\Apple\MobileSync"
            Log  = Get-TimestampedLogFile "C:\OneDrive\My Backups\Logs\Apple\MobileSync.log"
         },#>
         @{
            Path = "F:\My Backups\Apple\MobileSync"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\Apple\MobileSync.log"
         }
      )
   },
   @{
      Name         = "Crookshanks Drivers"
      Source       = "D:\HP Elite Desk 800 G4"
      Destinations = @(
         @{
            Path = "C:\OneDrive\My Backups\HP Elite Desk 800 G4"
            Log  = Get-TimestampedLogFile "C:\OneDrive\My Backups\Logs\HP Elite Desk 800 G4.log"
         },#>
         @{
            Path = "F:\My Backups\HP Elite Desk 800 G4"
            Log  = Get-TimestampedLogFile "F:\My Backups\Logs\HP Elite Desk 800 G4.log"
         }
      )
   }   
)


# ==================================================================================================================================================
# Perform backups for each source and destination
# ==================================================================================================================================================
foreach ($job in $backupJobs) {
   foreach ($dest in $job.Destinations) {
      Write-Host "Backing up '$($job.Name)' from '$($job.Source)' to '$($dest.Path)', Log:'$($dest.Log)...'"
      Invoke-RobocopyBackup -Source $job.Source -Destination $dest.Path -LogFile $dest.Log | Out-Null
      Write-Host "Backup completed."
   }
}
# ==================================================================================================================================================