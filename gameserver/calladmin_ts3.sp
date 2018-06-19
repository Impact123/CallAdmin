/**
 * -----------------------------------------------------
 * File        calladmin_ts3.sp
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
#include "include/system2"
#include <regex>

#undef REQUIRE_PLUGIN
#include "include/updater"
#pragma semicolon 1
#pragma newdecls required


// This should be 128 KB which is more than enough
// x * 4 -> bytes / 1024 -> KiloBytes
#pragma dynamic 32768



// Global stuff
ConVar g_hVersion;


ConVar g_hUrl;
char g_sUrl[PLATFORM_MAX_PATH];
char g_sRealUrl[PLATFORM_MAX_PATH];


ConVar g_hKey;
char g_sKey[PLATFORM_MAX_PATH];

int g_iCurrentTrackers;



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_ts3.txt"


public Plugin myinfo = 
{
	name = "CallAdmin: Ts3 module",
	author = "Impact, dordnung",
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



public Action Timer_UpdateTrackersCount(Handle timer)
{
	// Get current trackers
	GetCurrentTrackers();
	
	return Plugin_Continue;
}



int GetCurrentTrackers()
{
	// URL encode the key
	char sKey[PLATFORM_MAX_PATH * 2];
	System2_URLEncode(sKey, sizeof(sKey), g_sKey);

	// Create a HTTP request
	System2HTTPRequest httpRequest = new System2HTTPRequest(OnHTTPReceiveCount, "%s/onlinecount.php?key=%s", g_sRealUrl, sKey);
	httpRequest.Timeout = 10;
	
	// Start the HTTP request
	httpRequest.GET();

	// Clean up
	delete httpRequest;
}




void PreFormatUrl()
{
	// We work on a copy
	strcopy(g_sRealUrl, sizeof(g_sRealUrl), g_sUrl);
	
	// Strip the slash of the path if there is one
	int len = strlen(g_sRealUrl);
	if (len > 0 && g_sRealUrl[len - 1] == '/')
	{
		g_sRealUrl[len -1] = '\0';
	}
}



// Pseudo forward
public void CallAdmin_OnRequestTrackersCountRefresh(int &trackers)
{
	trackers = g_iCurrentTrackers;
}



public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	// Buffers
	char sClientID[21 * 4];
	char sClientName[MAX_NAME_LENGTH * 4];
	
	char sTargetID[21 * 4];
	char sTargetName[MAX_NAME_LENGTH * 4];
	
	char sServerName[64 * 4];
	char sServerIP[16 + 5];

	// Currently maximum 48 in length
	char sReason[REASON_MAX_LENGTH * 4];
	
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

	// Fetch serverdata here...
	CallAdmin_GetHostName(sServerName, sizeof(sServerName));
	CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
	Format(sServerIP, sizeof(sServerIP), "%s:%d", sServerIP, CallAdmin_GetHostPort());

	// URL encode the parameters
	char sKey[PLATFORM_MAX_PATH * 2];
	System2_URLEncode(sKey, sizeof(sKey), g_sKey);
	System2_URLEncode(sClientName, sizeof(sClientName), sClientName);
	System2_URLEncode(sClientID, sizeof(sClientID), sClientID);
	System2_URLEncode(sTargetName, sizeof(sTargetName), sTargetName);
	System2_URLEncode(sTargetID, sizeof(sTargetID), sTargetID);
	System2_URLEncode(sReason, sizeof(sReason), sReason);
	System2_URLEncode(sServerName, sizeof(sServerName), sServerName);
		
	// Temp, for bots
	if (strlen(sTargetID) < 1)
	{
		Format(sTargetID, sizeof(sTargetID), "INVALID");
	}
	
	// Create a HTTP request
	System2HTTPRequest httpRequest = new System2HTTPRequest(OnHTTPReceive, "%s/index.php?key=%s&targetid=%s&targetname=%s%&targetreason=%s&clientid=%s&clientname=%s&servername=%s&serverip=%s", g_sRealUrl, sKey, sTargetID, sTargetName, sReason, sClientID, sClientName, sServerName, sServerIP);
	httpRequest.Timeout = 10;
	
	// Start the HTTP request
	httpRequest.GET();

	// Clean up
	delete httpRequest;
}




// Report callback
public void OnHTTPReceive(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	// Check if request could be made
	if (!success)
	{
		CallAdmin_LogMessage("Error on sending report: %s", error);
	}
	// Check for valid HTTP response status code
	else if (response.StatusCode != 200)
	{
		CallAdmin_LogMessage("Error on sending report: HTTP status code %d", response.StatusCode);
	}
}




// Onlinecount callback
public void OnHTTPReceiveCount(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	// Check if request could be made
	if (!success)
	{
		CallAdmin_LogMessage("Error on receiving tracker count: %s", error);
		return;
	}

	// Check for valid HTTP response status code
	if (response.StatusCode != 200)
	{
		CallAdmin_LogMessage("Error on receiving tracker count: HTTP status code %d", response.StatusCode);
		return;
	}

	// Get the data of the response
	char[] data = new char[response.ContentLength + 1];
	response.GetContent(data, response.ContentLength + 1);

	// Check for valid data
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
}