#!/usr/bin/pwsh

Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false

$server = "vcsa.vmware.devcluster.openshift.com"
try {
    Connect-VIServer -User 'jcallen@e2e.local' -Server $server
}
catch {
    Write-Error "Unable to connect to vCenter: "
    Write-Error $_
    exit
}

$vm = get-vm -name "serial-test"
$vm | New-AdvancedSetting `
-name "guestinfo.ignition.config.data" `
-value "" `
-confirm:$false `
-Force


for ($i=1; $i -le 10; $i++ ) {

        $size = (1024*(512*$i))
        Write-Host "Byte[] Size: $($size)"
        #https://stackoverflow.com/questions/533636/generating-random-files-in-windows
        #https://stackoverflow.com/questions/17474131/creating-byte-in-powershell

        $out = New-Object -TypeName byte[] -Args $size
        (new-object Random).NextBytes($out)

        $o8size = [System.Text.Encoding]::UTF8.GetByteCount($out)
        $oasize = [System.Text.Encoding]::ASCII.GetByteCount($out)
        Write-Host "Random: UTF8: $($o8size) bytes, ASCII: $($oasize) bytes"

        $bytes = [System.Text.Encoding]::ASCII.GetBytes($out)
        $basize = [System.Text.Encoding]::ASCII.GetByteCount($out)
        Write-Host "To ASCII: ASCII: $($basize) bytes"

        $encoded = [Convert]::ToBase64String($bytes)
        $vm | New-AdvancedSetting `
          -name "guestinfo.ignition.config.data" `
          -value $encoded`
          -confirm:$false `
          -Force > $null

        #$vm | start-vm
        Start-Sleep -Seconds 10
        #$vm | Stop-VM -Confirm:$false
        $adv = (($vm | Get-AdvancedSetting -name "guestinfo.ignition.config.data").Value).replace("`n","")
        $a8size = [System.Text.Encoding]::UTF8.GetByteCount($adv)
        $aasize = [System.Text.Encoding]::ASCII.GetByteCount($adv)

        $e8size = [System.Text.Encoding]::UTF8.GetByteCount($encoded)
        $easize = [System.Text.Encoding]::ASCII.GetByteCount($encoded)

        if( $adv -eq $encoded) {
          Write-Host "From vCenter: UTF8: $($a8size) bytes, ASCII: $($aasize) bytes"
          Write-Host "Sent vCenter: UTF8: $($e8size) bytes, ASCII: $($easize) bytes"
        } else {
          Write-Host "$($adv.Length) == $($encoded.Length)"

          $adv.Substring(0,50)
          $encoded.Substring(0,50)
          $adv.Substring($adv.Length - 50)
          $encoded.Substring($encoded.Length - 50)
        }
}
