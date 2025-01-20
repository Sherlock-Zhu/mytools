cd ..\..\k\debug
ipmo .\vfp.psm1
ipmo .\hns.psm1

#Implement these 4 methods:
# 1. LogMessage - Implements logic to log messages. Defaults to logging to a file.
# 2. StartHandler - Handler invoked after the monitoring starts (before the node is in repro state)
# 3. TerminateHandler - Handler invoked before the monitoring stops (after the node is in repro state)
# 4. Start-HNSTrace - collect windows log and start hns trace
# 5. Stop-HNSTrace - stop hns trace and collect windows log
# 6. CheckKubeletLog - Search kubelet error log for the namespace error
# 7. Start-Monitoring - search Kubelet error log every min for error. If found, stop hns trace.

function LogMessage
{
    param
    (
        [string] $Message = ""
    )

    $FilePath = "C:\k\debug\MonitorWindowsNode_586401471.txt"
    $logEntry = "$(Get-Date) $Message"
    $logEntry | Out-File -FilePath $FilePath -Append
}

function StartHandler
{
    LogMessage "Capturing some information before the repro."
    $hnsInfo = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'hns'"
    $kubeproxyInfo = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'Kubeproxy'"
    LogMessage $hnsInfo
    LogMessage $kubeproxyInfo
}

function TerminateHandler
{
    param
    (
        [string] $LogPath = ""
    )
    LogMessage "Capturing some information after the repro."
    $hnsInfo = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'hns'"
    $kubeproxyInfo = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'Kubeproxy'"
    LogMessage $hnsInfo
    LogMessage $kubeproxyInfo
}

function Start-HNSTrace
{
    param
    (
      [bool] $isPreRepro = $false,
      [string] $path = "c:\586401471"
    )

    & C:\k\debug\collect-windows-logs.ps1
    $sessionName = 'HnsCapture'
    Write-Host "Starting HNS tracing"

    $timeNow = Get-Date -Format u
    $hnsTraceFileName = $timeNow.Replace(" ", "-").Replace(":","-")
    if ($isPreRepro -eq $true) {
      $hnsTraceFilePath = "$path\preRepro_$($hnsTraceFileName).etl"
    } else {
      $hnsTraceFilePath = "$path\Repro_$($hnsTraceFileName).etl"
    }
    & C:\k\debug\starthnstrace.ps1 -maxFileSize 2048 -NoPrompt -EtlFile $hnsTraceFilePath
}

function Stop-HNSTrace
{
    # Stop the tracing
    $sessionName = 'HnsCapture'
    Write-Host "Stopping $sessionName."
    Stop-NetEventSession $sessionName

    # Collect logs
    & C:\k\debug\collect-windows-logs.ps1
}

