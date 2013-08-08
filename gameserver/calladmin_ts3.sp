/**
 * -----------------------------------------------------
 * File        calladmin_ts3.sp
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
#include <socket>
#include <regex>

#undef REQUIRE_PLUGIN
#include <updater>
#pragma semicolon 1



// Global stuff
new Handle:g_hVersion;


new Handle:g_hUrl;
new String:g_sUrl[PLATFORM_MAX_PATH];
new String:g_sRealUrl[PLATFORM_MAX_PATH];
new String:g_sRealPath[PLATFORM_MAX_PATH];


new Handle:g_hKey;
new String:g_sKey[PLATFORM_MAX_PATH];

new g_iCurrentTrackers;



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_ts3.txt"


public Plugin:myinfo = 
{
	name = "CallAdmin: Ts3 module",
	author = "Impact, Popoklopsi",
	description = "The ts3module for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}





public OnPluginStart()
{
	AutoExecConfig_SetFile("plugin.calladmin_ts3");
	
	g_hVersion = AutoExecConfig_CreateConVar("sm_calladmin_ts3_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hUrl     = AutoExecConfig_CreateConVar("sm_calladmin_ts3_url", "http://calladmin.yourclan.eu/subfolder", "Url to the ts3script path", FCVAR_PLUGIN);
	g_hKey     = AutoExecConfig_CreateConVar("sm_calladmin_ts3_key", "SomeSecureKeyNobodyKnows", "Key of your ts3script", FCVAR_PLUGIN);
	
	
	AutoExecConfig(true, "plugin.calladmin_ts3");
	AutoExecConfig_CleanFile();
	
	
	SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);
	
	GetConVarString(g_hUrl, g_sUrl, sizeof(g_sUrl));
	PreFormatUrl();
	HookConVarChange(g_hUrl, OnCvarChanged);
	
	GetConVarString(g_hKey, g_sKey, sizeof(g_sKey));
	HookConVarChange(g_hKey, OnCvarChanged);
	
	CreateTimer(20.0, Timer_UpdateTrackersCount, _, TIMER_REPEAT);
	GetCurrentTrackers();
}



public Action:Timer_UpdateTrackersCount(Handle:timer)
{
	// Get current trackers
	GetCurrentTrackers();
	
	return Plugin_Continue;
}



GetCurrentTrackers()
{
	// Create a new socket
	new Handle:Socket = SocketCreate(SOCKET_TCP, OnSocketError);
	
	
	// Optional tweaking stuff
	SocketSetOption(Socket, ConcatenateCallbacks, 4096);
	SocketSetOption(Socket, SocketReceiveTimeout, 3);
	SocketSetOption(Socket, SocketSendTimeout, 3);
	
	// Connect
	SocketConnect(Socket, OnSocketConnectCount, OnSocketReceiveCount, OnSocketDisconnect, g_sRealUrl, 80);
}




PreFormatUrl()
{
	// We work on a copy
	strcopy(g_sRealUrl, sizeof(g_sRealUrl), g_sUrl);
	
	
	// Strip http and such stuff here
	if(StrContains(g_sRealUrl, "http://") == 0)
	{
		ReplaceString(g_sRealUrl, sizeof(g_sRealUrl), "http://", "");
	}

	if(StrContains(g_sRealUrl, "https://") == 0)
	{
		ReplaceString(g_sRealUrl, sizeof(g_sRealUrl), "https://", "");
	}
	
	if(StrContains(g_sRealUrl, "www.") == 0)
	{
		ReplaceString(g_sRealUrl, sizeof(g_sRealUrl), "www.", "");
	}
	
	
	new index;
	
	// We strip from / of the url to get the path
	if( (index = StrContains(g_sRealUrl, "/")) != -1 )
	{
		// Copy from there
		strcopy(g_sRealPath, sizeof(g_sRealPath), g_sRealUrl[index]);
		
		
		// Strip the slash of the path if there is one
		new len = strlen(g_sRealPath);
		if(len > 0 && g_sRealPath[len - 1] == '/')
		{
			g_sRealPath[len -1] = '\0';
		}
		
		// Strip the url from there the rest
		g_sRealUrl[index] = '\0';
	}
}




public OnCvarChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if(cvar == g_hVersion)
	{
		SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	}
	else if(cvar == g_hUrl)
	{
		GetConVarString(g_hUrl, g_sUrl, sizeof(g_sUrl));
		PreFormatUrl();
	}
	else if(cvar == g_hKey)
	{
		GetConVarString(g_hKey, g_sKey, sizeof(g_sKey));
	}
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



// Pseudo forward
public CallAdmin_OnRequestTrackersCountRefresh(&trackers)
{
	trackers = g_iCurrentTrackers;
}



public CallAdmin_OnReportPost(client, target, const String:reason[])
{
	// Create a new socket
	new Handle:Socket = SocketCreate(SOCKET_TCP, OnSocketError);
	
	
	// Optional tweaking stuff
	SocketSetOption(Socket, ConcatenateCallbacks, 4096);
	SocketSetOption(Socket, SocketReceiveTimeout, 3);
	SocketSetOption(Socket, SocketSendTimeout, 3);
	
	
	// Create a datapack
	new Handle:pack = CreateDataPack();
	
	
	// Buffers
	decl String:sClientID[21];
	decl String:sClientName[MAX_NAME_LENGTH];
	
	decl String:sTargetID[21];
	decl String:sTargetName[MAX_NAME_LENGTH];
	
	
	// Reporter wasn't a real client (initiated by a module)
	if(client == REPORTER_CONSOLE)
	{
		strcopy(sClientName, sizeof(sClientName), "Server/Console");
		strcopy(sClientID, sizeof(sClientID), "Server/Console");
	}
	else
	{
		GetClientName(client, sClientName, sizeof(sClientName));
		GetClientAuthString(client, sClientID, sizeof(sClientID));
	}

	
	GetClientName(target, sTargetName, sizeof(sTargetName));
	GetClientAuthString(target, sTargetID, sizeof(sTargetID));
	
	
	// Write the data to the pack
	WritePackString(pack, sClientID);
	WritePackString(pack, sClientName);
	
	WritePackString(pack, sTargetID);
	WritePackString(pack, sTargetName);
	
	WritePackString(pack, reason);
	
	
	// Set the pack as argument to the callbacks, so we can read it out later
	SocketSetArg(Socket, pack);
	
	
	// Connect
	SocketConnect(Socket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, g_sRealUrl, 80);
}




public OnSocketConnect(Handle:socket, any:pack)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if(SocketIsConnected(socket))
	{
		// Buffers
		decl String:sRequestString[2048];
		decl String:sRequestParams[2048];
		
		// Params
		decl String:sClientID[21];
		decl String:sClientName[MAX_NAME_LENGTH * 4];
		
		decl String:sTargetID[21];
		decl String:sTargetName[MAX_NAME_LENGTH * 4];
		
		decl String:sServerName[64 * 4];
		decl String:sServerIP[16 + 5];
		
		
		// Fetch serverdata here...
		CallAdmin_GetHostName(sServerName, sizeof(sServerName));
		CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
		Format(sServerIP, sizeof(sServerIP), "%s:%d", sServerIP, CallAdmin_GetHostPort());
		
		
		// Currently maximum 48 in length
		decl String:sReason[REASON_MAX_LENGTH * 4];
		
		
		// Reset the pack
		ResetPack(pack, false);
		
		
		// Read data
		ReadPackString(pack, sClientID, sizeof(sClientID));
		ReadPackString(pack, sClientName, sizeof(sClientName));
		
		ReadPackString(pack, sTargetID, sizeof(sTargetID));
		ReadPackString(pack, sTargetName, sizeof(sTargetName));
		
		ReadPackString(pack, sReason, sizeof(sReason));
		
		// Close the pack
		CloseHandle(pack);
		
		
		URLEncode(sClientName, sizeof(sClientName));
		URLEncode(sTargetName, sizeof(sTargetName));
		URLEncode(sReason, sizeof(sReason));
		URLEncode(sServerName, sizeof(sServerName));
		
		
		// Temp, for bots
		if(strlen(sTargetID) < 1)
		{
			Format(sTargetID, sizeof(sTargetID), "INVALID");
		}
		
		
		// Params
		Format(sRequestParams, sizeof(sRequestParams), "index.php?key=%s&targetid=%s&targetname=%s%&targetreason=%s&clientid=%s&clientname=%s&servername=%s&serverip=%s", g_sKey, sTargetID, sTargetName, sReason, sClientID, sClientName, sServerName, sServerIP);
		
		
		// Request String
		Format(sRequestString, sizeof(sRequestString), "GET %s/%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", g_sRealPath, sRequestParams, g_sRealUrl);
		
		
		// Send the request
		SocketSend(socket, sRequestString);
	}
}




public OnSocketReceive(Handle:socket, String:data[], const size, any:pack) 
{
	if(socket != INVALID_HANDLE)
	{
		// Check the response here and do something
		
		
		// Close the socket
		if(SocketIsConnected(socket))
		{
			SocketDisconnect(socket);
		}
	}
}



public OnSocketDisconnect(Handle:socket, any:pack)
{
	if(socket != INVALID_HANDLE)
	{
		CloseHandle(socket);
	}
}



public OnSocketError(Handle:socket, const errorType, const errorNum, any:pack)
{
	CallAdmin_LogMessage("Socket Error: %d, %d", errorType, errorNum);
	
	if(socket != INVALID_HANDLE)
	{
		CloseHandle(socket);
	}
}




// Onlinecount callback
public OnSocketConnectCount(Handle:socket, any:pack)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if(SocketIsConnected(socket))
	{
		// Buffers
		decl String:sRequestString[2048];
		decl String:sRequestParams[2048];

		
		// Params
		Format(sRequestParams, sizeof(sRequestParams), "onlinecount.php?key=%s", g_sKey);
		
		
		// Request String
		Format(sRequestString, sizeof(sRequestString), "GET %s/%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", g_sRealPath, sRequestParams, g_sRealUrl);
		
		
		// Send the request
		SocketSend(socket, sRequestString);
	}
}




// Onlinecount callback
public OnSocketReceiveCount(Handle:socket, String:data[], const size, any:pack) 
{
	if(socket != INVALID_HANDLE)
	{
		// This fixes an bug on windowsservers
		// The receivefunction for socket is getting called twice on these systems, once for the headers, and a second time for the body
		// Because we know that our response should begin with <?xml and contains a steamid we can quit here and don't waste resources on the first response
		// Other than that if the api is down, the request was malformed etcetera we don't waste resources for working with useless data
		if(StrContains(data, "<?xml", false) == -1)
		{
			return;
		}
		
		
		new String:Split[2][48];
		
		ExplodeString(data, "<onlineCount>", Split, sizeof(Split), sizeof(Split[]));
		
		
		// Run though count
		new splitsize = sizeof(Split);
		new index;
		for(new i; i < splitsize; i++)
		{
			if(strlen(Split[i]) > 0)
			{
				// If we find something we split off at the searchresult, we then then only have the steamid
				if( (index = StrContains(Split[i], "</onlineCount>", true)) != -1)
				{
					Split[i][index] = '\0';
				}
			}
		}
		
		
		// Add the count to the total trackers
		if(strlen(Split[1]) > 0)
		{
			if(SimpleRegexMatch(Split[1], "^[0-9]+$"))
			{
				new temp = StringToInt(Split[1]);
				
				if(temp > 0)
				{
					g_iCurrentTrackers = temp;
				}
			}
		}

		
		// Close the socket
		if(SocketIsConnected(socket))
		{
			SocketDisconnect(socket);
		}
	}
}




// Written by Peace-Maker (i guess), formatted for better readability
stock URLEncode(String:sString[], maxlen, String:safe[] = "/", bool:bFormat = false)
{
	decl String:sAlwaysSafe[256];
	Format(sAlwaysSafe, sizeof(sAlwaysSafe), "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-%s", safe);
	
	// Need 2 '%' since sp's Format parses one as a parameter to replace
	// http://wiki.alliedmods.net/Format_Class_Functions_%28SourceMod_Scripting%29
	if(bFormat)
	{
		ReplaceString(sString, maxlen, "%", "%%25");
	}
	else
	{
		ReplaceString(sString, maxlen, "%", "%25");
	}
	
	
	new String:sChar[8];
	new String:sReplaceChar[8];
	
	for(new i = 1; i < 256; i++)
	{
		// Skip the '%' double replace ftw..
		if(i==37)
		{
			continue;
		}
		
		
		Format(sChar, sizeof(sChar), "%c", i);
		if(StrContains(sAlwaysSafe, sChar) == -1 && StrContains(sString, sChar) != -1)
		{
			if(bFormat)
			{
				Format(sReplaceChar, sizeof(sReplaceChar), "%%%%%02X", i);
			}
			else
			{
				Format(sReplaceChar, sizeof(sReplaceChar), "%%%02X", i);
			}
			
			ReplaceString(sString, maxlen, sChar, sReplaceChar);
		}
	}
}