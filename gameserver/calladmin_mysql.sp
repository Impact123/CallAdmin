/**
 * -----------------------------------------------------
 * File        calladmin_mysql.sp
 * Authors     Impact, dordnung
 * License     GPLv3
 * Web         http://gugyclan.eu, https://dordnung.de
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013-2018 Impact, dordnung
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
#include "include/autoexecconfig"
#include "include/calladmin"

#undef REQUIRE_PLUGIN
#include "include/updater"
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
	author = "Impact, dordnung",
	description = "The mysqlmodule for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}




public void OnConfigsExecuted()
{
	g_iEntryPruning = g_hEntryPruning.IntValue;
	g_hServerKey.GetString(g_sServerKey, sizeof(g_sServerKey));
	g_iOhphanedEntryPruning = g_hOhphanedEntryPruning.IntValue;
	
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
	
	g_hVersion                = AutoExecConfig_CreateConVar("sm_calladmin_mysql_version", CALLADMIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hTableName              = AutoExecConfig_CreateConVar("sm_calladmin_table_name", "CallAdmin", "Name of the CallAdmin table", FCVAR_PROTECTED);
	g_hServerKey              = AutoExecConfig_CreateConVar("sm_calladmin_server_key", "", "Server key to identify this server (Max. 64 allowed!)", FCVAR_PROTECTED);
	g_hEntryPruning           = AutoExecConfig_CreateConVar("sm_calladmin_entrypruning", "25", "Entries older than given minutes will be deleted, 0 deactivates the feature", FCVAR_NONE, true, 0.0);
	g_hOhphanedEntryPruning   = AutoExecConfig_CreateConVar("sm_calladmin_entrypruning_ohphaned", "4320", "Entries older than given minutes will be recognized as orphaned and will be deleted globally (serverIP and serverPort won't be checked)", FCVAR_NONE, true, 0.0);
	
	
	AutoExecConfig(true, "plugin.calladmin_mysql");
	AutoExecConfig_CleanFile();
	
	
	LoadTranslations("calladmin.phrases");
	
	
	// This is done so that when the plugin is updated its version stays up to date too
	g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	g_hVersion.AddChangeHook(OnCvarChanged);

	g_hEntryPruning.AddChangeHook(OnCvarChanged);
	g_hServerKey.AddChangeHook(OnCvarChanged);
	g_hOhphanedEntryPruning.AddChangeHook(OnCvarChanged);

	CreateTimer(60.0, Timer_PruneEntries, _, TIMER_REPEAT);
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
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATER_URL);
	}
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
		
		char sServerIP[16];
		int serverPort;
		char sServerName[128];
		
		CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
		serverPort = CallAdmin_GetHostPort();
		CallAdmin_GetHostName(sServerName, sizeof(sServerName));
		
		// Update the servername
		g_hDbHandle.Format(query, sizeof(query), "UPDATE IGNORE `%s` SET serverName = '%s', serverKey = '%s' WHERE serverIP = '%s' AND serverPort = %d", g_sTableName, sServerName, g_sServerKey, sServerIP, serverPort);
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


	char clientName[MAX_NAME_LENGTH];
	char clientAuth[21];
	
	char targetName[MAX_NAME_LENGTH];
	char targetAuth[21];
	
	
	// Reporter wasn't a real client (initiated by a module)
	if (client == REPORTER_CONSOLE)
	{
		strcopy(clientName, sizeof(clientName), "Server/Console");
		strcopy(clientAuth, sizeof(clientAuth), "Server/Console");
	}
	else
	{
		GetClientName(client, clientName, sizeof(clientName));
		
		if (!GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth)))
		{
			CallAdmin_LogMessage("Failed to get authentication for client %d (%s)", client, clientName);
			
			return;
		}
	}
	
	
	GetClientName(target, targetName, sizeof(targetName));
	
	if (!GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth)))
	{
		CallAdmin_LogMessage("Failed to get authentication for client %d (%s)", client, targetName);
		
		return;
	}
	
	char sServerIP[16];
	int serverPort;
	char sServerName[128];
	
	CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
	serverPort = CallAdmin_GetHostPort();
	CallAdmin_GetHostName(sServerName, sizeof(sServerName));
	
	
	char query[1024];
	g_hDbHandle.Format(query, sizeof(query), "INSERT INTO `%s`\
												(serverIP, serverPort, serverName, serverKey, targetName, targetID, targetReason, clientName, clientID, callHandled, reportedAt)\
											VALUES\
												('%s', %d, '%s', '%s', '%s', '%s', '%s', '%s', '%s', 0, UNIX_TIMESTAMP())",
											g_sTableName, sServerIP, serverPort, sServerName, g_sServerKey, targetName, targetAuth, reason, clientName, clientAuth);
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
		
		// We only support the mysql driver
		char ident[32];
		g_hDbHandle.Driver.GetIdentifier(ident, sizeof(ident));
		if (!StrEqual(ident, "mysql"))
		{
			CallAdmin_LogMessage("ConErr: driver id %s, expected mysql", ident);
			SetFailState("ConErr: driver id %s, expected mysql", ident);
		}
		
		g_hDbHandle.SetCharset("utf8mb4");
		
		// Create main Table
		char query[1024];
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s` (\
															`callID` INT UNSIGNED NOT NULL AUTO_INCREMENT,\
															`serverIP` VARCHAR(15) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`serverPort` SMALLINT UNSIGNED NOT NULL,\
															`serverName` VARCHAR(64) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`serverKey` VARCHAR(32) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`targetName` VARCHAR(32) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`targetID` VARCHAR(21) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`targetReason` VARCHAR(%d) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`clientName` VARCHAR(32) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`clientID` VARCHAR(21) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`callHandled` TINYINT UNSIGNED NOT NULL,\
															`reportedAt` INT UNSIGNED NOT NULL,\
															INDEX `serverIP_serverPort` (`serverIP`, `serverPort`),\
															INDEX `reportedAt` (`reportedAt`),\
															INDEX `callHandled` (`callHandled`),\
															INDEX `serverKey` (`serverKey`),\
															PRIMARY KEY (`callID`))\
															ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci\
														", g_sTableName, REASON_MAX_LENGTH);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
														
		// Create trackers Table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s_Trackers` (\
															`trackerIP` VARCHAR(15) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`trackerID` VARCHAR(21) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`lastView` INT UNSIGNED NOT NULL,\
															`accessID` BIGINT UNSIGNED NOT NULL,\
															INDEX `lastView` (`lastView`),\
															UNIQUE INDEX `trackerIP` (`trackerIP`))\
															ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci\
														", g_sTableName);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
														
		// Create Access Table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s_Access` (\
															`serverKey` VARCHAR(32) COLLATE utf8mb4_unicode_ci NOT NULL,\
															`accessBit` BIGINT UNSIGNED NOT NULL,\
															UNIQUE INDEX `serverKey` (`serverKey`))\
															ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci\
														", g_sTableName);
		g_hDbHandle.Query(SQLT_ErrorCheckCallback, query);
										
		// Create Version Table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s_Settings` (\
															`version` VARCHAR(12) COLLATE utf8mb4_unicode_ci NOT NULL)\
															ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci\
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
		
		// Get current trackers (last 2 minutes)
		g_hDbHandle.Format(query, sizeof(query), "SELECT \
											COUNT(`trackerID`) as currentTrackers \
										FROM \
											`%s_Trackers` \
										WHERE \
											TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(lastView), NOW()) < 2 AND \
											`accessID` & (SELECT `accessBit` FROM `%s_Access` WHERE `serverKey`='%s')", g_sTableName, g_sTableName, g_sServerKey);
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
