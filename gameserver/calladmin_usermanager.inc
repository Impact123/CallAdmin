#if defined _calladmin_usermanager_included
	#endinput
#endif
#define _calladmin_usermanager_included






/**
 * Returns whether a client is immune from reports or not.
 *
 * @param client       The Client.
 * @return             True if client is immune, otherwise false.
 */
native bool:CallAdmin_IsClientImmune(client);




/**
 * Returns whether a client is on blacklist, so he can't report anyone, or not.
 *
 * @param client       The Client.
 * @return             True if client is on blacklist, otherwise false.
 */
native bool:CallAdmin_IsClientOnBlacklist(client);




/**
 * Sets the Immune state of a client.
 *
 * @param client       The Client.
 * @param SetState     True to immune client, otherwise false.
 * @noreturn
 */
native CallAdmin_SetClientImmune(client, bool:SetState);




/**
 * Sets the blacklist state of a client.
 *
 * @param client       The Client.
 * @param SetState     True to set client on blacklist client, otherwise false.
 * @noreturn
 */
native CallAdmin_SetClientOnBlacklist(client, bool:SetState);





/* Do not edit below this line */
public SharedPlugin:__pl_calladmin_usermanager = 
{
	name = "calladmin_usermanager",
	file = "calladmin_usermanager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};




#if !defined REQUIRE_PLUGIN
public __pl_calladmin_SetNTVOptional()
{
	MarkNativeAsOptional("CallAdmin_SetClientOnBlacklist");
	MarkNativeAsOptional("CallAdmin_SetClientImmune");
	MarkNativeAsOptional("CallAdmin_IsClientOnBlacklist");
	MarkNativeAsOptional("CallAdmin_IsClientImmune");
}
#endif
