/** Include guard */
#if defined _calladmin_included
	#endinput
#endif
#define _calladmin_included




/** Global calladmin version, do not change */
#define CALLADMIN_VERSION	"0.1.8"



/** Pass this as a clientindex to the ReportPlayer native if you don't have a client, eg report from server automatically */
#define REPORTER_CONSOLE 1679124


/** Maximum size a reason string can be in length */
#define REASON_MAX_LENGTH 128



/**
 * Called when the main CallAdmin client selection menu is about to be drawn for a client.
 * Note: CallAdmin will not notify players why or if their menu was blocked.
 *
 * @param client        Client index of the caller.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action CallAdmin_OnDrawMenu(int client);




/**
 * Called when the own reason selection is enabled and the select item for it is about to be drawn for a client.
 *
 * @param client        Client index of the caller.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action CallAdmin_OnDrawOwnReason(int client);




/**
 * Called when a target is about to be drawn to the target selection menu for a client.
 * Note: Called *n-1 times for the client selection menu where n is the amount of valid targets including the caller.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target about to be drawn.
 * @return              Plugin_Continue to allow the target to be drawn, Plugin_Handled otherwise.
 */
forward Action CallAdmin_OnDrawTarget(int client, int target);




/**
 * Called when the tracker count was changed.
 *
 * @param oldVal        Tracker count before update.
 * @param newVal        Tracker count after update.
 * @noreturn
 */
forward void CallAdmin_OnTrackerCountChanged(int oldVal, int newVal);




/**
 * Called before a client (or module) has reported another client.
 * Be sure to check that client != REPORTER_CONSOLE if you expect a valid client index.
 * Note: CallAdmin will not notify players why or if their report was blocked.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Reason selected by the client for the report.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action CallAdmin_OnReportPre(int client, int target, const char[] reason);




/**
 * Called after a client (or module) has reported another client.
 * Be sure to check that client != REPORTER_CONSOLE if you expect a valid client index.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Reason selected by the client for the report.
 * @noreturn
 */
forward void CallAdmin_OnReportPost(int client, int target, const char[] reason);




/**
 * Initiates a report call.
 * If you report automatically (via a module for example) set the client index to REPORTER_CONSOLE.
 *
 * @param client        Client index of the caller.
 * @param target        Client index of the target.
 * @param reason        Reason for the report.
 * @return              True if target could be reported, false otherwise.
 */
native bool CallAdmin_ReportClient(int client, int target, const char[] reason);




/**
 * Called when an admin is about to be added to the in-game admin count.
 *
 * @param client        Client index of the admin.
 * @return              Plugin_Continue to allow, Plugin_Handled otherwise.
 */
forward Action CallAdmin_OnAddToAdminCount(int client);




/**
 * Returns the cached count of current trackers.
 *
 * @return              Count of current trackers.
 */
native int CallAdmin_GetTrackersCount();




/**
 * Requests a forced refresh of the trackers count.
 * Note that most modules work asynchronous and only return their own cached count.
 *
 * @noreturn
 */
native void CallAdmin_RequestTrackersCountRefresh();




/**
 * Called when the trackercount of a module is requested.
 * This is either called periodically via the base calladmin, or when RequestTrackersCountRefresh is invoked.
 *
 * @param trackers      By ref value of your trackers.
 * @noreturn
 */
forward void CallAdmin_OnRequestTrackersCountRefresh(int &trackers);




enum ServerData
{
	ServerData_HostName,     /**< This is the hostname of the server, gathered from the `hostname` convar */
	ServerData_HostIP,       /**< This is the hostip of the server, gathered and converted from the `hostip` convar */
	ServerData_HostPort      /**< This is the hostport of the server, gathered from the `hostport` convar */
};




/**
 * Called when the serverdata data is changed.
 *
 * @param convar       Handle to the convar which was changed.
 * @param type         Type of data which was changed.
 * @param oldVal       Value of data before change.
 * @param newVal       Value of data after change.
 * @noreturn
 */
forward void CallAdmin_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal);




/**
 * Returns the server's hostname.
 *
 * @param buffer        String to copy hostname to.
 * @param max_size      Maximum size of buffer.
 * @noreturn
 */
native void CallAdmin_GetHostName(char[] buffer, int max_size);




/**
 * Returns the server's Ip String.
 *
 * @param buffer        String to copy hostip to.
 * @param max_size      Maximum size of buffer.
 * @noreturn
 */
native void CallAdmin_GetHostIP(char[] buffer, int max_size);




/**
 * Returns the server's port.
 *
 * @return              Port of the server.
 */
native int CallAdmin_GetHostPort();




/**
 * Logs a message to the calladmin logfile.
 * The message has this format "[Pluginname] Message", where the plugin name is detected automatically.
 *
 * @param format        Formatting rules.
 * @param ...           Variable number of format parameters.
 * @noreturn
 */
native void CallAdmin_LogMessage(const char[] format, any ...);




/**
 * Called when a message was logged to the calladmin logfile.
 *
 * @param plugin       Handle to the plugin which logged the message.
 * @param message      Message that was logged.
 * @noreturn
 */
forward void CallAdmin_OnLogMessage(Handle plugin, const char[] message);




/**
 * Returns the server's current report id.
 * This is a temporary value and is increased with each successfull report.
 *
 * @return      Current report id of the server.
 */
native int CallAdmin_GetReportID();




/**
 * Called when a report was handled.
 *
 * @param client       Admin who handled the report.
 * @param id           Id of the handled report.
 * @noreturn
 */
forward void CallAdmin_OnReportHandled(int client, int id);




/* Do not edit below this line */
public SharedPlugin __pl_calladmin = 
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
