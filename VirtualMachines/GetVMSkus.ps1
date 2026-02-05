$allSizes = (Get-AzComputeResourceSku -Location Italynorth | where ResourceType -eq "virtualMachines")
$CC = $AllSizes | where {$_.Name -like "*DC*" -or $_.Name -like "*EC*"}

$CCList = $CC | Select-Object Name, @{Name="Zones";Expression={$_.LocationInfo.Zones}}, @{Name="vCPUs";Expression={[Int]::Parse(($_.Capabilities | where Name -eq vCPUs).Value)}}

$CCList | sort vCPUs | where Name -like "*s*" | select -First 1