# CallAdmin  
CallAdmin is an multilingual, modular and extendable system to allow inGame reports for HL2-Games and Mods.  

The system is based on 3 parts.  
* An extendable sourcemod-plugin to report players inGame  
* [An Desktopclient](https://github.com/popoklopsi/CallAdmin-Client) to notify admins  when a new report was made  
* An webscript to interact with data from the database for the client  


## Installation #Plugin
1. Get the optional [Plugin updater](http://forums.alliedmods.net/showthread.php?t=169095), we highly recommend you to use it  
2. Open `../addons/sourcemod/config/databases.cfg` and add a new entry with the key `CallAdmin`  
3. Restart your server or change the map to reload the databases.cfg file  
4. Put `calladmin.smx` in your `../addons/sourcemod/plugins` directory  
5. Put `calladmin.phrases` in your `../addons/sourcemod/translations` directory  
7. Load the plugin or change the map, the plugin will create an file named `plugin.calladmin.cfg` in your `../cfg/sourcemod` folder  
8. Edit the config to your purposes  


### Download #Plugin
You can download the full package with the compiled plugin [here](http://vs.gugyclan.eu:8000/job/CallAdmin/) (grab the gameserver package).


## Installation #Webscript
1. Put all files into an subfolder in your webspace  
2. Open the app.config file, edit the database settings and set an key


### Download #Webscript
You can download the full package [here](http://vs.gugyclan.eu:8000/job/CallAdmin/) (grab the webserver package).


## Installation #Client
1. Download the client including all files into some folder  
2. Setup the client in the settings tab  
3. Wait for new reports  



## Notes
* This system is currently an alpha software, use it on your own risk  