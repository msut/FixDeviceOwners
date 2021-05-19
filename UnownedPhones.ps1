Import-Module -Name ActiveDirectory

# the models we need to fix.
$PhoneModels = @(
    "Cisco 7940",
    "Cisco 7942",
    "Cisco 7841",
    "Cisco 8841",
    "Cisco 8851",
    "Cisco 8861",
    "Cisco IP Communicator")

<#
.SYNOPSIS
Import an Uplinx phone inventory file

.DESCRIPTION
Import an Uplinx phone inventory file

.PARAMETER UplinxFile
The Uplinx phone inventory file

.EXAMPLE
$UplinxData = Import-UplinxData .\Phone_Inventory_Report.csv

#>
    function Import-UplinxData {

    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [string] $UplinxFile
    )

    $UplinxData = Import-Csv $UplinxFile
    return $UplinxData
}

<#
.SYNOPSIS
Get a list of phones that don't have the Owner User ID field populated.

.DESCRIPTION
Get a list of phones that don't have the Owner User ID field populated.

.PARAMETER UplinxData
The output from Import-UplinxData

.EXAMPLE
$UnownedPhones = Get-UnownedPhones $UplinxData

#>
function Get-UnownedPhones {

    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [System.Object[]] $UplinxData
    )

    $UnownedPhones = $UplinxData | Where-Object {$PhoneModels.Contains($_.model) -and $_.'Owner User ID' -eq ''}
    return $UnownedPhones
}

<#
.SYNOPSIS
All AD users with an ipPhone field populated.

.DESCRIPTION
All AD users with an ipPhone field populated.

.EXAMPLE
$DnToUserMap = Get-DnToAdUserMap

#>
function Get-DnToAdUserMap {
    $UsersWithPhone = Get-ADUser -Filter * -Properties ipphone | Where-Object {$null -ne $_.ipphone}
    $DnToUserMap = @{}
    $UsersWithPhone | ForEach-Object{$DnToUserMap.Add($_.ipphone, $_.samaccountname)}
    return $DnToUserMap
}

<#
.SYNOPSIS
Get a list of devices that have an owner that can be set.

.DESCRIPTION
Get a list of devices that have an owner that can be set.

.PARAMETER DnToUserMap
The output from Get-DnToAdUserMap

.PARAMETER UnownedPhones
The output from Get-UnownedPhones

.EXAMPLE
$PhonesToFix = Get-PhonesToBeFixed -DnToUserMap $DnToUserMap -UnownedPhones $UnownedPhones

#>
function Get-PhonesToBeFixed {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [hashtable] $DnToUserMap,
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [System.Object[]] $UnownedPhones
    )

    $PhonesToFix = @()
    $UnownedPhones | ForEach-Object{
        $user = $DnToUserMap[$_.'1st Extension']
        if($null -ne $user) {
            $PhonesToFix += [pscustomobject]@{
                device = $_.Name
                owner = $user
                }
        }
    }
    return $PhonesToFix
}

<#
.SYNOPSIS
Export to csv the phones to be fixed.

.DESCRIPTION
Export to csv the phones to be fixed.

.PARAMETER Path
The path to save the csv to.

.PARAMETER PhonesToFix
The output from Get-UnownedPhones

.EXAMPLE
Export-PhonesToBeFixed -Path $Path -PhonesToFix $PhonesToFix

#>
function Export-PhonesToBeFixed {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [string] $Path,
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [System.Object[]] $PhonesToFix
    )

    $PhonesToFix | Export-Csv -Path $Path -NoTypeInformation
}

<#
.SYNOPSIS
Given an Uplinx phone inventory report, generate a csv of device-username tuples.

.DESCRIPTION
Driver function to generate a csv of device-username tuples suitable 
for consumption by axl_fixDeviceOwnerId.py

.PARAMETER Path
The path to save the csv to.

.PARAMETER UplinxFile
The location of an Uplinx phone inventory report in csv format.

.EXAMPLE
Export-PhonesToBeFixedFromUplinxFile -Path ./phones_to_fix.csv -UplinxFile ./Phone_Inventory_Report.csv

#>
function Export-PhonesToBeFixedFromUplinxFile {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [string] $Path,
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [string] $UplinxFile
    )

    Write-Host "importing uplinx file"
    $UplinxData = Import-UplinxData $UplinxFile
    Write-Host "getting unowned phones"
    $UnownedPhones = Get-UnownedPhones $UplinxData
    Write-Host "creating DN to AD User map (long...)"
    $DnToUserMap = Get-DnToAdUserMap
    Write-Host "creating list of phones to fix"
    $PhonesToFix = Get-PhonesToBeFixed -DnToUserMap $DnToUserMap -UnownedPhones $UnownedPhones
    Write-Host "exporting list of phones to fix"
    Export-PhonesToBeFixed -Path $Path -PhonesToFix $PhonesToFix
}