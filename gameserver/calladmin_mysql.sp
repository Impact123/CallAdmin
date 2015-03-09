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
#pragma newdecls required


// Global Stuff
ConVar g_hEntryPruning;
char g_iEntryPruning;

ConVar g_hTableName;
char g_sTableName[32];

ConVar g_hServerKey;
char g_sServerKey[32];

ConVar g_hOhphanedEntryPruning;
char g_iOhphanedEntryPruning;

ConVar g_hVersion;

bool g_bAllLoaded;
bool g_bDbInitTriggered;

char g_iHostPort;
char g_sServerName[64];
char g_sHostIP[16];


#define PRUNE_TRACKERS_TIME 3
char g_iCurrentTrackers;



// Dbstuff
Database g_hDbHandle;


#define SQL_DB_CONF "CallAdmin"



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_mysql.txt"


public Plugin myinfo = 
{
	name = "CallAdmin: Mysql module",
	author = "Impact, Popoklopsi",
	description = "The mysqlmodule for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}



public void OnConfigsExecuted()
{
	if (!g_bDbInitTriggered)
	{
		// This convar is the only one which isn't hooked, we only fetch its content once before the connection to the database is made
		g_hTableName.GetString(g_sTableName, sizeof(g_sTableName));
		
		InitDB();
		g_bDbInitTriggered = true;
	}
}





public void OnPluginStart()
{
	AutoExecConfig_SetFile("plugin.calladmin_mysql");
	
	g_hVersion                = view_as<ConVar> AutoExecConfig_CreateConVar("sm_calladmin_mysql_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hTableName              = view_as<ConVar> AutoExecConfig_CreateConVar("sm_calladmin_table_name", "CallAdmin", "Name of the CallAdmin table", FCVAR_PLUGIN);
	g_hServerKey              = view_as<ConVar> AutoExecConfig_CreateConVar("sm_calladmin_server_key", "", "Server key to identify this server (Max. 64 allowed!)", FCVAR_PLUGIN);
	g_hEntryPruning           = view_as<ConVar> AutoExecConfig_CreateConVar("sm_calladmin_entrypruning", "25", "Entries older than given minutes will be deleted, 0 deactivates the feature", FCVAR_PLUGIN, true, 0.0);
	g_hOhphanedEntryPruning   = view_as<ConVar> AutoExecConfig_CreateConVar("sm_calladmin_entrypruning_ohphaned", "4320", "Entries older than given minutes will be recognized as orphaned and will be deleted globally (serverIP and serverPort won't be checked)", FCVAR_PLUGIN, true, 0.0);
	
	
	AutoExecConfig(true, "plugin.calladmin_mysql");
	AutoExecConfig_CleanFile();
	
	
	LoadTranslations("calladmin.phrases");
	
	
	g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);

	g_iEntryPruning = g_hEntryPruning.IntValue;
	HookConVarChange(g_hEntryPruning, OnCvarChanged);

	g_hServerKey.GetString(g_sServerKey, sizeof(g_sServerKey));
	HookConVarChange(g_hServerKey, OnCvarChanged);
	
	g_iOhphanedEntryPruning = g_hOhphanedEntryPruning.IntValue;
	HookConVarChange(g_hOhphanedEntryPruning, OnCvarChanged);

	CreateTimer(600.0, Timer_PruneEntries, _, TIMER_REPEAT);
	CreateTimer(20.0, Timer_UpdateTrackersCount, _, TIMER_REPEAT);
}




void InitDB()
{
	// Fallback for default if possible
	if (!SQL_CheckConfig(SQL_DB_CONF) && !SQL_CheckConfig("default"))
	{
		CallAdmin_LogMessage("Couldn't find database config");
		SetFailState("Couldn't find database config");
	}
	
	Database.Connect(SQLT_ConnectCallback, SQL_CheckConfig(SQL_DB_CONF) ? SQL_DB_CONF : "default");
}





public void OnAllPluginsLoaded()
{
	if (!LibraryExists("calladmin"))
	{
		SetFailState("CallAdmin not found");
	}

	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATER_URL);
	}

	g_iHostPort = CallAdmin_GetHostPort();
	CallAdmin_GetHostIP(g_sHostIP, sizeof(g_sHostIP));
	CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}




