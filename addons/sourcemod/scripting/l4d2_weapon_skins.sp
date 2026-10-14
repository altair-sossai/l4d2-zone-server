#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <ripext>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define CONFIG_PATH "configs/weapon_skins.cfg"
#define CHOICES_PATH "data/weapon_skins_players.txt"
#define MAX_WEAPON_ENTITIES 2048
#define DROPPED_MODEL_DELAY 0.1
#define OBS_MODE_IN_EYE 4
#define DEFAULT_PLAYER_LEVEL 1
#define PRIMARY_SLOT 0
#define TEAM_SURVIVOR 2

enum struct WeaponModels
{
	char weapon[64];
	char viewModel[PLATFORM_MAX_PATH];
	char worldModel[PLATFORM_MAX_PATH];
	char defaultViewModel[PLATFORM_MAX_PATH];
	char defaultWorldModel[PLATFORM_MAX_PATH];
	char models[PLATFORM_MAX_PATH];
	int viewModelIndex;
	int worldModelIndex;
	int defaultViewModelIndex;
	int defaultWorldModelIndex;
	bool ready;
}

enum struct WeaponSkin
{
	char name[64];
	char weapon[64];
	char worldModel[PLATFORM_MAX_PATH];
	char defaultWorldModel[PLATFORM_MAX_PATH];
	char materials[PLATFORM_MAX_PATH];
	int family;
	int viewModelIndex;
	int worldModelIndex;
	int defaultViewModelIndex;
	int defaultWorldModelIndex;
	bool ready;
}

public Plugin myinfo =
{
	name = "L4D2 Weapon Skins",
	author = "Altair Sossai",
	description = "Lets players use custom weapon skins, downloaded through FastDL, unlocked by their patent level",
	version = "2.0.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar
	g_hEnabled,
	g_hApiUrl,
	g_hKickNoDownloads;

int g_iOverride = -1;

ArrayList
	g_hSkins,
	g_hWeaponModels;

StringMap
	g_hSkinsByName,
	g_hWeaponModelsByClass,
	g_hSkinLevels,
	g_hPlayerLevels,
	g_hPlayerChoices,
	g_hTestChoices;

bool
	g_bSkinLevelsLoaded = false,
	g_bPlayerLevelsLoaded = false,
	g_bReadyUpAvailable = false,
	g_bWorldModelsEnabled = false,
	g_bChoicesChanged = false;

int g_iActiveWeaponRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iActiveSkin[MAXPLAYERS + 1] = { -1, ... };

int g_iWeaponRef[MAX_WEAPON_ENTITIES] = { INVALID_ENT_REFERENCE, ... };
int g_iWeaponSkin[MAX_WEAPON_ENTITIES] = { -1, ... };
int g_iWeaponOriginalSkin[MAX_WEAPON_ENTITIES] = { 0, ... };

int g_iAllowDownload[MAXPLAYERS + 1] = { -1, ... };
int g_iDownloadFilter[MAXPLAYERS + 1] = { -1, ... };

public void OnPluginStart()
{
	LoadTranslations("l4d2_weapon_skins.phrases");

	g_hEnabled = CreateConVar("weapon_skins_enabled", "0", "Enable the weapon skins", _, true, 0.0, true, 1.0);
	g_hApiUrl = CreateConVar("weapon_skins_api_url", "", "Play Stats web URL, used to read the skin and player levels", FCVAR_PROTECTED);
	g_hKickNoDownloads = CreateConVar("weapon_skins_kick_no_downloads", "0", "Kick players whose game does not download the server files, so everyone can see the skins", _, true, 0.0, true, 1.0);
	g_hEnabled.AddChangeHook(OnEnabledChanged);

	RegConsoleCmd("sm_weaponskins", Command_WeaponSkins, "Shows whether the weapon skins are on; admins turn them on or off with sm_weaponskins on|off");
	RegConsoleCmd("sm_skin", Command_Skin, "sm_skin [skin] - Shows the help or selects a weapon skin");
	RegConsoleCmd("sm_skins", Command_Skin, "sm_skins [skin] - Shows the help or selects a weapon skin");
	RegConsoleCmd("sm_skin_next", Command_SkinNext, "sm_skin_next [weapon] - Selects the next skin you can use");
	RegConsoleCmd("sm_skin_prev", Command_SkinPrev, "sm_skin_prev [weapon] - Selects the previous skin you can use");
	RegConsoleCmd("sm_skin_default", Command_SkinDefault, "sm_skin_default [weapon] - Goes back to the default skin");
	RegAdminCmd("sm_skin_test", Command_SkinTest, ADMFLAG_ROOT, "sm_skin_test <skin|default> [weapon] - Tests any skin on yourself until the map changes, ignoring level and ready-up");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AutoExecConfig(false);

	g_hSkins = new ArrayList(sizeof(WeaponSkin));
	g_hWeaponModels = new ArrayList(sizeof(WeaponModels));
	g_hSkinsByName = new StringMap();
	g_hWeaponModelsByClass = new StringMap();
	g_hSkinLevels = new StringMap();
	g_hPlayerLevels = new StringMap();
	g_hPlayerChoices = new StringMap();
	g_hTestChoices = new StringMap();

	LoadChoices();

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}

	char classname[64];
	for (int entity = MaxClients + 1; entity < GetMaxEntities(); entity++)
	{
		if (IsValidEntity(entity) && GetEntityClassname(entity, classname, sizeof(classname)))
		{
			OnEntityCreated(entity, classname);
		}
	}

	RefreshWorldModelsState();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsWeaponSpawnClass(classname))
	{
		return;
	}

	SDKHook(entity, SDKHook_Use, OnWeaponSpawnUse);
	SDKHook(entity, SDKHook_UsePost, OnWeaponSpawnUsePost);
}

