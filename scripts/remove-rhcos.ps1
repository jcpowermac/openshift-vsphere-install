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

$rhcos = Get-VM | Where-Object { $_.Name -match 'rhcos' }

foreach ($vm in $rhcos) {
        $createdTime = (Get-VIEvent $vm | Sort-Object createdTime | Select-Object -first 1).createdTime
        $totalHours = (New-TimeSpan -Start $createdTime.ToUniversalTime() -End (Get-Date).ToUniversalTime()).TotalHours
        Write-Host "Checking when virtual machine: $($vm.Name) was created: $($createdTime) totalHours: $($totalHours)"
        # being lazy...730 in a month
        if( $totalHours -gt 315 ) {
                $vm | Remove-VM -DeletePermanently:$true -Confirm:$false
        }
}
Disconnect-VIServer -Confirm:$false -Force:$true

