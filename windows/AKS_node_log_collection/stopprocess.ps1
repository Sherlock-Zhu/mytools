### stop 
## 需要给capture类型作为stop指令的参数
param
(
    [Parameter(Mandatory=$true)]
    [string]$FileType,    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,    
    [Parameter(Mandatory=$true)]
    [string]$ContainerName,
    [Parameter(Mandatory=$true)]
    [string]$SASPasswd
)

if ($FileType -eq 'packetcapture') {
    $EventSessionName = 'HnsPacketCapture'
} elseif ($FileType -eq 'hnstrace') {
    $EventSessionName = 'HnsCapture'
} else {
    Write-Output "supported FileType: packetcapture, hnstrace"
    exit 1
}

## 1. 停capture
$myprocess = Get-WmiObject Win32_Process | Where-Object { $_.Name -eq "powershell.exe" -and $_.CommandLine -like "*C:\Users\myaks\starthnscollect.ps1*" }
if ($myprocess) {
    Stop-Process -Id $myprocess.ProcessId -Force
    Stop-NetEventSession HnsPacketCapture
    Remove-NetEventSession HnsPacketCapture
    Write-Output "log collection process stopped"
} else {
    Write-Output "no ongoing log collection process found"
}
## 2. 停upload
$myprocess = Get-WmiObject Win32_Process | Where-Object { $_.Name -eq "powershell.exe" -and $_.CommandLine -like "*C:\Users\myaks\uploadhnscollect.ps1*" }
if ($myprocess) {
    Stop-Process -Id $myprocess.ProcessId -Force
    Write-Output "log upload process stoped"
 } else {
    Write-Output "no ongoing log upload process found"
}   
## 3. 检查是否还有AKSHNSlogrecord存在，有的话手动跑一遍upload
$mycontainer = "https://" + $StorageAccountName + ".blob.core.windows.net/" + $ContainerName + "/"
$sasword = "?" + $SASPasswd 
$EtlRecordName = '*' + $EventSessionName + 'record*'
$files = Get-ChildItem -Path 'C:\' -File | Where-Object { $_.Name -like $EtlRecordName } # 检查是否存在record文件
if ($files) {
    foreach ($file in $files) {
        try {
            $hnsfile = [System.IO.Path]::ChangeExtension($file.FullName, ".etl") # 获得etl文件名
            $hnsfilename = [System.IO.Path]::ChangeExtension($file.Name, ".etl")
            $uploaduri = $mycontainer + $hnsfilename + $sasword
            Invoke-WebRequest -Uri "$uploaduri" -Method Put -InFile "$hnsfile" -Headers @{"x-ms-version"="2019-12-12";"x-ms-blob-type"="BlockBlob"} -UseBasicParsing
            Write-Output "successfully upload file: $hnsfilename"
        } catch {
            Write-Error "Failed to delete: $file. Error: $_"
        }
        try {
            Remove-Item -Path $hnsfile -Force
            Write-Output "Deleted: $hnsfile"            
            Remove-Item -Path $file.FullName -Force
            Write-Output "Deleted: $($file.FullName)"            
        } catch {
            Write-Error "Failed to delete: $file. Error: $_"
        }
        Write-Output "uploaded latest log collected"
    }
} else {
    Write-Output "No files found containing 'AKSHNSlogrecord' in their name."
}
## 4. 把最后生成的etl文件上传并删除etl文件
$EtlFileName = '*' + $EventSessionName + '*.etl'
$files = Get-ChildItem -Path 'C:\' -File | Where-Object { $_.Name -like $EtlFileName }
if ($files) {
    foreach ($file in $files) {
        try {
            $uploaduri = $mycontainer + $file.Name + $sasword
            $filepath = $files.FullName
            Invoke-WebRequest -Uri "$uploaduri" -Method Put -InFile "$filepath" -Headers @{"x-ms-version"="2019-12-12";"x-ms-blob-type"="BlockBlob"} -UseBasicParsing
            Write-Output "successfully upload file: $filepath"
        } catch {
            Write-Output "Failed to upload file: $filepath. Error: $_"
        }
        try {
            Remove-Item -Path $filepath -Force
            Write-Output "Deleted file: $filepath"            
        } catch {
            Write-Output "Failed to delete file: $filepath. Error: $_"
        }
        Write-Output "all left etl file uploaded and cleaned."
    }
} else {
    Write-Output "No left etl file found."
}

Write-Output "successfully stopped all process"