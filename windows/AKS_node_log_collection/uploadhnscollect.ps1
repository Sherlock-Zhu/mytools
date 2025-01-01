### start upload
param
(
    [Parameter(Mandatory=$true)]
    [string]$EventSessionName,    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,   
    [Parameter(Mandatory=$true)]
    [string]$ContainerName,
    [Parameter(Mandatory=$true)]
    [string]$SASPasswd
)
$mycontainer = "https://" + $StorageAccountName + ".blob.core.windows.net/" + $ContainerName + "/"
$sasword = "?" + $SASPasswd 
 
while ($true) {
    Write-Output "log auto transfer process start"
    $EtlRecordName = '*' + $EventSessionName + 'record*'
    $files = Get-ChildItem -Path 'C:\' -File | Where-Object { $_.Name -like $EtlRecordName } # 检查是否存在record文件
    if ($files) {
        foreach ($file in $files) {
            try {
                $hnsfile = [System.IO.Path]::ChangeExtension($file.FullName, ".etl") # 获得etl文件名
                $hnsfilename = [System.IO.Path]::ChangeExtension($file.Name, ".etl")
                $uploaduri = $mycontainer + $hnsfilename + $sasword
                Invoke-WebRequest -Uri "$uploaduri" -Method Put -InFile "$hnsfile" -Headers @{"x-ms-version"="2019-12-12";"x-ms-blob-type"="BlockBlob"} -UseBasicParsing
                Write-Output "successfully upload file: $hnsfile"
            } catch {
                Write-Error "Failed to upload: $hnsfile. Error: $_"
            }
            try {
                Remove-Item -Path $hnsfile -Force
                Write-Output "Deleted: $hnsfile"            
                Remove-Item -Path $file.FullName -Force
                Write-Output "Deleted: $($file.FullName)"            
            } catch {
                Write-Error "Failed to delete file: $hnsfile. Error: $_"
            }
        }
    } else {
        Write-Output "No Record file is found."
    }
    Start-Sleep -Seconds 10
}
