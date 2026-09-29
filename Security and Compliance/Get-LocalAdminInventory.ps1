<#
.SYNOPSIS
    Enumerates local Administrators group membership across a list of
    computers and flags accounts that aren't on an approved allow-list.

.DESCRIPTION
    Rough-draft privileged-access audit tool. Supports the PAW/jump-box and
    identity-hardening work referenced on my resume: run this periodically to
    catch local admin rights that have crept onto endpoints outside of the
    expected domain admin groups/service accounts.

.PARAMETER ComputerName
    One or more computers to audit.

.PARAMETER AllowList
    Names (local account name, or "DOMAIN\Name" for domain principals) that
    are expected/approved members of the local Administrators group and
    should not be flagged.

.PARAMETER Credential
    Credential to use for remote queries.

.EXAMPLE
    .\Get-LocalAdminInventory.ps1 -ComputerName PC-JDOE, PC-ASMITH -AllowList "Administrator", "CORP\Domain Admins", "CORP\svc-rmm"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$ComputerName,

    [string[]]$AllowList = @('Administrator', 'Domain Admins'),

    [System.Management.Automation.PSCredential]$Credential
)

$scriptBlock = {
    Get-LocalGroupMember -Group 'Administrators' | Select-Object @{N = 'ComputerName'; E = { $env:COMPUTERNAME } }, Name, ObjectClass
}

$rawResults = foreach ($computer in $ComputerName) {
    if ($computer -eq $env:COMPUTERNAME) {
        & $scriptBlock
    }
    else {
        $params = @{ ComputerName = $computer; ScriptBlock = $scriptBlock }
        if ($Credential) { $params.Credential = $Credential }
        Invoke-Command @params
    }
}

$report = foreach ($member in $rawResults) {
    $isAllowed = $false
    foreach ($allowed in $AllowList) {
        if ($member.Name -eq $allowed -or $member.Name -like "*\$allowed") {
            $isAllowed = $true
            break
        }
    }

    [PSCustomObject]@{
        ComputerName = $member.ComputerName
        Member       = $member.Name
        ObjectClass  = $member.ObjectClass
        Flagged      = -not $isAllowed
    }
}

$report | Format-Table -AutoSize

$flagged = $report | Where-Object Flagged
if ($flagged) {
    Write-Warning "$($flagged.Count) unexpected local admin membership(s) found."
}
