# Hyper-V Server Name or IP address
$HyperVHost = "your_hyper_v_host"

# VM Settings
$VMName = "DCVM"                  # Name of the VM
$VMSwitch = "InternalSwitch"      # Name of the Virtual Switch to connect the VM
$VMGen = 2                        # VM Generation (Gen 2 is recommended for Windows Server 2012 and later)
$VHDPath = "C:\VMs\DCVM.vhdx"     # Path to the VHDX file
$VHDSizeGB = 40                   # Size of the VHDX in GB
$MemoryGB = 4                     # Amount of RAM for the VM in GB
$CPUCount = 2                     # Number of CPU cores for the VM
$DomainName = "your_domain_name"  # Name of the Active Directory domain

# ISO file path for the Windows Server installation media
$ISOPath = "C:\ISO\Windows_Server_ISO.iso"

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

# Set the VM's network adapter to a private network for the domain controller
New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress 192.168.1.10 -PrefixLength 24 -DefaultGateway 192.168.1.1
Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses ("192.168.1.10", "8.8.8.8")  # Use the DC's IP address as the DNS server

# Install the Active Directory Domain Services feature
Invoke-Command -ScriptBlock { Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose } -VMName $VMName

# Promote the server to a domain controller with a new forest
$SafeModeAdministratorPassword = ConvertTo-SecureString "your_admin_password" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ("your_domain\administrator", $SafeModeAdministratorPassword)
Install-ADDSDomainController -NoGlobalCatalog:$false -CreateDnsDelegation:$false -Credential $Credential -Force -Verbose

# Restart the VM to complete the promotion process
Restart-Computer -VMName $VMName -Wait -For PowerShell -Force

# Set the VM to boot from the hard disk (remove the DVD ISO)
Set-VMFirmware -VMName $VMName -FirstBootDevice $null

# Display VM's IP information
$VMNetworkInfo = Get-VMNetworkAdapter -VMName $VMName | Get-NetIPAddress
$VMNetworkInfo | Select-Object IPAddress, InterfaceAlias

# Display Domain Controller information
Get-ADDomainController -Server $VMName -Credential $Credential | Select-Object Name, IPv4Address, Domain, Forest
