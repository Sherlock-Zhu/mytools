cd c:
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Sherlock-Zhu/mytools/main/windows/AKS_node_log_collection/PartnerTTDRecorder_x86_x64.zip" -OutFile "PartnerTTDRecorder_x86_x64.zip"
Expand-Archive .\PartnerTTDRecorder_x86_x64.zip
$path = "c:\PartnerTTDRecorder_x86_x64.zip"
if (Test-Path $path)
{
    Remove-Item -Path $path -Recurse -Force
    Write-Host "find downloaded file and deleted"
}
$path = "c:\PartnerTTDRecorder_x86_x64"
if (Test-Path $path)
{
    Remove-Item -Path $path -Recurse -Force
    Write-Host "find uncompress path and deleted"
}
