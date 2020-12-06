# Creates x number of randomly named resource groups.
# Useful for testing various scenarios or automations.


$x = 5 # Number of RGs to create
$location = "centralus"

$i=0
while ($i -lt $x) {
    $num = Get-Random -Maximum 1000
    $name = "test-$num"

    $new = New-AzResourceGroup -Name $name -Location $location
    if ($new) {
        Write-Host "Created $name"
		$i++
    }
}
