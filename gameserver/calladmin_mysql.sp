/**
 * -----------------------------------------------------
 * File        calladmin_mysql.sp
 * Authors     Impact, David <popoklopsi> Ordnung
 * License     GPLv3
 * Web         http://gugyclan.eu, http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013 Impact, David <popoklopsi> Ordnung
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */
 
#include <sourcemod>
#include <autoexecconfig>
#include "calladmin"

#undef REQUIRE_PLUGIN
#include <updater>
#pragma semicolon 1



// Global Stuff
new Handle:g_hEntryPruning;
new g_iEntryPruning;

new Handle:g_hOhphanedEntryPruning;
new g_iOhphanedEntryPruning;

new Handle:g_hVersion;

new bool:g_bLateLoad;
new bool:g_bDBDelayedLoad;

new g_iHostPort;
new String:g_sServerName[64];
new String:g_sHostIP[16];


#define PRUNE_TRACKERS_TIME 3
new g_iCurrentTrackers;



// Dbstuff
new Handle:g_hDbHandle;


#define SQL_DB_CONF "CallAdmin"



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_mysql.txt"


public Plugin:myinfo = 
{
	name = "CallAdmin: Mysql module",
	author = "Impact, Popoklopsi",
	description = "BLEH",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}



public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = late;
	
	if(!g_bLateLoad)
	{
		g_bDBDelayedLoad = true;
	}

	return APLRes_Success;
}



public OnConfigsExecuted()
{
	if(g_bDBDelayedLoad)
	{
		InitDB();
		g_bDBDelayedLoad = false;
	}
}





public OnPluginStart()
{
	// Fallback for default if possible
	if(!SQL_CheckConfig(SQL_DB_CONF) && !SQL_CheckConfig("default"))
	{
		SetFailState("Couldn't find database config");
	}
	
	
	// We only connect directly if it was a lateload, else we connect when configs were executed to grab the cvars
	// Configs might've not been excuted and we can't grab the hostname/hostport else
	if(g_bLateLoad)
	{
		InitDB();
	}
	
	
	
	AutoExecConfig_SetFile("plugin.calladmin_mysql");
	
	g_hVersion                = AutoExecConfig_CreateConVar("sm_calladmin_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hEntryPruning           = AutoExecConfig_CreateConVar("sm_calladmin_entrypruning", "25", "Entries older than given minutes will be deleted, 0 deactivates the feature", FCVAR_PLUGIN, true, 0.0);
	g_hOhphanedEntryPruning   = AutoExecConfig_CreateConVar("sm_calladmin_entrypruning_ohphaned", "4320", "Entries older than given minutes will be recognized as orphaned and will be deleted globally (serverIP and serverPort won't be checked)", FCVAR_PLUGIN, true, 0.0, true, 0.0);
	
	
	AutoExecConfig(true, "plugin.calladmin_mysql");
	AutoExecConfig_CleanFile();
	
	
	LoadTranslations("calladmin.phrases");
	
	
	SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);
	
	g_iEntryPruning = GetConVarInt(g_hEntryPruning);
	HookConVarChange(g_hEntryPruning, OnCvarChanged);
	
	g_iOhphanedEntryPruning = GetConVarInt(g_hOhphanedEntryPruning);
	HookConVarChange(g_hOhphanedEntryPruning, OnCvarChanged);
	
	g_iHostPort = CallAdmin_GetHostPort();
	CallAdmin_GetHostIP(g_sHostIP, sizeof(g_sHostIP));
	CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));

	CreateTimer(600.0, Timer_PruneEntries, _, TIMER_REPEAT);
	CreateTimer(20.0, Timer_UpdateTrackersCount, _, TIMER_REPEAT);
}




InitDB()
{
	SQL_TConnect(SQLT_ConnectCallback, SQL_CheckConfig(SQL_DB_CONF) ? SQL_DB_CONF : "default");
}





public OnAllPluginsLoaded()
{
	if(!LibraryExists("calladmin"))
	{
		SetFailState("CallAdmin not found");
	}

	if(LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATER_URL);
	}
}




public OnLibraryAdded(const String:name[])
{
    if(StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATER_URL);
    }
}




