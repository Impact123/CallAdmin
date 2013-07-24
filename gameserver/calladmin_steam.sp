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
#include <regex>

#undef REQUIRE_PLUGIN
#include <updater>
#pragma semicolon 1

#undef REQUIRE_EXTENSIONS
#include <socket>



// This should be 128 KB which is more than enough
// x * 4 -> bytes / 1024 -> KiloBytes
#pragma dynamic 32768



// Each array can have 150 items, this is hardcoded, bad things happen if you change this
#define MAX_ITEMS 150
#define MAX_LISTENERS 64

// Updater
#define UPDATER_URL "http://plugins.gugyclan.eu/calladmin/calladmin_steam.txt"


// Global stuff
new g_iListeners;

new Handle:g_hVersion;

new Handle:g_hSteamUsername;
new String:g_sSteamUsername[128];

new Handle:g_hSteamPassword;
new String:g_sSteamPassword[128];

new Handle:g_hSteamSystem;
new bool:g_bSteamSystem;

new Handle:g_hSteamMagic;
new String:g_sSteamMagic[64];

new Handle:g_hSteamListenPort;
new g_iSteamListenPort;

new Handle:g_hSteamMasterIP;
new String:g_sSteamMasterIP[32];

new Handle:g_hSteamMasterPort;
new g_iSteamMasterPort;

new Handle:g_hSteamIDRegex;
new Handle:g_hCommunityIDRegex;


new String:g_sSteamIDConfigFile[PLATFORM_MAX_PATH];
new String:g_sGroupIDConfigFile[PLATFORM_MAX_PATH];

new Handle:g_hListenSocket = INVALID_HANDLE;
new Handle:g_hRelaySocket = INVALID_HANDLE;
new Handle:g_hRecipientsList = INVALID_HANDLE;




enum AuthStringType
{
	AuthString_SteamID,
	AuthString_CommunityID,
	AuthString_Unknown
}


enum Listener
{
	String:eMagicKey[64],
	Handle:eRecipients,
}


new g_Listeners[MAX_LISTENERS][Listener];






public Plugin:myinfo = 
{
	name = "CallAdmin: Steam module",
	author = "Impact, Popoklopsi, Zephyrus",
	description = "The Steammodule for CallAdmin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}






public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("GetUserMessageType");
	MarkNativeAsOptional("SocketIsConnected");
	MarkNativeAsOptional("SocketCreate");
	MarkNativeAsOptional("SocketBind");
	MarkNativeAsOptional("SocketConnect");
	MarkNativeAsOptional("SocketDisconnect");
	MarkNativeAsOptional("SocketListen");
	MarkNativeAsOptional("SocketSend");
	MarkNativeAsOptional("SocketSendTo");
	MarkNativeAsOptional("SocketSetOption");
	MarkNativeAsOptional("SocketSetReceiveCallback");
	MarkNativeAsOptional("SocketSetSendqueueEmptyCallback");
	MarkNativeAsOptional("SocketSetDisconnectCallback");
	MarkNativeAsOptional("SocketSetErrorCallback");
	MarkNativeAsOptional("SocketSetArg");
	MarkNativeAsOptional("SocketGetHostName");

	return APLRes_Success;
}



