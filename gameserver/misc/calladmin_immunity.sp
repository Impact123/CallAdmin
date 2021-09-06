/**
 * -----------------------------------------------------
 * File        calladmin_immunity.sp
 * Authors     Impact, dordnung
 * License     GPLv3
 * Web         http://gugyclan.eu, https://dordnung.de
 * -----------------------------------------------------
 * 
 * CallAdmin
 * Copyright (C) 2013-2019 Impact, dordnung
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
#include "../scripting/include/calladmin"
#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo = 
{
	name = "CallAdmin: Immunity module",
	author = "Impact, dordnung",
	description = "Makes CallAdmin's admins immune to targeting",
	version = CALLADMIN_VERSION,
	url = "http://gugyclan.eu"
}


public Action CallAdmin_OnDrawTarget(int client, int target)
{
	if (CheckCommandAccess(target, "sm_calladmin_admin", ADMFLAG_BAN, false))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}