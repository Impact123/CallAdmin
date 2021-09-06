#include <sourcemod>
#include "../scripting/include/calladmin"
#include "include/discord.inc"

#define PLUGIN_VERSION "1.1.2"

#define REPORT_MSG "{\"username\":\"{BOTNAME}\", \"content\":\"{MENTION} When in game, type !calladmin_handle {REPORT_ID} or /calladmin_handle {REPORT_ID} in chat to handle this report\",\"attachments\": [{\"color\": \"{COLOR}\",\"title\": \"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT})\",\"fields\": [{\"title\": \"Reason\",\"value\": \"{REASON}\",\"short\": true},{\"title\": \"Reporter\",\"value\": \"{REPORTER_NAME} ({REPORTER_ID})\",\"short\": true},{\"title\": \"Target\",\"value\": \"{TARGET_NAME} ({TARGET_ID})\",\"short\": true},{\"title\": \"Report Id\",\"value\": \"{REPORT_ID}\",\"short\": true}]}]}"
#define HANDLE_MSG "{\"username\":\"{BOTNAME}\", \"content\":\"{MENTION} Last report ({REPORT_ID}) was handled by: {HANDLER_NAME}\",\"attachments\": [{\"color\": \"{COLOR}\",\"title\": \"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT})\",\"fields\": [{\"title\": \"Report Id\",\"value\": \"{REPORT_ID}\",\"short\": true},{\"title\": \"Handler\",\"value\": \"{HANDLER_NAME}\",\"short\": true}]}]}"

char g_sHostPort[6];
char g_sServerName[256];
char g_sHostIP[16];

ConVar g_cBotName = null;
ConVar g_cColor = null;
ConVar g_cColor3 = null;
ConVar g_cMention = null;
ConVar g_cRemove = null;
ConVar g_cRemove2 = null;
ConVar g_cWebhook = null;

int g_iLastReportID;

public Plugin myinfo = 
{
	name = "Discord: CallAdmin",
	author = ".#Zipcore, Impact",
	description = "",
	version = PLUGIN_VERSION,
	url = "www.zipcore.net"
}

public void OnPluginStart()
{
	CreateConVar("discord_calladmin_version", PLUGIN_VERSION, "Discord CallAdmin version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_cBotName = CreateConVar("discord_calladmin_botname", "", "Report botname, leave this blank to use the webhook default name.");
	g_cColor = CreateConVar("discord_calladmin_color", "#ff2222", "Discord/Slack attachment color used for reports.");
	g_cColor3 = CreateConVar("discord_calladmin_color3", "#ff9911", "Discord/Slack attachment color used for admin reports.");
	g_cMention = CreateConVar("discord_calladmin_mention", "@here", "This allows you to mention reports, leave blank to disable.");
	g_cRemove = CreateConVar("discord_calladmin_remove", " | By PulseServers.com", "Remove this part from servername before sending the report.");
	g_cRemove2 = CreateConVar("discord_calladmin_remove2", "3kliksphilip.com | ", "Remove this part from servername before sending the report.");
	g_cWebhook = CreateConVar("discord_calladmin_webhook", "calladmin", "Config key from configs/discord.cfg.");
	
	AutoExecConfig(true, "discord_calladmin");
}

public void OnAllPluginsLoaded()
{
	if (!LibraryExists("calladmin"))
	{
		SetFailState("CallAdmin not found");
		return;
	}
	
	UpdateIPPort();
	CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}


public void OnConfigsExecuted()
{
	UpdateIPPort();
	CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}


void UpdateIPPort()
{
	Format(g_sHostPort, sizeof(g_sHostPort), "%d", CallAdmin_GetHostPort());
	CallAdmin_GetHostIP(g_sHostIP, sizeof(g_sHostIP));
}

public void CallAdmin_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal)
{
	if (type == ServerData_HostName)
		CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}


public void CallAdmin_OnReportHandled(int client, int id)
{
	if (id != g_iLastReportID)
	{
		return;
	}
	
	
	char sMSG[4096] = HANDLE_MSG;
	
	char sBot[512];
	g_cBotName.GetString(sBot, sizeof(sBot));
	ReplaceString(sMSG, sizeof(sMSG), "{BOTNAME}", sBot);
	
	char sMention[512];
	g_cMention.GetString(sMention, sizeof(sMention));
	ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);
	
	char sColor[8];
	if(!CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN, true))
		g_cColor.GetString(sColor, sizeof(sColor));
	else g_cColor3.GetString(sColor, sizeof(sColor));
	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);
	
	ReplaceString(sMSG, sizeof(sMSG), "{HOSTNAME}", g_sServerName);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_IP}", g_sHostIP);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_PORT}", g_sHostPort);
	
	
	char sReportId[8];
	Format(sReportId, sizeof(sReportId), "%d", g_iLastReportID);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORT_ID}", sReportId);
	
	char clientName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));

	Discord_EscapeString(clientName, sizeof(clientName));
	ReplaceString(sMSG, sizeof(sMSG), "{HANDLER_NAME}", clientName);
	
	LogMessage("Sending handled message: '%s'", sMSG);
	SendMessage(sMSG);
}


public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	char sColor[8];
	if(!CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN, true))
		g_cColor.GetString(sColor, sizeof(sColor));
	else g_cColor3.GetString(sColor, sizeof(sColor));
	
	char sReason[(REASON_MAX_LENGTH + 1) * 2];
	strcopy(sReason, sizeof(sReason), reason);
	Discord_EscapeString(sReason, sizeof(sReason));
	
	char clientAuth[21];
	char clientName[(MAX_NAME_LENGTH + 1) * 2];
	
	if (client == REPORTER_CONSOLE)
	{
		strcopy(clientName, sizeof(clientName), "Server");
		strcopy(clientAuth, sizeof(clientAuth), "CONSOLE");
	}
	else
	{
		GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
		GetClientName(client, clientName, sizeof(clientName));
		Discord_EscapeString(clientName, sizeof(clientName));
	}
	
	char targetAuth[21];
	char targetName[(MAX_NAME_LENGTH + 1) * 2];
	
	GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth));
	GetClientName(target, targetName, sizeof(targetName));
	Discord_EscapeString(targetName, sizeof(targetName));
	
	char sRemove[32];
	g_cRemove.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");
	
	g_cRemove2.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");

	
	Discord_EscapeString(g_sServerName, sizeof(g_sServerName));
	
	char sMention[512];
	g_cMention.GetString(sMention, sizeof(sMention));
	
	char sBot[512];
	g_cBotName.GetString(sBot, sizeof(sBot));
	
	g_iLastReportID = CallAdmin_GetReportID();
	
	char sMSG[4096] = REPORT_MSG;
	
	ReplaceString(sMSG, sizeof(sMSG), "{BOTNAME}", sBot);
	ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);
	
	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);
	
	ReplaceString(sMSG, sizeof(sMSG), "{HOSTNAME}", g_sServerName);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_IP}", g_sHostIP);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_PORT}", g_sHostPort);
	
	char sReportId[8];
	Format(sReportId, sizeof(sReportId), "%d", g_iLastReportID);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORT_ID}", sReportId);
	
	ReplaceString(sMSG, sizeof(sMSG), "{REASON}", sReason);
	
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_NAME}", clientName);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_ID}", clientAuth);
	
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_NAME}", targetName);
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_ID}", targetAuth);
		
	LogMessage("Sending report message: '%s'", sMSG);
	SendMessage(sMSG);
}

SendMessage(char[] sMessage)
{
	char sWebhook[32];
	g_cWebhook.GetString(sWebhook, sizeof(sWebhook));
	Discord_SendMessage(sWebhook, sMessage);
}