bool IsWeaponSpawnClass(const char[] classname)
{
	if (strncmp(classname, "weapon_", 7) != 0)
	{
		return false;
	}

	int length = strlen(classname);
	return length > 6 && StrEqual(classname[length - 6], "_spawn");
}

Action OnWeaponSpawnUse(int entity, int activator, int caller, UseType type, float value)
{
	if (activator < 1 || activator > MaxClients || !IsClientInGame(activator))
	{
		return Plugin_Continue;
	}

	int weapon = GetPlayerWeaponSlot(activator, PRIMARY_SLOT);
	int skinIndex = GetWeaponSkin(activator, weapon);
	if (skinIndex == -1)
	{
		return Plugin_Continue;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);
	RestoreWorldModel(weapon, skin);

	return Plugin_Continue;
}

void OnWeaponSpawnUsePost(int entity, int activator, int caller, UseType type, float value)
{
	if (activator < 1 || activator > MaxClients || !IsClientInGame(activator))
	{
		return;
	}

	int weapon = GetPlayerWeaponSlot(activator, PRIMARY_SLOT);
	if (weapon == -1)
	{
		return;
	}

	RefreshWorldModel(activator, weapon);
}

public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup"))
	{
		g_bReadyUpAvailable = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup"))
	{
		g_bReadyUpAvailable = false;
	}
}

public void OnMapStart()
{
	g_hTestChoices.Clear();

	LoadSkins();
	RefreshLevels();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RefreshLevels();
}

public void OnRoundIsLive()
{
	if (!g_bChoicesChanged)
	{
		return;
	}

	SaveChoices();
	g_bChoicesChanged = false;
}

void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshWorldModelsState();
}

Action Command_WeaponSkins(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%T %T", "Tag", client, IsEnabled() ? "StatusOn" : "StatusOff", client);
		return Plugin_Handled;
	}

	if (!CheckCommandAccess(client, "sm_weaponskins_admin", ADMFLAG_ROOT, true))
	{
		CReplyToCommand(client, "%T %T", "Tag", client, "NoAccess", client);
		return Plugin_Handled;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));

	if (StrEqual(arg, "on", false) || StrEqual(arg, "enable", false) || StrEqual(arg, "1"))
	{
		SetEnabled(client, true);
		return Plugin_Handled;
	}

	if (StrEqual(arg, "off", false) || StrEqual(arg, "disable", false) || StrEqual(arg, "0"))
	{
		SetEnabled(client, false);
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%T %T", "Tag", client, "Usage", client);
	return Plugin_Handled;
}

bool IsEnabled()
{
	return g_iOverride == -1 ? g_hEnabled.BoolValue : g_iOverride == 1;
}

void SetEnabled(int admin, bool enabled)
{
	g_iOverride = enabled ? 1 : 0;

	char name[MAX_NAME_LENGTH];
	if (admin > 0)
	{
		GetClientName(admin, name, sizeof(name));
	}
	else
	{
		strcopy(name, sizeof(name), "Console");
	}

	LogAction(admin, -1, "\"%L\" turned the weapon skins %s", admin, enabled ? "on" : "off");

	if (admin == 0)
	{
		PrintToServer("[WeaponSkins] weapon skins %s", enabled ? "on" : "off");
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}

		CPrintToChat(client, "%T %T", "Tag", client, enabled ? "AdminEnabled" : "AdminDisabled", client, name);
	}

	RefreshWorldModelsState();
}

Action Command_Skin(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[WeaponSkins] This command can only be used in game.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ShowHelp(client);
		return Plugin_Handled;
	}

	char name[64];
	GetCmdArg(1, name, sizeof(name));

	if (StrEqual(name, "default", false))
	{
		SelectDefault(client, args, 2);
		return Plugin_Handled;
	}

	if (!IsEnabled())
	{
		CPrintToChat(client, "%T %T", "Tag", client, "StatusOff", client);
		return Plugin_Handled;
	}

	int skinIndex = FindAvailableSkin(name);
	if (skinIndex == -1)
	{
		char siteUrl[256];
		GetSiteUrl(siteUrl, sizeof(siteUrl));
		CPrintToChat(client, "%T %T", "Tag", client, "SkinUnknown", client, name, siteUrl);
		return Plugin_Handled;
	}

	int requiredLevel = GetSkinLevel(name);
	int playerLevel = GetPlayerLevel(client);
	if (playerLevel < requiredLevel)
	{
		CPrintToChat(client, "%T %T", "Tag", client, "SkinLocked", client, name, requiredLevel, playerLevel);
		return Plugin_Handled;
	}

	if (!CanChangeNow(client))
	{
		return Plugin_Handled;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	SetChoice(client, skin.weapon, skin.name);
	ApplyChoiceToPrimaryWeapon(client, skin.weapon);

	char weaponName[32];
	GetWeaponDisplayName(skin.weapon, weaponName, sizeof(weaponName));
	CPrintToChat(client, "%T %T", "Tag", client, "SkinSelected", client, weaponName, skin.name);

	return Plugin_Handled;
}

Action Command_SkinNext(int client, int args)
{
	return CycleSkin(client, args, 1);
}

Action Command_SkinPrev(int client, int args)
{
	return CycleSkin(client, args, -1);
}

Action Command_SkinDefault(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[WeaponSkins] This command can only be used in game.");
		return Plugin_Handled;
	}

	SelectDefault(client, args, 1);
	return Plugin_Handled;
}

