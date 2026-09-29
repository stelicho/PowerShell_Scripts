function Get-NinjaUserProfile {
    <#
        Returns real, loadable user profile directories under C:\Users,
        excluding system/service placeholders (Public, Default, defaultuser0, etc).
    #>
    [CmdletBinding()]
    param()

    $excluded = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0')

    Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue | Where-Object {
        $excluded -notcontains $_.Name -and (Test-Path (Join-Path $_.FullName 'NTUSER.DAT'))
    }
}
