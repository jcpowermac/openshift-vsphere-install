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
            $remove = $True
            # first check how long the vm has been around
            $createdTime = (Get-VIEvent $vm | Sort-Object createdTime | Select-Object -first 1).createdTime
            Write-Host "Checking when virtual machine: $($vm.Name) was created: $($createdTime)"
            $totalHours = (New-TimeSpan -Start $createdTime.ToUniversalTime() -End (Get-Date).ToUniversalTime()).TotalHours
            if( $totalHours -lt 24 ) {
                Write-Host "Continuing..."
                $remove = $False
                continue
            }

            $folder[$vm.Folder] = ""
            #$vm |  Remove-VM -WhatIf:$true
            $vm | Stop-VM -Kill:$true -Confirm:$false
            $vm | Remove-VM -DeletePermanently:$true -Confirm:$false
        }
        if($remove) {
                #Remove-Folder -Folder $folder.Keys -WhatIf:$true
                Remove-Folder -Folder $folder.Keys -Confirm:$false -DeletePermanently:$true
        }
    }

    if($remove) {
      $rp | Remove-ResourcePool -Confirm:$false
      #$rp | Remove-ResourcePool -WhatIf:$true
    }
}

Disconnect-VIServer -Confirm:$false -Force:$true
