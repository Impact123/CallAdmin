#if defined _calladmin_included
	#endinput
#endif
#define _calladmin_included




/**
 * Called when own reason is enabled and the selection for it is about to be drawn for an client.
 *
 * @param client        Client index of the caller.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnDrawOwnReason(client);



/**
 * Called when the target selection menu for an client is about to be drawn for an client.
 * Note: Called *n-1 times for each selection where n is the amount of valid players.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target about to be drawed.
 * @return              Plugin_Continue to allow the target to be drawn, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnDrawTarget(client, target);




/**
 * Called when the trackercount was Changed.
 *
 * @param oldVal        Trackercount before update.
 * @param newVal        Trackercount after update.
 * @noreturn
 */
forward CallAdmin_OnTrackerCountChanged(oldVal, newVal);




/**
 * Called after an client has reported an player and the report was sent to the database.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Raw reason selected by the client for the report.
 * @param reason        Sanitized reason selected by the client for the report.
 * @noreturn
 */
forward CallAdmin_OnReportPost(client, target, const String:reasonRaw[], const String:reasonSanitized[]);




/**
 * Called when this player is added to the inGame admincount.
 *
 * @param client        Client index of the admin.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnAddToAdminCount(client);




/**
 * Retrieves the count of current trackers.
 *
 * @return              Count of current trackers.
 */
native CallAdmin_GetTrackersCount();




/**
 * Requests an forced refresh of the trackers count.
 *
 * @noreturn
 */
native CallAdmin_RequestTrackersCountRefresh();




/* 
	To be implemented 
	------------------
*/
// Callen when the client executes the sm_call command, we can block this per client
//forward CallAdmin_OnReportPre();





/* Do not edit below this line */
public SharedPlugin:__pl_calladmin = 
{
	name = "calladmin",
	file = "calladmin.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};




#if !defined REQUIRE_PLUGIN
public __pl_calladmin_SetNTVOptional()
{
	MarkNativeAsOptional("CallAdmin_GetTrackersCount");
	MarkNativeAsOptional("CallAdmin_RequestTrackersCountRefresh");
}
#endif
