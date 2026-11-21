#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ripext>

#define HUB_PATH "/api/forced-names"
#define HUB_URL_CVAR "playstats_url"
#define HUB_TOKEN_CVAR "playstats_token"
#define HUB_AUTHORIZATION_HEADER "Authorization"
#define HUB_STEAM_ID_KEY "steamId"
#define HUB_NAME_KEY "name"
#define HUB_URL_LENGTH 256
#define HUB_TOKEN_LENGTH 256
#define HUB_ENDPOINT_LENGTH 512
#define HUB_TIMEOUT 15
#define STEAM_ID_LENGTH 32
#define STEAM_UNIVERSE_INDEX 6

StringMap g_hNames;
StringMap g_hFileNames;
StringMap g_hHubNames;

ConVar g_cvHub;

bool g_bHubRequestPending = false;

public Plugin myinfo =
{
	name = "L4D2 Forced Names",
	author = "Altair Sossai",
	description = "Forces specific players to always use a configured name based on their SteamID, from a config file and from the PlayStats Hub.",
	version = "1.1.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
	g_hNames = new StringMap();
	g_hFileNames = new StringMap();
	g_hHubNames = new StringMap();

	g_cvHub = CreateConVar("l4d2_forced_names_hub", "0", "Also read the forced names from the PlayStats Hub (playstats_url and playstats_token) at the start of each round; the names from the hub win over configs/forced_names.cfg", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvHub.AddChangeHook(OnHubChanged);

	HookEvent("player_changename", Event_NameChange, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	LoadForcedNames();
}

public void OnConfigsExecuted()
{
	LoadForcedNames();
	RequestHubNames();
}

void OnHubChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_cvHub.BoolValue)
	{
		g_hHubNames.Clear();
		RebuildNames();
		return;
	}

	RequestHubNames();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RequestHubNames();
}

void LoadForcedNames()
{
	g_hFileNames.Clear();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/forced_names.cfg");

	KeyValues kv = new KeyValues("ForcedNames");
	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey(false))
	{
		do
		{
			char sSteamId[STEAM_ID_LENGTH];
			char sName[MAX_NAME_LENGTH];
			kv.GetSectionName(sSteamId, sizeof(sSteamId));
			kv.GetString(NULL_STRING, sName, sizeof(sName));

			AddName(g_hFileNames, sSteamId, sName);
		}
		while (kv.GotoNextKey(false));
	}
	delete kv;

	RebuildNames();
}

void RequestHubNames()
{
	if (!g_cvHub.BoolValue || g_bHubRequestPending)
		return;

	char sUrl[HUB_URL_LENGTH];
	char sToken[HUB_TOKEN_LENGTH];

	if (!ReadHubSettings(sUrl, sizeof(sUrl), sToken, sizeof(sToken)))
	{
		LogError("l4d2_forced_names_hub is on, but playstats_url or playstats_token is empty.");
		return;
	}

	char sEndpoint[HUB_ENDPOINT_LENGTH];
	FormatEx(sEndpoint, sizeof(sEndpoint), "%s%s", sUrl, HUB_PATH);

	HTTPRequest request = new HTTPRequest(sEndpoint);
	request.SetHeader(HUB_AUTHORIZATION_HEADER, "%s", sToken);
	request.Timeout = HUB_TIMEOUT;

	g_bHubRequestPending = true;
	request.Get(OnHubNames);
}

bool ReadHubSettings(char[] sUrl, int urlLength, char[] sToken, int tokenLength)
{
	ConVar urlCvar = FindConVar(HUB_URL_CVAR);
	ConVar tokenCvar = FindConVar(HUB_TOKEN_CVAR);

	if (urlCvar == null || tokenCvar == null)
		return false;

	urlCvar.GetString(sUrl, urlLength);
	tokenCvar.GetString(sToken, tokenLength);
	TrimString(sUrl);
	TrimString(sToken);

	int length = strlen(sUrl);

	while (length > 0 && sUrl[length - 1] == '/')
	{
		length--;
		sUrl[length] = '\0';
	}

	return length > 0 && sToken[0] != '\0';
}

void OnHubNames(HTTPResponse response, any value, const char[] error)
{
	g_bHubRequestPending = false;

	if (!g_cvHub.BoolValue)
		return;

	if (error[0] != '\0' || response.Status != HTTPStatus_OK)
	{
		LogError("Could not read the forced names from the hub (status %d): %s", response.Status, error);
		return;
	}

	JSONArray entries = view_as<JSONArray>(response.Data);

	if (entries == null)
		return;

	g_hHubNames.Clear();

	char sSteamId[STEAM_ID_LENGTH];
	char sName[MAX_NAME_LENGTH];

	for (int i = 0; i < entries.Length; i++)
	{
		JSONObject entry = view_as<JSONObject>(entries.Get(i));

		if (entry.GetString(HUB_STEAM_ID_KEY, sSteamId, sizeof(sSteamId)) && entry.GetString(HUB_NAME_KEY, sName, sizeof(sName)))
			AddName(g_hHubNames, sSteamId, sName);

		delete entry;
	}

	RebuildNames();
}

void AddName(StringMap names, char[] sSteamId, const char[] sName)
{
	if (!IsSteamId(sSteamId) || sName[0] == '\0')
		return;

	sSteamId[STEAM_UNIVERSE_INDEX] = '0';
	names.SetString(sSteamId, sName);
	sSteamId[STEAM_UNIVERSE_INDEX] = '1';
	names.SetString(sSteamId, sName);
}

void RebuildNames()
{
	g_hNames.Clear();

	CopyNames(g_hFileNames);
	CopyNames(g_hHubNames);

	Frame_EnforceAll();
}

void CopyNames(StringMap source)
{
	StringMapSnapshot snapshot = source.Snapshot();

	char sSteamId[STEAM_ID_LENGTH];
	char sName[MAX_NAME_LENGTH];

	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, sSteamId, sizeof(sSteamId));

		if (source.GetString(sSteamId, sName, sizeof(sName)))
			g_hNames.SetString(sSteamId, sName);
	}

	delete snapshot;
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

	char sSteamId[STEAM_ID_LENGTH];
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
	return strlen(sSteamId) > STEAM_UNIVERSE_INDEX && strncmp(sSteamId, "STEAM_", STEAM_UNIVERSE_INDEX) == 0;
}
