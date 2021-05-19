Import-Module -Name ActiveDirectory

# the models we need to fix.
$PhoneModels = @("Cisco 7841",
    "Cisco 8841",
    "Cisco 8851",
    "Cisco 8861",
    "Cisco IP Communicator")

function Import-UplinxData {

    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [string] $UplinxFile
    )

    $UplinxData = Import-Csv $UplinxFile
    return $UplinxData
}

function Get-UnownedPhones {

    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [System.Object[]] $UplinxData
    )

    $UnownedPhones = $UplinxData | Where-Object {$PhoneModels.Contains($_.model) -and $_.'Owner User ID' -eq ''}
    return $UnownedPhones
}

function Get-DnToAdUserMap {
    $UsersWithPhone = Get-ADUser -Filter * -Properties ipphone | Where-Object {$null -ne $_.ipphone}
    $DnToUserMap = @{}
    $UsersWithPhone | ForEach-Object{$DnToUserMap.Add($_.ipphone, $_.samaccountname)}
    return $DnToUserMap
}

function Get-PhonesToBeFixed {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [hashtable] $DnToUserMap,
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
        [System.Object[]] $UnownedPhones
    )

    # want: list of phones and users to fix
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
