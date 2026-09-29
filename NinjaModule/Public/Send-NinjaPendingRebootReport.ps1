function Send-NinjaPendingRebootReport {
    <#
    .SYNOPSIS
        Runs Get-NinjaPendingRebootStatus and writes the result into a NinjaOne custom field.

    .DESCRIPTION
        Requires the following device custom field to already exist in NinjaOne:
          - pendingRebootFlag   (Checkbox/Boolean)

        Only works when run through the NinjaOne agent, which injects the
        Ninja-Property-Set cmdlet into the script session. Running it
        standalone prints the value instead, so the logic can be validated
        without a live agent.

    .PARAMETER FieldName
        Override the NinjaOne custom field name to write to.
    #>
    [CmdletBinding()]
    param(
        [string]$FieldName = 'pendingRebootFlag'
    )

    $status = Get-NinjaPendingRebootStatus
    $hasNinjaCli = [bool](Get-Command -Name 'Ninja-Property-Set' -ErrorAction SilentlyContinue)

    if ($hasNinjaCli) {
        Ninja-Property-Set -Name $FieldName -Value $status.RebootPending
    }
    else {
        Write-Warning "Ninja-Property-Set not available (not running under the NinjaOne agent) - would have set '$FieldName' to: $($status.RebootPending)"
    }

    $status
}
