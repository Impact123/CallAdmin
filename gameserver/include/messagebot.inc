#if defined _messagebot_included
	#endinput
#endif

#define __messagebot_included

// Deprecated. There can be infinite recipients
#define MAX_RECIPIENTS 300

// Deprecated. The message can be infinite
#define MAX_MESSAGE_LENGTH 1024



enum MessageBotResult
{
	RESULT_NO_ERROR = 0,                                    // Everything worked fine
	RESULT_LOGIN_ERROR,                                     // Error while trying to login
	RESULT_TIMEOUT_ERROR,                                   // Operation timed out
	RESULT_RECIPIENTS_EMPTY,                                // No recipients were setup prior to sending a message
	RESULT_NO_RECEIVER,                                     // Couldn't send to any recipient
};


// Deprecated! Will always be zero
enum MessageBotError
{
	k_EResultUnknown = 0,                                   // Unknown error. For webapi method see your error log.
	k_EResultOK = 1,                                        // success
	k_EResultFail = 2,                                      // generic failure 
	k_EResultNoConnection = 3,                              // no/failed network connection
	//	k_EResultNoConnectionRetry = 4,                     // OBSOLETE - removed
	k_EResultInvalidPassword = 5,                           // password/ticket is invalid
	k_EResultLoggedInElsewhere = 6,                         // same user logged in elsewhere
	k_EResultInvalidProtocolVer = 7,                        // protocol version is incorrect
	k_EResultInvalidParam = 8,                              // a parameter is incorrect
	k_EResultFileNotFound = 9,                              // file was not found
	k_EResultBusy = 10,                                     // called method busy - action not taken
	k_EResultInvalidState = 11,                             // called object was in an invalid state
	k_EResultInvalidName = 12,                              // name is invalid
	k_EResultInvalidEmail = 13,                             // email is invalid
	k_EResultDuplicateName = 14,                            // name is not unique
	k_EResultAccessDenied = 15,                             // access is denied
	k_EResultTimeout = 16,                                  // operation timed out
	k_EResultBanned = 17,                                   // VAC2 banned
	k_EResultAccountNotFound = 18,                          // account not found
	k_EResultInvalidSteamID = 19,                           // steamID is invalid
	k_EResultServiceUnavailable = 20,                       // The requested service is currently unavailable
	k_EResultNotLoggedOn = 21,                              // The user is not logged on
	k_EResultPending = 22,                                  // Request is pending (may be in process, or waiting on third party)
	k_EResultEncryptionFailure = 23,                        // Encryption or Decryption failed
	k_EResultInsufficientPrivilege = 24,                    // Insufficient privilege
	k_EResultLimitExceeded = 25,                            // Too much of a good thing
	k_EResultRevoked = 26,                                  // Access has been revoked (used for revoked guest passes)
	k_EResultExpired = 27,                                  // License/Guest pass the user is trying to access is expired
	k_EResultAlreadyRedeemed = 28,                          // Guest pass has already been redeemed by account, cannot be acked again
	k_EResultDuplicateRequest = 29,                         // The request is a duplicate and the action has already occurred in the past, ignored this time
	k_EResultAlreadyOwned = 30,                             // All the games in this guest pass redemption request are already owned by the user
	k_EResultIPNotFound = 31,                               // IP address not found
	k_EResultPersistFailed = 32,                            // failed to write change to the data store
	k_EResultLockingFailed = 33,                            // failed to acquire access lock for this operation
	k_EResultLogonSessionReplaced = 34,                     //
	k_EResultConnectFailed = 35,                            //
	k_EResultHandshakeFailed = 36,                          //
	k_EResultIOFailure = 37,                                //
	k_EResultRemoteDisconnect = 38,                         //
	k_EResultShoppingCartNotFound = 39,                     // failed to find the shopping cart requested
	k_EResultBlocked = 40,                                  // a user didn't allow it
	k_EResultIgnored = 41,                                  // target is ignoring sender
	k_EResultNoMatch = 42,                                  // nothing matching the request found
	k_EResultAccountDisabled = 43,                          //
	k_EResultServiceReadOnly = 44,                          // this service is not accepting content changes right now
	k_EResultAccountNotFeatured = 45,                       // account doesn't have value, so this feature isn't available
	k_EResultAdministratorOK = 46,                          // allowed to take this action, but only because requester is admin
	k_EResultContentVersion = 47,                           // A Version mismatch in content transmitted within the Steam protocol.
	k_EResultTryAnotherCM = 48,                             // The current CM can't service the user making a request, user should try another.
	k_EResultPasswordRequiredToKickSession = 49,            // You are already logged in elsewhere, this cached credential login has failed.
	k_EResultAlreadyLoggedInElsewhere = 50,                 // You are already logged in elsewhere, you must wait
	k_EResultSuspended = 51,                                // Long running operation (content download) suspended/paused
	k_EResultCancelled = 52,                                // Operation canceled (typically by user: content download)
	k_EResultDataCorruption = 53,                           // Operation canceled because data is ill formed or unrecoverable
	k_EResultDiskFull = 54,                                 // Operation canceled - not enough disk space.
	k_EResultRemoteCallFailed = 55,                         // an remote call or IPC call failed
	k_EResultPasswordUnset = 56,                            // Password could not be verified as it's unset server side
	k_EResultPSNAccountUnlinked = 57,                       // Attempt to logon from a PS3 failed because the PSN online id is not linked to a Steam account
	k_EResultPSNTicketInvalid = 58,                         // PSN ticket was invalid
	k_EResultPSNAccountAlreadyLinked = 59,                  // PSN account is already linked to some other account, must explicitly request to replace/delete the link first
	k_EResultRemoteFileConflict = 60,                       // The sync cannot resume due to a conflict between the local and remote files
	k_EResultIllegalPassword = 61,                          // The requested new password is not legal
	k_EResultSameAsPreviousValue = 62,                      // new value is the same as the old one ( secret question and answer )
	k_EResultAccountLogonDenied = 63,                       // account login denied due to 2nd factor authentication failure
	k_EResultCannotUseOldPassword = 64,                     // The requested new password is not legal
	k_EResultInvalidLoginAuthCode = 65,                     // account login denied due to auth code invalid
	k_EResultAccountLogonDeniedNoMail = 66,                 // account login denied due to 2nd factor auth failure - and no mail has been sent
	k_EResultHardwareNotCapableOfIPT = 67,                  // 
	k_EResultIPTInitError = 68,                             // 
	k_EResultParentalControlRestrictions = 69,              // Operation failed due to parental control restrictions for current user
	k_EResultFacebookQueryError = 70,                       // Facebook query returned an error
	k_EResultExpiredLoginAuthCode = 71,                     // Expired Login Auth Code
	k_EResultIPLoginRestrictionFailed = 72,                 // IP Login Restriction Failed
	k_EResultAccountLockedDown = 73,                        // Account Locked Down
	k_EResultAccountLogonDeniedVerifiedEmailRequired = 74,  // Account Logon Denied Verified Email Required
	k_EResultNoMatchingURL = 75,                            // No matching URL
	k_EResultBadResponse = 76,                              // parse failure, missing field, etc.
	k_EResultRequirePasswordReEntry = 77,                   // The user cannot complete the action until they re-enter their password
	k_EResultValueOutOfRange = 78,                          // the value entered is outside the acceptable range
	k_EResultUnexpectedError = 79,                          // 
	k_EResultFeatureDisabled = 80,                          //
	k_EResultInvalidCEGSubmission = 81,                     //
	k_EResultRestrictedDevice = 82,                         //
	k_EResultRegionLocked = 83,                             //
	k_EResultRateLimitExceeded = 84,                        //
};