public Action:SteamTest(arg)
{
	CallAdmin_OnReportPost(0, 0, "TestReason");
	return Plugin_Handled;
}
public OnPluginStart()
{
	RegServerCmd("steamtest", SteamTest);
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
	
	
	
	AutoExecConfig_SetFile("plugin.calladmin_steam");
	
	g_hVersion       = AutoExecConfig_CreateConVar("sm_calladmin_steam_version", CALLADMIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hSteamUsername = AutoExecConfig_CreateConVar("sm_calladmin_steam_username", "", "Your steam username", FCVAR_PLUGIN|FCVAR_PROTECTED);
	g_hSteamPassword = AutoExecConfig_CreateConVar("sm_calladmin_steam_password", "", "Your steam password", FCVAR_PLUGIN|FCVAR_PROTECTED);

	g_hSteamSystem = AutoExecConfig_CreateConVar("sm_calladmin_steam_system", "1", "1=Standalone system, 0=Master-Relay System", FCVAR_PLUGIN);
	g_hSteamMagic = AutoExecConfig_CreateConVar("sm_calladmin_steam_key", "", "A Key to identify this server on the steamidlist.", FCVAR_PLUGIN|FCVAR_PROTECTED);
	g_hSteamListenPort = AutoExecConfig_CreateConVar("sm_calladmin_steam_listen_port", "0", "Only for master server: Port on which receive all reports", FCVAR_PLUGIN|FCVAR_PROTECTED);
	g_hSteamMasterIP = AutoExecConfig_CreateConVar("sm_calladmin_steam_master_ip", "", "Only for relay server: IP of the master gameserver", FCVAR_PLUGIN);
	g_hSteamMasterPort = AutoExecConfig_CreateConVar("sm_calladmin_steam_master_port", "", "Only for relay server: Listening Port of the master server", FCVAR_PLUGIN|FCVAR_PROTECTED);
	
	
	AutoExecConfig(true, "plugin.calladmin_steam");
	AutoExecConfig_CleanFile();
}




public OnConfigsExecuted()
{
	// Read the config
	SetConVarString(g_hVersion, CALLADMIN_VERSION, false, false);
	HookConVarChange(g_hVersion, OnCvarChanged);
	
	GetConVarString(g_hSteamUsername, g_sSteamUsername, sizeof(g_sSteamUsername));
	HookConVarChange(g_hSteamUsername, OnCvarChanged);
	
	GetConVarString(g_hSteamPassword, g_sSteamPassword, sizeof(g_sSteamPassword));
	HookConVarChange(g_hSteamPassword, OnCvarChanged);

	GetConVarString(g_hSteamMagic, g_sSteamMagic, sizeof(g_sSteamMagic));
	GetConVarString(g_hSteamMasterIP, g_sSteamMasterIP, sizeof(g_sSteamMasterIP));

	g_bSteamSystem = GetConVarBool(g_hSteamSystem);
	g_iSteamListenPort = GetConVarInt(g_hSteamListenPort);
	g_iSteamMasterPort = GetConVarInt(g_hSteamMasterPort);

	

	// Read in all those steamids
	ParseSteamIDList();
	
	// Read in all those groupids
	ParseGroupIDList();



	if (!g_bSteamSystem)
	{
		// We need the socket extension if we use master-relay system
		if(GetExtensionFileStatus("socket.ext") != 1)
		{
			CallAdmin_LogMessage("Failed to find running Socket extension for Master-Relay System. Falling back to Standalone System!");

			g_bSteamSystem = true;

			return;
		}

		if(g_iSteamListenPort != 0)
		{
			// Create a master socket
			if(g_hListenSocket == INVALID_HANDLE)
			{
				SetupMasterSocket();
			}
		}
		else if(g_iSteamMasterPort != 0 && strlen(g_sSteamMasterIP) > 1)
		{
			// Create a relay system here
			if(g_hRelaySocket == INVALID_HANDLE)
			{
				if (!SetupRelaySocket())
				{
					CreateTimer(30.0, Relay_Reconnect, TIMER_REPEAT);
				}
			}
		}
		else
		{
			// Falling back to normal system
			CallAdmin_LogMessage("Find incorrect settings for a Master-Relay System. Falling back to Standalone System!");

			g_bSteamSystem = true;
		}
	}
}




// Close socket on end
public OnPluginEnd()
{
	if(g_hListenSocket != INVALID_HANDLE)
	{
		CloseHandle(g_hListenSocket);
	}

	if(g_hRelaySocket != INVALID_HANDLE)
	{
		CloseHandle(g_hRelaySocket);
	}
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

	// Recipients list
	if (g_hRecipientsList == INVALID_HANDLE)
	{
		g_hRecipientsList = CreateArray(64);
	}
	
	
	// Buffer must be a little bit bigger to have enough room for possible comments
	decl String:sReadBuffer[128];
	new bool:isName;
	new Handle:current = g_hRecipientsList;

	new len;
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sReadBuffer, sizeof(sReadBuffer)))
	{
		isName = false;

		if(sReadBuffer[0] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}

		if(sReadBuffer[0] == '[')
		{
			if (g_bSteamSystem)
			{
				continue;
			}
			else
			{
				isName = true;
			}
		}
		
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), " ", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "[", "");
		
		
		// Support for comments on end of line
		len = strlen(sReadBuffer);
		for(new i; i < len; i++)
		{
			if(sReadBuffer[i] == ' ' || sReadBuffer[i] == '/' || sReadBuffer[i] == ']')
			{
				sReadBuffer[i] = '\0';
				
				break;
			}
		}


		if (isName)
		{
			if (StrEqual(g_sSteamMagic, sReadBuffer, false))
			{
				current = g_hRecipientsList;

				continue;
			}


			new bool:found = false;

			// Find equal name
			for (new i=0; i < g_iListeners; i++)
			{
				if (StrEqual(g_Listeners[i][eMagicKey], sReadBuffer, false))
				{
					current = g_Listeners[i][eRecipients];
					found = true;

					break;
				}
			}

			if (!found && g_iListeners < MAX_LISTENERS)
			{
				Format(g_Listeners[g_iListeners][eMagicKey], 64, sReadBuffer);

				current = g_Listeners[g_iListeners][eRecipients] = CreateArray(64);

				g_iListeners++;
			}

			continue;
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
		
		
		// Add to Array
		PushArrayString(current, sReadBuffer);
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
	
	WriteFileLine(hFile, "// List of group names, seperated by a new line");
	
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

	if(GetExtensionFileStatus("socket.ext") != 1)
	{
		CallAdmin_LogMessage("Failed to load GroupID list. Extension socket is missing!");

		return;
	}

	// Recipients list
	if (g_hRecipientsList == INVALID_HANDLE)
	{
		g_hRecipientsList = CreateArray(64);
	}
	
	
	// Buffer must be a little bit bigger to have enough room for possible comments
	decl String:sReadBuffer[128];
	new bool:isName;
	new Handle:current = g_hRecipientsList;
	
	new len;
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sReadBuffer, sizeof(sReadBuffer)))
	{
		if(sReadBuffer[0] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}

		if(sReadBuffer[0] == '[')
		{
			if (g_bSteamSystem)
			{
				continue;
			}
			else
			{
				isName = true;
			}
		}
		
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), " ", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "[", "");
		
		
		// Support for comments on end of line
		len = strlen(sReadBuffer);
		for(new i; i < len; i++)
		{
			if(sReadBuffer[i] == ' ' || sReadBuffer[i] == '/' || sReadBuffer[i] == ']')
			{
				sReadBuffer[i] = '\0';
				
				// Refresh the len
				len = strlen(sReadBuffer);
				
				
				break;
			}
		}


		if (isName)
		{
			if (StrEqual(g_sSteamMagic, sReadBuffer, false))
			{
				current = g_hRecipientsList;

				continue;
			}


			new bool:found = false;

			// Find equal name
			for (new i=0; i < g_iListeners; i++)
			{
				if (StrEqual(g_Listeners[i][eMagicKey], sReadBuffer, false))
				{
					current = g_Listeners[i][eRecipients];
					found = true;

					break;
				}
			}

			if (!found && g_iListeners < MAX_LISTENERS)
			{
				Format(g_Listeners[g_iListeners][eMagicKey], 64, sReadBuffer);

				current = g_Listeners[g_iListeners][eRecipients] = CreateArray(64);

				g_iListeners++;
			}
			
			continue;
		}
		
		
		if(len < 3 || len > 64)
		{
			continue;
		}
		
		
		// Go get them members
		FetchGroupMembers(sReadBuffer, current);
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
	decl String:sClientName[MAX_NAME_LENGTH];
	decl String:sClientID[21];
	
	decl String:sTargetName[MAX_NAME_LENGTH];
	decl String:sTargetID[21];
	
	decl String:sServerIP[16];
	decl String:sServerPort[16];
	decl String:sServerName[128];
	new serverPort;
	
	CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));
	serverPort = CallAdmin_GetHostPort();
	CallAdmin_GetHostName(sServerName, sizeof(sServerName));

	IntToString(serverPort, sServerPort, sizeof(sServerPort));

	
	// Reporter wasn't a real client (initiated by a module)
	if(client == REPORTER_CONSOLE || client == 0)
	{
		strcopy(sClientName, sizeof(sClientName), "Server/Console");
		strcopy(sClientID, sizeof(sClientID), "Server/Console");
	}
	else
	{
		GetClientName(client, sClientName, sizeof(sClientName));
		GetClientAuthString(client, sClientID, sizeof(sClientID));
	}

	if(target == 0)
	{
		strcopy(sTargetName, sizeof(sTargetName), "-/Console");
		strcopy(sTargetID, sizeof(sTargetID), "-/Console");
	}
	else
	{
		GetClientName(target, sTargetName, sizeof(sTargetName));
		GetClientAuthString(target, sTargetID, sizeof(sTargetID));
	}
	
	//GetClientName(target, sTargetName, sizeof(sTargetName));
	//GetClientAuthString(target, sTargetID, sizeof(sTargetID));
	
	if (g_bSteamSystem || g_hRelaySocket == INVALID_HANDLE)
	{
		SendReport(reason, sServerName, sServerIP, serverPort, sClientName, sClientID, sTargetName, sTargetID, g_sSteamMagic);
	}
	else
	{
		new iLength = strlen(g_sSteamMagic) + 640 + 9;
		new String:m_szPacket[iLength];
		new iIdx = 0;

		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, g_sSteamMagic) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, sServerName) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, sServerIP) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, sServerPort) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, sClientName) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, sClientID) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, sTargetName) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, sTargetID) + 1;
		iIdx += strcopy(m_szPacket[iIdx], iLength-iIdx, reason) + 1;

		SocketSend(g_hRelaySocket, m_szPacket, iIdx);
	}
}



