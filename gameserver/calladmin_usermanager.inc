/** Include guard */
#if defined _calladmin_usermanager_included
	#endinput
#endif
#define _calladmin_usermanager_included




/**
 * Returns whether a client is immune or not.
 * If a client is immune, he can't be reported.
 *
 * @param client       The Client.
 * @return             True if client is immune, false otherwise.
 */
native bool CallAdmin_IsClientImmune(int client);




/**
 * Returns whether a client is on the blacklist or not.
 * If a client is on the blacklist, he can't report players.
 *
 * @param client       The Client.
 * @return             True if client is on blacklist, false otherwise.
 */
native bool CallAdmin_IsClientOnBlacklist(int client);




/**
 * Sets whether a client is immune or not.
 * If a client is immune, he can't be reported.
 *
 * @param client       The Client.
 * @param immune       True to immune client, false otherwise.
 * @noreturn
 */
native void CallAdmin_SetClientImmune(int client, bool immune);




/**
 * Sets whether a client is in the backlist or not.
 * If a client is on the blacklist, he can't report players.
 *
 * @param client       The Client.
 * @param add          True to add client to blacklist, false to remove.
 * @noreturn
 */
native void CallAdmin_SetClientOnBlacklist(int client, bool add);




/* Do not edit below this line */
public SharedPlugin __pl_calladmin_usermanager = 
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
