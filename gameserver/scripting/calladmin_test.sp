/**
 * -----------------------------------------------------
 * File        calladmin_test.sp
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
#include "include/calladmin"
#pragma semicolon 1
#pragma newdecls required



public Plugin myinfo = 
{
	name = "CallAdmin: Test",
	author = "Impact, dordnung",
	description = "Tests the calladmin plugin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}




public void OnPluginStart()
{
	RegConsoleCmd("calladmin_test", Command_Test);
	RegConsoleCmd("sm_calladmin_test", Command_Test);
}




public Action Command_Test(int client, int args)
{
	if (!CheckCommandAccess(client, "sm_calladmin_admin", ADMFLAG_BAN, false))
	{
		ReplyToCommand(client, "\x04[CALLADMIN]\x03 %t", "CallAdmin_NoAdmin");
		
		return Plugin_Handled;
	}
	
	PrintToConsole(client, "[CallAdmin Test] Current trackercount: %d", CallAdmin_GetTrackersCount());
	
	char sServerName[128];
	CallAdmin_GetHostName(sServerName, sizeof(sServerName));
	PrintToConsole(client, "[CallAdmin Test] Current host name: %s", sServerName);
	
	char sServerIp[16];
	CallAdmin_GetHostIP(sServerIp, sizeof(sServerIp));
	PrintToConsole(client, "[CallAdmin Test] Current host ip: %s", sServerIp);
	
	int iServerPort = CallAdmin_GetHostPort();
	PrintToConsole(client, "[CallAdmin Test] Current host port: %d", iServerPort);
	
	int iReportId = CallAdmin_GetReportID();
	PrintToConsole(client, "[CallAdmin Test] Current report id: %d", iReportId);
	
	static char sReasons[][] = {"I was harassed", "I had an urge and felt like it needed to happen", "I don't like their face", "I misclicked"};
	
	if (client)
	{
		int index = GetRandomInt(0, sizeof(sReasons) -1);
		PrintToConsole(client, "[CallAdmin Test] Reporting client %N (%d) for: %s", client, client, sReasons[index]);
		
		CallAdmin_ReportClient(REPORTER_CONSOLE, client, sReasons[index]);
	}
	else
	{
		PrintToConsole(client, "[CallAdmin Test] Not in-game. Not creating a report");
	}
	
	PrintToConsole(client, "[CallAdmin Test] Logging message");
	CallAdmin_LogMessage("[CallAdmin Test] Loggingtest");
	
	
	static char forwardNames[][] = {
		"CallAdmin_OnDrawMenu",
		"CallAdmin_OnDrawOwnReason",
		"CallAdmin_OnDrawTarget",
		"CallAdmin_OnTrackerCountChanged",
		"CallAdmin_OnReportPre",
		"CallAdmin_OnReportPost",
		"CallAdmin_OnAddToAdminCount",
		"CallAdmin_OnRequestTrackersCountRefresh",
		"CallAdmin_OnServerDataChanged",
		"CallAdmin_OnLogMessage",
		"CallAdmin_OnReportHandled"
	};
	
	for (int i=0; i < sizeof(forwardNames); i++)
	{
		PrintToConsole(client, "[CallAdmin Test] Number of listeners for %s: %d", forwardNames[i], GetFunctionCountByName(forwardNames[i]));
	}
	
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		ReplyToCommand(client, "[CallAdmin Test] Check console for output");
	}
	
	return Plugin_Handled;
}


stock int GetFunctionCountByName(const char[] name, bool excludeMyself=true)
{
	Handle myself = GetMyHandle();
	Handle hIter;
	Handle hPlugin;
	Function func;
	int count;
	
	hIter = GetPluginIterator();
	
	while (MorePlugins(hIter))
	{
		hPlugin = ReadPlugin(hIter);
		
		if (
			(!excludeMyself || (excludeMyself && hPlugin != myself)) && 
			GetPluginStatus(hPlugin) == Plugin_Running
		)
		{
			if ( (func = GetFunctionByName(hPlugin, name) ) != INVALID_FUNCTION)
			{
				char sBuffer[128];
				GetPluginFilename(hPlugin, sBuffer, sizeof(sBuffer));
				PrintToCallAdminAdmins("Plugin %s has function %s", sBuffer, name);
				count++;
			}
		}
	}
	
	delete hIter;
	
	return count;
}


stock void PrintToCallAdminAdmins(const char[] format, any ...)
{
	char buffer[254];
	
	// Start from 0 because the sever shall be included
	for (int i = 0; i <= MaxClients; i++)
	{
		if (i == 0 || (IsClientInGame(i) && CheckCommandAccess(i, "sm_calladmin_admin", ADMFLAG_BAN, false)) )
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			
			PrintToConsole(i, "[CallAdmin Test] %s", buffer);
		}
	}
}


public Action CallAdmin_OnDrawMenu(int client)
{
	PrintToCallAdminAdmins("The main CallAdmin client selection menu is drawn to: %N", client);
	
	return Plugin_Continue;
}



public Action CallAdmin_OnDrawOwnReason(int client)
{
	PrintToCallAdminAdmins("An own reason menu is drawn to: %N", client);
	
	return Plugin_Continue;
}



public Action CallAdmin_OnDrawTarget(int client, int target)
{
	PrintToCallAdminAdmins("Client %N is drawn to %N", target, client);
	
	return Plugin_Continue;
}



public void CallAdmin_OnTrackerCountChanged(int oldVal, int newVal)
{
	PrintToCallAdminAdmins("Trackercount has changed from %d to %d", oldVal, newVal);
}



public Action CallAdmin_OnAddToAdminCount(int client)
{
	PrintToCallAdminAdmins("Client %N is being added to admin count", client);
	
	return Plugin_Continue;
}



public Action CallAdmin_OnReportPre(int client, int target, const char[] reason)
{
	// Reporter wasn't a real client (initiated by a module)
	if (client == REPORTER_CONSOLE)
	{
		PrintToCallAdminAdmins("%N is about to be reported by Server for: %s", target, reason);
	}
	else
	{
		PrintToCallAdminAdmins("%N is about to be reported by %N for: %s", target, client, reason);
	}
	
	return Plugin_Continue;
}



public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	int  id = CallAdmin_GetReportID();
	
	// Reporter wasn't a real client (initiated by a module)
	if (client == REPORTER_CONSOLE)
	{
		PrintToCallAdminAdmins("%N (ReportID: %i) was reported by Server for: %s", target, id, reason);
	}
	else
	{
		PrintToCallAdminAdmins("%N (ReportID: %i) was reported by %N for: %s", target, id, client, reason);
	}
}



public void CallAdmin_OnRequestTrackersCountRefresh(int &trackers)
{
	PrintToCallAdminAdmins("Base plugin requested a tracker count from us");
}



public void CallAdmin_OnLogMessage(Handle plugin, const char[] message)
{
	char sPluginName[64];
	GetPluginInfo(plugin, PlInfo_Name, sPluginName, sizeof(sPluginName));
	
	PrintToCallAdminAdmins("Plugin: %s (handle: %x) logged a message: %s", sPluginName, plugin, message);
}



public void CallAdmin_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal)
{
	PrintToCallAdminAdmins("Convar: %x (type: %d) was changed from '%s' to '%s'", convar, type, oldVal, newVal);
}



public void CallAdmin_OnReportHandled(int client, int id)
{
	PrintToCallAdminAdmins("ReportID: %d was handled by: %N", id, client);
}

