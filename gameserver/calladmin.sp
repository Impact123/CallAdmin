/**
 * -----------------------------------------------------
 * File        calladmin.sp
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




// Banreasons
new Handle:g_hBanReasons;
new String:g_sBanReasons[1200];
new String:g_sBanReasonsExploded[24][48];


// Global Stuff
new Handle:g_hServerName;
new String:g_sServerName[64];

new Handle:g_hEntryPruning;
new g_iEntryPruning;

new Handle:g_hOhphanedEntryPruning;
new g_iOhphanedEntryPruning;

new Handle:g_hVersion;

new Handle:g_hHostPort;
new g_iHostPort;

new Handle:g_hHostIP;
new g_iHostIP;
new String:g_sHostIP[16];

new Handle:g_hAdvertTimer;
new Handle:g_hAdvertInterval;
new Float:g_fAdvertInterval;

new Handle:g_hPublicMessage;
new bool:g_bPublicMessage;

new Handle:g_hOwnReason;
new bool:g_bOwnReason;

new Handle:g_hConfirmCall;
new bool:g_bConfirmCall;

new Handle:g_hSpamTime;
new g_iSpamTime;

new Handle:g_hAdminAction;
new g_iAdminAction;


#define ADMIN_ACTION_PASS          0
#define ADMIN_ACTION_BLOCK_MESSAGE 1


new bool:g_bLateLoad;
new bool:g_bDBDelayedLoad;


#define PRUNE_TRACKERS_TIME 3
new g_iCurrentTrackers;



// User info
new g_iTarget[MAXPLAYERS + 1];
new String:g_sTargetReason[MAXPLAYERS + 1][48];

// Is this player writing his own reason?
new bool:g_bAwaitingReason[MAXPLAYERS +1];

// Is this player waiting for an admin?
new bool:g_bAwaitingAdmin[MAXPLAYERS +1];

// When has this user reported the last time
new g_iLastReport[MAXPLAYERS +1];

// When was this user reported the last time
new g_bWasReported[MAXPLAYERS +1];

// Player saw the antispam message
new bool:g_bSawMesage[MAXPLAYERS +1];


// Dbstuff
new Handle:g_hDbHandle;



// Api
new Handle:g_hOnReportPostForward;
new Handle:g_hOnDrawOwnReasonForward;
new Handle:g_hOnTrackerCountChangedForward;
new Handle:g_hOnDrawTargetForward;
new Handle:g_hOnAddToAdminCountForward;



#define SQL_DB_CONF "CallAdmin"



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin.txt"


public Plugin:myinfo = 
{
	name = "CallAdmin",
	author = "Impact, Popoklopsi",
	description = "Call an Admin for help",
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
	
	RegPluginLibrary("calladmin");
	
	
	// Api
	CreateNative("CallAdmin_GetTrackersCount", Native_GetCurrentTrackers);
	CreateNative("CallAdmin_RequestTrackersCountRefresh", Native_RequestTrackersCountRefresh);
	CreateNative("CallAdmin_GetHostName", Native_GetHostName);
	CreateNative("CallAdmin_GetHostIP", Native_GetHostIP);
	CreateNative("CallAdmin_GetHostPort", Native_GetHostPort);
	
	
	return APLRes_Success;
}





public Native_GetCurrentTrackers(Handle:plugin, numParams)
{
	return g_iCurrentTrackers;
}




public Native_RequestTrackersCountRefresh(Handle:plugin, numParams)
{
	GetCurrentTrackers();
}




public Native_GetHostName(Handle:plugin, numParams)
{
	new max_size = GetNativeCell(2);
	SetNativeString(1, g_sServerName, max_size);
}




public Native_GetHostIP(Handle:plugin, numParams)
{
	new max_size = GetNativeCell(2);
	SetNativeString(1, g_sHostIP, max_size);
}



public Native_GetHostPort(Handle:plugin, numParams)
{
	return g_iHostPort;
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
	
	
	g_hHostPort   = FindConVar("hostport");
	g_hHostIP     = FindConVar("hostip");
	g_hServerName = FindConVar("hostname");
	
	// Shouldn't happen
	if(g_hHostPort == INVALID_HANDLE)
	{
		SetFailState("Couldn't find cvar 'hostport'");
	}
	if(g_hHostIP == INVALID_HANDLE)
	{
		SetFailState("Couldn't find cvar 'hostip'");
	}
	if(g_hServerName == INVALID_HANDLE)
	{
		SetFailState("Couldn't find cvar 'hostname'");
	}

	
	RegConsoleCmd("sm_call", Command_Call);
	
	
	AutoExecConfig_SetFile("plugin.calladmin");
	
	g_hVersion                = AutoExecConfig_CreateConVar("sm_calladmin_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hBanReasons             = AutoExecConfig_CreateConVar("sm_calladmin_banreasons", "Aimbot; Wallhack; Speedhack; Spinhack; Multihack; No-Recoil Hack; Other", "Semicolon seperated list of banreasons (24 reasons max, 48 max length per reason)", FCVAR_PLUGIN);
	g_hEntryPruning           = AutoExecConfig_CreateConVar("sm_calladmin_entrypruning", "25", "Entries older than given minutes will be deleted, 0 deactivates the feature", FCVAR_PLUGIN, true, 0.0);
	g_hOhphanedEntryPruning   = AutoExecConfig_CreateConVar("sm_calladmin_entrypruning_ohphaned", "4320", "Entries older than given minutes will be recognized as orphaned and will be deleted globally (serverIP and serverPort won't be checked)", FCVAR_PLUGIN, true, 0.0, true, 0.0);
	g_hAdvertInterval         = AutoExecConfig_CreateConVar("sm_calladmin_advert_interval", "60.0",  "Interval to advert the use of calladmin, 0.0 deactivates the feature", FCVAR_PLUGIN, true, 0.0, true, 1800.0);
	g_hPublicMessage          = AutoExecConfig_CreateConVar("sm_calladmin_public_message", "1",  "Whether or not an report should be notified to all players or only the reporter.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hOwnReason              = AutoExecConfig_CreateConVar("sm_calladmin_own_reason", "1",  "Whether or not client can submit their own reason.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hConfirmCall            = AutoExecConfig_CreateConVar("sm_calladmin_confirm_call", "1",  "Whether or not an call must be confirmed by the client", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hSpamTime               = AutoExecConfig_CreateConVar("sm_calladmin_spamtime", "25", "An user must wait this many seconds after an report before he can issue a new one", FCVAR_PLUGIN, true, 0.0);
	g_hAdminAction            = AutoExecConfig_CreateConVar("sm_calladmin_admin_action", "1", "What happens when admins are ingame on report\n0 - Do nothing, let the report pass, 1 - Block the report and notify the caller and admins", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	
	
	AutoExecConfig(true, "plugin.calladmin");
	AutoExecConfig_CleanFile();
	
	
	LoadTranslations("calladmin.phrases");
	
	
	SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);
	
	GetConVarString(g_hBanReasons, g_sBanReasons, sizeof(g_sBanReasons));
	ExplodeString(g_sBanReasons, ";", g_sBanReasonsExploded, sizeof(g_sBanReasonsExploded), sizeof(g_sBanReasonsExploded[]), true);
	HookConVarChange(g_hBanReasons, OnCvarChanged);
	
	GetConVarString(g_hServerName, g_sServerName, sizeof(g_sServerName));
	HookConVarChange(g_hServerName, OnCvarChanged);
	
	g_iHostPort = GetConVarInt(g_hHostPort);
	HookConVarChange(g_hHostPort, OnCvarChanged);
	
	g_iHostIP = GetConVarInt(g_hHostIP);
	LongToIp(g_iHostIP, g_sHostIP, sizeof(g_sHostIP));
	HookConVarChange(g_hHostIP, OnCvarChanged);
	
	g_iEntryPruning = GetConVarInt(g_hEntryPruning);
	HookConVarChange(g_hEntryPruning, OnCvarChanged);
	
	g_iOhphanedEntryPruning = GetConVarInt(g_hOhphanedEntryPruning);
	HookConVarChange(g_hOhphanedEntryPruning, OnCvarChanged);
	
	g_fAdvertInterval = GetConVarFloat(g_hAdvertInterval);
	HookConVarChange(g_hAdvertInterval, OnCvarChanged);
	
	g_bPublicMessage = GetConVarBool(g_hPublicMessage);
	HookConVarChange(g_hPublicMessage, OnCvarChanged);
	
	g_bOwnReason = GetConVarBool(g_hOwnReason);
	HookConVarChange(g_hOwnReason, OnCvarChanged);
	
	g_bConfirmCall = GetConVarBool(g_hConfirmCall);
	HookConVarChange(g_hConfirmCall, OnCvarChanged);
	
	g_iSpamTime = GetConVarInt(g_hSpamTime);
	HookConVarChange(g_hSpamTime, OnCvarChanged);
	
	g_iAdminAction = GetConVarInt(g_hAdminAction);
	HookConVarChange(g_hAdminAction, OnCvarChanged);
	
	
	if(g_fAdvertInterval != 0.0)
	{
		g_hAdvertTimer = CreateTimer(g_fAdvertInterval, Timer_Advert, _, TIMER_REPEAT);
	}
	
	CreateTimer(600.0, Timer_PruneEntries, _, TIMER_REPEAT);
	CreateTimer(20.0, Timer_UpdateTrackersCount, _, TIMER_REPEAT);
	
	AddCommandListener(ChatListener, "say");
	AddCommandListener(ChatListener, "say_team");
	
	
	// Api
	g_hOnReportPostForward          = CreateGlobalForward("CallAdmin_OnReportPost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
	g_hOnDrawOwnReasonForward       = CreateGlobalForward("CallAdmin_OnDrawOwnReason", ET_Event, Param_Cell);
	g_hOnTrackerCountChangedForward = CreateGlobalForward("CallAdmin_OnTrackerCountChanged", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnDrawTargetForward          = CreateGlobalForward("CallAdmin_OnDrawTarget", ET_Event, Param_Cell, Param_Cell);
	g_hOnAddToAdminCountForward     = CreateGlobalForward("CallAdmin_OnAddToAdminCount", ET_Event, Param_Cell);
}




Forward_OnReportPost(client, target, const String:reasonRaw[], const String:reasonSanitized[])
{
	Call_StartForward(g_hOnReportPostForward);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushString(reasonRaw);
	Call_PushString(reasonSanitized);
	
	Call_Finish();
}



bool:Forward_OnDrawOwnReason(client)
{
	new Action:result;
	
	Call_StartForward(g_hOnDrawOwnReasonForward);
	Call_PushCell(client);
	
	Call_Finish(result);
	
	if(result == Plugin_Continue)
	{
		return true;
	}
	
	return false;
}



bool:Forward_OnAddToAdminCount(client)
{
	new Action:result;
	
	Call_StartForward(g_hOnAddToAdminCountForward);
	Call_PushCell(client);
	
	Call_Finish(result);
	
	if(result == Plugin_Continue)
	{
		return true;
	}
	
	return false;
}



Forward_OnTrackerCountChanged(oldVal, newVal)
{
	Call_StartForward(g_hOnTrackerCountChangedForward);
	Call_PushCell(oldVal);
	Call_PushCell(newVal);
	
	Call_Finish();
}



bool:Forward_OnDrawTarget(client, target)
{
	new Action:result;
	
	Call_StartForward(g_hOnDrawTargetForward);
	Call_PushCell(client);
	Call_PushCell(target);
	
	Call_Finish(result);
	
	if(result == Plugin_Continue)
	{
		return true;
	}
	
	return false;
}




InitDB()
{
	SQL_TConnect(SQLT_ConnectCallback, SQL_CheckConfig(SQL_DB_CONF) ? SQL_DB_CONF : "default");
}




public Action:Timer_Advert(Handle:timer)
{
	if(g_iCurrentTrackers > 0)
	{
		if(g_iCurrentTrackers == 1)
		{
			PrintToChatAll("\x04[CALLADMIN]\x03 %t", "CallAdmin_AdvertMessageSingular", g_iCurrentTrackers);
		}
		else
		{
			PrintToChatAll("\x04[CALLADMIN]\x03 %t", "CallAdmin_AdvertMessagePlural", g_iCurrentTrackers);
		}
	}
	
	return Plugin_Handled;
}




public OnAllPluginsLoaded()
{
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




PruneDatabase()
{
	if(g_hDbHandle != INVALID_HANDLE)
	{
		decl String:query[1024];
		
		// Prune main table (this server)
		Format(query, sizeof(query), "DELETE FROM CallAdmin WHERE serverIP = '%s' AND serverPort = '%d' AND TIMESTAMPDIFF(MINUTE, FROM_UNIXTIME(reportedAt), NOW()) > %d", g_sHostIP, g_iHostPort, g_iEntryPruning);
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
	if(cvar == g_hBanReasons)
	{
		GetConVarString(g_hBanReasons, g_sBanReasons, sizeof(g_sBanReasons));
		ExplodeString(g_sBanReasons, ";", g_sBanReasonsExploded, sizeof(g_sBanReasonsExploded), sizeof(g_sBanReasonsExploded[]), true);
	}
	else if(cvar == g_hHostPort)
	{
		g_iHostPort = GetConVarInt(g_hHostPort);
	}
	else if(cvar == g_hHostIP)
	{
		g_iHostIP = GetConVarInt(g_hHostIP);
		
		LongToIp(g_iHostIP, g_sHostIP, sizeof(g_sHostIP));
	}
	else if(cvar == g_hServerName)
	{
		GetConVarString(g_hServerName, g_sServerName, sizeof(g_sServerName));
		UpdateServerData();
	}
	else if(cvar == g_hEntryPruning)
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
	else if(cvar == g_hAdvertInterval)
	{
		// Close the old timer
		if(g_hAdvertTimer != INVALID_HANDLE)
		{
			CloseHandle(g_hAdvertTimer);
			g_hAdvertTimer = INVALID_HANDLE;
		}
		
		g_fAdvertInterval = GetConVarFloat(g_hAdvertInterval);
		
		if(g_fAdvertInterval != 0.0)
		{
			g_hAdvertTimer = CreateTimer(g_fAdvertInterval, Timer_Advert, _, TIMER_REPEAT);
		}
	}
	else if(cvar == g_hPublicMessage)
	{
		g_bPublicMessage = GetConVarBool(g_hPublicMessage);
	}
	else if(cvar == g_hOwnReason)
	{
		g_bOwnReason = GetConVarBool(g_hOwnReason);
	}
	else if(cvar == g_hConfirmCall)
	{
		g_bConfirmCall = GetConVarBool(g_hConfirmCall);
	}
	else if(cvar == g_hSpamTime)
	{
		g_iSpamTime = GetConVarInt(g_hSpamTime);
	}
	else if(cvar == g_hAdminAction)
	{
		g_iAdminAction = GetConVarInt(g_hAdminAction);
	}
}




public Action:Command_Call(client, args)
{
	if(g_iLastReport[client] == 0 || g_iLastReport[client] <= ( GetTime() - g_iSpamTime ))
	{
		g_bSawMesage[client] = false;
		
		// Oh noes, no trackers, and no admins ingame
		if(g_iCurrentTrackers < 1 && GetAdminCount() < 1)
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoTrackers");
			g_bAwaitingAdmin[client] = true;
			g_iLastReport[client] = GetTime();
			
			return Plugin_Handled;
		}
		
		ShowClientSelectMenu(client);
	}
	else if(!g_bSawMesage[client])
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_CommandNotAllowed", g_iSpamTime - ( GetTime() - g_iLastReport[client] ));
		g_bSawMesage[client] = true;
	}

	return Plugin_Handled;
}



ConfirmCall(client)
{
	new Handle:menu = CreateMenu(MenuHandler_ConfirmCall);
	SetMenuTitle(menu, "%T", "CallAdmin_ConfirmCall", client);
	
	decl String:sConfirm[24];
	
	Format(sConfirm, sizeof(sConfirm), "%T", "CallAdmin_Yes", client);
	AddMenuItem(menu, "Yes", sConfirm);
	
	Format(sConfirm, sizeof(sConfirm), "%T", "CallAdmin_No", client);
	AddMenuItem(menu, "No", sConfirm);
	
	DisplayMenu(menu, client, 30);
}



public MenuHandler_ConfirmCall(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		new String:sInfo[24];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		// Yup
		if(StrEqual("Yes", sInfo))
		{
			if(IsClientValid(g_iTarget[client]))
			{
				// Already reported (race condition)
				if(g_bWasReported[g_iTarget[client]])
				{
					PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
					
					return;					
				}
				
				// Admins available and we want to notify them instead of send the report
				if(GetAdminCount() > 0 && g_iAdminAction == ADMIN_ACTION_BLOCK_MESSAGE)
				{
					PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_IngameAdminNotified");
					PrintNotifyMessageToAdmins(client, g_iTarget[client]);
					
					// States
					g_iLastReport[client]   = GetTime();
					g_bWasReported[g_iTarget[client]]  = true;
					
					return;
				}
				
				// Send the report
				ReportPlayer(client, g_iTarget[client]);
			}
			else
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
			}
		}
		else
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_CallAborted");
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}




ReportPlayer(client, target)
{
	new String:clientNameBuf[MAX_NAME_LENGTH];
	new String:clientName[(MAX_NAME_LENGTH + 1) * 2];
	new String:clientAuth[21];
	
	new String:targetNameBuf[MAX_NAME_LENGTH];
	new String:targetName[(MAX_NAME_LENGTH + 1) * 2];
	new String:targetAuth[21];
	
	new String:sReason[(48 + 1) * 2];
	SQL_EscapeString(g_hDbHandle, g_sTargetReason[client], sReason, sizeof(sReason));
	
	
	GetClientName(client, clientNameBuf, sizeof(clientNameBuf));
	SQL_EscapeString(g_hDbHandle, clientNameBuf, clientName, sizeof(clientName));
	GetClientAuthString(client, clientAuth, sizeof(clientAuth));
	
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
	
	
	if(g_bPublicMessage)
	{
		PrintToChatAll("\x04[CALLADMIN]\x03 %t", "CallAdmin_HasReported", clientNameBuf, targetNameBuf, g_sTargetReason[client]);
	}
	else
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_YouHaveReported", targetNameBuf, g_sTargetReason[client]);
	}
	
	// States
	g_iLastReport[client]   = GetTime();
	g_bWasReported[target]  = true;
	
	
	// Call the forward
	Forward_OnReportPost(client, target, g_sTargetReason[client], sReason);
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
														
		// Create tracker Table
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
	if(GetRealClientCount() > 0)
	{
		GetCurrentTrackers();
	}
	
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
			new temp = g_iCurrentTrackers;
			
			g_iCurrentTrackers = SQL_FetchInt(hndl, 0);
			
			
			// Call the forward
			if(temp != g_iCurrentTrackers)
			{
				Forward_OnTrackerCountChanged(temp, g_iCurrentTrackers);
			}
			
			
			// Notify the waiters
			if(g_iCurrentTrackers > 0)
			{
				NotifyAdminAwaiters();
			}
		}
	}
}




ShowClientSelectMenu(client)
{
	decl String:sName[MAX_NAME_LENGTH];
	decl String:sID[24];
	
	new Handle:menu = CreateMenu(MenuHandler_ClientSelect);
	SetMenuTitle(menu, "%T", "CallAdmin_SelectClient", client);
	
	for(new i; i <= MaxClients; i++)
	{
		if(i != client && !g_bWasReported[i] && IsClientValid(i) && IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && Forward_OnDrawTarget(client, i))
		{
			GetClientName(i, sName, sizeof(sName));
			Format(sID, sizeof(sID), "%d", GetClientSerial(i));
			
			AddMenuItem(menu, sID, sName);
		}
	}
	
	if(GetMenuItemCount(menu) < 1)
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoPlayers");
		g_iLastReport[client] = GetTime();
	}
	else
	{
		DisplayMenu(menu, client, 30);
	}
}




public MenuHandler_ClientSelect(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		new String:sInfo[24];
		new iSerial;
		new iID;
		
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		iSerial = StringToInt(sInfo);
		iID     = GetClientFromSerial(iSerial);
		
		
		if(IsClientValid(iID))
		{
			g_iTarget[client] = iID;
			
			// Already reported (race condition)
			if(g_bWasReported[g_iTarget[client]])
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
				
				return;					
			}
			
			ShowBanreasonMenu(client);
		}
		else
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}




public OnClientDisconnect_Post(client)
{
	g_iTarget[client]          = 0;
	g_sTargetReason[client][0] = '\0';
	g_iLastReport[client]      = 0;
	g_bWasReported[client]     = false;
	g_bSawMesage[client]       = false;
	g_bAwaitingReason[client]  = false;
	g_bAwaitingAdmin[client]   = false;
	
	RemoveAsTarget(client);
}




RemoveAsTarget(client)
{
	for(new i; i <= MaxClients; i++)
	{
		if(g_iTarget[i] == client)
		{
			g_iTarget[i] = 0;
		}
	}
}




ShowBanreasonMenu(client)
{
	new count;
	
	count = sizeof(g_sBanReasonsExploded);

	
	new Handle:menu = CreateMenu(MenuHandler_BanReason);
	SetMenuTitle(menu, "%T", "CallAdmin_SelectReason", client, g_iTarget[client]);
	
	new index;
	for(new i; i < count; i++)
	{
		if(strlen(g_sBanReasonsExploded[i]) < 3)
		{
			continue;
		}
		
		index = 0;
		if(g_sBanReasonsExploded[i][0] == ' ')
		{
			index = 1;
		}
		
		AddMenuItem(menu, g_sBanReasonsExploded[i][index], g_sBanReasonsExploded[i][index]);
	}
	
	// Own reason, call the forward
	if(g_bOwnReason && Forward_OnDrawOwnReason(client))
	{
		decl String:sOwnReason[48];

		Format(sOwnReason, sizeof(sOwnReason), "%T", "CallAdmin_OwnReason", client);
		AddMenuItem(menu, "Own reason", sOwnReason);
	}
	
	DisplayMenu(menu, client, 30);
}




public MenuHandler_BanReason(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		new String:sInfo[48];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		// Own reason
		if(StrEqual("Own reason", sInfo))
		{
			g_bAwaitingReason[client] = true;
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_TypeOwnReason");
			return;
		}
		
		Format(g_sTargetReason[client], sizeof(g_sTargetReason[]), sInfo);
		
		
		if(IsClientValid(g_iTarget[client]))
		{
			// Already reported (race condition)
			if(g_bWasReported[g_iTarget[client]])
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
				
				return;					
			}
				
			// Send the report
			if(g_bConfirmCall)
			{
				ConfirmCall(client);
			}
			else
			{
				// Already reported (race condition)
				if(g_bWasReported[g_iTarget[client]])
				{
					PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
					
					return;					
				}
				
				// Admins available and we want to notify them instead of send the report
				if(GetAdminCount() > 0 && g_iAdminAction == ADMIN_ACTION_BLOCK_MESSAGE)
				{
					PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_IngameAdminNotified");
					PrintNotifyMessageToAdmins(client, g_iTarget[client]);
					
					// States
					g_iLastReport[client]   = GetTime();
					g_bWasReported[g_iTarget[client]]  = true;
					
					return;
				}
				
				ReportPlayer(client, g_iTarget[client]);
			}			
		}
		else
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}




public Action:ChatListener(client, const String:command[], argc)
{
	if(g_bAwaitingReason[client] && !IsChatTrigger())
	{
		// 2 more for quotes
		decl String:sReason[50];
		
		GetCmdArgString(sReason, sizeof(sReason));
		StripQuotes(sReason);
		strcopy(g_sTargetReason[client], sizeof(g_sTargetReason[]), sReason);
		
		g_bAwaitingReason[client] = false;
		
		
		// Has aborted
		if(StrEqual(sReason, "!noreason") || StrEqual(sReason, "!abort"))
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_CallAborted");
			
			return Plugin_Handled;
		}
		
		
		// Õ_Õ
		if(strlen(sReason) < 3)
		{
			g_bAwaitingReason[client] = true;
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_OwnReasonTooShort");
			
			return Plugin_Handled;
		}
		
		
		if(IsClientValid(g_iTarget[client]))
		{
			// Send the report
			if(g_bConfirmCall)
			{
				ConfirmCall(client);
			}
			else
			{
				// Admins available and we want to notify them instead of send the report
				if(GetAdminCount() > 0 && g_iAdminAction == ADMIN_ACTION_BLOCK_MESSAGE)
				{
					PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_IngameAdminNotified");
					PrintNotifyMessageToAdmins(client, g_iTarget[client]);
					
					// States
					g_iLastReport[client]   = GetTime();
					g_bWasReported[g_iTarget[client]]  = true;
					
					return Plugin_Handled;
				}
				
				ReportPlayer(client, g_iTarget[client]);
			}
		}
		else
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
		}
		
		
		// Block the chatmessage
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}




NotifyAdminAwaiters()
{
	for(new i; i <= MaxClients; i++)
	{
		if(IsClientValid(i) && g_bAwaitingAdmin[i])
		{
			PrintToChat(i, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AdminsAvailable");
			g_bAwaitingAdmin[i] = false;
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



stock GetRealClientCount()
{
	new count;
	
	for(new i; i <= MaxClients; i++)
	{
		if(IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i))
		{
			count++;
		}
	}
	
	return count;
}



stock GetAdminCount()
{
	new count;
	
	for(new i; i <= MaxClients; i++)
	{
		if(IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && CheckCommandAccess(i, "sm_calladmin_admin", ADMFLAG_BAN, false) && Forward_OnAddToAdminCount(i)) 
		{
			count++;
		}
	}
	
	return count;
}


stock PrintNotifyMessageToAdmins(client, target)
{
	for(new i; i <= MaxClients; i++)
	{
		if(IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && CheckCommandAccess(i, "sm_calladmin_admin", ADMFLAG_BAN, false) && Forward_OnAddToAdminCount(i)) 
		{
			PrintToChat(i, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AdminNotification", client, target, g_sTargetReason[client]);
		}
	}	
}



stock LongToIp(long, String:str[], maxlen)
{
	new pieces[4];
	
	pieces[0] = (long >>> 24 & 255);
	pieces[1] = (long >>> 16 & 255);
	pieces[2] = (long >>> 8 & 255);
	pieces[3] = (long & 255); 
	
	Format(str, maxlen, "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]); 
}