Action Command_SkinTest(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[WeaponSkins] This command can only be used in game.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyToCommand(client, "[WeaponSkins] Usage: sm_skin_test <skin|default> [weapon]");
		return Plugin_Handled;
	}

	char name[64];
	GetCmdArg(1, name, sizeof(name));

	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return Plugin_Handled;
	}

	char weapon[64];
	char key[128];

	if (StrEqual(name, "default", false))
	{
		if (!ResolveWeapon(client, args, 2, weapon, sizeof(weapon)))
		{
			CPrintToChat(client, "%T %T", "Tag", client, "NoWeapon", client);
			return Plugin_Handled;
		}

		FormatEx(key, sizeof(key), "%s:%s", steamId, weapon);
		g_hTestChoices.Remove(key);
		ApplyChoiceToPrimaryWeapon(client, weapon);

		ReplyToCommand(client, "[WeaponSkins] Test skin removed from %s.", weapon);
		return Plugin_Handled;
	}

	int skinIndex;
	if (!g_hSkinsByName.GetValue(name, skinIndex))
	{
		char siteUrl[256];
		GetSiteUrl(siteUrl, sizeof(siteUrl));
		CPrintToChat(client, "%T %T", "Tag", client, "SkinUnknown", client, name, siteUrl);
		return Plugin_Handled;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	FormatEx(key, sizeof(key), "%s:%s", steamId, skin.weapon);
	g_hTestChoices.SetString(key, skin.name);
	ApplyChoiceToPrimaryWeapon(client, skin.weapon);

	ReplyToCommand(client, "[WeaponSkins] Testing %s on %s until the map changes.", skin.name, skin.weapon);
	return Plugin_Handled;
}

void ShowHelp(int client)
{
	char siteUrl[256];
	GetSiteUrl(siteUrl, sizeof(siteUrl));

	CPrintToChat(client, "%T %T", "Tag", client, "HelpTitle", client);
	CPrintToChat(client, "%T", "HelpLevel", client, GetPlayerLevel(client));
	CPrintToChat(client, "%T", "HelpChoose", client);
	CPrintToChat(client, "%T", "HelpCycle", client);
	CPrintToChat(client, "%T", "HelpDefault", client);
	CPrintToChat(client, "%T", "HelpReady", client);
	CPrintToChat(client, "%T", "HelpSite", client, siteUrl);
}

Action CycleSkin(int client, int args, int direction)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[WeaponSkins] This command can only be used in game.");
		return Plugin_Handled;
	}

	if (!IsEnabled())
	{
		CPrintToChat(client, "%T %T", "Tag", client, "StatusOff", client);
		return Plugin_Handled;
	}

	char weapon[64];
	if (!ResolveWeapon(client, args, 1, weapon, sizeof(weapon)))
	{
		CPrintToChat(client, "%T %T", "Tag", client, "NoWeapon", client);
		return Plugin_Handled;
	}

	char weaponName[32];
	GetWeaponDisplayName(weapon, weaponName, sizeof(weaponName));

	ArrayList available = GetAvailableSkins(client, weapon);
	int total = available.Length;

	if (total == 0)
	{
		delete available;
		CPrintToChat(client, "%T %T", "Tag", client, "NoSkinsForWeapon", client, weaponName);
		return Plugin_Handled;
	}

	if (!CanChangeNow(client))
	{
		delete available;
		return Plugin_Handled;
	}

	char current[64];
	GetChoice(client, weapon, current, sizeof(current));

	int currentPosition = -1;
	WeaponSkin skin;
	for (int i = 0; i < total; i++)
	{
		g_hSkins.GetArray(available.Get(i), skin);

		if (StrEqual(skin.name, current))
		{
			currentPosition = i;
			break;
		}
	}

	int nextPosition = currentPosition + direction;
	if (currentPosition == -1 && direction < 0)
	{
		nextPosition = total - 1;
	}

	if (nextPosition < 0 || nextPosition >= total)
	{
		delete available;

		ClearChoice(client, weapon);
		ApplyChoiceToPrimaryWeapon(client, weapon);

		CPrintToChat(client, "%T %T", "Tag", client, "SkinDefault", client, weaponName);
		return Plugin_Handled;
	}

	g_hSkins.GetArray(available.Get(nextPosition), skin);
	delete available;

	SetChoice(client, weapon, skin.name);
	ApplyChoiceToPrimaryWeapon(client, weapon);

	CPrintToChat(client, "%T %T", "Tag", client, "SkinCycle", client, weaponName, skin.name, nextPosition + 1, total);
	return Plugin_Handled;
}

void SelectDefault(int client, int args, int weaponArg)
{
	char weapon[64];
	if (!ResolveWeapon(client, args, weaponArg, weapon, sizeof(weapon)))
	{
		CPrintToChat(client, "%T %T", "Tag", client, "NoWeapon", client);
		return;
	}

	if (!CanChangeNow(client))
	{
		return;
	}

	ClearChoice(client, weapon);
	ApplyChoiceToPrimaryWeapon(client, weapon);

	char weaponName[32];
	GetWeaponDisplayName(weapon, weaponName, sizeof(weaponName));
	CPrintToChat(client, "%T %T", "Tag", client, "SkinDefault", client, weaponName);
}

bool CanChangeNow(int client)
{
	if (GetClientTeam(client) != TEAM_SURVIVOR)
	{
		CPrintToChat(client, "%T %T", "Tag", client, "OnlySurvivors", client);
		return false;
	}

	if (g_bReadyUpAvailable && !IsInReady())
	{
		CPrintToChat(client, "%T %T", "Tag", client, "OnlyDuringReadyUp", client);
		return false;
	}

	return true;
}