public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATER_URL);
    }
}




public Action Timer_PruneEntries(Handle timer)
{
	// Prune old entries if enabled
	if (g_iEntryPruning > 0)
	{
		PruneDatabase();
	}
	
	return Plugin_Continue;
}




// Pseudo forward
public void CallAdmin_OnRequestTrackersCountRefresh(int &trackers)
{
	trackers = g_iCurrentTrackers;
}




public void CallAdmin_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal)
{
	if (type == ServerData_HostIP)
	{
		CallAdmin_GetHostIP(g_sHostIP, sizeof(g_sHostIP));
	}
	else if (type == ServerData_HostName)
	{
		CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
	}
	else if (type == ServerData_HostPort)
	{
		g_iHostPort = CallAdmin_GetHostPort();
	}
}




void PruneDatabase()
{
	if (g_hDbHandle != null && g_bAllLoaded)
	{
		char query[1024];
		char sHostIP[16];
		int iHostPort = CallAdmin_GetHostPort();
		CallAdmin_GetHostIP(sHostIP, sizeof(sHostIP));
		
		// Prune main table (this server)
		Format(query, sizeof(query), "DELETE FROM `%s` WHERE serverIP = '%s' AND serverPort = %d AND TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(reportedAt), NOW()) > %d", g_sTableName, sHostIP, iHostPort, g_iEntryPruning);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
		
		
		// Prune trackers table (global)
		Format(query, sizeof(query), "DELETE FROM `%s_Trackers` WHERE TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(lastView), NOW()) >= %d", g_sTableName, PRUNE_TRACKERS_TIME);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
		
		
		// Prune ohphaned entries (global)
		Format(query, sizeof(query), "DELETE FROM `%s` WHERE TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(reportedAt), NOW()) > %d", g_sTableName, g_iOhphanedEntryPruning);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
	}
}




void UpdateServerData()
{
	if (g_hDbHandle != null && g_bAllLoaded)
	{
		char query[1024];
		
		char sHostName[(sizeof(g_sServerName) + 1) * 2];
		g_hDbHandle.Escape(g_sServerName, sHostName, sizeof(sHostName));
		
		// Update the servername
		Format(query, sizeof(query), "UPDATE IGNORE `%s` SET serverName = '%s', serverKey = '%s' WHERE serverIP = '%s' AND serverPort = %d", g_sTableName, sHostName, g_sServerKey, g_sHostIP, g_iHostPort);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
	}
}




public void OnCvarChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_hEntryPruning)
	{
		g_iEntryPruning = g_hEntryPruning.IntValue;
	}
	else if (cvar == g_hServerKey)
	{
		g_hServerKey.GetString(g_sServerKey, sizeof(g_sServerKey));
	}
	else if (cvar == g_hOhphanedEntryPruning)
	{
		g_iOhphanedEntryPruning = g_hOhphanedEntryPruning.IntValue;
	}
	else if (cvar == g_hVersion)
	{
		g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	}
	
	UpdateServerData();
}




public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	// We need all loaded
	if (!g_bAllLoaded || g_hDbHandle == null)
	{
		return;
	}


	char clientNameBuf[MAX_NAME_LENGTH];
	char clientName[(MAX_NAME_LENGTH + 1) * 2];
	char clientAuth[21];
	
	char targetNameBuf[MAX_NAME_LENGTH];
	char targetName[(MAX_NAME_LENGTH + 1) * 2];
	char targetAuth[21];

	char sKey[(32 + 1) * 2];
	g_hDbHandle.Escape(g_sServerKey, sKey, sizeof(sKey));

	char sReason[(REASON_MAX_LENGTH + 1) * 2];
	g_hDbHandle.Escape(reason, sReason, sizeof(sReason));
	
	
	// Reporter wasn't a real client (initiated by a module)
	if (client == REPORTER_CONSOLE)
	{
		strcopy(clientName, sizeof(clientName), "Server/Console");
		strcopy(clientAuth, sizeof(clientAuth), "Server/Console");
	}
	else
	{
		GetClientName(client, clientNameBuf, sizeof(clientNameBuf));
		g_hDbHandle.Escape(clientNameBuf, clientName, sizeof(clientName));
		GetClientAuthString(client, clientAuth, sizeof(clientAuth));
	}
	
	
	GetClientName(target, targetNameBuf, sizeof(targetNameBuf));
	g_hDbHandle.Escape(targetNameBuf, targetName, sizeof(targetName));
	GetClientAuthString(target, targetAuth, sizeof(targetAuth));
	
	char serverName[(sizeof(g_sServerName) + 1) * 2];
	g_hDbHandle.Escape(g_sServerName, serverName, sizeof(serverName));
	
	char query[1024];
	Format(query, sizeof(query), "INSERT INTO `%s`\
												(serverIP, serverPort, serverName, serverKey, targetName, targetID, targetReason, clientName, clientID, callHandled, reportedAt)\
											VALUES\
												('%s', %d, '%s', '%s', '%s', '%s', '%s', '%s', '%s', 0, UNIX_TIMESTAMP())",
											g_sTableName, g_sHostIP, g_iHostPort, serverName, sKey, targetName, targetAuth, sReason, clientName, clientAuth);
	g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
}




