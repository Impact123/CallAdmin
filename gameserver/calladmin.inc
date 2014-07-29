/** Include guard */
#if defined _calladmin_included
	#endinput
#endif
#define _calladmin_included




/** Global calladmin version, do not change */
#define CALLADMIN_VERSION	"0.1.4"



/** Pass this as a clientindex to the ReportPlayer native if you don't have a client, eg report from server automatically */
#define REPORTER_CONSOLE 1679124


/** Maximum size a reason string can be in length */
#define REASON_MAX_LENGTH 128



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
 * Called when an client is about to be drawn to the target selection menu for an client.
 * Note: Called *n-1 times for the client selection menu where n is the amount of valid targets including the caller.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target about to be drawed.
 * @return              Plugin_Continue to allow the target to be drawn, Plugin_Handled otherwise.
 */
forward Action:CallAdmin_OnDrawTarget(client, target);




/**
 * Called when the trackercount was changed.
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
 * Be sure to check that client != REPORTER_CONSOLE if you expect a valid client index.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Reason selected by the client for the report.
 * @noreturn
 */
forward CallAdmin_OnReportPost(client, target, const String:reason[]);




/**
 * Initiates an report call.
 * If you report automatically (via a module for example) set the clientindex to REPORTER_CONSOLE
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
 * Note that most module's work asynchronous and only return their own cached count.
 *
 * @noreturn
 */
native CallAdmin_RequestTrackersCountRefresh();




/**
 * Called when the trackercount of a module is requested.
 * This is either called periodically via the base calladmin or when RequestTrackersCountRefresh is invoked.
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
	ServerData_HostName,     /**< This is the hostname of the server, gathered from the `hostname` convar */
	ServerData_HostIP,       /**< This is the hostip of the server, gathered and converted from the `hostip` convar */
	ServerData_HostPort      /**< This is the hostport of the server, gathered from the `hostport` convar */
};



/**
 * Returns the servers hostname.
 *
 * @param buffer        String to copy hostname to.
 * @param max_size      Maximum size of buffer.
 * @noreturn
 */
native CallAdmin_GetHostName(String:buffer[], max_size);




/**
 * Returns the servers IP String.
 *
 * @param buffer        String to copy hostip to.
 * @param max_size      Maximum size of buffer.
 * @noreturn
 */
native CallAdmin_GetHostIP(String:buffer[], max_size);




/**
 * Returns the servers HostPort.
 *
 * @return              Hostport.
 */
native CallAdmin_GetHostPort();




/**
 * Logs a message to the calladmin logfile.
 * The message has this format "[Pluginname] Message", where the pluginname is gathered automatically.
 *
 * @param format        Formatting rules.
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native CallAdmin_LogMessage(const String:format[], any:...);




/**
 * Called when a message was logged to the calladmin logfile.
 *
 * @param plugin       Handle to the plugin which logged a message.
 * @param message      Message which was logged.
 * @noreturn
 */
forward CallAdmin_OnLogMessage(Handle:plugin, const String:message[]);




/**
 * Returns the servers current report id.
 * This is a temporary value and is increased with each report.
 *
 * @return      Current report id of the server.
 */
native CallAdmin_GetReportID();




/**
 * Called when a report was handled.
 *
 * @param client       Admin who handled the report.
 * @param id           ID of the handled report.
 * @noreturn
 */
forward CallAdmin_OnReportHandled(client, id);




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
	MarkNativeAsOptional("CallAdmin_LogMessage");
	MarkNativeAsOptional("CallAdmin_GetReportID");
}
#endif
