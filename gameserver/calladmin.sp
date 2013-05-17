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
#include <clientprefs>
#pragma semicolon 1


#define CLIENTPREFS_AVAILABLE()      (LibraryExists("clientprefs"))



// Banreasons
new Handle:g_hBanReasons;
new String:g_sBanReasons[1200];
new String:g_sBanReasonsExploded[24][48];


// Global Stuff
new Handle:g_hServerName;
new String:g_sServerName[64];

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

new Handle:g_hReportTime;
new g_iReportTime;

new Handle:g_hAdminAction;
new g_iAdminAction;


#define ADMIN_ACTION_PASS          0
#define ADMIN_ACTION_BLOCK_MESSAGE 1


new bool:g_bLateLoad;
#pragma unused g_bLateLoad


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

// When was this user reported the last time?
new g_iLastReported[MAXPLAYERS +1];

// Player saw the antispam message
new bool:g_bSawMesage[MAXPLAYERS +1];


// Cookies, yummy
new Handle:g_hLastReportCookie;
new Handle:g_hLastReportedCookie;


// Api
new Handle:g_hOnReportPostForward;
new Handle:g_hOnDrawOwnReasonForward;
new Handle:g_hOnTrackerCountChangedForward;
new Handle:g_hOnDrawTargetForward;
new Handle:g_hOnAddToAdminCountForward;
new Handle:g_hOnServerDataChangedForward;




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
		
	RegPluginLibrary("calladmin");
	
	
	// Api
	CreateNative("CallAdmin_GetTrackersCount", Native_GetCurrentTrackers);
	CreateNative("CallAdmin_RequestTrackersCountRefresh", Native_RequestTrackersCountRefresh);
	CreateNative("CallAdmin_GetHostName", Native_GetHostName);
	CreateNative("CallAdmin_GetHostIP", Native_GetHostIP);
	CreateNative("CallAdmin_GetHostPort", Native_GetHostPort);
	CreateNative("CallAdmin_ReportClient", Native_ReportClient);
	
	
	return APLRes_Success;
}





public Native_GetCurrentTrackers(Handle:plugin, numParams)
{
	return g_iCurrentTrackers;
}