ArrayList GetAvailableSkins(int client, const char[] weapon)
{
	ArrayList available = new ArrayList();
	int playerLevel = GetPlayerLevel(client);

	WeaponSkin skin;
	for (int i = 0; i < g_hSkins.Length; i++)
	{
		g_hSkins.GetArray(i, skin);

		if (!skin.ready || !StrEqual(skin.weapon, weapon))
		{
			continue;
		}

		int level;
		if (!g_hSkinLevels.GetValue(skin.name, level) || level > playerLevel)
		{
			continue;
		}

		available.Push(i);
	}

	return available;
}

int FindAvailableSkin(const char[] name)
{
	int skinIndex;
	if (!g_hSkinsByName.GetValue(name, skinIndex) || !g_hSkinLevels.ContainsKey(name))
	{
		return -1;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	return skin.ready ? skinIndex : -1;
}

int GetSkinLevel(const char[] name)
{
	int level;
	if (!g_hSkinLevels.GetValue(name, level))
	{
		return 0;
	}

	return level;
}

int GetPlayerLevel(int client)
{
	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return DEFAULT_PLAYER_LEVEL;
	}

	return GetLevelOf(steamId);
}

int GetLevelOf(const char[] steamId)
{
	int level;
	if (!g_hPlayerLevels.GetValue(steamId, level))
	{
		return DEFAULT_PLAYER_LEVEL;
	}

	return level;
}

bool ResolveWeapon(int client, int args, int argIndex, char[] weapon, int maxlength)
{
	if (args >= argIndex)
	{
		char arg[64];
		GetCmdArg(argIndex, arg, sizeof(arg));
		NormalizeWeapon(arg, weapon, maxlength);

		return IsSkinnableWeapon(weapon);
	}

	int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (active > MaxClients && IsValidEntity(active))
	{
		GetEntityClassname(active, weapon, maxlength);

		if (IsSkinnableWeapon(weapon))
		{
			return true;
		}
	}

	int primary = GetPlayerWeaponSlot(client, PRIMARY_SLOT);
	if (primary > MaxClients && IsValidEntity(primary))
	{
		GetEntityClassname(primary, weapon, maxlength);

		if (IsSkinnableWeapon(weapon))
		{
			return true;
		}
	}

	return false;
}

void NormalizeWeapon(const char[] arg, char[] weapon, int maxlength)
{
	if (StrEqual(arg, "smg", false) || StrEqual(arg, "uzi", false))
	{
		strcopy(weapon, maxlength, "weapon_smg");
		return;
	}

	if (StrEqual(arg, "mac", false) || StrEqual(arg, "mac10", false) || StrEqual(arg, "mac-10", false) || StrEqual(arg, "silenced", false) || StrEqual(arg, "smg_silenced", false))
	{
		strcopy(weapon, maxlength, "weapon_smg_silenced");
		return;
	}

	if (StrEqual(arg, "pump", false) || StrEqual(arg, "pumpshotgun", false))
	{
		strcopy(weapon, maxlength, "weapon_pumpshotgun");
		return;
	}

	if (StrEqual(arg, "chrome", false) || StrEqual(arg, "shotgun_chrome", false))
	{
		strcopy(weapon, maxlength, "weapon_shotgun_chrome");
		return;
	}

	if (StrContains(arg, "weapon_", false) == 0)
	{
		strcopy(weapon, maxlength, arg);
		return;
	}

	FormatEx(weapon, maxlength, "weapon_%s", arg);
}

bool IsSkinnableWeapon(const char[] weapon)
{
	WeaponSkin skin;
	for (int i = 0; i < g_hSkins.Length; i++)
	{
		g_hSkins.GetArray(i, skin);

		if (StrEqual(skin.weapon, weapon, false))
		{
			return true;
		}
	}

	return false;
}

void GetWeaponDisplayName(const char[] weapon, char[] name, int maxlength)
{
	if (StrEqual(weapon, "weapon_smg"))
	{
		strcopy(name, maxlength, "SMG");
		return;
	}

	if (StrEqual(weapon, "weapon_smg_silenced"))
	{
		strcopy(name, maxlength, "MAC-10");
		return;
	}

	if (StrEqual(weapon, "weapon_pumpshotgun"))
	{
		strcopy(name, maxlength, "Pump Shotgun");
		return;
	}

	if (StrEqual(weapon, "weapon_shotgun_chrome"))
	{
		strcopy(name, maxlength, "Chrome Shotgun");
		return;
	}

	strcopy(name, maxlength, weapon);
}

void GetSiteUrl(char[] url, int maxlength)
{
	g_hApiUrl.GetString(url, maxlength);
	TrimTrailingSlash(url);
	StrCat(url, maxlength, "/skins");
}

void TrimTrailingSlash(char[] url)
{
	int length = strlen(url);
	if (length > 0 && url[length - 1] == '/')
	{
		url[length - 1] = '\0';
	}
}

bool GetSteamId(int client, char[] steamId, int maxlength)
{
	if (IsFakeClient(client))
	{
		return false;
	}

	return GetClientAuthId(client, AuthId_SteamID64, steamId, maxlength);
}

void GetChoice(int client, const char[] weapon, char[] name, int maxlength)
{
	name[0] = '\0';

	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return;
	}

	char key[128];
	FormatEx(key, sizeof(key), "%s:%s", steamId, weapon);
	g_hPlayerChoices.GetString(key, name, maxlength);
}

void SetChoice(int client, const char[] weapon, const char[] name)
{
	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return;
	}

	char key[128];
	FormatEx(key, sizeof(key), "%s:%s", steamId, weapon);
	g_hTestChoices.Remove(key);

	char current[64];
	if (g_hPlayerChoices.GetString(key, current, sizeof(current)) && StrEqual(current, name))
	{
		return;
	}

	g_hPlayerChoices.SetString(key, name);
	g_bChoicesChanged = true;
}

