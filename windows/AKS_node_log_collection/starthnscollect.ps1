### start capture
param
(
    [Parameter(Mandatory=$true)]
    [string]$SessionName,  
    [Parameter(Mandatory=$true)]
    [int]$Period   
)

if ($SessionName -eq 'HnsPacketCapture') {
    $CapScript = 'C:\k\debug\startpacketcapture.ps1'
} elseif ($SessionName -eq 'HnsCapture') {
    $CapScript = 'C:\k\debug\starthnstrace.ps1'
} else {
    Write-Error "supported SessionName: HnsPacketCapture, HnsCapture"
    exit 1
}

while ($true) {
    $currentTime = Get-Date -Format "MMddHHmmss"  # 获取当前时间，并格式化为年月日时分秒
    Write-Output "${currentTime}: log collection process start"
    $hnsfileName = "c:\" + $SessionName + $currentTime + ".etl"  # 文件名格式为 testfile+当前时间.txt
    $recordfileName = $SessionName + $currentTime + "." + $SessionName + "record"  # 文件名格式为 testfile+当前时间.txt
    # powershell $CapScript -EtlFile $hnsfileName -NoPrompt -maxFileSize 1000 # start capture script
    powershell $CapScript -EtlFile $hnsfileName -NoPrompt -maxFileSize 2000 # temporarily expand it to 2000
    Start-Sleep -Seconds $Period
    Stop-NetEventSession $SessionName  # stop capture session
    Remove-NetEventSession $SessionName  # remove capture session
    New-Item -Path "C:\" -Name $recordfileName -ItemType File  # 创建record文件
    Start-Sleep -Seconds 1
}

