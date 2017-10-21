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
#include "include/autoexecconfig"
#include "include/messagebot"
#include "include/calladmin"
#include "include/socket"
#include <regex>

#undef REQUIRE_PLUGIN
#include "include/updater"
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

ConVar g_hSteamUsername;
char g_sSteamUsername[128];

ConVar g_hSteamPassword;
char g_sSteamPassword[128];

Regex g_hSteamID2Regex;
Regex g_hSteamID3Regex;
Regex g_hCommunityIDRegex;


char g_sSteamIDConfigFile[PLATFORM_MAX_PATH];
char g_sGroupIDConfigFile[PLATFORM_MAX_PATH];


int g_iLastReportID;


enum AuthStringType
{
	AuthString_SteamID2,
	AuthString_SteamID3,
	AuthString_CommunityID,
	AuthString_Unknown
}


ArrayList g_hRecipientAdt;



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
	g_hSteamID2Regex    = new Regex("^STEAM_[0-1]{1}:[0-1]{1}:[0-9]+$");
	g_hSteamID3Regex    = new Regex("^\\[U:1:[0-9]{3,11}+\\]$");
	g_hCommunityIDRegex = new Regex("^[0-9]{4,17}+$");
	
	
	g_hRecipientAdt = new ArrayList(ByteCountToCells(21));
	
	
	// Clear the recipients
	MessageBot_ClearRecipients();
	
	// Read in all those steamids
	ParseSteamIDList();
	
	// Read in all those groupids
	ParseGroupIDList();
	

	RegConsoleCmd("sm_calladmin_steam_reload", Command_Reload);
	RegConsoleCmd("sm_calladmin_steam_listrecipients", Command_ListRecipients);
	
	
	AutoExecConfig_SetFile("plugin.calladmin_steam");
	
	g_hVersion       = AutoExecConfig_CreateConVar("sm_calladmin_steam_version", CALLADMIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hSteamUsername = AutoExecConfig_CreateConVar("sm_calladmin_steam_username", "", "Your steam username", FCVAR_PROTECTED);
	g_hSteamPassword = AutoExecConfig_CreateConVar("sm_calladmin_steam_password", "", "Your steam password", FCVAR_PROTECTED);
	
	
	AutoExecConfig(true, "plugin.calladmin_steam");
	AutoExecConfig_CleanFile();
	
	
	g_hVersion.SetString(CALLADMIN_VERSION, false, false);
	g_hVersion.AddChangeHook(OnCvarChanged);
	
	g_hSteamUsername.GetString(g_sSteamUsername, sizeof(g_sSteamUsername));
	g_hSteamUsername.AddChangeHook(OnCvarChanged);
	
	g_hSteamPassword.GetString(g_sSteamPassword, sizeof(g_sSteamPassword));
	g_hSteamPassword.AddChangeHook(OnCvarChanged);
}



public void OnMessageResultReceived(MessageBotResult result, MessageBotError error)
{
	static char resultString[][] = {"No error", "Error while trying to login", "Operation timed out",
	                                  "No recipients were setup prior to sending a message", "Couldn't send to any recipient"};


	if (result != RESULT_NO_ERROR)
	{
		CallAdmin_LogMessage("Failed to send steam message: (result: %d [%s] | error: %d)", result, resultString[result], error);
	}
}




void CreateSteamIDList()
{
	File hFile;
	hFile = OpenFile(g_sSteamIDConfigFile, "w");
	
	// Failed to open
	if (hFile == null)
	{
		CallAdmin_LogMessage("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for writing");
		SetFailState("Failed to open configfile 'calladmin_steam_steamidlist.cfg' for writing");
	}
	
	hFile.WriteLine("// List of steamids or communityids, seperated by a new line");
	hFile.WriteLine("// STEAM_0:0:1");
	hFile.WriteLine("// 76561197960265730");
	
	delete hFile;
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
	while (!hFile.EndOfFile() && hFile.ReadLine(sReadBuffer, sizeof(sReadBuffer)))
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
		
		// Is a steamid2
		if (type == AuthString_SteamID2)
		{
			g_hSteamID2Regex.GetSubString(1, sReadBuffer, sizeof(sReadBuffer));
		}
		// Is a steamid3
		else if (type == AuthString_SteamID3)
		{
			g_hSteamID3Regex.GetSubString(1, sReadBuffer, sizeof(sReadBuffer));
			
			// Convert it to an steamid2
			SteamID3ToSteamId2(sReadBuffer, sReadBuffer, sizeof(sReadBuffer));
		}
		// Is a communityid
		else if (type == AuthString_CommunityID)
		{
			g_hCommunityIDRegex.GetSubString(1, sReadBuffer, sizeof(sReadBuffer));
		}
		// No match :(
		else
		{
			continue;
		}
		
		// Add as recipient
		MessageBot_AddRecipient(sReadBuffer);
		g_hRecipientAdt.PushString(sReadBuffer);
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
	
	hFile.WriteLine("// List of group names (custom group name), separated by a new line");
	hFile.WriteLine("// So for example if your community link is: http://steamcommunity.com/groups/Valve then write in a new line: Valve");
	hFile.WriteLine("// YourGroupName");
	
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
}




