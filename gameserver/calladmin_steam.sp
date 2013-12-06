/**
 * -----------------------------------------------------
 * File        calladmin_steam.sp
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
#include <messagebot>
#include "calladmin"
#include <socket>
#include <regex>

#undef REQUIRE_PLUGIN
#include <updater>
#pragma semicolon 1


// This should be 128 KB which is more than enough
// x * 4 -> bytes / 1024 -> KiloBytes
#pragma dynamic 32768


#define CALLADMIN_STEAM_AVAILABLE()      (GetFeatureStatus(FeatureType_Native, "CallAdminBot_ReportPlayer")   == FeatureStatus_Available)
#define SOCKET_AVAILABLE()               (GetFeatureStatus(FeatureType_Native, "SocketCreate")                == FeatureStatus_Available)



// Each array can have 150 items, this is hardcoded, bad things happen if you change this
#define MAX_ITEMS 150



// Global stuff
new Handle:g_hVersion;

new Handle:g_hSteamUsername;
new String:g_sSteamUsername[128];

new Handle:g_hSteamPassword;
new String:g_sSteamPassword[128];

new Handle:g_hSteamIDRegex;
new Handle:g_hCommunityIDRegex;


new String:g_sSteamIDConfigFile[PLATFORM_MAX_PATH];
new String:g_sGroupIDConfigFile[PLATFORM_MAX_PATH];



enum AuthStringType
{
	AuthString_SteamID,
	AuthString_CommunityID,
	AuthString_Unknown
}



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_steam.txt"


public Plugin:myinfo = 
{
	name = "CallAdmin: Steam module",
	author = "Impact, Popoklopsi",
	description = "The steammodule for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}





public OnPluginStart()
{
	// Path to the SteamID list
	BuildPath(Path_SM, g_sSteamIDConfigFile, sizeof(g_sSteamIDConfigFile), "configs/calladmin_steam_steamidlist.cfg");
	
	if(!FileExists(g_sSteamIDConfigFile))
	{
		CreateSteamIDList();
	}
	
	
	// Path to the GroupID list
	BuildPath(Path_SM, g_sGroupIDConfigFile, sizeof(g_sGroupIDConfigFile), "configs/calladmin_steam_groupidlist.cfg");
	
	if(!FileExists(g_sGroupIDConfigFile))
	{
		CreateGroupIDList();
	}
	
	
	// Just for simple validation usage
	g_hSteamIDRegex     = CompileRegex("^STEAM_[0-1]{1}:[0-1]{1}:[0-9]+$");
	g_hCommunityIDRegex = CompileRegex("^[0-9]{4,17}+$");
	
	
	
	// Clear the recipients
	MessageBot_ClearRecipients();
	
	// Read in all those steamids
	ParseSteamIDList();
	
	// Read in all those groupids
	ParseGroupIDList();
	

	
	
	AutoExecConfig_SetFile("plugin.calladmin_steam");
	
	g_hVersion       = AutoExecConfig_CreateConVar("sm_calladmin_steam_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hSteamUsername = AutoExecConfig_CreateConVar("sm_calladmin_steam_username", "", "Your steam username", FCVAR_PLUGIN|FCVAR_PROTECTED);
	g_hSteamPassword = AutoExecConfig_CreateConVar("sm_calladmin_steam_password", "", "Your steam password", FCVAR_PLUGIN|FCVAR_PROTECTED);
	
	
	AutoExecConfig(true, "plugin.calladmin_steam");
	AutoExecConfig_CleanFile();
	
	
	LoadTranslations("calladmin_steam.phrases");
	
	SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);
	
	GetConVarString(g_hSteamUsername, g_sSteamUsername, sizeof(g_sSteamUsername));
	HookConVarChange(g_hSteamUsername, OnCvarChanged);
	
	GetConVarString(g_hSteamPassword, g_sSteamPassword, sizeof(g_sSteamPassword));
	HookConVarChange(g_hSteamPassword, OnCvarChanged);
}



public OnMessageResultReceived(MessageBotResult:result, error)
{
	if(result != RESULT_NO_ERROR)
	{
		CallAdmin_LogMessage("Failed to send message, result was: (%d, %d)", result, error);
	}
}




CreateSteamIDList()
{
	new Handle:hFile;
	hFile = OpenFile(g_sSteamIDConfigFile, "w");
	
	// Failed to open
	if(hFile == INVALID_HANDLE)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for writing");
		SetFailState("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for writing");
	}
	
	WriteFileLine(hFile, "// List of steamID's or communityid's, seperated by a new line");
	
	CloseHandle(hFile);
}




ParseSteamIDList()
{
	new Handle:hFile;
	
	hFile = OpenFile(g_sSteamIDConfigFile, "r");
	
	
	// Failed to open
	if(hFile == INVALID_HANDLE)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for reading");
		SetFailState("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for reading");
	}
	
	
	// Buffer must be a little bit bigger to have enough room for possible comments
	decl String:sReadBuffer[128];

	
	new len;
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sReadBuffer, sizeof(sReadBuffer)))
	{
		if(sReadBuffer[0] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}
		
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), " ", "");
		
		
		
		// Support for comments on end of line
		len = strlen(sReadBuffer);
		for(new i; i < len; i++)
		{
			if(sReadBuffer[i] == ' ' || sReadBuffer[i] == '/')
			{
				sReadBuffer[i] = '\0';
				
				break;
			}
		}
		
		
		new AuthStringType:type = GetAuthIDType(sReadBuffer);
		
		// Is a steamid
		if(type == AuthString_SteamID)
		{
			GetRegexSubString(g_hSteamIDRegex, 1, sReadBuffer, sizeof(sReadBuffer));
		}
		// Is a communityid
		else if(type == AuthString_CommunityID)
		{
			GetRegexSubString(g_hCommunityIDRegex, 1, sReadBuffer, sizeof(sReadBuffer));
		}
		// No match :(
		else
		{
			continue;
		}
		
		
		// Add as recipient
		MessageBot_AddRecipient(sReadBuffer);
	}
	
	CloseHandle(hFile);
}




CreateGroupIDList()
{
	new Handle:hFile;
	hFile = OpenFile(g_sGroupIDConfigFile, "w");
	
	// Failed to open
	if(hFile == INVALID_HANDLE)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for writing");
		SetFailState("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for writing");
	}
	
	WriteFileLine(hFile, "// List of group names (custom group url), seperated by a new line");
	
	CloseHandle(hFile);
}




ParseGroupIDList()
{
	new Handle:hFile;
	
	hFile = OpenFile(g_sGroupIDConfigFile, "r");
	
	
	// Failed to open
	if(hFile == INVALID_HANDLE)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for reading");
		SetFailState("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for reading");
	}
	
	
	// Buffer must be a little bit bigger to have enough room for possible comments
	decl String:sReadBuffer[128];

	
	new len;
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sReadBuffer, sizeof(sReadBuffer)))
	{
		if(sReadBuffer[0] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}
		
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), " ", "");
		
		
		
		// Support for comments on end of line
		len = strlen(sReadBuffer);
		for(new i; i < len; i++)
		{
			if(sReadBuffer[i] == ' ' || sReadBuffer[i] == '/')
			{
				sReadBuffer[i] = '\0';
				
				// Refresh the len
				len = strlen(sReadBuffer);
				
				
				break;
			}
		}
		
		
		if(len < 3 || len > 64)
		{
			continue;
		}
		
		
		// Go get them members
		FetchGroupMembers(sReadBuffer);
	}
	
	CloseHandle(hFile);
}




public OnCvarChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if(cvar == g_hVersion)
	{
		SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	}
	else if(cvar == g_hSteamUsername)
	{
		GetConVarString(g_hSteamUsername, g_sSteamUsername, sizeof(g_sSteamUsername));
	}
	else if(cvar == g_hSteamPassword)
	{
		GetConVarString(g_hSteamPassword, g_sSteamPassword, sizeof(g_sSteamPassword));
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




public CallAdmin_OnReportPost(client, target, const String:reason[])
{
	MessageBot_SetLoginData(g_sSteamUsername, g_sSteamPassword);
	
	decl String:sClientName[MAX_NAME_LENGTH];
	decl String:sClientID[21];
	
	decl String:sTargetName[MAX_NAME_LENGTH];
	decl String:sTargetID[21];
	
	decl String:sServerIP[16];
	new serverPort;
	decl String:sServerName[128];
	
	CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
	serverPort = CallAdmin_GetHostPort();
	CallAdmin_GetHostName(sServerName, sizeof(sServerName));
	
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
	
	decl String:sMessage[4096];
	Format(sMessage, sizeof(sMessage), "%t", "CallAdmin_SteamMessage", sServerName, sServerIP, serverPort, sClientName, sClientID, sTargetName, sTargetID, reason);
	
	MessageBot_SendMessage(OnMessageResultReceived, sMessage);
}




FetchGroupMembers(String:groupID[])
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
	decl String:sGroupID[64];
	strcopy(sGroupID, sizeof(sGroupID), groupID);
	
	
	// Write the data to the pack
	WritePackString(pack, sGroupID);
	
	
	// Set the pack as argument to the callbacks, so we can read it out later
	SocketSetArg(Socket, pack);
	
	
	// Connect
	SocketConnect(Socket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, "steamcommunity.com", 80);
}




public OnSocketConnect(Handle:socket, any:pack)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if(SocketIsConnected(socket))
	{
		// Buffers
		decl String:sRequestString[1024];
		decl String:sRequestPath[512];
		decl String:sGroupID[64 * 4];
		
		
		// Reset the pack
		ResetPack(pack, false);
		
		
		// Read data
		ReadPackString(pack, sGroupID, sizeof(sGroupID));
		
		// Close the pack
		CloseHandle(pack);
		
		
		URLEncode(sGroupID, sizeof(sGroupID));
		
		
		// Params
		Format(sRequestPath, sizeof(sRequestPath), "groups/%s/memberslistxml", sGroupID);

		
		// Request String
		Format(sRequestString, sizeof(sRequestString), "GET /%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", sRequestPath, "steamcommunity.com");

		
		// Send the request
		SocketSend(socket, sRequestString);
	}
}




public OnSocketReceive(Handle:socket, String:data[], const size, any:pack) 
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
		
		
		// 150 ids should be enough for now
		// We shoudln't need it, but we use a little bit of a buffer to filter out garbage
		new String:Split[150 + 50][64];
		new String:sTempID[21];
		
		
		// We only have an limited amount of lines we can split, we shouldn't waste this ;)
		new startindex  = 0;
		if( (startindex = StrContains(data, "<members>", true)) == -1)
		{
			startindex = 0;
		}
		
		new endindex  = strlen(data);
		if( (endindex = StrContains(data, "</members>", true)) != -1)
		{
			data[endindex] = '\0';
		}
		
		
		ExplodeString(data[startindex], "<steamID64>", Split, sizeof(Split), sizeof(Split[]));
				
		
		// Run though Communityids
		new splitsize = sizeof(Split);
		new index;
		for(new i; i < splitsize; i++)
		{
			if(strlen(Split[i]) > 0)
			{
				// If we find something we split off at the searchresult, we then then only have the steamid
				if( (index = StrContains(Split[i], "</steamID64>", true)) != -1)
				{
					Split[i][index] = '\0';
				}
				
				// No match :(
				if(MatchRegex(g_hCommunityIDRegex, Split[i]) != 1)
				{
					continue;
				}
				
				// We might have a use for this later
				strcopy(sTempID, sizeof(sTempID), Split[i]);
				
				// Add as recipient
				MessageBot_AddRecipient(sTempID);
			}
		}
		
		
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




stock AuthStringType:GetAuthIDType(String:auth[])
{
	if(MatchRegex(g_hSteamIDRegex, auth) == 1)
	{
		return AuthString_SteamID;
	}
	else if(MatchRegex(g_hCommunityIDRegex, auth) == 1)
	{
		return AuthString_CommunityID;
	}
	
	return AuthString_Unknown;
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