public Native_RequestTrackersCountRefresh(Handle:plugin, numParams)
{
	// Fire the internal update
	Timer_UpdateTrackersCount(INVALID_HANDLE);
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




public Native_ReportClient(Handle:plugin, numParams)
{
	new client;
	new target;
	new String:sReason[48];
	
	client = GetNativeCell(1);
	target = GetNativeCell(2);
	GetNativeString(3, sReason, sizeof(sReason));
	
	// We check for the REPORTER_CONSOLE define here, if this is set we have no valid client and the report comes from server
	if(!IsClientValid(client) && client != REPORTER_CONSOLE)
	{
		return false;
	}
	
	if(!IsClientValid(target))
	{
		return false;
	}


	// Call the forward
	Forward_OnReportPost(client, target, sReason);
	
	return true;
}






public OnPluginStart()
{
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
	RegConsoleCmd("sm_calladmin", Command_Call);
	
	
	AutoExecConfig_SetFile("plugin.calladmin");
	
	g_hVersion                = AutoExecConfig_CreateConVar("sm_calladmin_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hBanReasons             = AutoExecConfig_CreateConVar("sm_calladmin_banreasons", "Aimbot; Wallhack; Speedhack; Spinhack; Multihack; No-Recoil Hack; Other", "Semicolon seperated list of banreasons (24 reasons max, 48 max length per reason)", FCVAR_PLUGIN);
	g_hAdvertInterval         = AutoExecConfig_CreateConVar("sm_calladmin_advert_interval", "60.0",  "Interval to advert the use of calladmin, 0.0 deactivates the feature", FCVAR_PLUGIN, true, 0.0, true, 1800.0);
	g_hPublicMessage          = AutoExecConfig_CreateConVar("sm_calladmin_public_message", "1",  "Whether or not an report should be notified to all players or only the reporter.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hOwnReason              = AutoExecConfig_CreateConVar("sm_calladmin_own_reason", "1",  "Whether or not client can submit their own reason.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hConfirmCall            = AutoExecConfig_CreateConVar("sm_calladmin_confirm_call", "1",  "Whether or not an call must be confirmed by the client", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hSpamTime               = AutoExecConfig_CreateConVar("sm_calladmin_spamtime", "25", "An user must wait this many seconds after an report before he can issue a new one", FCVAR_PLUGIN, true, 0.0);
	g_hReportTime             = AutoExecConfig_CreateConVar("sm_calladmin_reporttime", "300", "An user cannot be reported again for this many seconds", FCVAR_PLUGIN, true, 0.0);
	g_hAdminAction            = AutoExecConfig_CreateConVar("sm_calladmin_admin_action", "0", "What happens when admins are ingame on report: 0 - Do nothing, let the report pass, 1 - Block the report and notify the caller and admins", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	
	
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
	
	g_iReportTime = GetConVarInt(g_hReportTime);
	HookConVarChange(g_hReportTime, OnCvarChanged);
	
	g_iAdminAction = GetConVarInt(g_hAdminAction);
	HookConVarChange(g_hAdminAction, OnCvarChanged);
	
	
	// We only create a timer if interval > 0.0
	if(g_fAdvertInterval != 0.0)
	{
		g_hAdvertTimer = CreateTimer(g_fAdvertInterval, Timer_Advert, _, TIMER_REPEAT);
	}

	
	// Modules must create their own updaters
	CreateTimer(10.0, Timer_UpdateTrackersCount, _, TIMER_REPEAT);
	
	// Used for the own reason
	AddCommandListener(ChatListener, "say");
	AddCommandListener(ChatListener, "say_team");
	
	
	// Api
	g_hOnReportPostForward          = CreateGlobalForward("CallAdmin_OnReportPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_hOnDrawOwnReasonForward       = CreateGlobalForward("CallAdmin_OnDrawOwnReason", ET_Event, Param_Cell);
	g_hOnTrackerCountChangedForward = CreateGlobalForward("CallAdmin_OnTrackerCountChanged", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnDrawTargetForward          = CreateGlobalForward("CallAdmin_OnDrawTarget", ET_Event, Param_Cell, Param_Cell);
	g_hOnAddToAdminCountForward     = CreateGlobalForward("CallAdmin_OnAddToAdminCount", ET_Event, Param_Cell);
	g_hOnServerDataChangedForward   = CreateGlobalForward("CallAdmin_OnServerDataChanged", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
	
	
	// Cookeys
	if(CLIENTPREFS_AVAILABLE())
	{
		g_hLastReportCookie   = RegClientCookie("CallAdmin_LastReport", "Contains a timestamp when this user has reported the last time", CookieAccess_Private);
		g_hLastReportedCookie = RegClientCookie("CallAdmin_LastReported", "Contains a timestamp when this user was reported the last time", CookieAccess_Private);
		
		FetchClientCookies();
	}
}




public OnClientCookiesCached(client)
{
	new String:sCookieBuf[24];
	GetClientCookie(client, g_hLastReportCookie, sCookieBuf, sizeof(sCookieBuf));
	
	if(strlen(sCookieBuf) > 0)
	{
		g_iLastReport[client] = StringToInt(sCookieBuf);
	}
	
	
	// Just to be safe
	sCookieBuf[0] = '\0';
	
	GetClientCookie(client, g_hLastReportedCookie, sCookieBuf, sizeof(sCookieBuf));
	
	if(strlen(sCookieBuf) > 0)
	{
		g_iLastReported[client] = StringToInt(sCookieBuf);
	}
}




FetchClientCookies()
{
	for(new i; i <= MaxClients; i++)
	{
		if(IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}




Forward_OnReportPost(client, target, const String:reason[])
{
	Call_StartForward(g_hOnReportPostForward);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushString(reason);
	
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



Forward_OnServerDataChanged(Handle:convar, ServerData:type, const String:oldVal[], const String:newVal[])
{
	Call_StartForward(g_hOnServerDataChangedForward);
	Call_PushCell(convar);
	Call_PushCell(type);
	Call_PushString(oldVal);
	Call_PushString(newVal);
	
	Call_Finish();
}




public Action:Timer_Advert(Handle:timer)
{
	if(g_iCurrentTrackers > 0)
	{
		// Spelling is different (0 admins, 1 admin, 2 admins, 3 admins...), we account for that :)
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
		
		// Call forward
		Forward_OnServerDataChanged(cvar, ServerData_HostPort, oldValue, newValue);
	}
	else if(cvar == g_hHostIP)
	{
		g_iHostIP = GetConVarInt(g_hHostIP);
		
		LongToIp(g_iHostIP, g_sHostIP, sizeof(g_sHostIP));
		
		// Call forward
		Forward_OnServerDataChanged(cvar, ServerData_HostIP, g_sHostIP, g_sHostIP);
	}
	else if(cvar == g_hServerName)
	{
		GetConVarString(g_hServerName, g_sServerName, sizeof(g_sServerName));
		
		// Call forward
		Forward_OnServerDataChanged(cvar, ServerData_HostName, oldValue, newValue);
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
	else if(cvar == g_hReportTime)
	{
		g_iReportTime = GetConVarInt(g_hReportTime);
	}
	else if(cvar == g_hAdminAction)
	{
		g_iAdminAction = GetConVarInt(g_hAdminAction);
	}
}




public Action:Command_Call(client, args)
{
	if(g_iLastReport[client] == 0 || LastReportTimeCheck(client))
	{
		g_bSawMesage[client] = false;
		
		ShowClientSelectMenu(client);
	}
	else if(!g_bSawMesage[client])
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_CommandNotAllowed", g_iSpamTime - ( GetTime() - g_iLastReport[client] ));
		g_bSawMesage[client] = true;
	}

	return Plugin_Handled;
}



bool:LastReportTimeCheck(client)
{
	if(g_iLastReport[client] <= ( GetTime() - g_iSpamTime ))
	{
		return true;
	}
	
	return false;
}



bool:LastReportedTimeCheck(client)
{
	if(g_iLastReported[client] <= ( GetTime() - g_iReportTime ))
	{
		return true;
	}
	
	return false;
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
		
		// Client has chosen to confirm the call
		if(StrEqual("Yes", sInfo))
		{
			// Selected target isn't valid anymore
			if(!IsClientValid(g_iTarget[client]))
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
				
				return;
			}
			
			
			// Already reported (race condition)
			if(!LastReportedTimeCheck(g_iTarget[client]) )
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
				
				return;					
			}
			
			
			// Admins available and we want to notify them instead of sending the report
			if(GetAdminCount() > 0 && g_iAdminAction == ADMIN_ACTION_BLOCK_MESSAGE)
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_IngameAdminNotified");
				PrintNotifyMessageToAdmins(client, g_iTarget[client]);
				
				// States
				g_iLastReport[client]               = GetTime();
				g_iLastReported[g_iTarget[client]]  = GetTime();
				
				if(CLIENTPREFS_AVAILABLE())
				{
					SetClientCookieEx(client, g_hLastReportCookie, "%d", GetTime());
					SetClientCookieEx(g_iTarget[client], g_hLastReportedCookie, "%d", GetTime());
				}
				
				return;
			}
			
			// Send the report
			ReportPlayer(client, g_iTarget[client], g_sTargetReason[client]);
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




ReportPlayer(client, target, String:sReason[])
{
	new String:clientNameBuf[MAX_NAME_LENGTH];
	new String:targetNameBuf[MAX_NAME_LENGTH];

	GetClientName(client, clientNameBuf, sizeof(clientNameBuf));
	GetClientName(target, targetNameBuf, sizeof(targetNameBuf));

	if(g_bPublicMessage)
	{
		PrintToChatAll("\x04[CALLADMIN]\x03 %t", "CallAdmin_HasReported", clientNameBuf, targetNameBuf, sReason);
	}
	else
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_YouHaveReported", targetNameBuf, sReason);
	}
	
	// States
	g_iLastReport[client]   = GetTime();
	g_iLastReported[target] = GetTime();
	
	if(CLIENTPREFS_AVAILABLE())
	{
		SetClientCookieEx(client, g_hLastReportCookie, "%d", GetTime());
		SetClientCookieEx(target, g_hLastReportedCookie, "%d", GetTime());
	}
	
	// Call the forward
	Forward_OnReportPost(client, target, sReason);
}








public Action:Timer_UpdateTrackersCount(Handle:timer)
{
	// Get current trackers
	new temp = GetTotalTrackers();
	
	// Call the forward
	if(temp != g_iCurrentTrackers)
	{
		Forward_OnTrackerCountChanged(temp, g_iCurrentTrackers);
	}
	
	// set the new count
	g_iCurrentTrackers = temp;
	
	return Plugin_Continue;
}




GetTotalTrackers()
{
	new Handle:hIter;
	new Handle:hPlugin;
	new Function:func;
	new count;
	new tempcount;
	
	hIter = GetPluginIterator();
	
	while(MorePlugins(hIter))
	{
		hPlugin = ReadPlugin(hIter);
		
		if(GetPluginStatus(hPlugin) == Plugin_Running)
		{
			// We check if the plugin has the pesudo forward
			if( (func = GetFunctionByName(hPlugin, "CallAdmin_OnRequestTrackersCountRefresh") ) != INVALID_FUNCTION)
			{
				Call_StartFunction(hPlugin, func);
				Call_PushCellRef(tempcount);
				
				Call_Finish();
				
				if(tempcount > 0)
				{
					count += tempcount;
				}
			}
		}
	}
	
	CloseHandle(hIter);
		
	return count;
}




ShowClientSelectMenu(client)
{
	decl String:sName[MAX_NAME_LENGTH];
	decl String:sID[24];
	
	new Handle:menu = CreateMenu(MenuHandler_ClientSelect);
	SetMenuTitle(menu, "%T", "CallAdmin_SelectClient", client);
	
	for(new i; i <= MaxClients; i++)
	{
		if(i != client && LastReportedTimeCheck(i) && IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && Forward_OnDrawTarget(client, i))
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
		
		if(CLIENTPREFS_AVAILABLE())
		{
			SetClientCookieEx(client, g_hLastReportCookie, "%d", GetTime());
		}
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
		
		
		// Selected target isn't valid anymore
		if(!IsClientValid(iID))
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
			
			return;
		}
		
		
		g_iTarget[client] = iID;
		
		// Already reported (race condition)
		if(!LastReportedTimeCheck(g_iTarget[client]) )
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
			
			return;					
		}
		
		ShowBanreasonMenu(client);
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
	g_iLastReported[client]    = 0;
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
		
		
		// Selected target isn't valid anymore
		if(!IsClientValid(g_iTarget[client]))
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
			
			return;
		}
		
		
		// Already reported (race condition)
		if(!LastReportedTimeCheck(g_iTarget[client]) )
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
			
			return;					
		}
		
			
		// Confirm the report
		if(g_bConfirmCall)
		{
			ConfirmCall(client);
		}
		else
		{
			// Admins available and we want to notify them instead of sending the report
			if(GetAdminCount() > 0 && g_iAdminAction == ADMIN_ACTION_BLOCK_MESSAGE)
			{
				PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_IngameAdminNotified");
				PrintNotifyMessageToAdmins(client, g_iTarget[client]);
				
				// States
				g_iLastReport[client]               = GetTime();
				g_iLastReported[g_iTarget[client]]  = GetTime();
				
				if(CLIENTPREFS_AVAILABLE())
				{
					SetClientCookieEx(client, g_hLastReportCookie, "%d", GetTime());
					SetClientCookieEx(g_iTarget[client], g_hLastReportedCookie, "%d", GetTime());
				}
				
				return;
			}
			
			ReportPlayer(client, g_iTarget[client], g_sTargetReason[client]);
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
		
		
		// Reason was too short
		if(strlen(sReason) < 3)
		{
			g_bAwaitingReason[client] = true;
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_OwnReasonTooShort");
			
			return Plugin_Handled;
		}
		
		
		// Selected target isn't valid anymore
		if(!IsClientValid(g_iTarget[client]))
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
			
			return Plugin_Handled;
		}
		
		
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
				g_iLastReport[client]               = GetTime();
				g_iLastReported[g_iTarget[client]]  = GetTime();
				
				if(CLIENTPREFS_AVAILABLE())
				{
					SetClientCookieEx(client, g_hLastReportCookie, "%d", GetTime());
					SetClientCookieEx(g_iTarget[client], g_hLastReportedCookie, "%d", GetTime());
				}
				
				return Plugin_Handled;
			}
			
			ReportPlayer(client, g_iTarget[client], g_sTargetReason[client]);
		}
		
		
		// Block the chatmessage
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
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



// Gnah, this should be the default behavior
stock SetClientCookieEx(client, Handle:cookie, const String:format[], any:...)
{
	decl String:sFormatBuf[1024];
	VFormat(sFormatBuf, sizeof(sFormatBuf), format, 4);
	
	SetClientCookie(client, cookie, sFormatBuf);
}