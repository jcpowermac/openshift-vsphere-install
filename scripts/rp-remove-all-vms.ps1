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
    [array]$rpvms = $rp | Get-VM

    if ($rpvms.Length -gt 0) {
        foreach ($vm in $rpvms) {
            $folder[$vm.Folder] = ""        
            #$vm |  Remove-VM -WhatIf:$true
            $vm | Stop-VM -Kill:$true -Confirm:$false  
            $vm | Remove-VM -DeletePermanently:$true -Confirm:$false
        }
        #Remove-Folder -Folder $folder.Keys -WhatIf:$true 
        Remove-Folder -Folder $folder.Keys -Confirm:$false -DeletePermanently:$true
    }

    $rp | Remove-ResourcePool -Confirm:$false
    #$rp | Remove-ResourcePool -WhatIf:$true 
}

Disconnect-VIServer -Confirm:$false -Force:$true