SendReport(const String:sReason[], const String:sServerName[], const String:sServerIP[], iServerPort, const String:sClientName[], const String:sClientID[], const String:sTargetName[], const String:sTargetID[], const String:sKey[])
{
	new Handle:hRecipients = INVALID_HANDLE;

	// Find recipients
	if (g_bSteamSystem || StrEqual(sKey, g_sSteamMagic, false))
	{
		hRecipients = g_hRecipientsList;

	}
	else
	{
		for (new i = 0; i < g_iListeners; i++)
		{
			if (StrEqual(g_Listeners[i][eMagicKey], sKey, false))
			{
				hRecipients = g_Listeners[i][eRecipients];

				break;
			}
		}
	}


	// Add all recipients
	if (hRecipients != INVALID_HANDLE)
	{
		decl String:sMessage[4096];

		// Clear the recipients
		MessageBot_ClearRecipients();

		// Add Recipients
		decl String:buffer[128];
		new len = GetArraySize(hRecipients);

		for(new i=0; i < len; i++)
		{
			GetArrayString(hRecipients, i, buffer, sizeof(buffer));
			MessageBot_AddRecipient(buffer);
		}

		Format(sMessage, sizeof(sMessage), "\nNew report on server: %s (%s:%d)\nReporter: %s (%s)\nTarget: %s (%s)\nReason: %s", sServerName, sServerIP, iServerPort, sClientName, sClientID, sTargetName, sTargetID, sReason);

		MessageBot_SetLoginData(g_sSteamUsername, g_sSteamPassword);
		MessageBot_SendMessage(OnMessageResultReceived, sMessage);
	}
}




