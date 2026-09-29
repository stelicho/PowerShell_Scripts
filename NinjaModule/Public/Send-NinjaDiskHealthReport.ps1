function Send-NinjaDiskHealthReport {
    <#
    .SYNOPSIS
        Runs Get-NinjaDiskHealth and writes a summary into NinjaOne custom fields.

    .DESCRIPTION
        Requires the following device custom fields to already exist in NinjaOne:
          - diskLowSpaceFlag    (Checkbox/Boolean)
          - diskUnhealthyFlag   (Checkbox/Boolean)
          - diskHealthDetails   (WYSIWYG / multi-line Text)
          - diskHealthLastScan  (Date/Time or Text)

        Only works when run through the NinjaOne agent, which injects the
        Ninja-Property-Set cmdlet into the script session. Running it
        standalone prints the values instead, so the logic can be validated
        without a live agent.

    .PARAMETER FreeSpaceWarningPct
        Passed through to Get-NinjaDiskHealth.

    .PARAMETER LowSpaceField
    .PARAMETER UnhealthyField
    .PARAMETER DetailsField
    .PARAMETER LastScanField
        Override the NinjaOne custom field names to write to.
    #>
    [CmdletBinding()]
    param(
        [int]$FreeSpaceWarningPct = 10,
        [string]$LowSpaceField = 'diskLowSpaceFlag',
        [string]$UnhealthyField = 'diskUnhealthyFlag',
        [string]$DetailsField = 'diskHealthDetails',
        [string]$LastScanField = 'diskHealthLastScan'
    )

    $health = Get-NinjaDiskHealth -FreeSpaceWarningPct $FreeSpaceWarningPct
    $scanTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    $volumeRows = $health.Volumes | ForEach-Object {
        "<tr><td>$($_.Drive)</td><td>$($_.FreeGB) / $($_.SizeGB) GB</td><td>$($_.FreePct)%</td></tr>"
    }
    $diskRows = $health.PhysicalDisks | ForEach-Object {
        "<tr><td>$($_.FriendlyName)</td><td>$($_.MediaType)</td><td>$($_.HealthStatus)</td></tr>"
    }
    $detailsHtml = "<p><b>Volumes</b></p><table><tr><th>Drive</th><th>Free/Total</th><th>Free %</th></tr>$($volumeRows -join '')</table>" +
                   "<p><b>Physical Disks</b></p><table><tr><th>Disk</th><th>Media</th><th>Health</th></tr>$($diskRows -join '')</table>"

    $fieldValues = [ordered]@{
        $LowSpaceField  = $health.AnyLowSpace
        $UnhealthyField = $health.AnyUnhealthy
        $DetailsField   = $detailsHtml
        $LastScanField  = $scanTime
    }

    $hasNinjaCli = [bool](Get-Command -Name 'Ninja-Property-Set' -ErrorAction SilentlyContinue)

    foreach ($field in $fieldValues.GetEnumerator()) {
        if ($hasNinjaCli) {
            Ninja-Property-Set -Name $field.Key -Value $field.Value
        }
        else {
            Write-Warning "Ninja-Property-Set not available (not running under the NinjaOne agent) - would have set '$($field.Key)' to: $($field.Value)"
        }
    }

    $health
}