public void SQLT_ConnectCallback(Database db, const char[] error, any data)
{
	if (db == null)
	{
		CallAdmin_LogMessage("ConErr: %s", error);
		SetFailState("ConErr: %s", error);
	}
	else
	{
		g_hDbHandle = db;
		
		// Set utf-8 encodings
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, "SET NAMES 'utf8'");
		
		// Create main Table
		char query[1024];
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s` (\
															`callID` INT UNSIGNED NOT NULL AUTO_INCREMENT,\
															`serverIP` VARCHAR(15) NOT NULL,\
															`serverPort` SMALLINT UNSIGNED NOT NULL,\
															`serverName` VARCHAR(64) NOT NULL,\
															`serverKey` VARCHAR(32) NOT NULL,\
															`targetName` VARCHAR(32) NOT NULL,\
															`targetID` VARCHAR(21) NOT NULL,\
															`targetReason` VARCHAR(%d) NOT NULL,\
															`clientName` VARCHAR(32) NOT NULL,\
															`clientID` VARCHAR(21) NOT NULL,\
															`callHandled` TINYINT UNSIGNED NOT NULL,\
															`reportedAt` INT UNSIGNED NOT NULL,\
															INDEX `serverIP_serverPort` (`serverIP`, `serverPort`),\
															INDEX `reportedAt` (`reportedAt`),\
															INDEX `callHandled` (`callHandled`),\
															INDEX `serverKey` (`serverKey`),\
															PRIMARY KEY (`callID`))\
															COLLATE='utf8_unicode_ci'\
														", g_sTableName, REASON_MAX_LENGTH);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
														
		// Create trackers Table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s_Trackers` (\
															`trackerIP` VARCHAR(15) NOT NULL,\
															`trackerID` VARCHAR(21) NOT NULL,\
															`lastView` INT UNSIGNED NOT NULL,\
															`accessID` BIGINT UNSIGNED NOT NULL,\
															INDEX `lastView` (`lastView`),\
															UNIQUE INDEX `trackerIP` (`trackerIP`))\
															COLLATE='utf8_unicode_ci'\
														", g_sTableName);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
														
		// Create Access Table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s_Access` (\
															`serverKey` VARCHAR(32) NOT NULL,\
															`accessBit` BIGINT UNSIGNED NOT NULL,\
															UNIQUE INDEX `serverKey` (`serverKey`))\
															COLLATE='utf8_unicode_ci'\
														", g_sTableName);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
										
		// Create Version Table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s_Settings` (\
															`version` VARCHAR(12) NOT NULL)\
															COLLATE='utf8_unicode_ci'\
														", g_sTableName);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
		
		// Get current version
		Format(query, sizeof(query), "SELECT \
											`version` \
										FROM \
											`%s_Settings` LIMIT 1", g_sTableName);
		g_hDbHandle.Query(SQLT_CurrentVersion, query);
	}
}




public void SQLT_ErrorCheckCallback(Database db, DBResultSet result, const char[] error, any data)
{
	if (result == null)
	{
		CallAdmin_LogMessage("QueryErr: %s", error);
		SetFailState("QueryErr: %s", error);
	}
}




