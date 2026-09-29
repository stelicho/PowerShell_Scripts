function Get-PstOstFile {
    <#
    .SYNOPSIS
        Finds .pst/.ost files in user home directories.

    .PARAMETER UserName
        Restrict the scan to specific Windows account names. Default: all real profiles.

    .PARAMETER Extension
        File extensions to look for. Default: pst, ost.

    .PARAMETER Full
        By default only the well-known Outlook data locations are scanned
        (Documents\Outlook Files and AppData\Local\Microsoft\Outlook). Pass
        -Full to recurse the entire user profile instead, which is slower
        but catches files stored in nonstandard locations.

    .EXAMPLE
        Get-PstOstFile

    .EXAMPLE
        Get-PstOstFile -UserName jsmith -Full
    #>
    [CmdletBinding()]
    param(
        [string[]]$UserName,
        [ValidateSet('pst', 'ost')]
        [string[]]$Extension = @('pst', 'ost'),
        [switch]$Full
    )

    $profiles = Get-NinjaUserProfile
    if ($UserName) {
        $profiles = $profiles | Where-Object { $UserName -contains $_.Name }
    }

    foreach ($profile in $profiles) {
        if ($Full) {
            $searchPaths = @($profile.FullName)
        }
        else {
            $searchPaths = @(
                (Join-Path $profile.FullName 'Documents\Outlook Files'),
                (Join-Path $profile.FullName 'AppData\Local\Microsoft\Outlook')
            ) | Where-Object { Test-Path $_ }
        }

        foreach ($path in $searchPaths) {
            foreach ($ext in $Extension) {
                Get-ChildItem -Path $path -Filter "*.$ext" -File -Recurse -Force -ErrorAction SilentlyContinue |
                    Select-Object `
                        @{ Name = 'User'; Expression = { $profile.Name } },
                        @{ Name = 'FileName'; Expression = { $_.Name } },
                        FullName,
                        @{ Name = 'SizeMB'; Expression = { [math]::Round($_.Length / 1MB, 2) } },
                        LastWriteTime
            }
        }
    }
}
