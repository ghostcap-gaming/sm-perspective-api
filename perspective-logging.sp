#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define DIR_PERMS 511

ConVar convar_Enabled;

char g_BasePath[PLATFORM_MAX_PATH];

public Plugin myinfo = {
	name = "[ANY] Perspective Logging", 
	author = "GhostCap", 
	description = "Automatically logs all comments analyzed to log files.", 
	version = "1.0.0", 
	url = "https://www.ghostcap.com/"
};

public void OnPluginStart() {
	CreateConVar("sm_perspective_logging_version", "1.0.0", "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_perspective_logging_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig();

	BuildPath(Path_SM, g_BasePath, sizeof(g_BasePath), "logs/perspective/");

	if (!DirExists(g_BasePath)) {
		CreateDirectory(g_BasePath, DIR_PERMS);
	}
}

public void OnCommentAnalyzed(int client, const char[] comment, const char[] attribute, const char[] type, float value) {
	if (!convar_Enabled.BoolValue) {
		return;
	}

	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "%s%s.log", g_BasePath, attribute);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	char sSteamID[64];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));

	char sIP[64];
	GetClientIP(client, sIP, sizeof(sIP));

	LogToFile(sPath, "%s - SteamID: %s - IP: %s - Type: %s - Value: %.4f - Comment: %s", sName, sSteamID, sIP, type, value, comment);
}