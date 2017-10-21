/**
 * -----------------------------------------------------
 * File        calladmin_ts3.sp
 * Authors     Impact, Popoklopsi
 * License     GPLv3
 * Web         http://gugyclan.eu, http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013 Impact, Popoklopsi
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
#include "include/socket"
#include <regex>

#undef REQUIRE_PLUGIN
#include "include/updater"
#pragma semicolon 1
#pragma newdecls required



// Global stuff
ConVar g_hVersion;


ConVar g_hUrl;
char g_sUrl[PLATFORM_MAX_PATH];
char g_sRealUrl[PLATFORM_MAX_PATH];
char g_sRealPath[PLATFORM_MAX_PATH];


ConVar g_hKey;
char g_sKey[PLATFORM_MAX_PATH];

int g_iCurrentTrackers;



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_ts3.txt"


public Plugin myinfo = 
{
	name = "CallAdmin: Ts3 module",
	author = "Impact, Popoklopsi",
	description = "The ts3module for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}





public void OnPluginStart()
{
	AutoExecConfig_SetFile("plugin.calladmin_ts3");
	
	g_hVersion = AutoExecConfig_CreateConVar("sm_calladmin_ts3_version", CALLADMIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hUrl     = AutoExecConfig_CreateConVar("sm_calladmin_ts3_url", "http://calladmin.yourclan.eu/ts3", "Url to the ts3 folder of the webscripts", FCVAR_PROTECTED);
	g_hKey     = AutoExecConfig_CreateConVar("sm_calladmin_ts3_key", "SomeSecureKeyNobodyKnows", "Key of your ts3script", FCVAR_PROTECTED);
	
	
	AutoExecConfig(true, "plugin.calladmin_ts3");
	AutoExecConfig_CleanFile();
	
	
	g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	g_hVersion.AddChangeHook(OnCvarChanged);
	
	g_hUrl.GetString(g_sUrl, sizeof(g_sUrl));
	PreFormatUrl();
	g_hUrl.AddChangeHook(OnCvarChanged);
	
	g_hKey.GetString(g_sKey, sizeof(g_sKey));
	g_hKey.AddChangeHook(OnCvarChanged);
	
	CreateTimer(20.0, Timer_UpdateTrackersCount, _, TIMER_REPEAT);
	GetCurrentTrackers();
}



public Action Timer_UpdateTrackersCount(Handle timer)
{
	// Get current trackers
	GetCurrentTrackers();
	
	return Plugin_Continue;
}



int GetCurrentTrackers()
{
	// Create a socket
	Handle Socket = SocketCreate(SOCKET_TCP, OnSocketError);
	
	
	// Optional tweaking stuff
	SocketSetOption(Socket, ConcatenateCallbacks, 4096);
	SocketSetOption(Socket, SocketReceiveTimeout, 3);
	SocketSetOption(Socket, SocketSendTimeout, 3);
	
	// Connect
	SocketConnect(Socket, OnSocketConnectCount, OnSocketReceiveCount, OnSocketDisconnect, g_sRealUrl, 80);
}




void PreFormatUrl()
{
	// We work on a copy
	strcopy(g_sRealUrl, sizeof(g_sRealUrl), g_sUrl);
	
	
	// Strip http and such stuff here
	if (StrContains(g_sRealUrl, "http://") == 0)
	{
		ReplaceString(g_sRealUrl, sizeof(g_sRealUrl), "http://", "");
	}

	if (StrContains(g_sRealUrl, "https://") == 0)
	{
		ReplaceString(g_sRealUrl, sizeof(g_sRealUrl), "https://", "");
	}
	
	if (StrContains(g_sRealUrl, "www.") == 0)
	{
		ReplaceString(g_sRealUrl, sizeof(g_sRealUrl), "www.", "");
	}
	
	
	int index;
	
	// We strip from / of the url to get the path
	if ( (index = StrContains(g_sRealUrl, "/")) != -1 )
	{
		// Copy from there
		strcopy(g_sRealPath, sizeof(g_sRealPath), g_sRealUrl[index]);
		
		
		// Strip the slash of the path if there is one
		int len = strlen(g_sRealPath);
		if (len > 0 && g_sRealPath[len - 1] == '/')
		{
			g_sRealPath[len -1] = '\0';
		}
		
		// Strip the url from there the rest
		g_sRealUrl[index] = '\0';
	}
}




public void OnCvarChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_hVersion)
	{
		g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	}
	else if (cvar == g_hUrl)
	{
		g_hUrl.GetString(g_sUrl, sizeof(g_sUrl));
		PreFormatUrl();
	}
	else if (cvar == g_hKey)
	{
		g_hKey.GetString(g_sKey, sizeof(g_sKey));
	}
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
}



public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATER_URL);
    }
}



// Pseudo forward
public void CallAdmin_OnRequestTrackersCountRefresh(int &trackers)
{
	trackers = g_iCurrentTrackers;
}



public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	// Create a socket
	Handle Socket = SocketCreate(SOCKET_TCP, OnSocketError);
	
	
	// Optional tweaking stuff
	SocketSetOption(Socket, ConcatenateCallbacks, 4096);
	SocketSetOption(Socket, SocketReceiveTimeout, 3);
	SocketSetOption(Socket, SocketSendTimeout, 3);
	
	
	DataPack pack = new DataPack();
	
	
	// Buffers
	char sClientID[21];
	char sClientName[MAX_NAME_LENGTH];
	
	char sTargetID[21];
	char sTargetName[MAX_NAME_LENGTH];
	
	
	// Reporter wasn't a real client (initiated by a module)
	if (client == REPORTER_CONSOLE)
	{
		strcopy(sClientName, sizeof(sClientName), "Server/Console");
		strcopy(sClientID, sizeof(sClientID), "Server/Console");
	}
	else
	{
		GetClientName(client, sClientName, sizeof(sClientName));
		
		if (!GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID)))
		{
			CallAdmin_LogMessage("Failed to get authentication for client %d (%s)", client, sClientName);
			
			return;
		}
	}

	
	GetClientName(target, sTargetName, sizeof(sTargetName));
	
	if (!GetClientAuthId(target, AuthId_Steam2, sTargetID, sizeof(sTargetID)))
	{
		CallAdmin_LogMessage("Failed to get authentication for client %d (%s)", client, sTargetName);
		
		return;
	}
	
	
	// Write the data to the pack
	pack.WriteString(sClientID);
	pack.WriteString(sClientName);
	
	pack.WriteString(sTargetID);
	pack.WriteString(sTargetName);
	
	pack.WriteString(reason);
	
	
	// Set the pack as argument to the callbacks, so we can read it out later
	SocketSetArg(Socket, pack);
	
	
	// Connect
	SocketConnect(Socket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, g_sRealUrl, 80);
}




public int OnSocketConnect(Handle socket, DataPack pack)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if (SocketIsConnected(socket))
	{
		// Buffers
		char sRequestString[2048];
		char sRequestParams[2048];
		
		// Params
		char sClientID[21];
		char sClientName[MAX_NAME_LENGTH * 4];
		
		char sTargetID[21];
		char sTargetName[MAX_NAME_LENGTH * 4];
		
		char sServerName[64 * 4];
		char sServerIP[16 + 5];
		
		
		// Fetch serverdata here...
		CallAdmin_GetHostName(sServerName, sizeof(sServerName));
		CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
		Format(sServerIP, sizeof(sServerIP), "%s:%d", sServerIP, CallAdmin_GetHostPort());
		
		
		// Currently maximum 48 in length
		char sReason[REASON_MAX_LENGTH * 4];
		
		
		// Reset the pack
		pack.Reset(false);
		
		
		// Read data
		pack.ReadString(sClientID, sizeof(sClientID));
		pack.ReadString(sClientName, sizeof(sClientName));
		
		pack.ReadString(sTargetID, sizeof(sTargetID));
		pack.ReadString(sTargetName, sizeof(sTargetName));
		
		pack.ReadString(sReason, sizeof(sReason));
		
		// Close the pack
		delete pack;
		
		
		URLEncode(sClientName, sizeof(sClientName));
		URLEncode(sTargetName, sizeof(sTargetName));
		URLEncode(sReason, sizeof(sReason));
		URLEncode(sServerName, sizeof(sServerName));
		
		
		// Temp, for bots
		if (strlen(sTargetID) < 1)
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




public int OnSocketReceive(Handle socket, char[] data, const int size, any pack) 
{
	if (socket != null)
	{
		// Check the response here and do something
		
		
		// Close the socket
		if (SocketIsConnected(socket))
		{
			SocketDisconnect(socket);
		}
	}
}



public int OnSocketDisconnect(Handle socket, any pack)
{
	delete socket;
}



public int OnSocketError(Handle socket, const int errorType, const int errorNum, any pack)
{
	CallAdmin_LogMessage("Socket Error: %d, %d", errorType, errorNum);
	
	delete socket;
}




// Onlinecount callback
public int OnSocketConnectCount(Handle socket, any pack)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if (SocketIsConnected(socket))
	{
		// Buffers
		char sRequestString[2048];
		char sRequestParams[2048];

		
		// Params
		Format(sRequestParams, sizeof(sRequestParams), "onlinecount.php?key=%s", g_sKey);
		
		
		// Request String
		Format(sRequestString, sizeof(sRequestString), "GET %s/%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", g_sRealPath, sRequestParams, g_sRealUrl);
		
		
		// Send the request
		SocketSend(socket, sRequestString);
	}
}




// Onlinecount callback
public int OnSocketReceiveCount(Handle socket, char[] data, const int size, any pack) 
{
	if (socket != null)
	{
		// This fixes an bug on windowsservers
		// The receivefunction for socket is getting called twice on these systems, once for the headers, and a second time for the body
		// Because we know that our response should begin with <?xml and contains a steamid we can quit here and don't waste resources on the first response
		// Other than that if the api is down, the request was malformed etcetera we don't waste resources for working with useless data
		if (StrContains(data, "<?xml", false) == -1)
		{
			return;
		}
		
		
		char Split[2][48];
		
		ExplodeString(data, "<onlineCount>", Split, sizeof(Split), sizeof(Split[]));
		
		
		// Run though count
		int splitsize = sizeof(Split);
		int index;
		for (int i; i < splitsize; i++)
		{
			if (strlen(Split[i]) > 0)
			{
				// If we find something we split off at the searchresult, we then then only have the steamid
				if ( (index = StrContains(Split[i], "</onlineCount>", true)) != -1)
				{
					Split[i][index] = '\0';
				}
			}
		}
		
		
		// Add the count to the total trackers
		if (strlen(Split[1]) > 0)
		{
			if (SimpleRegexMatch(Split[1], "^[0-9]+$"))
			{
				int temp = StringToInt(Split[1]);
				
				if (temp > 0)
				{
					g_iCurrentTrackers = temp;
				}
			}
		}

		
		// Close the socket
		if (SocketIsConnected(socket))
		{
			SocketDisconnect(socket);
		}
	}
}




// Written by Peace-Maker (i guess), formatted for better readability
stock void URLEncode(char[] sString, int maxlen, char safe[] = "/", bool bFormat = false)
{
	char sAlwaysSafe[256];
	Format(sAlwaysSafe, sizeof(sAlwaysSafe), "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-%s", safe);
	
	// Need 2 '%' since sp's Format parses one as a parameter to replace
	// http://wiki.alliedmods.net/Format_Class_Functions_%28SourceMod_Scripting%29
	if (bFormat)
	{
		ReplaceString(sString, maxlen, "%", "%%25");
	}
	else
	{
		ReplaceString(sString, maxlen, "%", "%25");
	}
	
	
	char sChar[8];
	char sReplaceChar[8];
	
	for (int i = 1; i < 256; i++)
	{
		// Skip the '%' double replace ftw..
		if (i==37)
		{
			continue;
		}
		
		
		Format(sChar, sizeof(sChar), "%c", i);
		if (StrContains(sAlwaysSafe, sChar) == -1 && StrContains(sString, sChar) != -1)
		{
			if (bFormat)
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