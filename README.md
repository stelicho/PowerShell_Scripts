# PowerShell Scripts

A personal collection of PowerShell scripts and modules I've written for real-world sysadmin and IT automation work. This repo doubles as a portfolio piece — a living sample of my PowerShell style, module structure, and documentation habits, intended to accompany my resume.

## Contents

### NinjaModule
A PowerShell module built for use with the [NinjaOne](https://www.ninjaone.com/) RMM agent.

- `Get-PstOstFile` — scans user profiles for Outlook `.pst`/`.ost` data files and reports size, location, and last-modified date.
- `Send-PstOstReportToNinjaOne` — runs the scan above and pushes a summary (count, total size, largest file, full details) into NinjaOne custom fields via `Ninja-Property-Set`.
- `Get-NinjaDiskHealth` — reports free space per volume and physical disk (SMART/reliability) health.
- `Send-NinjaDiskHealthReport` — runs the disk health check and pushes a summary into NinjaOne custom fields.
- `Get-NinjaPendingRebootStatus` — checks Component Based Servicing, Windows Update, and pending file-rename indicators for a pending reboot.
- `Send-NinjaPendingRebootReport` — runs the pending-reboot check and pushes the result into a NinjaOne custom field.
- `Get-NinjaUserProfile` (private) — shared helper that enumerates real, loadable user profiles under `C:\Users`.

All `Send-*` functions fall back to printing values when run outside the NinjaOne agent, so the logic can be tested standalone.

### Active Directory
- `New-DomainController.ps1` — installs the AD DS/DNS roles and promotes a clean Windows Server to the first Domain Controller of a brand-new Active Directory forest (`Install-ADDSForest`).
- `Install-ADDSDomainController.ps1` — adds an additional/replica Domain Controller to an existing domain (`Install-ADDSDomainController`), with site assignment.
- `New-ADBulkUser.ps1` — bulk-creates AD user accounts from a CSV of new hires, including group memberships and a forced password change at next logon.
- `New-DnsRecord.ps1` — creates A (with optional matching PTR), CNAME, or standalone PTR records in an AD-integrated DNS zone.
- `New-DfsReplicationTarget.ps1` — creates a new DFS Replication group and folder between two servers, or adds a new replication target/member to an existing group.
- `New-EncryptedFileShare.ps1` — provisions a new SMB file share with SMB 3.0 encryption-in-transit enforced, backed by a dedicated AD security group and locked-down NTFS permissions.

### Network Automation
- `Backup-NetworkDeviceConfig.ps1` — SSHes into a list of network devices (Cisco IOS-XE, NX-OS, ASA) via Posh-SSH and saves a timestamped running-config backup per device. Vendor-agnostic pattern in the spirit of Netmiko/[Swiftmiko](https://github.com/stelicho/Swiftmiko).
- `Test-DeviceReachability.ps1` — sweeps a device list for ICMP and TCP management-port reachability with response-time reporting, NOC-monitoring style.
- `Get-SwitchPortInventory.ps1` — SSHes into a Cisco switch and builds a port-by-port inventory (status, VLAN, speed/duplex, connected MACs) by parsing `show interface status` / `show mac address-table`.

### Security and Compliance
- `Test-CisBenchmark.ps1` — checks a Windows host against a sample of CIS Benchmark controls (SMBv1, Guest account, firewall profiles, RDP NLA, minimum password length), reports pass/fail, and can auto-remediate failures with `-Remediate`.
- `Get-LocalAdminInventory.ps1` — audits local Administrators group membership across a list of computers and flags accounts not on an approved allow-list, supporting privileged-access/PAW hardening work.
- `New-SecureDataWipe.ps1` — performs a NIST SP 800-88 "Clear"-aligned free-space sanitization (`cipher /w`) on a target volume and generates a wipe certificate for ITAD/asset-tracking records.

### Identity and M365
- `New-EmployeeOnboarding.ps1` — creates the on-prem AD account and group memberships for a new hire in a hybrid AD environment, then assigns an M365 license via Microsoft Graph once Entra Connect has synced the account.
- `Disable-EmployeeOffboarding.ps1` — disables the AD account, strips group memberships, moves it to a disabled-users OU, and (with `-RevokeM365`) revokes Entra ID sessions and removes M365 licenses via Microsoft Graph.
- `Get-InactiveUserReport.ps1` — flags enabled AD accounts with no logon within a configurable window, for offboarding/governance review.
- `Register-AutopilotDevice.ps1` — collects a device's hardware hash and registers it with Windows Autopilot via Microsoft Graph, with optional group tag and user assignment.

### Virtualization
- `Get-VMHealthReport.ps1` — VMware PowerCLI report covering cluster HA/DRS status, host status, datastore capacity, and VM inventory with stale-snapshot detection.
- `New-HyperVLabVM.ps1` — provisions a new Hyper-V lab VM, including a differencing or blank dynamic VHDX, CPU/memory sizing, and virtual switch attachment.
- `Remove-StaleSnapshot.ps1` — finds Hyper-V checkpoints older than a configurable age and optionally removes them.

### Windows PC Administration
- `Get-WorkstationHealthReport.ps1` — local or remote helpdesk triage report: disk space, pending reboot state, uptime, antivirus status, and pending Windows Updates.
- `Install-StandardSoftwareBundle.ps1` — silently installs a standard software bundle via `winget` for new/rebuilt workstations.
- `Repair-WindowsUpdateComponents.ps1` — classic fix-it script that resets stuck Windows Update services, cache folders, and BITS/WU DLL registrations.
- `Set-HostnameAndJoinDomain.ps1` — renames a workstation and joins it to an Active Directory domain in one step, with optional target OU placement.
- `Enable-BitLockerEncryption.ps1` — enables BitLocker on a volume with TPM + recovery password protectors, with optional recovery key escrow to AD.

### Backup and DR
- `Get-VeeamJobStatusReport.ps1` — pulls Veeam Backup & Replication job sessions from the last N hours and flags any that didn't complete successfully.
- `Update-TapeRotationLog.ps1` — tracks a daily LTO tape rotation schedule, logs which tape is due, and warns when a tape is overdue for off-site rotation.

### Windows Server Administration
- `New-DhcpScope.ps1` — creates and activates a new DHCP scope with gateway/DNS options and an optional exclusion range.
- `Backup-GPOReport.ps1` — backs up every GPO in the domain and generates an HTML settings report for each, for change tracking and DR.
- `New-IisWebsite.ps1` — provisions a new IIS site and application pool with an HTTP binding, and optionally imports a PFX certificate for HTTPS.

### Printer Fleet Monitoring
- `Get-PrinterFleetInventory.ps1` — SNMP-based inventory of network printers/MFCs (description, serial number, lifetime page count).
- `Get-PrinterTonerStatus.ps1` — SNMP polling of printer consumable levels, flagging toner/drums under a configurable warning threshold.

### SQL Server Administration
- `Backup-SqlDatabase.ps1` — runs full or differential backups of one or more SQL Server databases with compression, and prunes backups past a retention window.
- `Test-SqlDatabaseIntegrity.ps1` — runs `DBCC CHECKDB` across one or more databases and reports any integrity errors found.

### Exchange Online
- `New-SharedMailbox.ps1` — creates a new Exchange Online shared mailbox and grants Full Access + Send As permissions to a list of delegates.
- `Get-MailboxSizeReport.ps1` — reports mailbox size/item count for all mailboxes and flags anything approaching its storage quota.

### Firewall Automation
- `Backup-FortiGateConfig.ps1` — downloads a full configuration backup from a FortiGate via its REST API.
- `Get-FortiGateFirewallPolicyReport.ps1` — pulls the firewall policy table from a FortiGate via REST API into a readable/exportable report.

### SIEM and EDR
- `Search-ElasticSecurityAlerts.ps1` — queries the Elastic Security (Kibana) detection engine alerts API for recent alerts and summarizes by severity.
- `Get-HuntressAgentStatus.ps1` — pulls agent status from the Huntress managed EDR API and flags endpoints that haven't checked in recently.

## About

I maintain this repo to keep useful scripts organized and to demonstrate practical PowerShell experience: module design (public/private function separation, manifests), comment-based help, parameter validation, and integration with tools like NinjaOne, Active Directory, Microsoft Graph, VMware PowerCLI, and Hyper-V. Feedback and questions are welcome.
