@{
    RootModule        = 'NinjaModule.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = 'b3f1c6b0-8b8b-4a8b-9a2a-2f6a4e2a0d11'
    Author            = 'kcampbell7374'
    Description       = 'Endpoint health and reporting helpers for the NinjaOne RMM agent: PST/OST scanning, disk health, and pending-reboot detection, each pushed to NinjaOne custom fields.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-PstOstFile',
        'Send-PstOstReportToNinjaOne',
        'Get-NinjaDiskHealth',
        'Send-NinjaDiskHealthReport',
        'Get-NinjaPendingRebootStatus',
        'Send-NinjaPendingRebootReport'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
