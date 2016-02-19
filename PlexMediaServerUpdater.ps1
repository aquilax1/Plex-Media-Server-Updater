#Start the update process
Write-Host (get-date) "Starting plex media server updater"
try
{
	#basic configuration
	#name of the plex media server windows service, PMService uses "PlexService", with NSSM need to know the service name
	$service_name="PlexService"
	#language of the installer, there are only two languages available: English and Korean
	$language="English"
	#temporary path to save the plex media server installer
	$temp_path=$env:temp+"\"
	#delete installer when finished, $True to delete it, $False to keep it
	$delete_installer=$True
	
	#advanced confguration, should be changed if plex changes something in the download page or installation path
	#checking for 32/64 version of windows to pick the right program files folder
	$programs=$env:ProgramFiles
	if (Test-Path ($programs+" (x86)")) {$programs=$programs+" (x86)"}
	#installation path, where plex media server is installed, it is the same for all the users becase it can't be configured
	$plex_path=$programs+"\Plex\Plex Media Server\Plex Media Server.exe"
	#download page of plex media server, it should be changed if plex changes the download page url
	#note: this is the public download page, users with plexpass have another download page
	$download_page="https://plex.tv/downloads"
	#version regex, search for the version number in the download page
	$online_version_regex="Version (\d+\.\d+\.\d+\.\d+)"
	#download link regex, search for the download link in the download page
	$download_link_regex="<a .*?href=`"(.*?)`".*?>Download "+$language+"<\/a>"
	
	#get installed version of plex media server from the executable
	If (-not (Test-Path $plex_path)) { throw [System.Exception] "Plex media server is not installed, installation path should be "+$plex_path }
	$inst_version=[System.Version] [System.Diagnostics.FileVersionInfo]::GetVersionInfo($plex_path).FileVersion
	Write-Host (get-date) "Installed version of plex media server is" $inst_version 
	
	#get plex media server download page
	Write-Host (get-date) "Checking online version of plex media server ..."
	$client=new-object System.Net.WebClient
	$page=$client.DownloadString($download_page)
	
	#get version from plex download page
	$is_match=$page -match $online_version_regex
	if (-not $is_match) { throw [System.Exception] "No version found on the download page, something is wrong, has changed ..." }
	$online_version=[System.Version] $matches[1]
	Write-Host (get-date) "Online version of plex media server is" $online_version
	
	#check if the online version is newer 
	if ($online_version -le $inst_version) { throw [System.Exception] "No new version available to download" }
	Write-Host (get-date) "A newer version of plex media server is available"
	
	#get download link
	$is_match=$page -match $download_link_regex
	if (-not $is_match) { throw [System.Exception] "No download link found on the download page, something is wrong, has changed ..." }
	$download_url=[System.Uri] $matches[1]
	
	#download plex installer in temp folder
	$installer_path=$temp_path+$download_url.Segments[$download_url.Segments.Length-1]
	if (Test-Path $installer_path) { Write-Host (get-date) "Installer already available in" $installer_path}
	else
	{
		Write-Host (get-date) "Downloading installer from" $download_url "to" $installer_path
		$client.DownloadFile($download_url,$installer_path)
		Write-Host (get-date) "Download completed"
	}
	
	#stop plex service
	$plex_service=get-service $service_name
	if ($plex_service.Status -eq "Running") 
	{ 
		Write-Host (get-date) "Stopping plex media server service" 
		$plex_service.Stop()
		$plex_service.WaitForStatus("Stopped",[TimeSpan]::FromSeconds(10))
		if ($plex_service.Status -ne "Stopped") { throw [System.Exception] "Can't stop plex media server service" }
	}
	
	#run plex installer
	Write-Host (get-date) "Installing newer version of plex media server"
	Start-Process $installer_path -ArgumentList "/install /quiet /norestart" -Wait -ErrorAction Inquire
	Write-Host (get-date) "Installation completed"
	
	#delete plex installer
	if ($delete_installer)
	{
		Write-Host (get-date) "Deleting plex media server installer"
		Remove-Item $installer_path
	}
	
	#remove plex from windows startup programs
	$GIP = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Plex Media Server" -ErrorAction SilentlyContinue
	If ($GIP -match "Plex Media Server")
	{
		Write-Host (get-date) "Removing plex media server from startup programs" 
		Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "Plex Media Server" 
	}
	
	#start plex service
	Write-Host (get-date) "Starting plex media server service"
	$plex_service.Start()
	$plex_service.WaitForStatus("Running",[TimeSpan]::FromSeconds(10))
	if ($plex_service.Status -ne "Running") { throw [System.Exception] "Can't start plex media server service" }
}
catch { Write-Host (get-date) "Error:" $_.Exception.Message }
Write-Host (get-date) "Plex media server updater ended"