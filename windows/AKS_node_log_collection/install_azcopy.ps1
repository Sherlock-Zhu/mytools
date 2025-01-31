# =============================================================================
# Install AzCopy on Windows (PowerShell)
# https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10
# https://github.com/Azure/azure-storage-azcopy
# -----------------------------------------------------------------------------
# Developer.......: Andre Essing (https://www.andre-essing.de/)
#                                (https://github.com/aessing)
#                                (https://twitter.com/aessing)
#                                (https://www.linkedin.com/in/aessing/)
# -----------------------------------------------------------------------------
# THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# =============================================================================

# Download and extract
Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile AzCopy.zip -UseBasicParsing
Expand-Archive ./AzCopy.zip ./AzCopy -Force

# Move AzCopy
mkdir ~\AppData\Local\Programs\AZCopy
Get-ChildItem ./AzCopy/*/azcopy.exe | Move-Item -Destination ~\AppData\Local\Programs\AZCopy\

# Add AzCopy to PATH
$userenv = (Get-ItemProperty -Path 'HKCU:\Environment' -Name Path).path
$newPath = "$userenv;%USERPROFILE%\AppData\Local\Programs\AZCopy;"
New-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value $newPath -Force

# Clean the kitchen
del -Force AzCopy.zip
del -Force -Recurse .\AzCopy\