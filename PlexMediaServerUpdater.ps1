<#
.SYNOPSIS
Powershell script to update PLEX automatically

.DESCRIPTION
This powershell script scans the PLEX folder for new downloaded versions and installs them automatically.
This script normally doesn't require any parameter, because if PLEX is running, it can determine all that it needs to find the PLEX folder with the new installers and install them.

.PARAMETER userName
The name of the user account under which PLEX runs, it is important because the new downloaded installers are in app data folder of the user.
If omitted and PLEX is running, the script can determine it automatically.

.PARAMETER serviceName
The name of the windows service under which PLEX runs, it is important if PLEX run as a service, because before the installation the service has to be stopped and after restarted.
If omitted and PLEX is running, the script can determine it automatically.

.PARAMETER keepInstallerFile
Normally the script deletes the installer file after the installation to free space on the hard disk.
To not delete it and keep it uses this parameter.

.EXAMPLE
./PlexMediaServerUpdater.ps1
It scans the folder of the local instance of PLEX for a newer installer and install it

.EXAMPLE
./PlexMediaServerUpdater.ps1 -keepOldInstallers
It scans the folder of the local instance of PLEX for a newer installer and install it, but it won't delete the old installer files

.LINK
https://github.com/aquilax1/Plex-Media-Server-Updater
#>
param([String] $userName, [String] $serviceName, [Switch] $keepOldInstallers)

function getPlexService
{
	#Get service from service name
	if (![System.String]::IsNullOrEmpty($serviceName)) { return get-service $serviceName }
	#Get service from Plex process, if it is running
	$ser=$Null
	$pro=$process
	while ($ser -eq $Null -and $pro -ne $Null)
	{
		$ser=gwmi Win32_Service -Filter ("ProcessId="+$pro.ProcessId)
		$pro=gwmi Win32_Process -Filter ("ProcessId="+$pro.ParentProcessId)
	}
	if ($ser -ne $Null) { return get-service $ser.Name}
}

function getPlexExecutablePath
{
	#Get Plex install path from registry
	$path = Get-ItemProperty "HKCU:\Software\Plex, Inc.\Plex Media Server" -Name "InstallFolder" -ErrorAction SilentlyContinue
	if ($path -match "InstallFolder" ) { return $path.InstallFolder+"\Plex Media Server.exe" }
	#Get Plex install path from Plex process, if Plex is running
	if ($process -ne $Null) { return $process.ExecutablePath }
	#Get Plex default install path
	$programs=$env:ProgramFiles
	if (Test-Path ($programs+" (x86)")) {$programs=$programs+" (x86)"}
	$plex_path=$programs+"\Plex\Plex Media Server\Plex Media Server.exe"
	if (Test-Path $plex_path) { return $plex_path }
	#Nothing found, throw exception
	throw [System.Exception] "Can't find Plex installation path"
}

function getPlexUserAccount
{
	#Get user name from Plex process, if Plex is running
	if ($process -ne $Null) { return $process.GetOwner().User }
	#Get user name from service, if there is one
	if ($service -ne $Null) { return $service.StartName }
	#Nothing found, throw exception
	throw [System.Exception] "Can't determine user account if plex is not running and no service name is specified"
}

function installPlex
{
	try
	{
		Write-Host (get-date) "Starting Plex installer"
		Start-Process $installer.FullName -ArgumentList "/install /quiet /norestart" -Wait
		Write-Host (get-date) "Installation completed"
	}
	catch { Write-Host (get-date) "Error:" $_.Exception.Message }
}

try
{
	$web=New-Object System.Net.WebClient

	#Get Plex process, if it is running
	$process=gwmi Win32_Process -Filter "Name='Plex Media Server.exe'"
	#Write-Host (Get-Date) "Plex is running?" ($process -ne $Null)

	#Get Plex service, if there is one
	$service=getPlexService
	#Write-Host (Get-Date) "Plex is running as a service?" ($service -ne $Null)

	#Check for same user in case of plex running as a desktop application
	if ($service -eq $Null -and $process -ne $Null -and $process.GetOwner.User -ne $Env:UserName) { throw [System.Exception] "For Plex running as a desktop application this updater script must be executed under the same user account of Plex"}

	#Get Plex version from executable
	$plex_version=[System.Version] [System.Diagnostics.FileVersionInfo]::GetVersionInfo((getPlexExecutablePath)).FileVersion
	#Write-Host (Get-Date) "Plex current installed version is" $plex_version
	
	#Get current release from Plex API
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$current_release=(ConvertFrom-Json $web.DownloadString("https://plex.tv/pms/downloads/5.json")).computer.Windows
	$current_version=[System.Version][regex]::match($current_release.version,"\d+\.\d+\.\d+\.\d+").Value
	
	if ($current_version -le $plex_version)
	{
		Write-Host (Get-Date) "No new version available"
	}
	else
	{
		Write-Host (Get-Date) "Downloading new version" $current_version
		$url=$current_release.releases[0].url
		#write-host (get-date) $url
		$path=$Env:temp+$url.substring($url.LastIndexOf("/"))
		#write-host (get-date) $path
		$web.DownloadFile($url,$path)
	
		$installer=Get-ChildItem $path
		if ($installer -ne $Null)
		{
			Write-Host (Get-Date) "Installing Plex version" ($installer_path.Version)
			
			if ($service -ne $Null)
			{
				#Installing Plex when running as a service
				if ($service.Status -eq "Running")
				{
					Write-Host (get-date) "Stopping Plex service" 
					$service.Stop()
					$service.WaitForStatus("Stopped",[TimeSpan]::FromSeconds(10))
					if ($service.Status -ne "Stopped") { throw [System.Exception] "Can't stop Plex service" }
				}
				
				installPlex
				
				Write-Host (get-date) "Removing Plex from startup programs" 
				Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "Plex Media Server"  -ErrorAction SilentlyContinue
				
				Write-Host (get-date) "Starting Plex service"
				$service.Start()
				$service.WaitForStatus("Running",[TimeSpan]::FromSeconds(10))
				if ($service.Status -ne "Running") { throw [System.Exception] "Can't start Plex service" }
			}
			else
			{
				#Installing Plex when running as a desktop application
				if ($process -ne $Null)
				{
					Write-Host (get-date) "Stopping Plex"
					$process=Get-Process "Plex Media Server"
					$process.CloseMainWindow()
					$process.WaitForExit(10000)
					if (!$process.HasExited)  { $process.Kill() }
					$process.WaitForExit(5000)
					if (!$process.HasExited) { throw [System.Exception] "Can't stop Plex" }
				}
				
				installPlex
				
				Write-Host (get-date) "Starting Plex"
				Start-Process getPlexExecutablePath
				Start-Sleep -s 5
				if ((Get-Process "Plex Media Server") -eq $Null) { throw [System.Exception] "Can't start Plex" }
			}
		}
		if (-not $keepInstallerFile)
		{
			Write-Host (Get-Date) "Removing installer"
			Remove-Item $installer -Force
		}
	}
}
catch { Write-Host (get-date) "Error:" $_.Exception.Message }