public void SQLT_CurrentVersion(Database db, DBResultSet result, const char[] error, any data)
{
	char version[12];
	char query[512];

	if (result != null)
	{
		if (result.FetchRow())
		{
			result.FetchString(0, version, sizeof(version));

			// Setup maybe new structure
			ChangeDB(version);
		}
		else
		{
			// We have to check the real version
			Format(query, sizeof(query), "SELECT \
										`serverKey` \
									FROM \
										`%s` LIMIT 1", g_sTableName);

			g_hDbHandle.Query(SQLT_GetRealVersion, query);

			// Insert Version
			Format(query, sizeof(query), "INSERT INTO `%s_Settings` \
														(version) \
													VALUES \
														('%s')", g_sTableName, CALLADMIN_VERSION);
			g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);


			return;
		}
	}
	else 
	{
		CallAdmin_LogMessage("VersionErr: %s", error);
		SetFailState("VersionErr: %s", error);
	}


	// Update version
	Format(query, sizeof(query), "UPDATE `%s_Settings` SET version = '%s'", g_sTableName, CALLADMIN_VERSION);
	g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
}




public void SQLT_GetRealVersion(Database db, DBResultSet result, const char[] error, any data)
{
	if (result == null)
	{
		// We have the old 0.1.2A
		ChangeDB("0.1.2A");
	}
	else
	{
		// The version is the current version
		OnAllLoaded();
	}
}




void ChangeDB(const char[] version)
{
	char query[512];

	// Check version < 0.1.3
	if (!IsVersionNewerOrEqual(version, "0.1.3"))
	{
		// Update Table to current structure
		Format(query, sizeof(query), "ALTER TABLE `%s` \
													ADD COLUMN `serverKey` VARCHAR(32) NOT NULL AFTER `serverName`, \
													CHANGE COLUMN `targetReason` `targetReason` VARCHAR(%d) NOT NULL AFTER `targetID`, \
													ADD INDEX `serverKey` (`serverKey`) \
													", g_sTableName, REASON_MAX_LENGTH);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
	}

	// Now we are finished
	OnAllLoaded();
}





bool IsVersionNewerOrEqual(const char[] currentVersion, const char[] versionCompare)
{
	// Check if currentVersion >= versionCompare
	return (strcmp(versionCompare, currentVersion, false) <= 0);
}




public Action Timer_UpdateTrackersCount(Handle timer)
{
	// Get current trackers
	GetCurrentTrackers();
	
	return Plugin_Continue;
}




int GetCurrentTrackers()
{
	// We need all loaded
	if (g_hDbHandle != null && g_bAllLoaded)
	{
		char query[1024];

		char sKey[(32 + 1) * 2];
		SQL_EscapeString(g_hDbHandle, g_sServerKey, sKey, sizeof(sKey));
		
		// Get current trackers (last 2 minutes)
		Format(query, sizeof(query), "SELECT \
											COUNT(`trackerID`) as currentTrackers \
										FROM \
											`%s_Trackers` \
										WHERE \
											TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(lastView), NOW()) < 2 AND \
											`accessID` & (SELECT `accessBit` FROM `%s_Access` WHERE `serverKey`='%s')", g_sTableName, g_sTableName, sKey);
		g_hDbHandle.Query(SQLT_CurrentTrackersCallback, query);
	}
	else
	{
		// Set to zero
		g_iCurrentTrackers = 0;
	}
}




public void SQLT_CurrentTrackersCallback(Database db, DBResultSet result, const char[] error, any data)
{
	if (result == null)
	{
		CallAdmin_LogMessage("CurrentTrackersErr: %s", error);
		SetFailState("CurrentTrackersErr: %s", error);
	}
	else
	{
		if (result.FetchRow())
		{
			g_iCurrentTrackers = result.FetchInt(0);
		}
	}
}




void OnAllLoaded()
{
	g_bAllLoaded = true;


	// Prune old entries if enabled
	if (g_iEntryPruning > 0)
	{
		PruneDatabase();
	}
	
	// Get Current trackers
	GetCurrentTrackers();

	// Update Serverdata
	UpdateServerData();
}