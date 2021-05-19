Import-Module -Name ActiveDirectory

# the models we need to fix.
$PhoneModels = @("Cisco 7841",
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