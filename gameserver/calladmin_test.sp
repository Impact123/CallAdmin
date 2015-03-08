/**
 * -----------------------------------------------------
 * File        calladmin_test.sp
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
#include "calladmin"
#pragma semicolon 1
#pragma newdecls required



public Plugin myinfo = 
{
	name = "CallAdmin: Test",
	author = "Impact, Popoklopsi",
	description = "Tests the calladmin plugin",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}




public void OnPluginStart()
{
	RegConsoleCmd("calladmin_test", Command_Test);
}




public Action Command_Test(int client, int args)
{
	PrintToServer("Current trackercount: %d", CallAdmin_GetTrackersCount());
	CallAdmin_LogMessage("Loggingtest");
	
	return Plugin_Handled;
}



public Action CallAdmin_OnDrawMenu(int client)
{
	PrintToServer("The main CallAdmin client selection menu is drawn to: %N", client);
	
	return Plugin_Continue;
}



public Action CallAdmin_OnDrawOwnReason(int client)
{
	PrintToServer("An own reason menu is drawn to: %N", client);
	
	return Plugin_Continue;
}



public Action CallAdmin_OnDrawTarget(int client, int target)
{
	PrintToServer("Client %N is drawn to %N", target, client);
	
	return Plugin_Continue;
}



public void CallAdmin_OnTrackerCountChanged(int oldVal, int newVal)
{
	PrintToServer("Trackercount has changed from %d to %d", oldVal, newVal);
}



public Action CallAdmin_OnAddToAdminCount(int client)
{
	PrintToServer("Client %N is being added to admin count", client);
	
	return Plugin_Continue;
}



public Action CallAdmin_OnReportPre(int client, int target, const char[] reason)
{
	PrintToServer("%N is about to be reported by %N for %s", target, client, reason);
	
	return Plugin_Continue;
}



public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	int  id = CallAdmin_GetReportID();
	
	// Reporter wasn't a real client (initiated by a module)
	if (client == REPORTER_CONSOLE)
	{
		PrintToServer("%N (ReportID: %i) was reported by Server for %s", target, id, reason);
	}
	else
	{
		PrintToServer("%N (ReportID: %i) was reported by %N for %s", target, id, client, reason);
	}
}



public void CallAdmin_OnRequestTrackersCountRefresh(int &trackers)
{
	PrintToServer("Base plugin requested a tracker count from us");
}



public void CallAdmin_OnLogMessage(Handle plugin, const char[] message)
{
	char sPluginName[64];
	GetPluginInfo(plugin, PlInfo_Name, sPluginName, sizeof(sPluginName));
	
	PrintToServer("Plugin: %s (handle: %x) logged a message: %s", sPluginName, plugin, message);
}



public void CallAdmin_OnServerDataChanged(Handle convar, ServerData type, const char[] oldVal, const char[] newVal)
{
	PrintToServer("Convar: %x (type: %d) was changed from '%s' to '%s'", convar, type, oldVal, newVal);
}



public void CallAdmin_OnReportHandled(int client, int id)
{
	PrintToServer("ReportID: %d was handled by: %N", id, client);
}

