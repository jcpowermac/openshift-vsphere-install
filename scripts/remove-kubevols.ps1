#!/usr/bin/pwsh

Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false > $null

$server = "vcsa-ci.vmware.devcluster.openshift.com"
$ds = "nvme-ds1"

try {
    Connect-VIServer $server
}
catch {
    Write-Error "Unable to connect to vCenter: "
    Write-Error $_
    exit
}

$datastore = Get-Datastore $ds
$vm = Get-VM to-delete-kubevols-easy


New-PSDrive -Name DS -PSProvider VimDatastore -Root '\' -Location $datastore > $null

#Get-ChildItem -Path "DS:/$($vm.Name)/vmware*.log" | Remove-Item -Confirm:$false
#$kubevols = Get-ChildItem -Recurse -Path "$((Get-Datastore $ds).DatastoreBrowserPath)/kubevols"
#Get-ChildItem -Path "DS:/$($vm.Name)/vmware*.log" | Remove-Item -Confirm:$false
$kubevols = Get-ChildItem -Recurse -Path "DS:/kubevols/"

foreach ($file in $kubevols) {
    $totalHours = (New-TimeSpan -Start $file.LastWriteTime.ToUniversalTime() -End (Get-Date).ToUniversalTime()).TotalHours
    if( $totalHours -gt 315 ) {
        New-HardDisk -vm $vm -DiskPath $file.DatastoreFullPath -Confirm:$false
        Get-HardDisk -VM $vm | Remove-HardDisk -DeletePermanently:$true -Confirm:$false
        #Get-HardDisk -Path $file | Remove-HardDisk -DeletePermanently:$true -Confirm:$false
        #Get-HardDisk -Path $file | Remove-HardDisk -WhatIf:$true

    }
}
Disconnect-VIServer -Confirm:$false -Force:$true