public Action:Timer_PruneEntries(Handle:timer)
{
	// Prune old entries if enabled
	if(g_iEntryPruning > 0)
	{
		PruneDatabase();
	}
	
	return Plugin_Continue;
}




// Pseudo forward
public CallAdmin_OnRequestTrackersCountRefresh(&trackers)
{
	trackers = g_iCurrentTrackers;
}




public CallAdmin_OnServerDataChanged(Handle:convar, ServerData:type, const String:oldVal[], const String:newVal[])
{
	if(type == ServerData_HostIP)
	{
		CallAdmin_GetHostIP(g_sHostIP, sizeof(g_sHostIP));
	}
	else if(type == ServerData_HostName)
	{
		CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
	}
	else if(type == ServerData_HostPort)
	{
		g_iHostPort = CallAdmin_GetHostPort();
	}
}




PruneDatabase()
{
	if(g_hDbHandle != INVALID_HANDLE)
	{
		decl String:query[1024];
		decl String:sHostIP[16];
		new iHostPort = CallAdmin_GetHostPort();
		CallAdmin_GetHostIP(sHostIP, sizeof(sHostIP));
		
		// Prune main table (this server)
		Format(query, sizeof(query), "DELETE FROM CallAdmin WHERE serverIP = '%s' AND serverPort = '%d' AND TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(reportedAt), NOW()) > %d", sHostIP, iHostPort, g_iEntryPruning);
		SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, query);
		
		
		// Prune trackers table (global)
		Format(query, sizeof(query), "DELETE FROM CallAdmin_Trackers WHERE TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(lastView), NOW()) >= %d", PRUNE_TRACKERS_TIME);
		SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, query);
		
		
		// Prune ohphaned entries (global)
		Format(query, sizeof(query), "DELETE FROM CallAdmin WHERE TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(reportedAt), NOW()) > %d", g_iOhphanedEntryPruning);
		SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, query);
	}
}




UpdateServerData()
{
	if(g_hDbHandle != INVALID_HANDLE)
	{
		decl String:query[1024];
		
		decl String:sHostName[(sizeof(g_sServerName) + 1) * 2];
		SQL_EscapeString(g_hDbHandle, g_sServerName, sHostName, sizeof(sHostName));
		
		// Update the servername
		Format(query, sizeof(query), "UPDATE IGNORE CallAdmin SET serverName = '%s' WHERE serverIP = '%s' AND serverPort = '%d'", sHostName, g_sHostIP, g_iHostPort);
		SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, query);
	}
}




public OnCvarChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if(cvar == g_hEntryPruning)
	{
		g_iEntryPruning = GetConVarInt(g_hEntryPruning);
	}
	else if(cvar == g_hOhphanedEntryPruning)
	{
		g_iOhphanedEntryPruning = GetConVarInt(g_hOhphanedEntryPruning);
	}
	else if(cvar == g_hVersion)
	{
		SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	}
	
	UpdateServerData();
}




public CallAdmin_OnReportPost(client, target, const String:reason[])
{
	new String:clientNameBuf[MAX_NAME_LENGTH];
	new String:clientName[(MAX_NAME_LENGTH + 1) * 2];
	new String:clientAuth[21];
	
	new String:targetNameBuf[MAX_NAME_LENGTH];
	new String:targetName[(MAX_NAME_LENGTH + 1) * 2];
	new String:targetAuth[21];
	
	new String:sReason[(48 + 1) * 2];
	SQL_EscapeString(g_hDbHandle, reason, sReason, sizeof(sReason));
	
	
	// Reporter wasn't a real client (initiated by a module)
	if(client == REPORTER_CONSOLE)
	{
		strcopy(clientName, sizeof(clientName), "Server/Console");
		strcopy(clientAuth, sizeof(clientAuth), "Server/Console");
	}
	else
	{
		GetClientName(client, clientNameBuf, sizeof(clientNameBuf));
		SQL_EscapeString(g_hDbHandle, clientNameBuf, clientName, sizeof(clientName));
		GetClientAuthString(client, clientAuth, sizeof(clientAuth));
	}
	
	
	GetClientName(target, targetNameBuf, sizeof(targetNameBuf));
	SQL_EscapeString(g_hDbHandle, targetNameBuf, targetName, sizeof(targetName));
	GetClientAuthString(target, targetAuth, sizeof(targetAuth));
	
	new String:serverName[(sizeof(g_sServerName) + 1) * 2];
	SQL_EscapeString(g_hDbHandle, g_sServerName, serverName, sizeof(serverName));
	
	new String:query[1024];
	Format(query, sizeof(query), "INSERT INTO CallAdmin\
												(serverIP, serverPort, serverName, targetName, targetID, targetReason, clientName, clientID, reportedAt)\
											VALUES\
												('%s', '%d', '%s', '%s', '%s', '%s', '%s', '%s', UNIX_TIMESTAMP())",
											g_sHostIP, g_iHostPort, serverName, targetName, targetAuth, sReason, clientName, clientAuth);
	SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, query);
}




