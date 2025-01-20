### start process
## 需要给capture类型作为start指令的参数
param
(
    [Parameter(Mandatory=$true)]
    [string]$FileType,
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,    
    [Parameter(Mandatory=$true)]
    [string]$ContainerName,
    [Parameter(Mandatory=$true)]
    [string]$SASPasswd,

    [int]$Period = 3600
)

if ($FileType -eq 'packetcapture') {
    $EventSessionName = 'HnsPacketCapture'
} elseif ($FileType -eq 'hnstrace') {
    $EventSessionName = 'HnsCapture'
} else {
    Write-Output "supported FileType: packetcapture, hnstrace"
    exit 1
}

# 0. test if container information works:
Write-Output "start testing if storage account information is correct..."
$testfileName = "testupload"+ $currentTime + ".testfile"
$testfilePath = "c:\" + $testfileName
New-Item -Path $testfilePath -ItemType "File" -Force
$mycontainer = "https://" + $StorageAccountName + ".blob.core.windows.net/" + $ContainerName + "/"
$sasword = "?" + $SASPasswd 
$uploaduri = $mycontainer + $testfileName + $sasword
Invoke-WebRequest -Uri "$uploaduri" -Method Put -InFile "$testfilePath" -Headers @{"x-ms-version"="2019-12-12";"x-ms-blob-type"="BlockBlob"} -UseBasicParsing
Write-Host -ForegroundColor Green "Have you seen file $testfileName in your storage account?`n`nif you saw the file, please press y, else please press n`n`n"
while ($true) {
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    # 判断输入
    if ($x.Character -eq 'y') {
        Write-Host "storage account verify passed, continuing..."
        break  
    } elseif ($x.Character -eq 'n') {
        Write-Host "Seems cannot upload file to your storage account, please check if related information provided is correct or any blocker from storage account side. exiting..."
        Remove-Item -Path $testfilePath -Force # remove test file
        break  
    } else {
        Write-Host "Wrong key, please press y or n"
    }
}

# 1. force stop process if any
Write-Output "stop existing capture process if there is any ..."
Stop-NetEventSession $EventSessionName -ErrorAction Ignore | Out-Null
Remove-NetEventSession $EventSessionName -ErrorAction Ignore | Out-Null

# 2. 删除已经存在的AKSHNSlogrecord和etl文件
Write-Output "Delete previous capture file if there is any ..."
$EtlFileName = '*' + $EventSessionName + '*.etl'
$files = Get-ChildItem -Path 'C:\' -File | Where-Object { $_.Name -like $EtlFileName } # 检查是否存在etl文件
if ($files) {
    foreach ($file in $files) {
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Output "successfully deleted file: $($file.FullName)"
        } catch {
            Write-Error "Failed to delete: $($file.FullName). Error: $_"
        }
    }
} else {
    Write-Output "No previous etl file found."
}
$EtlRecordName = '*' + $EventSessionName + 'record*' 
$files = Get-ChildItem -Path 'C:\' -File | Where-Object { $_.Name -like $EtlRecordName } # 检查是否存在record文件
if ($files) {
    foreach ($file in $files) {
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Output "successfully deleted file: $($file.FullName)"
        } catch {
            Write-Output "Failed to delete: $($file.FullName). Error: $_"
        }
    }
} else {
    Write-Output "No previous record file found."
}

# 3. start process
try {
    Start-Process powershell -ArgumentList "-File uploadhnscollect.ps1 -EventSessionName $EventSessionName -StorageAccountName $StorageAccountName -ContainerName $ContainerName -SASPasswd $SASPasswd" -RedirectStandardOutput "uploadhnscollect_out.txt" -RedirectStandardError "uploadhnscollect_err.txt"
} catch {
    Write-Error "Failed to start log upload process, Error: $_"
    exit 1
}
try {        
    Start-Process powershell -ArgumentList "-File starthnscollect.ps1 -SessionName $EventSessionName -Period $Period" -RedirectStandardOutput "starthnscollect_out.txt" -RedirectStandardError "starthnscollect_err.txt"
} catch {
    Write-Error "Failed to start log collection process, Error: $_"
    exit 1
}
Write-Output "process started"

# Get-Process -Name "powershell"
