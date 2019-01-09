/**
 * -----------------------------------------------------
 * File        calladmin_block.sp
 * Authors     Impact
 * License     GPLv3
 * Web         http://gugy.eu
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2017 Impact
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
#include <regex>
#include "include/calladmin"
#pragma semicolon 1
#pragma newdecls required


ArrayList g_hBlockedPlayers;


public Plugin myinfo = 
{
	name = "CallAdmin: Block",
	author = "Impact",
	description = "Blocks players from using CallAdmin's menu",
	version = "0.0.1",
	url = "http://gugy.eu"
}



public void OnPluginStart()
{
	g_hBlockedPlayers = new ArrayList(ByteCountToCells(21));
	
	RegAdminCmd("sm_calladmin_block_add", CommandBlockAdd, ADMFLAG_BAN);
	RegAdminCmd("sm_calladmin_block_remove", CommandBlockRemove, ADMFLAG_BAN);
	RegAdminCmd("sm_calladmin_block_list", CommandBlockList, ADMFLAG_BAN);
}



public Action CommandBlockAdd(int client, int args)
{
	char buf[21];
	GetCmdArgString(buf, sizeof(buf));
	StripQuotes (buf);
	
	if (!SimpleRegexMatch(buf, "^STEAM_\\d:\\d:\\d+$"))
	{
		ReplyToCommand(client, "Given steam id %s is invalid", buf);
		return Plugin_Handled;
	}
	
	if (g_hBlockedPlayers.FindString(buf) == -1)
	{
		g_hBlockedPlayers.PushString(buf);
		ReplyToCommand(client, "Steam id %s was added to the list", buf);
	}
	else
	{
		ReplyToCommand(client, "Steam id %s was already in the list", buf);
	}
	
	return Plugin_Handled;
}



public Action CommandBlockRemove(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "Command expects 1 argument");
		return Plugin_Handled;
	}
	
	char buf[21];
	GetCmdArg(1, buf, sizeof(buf));
	
	int count = g_hBlockedPlayers.Length;
	int index = StringToInt(buf);

	if (index < 0 || index >= count)
	{
		ReplyToCommand(client, "No id found for index %d", index);
		return Plugin_Handled;
	}
	
	g_hBlockedPlayers.GetString(index, buf, sizeof(buf));
	g_hBlockedPlayers.Erase(index);
	ReplyToCommand(client, "Steam id %s was removed", buf);
	
	return Plugin_Handled;
}



public Action CommandBlockList(int client, int args)
{
	int count = g_hBlockedPlayers.Length;
	char sBuffer[21];
	
	if (count == 0)
	{
		ReplyToCommand(client, "No blocked players in list");
		return Plugin_Handled;
	}
	
	for (int i; i < count; i++)
	{
		g_hBlockedPlayers.GetString(i, sBuffer, sizeof(sBuffer));
		ReplyToCommand(client, "%d: %s", i, sBuffer);
	}
	
	
	return Plugin_Handled;
}



public Action CallAdmin_OnDrawMenu(int client)
{
	char sAuth[21];
	
	if (!GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth)))
	{
		return Plugin_Continue;
	}
	
	if (g_hBlockedPlayers.FindString(sAuth) != -1)
	{
		ReplyToCommand(client, "You have been blocked from using CallAdmin");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

