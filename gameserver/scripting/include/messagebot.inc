/**
 * -----------------------------------------------------
 * File         messagebot.inc
 * Authors      David Ordnung, Impact
 * License      GPLv3
 * Web          http://dordnung.de, http://gugyclan.eu
 * -----------------------------------------------------
 *
 * Copyright (C) 2014-2018 David Ordnung, Impact
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

#if defined _messagebot_included
    #endinput
#endif

#define __messagebot_included


enum MessageBotResult
{
    RESULT_NO_ERROR,                   // Everything worked fine
    RESULT_NO_RECEIVER,                // No recipients were setup prior to sending a message
    RESULT_LOGIN_ERROR,                // Error while trying to login
    RESULT_API_ERROR,                  // Error during an API request
};

enum MessageBotOption
{
    OPTION_DEBUG,                      // Option for enable or disable debugging (def. 0)
    OPTION_WAIT_BETWEEN_MESSAGES,      // Option to set the wait time in milliseconds between messages (def. 2000)
    OPTION_WAIT_AFTER_LOGOUT,          // Option to set the wait time in milliseconds after logout (def. 5000)
    OPTION_REQUEST_TIMEOUT,            // Option to set the request timeout in seconds for CURL requests (def. 30)
    OPTION_SHUFFLE_RECIPIENTS,         // Option to enable or disable shuffling of the recipient list before sending a message (def. 0)
};


/**
 * Called when the message was queued and the result is available.
 *
 * @param result        Result code.
 * @param error         More detailed error message on failure.
 */
typeset MessageBotCB
{
    function void (MessageBotResult result, const char[] error);
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
 * Sends a message to all recipients.
 *
 * @param callback            Callback to be called when result is available.
 * @param message             Message to be sent.
 * @noreturn
 */
native void MessageBot_SendMessage(MessageBotCB callback, const char[] message);

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

/**
 * Sets a specific option.
 *
 * @param option       The option to set the value of.
 * @param value        The value to set the option to.
 *                     For boolean values use 1 for true and 0 for false.
 * @noreturn
 */
native void MessageBot_SetOption(MessageBotOption option, int value);

/**
 * Returns the current value of a specific option.
 *
 * @param option       The option to get the value of.
 * @noreturn           The current value of the option.
 *                     For boolean values 1 for true and 0 for false will be returned.
 */
native int MessageBot_GetOption(MessageBotOption option);


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
        MarkNativeAsOptional("MessageBot_IsRecipient");
        MarkNativeAsOptional("MessageBot_ClearRecipients");
        MarkNativeAsOptional("MessageBot_SetOption");
        MarkNativeAsOptional("MessageBot_GetOption");

    }
#endif