void ClearChoice(int client, const char[] weapon)
{
	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return;
	}

	char key[128];
	FormatEx(key, sizeof(key), "%s:%s", steamId, weapon);
	g_hTestChoices.Remove(key);

	if (g_hPlayerChoices.Remove(key))
	{
		g_bChoicesChanged = true;
	}
}

void LoadChoices()
{
	g_hPlayerChoices.Clear();

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CHOICES_PATH);

	KeyValues kv = new KeyValues("WeaponSkinsPlayers");
	if (!kv.ImportFromFile(path) || !kv.GotoFirstSubKey())
	{
		delete kv;
		return;
	}

	do
	{
		char steamId[32];
		kv.GetSectionName(steamId, sizeof(steamId));

		if (!kv.GotoFirstSubKey(false))
		{
			continue;
		}

		do
		{
			char weapon[64];
			char name[64];
			kv.GetSectionName(weapon, sizeof(weapon));
			kv.GetString(NULL_STRING, name, sizeof(name));

			char key[128];
			FormatEx(key, sizeof(key), "%s:%s", steamId, weapon);
			g_hPlayerChoices.SetString(key, name);
		}
		while (kv.GotoNextKey(false));

		kv.GoBack();
	}
	while (kv.GotoNextKey());

	delete kv;
}

void SaveChoices()
{
	KeyValues kv = new KeyValues("WeaponSkinsPlayers");

	StringMapSnapshot snapshot = g_hPlayerChoices.Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		char key[128];
		snapshot.GetKey(i, key, sizeof(key));

		char parts[2][64];
		if (ExplodeString(key, ":", parts, sizeof(parts), sizeof(parts[])) != 2)
		{
			continue;
		}

		char name[64];
		g_hPlayerChoices.GetString(key, name, sizeof(name));

		kv.JumpToKey(parts[0], true);
		kv.SetString(parts[1], name);
		kv.GoBack();
	}
	delete snapshot;

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CHOICES_PATH);
	kv.ExportToFile(path);

	delete kv;
}

void RefreshLevels()
{
	char apiUrl[256];
	g_hApiUrl.GetString(apiUrl, sizeof(apiUrl));
	TrimTrailingSlash(apiUrl);

	if (apiUrl[0] == '\0')
	{
		return;
	}

	char endpoint[320];

	FormatEx(endpoint, sizeof(endpoint), "%s/api/skins", apiUrl);
	HTTPRequest skinsRequest = new HTTPRequest(endpoint);
	skinsRequest.Get(OnSkinLevelsResponse);

	FormatEx(endpoint, sizeof(endpoint), "%s/api/players/levels", apiUrl);
	HTTPRequest playersRequest = new HTTPRequest(endpoint);
	playersRequest.Get(OnPlayerLevelsResponse);
}

void OnSkinLevelsResponse(HTTPResponse response, any value)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogError("Could not load the skin levels (HTTP %d)", response.Status);
		return;
	}

	g_hSkinLevels.Clear();

	JSONArray skins = view_as<JSONArray>(response.Data);
	for (int i = 0; i < skins.Length; i++)
	{
		JSONObject skin = view_as<JSONObject>(skins.Get(i));

		char id[64];
		skin.GetString("id", id, sizeof(id));
		g_hSkinLevels.SetValue(id, skin.GetInt("level"));

		delete skin;
	}

	g_bSkinLevelsLoaded = true;

	ValidateChoices();
}

void OnPlayerLevelsResponse(HTTPResponse response, any value)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogError("Could not load the player levels (HTTP %d)", response.Status);
		return;
	}

	g_hPlayerLevels.Clear();

	JSONArray players = view_as<JSONArray>(response.Data);
	for (int i = 0; i < players.Length; i++)
	{
		JSONObject player = view_as<JSONObject>(players.Get(i));

		char communityId[32];
		player.GetString("communityId", communityId, sizeof(communityId));
		g_hPlayerLevels.SetValue(communityId, player.GetInt("level"));

		delete player;
	}

	g_bPlayerLevelsLoaded = true;

	ValidateChoices();
}

void ValidateChoices()
{
	if (!g_bSkinLevelsLoaded || !g_bPlayerLevelsLoaded)
	{
		return;
	}

	StringMapSnapshot snapshot = g_hPlayerChoices.Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		char key[128];
		snapshot.GetKey(i, key, sizeof(key));

		char parts[2][64];
		if (ExplodeString(key, ":", parts, sizeof(parts), sizeof(parts[])) != 2)
		{
			continue;
		}

		char name[64];
		g_hPlayerChoices.GetString(key, name, sizeof(name));

		int requiredLevel;
		if (g_hSkinLevels.GetValue(name, requiredLevel) && GetLevelOf(parts[0]) >= requiredLevel)
		{
			continue;
		}

		g_hPlayerChoices.Remove(key);
		g_bChoicesChanged = true;

		NotifyChoiceRemoved(parts[0], parts[1], name);
	}
	delete snapshot;
}

void NotifyChoiceRemoved(const char[] steamId, const char[] weapon, const char[] name)
{
	int client = FindClientBySteamId(steamId);
	if (client == 0)
	{
		return;
	}

	ApplyChoiceToPrimaryWeapon(client, weapon);

	char weaponName[32];
	GetWeaponDisplayName(weapon, weaponName, sizeof(weaponName));
	CPrintToChat(client, "%T %T", "Tag", client, "SkinReset", client, weaponName, name);
}

int FindClientBySteamId(const char[] steamId)
{
	char clientSteamId[32];
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !GetSteamId(client, clientSteamId, sizeof(clientSteamId)))
		{
			continue;
		}

		if (StrEqual(clientSteamId, steamId))
		{
			return client;
		}
	}

	return 0;
}

