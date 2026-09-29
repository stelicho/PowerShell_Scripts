<#
.SYNOPSIS
    Spins up a quick Hyper-V lab VM: creates a differencing/dynamic VHDX,
    attaches it, sets memory/CPU, and connects it to a specified virtual switch.

.DESCRIPTION
    Rough-draft lab provisioning script for Hyper-V, useful for quickly
    standing up test VMs (domain controllers, member servers, network
    simulation endpoints) without going through Hyper-V Manager by hand.

.PARAMETER Name
    Name of the new VM.

.PARAMETER VhdParentPath
    Optional path to a parent VHDX to create a differencing disk from (fast
    lab provisioning from a sysprepped golden image). If omitted, a blank
    dynamic VHDX is created instead.

.PARAMETER VhdSizeGB
    Size of the new blank VHDX in GB, used only when VhdParentPath is not supplied. Default: 60.

.PARAMETER MemoryGB
    Startup/dynamic memory in GB. Default: 4.

.PARAMETER CpuCount
    Number of virtual processors. Default: 2.

.PARAMETER SwitchName
    Name of the Hyper-V virtual switch to connect the VM's network adapter to.

.PARAMETER VmPath
    Root path to store the new VM and its disk. Default: the host's configured Hyper-V VM path.

.EXAMPLE
    .\New-HyperVLabVM.ps1 -Name "LAB-DC01" -VhdParentPath "D:\Golden\Server2022-Golden.vhdx" -SwitchName "Lab-Internal"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [string]$VhdParentPath,
    [int]$VhdSizeGB = 60,
    [int]$MemoryGB = 4,
    [int]$CpuCount = 2,

    [Parameter(Mandatory)]
    [string]$SwitchName,

    [string]$VmPath = (Get-VMHost).VirtualMachinePath
)

$ErrorActionPreference = 'Stop'

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    throw "Virtual switch '$SwitchName' was not found. Available switches: $((Get-VMSwitch).Name -join ', ')"
}

$vhdFolder = Join-Path $VmPath "$Name\Virtual Hard Disks"
$vhdPath   = Join-Path $vhdFolder "$Name.vhdx"

if ($PSCmdlet.ShouldProcess($Name, "Create Hyper-V VM")) {
    New-Item -Path $vhdFolder -ItemType Directory -Force | Out-Null

    if ($VhdParentPath) {
        New-VHD -Path $vhdPath -ParentPath $VhdParentPath -Differencing | Out-Null
        Write-Host "Created differencing disk from $VhdParentPath." -ForegroundColor Green
    }
    else {
        New-VHD -Path $vhdPath -SizeBytes ($VhdSizeGB * 1GB) -Dynamic | Out-Null
        Write-Host "Created blank $VhdSizeGB GB dynamic VHDX." -ForegroundColor Green
    }

    New-VM -Name $Name -MemoryStartupBytes ($MemoryGB * 1GB) -VHDPath $vhdPath -SwitchName $SwitchName -Generation 2 -Path $VmPath | Out-Null
    Set-VMProcessor -VMName $Name -Count $CpuCount
    Set-VMMemory -VMName $Name -DynamicMemoryEnabled $true -MinimumBytes 512MB -MaximumBytes ($MemoryGB * 1GB)
    Set-VMFirmware -VMName $Name -EnableSecureBoot Off

    Write-Host "Created VM '$Name' ($CpuCount vCPU, $MemoryGB GB dynamic memory) on switch '$SwitchName'." -ForegroundColor Green
    Write-Host "Start it with: Start-VM -Name '$Name'" -ForegroundColor Cyan
}
