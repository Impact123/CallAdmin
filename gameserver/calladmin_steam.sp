/**
 * -----------------------------------------------------
 * File        calladmin_steam.sp
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
#include <autoexecconfig>
#include <messagebot>
#include "calladmin"
#include <socket>
#include <regex>

#undef REQUIRE_PLUGIN
#include <updater>
#pragma semicolon 1
#pragma newdecls required


// This should be 128 KB which is more than enough
// x * 4 -> bytes / 1024 -> KiloBytes
#pragma dynamic 32768


#define CALLADMIN_STEAM_METHOD_AVAILABLE()      (GetFeatureStatus(FeatureType_Native, "MessageBot_SetSendMethod")      == FeatureStatus_Available)
#define SOCKET_AVAILABLE()                      (GetFeatureStatus(FeatureType_Native, "SocketCreate")                  == FeatureStatus_Available)



// Each array can have 150 items, this is hardcoded, bad things happen if you change this
#define MAX_ITEMS 150



// Global stuff
ConVar g_hVersion;

ConVar g_hSteamMethod;
bool g_bSteamMethod;


ConVar g_hSteamUsername;
char g_sSteamUsername[128];

ConVar g_hSteamPassword;
char g_sSteamPassword[128];

Handle g_hSteamIDRegex;
Handle g_hSteamIDRegex2;
Handle g_hCommunityIDRegex;


char g_sSteamIDConfigFile[PLATFORM_MAX_PATH];
char g_sGroupIDConfigFile[PLATFORM_MAX_PATH];


int g_iLastReportID;
int g_iRecipientCount;
bool g_bRecipientCountLimitReached;


enum AuthStringType
{
	AuthString_SteamID,
	AuthString_SteamID2,
	AuthString_CommunityID,
	AuthString_Unknown
}



// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_steam.txt"


public Plugin myinfo = 
{
	name = "CallAdmin: Steam module",
	author = "Impact, Popoklopsi",
	description = "The steammodule for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}





public void OnPluginStart()
{
	// Path to the SteamID list
	BuildPath(Path_SM, g_sSteamIDConfigFile, sizeof(g_sSteamIDConfigFile), "configs/calladmin_steam_steamidlist.cfg");
	
	if (!FileExists(g_sSteamIDConfigFile))
	{
		CreateSteamIDList();
	}
	
	
	// Path to the GroupID list
	BuildPath(Path_SM, g_sGroupIDConfigFile, sizeof(g_sGroupIDConfigFile), "configs/calladmin_steam_groupidlist.cfg");
	
	if (!FileExists(g_sGroupIDConfigFile))
	{
		CreateGroupIDList();
	}
	
	
	// Just for simple validation usage
	g_hSteamIDRegex     = CompileRegex("^STEAM_[0-1]{1}:[0-1]{1}:[0-9]+$");
	g_hSteamIDRegex2    = CompileRegex("^\\[U:1:[0-9]{3,11}+\\]$");
	g_hCommunityIDRegex = CompileRegex("^[0-9]{4,17}+$");
	
	
	
	// Clear the recipients
	MessageBot_ClearRecipients();
	
	// Read in all those steamids
	ParseSteamIDList();
	
	// Read in all those groupids
	ParseGroupIDList();
	

	RegConsoleCmd("sm_calladmin_steam_reload", Command_Reload);
	
	
	AutoExecConfig_SetFile("plugin.calladmin_steam");
	
	g_hVersion       = AutoExecConfig_CreateConVar("sm_calladmin_steam_version", CALLADMIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hSteamMethod   = AutoExecConfig_CreateConVar("sm_calladmin_steam_method", "0", "1 = Use Opensteamworks to send message, 0 = Use Steam Web API to send message", FCVAR_NONE);
	g_hSteamUsername = AutoExecConfig_CreateConVar("sm_calladmin_steam_username", "", "Your steam username", FCVAR_PROTECTED);
	g_hSteamPassword = AutoExecConfig_CreateConVar("sm_calladmin_steam_password", "", "Your steam password", FCVAR_PROTECTED);
	
	
	AutoExecConfig(true, "plugin.calladmin_steam");
	AutoExecConfig_CleanFile();
	
	
	g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);
	
	g_hSteamUsername.GetString(g_sSteamUsername, sizeof(g_sSteamUsername));
	HookConVarChange(g_hSteamUsername, OnCvarChanged);
	
	g_hSteamPassword.GetString(g_sSteamPassword, sizeof(g_sSteamPassword));
	HookConVarChange(g_hSteamPassword, OnCvarChanged);
	
	g_bSteamMethod = g_hSteamMethod.BoolValue;
	HookConVarChange(g_hSteamMethod, OnCvarChanged);


	if (CALLADMIN_STEAM_METHOD_AVAILABLE())
	{
		if (g_bSteamMethod)
		{
			MessageBot_SetSendMethod(SEND_METHOD_STEAMWORKS);
		}
		else
		{
			MessageBot_SetSendMethod(SEND_METHOD_ONLINEAPI);
		}
	}
}



public void OnMessageResultReceived(MessageBotResult result, MessageBotError error)
{
	static char resultString[][] = {"No error", "Error while trying to login", "Operation timed out",
	                                  "No recipients were setup prior to sending a message", "Couldn't send to any recipient"};


	if (result != RESULT_NO_ERROR)
	{
		char sSteamMethod[24];
		Format(sSteamMethod, sizeof(sSteamMethod), "%s", g_bSteamMethod ? "Steamworks" : "Web API");
		CallAdmin_LogMessage("Failed to send steam message via %s: (result: %d [%s] | error: %d)", sSteamMethod, result, resultString[result], error);
	}
}




void CreateSteamIDList()
{
	Handle hFile;
	hFile = OpenFile(g_sSteamIDConfigFile, "w");
	
	// Failed to open
	if (hFile == null)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for writing");
		SetFailState("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for writing");
	}
	
	WriteFileLine(hFile, "// List of steamids or communityids, seperated by a new line");
	WriteFileLine(hFile, "// STEAM_0:0:1");
	WriteFileLine(hFile, "// 76561197960265730");
	
	CloseHandle(hFile);
}




void ParseSteamIDList()
{
	File hFile;
	
	hFile = OpenFile(g_sSteamIDConfigFile, "r");
	
	
	// Failed to open
	if (hFile == null)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for reading");
		SetFailState("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for reading");
	}
	
	
	// Buffer must be a little bit bigger to have enough room for possible comments
	char sReadBuffer[128];

	
	int len;
	while (!IsEndOfFile(hFile) && hFile.ReadLine(sReadBuffer, sizeof(sReadBuffer)))
	{
		if (sReadBuffer[0] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}
		
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), " ", "");
		
		
		
		// Support for comments on end of line
		len = strlen(sReadBuffer);
		for (int i; i < len; i++)
		{
			if (sReadBuffer[i] == ' ' || sReadBuffer[i] == '/')
			{
				sReadBuffer[i] = '\0';
				
				break;
			}
		}
		
		
		AuthStringType type = GetAuthIDType(sReadBuffer);
		
		// Is a steamid
		if (type == AuthString_SteamID)
		{
			GetRegexSubString(g_hSteamIDRegex, 1, sReadBuffer, sizeof(sReadBuffer));
		}
		// Is a steamid2
		else if (type == AuthString_SteamID2)
		{
			GetRegexSubString(g_hSteamIDRegex, 1, sReadBuffer, sizeof(sReadBuffer));
			
			// Convert it to an steamid
			SteamID2ToSteamId(sReadBuffer, sReadBuffer, sizeof(sReadBuffer));
		}
		// Is a communityid
		else if (type == AuthString_CommunityID)
		{
			GetRegexSubString(g_hCommunityIDRegex, 1, sReadBuffer, sizeof(sReadBuffer));
		}
		// No match :(
		else
		{
			continue;
		}
		
		
		if(g_iRecipientCount >= MAX_ITEMS && !g_bRecipientCountLimitReached)
		{
			g_bRecipientCountLimitReached = true;
			CallAdmin_LogMessage("Maximum amount of %d recipients reached", MAX_ITEMS);
		}
		else
		{
			// Add as recipient
			MessageBot_AddRecipient(sReadBuffer);
			g_iRecipientCount++;
		}
	}
	
	hFile.Close();
}




void CreateGroupIDList()
{
	File hFile;
	hFile = OpenFile(g_sGroupIDConfigFile, "w");
	
	// Failed to open
	if (hFile == null)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for writing");
		SetFailState("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for writing");
	}
	
	hFile.WriteLine("// List of group names (custom group url), seperated by a new line");
	hFile.WriteLine("// Valve");
	hFile.WriteLine("// Steam");
	
	hFile.Close();
}




void ParseGroupIDList()
{
	File hFile;
	
	hFile = OpenFile(g_sGroupIDConfigFile, "r");
	
	
	// Failed to open
	if (hFile == null)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for reading");
		SetFailState("Failed to open configfile 'calladmin_steam_groupidlist.cfg' for reading");
	}
	
	
	// Buffer must be a little bit bigger to have enough room for possible comments
	char sReadBuffer[128];

	
	int len;
	while (! hFile.EndOfFile() &&  hFile.ReadLine(sReadBuffer, sizeof(sReadBuffer)))
	{
		if (sReadBuffer[0] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}
		
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), " ", "");
		
		
		
		// Support for comments on end of line
		len = strlen(sReadBuffer);
		for (int i; i < len; i++)
		{
			if (sReadBuffer[i] == ' ' || sReadBuffer[i] == '/')
			{
				sReadBuffer[i] = '\0';
				
				// Refresh the len
				len = strlen(sReadBuffer);
				
				
				break;
			}
		}
		
		
		if (len < 3 || len > 64)
		{
			continue;
		}
		
		
		// Go get them members
		FetchGroupMembers(sReadBuffer);
	}
	
	hFile.Close();
}




public void OnCvarChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_hVersion)
	{
		g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	}
	else if (cvar == g_hSteamUsername)
	{
		g_hSteamUsername.GetString(g_sSteamUsername, sizeof(g_sSteamUsername));
	}
	else if (cvar == g_hSteamPassword)
	{
		g_hSteamPassword.GetString(g_sSteamPassword, sizeof(g_sSteamPassword));
	}
	else if (cvar == g_hSteamMethod)
	{
		g_bSteamMethod = g_hSteamMethod.BoolValue;

		if (CALLADMIN_STEAM_METHOD_AVAILABLE())
		{
			if (g_bSteamMethod)
			{
				MessageBot_SetSendMethod(SEND_METHOD_STEAMWORKS);
			}
			else
			{
				MessageBot_SetSendMethod(SEND_METHOD_ONLINEAPI);
			}
		}
	}
}




public Action Command_Reload(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_calladmin_admin", ADMFLAG_BAN, false))
	{
		PrintToChat(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoAdmin");
		
		return Plugin_Handled;
	}
	
	
	// Clear the recipients
	MessageBot_ClearRecipients();
	g_iRecipientCount = 0;
	g_bRecipientCountLimitReached = false;
	
	// Read in all those steamids
	ParseSteamIDList();
	
	// Read in all those groupids
	ParseGroupIDList();

	return Plugin_Handled;
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




public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	MessageBot_SetLoginData(g_sSteamUsername, g_sSteamPassword);
	
	char sClientName[MAX_NAME_LENGTH];
	char sClientID[21];
	
	char sTargetName[MAX_NAME_LENGTH];
	char sTargetID[21];
	
	char sServerIP[16];
	int serverPort;
	char sServerName[128];
	
	CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
	serverPort = CallAdmin_GetHostPort();
	CallAdmin_GetHostName(sServerName, sizeof(sServerName));
	
	// Reporter wasn't a real client (initiated by a module)
	if (client == REPORTER_CONSOLE)
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
	
	g_iLastReportID = CallAdmin_GetReportID();
	
	char sMessage[4096];
	Format(sMessage, sizeof(sMessage), "\nNew report on server: %s (%s:%d)\nReportID: %d\nReporter: %s (%s)\nTarget: %s (%s)\nReason: %s\nJoin server: steam://connect/%s:%d\nWhen in game, type !calladmin_handle %d or /calladmin_handle %d in chat to handle this report", sServerName, sServerIP, serverPort, g_iLastReportID, sClientName, sClientID, sTargetName, sTargetID, reason, sServerIP, serverPort, g_iLastReportID, g_iLastReportID);
							 
	MessageBot_SendMessage(OnMessageResultReceived, sMessage);
}



public void CallAdmin_OnReportHandled(int client, int id)
{
	if (id != g_iLastReportID)
	{
		return;
	}
	
	char sMessage[1024];
	Format(sMessage, sizeof(sMessage), "\nLast report (%d) was handled by: %N", g_iLastReportID, client);
	
	MessageBot_SendMessage(OnMessageResultReceived, sMessage);
}



void FetchGroupMembers(const char[] groupID)
{
	// Create a new socket
	Handle Socket = SocketCreate(SOCKET_TCP, OnSocketError);
	
	
	// Optional tweaking stuff
	SocketSetOption(Socket, ConcatenateCallbacks, 4096);
	SocketSetOption(Socket, SocketReceiveTimeout, 3);
	SocketSetOption(Socket, SocketSendTimeout, 3);
	
	

	// Create a datapack
	Handle pack = CreateDataPack();
	
	
	// Buffers
	char sGroupID[64];
	strcopy(sGroupID, sizeof(sGroupID), groupID);
	
	
	// Write the data to the pack
	WritePackString(pack, sGroupID);
	
	
	// Set the pack as argument to the callbacks, so we can read it out later
	SocketSetArg(Socket, pack);
	
	
	// Connect
	SocketConnect(Socket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, "steamcommunity.com", 80);
}




public int OnSocketConnect(Handle socket, any pack)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if (SocketIsConnected(socket))
	{
		// Buffers
		char sRequestString[1024];
		char sRequestPath[512];
		char sGroupID[64 * 4];
		
		
		// Reset the pack
		ResetPack(pack, false);
		
		
		// Read data
		ReadPackString(pack, sGroupID, sizeof(sGroupID));
		
		// Close the pack
		CloseHandle(pack);
		
		
		URLEncode(sGroupID, sizeof(sGroupID));
		
		
		// Params
		Format(sRequestPath, sizeof(sRequestPath), "groups/%s/memberslistxml?xml=1", sGroupID);

		
		// Request String
		Format(sRequestString, sizeof(sRequestString), "GET /%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", sRequestPath, "steamcommunity.com");

		
		// Send the request
		SocketSend(socket, sRequestString);
	}
}




public int OnSocketReceive(Handle socket, char[] data, const int size, any pack) 
{
	if (socket != null)
	{
		static int SPLITSIZE1 = (MAX_ITEMS / 2) + 50;
		static int SPLITSIZE2 = 64;
		
		// 150 ids should be enough for now
		// We shoudln't need it, but we use a little bit of a buffer to filter out garbage
		char[][] Split = new char[SPLITSIZE1][SPLITSIZE2];
		char sTempID[21];
		
		
		// We only have an limited amount of lines we can split, we shouldn't waste this ;)
		int startindex  = 0;
		if ( (startindex = StrContains(data, "<members>", true)) == -1)
		{
			startindex = 0;
		}
		
		int endindex  = strlen(data);
		if ( (endindex = StrContains(data, "</members>", true)) != -1)
		{
			data[endindex] = '\0';
		}
		
		
		ExplodeString(data[startindex], "<steamID64>", Split, SPLITSIZE1, SPLITSIZE2);
				
		
		// Run though Communityids
		int splitsize = SPLITSIZE1;
		int index;
		for (int i; i < splitsize; i++)
		{
			if (strlen(Split[i]) > 0)
			{
				// If we find something we split off at the searchresult, we then then only have the steamid
				if ( (index = StrContains(Split[i], "</steamID64>", true)) != -1)
				{
					Split[i][index] = '\0';
				}
				
				// No match :(
				if (GetAuthIDType(Split[i]) != AuthString_CommunityID)
				{
					continue;
				}
				
				// We might have a use for this later
				strcopy(sTempID, sizeof(sTempID), Split[i]);
				
				if (g_iRecipientCount >= MAX_ITEMS && !g_bRecipientCountLimitReached)
				{
					g_bRecipientCountLimitReached = true;
					CallAdmin_LogMessage("Maximum amount of %d recipients reached", MAX_ITEMS);
				}
				else
				{
					// Add as recipient
					MessageBot_AddRecipient(sTempID);
					g_iRecipientCount++;
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




public int OnSocketDisconnect(Handle socket, any pack)
{
	if (socket != null)
	{
		CloseHandle(socket);
	}
}




public int OnSocketError(Handle socket, const int errorType, const int errorNum, any pack)
{
	CallAdmin_LogMessage("Socket Error: %d, %d", errorType, errorNum);
	
	if (socket != null)
	{
		CloseHandle(socket);
	}
}




stock AuthStringType GetAuthIDType(const char[] auth)
{
	if (MatchRegex(g_hSteamIDRegex, auth) == 1)
	{
		return AuthString_SteamID;
	}
	else if (MatchRegex(g_hSteamIDRegex2, auth) == 1)
	{
		return AuthString_SteamID2;
	}
	else if (MatchRegex(g_hCommunityIDRegex, auth) == 1)
	{
		return AuthString_CommunityID;
	}
	
	return AuthString_Unknown;
}



stock void SteamID2ToSteamId(const char[] steamID2, char[] dest, int max_len)
{
	char sTemp[21];
	strcopy(sTemp, sizeof(sTemp), steamID2);
	
	sTemp[strlen(sTemp)] = '\0';
	
	int temp = StringToInt(sTemp[5]);
	
	Format(dest, max_len, "STEAM_0:%d:%d", temp & 1, temp >> 1);
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