void ApplyChoiceToPrimaryWeapon(int client, const char[] weaponClass)
{
	int weapon = GetPlayerWeaponSlot(client, PRIMARY_SLOT);
	if (weapon <= MaxClients || weapon >= MAX_WEAPON_ENTITIES || !IsValidEntity(weapon))
	{
		return;
	}

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));

	if (!StrEqual(classname, weaponClass))
	{
		return;
	}

	int skinIndex = GetPlayerWeaponSkin(client, weapon);
	int previousSkin = GetAssignedWeaponSkin(weapon);

	if (previousSkin != -1 && previousSkin != skinIndex)
	{
		WeaponSkin previous;
		g_hSkins.GetArray(previousSkin, previous);
		RestoreWorldModel(weapon, previous);
		RestoreViewModel(client, previous);
	}

	TrackWeapon(weapon);
	g_iWeaponSkin[weapon] = skinIndex;

	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == weapon)
	{
		g_iActiveWeaponRef[client] = g_iWeaponRef[weapon];
		g_iActiveSkin[client] = skinIndex;
	}

	if (skinIndex == -1)
	{
		return;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);
	ApplyWorldModel(weapon, skin);
}

public void OnClientPutInServer(int client)
{
	g_iActiveWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iActiveSkin[client] = -1;

	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);

	if (IsFakeClient(client))
	{
		return;
	}

	g_iAllowDownload[client] = -1;
	g_iDownloadFilter[client] = -1;

	int userId = GetClientUserId(client);
	QueryClientConVar(client, "cl_allowdownload", OnAllowDownloadQueried, userId);
	QueryClientConVar(client, "cl_downloadfilter", OnDownloadFilterQueried, userId);

	RefreshWorldModelsState();
}

public void OnClientDisconnect(int client)
{
	g_iActiveWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iActiveSkin[client] = -1;
}

public void OnClientDisconnect_Post(int client)
{
	g_iAllowDownload[client] = -1;
	g_iDownloadFilter[client] = -1;

	RefreshWorldModelsState();
}

void OnAllowDownloadQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any userId)
{
	if (GetClientOfUserId(userId) != client)
	{
		return;
	}

	g_iAllowDownload[client] = result == ConVarQuery_Okay && StringToInt(cvarValue) == 1 ? 1 : 0;

	if (result == ConVarQuery_Okay && g_iAllowDownload[client] == 0)
	{
		KickWithoutDownloads(client);
	}

	RefreshWorldModelsState();
}

void OnDownloadFilterQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any userId)
{
	if (GetClientOfUserId(userId) != client)
	{
		return;
	}

	bool downloadsModels = StrEqual(cvarValue, "all", false) || StrEqual(cvarValue, "nosounds", false);
	g_iDownloadFilter[client] = result == ConVarQuery_Okay && downloadsModels ? 1 : 0;

	if (result == ConVarQuery_Okay && g_iDownloadFilter[client] == 0)
	{
		KickWithoutDownloads(client);
	}

	RefreshWorldModelsState();
}

void KickWithoutDownloads(int client)
{
	if (!g_hKickNoDownloads.BoolValue || !IsEnabled() || IsClientInKickQueue(client))
	{
		return;
	}

	KickClient(client, "%T", "KickNoDownloads", client);
}

bool CanClientSeeSkins(int client)
{
	if (IsFakeClient(client))
	{
		return true;
	}

	return g_iAllowDownload[client] == 1 && g_iDownloadFilter[client] == 1;
}

bool HasClientWithoutSkins()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !CanClientSeeSkins(client))
		{
			return true;
		}
	}

	return false;
}

void RefreshWorldModelsState()
{
	bool enabled = IsEnabled() && !HasClientWithoutSkins();
	if (enabled == g_bWorldModelsEnabled)
	{
		return;
	}

	g_bWorldModelsEnabled = enabled;

	WeaponSkin skin;
	for (int weapon = MaxClients + 1; weapon < MAX_WEAPON_ENTITIES; weapon++)
	{
		int skinIndex = GetAssignedWeaponSkin(weapon);
		if (skinIndex == -1)
		{
			continue;
		}

		g_hSkins.GetArray(skinIndex, skin);

		if (enabled)
		{
			ApplyWorldModel(weapon, skin);
			continue;
		}

		RestoreWorldModel(weapon, skin);
	}
}

void LoadSkins()
{
	g_hSkins.Clear();
	g_hSkinsByName.Clear();
	g_hWeaponModels.Clear();
	g_hWeaponModelsByClass.Clear();

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CONFIG_PATH);

	KeyValues kv = new KeyValues("WeaponSkins");
	if (!kv.ImportFromFile(path))
	{
		LogError("Could not read %s", path);
		delete kv;
		return;
	}

	LoadWeaponModels(kv);
	LoadSkinDefinitions(kv);

	delete kv;
}

void LoadWeaponModels(KeyValues kv)
{
	if (!kv.JumpToKey("Weapons") || !kv.GotoFirstSubKey())
	{
		kv.Rewind();
		return;
	}

	do
	{
		WeaponModels models;
		kv.GetSectionName(models.weapon, sizeof(models.weapon));
		kv.GetString("view_model", models.viewModel, sizeof(models.viewModel));
		kv.GetString("world_model", models.worldModel, sizeof(models.worldModel));
		kv.GetString("default_view_model", models.defaultViewModel, sizeof(models.defaultViewModel));
		kv.GetString("default_world_model", models.defaultWorldModel, sizeof(models.defaultWorldModel));
		kv.GetString("models", models.models, sizeof(models.models));

		models.ready = PrepareWeaponModels(models);
		g_hWeaponModelsByClass.SetValue(models.weapon, g_hWeaponModels.PushArray(models));
	}
	while (kv.GotoNextKey());

	kv.Rewind();
}

