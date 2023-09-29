# Check if the script is running with administrative privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script with administrative privileges."
    Exit
}

# Install Hyper-V feature
Write-Host "Installing Hyper-V feature..."
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

Write-Host "Hyper-V installation completed successfully."
