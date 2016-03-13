# Plex-Media-Server-Updater

##Introduction
Powershell script to update Plex media server when configured to run as a service

This script has been inspired from the [PMS as a service updater](https://forums.plex.tv/discussion/136596/utility-pms-as-a-service-updater) script.  

[Plex](https://plex.tv/) is a great media server but on Windows it can't run as a service natively, to run it as a service requires a service wrapper like:
* [PMService](https://github.com/cjmurph/PmsService)
* [NSSM](https://nssm.cc/)
* [SrvAny](https://www.microsoft.com/en-us/download/details.aspx?id=17657)
* [AlwaysUp](http://www.coretechnologies.com/products/AlwaysUp/)

Running Plex media server as a service has different advantages:
* Doesn't require a logged in user, thus less CPU and RAM, thus less electricity consume and fan noisy
* It starts automatically when Windows starts, this means that Windows can install updates automatically and reboot, and is not a problem
* Automatically restart it if it crashes
* Running it under a less privileged account, like local service  

The only disadvantage of a service is that it is a little bit more complicated to update, because before installing the new version, the service has to be stopped, this means that the automatic update mechanism of Plex media server doesn't work.  
The objective of this script is to have an automatic update mechanism for Plex media server also when it run as service.

##Plex as a service with NSSM
To run Plex media server as service with NSSM execute in a command shell use the following instruction:

```nssm.exe install PlexService "C:\Program Files (x86)\Plex\Plex Media Server\Plex Media Server.exe" "-noninteractive"```

To change the service account from local system to local service execute the following instruction:

```nssm.exe set PlexService ObjectName "Local Service"```

To start and stop the service use either the [service management console](http://www.windows-commandline.com/run-command-for-services-management/) or the following instructions in a command shell:

```
//To start a service use one of them:
nssm.exe start PlexService
sc.exe start PlexService
net start PlexService

//To stop a service use one of them:
nssm.exe stop PlexService
sc.exe stop PlexService
net stop PlexService
```

##How this script works
This script searches for the running process of Plex and determines if it is running as a service or as a desktop application, then it determines the application data folder, which is the folder where Plex download the installers of the new versions, and it checks if an installer of a newer version is available, in which case it installs it. If Plex is running as a service, it  stops the service, installs the newer version and restarts the service. If Plex is running as a desktop application, it kills the process, installs the newer version and relaunches the application.

##Parameters
The script should work complete automatically, without the need of any parameter, although it is possible to pass as parameters the user name, the service name, and whether you want it to delete the old installer from the hard disk or not.

##Installation
This script hasn't an installer, just save the script somewhere in the hard disk and execute it:  

```powershell -file PlexMediaServerUpdater.ps1```  

But it is much easier to set up a Windows scheduler task to execute the script periodically, so that the update process is completely automated and doesn't require any more a manual intervention.
For this reason there is also a XML file, which is a Windows scheduler task, to easily set up the automatic update process. The only change that has to be made to the Windows scheduler task is the working directory, which is where the script has been saved.
If you save the script in the Plex media server folder (C:\Program Files (x86)\Plex), where I have saved it, you don't have to modify the working directory of the Windows scheduler task.
The task is configured to output the script execution in a log file, it is a simple output to a log file, thus the log file will grow indefinitely. This could be a problem but only after many years, because in the case that there isn't a newer version, the output in the log file is just one line, namely "No new version available to install".