bool PrepareWeaponModels(WeaponModels models)
{
	if (models.viewModel[0] == '\0' || models.worldModel[0] == '\0' || models.defaultViewModel[0] == '\0' || models.defaultWorldModel[0] == '\0' || models.models[0] == '\0')
	{
		LogError("Weapon \"%s\" is missing required keys", models.weapon);
		return false;
	}

	if (!FileExists(models.viewModel) || !FileExists(models.worldModel))
	{
		LogError("Weapon \"%s\" models were not found on the server", models.weapon);
		return false;
	}

	AddDirectoryToDownloadsTable(models.models);

	models.viewModelIndex = PrecacheModel(models.viewModel, true);
	models.worldModelIndex = PrecacheModel(models.worldModel, true);
	models.defaultViewModelIndex = PrecacheModel(models.defaultViewModel, true);
	models.defaultWorldModelIndex = PrecacheModel(models.defaultWorldModel, true);

	return true;
}

void LoadSkinDefinitions(KeyValues kv)
{
	if (!kv.JumpToKey("Skins") || !kv.GotoFirstSubKey())
	{
		kv.Rewind();
		return;
	}

	do
	{
		WeaponSkin skin;
		kv.GetSectionName(skin.name, sizeof(skin.name));
		kv.GetString("weapon", skin.weapon, sizeof(skin.weapon));
		kv.GetString("materials", skin.materials, sizeof(skin.materials));
		skin.family = kv.GetNum("skin", -1);

		if (skin.weapon[0] == '\0' || skin.materials[0] == '\0' || skin.family < 0)
		{
			LogError("Skin \"%s\" is missing required keys", skin.name);
			continue;
		}

		skin.ready = PrepareSkin(skin);
		g_hSkinsByName.SetValue(skin.name, g_hSkins.PushArray(skin));
	}
	while (kv.GotoNextKey());

	kv.Rewind();
}

bool PrepareSkin(WeaponSkin skin)
{
	int modelsIndex;
	if (!g_hWeaponModelsByClass.GetValue(skin.weapon, modelsIndex))
	{
		LogError("Skin \"%s\" uses %s, which has no models configured", skin.name, skin.weapon);
		return false;
	}

	WeaponModels models;
	g_hWeaponModels.GetArray(modelsIndex, models);

	if (!models.ready)
	{
		return false;
	}

	if (!DirExists(skin.materials))
	{
		LogError("Skin \"%s\" materials were not found on the server", skin.name);
		return false;
	}

	AddDirectoryToDownloadsTable(skin.materials);

	strcopy(skin.worldModel, sizeof(skin.worldModel), models.worldModel);
	strcopy(skin.defaultWorldModel, sizeof(skin.defaultWorldModel), models.defaultWorldModel);
	skin.viewModelIndex = models.viewModelIndex;
	skin.worldModelIndex = models.worldModelIndex;
	skin.defaultViewModelIndex = models.defaultViewModelIndex;
	skin.defaultWorldModelIndex = models.defaultWorldModelIndex;

	return true;
}

void OnWeaponEquipPost(int client, int weapon)
{
	RefreshWorldModel(client, weapon);
}

