<#
.SYNOPSIS
    Creates a new Exchange Online shared mailbox and grants Full Access +
    Send As permissions to a list of delegate users.

.DESCRIPTION
    Rough-draft mailbox provisioning script using the ExchangeOnlineManagement
    module. Shared mailboxes don't require a license, so this is a common
    request for team inboxes (e.g. helpdesk@, ap@, info@).

.PARAMETER MailboxName
    Display name for the new shared mailbox.

.PARAMETER PrimarySmtpAddress
    Primary email address for the mailbox, e.g. "helpdesk@contoso.com".

.PARAMETER FullAccessUsers
    UPNs of users to grant Full Access (with auto-mapping) to the mailbox.

.PARAMETER SendAsUsers
    UPNs of users to grant Send As rights to. Defaults to the same list as FullAccessUsers.

.EXAMPLE
    .\New-SharedMailbox.ps1 -MailboxName "Help Desk" -PrimarySmtpAddress helpdesk@contoso.com `
        -FullAccessUsers jane.doe@contoso.com,john.smith@contoso.com
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$MailboxName,

    [Parameter(Mandatory)]
    [string]$PrimarySmtpAddress,

    [Parameter(Mandatory)]
    [string[]]$FullAccessUsers,

    [string[]]$SendAsUsers = $FullAccessUsers
)

$ErrorActionPreference = 'Stop'

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

if (Get-Mailbox -Identity $PrimarySmtpAddress -ErrorAction SilentlyContinue) {
    throw "A mailbox with address '$PrimarySmtpAddress' already exists."
}

if ($PSCmdlet.ShouldProcess($MailboxName, "Create shared mailbox")) {
    New-Mailbox -Shared -Name $MailboxName -PrimarySmtpAddress $PrimarySmtpAddress | Out-Null
    Write-Host "Created shared mailbox '$MailboxName' ($PrimarySmtpAddress)." -ForegroundColor Green

    Write-Host "Waiting for the mailbox to finish provisioning before granting permissions..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15

    foreach ($user in $FullAccessUsers) {
        Add-MailboxPermission -Identity $PrimarySmtpAddress -User $user -AccessRights FullAccess -AutoMapping $true | Out-Null
        Write-Host "  Granted Full Access to $user." -ForegroundColor Green
    }

    foreach ($user in $SendAsUsers) {
        Add-RecipientPermission -Identity $PrimarySmtpAddress -Trustee $user -AccessRights SendAs -Confirm:$false | Out-Null
        Write-Host "  Granted Send As to $user." -ForegroundColor Green
    }
}

Disconnect-ExchangeOnline -Confirm:$false
