param([String] $userName, [String] $serviceName, [Boolean] $deleteOldInstallers=$True)
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

function getPlexLocalAppDataPath
{
	#Get user name from Plex process of service if not specified
	if ([System.String]::IsNullOrEmpty($userName)) { $userName=getPlexUserAccount }
	#Get user id from user name
	$sid=([System.Security.Principal.NTAccount]$userName).Translate([System.Security.Principal.SecurityIdentifier]).Value
	#Get Plex local app data path if specified in Plex configuration
	$d=New-PSDrive HKU Registry HKEY_USERS
	$path=Get-ItemProperty ("HKU:\"+$sid+"\Software\Plex, Inc.\Plex Media Server") -Name "LocalAppDataPath" -ErrorAction SilentlyContinue
	if ($path -match "LocalAppDataPath" ) { return $path.LocalAppDataPath }
	#Get Plex default path for local app data path
	$path=Get-ItemProperty ("HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\"+$sid) -Name "ProfileImagePath" -ErrorAction SilentlyContinue
	return ($path.ProfileImagePath)+"\AppData\Local\Plex Media Server"
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

	#Get all folders with their version in the "updates" folder
	$installer_dirs=Get-ChildItem -D ((getPlexLocalAppDataPath)+"\Updates")
	
	#Get installer versions to compare to plex installed version
	$installer_list=$installer_dirs | Select-Object -P FullName,@{Name="Version"; Expression={[System.Version][regex]::match($_.Name,"\d+\.\d+\.\d+\.\d+").Value}} | Sort-Object -P Version

	#Get the installer with the highest version
	$installer_path=$installer_list | Select-Object -L 1

	#Check if the installer has an higher version of the executable
	if ($installer_path.Version -le $plex_version)
	{
		Write-Host (Get-Date) "No new version available to install"
		
		#Removing old installers
		if ($installer_dirs -ne $Null) 
		{
			if ($deleteOldInstallers)
			{
				Write-Host (Get-Date) "Removing old installers"
				$installer_dirs | Remove-Item -R -Force
			}
		}
	}
	else
	{
		#Get installer in "packages" folder
		$installer=Get-ChildItem (($installer_path.FullName)+"\Packages") -Filter "*.exe" | Select-Object -F 1
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
	}
}
catch { Write-Host (get-date) "Error:" $_.Exception.Message }
