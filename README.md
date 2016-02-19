# Plex-Media-Server-Updater
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

This script checks for the installed version of Plex media server and compares it to the version on the download page, if a newer version is available, it downloads it and installs it automatically, taking care to stop the service before and to restart it after.  
The script has few configuration parameters, the most important one is the name of the service running Plex media server, the other parameters are really optional, like if you prefer to download the Korean version, or to change the temporary folder of the installer or if you want to keep the installer after the installation is completed.
The script can be executed in a command shell with the following instruction:  

```powershell -file PlexMediaServerUpdater.ps1```  

But it is much easier to set up a Windows scheduler task to execute the script periodically, so that the update process is completely automated and doesn't require any more a manual intervention.
For this reason there is also a XML file, which is a Windows scheduler task, to easily set up the automatic update process. 
Because this "software" doesn't have an installer, the script can be saved everywhere on the hard disk, therefore the only change that has to be made to the Windows scheduler task is the working directory, which is where the script has been saved.
If you save the script in the Plex media server folder (C:\Program Files (x86)\Plex), where I have saved it, you don't have to modify the working directory of the Windows scheduler task.
The task is configured to output the script execution in a log file, it is a simple output to a log file, thus the log file will grow indefinitely.
This could be a problem, if the task is execute to often, the default execution interval in once a week, which shouldn't be a problem for the next 10 years.
