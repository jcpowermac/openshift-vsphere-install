#!/usr/bin/pwsh

# TODO: Folder, Resource Pool
# TODO: CoreDNS, HAProxy and DHCP

$installConfigFile = "/srv/origin/install-config.yaml"
$openshiftInstallBinary = "/srv/origin/openshift-install"
$openshiftInstallCreateIgnArgs = @("create", "ignition-configs")
$openshiftInstallWaitBootstrapArgs = @("wait-for", "bootstrap-complete")
$openshiftInstallWaitInstallCompleteArgs = @("wait-for", "install-complete")
$rhcosOvaFile = "/srv/origin/rhcos.ova"

$originVirtualMachines = @{bootstrap = "boostrap";
    cp0                              = "master";
    cp1                              = "master";
    cp2                              = "master";
    w0                               = "worker";
    w1                               = "worker";
    w2                               = "worker"
}

if (-Not (Test-Path -Path $installConfigFile)) {
    Write-Error "An openshift-install install-config.yaml file is required before running this PowerShell script."
    exit
}

# Download Binary and RHCOS OVA
Get-InstallBinary
Get-OVA

# Import yaml to use existing install-config.yaml file
Import-Module powershell-yaml

# Allow invalid vCenter certificate
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false

# Read the contents of the install-config.yaml
try {
    $installConfig = Get-Content -raw $installConfigFile |
        ConvertFrom-Yaml

    $vsphere = $installConfig['platform']['vsphere']
}
catch {
    Write-Error "install-config.yaml is formatted incorrectly: "
    Write-Error $_
    exit
}

try {
    Connect-VIServer -User $vsphere['username'] -Password $vsphere['password'] -Server $vsphere['vcenter']
}
catch {
    Write-Error "Unable to connect to vCenter: "
    Write-Error $_
    exit
}


try {
    #$process = Start-Process -FilePath $openshiftInstallBinary -ArgumentList $openshiftInstallCreateIgnArgs -Wait -Confirm:$true
    Start-Process -FilePath $openshiftInstallBinary -ArgumentList $openshiftInstallCreateIgnArgs -Wait -Confirm:$true
}
catch {
    Write-Error "openshift-install command failed:"
    Write-Error $_
    exit
}

foreach ($key in $originVirtualMachines.Keys) {
    $type = $oVM[$key]
    New-OpenShiftVM -Name $key `
        -Type $type `
        -Folder jcallen `
        -Template rhcos-latest `
        -ResourcePool jcallen `
        -Datastore ds-nmve1
}

# Wait for openshift-install to complete bootstrap and install-complete
Wait-ForOpenShiftInstall

function New-OpenShiftVM {
    Param($Name, $Type, $Folder, $Template, $ResourcePool, $Datastore)

    try {
        $content = Get-Content -raw "/srv/origin/$($Type).ign"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($content)
        $encoded = [Convert]::ToBase64String($bytes)
    }
    catch {
        Write-Error "An error occurred with ignition file:"
        Write-Error $_
        exit
    }

    try {
        # Create RHCOS Virtual Machine
        $vm = New-VM `
            -name $Name `
            -Location $Folder `
            -VM $Template `
            -DiskStorageFormat thin `
            -Datastore $Datastore `
            -ResourcePool $ResourcePool

        # Set the number of CPUs and Memory
        $vm |
            Set-VM -NumCpu 4 -MemoryGB 8 -Confirm:$false

        # Change the hard disk capactiy to 60 GB
        $vm |
            Get-HardDisk |
            Set-HardDisk -capacitygb 60 -Confirm:$false

        # Create a new advanced virtual machine configuration setting for ignition
        $vm |
            New-AdvancedSetting `
                -name "guestinfo.ignition.config.data.encoding" `
                -value "base64" `
                -confirm:$false

        $vm |
            New-AdvancedSetting `
                -name "disk.EnableUUID" `
                -value $true `
                -confirm:$false

        # Create a new advanced virtual machine configuration setting for ignition data
        $vm |
            New-AdvancedSetting `
                -name "guestinfo.ignition.config.data" `
                -value $encoded `
                -confirm:$false `
                -Force
    }
    catch {
        Write-Error "Failed to configure virtual machine: "
        Write-Error $_
        exit
    }
}
function Get-InstallBinary {
    # first list the http directory
    $url = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/"
    $match = "install-linux"
    Write-Host "Downloading openshift-install..."
    Invoke-MatchWebRequest -Uri $url -Match $match -OutFile $openshiftInstallBinary
}

function Get-OVA {
    $url = "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.1/latest/"
    $match = "vmware"
    Write-Host "Downloading RHCOS OVA..."
    Invoke-MatchWebRequest -Uri $url -Match $match -OutFile $rhcosOvaFile
}

function Invoke-MatchWebRequest {
    Param($Uri, $Match, $OutFile)
    try {
        $dirlist = Invoke-WebRequest -Uri $url
        $filename = ($dirlist.Links |
                Where-Object { $_.href -match $Match }).href
        Invoke-WebRequest -Uri "$($Uri)/$($filename)" -OutFile $OutFile
    }
    catch {
        Write-Error "Failed to download $($filename):"
        Write-Error $_
        exit
    }
}

# TODO: this function could be simplified
function Wait-ForOpenShiftInstall {
    try {
        Start-Process -FilePath $openshiftInstallBinary -ArgumentList $openshiftInstallWaitBootstrapArgs -Wait -Confirm:$true
    }
    catch {
        Write-Error "openshift-install command failed:"
        Write-Error $_
        exit
    }

    Stop-VM -VM "bootstrap"

    try {
        Start-Process -FilePath $openshiftInstallBinary -ArgumentList $openshiftInstallWaitInstallCompleteArgs -Wait -Confirm:$true
    }
    catch {
        Write-Error "openshift-install command failed:"
        Write-Error $_
        exit
    }
}