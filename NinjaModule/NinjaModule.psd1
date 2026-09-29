@{
    RootModule        = 'NinjaModule.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b3f1c6b0-8b8b-4a8b-9a2a-2f6a4e2a0d11'
    Author            = 'kcampbell7374'
    Description       = 'Scans user home directories for .pst/.ost files and reports the results to NinjaOne custom fields.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-PstOstFile', 'Send-PstOstReportToNinjaOne')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