// Deprecated. Only Online API is supported.
enum MessageBotSendMethod
{
	SEND_METHOD_STEAMWORKS = 0,                             // Send through Steamworks API
	SEND_METHOD_ONLINEAPI                                   // Send through Online API
};


/**
 * Called when the message was queued and the result is available.
 *
 * @param result    Result code.
 * @param error     Error code. Deprecated. Will always be zero.
 */
typeset MessageBotReceiveCB
{
	function void (MessageBotResult result, int error);
	function void (MessageBotResult result, MessageBotError error);
};


/**
 * Sets the login data to connect to the account.
 *
 * @param steamUsername       Steam username.
 * @param steamPassword       Steam password.
 * @noreturn
 */
native void MessageBot_SetLoginData(const char[] steamUsername, const char[] steamPassword);

/**
 * Sets the method how to send a message.
 *
 * @param method              Method to send message.
 * @noreturn
 */
#pragma deprecated Does nothing.
native void MessageBot_SetSendMethod(MessageBotSendMethod method);

/**
 * Sends a message to all recipients.
 *
 * @param callback            Callback to be called when result is available.
 * @param message             Message to be sent.
 * @param showOnline          Show that bot is online?
 * @noreturn
 */
native void MessageBot_SendMessage(MessageBotReceiveCB callback, const char[] message, bool showOnline=true);

/**
 * Add an auth to the list of recipients.
 *
 * @param auth               Auth/CommunityID of the recipient.
 * @return                   True if auth didn't exist and was added to the list, false otherwise.
 */
native bool MessageBot_AddRecipient(const char[] auth);

/**
 * Remove an auth from the list of recipients.
 *
 * @param auth               Auth/CommunityID of the recipient.
 * @return                   True if auth existed and was removed from the list, false otherwise.
 */
native bool MessageBot_RemoveRecipient(const char[] auth);

/**
 * Returns whether the auth is on the recipients list.
 *
 * @param auth               Auth/CommunityID of the recipient.
 * @return                   True if auth is a recipient, false otherwise.
 */
native bool MessageBot_IsRecipient(const char[] auth);

/**
 * Clear the list of recipients.
 *
 * @noreturn
 */
native void MessageBot_ClearRecipients();


/** Do Not Edit Below This Line **/
public Extension __ext_messagebot =
{
	name = "messagebot",
	file = "messagebot.ext",

	#if defined AUTOLOAD_EXTENSIONS
		autoload = 1,
	#else
		autoload = 0,
	#endif

	#if defined REQUIRE_EXTENSIONS
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_EXTENSIONS
	public void __ext_messagebot_SetNTVOptional()
	{
		MarkNativeAsOptional("MessageBot_SetLoginData");
		MarkNativeAsOptional("MessageBot_SendMessage");
		MarkNativeAsOptional("MessageBot_AddRecipient");
		MarkNativeAsOptional("MessageBot_RemoveRecipient");
		MarkNativeAsOptional("MessageBot_ClearRecipients");
		MarkNativeAsOptional("MessageBot_SetSendMethod");
		MarkNativeAsOptional("MessageBot_IsRecipient");
	}
#endif
