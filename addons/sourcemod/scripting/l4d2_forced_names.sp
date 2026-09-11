#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

StringMap g_hNames;

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

	HookEvent("player_changename", Event_NameChange, EventHookMode_Post);

	LoadForcedNames();
}

public void OnConfigsExecuted()
{
	LoadForcedNames();
}

void LoadForcedNames()
{
	g_hNames.Clear();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/forced_names.cfg");

	KeyValues kv = new KeyValues("ForcedNames");
	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey(false))
	{
		do
		{
			char sSteamId[32];
			char sName[MAX_NAME_LENGTH];
			kv.GetSectionName(sSteamId, sizeof(sSteamId));
			kv.GetString(NULL_STRING, sName, sizeof(sName));

			if (!IsSteamId(sSteamId))
				continue;

			sSteamId[6] = '0';
			g_hNames.SetString(sSteamId, sName);
			sSteamId[6] = '1';
			g_hNames.SetString(sSteamId, sName);
		}
		while (kv.GotoNextKey(false));
	}
	delete kv;

	Frame_EnforceAll();
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

void Frame_EnforceAll()
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