public SQLT_ConnectCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		SetFailState("ConErr: %s", error);
	}
	else
	{
		g_hDbHandle = hndl;
		
		// Set utf-8 encodings
		SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, "SET NAMES 'utf8'");
		
		// Create main Table
		SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, "CREATE TABLE IF NOT EXISTS `CallAdmin` (\
															`callID` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,\
															`serverIP` VARCHAR(15) NOT NULL,\
															`serverPort` SMALLINT(5) UNSIGNED NOT NULL,\
															`serverName` VARCHAR(64) NOT NULL,\
															`targetName` VARCHAR(32) NOT NULL,\
															`targetID` VARCHAR(21) NOT NULL,\
															`targetReason` VARCHAR(48) NOT NULL,\
															`clientName` VARCHAR(32) NOT NULL,\
															`clientID` VARCHAR(21) NOT NULL,\
															`callHandled` TINYINT(1) UNSIGNED NOT NULL,\
															`reportedAt` INT(10) UNSIGNED NOT NULL,\
															INDEX `serverIP_serverPort` (`serverIP`, `serverPort`),\
															INDEX `reportedAt` (`reportedAt`),\
															INDEX `callHandled` (`callHandled`),\
															PRIMARY KEY (`callID`))\
															COLLATE='utf8_unicode_ci'\
														");
														
		// Create trackers Table
		SQL_TQuery(g_hDbHandle, SQLT_ErrorCheckCallback, "CREATE TABLE IF NOT EXISTS `CallAdmin_Trackers` (\
															`trackerIP` VARCHAR(15) NOT NULL,\
															`trackerID` VARCHAR(21) NOT NULL,\
															`lastView` INT(10) UNSIGNED NOT NULL,\
															INDEX `lastView` (`lastView`),\
															UNIQUE INDEX `trackerIP` (`trackerIP`))\
															COLLATE='utf8_unicode_ci'\
														");
		
		// Prune old entries if enabled
		if(g_iEntryPruning > 0)
		{
			PruneDatabase();
		}
		
		// Get Current trackers
		GetCurrentTrackers();
		
		// Update Serverdata
		UpdateServerData();
	}
}




public SQLT_ErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		SetFailState("QueryErr: %s", error);
	}
}




public Action:Timer_UpdateTrackersCount(Handle:timer)
{
	// Get current trackers
	GetCurrentTrackers();
	
	return Plugin_Continue;
}




GetCurrentTrackers()
{
	if(g_hDbHandle != INVALID_HANDLE)
	{
		decl String:query[1024];
		
		// Get current trackers (last 2 minutes)
		Format(query, sizeof(query), "SELECT \
											COUNT(`trackerID`) as currentTrackers \
										FROM \
											CallAdmin_Trackers \
										WHERE \
											TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(lastView), NOW()) < 2");
		SQL_TQuery(g_hDbHandle, SQLT_CurrentTrackersCallback, query);
	}
}




public SQLT_CurrentTrackersCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		SetFailState("CurrentTrackersErr: %s", error);
	}
	else
	{
		if(SQL_FetchRow(hndl))
		{
			g_iCurrentTrackers = SQL_FetchInt(hndl, 0);
		}
	}
}





stock bool:IsClientValid(id)
{
	if(id > 0 && id <= MaxClients && IsClientInGame(id))
	{
		return true;
	}
	
	return false;
}