void OnWeaponDropPost(int client, int weapon)
{
	if (GetWeaponSkin(client, weapon) == -1)
	{
		return;
	}

	CreateTimer(DROPPED_MODEL_DELAY, Timer_ApplyDroppedWorldModel, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ApplyDroppedWorldModel(Handle timer, int weaponRef)
{
	int weapon = EntRefToEntIndex(weaponRef);
	if (weapon == INVALID_ENT_REFERENCE)
	{
		return Plugin_Stop;
	}

	if (GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") != -1)
	{
		return Plugin_Stop;
	}

	int skinIndex = GetAssignedWeaponSkin(weapon);
	if (skinIndex == -1)
	{
		return Plugin_Stop;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);
	ApplyWorldModel(weapon, skin);

	return Plugin_Stop;
}

void RefreshWorldModel(int client, int weapon)
{
	int skinIndex = GetWeaponSkin(client, weapon);
	if (skinIndex == -1)
	{
		return;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);
	ApplyWorldModel(weapon, skin);
}

void OnPostThinkPost(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int weaponRef = weapon > MaxClients ? EntIndexToEntRef(weapon) : INVALID_ENT_REFERENCE;

	if (weaponRef != g_iActiveWeaponRef[client])
	{
		g_iActiveWeaponRef[client] = weaponRef;
		g_iActiveSkin[client] = GetWeaponSkin(client, weapon);
	}

	if (g_iActiveSkin[client] == -1)
	{
		return;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(g_iActiveSkin[client], skin);

	ApplyWorldModel(weapon, skin);

	if (CanShowViewModel(client))
	{
		ApplyViewModel(client, skin);
		return;
	}

	RestoreViewModel(client, skin);
}

bool CanShowViewModel(int client)
{
	if (!IsEnabled() || !CanClientSeeSkins(client))
	{
		return false;
	}

	if (g_bWorldModelsEnabled)
	{
		return true;
	}

	for (int observer = 1; observer <= MaxClients; observer++)
	{
		if (observer == client || !IsClientInGame(observer) || CanClientSeeSkins(observer))
		{
			continue;
		}

		if (GetEntPropEnt(observer, Prop_Send, "m_hObserverTarget") != client)
		{
			continue;
		}

		if (GetEntProp(observer, Prop_Send, "m_iObserverMode") == OBS_MODE_IN_EYE)
		{
			return false;
		}
	}

	return true;
}

int GetWeaponSkin(int client, int weapon)
{
	if (weapon <= MaxClients || weapon >= MAX_WEAPON_ENTITIES || !IsValidEntity(weapon))
	{
		return -1;
	}

	if (g_iWeaponRef[weapon] != EntIndexToEntRef(weapon))
	{
		TrackWeapon(weapon);
		g_iWeaponSkin[weapon] = GetPlayerWeaponSkin(client, weapon);
	}

	return g_iWeaponSkin[weapon];
}

void TrackWeapon(int weapon)
{
	int weaponRef = EntIndexToEntRef(weapon);
	if (g_iWeaponRef[weapon] == weaponRef)
	{
		return;
	}

	g_iWeaponRef[weapon] = weaponRef;
	g_iWeaponSkin[weapon] = -1;
	g_iWeaponOriginalSkin[weapon] = GetEntProp(weapon, Prop_Send, "m_nSkin");
}

int GetOriginalSkin(int weapon)
{
	if (weapon <= MaxClients || weapon >= MAX_WEAPON_ENTITIES || !IsValidEntity(weapon))
	{
		return 0;
	}

	if (g_iWeaponRef[weapon] != EntIndexToEntRef(weapon))
	{
		return GetEntProp(weapon, Prop_Send, "m_nSkin");
	}

	return g_iWeaponOriginalSkin[weapon];
}

int GetAssignedWeaponSkin(int weapon)
{
	if (weapon <= MaxClients || weapon >= MAX_WEAPON_ENTITIES || !IsValidEntity(weapon))
	{
		return -1;
	}

	if (g_iWeaponRef[weapon] != EntIndexToEntRef(weapon))
	{
		return -1;
	}

	return g_iWeaponSkin[weapon];
}

int GetPlayerWeaponSkin(int client, int weapon)
{
	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return -1;
	}

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));

	char key[128];
	FormatEx(key, sizeof(key), "%s:%s", steamId, classname);

	char name[64];
	if (g_hTestChoices.GetString(key, name, sizeof(name)))
	{
		return FindReadySkin(name);
	}

	if (!g_hPlayerChoices.GetString(key, name, sizeof(name)))
	{
		return -1;
	}

	int requiredLevel;
	if (!g_hSkinLevels.GetValue(name, requiredLevel) || GetLevelOf(steamId) < requiredLevel)
	{
		return -1;
	}

	return FindReadySkin(name);
}

int FindReadySkin(const char[] name)
{
	int skinIndex;
	if (!g_hSkinsByName.GetValue(name, skinIndex))
	{
		return -1;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	return skin.ready ? skinIndex : -1;
}

void ApplyViewModel(int client, WeaponSkin skin)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if (viewModel <= MaxClients || !IsValidEntity(viewModel))
	{
		return;
	}

	if (GetEntProp(viewModel, Prop_Send, "m_nModelIndex") != skin.viewModelIndex)
	{
		SetEntProp(viewModel, Prop_Send, "m_nModelIndex", skin.viewModelIndex);
	}

	if (GetEntProp(viewModel, Prop_Send, "m_nSkin") != skin.family)
	{
		SetEntProp(viewModel, Prop_Send, "m_nSkin", skin.family);
	}
}

void RestoreViewModel(int client, WeaponSkin skin)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if (viewModel <= MaxClients || !IsValidEntity(viewModel))
	{
		return;
	}

	if (GetEntProp(viewModel, Prop_Send, "m_nModelIndex") != skin.viewModelIndex)
	{
		return;
	}

	SetEntProp(viewModel, Prop_Send, "m_nModelIndex", skin.defaultViewModelIndex);
	SetEntProp(viewModel, Prop_Send, "m_nSkin", GetOriginalSkin(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")));
}

void RestoreWorldModel(int weapon, WeaponSkin skin)
{
	bool restored = false;

	if (GetEntProp(weapon, Prop_Send, "m_nModelIndex") == skin.worldModelIndex)
	{
		SetEntityModel(weapon, skin.defaultWorldModel);
		restored = true;
	}

	if (HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex") && GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") == skin.worldModelIndex)
	{
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", skin.defaultWorldModelIndex);
		restored = true;
	}

	if (restored)
	{
		SetEntProp(weapon, Prop_Send, "m_nSkin", GetOriginalSkin(weapon));
	}
}

void ApplyWorldModel(int weapon, WeaponSkin skin)
{
	if (!g_bWorldModelsEnabled)
	{
		return;
	}

	if (GetEntProp(weapon, Prop_Send, "m_nModelIndex") == skin.defaultWorldModelIndex)
	{
		SetEntityModel(weapon, skin.worldModel);
	}

	if (HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex") && GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") != skin.worldModelIndex)
	{
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", skin.worldModelIndex);
	}

	if (GetEntProp(weapon, Prop_Send, "m_nSkin") != skin.family)
	{
		SetEntProp(weapon, Prop_Send, "m_nSkin", skin.family);
	}
}

void AddDirectoryToDownloadsTable(const char[] directory)
{
	DirectoryListing listing = OpenDirectory(directory);
	if (listing == null)
	{
		LogError("Could not open folder %s", directory);
		return;
	}

	char entry[PLATFORM_MAX_PATH];
	char file[PLATFORM_MAX_PATH];
	FileType type;

	while (listing.GetNext(entry, sizeof(entry), type))
	{
		if (type != FileType_File)
		{
			continue;
		}

		FormatEx(file, sizeof(file), "%s/%s", directory, entry);
		AddFileToDownloadsTable(file);
	}

	delete listing;
}