public Action Command_Reload(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_calladmin_admin", ADMFLAG_BAN, false))
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoAdmin");
		
		return Plugin_Handled;
	}
	
	
	// Clear the recipients
	MessageBot_ClearRecipients();
	g_hRecipientAdt.Clear();
	
	// Read in all those steamids
	ParseSteamIDList();
	
	// Read in all those groupids
	ParseGroupIDList();

	return Plugin_Handled;
}




public Action Command_ListRecipients(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_calladmin_admin", ADMFLAG_BAN, false))
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoAdmin");
		
		return Plugin_Handled;
	}
	
	int count = g_hRecipientAdt.Length;
	char sRecipientBuffer[21];
	
	if (count)
	{
		for (int i; i < count; i++)
		{
			g_hRecipientAdt.GetString(i, sRecipientBuffer, sizeof(sRecipientBuffer));
			
			ReplyToCommand(client, "Recipient %d: %s%s", i + 1, sRecipientBuffer, MessageBot_IsRecipient(sRecipientBuffer) ? "" : " (Not In Messagebot's list)");
		}
	}
	else
	{
		ReplyToCommand(client, "Recipient list is empty");
	}

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
	DataPack pack = new DataPack();
	
	
	// Buffers
	char sGroupID[64];
	strcopy(sGroupID, sizeof(sGroupID), groupID);
	
	
	// Write the data to the pack
	pack.WriteString(sGroupID);
	
	
	// Set the pack as argument to the callbacks, so we can read it out later
	SocketSetArg(Socket, pack);
	
	
	// Connect
	SocketConnect(Socket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, "steamcommunity.com", 80);
}




public int OnSocketConnect(Handle socket, DataPack pack)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if (SocketIsConnected(socket))
	{
		// Buffers
		char sRequestString[1024];
		char sRequestPath[512];
		char sGroupID[64 * 4];
		
		
		// Reset the pack
		pack.Reset(false);
		
		
		// Read data
		pack.ReadString(sGroupID, sizeof(sGroupID));
		
		// Close the pack
		delete pack;
		
		
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
		// We shoudln't need it, but we use a little bit of a buffer to filter out garbage
		static int SPLITSIZE1 = MAX_ITEMS + 50;
		static int SPLITSIZE2 = 64;
		
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
				
				// Add as recipient
				MessageBot_AddRecipient(sTempID);
				g_hRecipientAdt.PushString(sTempID);
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
	delete socket;
}




public int OnSocketError(Handle socket, const int errorType, const int errorNum, any pack)
{
	CallAdmin_LogMessage("Socket Error: %d, %d", errorType, errorNum);
	
	delete socket;
}




stock AuthStringType GetAuthIDType(const char[] auth)
{
	if (g_hSteamID2Regex.Match(auth) == 1)
	{
		return AuthString_SteamID2;
	}
	else if (g_hSteamID3Regex.Match(auth) == 1)
	{
		return AuthString_SteamID3;
	}
	else if (g_hCommunityIDRegex.Match(auth) == 1)
	{
		return AuthString_CommunityID;
	}
	
	return AuthString_Unknown;
}



stock void SteamID3ToSteamId2(const char[] steamID3, char[] dest, int max_len)
{
	char sTemp[21];
	strcopy(sTemp, sizeof(sTemp), steamID3);
	
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