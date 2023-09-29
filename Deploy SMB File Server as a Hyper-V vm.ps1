# Hyper-V Server Name or IP address
$HyperVHost = "your_hyper_v_host"

# VM Settings
$VMName = "FileServerVM"         # Name of the VM
$VMSwitch = "InternalSwitch"     # Name of the Virtual Switch to connect the VM
$VMGen = 2                       # VM Generation (Gen 2 is recommended for Windows Server 2012 and later)
$VHDPath = "C:\VMs\FileServerVM.vhdx"  # Path to the VHDX file
$VHDSizeGB = 100                 # Size of the VHDX in GB
$MemoryGB = 4                    # Amount of RAM for the VM in GB
$CPUCount = 2                    # Number of CPU cores for the VM

# ISO file path for the Windows Server installation media
$ISOPath = "C:\ISO\Windows_Server_ISO.iso"

# File Server Settings
$FileServerName = "FileServer"   # Name for the File Server
$FileServerDriveLetter = "D:"    # Drive letter for the File Server data volume
$FileServerDataPath = "D:\Data"  # Path for the File Server data volume

# Create a new VM
New-VM -Name $VMName -SwitchName $VMSwitch -Generation $VMGen -MemoryStartupBytes $MemoryGB*1GB -NewVHDPath $VHDPath -NewVHDSizeBytes $VHDSizeGB*1GB -Path "C:\VMs" -BootDevice CD -Verbose

# Set CPU count for the VM
Set-VMProcessor -VMName $VMName -Count $CPUCount

# Attach the Windows Server installation ISO to the VM
$VM = Get-VM -Name $VMName
$DVDDrive = Get-VMDvdDrive -VM $VM
Set-VMDvdDrive -VM $VM -Path $ISOPath

# Start the VM
Start-VM -Name $VMName

# Wait for VM to boot and install the OS (adjust the sleep time as needed)
Start-Sleep -Seconds 30

# Get the VM's network adapter
$NetworkAdapter = Get-VMNetworkAdapter -VMName $VMName

# Get the MAC address of the network adapter
$MACAddress = $NetworkAdapter.MacAddress

# Configure VM to use DHCP to obtain an IP address (you can modify this for a static IP if needed)
Set-VMNetworkAdapter -VMName $VMName -DhcpGuard Off

# Get the network adapter interface index
$InterfaceIndex = Get-NetAdapter | Where-Object { $_.MacAddress -eq $MACAddress } | Select-Object -ExpandProperty ifIndex

# Set the VM's network adapter to a private network for the file server
New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress 192.168.1.10 -PrefixLength 24 -DefaultGateway 192.168.1.1
Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses ("192.168.1.10", "8.8.8.8")  # Use the VM's IP address as the DNS server

# Install the operating system on the VM (adjust the installation options as needed)
Invoke-Command -ScriptBlock {
    Install-WindowsFeature -Name File-Services -IncludeManagementTools -Verbose
} -VMName $VMName

# Create a new volume for the file server data
Invoke-Command -ScriptBlock {
    New-Partition -DiskNumber 2 -UseMaximumSize -AssignDriveLetter
    Format-Volume -DriveLetter $using:FileServerDriveLetter -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
} -VMName $VMName

# Set the VM to boot from the hard disk (remove the DVD ISO)
Set-VMFirmware -VMName $VMName -FirstBootDevice $null

# Rename the computer to the File Server name
Invoke-Command -ScriptBlock { Rename-Computer -NewName $using:FileServerName -Force -Restart } -VMName $VMName

# Wait for the VM to restart and become available
Start-Sleep -Seconds 60

# Install the File Server role and features
Invoke-Command -ScriptBlock {
    Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools -Verbose
} -VMName $VMName

# Create a shared folder for the file server data
Invoke-Command -ScriptBlock {
    New-SmbShare -Name "DataShare" -Path $using:FileServerDataPath -FullAccess "Everyone"
} -VMName $VMName

# Display VM's IP information
$VMNetworkInfo = Get-VMNetworkAdapter -VMName $VMName | Get-NetIPAddress
$VMNetworkInfo | Select-Object IPAddress, InterfaceAlias

# Display the file server details
"File Server Name: $FileServerName"
"File Server IP: 192.168.1.10"  # Replace with the IP address of the file server
"Data Share Path: \\192.168.1.10\DataShare"  # Replace with the IP address of the file server
