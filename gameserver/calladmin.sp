/**
 * -----------------------------------------------------
 * File        calladmin.sp
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
#include "include/calladmin_stocks"

#undef REQUIRE_PLUGIN
#include "include/updater"
#include <clientprefs>
#pragma semicolon 1
#pragma newdecls required



// Banreasons
ArrayList g_hReasonAdt;
char g_sReasonConfigFile[PLATFORM_MAX_PATH];


// Global Stuff
ConVar g_hServerName;
char g_sServerName[64];

ConVar g_hVersion;

ConVar g_hHostPort;
int g_iHostPort;

ConVar g_hHostIP;
char g_sHostIP[16];

Handle g_hAdvertTimer;
ConVar g_hAdvertInterval;
float g_fAdvertInterval;

ConVar g_hPublicMessage;
bool g_bPublicMessage;

ConVar g_hOwnReason;
bool g_bOwnReason;

ConVar g_hConfirmCall;
bool g_bConfirmCall;

ConVar g_hSpamTime;
int g_iSpamTime;

ConVar g_hReportTime;
int g_iReportTime;

ConVar g_hAdminAction;
int g_iAdminAction;



// Report id used for handling
int g_iCurrentReportID;

// List of not handled IDs
ArrayList g_hActiveReports;



// Log file
char g_sLogFile[PLATFORM_MAX_PATH];


#define ADMIN_ACTION_PASS                       0
#define ADMIN_ACTION_BLOCK_NOTIFY               1
#define ADMIN_ACTION_PASS_NOTIFY                2


int g_iCurrentTrackers;



// Current target info
g_iTarget[MAXPLAYERS + 1];
char g_sTargetReason[MAXPLAYERS + 1][REASON_MAX_LENGTH];

// Is this player writing his own reason?
bool g_bAwaitingReason[MAXPLAYERS +1];

// When has this user reported the last time
g_iLastReport[MAXPLAYERS +1];

// When was this user reported the last time?
g_iLastReported[MAXPLAYERS +1];

// Whether or not a client saw the antispam message
bool g_bSawMessage[MAXPLAYERS +1];


// Cookies
Handle g_hLastReportCookie;
Handle g_hLastReportedCookie;


// Api
Handle g_hOnReportPreForward;
Handle g_hOnReportPostForward;
Handle g_hOnDrawMenuForward;
Handle g_hOnDrawOwnReasonForward;
Handle g_hOnTrackerCountChangedForward;
Handle g_hOnDrawTargetForward;
Handle g_hOnAddToAdminCountForward;
Handle g_hOnServerDataChangedForward;
Handle g_hOnLogMessageForward;
Handle g_hOnReportHandledForward;




// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin.txt"


public Plugin myinfo = 
{
	name = "CallAdmin",
	author = "Impact, dordnung",
	description = "Call an Admin for help",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}



public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("calladmin");
	
	
	// This needs to be done this early because we want modules to be able to use CallAdmin_LogMessage inside OnPluginStart
	// Modules should be loaded after the plugin because they depend on it and this shouldn't be an issue, but oddly it is
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/calladmin.log");
	
	
	// Api
	CreateNative("CallAdmin_GetTrackersCount", Native_GetCurrentTrackers);
	CreateNative("CallAdmin_RequestTrackersCountRefresh", Native_RequestTrackersCountRefresh);
	CreateNative("CallAdmin_GetHostName", Native_GetHostName);
	CreateNative("CallAdmin_GetHostIP", Native_GetHostIP);
	CreateNative("CallAdmin_GetHostPort", Native_GetHostPort);
	CreateNative("CallAdmin_ReportClient", Native_ReportClient);
	CreateNative("CallAdmin_LogMessage", Native_LogMessage);
	CreateNative("CallAdmin_GetReportID", Native_GetReportID);
	
	
	return APLRes_Success;
}





public int Native_GetCurrentTrackers(Handle plugin, int numParams)
{
	return g_iCurrentTrackers;
}




public int Native_RequestTrackersCountRefresh(Handle plugin, int numParams)
{
	Timer_UpdateTrackersCount(null);
}




public int Native_GetHostName(Handle plugin, int numParams)
{
	int max_size = GetNativeCell(2);
	SetNativeString(1, g_sServerName, max_size);
}




public int Native_GetHostIP(Handle plugin, int numParams)
{
	int max_size = GetNativeCell(2);
	SetNativeString(1, g_sHostIP, max_size);
}




public int Native_GetHostPort(Handle plugin, int numParams)
{
	return g_iHostPort;
}




public int Native_ReportClient(Handle plugin, int numParams)
{
	int client;
	int target;
	char sReason[REASON_MAX_LENGTH];
	
	client = GetNativeCell(1);
	target = GetNativeCell(2);
	GetNativeString(3, sReason, sizeof(sReason));
	
	
	// We check for the REPORTER_CONSOLE define here, if this is set we have no valid client and the report comes from server
	if (!IsClientValid(client) && client != REPORTER_CONSOLE)
	{
		return false;
	}
	
	if (!IsClientValid(target))
	{
		return false;
	}
	
	if (!Forward_OnReportPre(client, target, sReason))
	{
		return false;
	}

	g_iCurrentReportID++;
	g_hActiveReports.Push(g_iCurrentReportID);

	Forward_OnReportPost(client, target, sReason);

	return true;
}




public int Native_LogMessage(Handle plugin, int numParams)
{
	char sPluginName[64];
	char sMessage[2048];
	GetPluginInfo(plugin, PlInfo_Name, sPluginName, sizeof(sPluginName));
	
	FormatNativeString(0, 1, 2, sizeof(sMessage), _, sMessage);
	
	LogToFileEx(g_sLogFile, "[%s] %s", sPluginName, sMessage);
	
	Forward_OnLogMessage(plugin, sMessage);
}




public int Native_GetReportID(Handle plugin, int numParams)
{
	return g_iCurrentReportID;
}




public void OnConfigsExecuted()
{
	g_iHostPort = g_hHostPort.IntValue;
	UpdateHostIp();
	
	g_hServerName.GetString(g_sServerName, sizeof(g_sServerName));
	g_bPublicMessage = g_hPublicMessage.BoolValue;
	g_bOwnReason = g_hOwnReason.BoolValue;
	g_bConfirmCall = g_hConfirmCall.BoolValue;
	g_iSpamTime = g_hSpamTime.IntValue;
	g_iReportTime = g_hReportTime.IntValue;
	g_iAdminAction = g_hAdminAction.IntValue;
	
	g_fAdvertInterval = g_hAdvertInterval.FloatValue;
	
	delete g_hAdvertTimer;
	
	if (g_fAdvertInterval != 0.0)
	{
		g_hAdvertTimer = CreateTimer(g_fAdvertInterval, Timer_Advert, _, TIMER_REPEAT);
	}
}




public void OnPluginStart()
{
	g_hHostPort   = FindConVar("hostport");
	g_hHostIP     = FindConVar("hostip");
	g_hServerName = FindConVar("hostname");
	
	
	if (g_hHostPort == null)
	{
		CallAdmin_LogMessage("Couldn't find cvar 'hostport'");
		SetFailState("Couldn't find cvar 'hostport'");
	}
	
	if (g_hHostIP == null)
	{
		CallAdmin_LogMessage("Couldn't find cvar 'hostip'");
		SetFailState("Couldn't find cvar 'hostip'");
	}
	
	if (g_hServerName == null)
	{
		CallAdmin_LogMessage("Couldn't find cvar 'hostname'");
		SetFailState("Couldn't find cvar 'hostname'");
	}

	
	RegConsoleCmd("sm_call", Command_Call);
	RegConsoleCmd("sm_calladmin", Command_Call);
	
	RegConsoleCmd("sm_call_handle", Command_HandleCall);
	RegConsoleCmd("sm_calladmin_handle", Command_HandleCall);
	
	RegConsoleCmd("sm_calladmin_reload", Command_Reload);
	
	
	AutoExecConfig_SetFile("plugin.calladmin");
	
	g_hVersion                = AutoExecConfig_CreateConVar("sm_calladmin_version", CALLADMIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hAdvertInterval         = AutoExecConfig_CreateConVar("sm_calladmin_advert_interval", "60.0",  "Interval to advert the use of calladmin, 0.0 deactivates the feature", FCVAR_NONE, true, 0.0, true, 1800.0);
	g_hPublicMessage          = AutoExecConfig_CreateConVar("sm_calladmin_public_message", "1",  "Whether or not a report should be notified to all players or only the reporter.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hOwnReason              = AutoExecConfig_CreateConVar("sm_calladmin_own_reason", "1",  "Whether or not a client can submit their own reason.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hConfirmCall            = AutoExecConfig_CreateConVar("sm_calladmin_confirm_call", "1",  "Whether or not a call must be confirmed by the client", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hSpamTime               = AutoExecConfig_CreateConVar("sm_calladmin_spamtime", "25", "An user must wait this many seconds after a report before he can issue a new one", FCVAR_NONE, true, 0.0);
	g_hReportTime             = AutoExecConfig_CreateConVar("sm_calladmin_reporttime", "300", "An user cannot be reported again for this many seconds", FCVAR_NONE, true, 0.0);
	g_hAdminAction            = AutoExecConfig_CreateConVar("sm_calladmin_admin_action", "0", "What happens when admins are in-game on report: 0 - Let the report pass, 1 - Block the report and notify the caller and admins in-game about it, 2 - Let the report pass and notify the caller and admins in-game about it", FCVAR_NONE, true, 0.0, true, 2.0);

	
	
	AutoExecConfig(true, "plugin.calladmin");
	AutoExecConfig_CleanFile();
	
	
	LoadTranslations("calladmin.phrases");
	
	// This is done so that when the plugin is updated its version stays up to date too
	g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	g_hVersion.AddChangeHook(OnCvarChanged);
	
	
	g_hServerName.AddChangeHook(OnCvarChanged);
	g_hHostPort.AddChangeHook(OnCvarChanged);
	g_hHostIP.AddChangeHook(OnCvarChanged);
	g_hAdvertInterval.AddChangeHook(OnCvarChanged);
	g_hPublicMessage.AddChangeHook(OnCvarChanged);
	g_hOwnReason.AddChangeHook(OnCvarChanged);
	g_hConfirmCall.AddChangeHook(OnCvarChanged);	
	g_hSpamTime.AddChangeHook(OnCvarChanged);
	g_hReportTime.AddChangeHook(OnCvarChanged);
	g_hAdminAction.AddChangeHook(OnCvarChanged);
	
	
	// Modules must create their own updaters
	CreateTimer(10.0, Timer_UpdateTrackersCount, _, TIMER_REPEAT);
	
	
	// Used to allow a client to input their own reason
	AddCommandListener(ChatListener, "say");
	AddCommandListener(ChatListener, "say2");
	AddCommandListener(ChatListener, "say_team");
	
	
	// Api
	g_hOnReportPreForward           = CreateGlobalForward("CallAdmin_OnReportPre", ET_Event, Param_Cell, Param_Cell, Param_String);
	g_hOnReportPostForward          = CreateGlobalForward("CallAdmin_OnReportPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_hOnDrawMenuForward            = CreateGlobalForward("CallAdmin_OnDrawMenu", ET_Event, Param_Cell);
	g_hOnDrawOwnReasonForward       = CreateGlobalForward("CallAdmin_OnDrawOwnReason", ET_Event, Param_Cell);
	g_hOnTrackerCountChangedForward = CreateGlobalForward("CallAdmin_OnTrackerCountChanged", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnDrawTargetForward          = CreateGlobalForward("CallAdmin_OnDrawTarget", ET_Event, Param_Cell, Param_Cell);
	g_hOnAddToAdminCountForward     = CreateGlobalForward("CallAdmin_OnAddToAdminCount", ET_Event, Param_Cell);
	g_hOnServerDataChangedForward   = CreateGlobalForward("CallAdmin_OnServerDataChanged", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
	g_hOnLogMessageForward          = CreateGlobalForward("CallAdmin_OnLogMessage", ET_Ignore, Param_Cell, Param_String);
	g_hOnReportHandledForward       = CreateGlobalForward("CallAdmin_OnReportHandled", ET_Ignore, Param_Cell, Param_Cell); 
	
	
	// Cookies
	if (LibraryExists("clientprefs"))
	{
		g_hLastReportCookie   = RegClientCookie("CallAdmin_LastReport", "Contains a timestamp when this user has reported the last time", CookieAccess_Private);
		g_hLastReportedCookie = RegClientCookie("CallAdmin_LastReported", "Contains a timestamp when this user was reported the last time", CookieAccess_Private);
		
		FetchClientCookies();
	}
	

	// Report handling
	g_hActiveReports = new ArrayList();
	
	// Reason handling
	g_hReasonAdt = new ArrayList(ByteCountToCells(REASON_MAX_LENGTH));
	
	BuildPath(Path_SM, g_sReasonConfigFile, sizeof(g_sReasonConfigFile), "configs/calladmin_reasons.cfg");
	
	if (!FileExists(g_sReasonConfigFile))
	{
		CreateReasonList();
	}
	
	ParseReasonList();
}




void CreateReasonList()
{
	File hFile;
	hFile = OpenFile(g_sReasonConfigFile, "w");
	
	if (hFile == null)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_reasons.cfg' for writing");
		SetFailState("Failed to open configfile 'calladmin_reasons.cfg' for writing");
	}
	
	hFile.WriteLine("// List of reasons seperated by a new line, max %d in length", REASON_MAX_LENGTH);
	hFile.WriteLine("Aimbot");
	hFile.WriteLine("Wallhack");
	hFile.WriteLine("Speedhack");
	hFile.WriteLine("Spinhack");
	hFile.WriteLine("Multihack");
	hFile.WriteLine("No-Recoil Hack");
	hFile.WriteLine("Other");
	
	hFile.Close();
}




void ParseReasonList()
{
	File hFile;
	
	hFile = OpenFile(g_sReasonConfigFile, "r");
	
	
	if (hFile == null)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_reasons.cfg' for reading");
		SetFailState("Failed to open configfile 'calladmin_reasons.cfg' for reading");
	}
	
	
	// Buffer must be a little bit bigger to have enough room for possible comments and being able to check for too long reasons
	char sReadBuffer[PLATFORM_MAX_PATH];
	
	
	int len;
	while (!hFile.EndOfFile() && hFile.ReadLine(sReadBuffer, sizeof(sReadBuffer)))
	{
		if (sReadBuffer[0] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}
		
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");

		len = strlen(sReadBuffer);
		
		
		if (len < 3 || len > REASON_MAX_LENGTH)
		{
			continue;
		}
			
		
		// Add the reason to the list only if it doesn't already exist
		if (g_hReasonAdt.FindString(sReadBuffer) == -1)
		{
			g_hReasonAdt.PushString(sReadBuffer);
		}
	}
	
	hFile.Close();
}




public void OnClientCookiesCached(int client)
{
	char sCookieBuf[24];
	GetClientCookie(client, g_hLastReportCookie, sCookieBuf, sizeof(sCookieBuf));
	
	if (strlen(sCookieBuf) > 0)
	{
		g_iLastReport[client] = StringToInt(sCookieBuf);
	}
	
	
	// Just to be safe
	sCookieBuf[0] = '\0';
	
	GetClientCookie(client, g_hLastReportedCookie, sCookieBuf, sizeof(sCookieBuf));
	
	if (strlen(sCookieBuf) > 0)
	{
		g_iLastReported[client] = StringToInt(sCookieBuf);
	}
}




void FetchClientCookies()
{
	for (int i; i <= MaxClients; i++)
	{
		if (IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}




bool Forward_OnDrawMenu(int client)
{
	Action result;
	
	Call_StartForward(g_hOnDrawMenuForward);
	Call_PushCell(client);
	
	Call_Finish(result);
	
	return (result == Plugin_Continue);
}




bool Forward_OnReportPre(int client, int target, const char[] reason)
{
	Action result;
	
	Call_StartForward(g_hOnReportPreForward);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushString(reason);
	
	Call_Finish(result);
	
	return (result == Plugin_Continue);
}




void Forward_OnReportPost(int client, int target, const char[] reason)
{
	Call_StartForward(g_hOnReportPostForward);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushString(reason);
	
	Call_Finish();
}



bool Forward_OnDrawOwnReason(int client)
{
	Action result;
	
	Call_StartForward(g_hOnDrawOwnReasonForward);
	Call_PushCell(client);
	
	Call_Finish(result);
	
	return (result == Plugin_Continue);
}



bool Forward_OnAddToAdminCount(int client)
{
	Action result;
	
	Call_StartForward(g_hOnAddToAdminCountForward);
	Call_PushCell(client);
	
	Call_Finish(result);
	
	return (result == Plugin_Continue);
}



void Forward_OnTrackerCountChanged(int oldVal, int newVal)
{
	Call_StartForward(g_hOnTrackerCountChangedForward);
	Call_PushCell(oldVal);
	Call_PushCell(newVal);
	
	Call_Finish();
}



bool Forward_OnDrawTarget(int client, int target)
{
	Action result;
	
	Call_StartForward(g_hOnDrawTargetForward);
	Call_PushCell(client);
	Call_PushCell(target);
	
	Call_Finish(result);
	
	return (result == Plugin_Continue);
}



void Forward_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal)
{
	Call_StartForward(g_hOnServerDataChangedForward);
	Call_PushCell(convar);
	Call_PushCell(type);
	Call_PushString(oldVal);
	Call_PushString(newVal);
	
	Call_Finish();
}



void Forward_OnLogMessage(Handle plugin, const char[] message)
{
	Call_StartForward(g_hOnLogMessageForward);
	Call_PushCell(plugin);
	Call_PushString(message);
	
	Call_Finish();
}



void Forward_OnReportHandled(int client, int id)
{
	Call_StartForward(g_hOnReportHandledForward);
	Call_PushCell(client);
	Call_PushCell(id);
	
	Call_Finish();
}




public Action Timer_Advert(Handle timer)
{
	if (g_iCurrentTrackers > 0)
	{
		// Spelling is different (0 admins, 1 admin, 2 admins, 3 admins...)
		if (g_iCurrentTrackers == 1)
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




public void OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_hHostPort)
	{
		g_iHostPort = g_hHostPort.IntValue;
		
		Forward_OnServerDataChanged(cvar, ServerData_HostPort, oldValue, newValue);
	}
	else if (cvar == g_hHostIP)
	{
		UpdateHostIp();
		
		Forward_OnServerDataChanged(cvar, ServerData_HostIP, g_sHostIP, g_sHostIP);
	}
	else if (cvar == g_hServerName)
	{
		g_hServerName.GetString(g_sServerName, sizeof(g_sServerName));
		
		Forward_OnServerDataChanged(cvar, ServerData_HostName, oldValue, newValue);
	}
	else if (cvar == g_hVersion)
	{
		g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	}
	else if (cvar == g_hAdvertInterval)
	{
		delete g_hAdvertTimer;
		
		g_fAdvertInterval = g_hAdvertInterval.FloatValue;
		
		if (g_fAdvertInterval != 0.0)
		{
			g_hAdvertTimer = CreateTimer(g_fAdvertInterval, Timer_Advert, _, TIMER_REPEAT);
		}
	}
	else if (cvar == g_hPublicMessage)
	{
		g_bPublicMessage = g_hPublicMessage.BoolValue;
	}
	else if (cvar == g_hOwnReason)
	{
		g_bOwnReason = g_hOwnReason.BoolValue;
	}
	else if (cvar == g_hConfirmCall)
	{
		g_bConfirmCall = g_hConfirmCall.BoolValue;
	}
	else if (cvar == g_hSpamTime)
	{
		g_iSpamTime = g_hSpamTime.IntValue;
	}
	else if (cvar == g_hReportTime)
	{
		g_iReportTime = g_hReportTime.IntValue;
	}
	else if (cvar == g_hAdminAction)
	{
		g_iAdminAction = g_hAdminAction.IntValue;
	}
}




public Action Command_Call(int client, int argc)
{
	// Console cannot use this
	if (client == 0)
	{
		ReplyToCommand(client, "This command can't be used from console");
		
		return Plugin_Handled;
	}
	
	
	if (!Forward_OnDrawMenu(client))
	{
		return Plugin_Handled;
	}
	
	
	if (g_iLastReport[client] == 0 || LastReportTimeCheck(client))
	{
		g_bSawMessage[client] = false;
		
		ShowClientSelectMenu(client);
	}
	else if (!g_bSawMessage[client])
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_CommandNotAllowed", g_iSpamTime - ( GetTime() - g_iLastReport[client] ));
		g_bSawMessage[client] = true;
	}

	return Plugin_Handled;
}



public Action Command_HandleCall(int client, int argc)
{
	if (client == 0)
	{
		ReplyToCommand(client, "This command can't be used from console");
		
		return Plugin_Handled;
	}
	
	
	if (!CheckCommandAccess(client, "sm_calladmin_admin", ADMFLAG_BAN, false))
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoAdmin");
		
		return Plugin_Handled;
	}
	
	
	if (argc != 1)
	{
		char cmdName[64];
		GetCmdArg(0, cmdName, sizeof(cmdName));
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t: %s <id>", "CallAdmin_WrongNumberOfArguments", cmdName);
		
		return Plugin_Handled;
	}
	
	
	char sArgID[10];
	int reportID;
	
	GetCmdArg(1, sArgID, sizeof(sArgID));
	reportID = StringToInt(sArgID);
	
	
	if (reportID > g_iCurrentReportID)
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_WrongReportID");
		
		return Plugin_Handled;	
	}
	
	
	// Report was already handled
	int reportIndex = g_hActiveReports.FindValue(reportID);
	if (reportIndex == -1)
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_ReportAlreadyHandled");
		
		return Plugin_Handled;	
	}
	
	
	g_hActiveReports.Erase(reportIndex);
	Forward_OnReportHandled(client, reportID);

	return Plugin_Handled;
}



public Action Command_Reload(int client, int argc)
{
	if (!CheckCommandAccess(client, "sm_calladmin_admin", ADMFLAG_BAN, false))
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoAdmin");
		
		return Plugin_Handled;
	}
	
	
	g_hActiveReports.Clear();
	g_hReasonAdt.Clear();
	ParseReasonList();

	return Plugin_Handled;
}



bool LastReportTimeCheck(int client)
{
	if (g_iLastReport[client] <= ( GetTime() - g_iSpamTime ))
	{
		return true;
	}
	
	return false;
}



bool LastReportedTimeCheck(int client)
{
	if (g_iLastReported[client] <= ( GetTime() - g_iReportTime ))
	{
		return true;
	}
	
	return false;
}



// Updates the timestamps of lastreport and lastreported
void SetStates(int client, int target)
{
	int currentTime = GetTime();
	
	g_iLastReport[client]   = currentTime;
	g_iLastReported[target] = currentTime;
	
	
	// Cookies
	if (LibraryExists("clientprefs"))
	{
		SetClientCookieEx(client, g_hLastReportCookie, "%d", currentTime);
		SetClientCookieEx(target, g_hLastReportedCookie, "%d", currentTime);
	}
}



void ConfirmCall(int client)
{
	Menu menu = new Menu(MenuHandler_ConfirmCall);
	menu.SetTitle("%T", "CallAdmin_ConfirmCall", client);
	
	char sConfirm[24];
	
	Format(sConfirm, sizeof(sConfirm), "%T", "CallAdmin_Yes", client);
	menu.AddItem("Yes", sConfirm);
	
	Format(sConfirm, sizeof(sConfirm), "%T", "CallAdmin_No", client);
	menu.AddItem("No", sConfirm);
	
	menu.Display(client, 30);
}



public int MenuHandler_ConfirmCall(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[24];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		// Client has chosen to confirm the call
		if (StrEqual("Yes", sInfo))
		{
			if (!ReportPlayer(client, g_iTarget[client], g_sTargetReason[client]))
			{
				return;
			}
		}
		else
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_CallAborted");
		}
	}
	else if (action == MenuAction_End)
	{
		menu.Close();
	}
}


bool PreReportCheck(int client, int target)
{
	// Selected target isn't valid anymore
	if (!IsClientValid(target))
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NotInGame");
		
		return false;
	}
	
	
	// Already reported (race condition)
	if (!LastReportedTimeCheck(target))
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AlreadyReported");
		
		return false;					
	}
	
	return true;
}



bool ReportPlayer(int client, int target, char[] sReason)
{
	if (!PreReportCheck(client, target))
	{
		return false;
	}
	
	
	// Admins available and...
	if (GetAdminCount() > 0)
	{
		// we want to notify instead of sending the report
		if (g_iAdminAction == ADMIN_ACTION_BLOCK_NOTIFY)
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_IngameAdminNotified");
			PrintNotifyMessageToAdmins(client, g_iTarget[client]);
			
			SetStates(client, g_iTarget[client]);
			
			return false;
		}
		// we want to notify in addition to sending the report
		else if (g_iAdminAction == ADMIN_ACTION_PASS_NOTIFY)
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_IngameAdminNotified");
			PrintNotifyMessageToAdmins(client, g_iTarget[client]);
		}
	}
	
	
	if (!Forward_OnReportPre(client, g_iTarget[client], g_sTargetReason[client]))
	{
		return false;
	}

	if (g_bPublicMessage)
	{
		PrintToChatAll("\x04[CALLADMIN]\x03 %t", "CallAdmin_HasReported", client, target, sReason);
	}
	else
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_YouHaveReported", target, sReason);
	}
	
	SetStates(client, target);
	
	
	g_iCurrentReportID++;
	g_hActiveReports.Push(g_iCurrentReportID);

	Forward_OnReportPost(client, target, sReason);
	
	return true;
}








public Action Timer_UpdateTrackersCount(Handle timer)
{
	int temp = GetTotalTrackers();
	
	if (temp != g_iCurrentTrackers)
	{
		Forward_OnTrackerCountChanged(g_iCurrentTrackers, temp);
	}
	
	g_iCurrentTrackers = temp;
	
	return Plugin_Continue;
}




int GetTotalTrackers()
{
	Handle hIter;
	Handle hPlugin;
	Function func;
	int count;
	int tempcount;
	
	hIter = GetPluginIterator();
	
	while (MorePlugins(hIter))
	{
		hPlugin = ReadPlugin(hIter);
		
		if (GetPluginStatus(hPlugin) == Plugin_Running)
		{
			// We check if the plugin has the public CallAdmin_OnRequestTrackersCountRefresh function
			if ( (func = GetFunctionByName(hPlugin, "CallAdmin_OnRequestTrackersCountRefresh") ) != INVALID_FUNCTION)
			{
				Call_StartFunction(hPlugin, func);
				Call_PushCellRef(tempcount);
				
				Call_Finish();
				
				if (tempcount > 0)
				{
					count += tempcount;
				}
			}
		}
	}
	
	delete hIter;
	
	return count;
}




void ShowClientSelectMenu(int client)
{
	char sBuffer[128];
	char sID[24];
	
	Menu menu = new Menu(MenuHandler_ClientSelect);
	menu.SetTitle("%T", "CallAdmin_SelectClient", client);
	
	for (int i; i <= MaxClients; i++)
	{
		if (i != client && IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && Forward_OnDrawTarget(client, i))
		{
			GetClientName(i, sBuffer, sizeof(sBuffer));
			Format(sID, sizeof(sID), "%d", GetClientSerial(i));
			
			if (LastReportedTimeCheck(i))
			{
				menu.AddItem(sID, sBuffer);
			}
			else
			{
				// Player was recently reported, their item is disabled
				Format(sBuffer, sizeof(sBuffer), "%s (%T)", sBuffer, "CallAdmin_RecentlyReported", client);
				menu.AddItem(sID, sBuffer, ITEMDRAW_DISABLED);
			}
		}
	}
	
	// Menu has no items, no players to report
	if (menu.ItemCount < 1)
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoPlayers");
	}
	else
	{
		menu.Display(client, 30);
	}
}




public int MenuHandler_ClientSelect(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[24];
		int iSerial;
		int iID;
		
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		iSerial = StringToInt(sInfo);
		iID     = GetClientFromSerial(iSerial);
		

		if (!PreReportCheck(client, iID))
		{
			return;					
		}
		
		g_iTarget[client] = iID;
		
		ShowBanReasonMenu(client);
	}
	else if (action == MenuAction_End)
	{
		menu.Close();
	}
}




public void OnClientDisconnect_Post(int client)
{
	g_iTarget[client]          = 0;
	g_sTargetReason[client][0] = '\0';
	g_iLastReport[client]      = 0;
	g_iLastReported[client]    = 0;
	g_bSawMessage[client]       = false;
	g_bAwaitingReason[client]  = false;
	
	RemoveAsTarget(client);
}




void RemoveAsTarget(int client)
{
	for (int i; i <= MaxClients; i++)
	{
		if (g_iTarget[i] == client)
		{
			g_iTarget[i] = 0;
		}
	}
}




void ShowBanReasonMenu(int client)
{
	int count;
	char sReasonBuffer[REASON_MAX_LENGTH];
	count = g_hReasonAdt.Length;

	
	Menu menu = new Menu(MenuHandler_BanReason);
	menu.SetTitle("%T", "CallAdmin_SelectReason", client, g_iTarget[client]);
	
	for (int i; i < count; i++)
	{
		g_hReasonAdt.GetString(i, sReasonBuffer, sizeof(sReasonBuffer));
		
		if (strlen(sReasonBuffer) < 3)
		{
			continue;
		}

		
		menu.AddItem(sReasonBuffer, sReasonBuffer);
	}
	
	// Own reason, call the forward
	if (g_bOwnReason && Forward_OnDrawOwnReason(client))
	{
		char sOwnReason[REASON_MAX_LENGTH];

		Format(sOwnReason, sizeof(sOwnReason), "%T", "CallAdmin_OwnReason", client);
		menu.AddItem("Own reason", sOwnReason);
	}
	
	menu.Display(client, 30);
}




public int MenuHandler_BanReason(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[REASON_MAX_LENGTH];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		// User has chosen to use his own reason
		if (StrEqual("Own reason", sInfo))
		{
			g_bAwaitingReason[client] = true;
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_TypeOwnReason");
			return;
		}
		
		Format(g_sTargetReason[client], sizeof(g_sTargetReason[]), sInfo);
		
		if (!PreReportCheck(client, g_iTarget[client]))
		{
			return;
		}
		
			
		if (g_bConfirmCall)
		{
			ConfirmCall(client);
		}
		else
		{
			if (!ReportPlayer(client, g_iTarget[client], g_sTargetReason[client]))
			{
				return;
			}
		}			
	}
	else if (action == MenuAction_End)
	{
		menu.Close();
	}
}




public Action ChatListener(int client, const char[] command, int argc)
{
	// There were a few cases were the client index was invalid which caused an index out-of-bounds error
	// Invalid clients shouldn't be able to trigger this callback so the reason why this happens has yet to be found out
	// Until then we have this check here to prevent it
	if (!IsClientValid(client))
	{
		return Plugin_Continue;
	}
	
	
	if (g_bAwaitingReason[client] && !IsChatTrigger())
	{
		// 2 more for quotes
		char sReason[REASON_MAX_LENGTH + 2];
		
		GetCmdArgString(sReason, sizeof(sReason));
		StripQuotes(sReason);
		strcopy(g_sTargetReason[client], sizeof(g_sTargetReason[]), sReason);
		
		g_bAwaitingReason[client] = false;
		
		
		// Has aborted
		if (StrEqual(sReason, "!noreason") || StrEqual(sReason, "!abort"))
		{
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_CallAborted");
			
			return Plugin_Handled;
		}
		
		
		// Reason was too short
		if (strlen(sReason) < 3)
		{
			g_bAwaitingReason[client] = true;
			PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_OwnReasonTooShort");
			
			return Plugin_Handled;
		}
		
		
		if (!PreReportCheck(client, g_iTarget[client]))
		{
			return Plugin_Handled;
		}
		
		
		if (g_bConfirmCall)
		{
			ConfirmCall(client);
		}
		else
		{
			if (!ReportPlayer(client, g_iTarget[client], g_sTargetReason[client]))
			{
				return Plugin_Handled;
			}
		}
		
		
		// Block the chatmessage
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}



stock int GetRealClientCount()
{
	int count;
	
	for (int i; i <= MaxClients; i++)
	{
		if (IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i))
		{
			count++;
		}
	}
	
	return count;
}



stock int GetAdminCount()
{
	int count;
	
	for (int i; i <= MaxClients; i++)
	{
		if (IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && CheckCommandAccess(i, "sm_calladmin_admin", ADMFLAG_BAN, false) && Forward_OnAddToAdminCount(i)) 
		{
			count++;
		}
	}
	
	return count;
}


stock void PrintNotifyMessageToAdmins(int client, int target)
{
	for (int i; i <= MaxClients; i++)
	{
		if (IsClientValid(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && CheckCommandAccess(i, "sm_calladmin_admin", ADMFLAG_BAN, false) && Forward_OnAddToAdminCount(i)) 
		{
			PrintToChat(i, "\x04[CALLADMIN]\x03 %t", "CallAdmin_AdminNotification", client, target, g_sTargetReason[client]);
		}
	}	
}



stock void LongToIp(int long, char[] str, int maxlen)
{
	int pieces[4];
	
	pieces[0] = ((long >>> 24) & 255);
	pieces[1] = ((long >>> 16) & 255);
	pieces[2] = ((long >>> 8) & 255);
	pieces[3] = (long & 255); 
	
	Format(str, maxlen, "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]); 
}



// Updates the global g_sHostIP variable to the current ip of the server
// Using the int value directly provides incorrect results, when given the time it should be examined why 
void UpdateHostIp()
{
	char tmpString[sizeof(g_sHostIP)];
	g_hHostIP.GetString(tmpString, sizeof(tmpString));
	
	int tmpInt = StringToInt(tmpString);
	LongToIp(tmpInt, g_sHostIP, sizeof(g_sHostIP));
}



stock void SetClientCookieEx(int client, Handle cookie, const char[] format, any:...)
{
	char sFormatBuf[1024];
	VFormat(sFormatBuf, sizeof(sFormatBuf), format, 4);
	
	SetClientCookie(client, cookie, sFormatBuf);
}
