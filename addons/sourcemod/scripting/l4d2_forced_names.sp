#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

StringMap g_hNames;

bool g_bNamesLocked = false;

public Plugin myinfo =
{
	name = "L4D2 Forced Names",
	author = "Altair Sossai",
	description = "Forces specific players to always use a configured name based on their SteamID.",
	version = "1.0.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
	g_hNames = new StringMap();

	RegServerCmd("sm_forcename", ForceNameCmd, "Maps a SteamID to a forced player name");
	RegServerCmd("sm_forcename_lock", ForceNameLockCmd, "Locks the forced names list so later sm_forcename calls are ignored");

	HookEvent("player_changename", Event_NameChange, EventHookMode_Post);

	LoadForcedNames();
}

public void OnConfigsExecuted()
{
	LoadForcedNames();
}

void LoadForcedNames()
{
	g_bNamesLocked = false;
	g_hNames.Clear();
	ServerCommand("exec %s", "sourcemod/forced_names.cfg");

	RequestFrame(Frame_EnforceAll);
}

Action ForceNameCmd(int args)
{
	if (g_bNamesLocked)
		return Plugin_Handled;

	if (args < 2)
	{
		PrintToServer("[ForcedNames] Usage: sm_forcename \"<steamid>\" \"<name>\"");
		return Plugin_Handled;
	}

	char sSteamId[32];
	char sName[MAX_NAME_LENGTH];
	GetCmdArg(1, sSteamId, sizeof(sSteamId));
	GetCmdArg(2, sName, sizeof(sName));

	if (!IsSteamId(sSteamId))
		return Plugin_Handled;

	sSteamId[6] = '0';
	g_hNames.SetString(sSteamId, sName);
	sSteamId[6] = '1';
	g_hNames.SetString(sSteamId, sName);

	return Plugin_Handled;
}

Action ForceNameLockCmd(int args)
{
	g_bNamesLocked = true;

	return Plugin_Handled;
}

void Event_NameChange(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
	{
		RequestFrame(Frame_EnforceClient, GetClientUserId(client));
	}
}

public void OnClientPostAdminCheck(int client)
{
	EnforceName(client);
}

void Frame_EnforceClient(int userid)
{
	EnforceName(GetClientOfUserId(userid));
}

void Frame_EnforceAll(any data)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			EnforceName(client);
	}
}

void EnforceName(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return;

	char sSteamId[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId)))
		return;

	if (!IsSteamId(sSteamId))
		return;

	char sForced[MAX_NAME_LENGTH];
	if (!g_hNames.GetString(sSteamId, sForced, sizeof(sForced)))
		return;

	char sCurrent[MAX_NAME_LENGTH];
	GetClientName(client, sCurrent, sizeof(sCurrent));

	if (!StrEqual(sCurrent, sForced))
		SetClientName(client, sForced);
}

bool IsSteamId(const char[] sSteamId)
{
	return strlen(sSteamId) > 6 && strncmp(sSteamId, "STEAM_", 6) == 0;
}
