function Send-PstOstReportToNinjaOne {
    <#
    .SYNOPSIS
        Scans user profiles for .pst/.ost files and writes a summary into
        NinjaOne custom fields via the Ninja-Property-Set cmdlet.

    .DESCRIPTION
        Requires the following device custom fields to already exist in
        NinjaOne (names are configurable via parameters below):
          - pstOstFileCount     (Integer)
          - pstOstTotalSizeMb   (Decimal)
          - pstOstLargestFile   (Text)
          - pstOstDetails       (WYSIWYG / multi-line Text)
          - pstOstLastScan      (Date/Time or Text)

        Only works when run through the NinjaOne agent, which injects the
        Ninja-Property-Set cmdlet into the script session. Running it
        standalone (e.g. while developing) prints the values instead of
        throwing, so you can validate the scan logic without a live agent.

    .PARAMETER UserName
        Passed through to Get-PstOstFile to restrict which profiles are scanned.

    .PARAMETER Full
        Passed through to Get-PstOstFile to do a full profile recurse instead
        of the default well-known Outlook data locations.

    .PARAMETER CountField
    .PARAMETER TotalSizeField
    .PARAMETER LargestFileField
    .PARAMETER DetailsField
    .PARAMETER LastScanField
        Override the NinjaOne custom field names to write to.
    #>
    [CmdletBinding()]
    param(
        [string[]]$UserName,
        [switch]$Full,
        [string]$CountField = 'pstOstFileCount',
        [string]$TotalSizeField = 'pstOstTotalSizeMb',
        [string]$LargestFileField = 'pstOstLargestFile',
        [string]$DetailsField = 'pstOstDetails',
        [string]$LastScanField = 'pstOstLastScan'
    )

    $files = @(Get-PstOstFile -UserName $UserName -Full:$Full)

    $count = $files.Count
    $totalSizeMb = [math]::Round((($files | Measure-Object -Property SizeMB -Sum).Sum), 2)
    $largest = $files | Sort-Object SizeMB -Descending | Select-Object -First 1
    $largestSummary = if ($largest) { "$($largest.FullName) ($($largest.SizeMB) MB)" } else { 'None found' }
    $scanTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    $detailsHtml = if ($files) {
        $rows = $files | Sort-Object SizeMB -Descending | ForEach-Object {
            "<tr><td>$($_.User)</td><td>$($_.FullName)</td><td>$($_.SizeMB) MB</td><td>$($_.LastWriteTime)</td></tr>"
        }
        "<table><tr><th>User</th><th>Path</th><th>Size</th><th>Last Modified</th></tr>$($rows -join '')</table>"
    }
    else {
        '<p>No .pst/.ost files found.</p>'
    }

    $fieldValues = [ordered]@{
        $CountField       = $count
        $TotalSizeField   = $totalSizeMb
        $LargestFileField = $largestSummary
        $DetailsField     = $detailsHtml
        $LastScanField    = $scanTime
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

    [PSCustomObject]@{
        FileCount   = $count
        TotalSizeMb = $totalSizeMb
        LargestFile = $largestSummary
        ScanTime    = $scanTime
        Files       = $files
    }
}