SetupMasterSocket()
{
	decl String:sServerIP[16];
	
	CallAdmin_GetHostIP(sServerIP, sizeof(sServerIP));


	g_hListenSocket = SocketCreate(SOCKET_TCP, Master_SocketError);

	if(!SocketBind(g_hListenSocket, sServerIP, g_iSteamListenPort))
	{
		CallAdmin_LogMessage("Failed to bind socket to %s:%d", sServerIP, g_iSteamListenPort);
		CloseHandle(g_hListenSocket);

		return;
	}

	SocketListen(g_hListenSocket, Master_SocketIncoming);
}


public Master_SocketIncoming(Handle:socket, Handle:newSocket, String:remoteIP[], remotePort, any:data)
{
	SocketSetReceiveCallback(newSocket, Master_ChildSocketReceive);
	SocketSetDisconnectCallback(newSocket, Master_ChildSocketDisconnected);
	SocketSetErrorCallback(newSocket, Master_ChildSocketError);
}


public Master_ChildSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:data)
{
	new iTerminators = 0;

	decl String:sMagic[64];
	decl String:sServerName[128];
	decl String:sServerIP[16];
	decl String:sServerPort[16];
	decl String:sClientName[64];
	decl String:sClientID[32];
	decl String:sTargetName[64];
	decl String:sTargetID[32];
	decl String:sReason[256];


	for(new i=0; i < dataSize; ++i)
	{
		if(receiveData[i] == 0)
		{
			++iTerminators;
		}
	}

	if(iTerminators != 9)
	{
		return;
	}


	new iIdx = 0;

	strcopy(sMagic, sizeof(sMagic), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sServerName, sizeof(sServerName), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sServerIP, sizeof(sServerIP), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sServerPort, sizeof(sServerPort), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sClientName, sizeof(sClientName), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sClientID, sizeof(sClientID), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sTargetName, sizeof(sTargetName), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sTargetID, sizeof(sTargetID), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;
	strcopy(sReason, sizeof(sReason), receiveData[iIdx]);
	iIdx += strlen(receiveData[iIdx]) + 1;


	// Send the report
	SendReport(sReason, sServerName, sServerIP, StringToInt(sServerPort), sClientName, sClientID, sTargetName, sTargetID, sMagic);
}


public Master_ChildSocketDisconnected(Handle:socket, any:hRecipients)
{
	CloseHandle(socket);
}


public Master_ChildSocketError(Handle:socket, const errorType, const errorNum, any:data)
{
	CallAdmin_LogMessage("Relay server socket error %d (errno %d)", errorType, errorNum);

	CloseHandle(socket);
}


public Master_SocketError(Handle:socket, const errorType, const errorNum, any:data)
{
	CallAdmin_LogMessage("Master socket error %d (errno %d)", errorType, errorNum);
	g_hListenSocket = INVALID_HANDLE;

	CloseHandle(socket);
}




bool:SetupRelaySocket()
{
	g_hRelaySocket = SocketCreate(SOCKET_TCP, Relay_SocketError);

	SocketConnect(g_hRelaySocket, Relay_SocketConnected, Relay_SocketReceive, Relay_SocketDisconnected, g_sSteamMasterIP, g_iSteamMasterPort);

	if (g_hRelaySocket == INVALID_HANDLE || !SocketIsConnected(g_hRelaySocket))
	{
		return false;
	}

	return true;
}


public Relay_SocketConnected(Handle:socket, any:data)
{
}


public Relay_SocketReceive(Handle:socket, String:receiveData[], const dataSize, any:data)
{
}


public Relay_SocketDisconnected(Handle:socket, any:data)
{
	CallAdmin_LogMessage("Stopped relaying reports. Maybe master Server is down? Trying to reconnect...");
	g_hRelaySocket = INVALID_HANDLE;

	CloseHandle(socket);

	CreateTimer(30.0, Relay_Reconnect, TIMER_REPEAT);
}


public Relay_SocketError(Handle:socket, const errorType, const errorNum, any:data)
{
	CallAdmin_LogMessage("Relay socket error %d (errno %d). Trying to reconnect...", errorType, errorNum);

	g_hRelaySocket = INVALID_HANDLE;

	CloseHandle(socket);


	CreateTimer(30.0, Relay_Reconnect);
}


public Action:Relay_Reconnect(Handle:timer, any:data)
{
	if(g_iSteamMasterPort != 0 && strlen(g_sSteamMasterIP) > 1)
	{
		// Create a new relay system here
		if(g_hRelaySocket == INVALID_HANDLE)
		{
			if (SetupRelaySocket())
			{
				CallAdmin_LogMessage("Relay socket is connected again!");

				return Plugin_Stop;
			}
		}
	}

	return Plugin_Continue;
}




FetchGroupMembers(String:groupID[], Handle:current)
{
	// Create a new socket
	new Handle:Socket = SocketCreate(SOCKET_TCP, OnSocketError);
	
	
	// Optional tweaking stuff
	SocketSetOption(Socket, ConcatenateCallbacks, 4096);
	SocketSetOption(Socket, SocketReceiveTimeout, 3);
	SocketSetOption(Socket, SocketSendTimeout, 3);
	
	

	// Create a array
	new Handle:array = CreateArray(64, 2);
	
	
	// Buffers
	decl String:sGroupID[64];
	strcopy(sGroupID, sizeof(sGroupID), groupID);
	
	
	// Write the data to the array
	PushArrayString(array, sGroupID);
	PushArrayCell(array, current);
	
	
	// Set the array as argument to the callbacks, so we can read it out later
	SocketSetArg(Socket, array);
	
	
	// Connect
	SocketConnect(Socket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, "steamcommunity.com", 80);
}




public OnSocketConnect(Handle:socket, any:array)
{
	// If socket is connected, should be since this is the callback that is called if it is connected
	if(SocketIsConnected(socket))
	{
		// Buffers
		decl String:sRequestString[1024];
		decl String:sRequestPath[512];
		decl String:sGroupID[64];
		
		new Handle:current;

		
		// Read data
		GetArrayString(array, 0, sGroupID, sizeof(sGroupID));
		current = GetArrayCell(array, 1);

		// Close the array
		CloseHandle(array);
		
		
		URLEncode(sGroupID, sizeof(sGroupID));
		
		
		// Params
		Format(sRequestPath, sizeof(sRequestPath), "groups/%s/memberslistxml", sGroupID);

		
		// Request String
		Format(sRequestString, sizeof(sRequestString), "GET /%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", sRequestPath, "steamcommunity.com");

		
		// Send the request
		SocketSetArg(socket, current);
		SocketSend(socket, sRequestString);
	}
}




public OnSocketReceive(Handle:socket, String:data[], const size, any:current) 
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
				
				// Add to array
				PushArrayString(current, sTempID);
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