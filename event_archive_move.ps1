$NetworkPath = "" #\\127.0.0.1\SharedFolder
$FolderPath = "" # Folder Path 
$RetentionPeriod = -7
$Date= Get-Date -Format "MM-dd-yyyy"
net use * $NetworkPath /user:<domain\user> "password"
$DriveLetter = (Get-PSDrive | Where-Object { $_.DisplayRoot -eq $NetworkPath }).root

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Message,
 
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('INFO','WARN','ERROR')]
        [String]$Severity = 'INFO'
    )
    $Time = (Get-Date -f g)
    Add-Content $DriveLetter$FolderPath\Logs\archive-move-log-$Date.txt [$Severity]:$Time": "$Message
 }


if ([System.IO.Directory]::Exists($DriveLetter)) {
    Write-Host "Drive Mapped: "$DriveLetter
    if (Test-Path ($DriveLetter + $FolderPath)) {

        Write-Host "Path Exists: "$DriveLetter$FolderPath
        Write-Log -Message "Path Exists: $DriveLetter$FolderPath" -Severity INFO

        Get-ChildItem -Path "C:\Windows\System32\winevt\Logs" Archive-Security*.* |
        Where-Object { $_.LastWriteTime -lt (get-date).AddDays($RetentionPeriod) } |
        ForEach-Object {

            $FileName = $PSItem.Name
            $FilePath = $PSItem.FullName

            Write-Host "----------------------------------"
            Write-Host "Copying Started: "$FileName
            Write-Log -Message "----------------------------------" -Severity INFO
            Write-Log -Message "Copying Started: $FileName" -Severity INFO

            $Exclude = Get-ChildItem ($DriveLetter+$FolderPath)

            Write-Host "Hashing Source File"
            Write-Log -Message "Hashing Source File" -Severity INFO

            $SourceFileHash = (Get-FileHash $FilePath -Algorithm "MD5").Hash

            Write-Host "Source#: "$SourceFileHash
            Write-Log -Message "Source#: $SourceFileHash" -Severity INFO

            Copy-Item -Path ($FilePath) -destination ($DriveLetter + $FolderPath) -Exclude $Exclude

            Write-Host "Hashing Destination File"
            Write-Log -Message "Hashing Destination File" -Severity INFO

            $DestFileHash = (Get-FileHash  ($DriveLetter + $FolderPath+"\"+$FileName) -Algorithm "MD5").Hash

            Write-Host "Dest#: "$DestFileHash
            Write-Log -Message "Dest#: $DestFileHash" -Severity INFO

            if($SourceFileHash -eq $DestFileHash){

                Write-Host "Hash Matched"
                Write-Log -Message "Hash Matched" -Severity INFO

                Remove-Item -Path $FilePath

                Write-Host "Removed Source File: "$FileName
                Write-Log -Message "Removed Source File: $FileName" -Severity INFO
            }
            else{
                Write-Host "Hash Not Matched"
                Write-Log -Message "Hash Not Matched" -Severity ERROR

                Remove-Item -Path ($DriveLetter + $FolderPath+"\"+$FileName) -Force

                Write-Host "Removed Copied File: "$FileName
                Write-Log -Message "Removed Copied File: $FileName" -Severity WARN

                Write-Host "Re-Copy Source File: "$FileName
                Write-Log -Message "Re-Copy Source File: $FileName" -Severity INFO

                Copy-Item -Path ($FilePath) -destination ($DriveLetter + $FolderPath) -Exclude $Exclude
                $DestFileReHash = (Get-FileHash  ($DriveLetter + $FolderPath+"\"+$FileName) -Algorithm "MD5").Hash

                Write-Host "DestRe#: "$DestFileReHash
                Write-Log -Message "DestRe#: $DestFileReHash" -Severity INFO

                if($SourceFileHash -eq $DestFileReHash){
                    Remove-Item -Path $FilePath

                    Write-Host "Removed Source File: "$FileName
                    Write-Log -Message "Removed Source File: $FileName" -Severity INFO
                }
                else{
                    Remove-Item -Path ($DriveLetter + $FolderPath+"\"+$FileName) -Force

                    Write-Host "Removed Copied File: "$FileName
                    Write-Log -Message "Removed Copied File: $FileName" -Severity WARN
                    Write-Log -Message "ERROR Coping: $FileName" -Severity ERROR
                }
            }  
        }
        Write-Host "Finished Copying"
        Write-Log -Message "Finished Copying" -Severity INFO
        net use * /delete /y
    }
    else{
        Write-Host "Path Does Not Exist"
        Write-Log -Message "Path Does Not Exist" -Severity ERROR
        net use * /delete /y
    }
}
else{
    Write-Host "Drive Not Mapped"
    Write-Log -Message "Drive Not Mapped" -Severity ERROR
    net use * /delete /y
}


    
