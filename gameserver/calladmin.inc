#if defined _calladmin_included
	#endinput
#endif
#define _calladmin_included




// Do not touch
#define CALLADMIN_VERSION	"0.1.2A"



// Pass this as a clientindex to the ReportPlayer native if you don't have a client, eg report from server automatically
#define REPORTER_CONSOLE 1679124




/**
 * Called when the main CallAdmin client selection menu is about to be drawn for a client.
 *
 * @param client        Client index of the caller.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnDrawMenu(client);




/**
 * Called when own reason selection is enabled and the select item for it is about to be drawn for a client.
 *
 * @param client        Client index of the caller.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnDrawOwnReason(client);




/**
 * Called when an client is about to be drawn as to the target selection menu for an client.
 * Note: Called *n-1 times for the client selection menu where n is the amount of valid players including the caller.
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
 * Called before an client (or module) has reported another player.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Reason selected by the client for the report.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnReportPre(client, target, const String:reason[]);




/**
 * Called after an client (or module) has reported another player.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Reason selected by the client for the report.
 * @noreturn
 */
forward CallAdmin_OnReportPost(client, target, const String:reason[]);




/**
 * Initiates an report call.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Reason for the report.
 * @return              True if target could be reported, false otherwise.
 */
native bool:CallAdmin_ReportClient(client, target, const String:reason[]);




/**
 * Called when an admin is  about to be added to the inGame admincount.
 *
 * @param client        Client index of the admin.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnAddToAdminCount(client);




/**
 * Returns the cached count of current trackers.
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




/**
 * Called when the trackercount of a module is requested.
 * Note: This is a pseudo forward (it's a function call)
 *
 * @param trackers      By ref value of your trackers.
 * @noreturn
 */
forward CallAdmin_OnRequestTrackersCountRefresh(&trackers);




/**
 * Called when the serverdata data is changed.
 *
 * @param convar       Handle to the convar which was changed.
 * @param type         Type of data which was changed.
 * @param oldVal       Value of data before change.
 * @param newVal       Value of data after change.
 * @noreturn
 */
forward CallAdmin_OnServerDataChanged(Handle:convar, ServerData:type, const String:oldVal[], const String:newVal[]);




enum ServerData
{
	ServerData_HostName,
	ServerData_HostIP,
	ServerData_HostPort
}



/**
 * Returns the servers hostname.
 *
 * @param buffer        String to copy hostname to
 * @param max_size      Maximum size of buffer
 * @noreturn
 */
native CallAdmin_GetHostName(String:buffer[], max_size);




/**
 * Returns the servers IP String.
 *
 * @param buffer        String to copy hostip to
 * @param max_size      Maximum size of buffer
 * @noreturn
 */
native CallAdmin_GetHostIP(String:buffer[], max_size);




/**
 * Returns the servers HostPort.
 *
 * @return              Hostport
 */
native CallAdmin_GetHostPort();





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
	MarkNativeAsOptional("CallAdmin_GetHostName");
	MarkNativeAsOptional("CallAdmin_GetHostIP");
	MarkNativeAsOptional("CallAdmin_GetHostPort");
	MarkNativeAsOptional("CallAdmin_ReportClient");
}
#endif
