#!/usr/bin/pwsh

Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false

$server = "vcsa-ci.vmware.devcluster.openshift.com"

try {
    Connect-VIServer $server
}
catch {
    Write-Error "Unable to connect to vCenter: "
    Write-Error $_
    exit
}

$rps = Get-ResourcePool | Where-Object { $_.Name -match 'ci' }

foreach ($rp in $rps) {

    $folder = @{}
    $remove = $False
    [array]$rpvms = $rp | Get-VM

    if ($rpvms.Length -gt 0) {
        foreach ($vm in $rpvms) {
            $vm | Get-VMResourceConfiguration
        }
    }
}

Disconnect-VIServer -Confirm:$false -Force:$true
