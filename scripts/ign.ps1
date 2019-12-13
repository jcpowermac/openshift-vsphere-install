#!/usr/bin/pwsh

Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false

$server = "172.31.54.15"
try {
    Connect-VIServer -User 'administrator@vsphere.local' -Password  -Server $server
}
catch {
    Write-Error "Unable to connect to vCenter: "
    Write-Error $_
    exit
}

$vm = get-vm -name "ign-test"

$vm | New-AdvancedSetting `
-name "guestinfo.ignition.config.data.encoding" `
-value "base64" `
-confirm:$false `
-Force

$vm | New-AdvancedSetting `
-name "ignition.config.data.encoding" `
-value "base64" `
-confirm:$false `
-Force


$bytes = [System.IO.File]::ReadAllBytes('/srv/origin/vmware.ign')

$encoded = [Convert]::ToBase64String($bytes)

$vm | New-AdvancedSetting `
  -name "guestinfo.ignition.config.data" `
  -value $encoded`
  -confirm:$false `
  -Force > $null


$vm | New-AdvancedSetting `
  -name "ignition.config.data" `
  -value $encoded`
  -confirm:$false `
  -Force > $null