function CheckKubeletLog
{
    param (
          [Parameter(Mandatory=$false)][AllowEmptyString()] [string] $prevTimestamp = $null
      )

      Write-Host "-------Entering CheckKubeletLog--------"
      $filePath = "C:\k\kubelet.err.log"
      $timePattern = '(\d{4}\s\d{2}:\d{2}:\d{2}\.\d{6})'
      $keyword1 = 'hcs::CreateComputeSystem'
      $keyword2 = 'The requested operation for attach namespace failed.: unknown'
      $foundError = $false

      # find the latest time stamp of the log
      $currentDateTime = (Get-Date).ToUniversalTime()
      $currentTimestamp = $currentDateTime.ToString("MMdd HH:mm:ss.ffffff")
      $latestTimestamp = $currentTimestamp
      Write-Host "The current timestamp is $latestTimestamp"
      LogMessage "The current timestamp is $latestTimestamp"

      if (-not (Test-Path $filePath))
      {
          Write-Host "no kubelet error log found. exiting"
          LogMessage "no kubelet error log found. exiting"
          return @{
              LatestTimestamp = $latestTimestamp
              FoundError = $foundError
          }
      }

      $kubeletLogs = Get-Content -Path $filePath
      $lines = -$kubeletLogs.count
      for ($i = -1; $i -ge $lines; $i--)
      {
          if ($kubeletLogs[$i] -match $timePattern) {
              $timeStamp = $matches[1]
              $latestTimestamp = $timeStamp
              Write-Host "- Got the latest timestamp from the log"
              LogMessage "- Got the latest timestamp from the log"
              break;
          }
      }
      LogMessage "The latest timestamp is $latestTimestamp"
      Write-Host "The latest timestamp is $latestTimestamp"

      # if this is the first time checking log, just get the latest timestamp and exit
      # we don't care what happened before this log collection was started
      if ($prevTimestamp -eq "") {
          LogMessage "checking the kubelet log for the first time. Existing..."
          Write-Host "checking the kubelet log for the first time. Existing..."
          return @{
              LatestTimestamp = $latestTimestamp
              FoundError = $foundError
          }
      }

      # only check the content that is newly logged from the last check
      Write-Host "- Searching the log for any new errors"
      LogMessage "- Searching the log for any new errors"
      for ($i = -1; $i -ge $lines; $i--)
      {
          if ($kubeletLogs[$i] -match $timePattern)
          {
              $timeStamp = $matches[1]
              if ($timeStamp -le $prevTimestamp)
              {
                  # old logs
                  Write-Host "old logs, skipping"
                  LogMessage "old logs, skipping"
                  break;
              }

              # new logs, search for the namespace error
              if ($kubeletLogs[$i] -match "$keyword1.*$keyword2")
              {
                  if ($kubeletLogs[$i] -match $containerIdPattern)
                  {
                      $containerid = $matches[1]
                      LogMessage "***$timeStamp, namespace error found for $containerid***"
                      Write-Host "***$timeStamp, namespace error found for $containerid***"
                      $foundError = $true
                      break;
                  }
              }
          }
      }
      return @{
          LatestTimestamp = $latestTimestamp
          FoundError = $foundError
      }
}

function Start-Monitoring
{
  param
  (
      # Interval to poll kubectl log in seconds
      [int] $PollingInterval = 60
  )

      # terminate any existing trace event
      $sessionName = 'HnsCapture'
      Stop-NetEventSession $sessionName -ErrorAction Ignore | Out-Null
      Remove-NetEventSession $sessionName -ErrorAction Ignore | Out-Null
      $sessionName = 'HnsPacketCapture'
      Stop-NetEventSession $sessionName -ErrorAction Ignore | Out-Null
      Remove-NetEventSession $sessionName -ErrorAction Ignore | Out-Null

      $path = "c:\586401471"
      if (Test-Path $path)
      {
          Remove-Item -Path $path -Recurse -Force
      }
      New-Item $path -Type Directory -Force
      cd $path

      $preReproTraceOngoing = $true
      Start-HNSTrace -isPreRepro $preReproTraceOngoing
      StartHandler

      LogMessage "Started Monitoring"

      $prevTimestamp = ""
      while($true)
      {
          $result = CheckKubeletLog -prevTimestamp $prevTimestamp
          Write-Host "checked kubelet log upto $($result.LatestTimestamp)"
          LogMessage "checked checking kubelet log upto $($result.LatestTimestamp)"
          $prevTimestamp = $result.LatestTimestamp

          # found repro
          if ($result.FoundError -eq $true)
          {
              if ($preReproTraceOngoing -eq $true) {
                  Stop-HNSTrace
                  TerminateHandler
                  $preReproTraceOngoing = $false
              }
              Write-Host "Found namespace error, logs are at $($path)"
              LogMessage "Found namespace error, logs are at $($path)"

              Start-HNSTrace -isPreRepro $preReproTraceOngoing
              # Take captures for 1 mnts
              sleep 60
              Stop-HNSTrace
              TerminateHandler

              # we got a dump, don't check again for at least an hour
              Write-Host "Sleeping for 3600s"
              LogMessage "Sleeping for 3600s"
              sleep 3600
          }
          Write-Host "Sleeping for $PollingInterval between polling"
          LogMessage "Sleeping for $PollingInterval betwen polling"
          Start-Sleep -Seconds $PollingInterval
      }
  }

##### Start execution #########

Start-Monitoring
