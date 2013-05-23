#if defined _calladmin_usermanager_included
	#endinput
#endif
#define _calladmin_usermanager_included






/**
 * Returns whether a client is immune or not.
 * If a client is immune, he can't be reported.
 *
 * @param client       The Client.
 * @return             True if client is immune, otherwise false.
 */
native bool:CallAdmin_IsClientImmune(client);




/**
 * Returns whether a client is on the blacklist or not.
 * If a client is on the blacklist, he can't report players.
 *
 * @param client       The Client.
 * @return             True if client is on blacklist, otherwise false.
 */
native bool:CallAdmin_IsClientOnBlacklist(client);




/**
 * Sets whether a client is immune or not.
 * If a client is immune, he can't be reported.
 *
 * @param client       The Client.
 * @param immune       True to immune client, otherwise false.
 * @noreturn
 */
native CallAdmin_SetClientImmune(client, bool:immune);




/**
 * Adds or removes a client to/from blacklist.
 * If a client is on the blacklist, he can't report players.
 *
 * @param client       The Client.
 * @param add          True to add client to blacklist, false to remove.
 * @noreturn
 */
native CallAdmin_SetClientOnBlacklist(client, bool:add);





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
