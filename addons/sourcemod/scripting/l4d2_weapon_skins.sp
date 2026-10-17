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
#define SKINS_CACHE_PATH "data/weapon_skins_cache.json"
#define PLAYERS_CACHE_PATH "data/weapon_skins_players_cache.json"
#define MAX_WEAPON_ENTITIES 2048
#define DROPPED_MODEL_DELAY 0.1
#define PILE_CHECK_DELAY 0.5
#define REFRESH_INTERVAL 120.0
#define LOCAL_CHANGE_GRACE 15.0
#define OBS_MODE_IN_EYE 4
#define PRIMARY_SLOT 0
#define SECONDARY_SLOT 1
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
	int stockSkins;
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
	description = "Lets players use the custom weapon skins they bought in the skin shop, downloaded through FastDL",
	version = "3.3.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar
	g_hEnabled,
	g_hApiUrl,
	g_hApiSecret,
	g_hKickNoDownloads,
	g_hPileRadius,
	g_hPileMax,
	g_hPreviewAll;

int g_iOverride = -1;

char g_sWeaponAliases[][][] =
{
	{ "smg", "weapon_smg" },
	{ "uzi", "weapon_smg" },
	{ "mac", "weapon_smg_silenced" },
	{ "mac10", "weapon_smg_silenced" },
	{ "mac-10", "weapon_smg_silenced" },
	{ "silenced", "weapon_smg_silenced" },
	{ "mp5", "weapon_smg_mp5" },
	{ "pump", "weapon_pumpshotgun" },
	{ "chrome", "weapon_shotgun_chrome" },
	{ "axe", "weapon_melee_fireaxe" },
	{ "fireaxe", "weapon_melee_fireaxe" },
	{ "bat", "weapon_melee_baseball_bat" },
	{ "cricket", "weapon_melee_cricket_bat" },
	{ "guitar", "weapon_melee_electric_guitar" },
	{ "pan", "weapon_melee_frying_pan" },
	{ "golf", "weapon_melee_golfclub" },
	{ "magnum", "weapon_pistol_magnum" },
	{ "deagle", "weapon_pistol_magnum" }
};

char g_sWeaponNames[][][] =
{
	{ "weapon_smg", "SMG" },
	{ "weapon_smg_silenced", "MAC-10" },
	{ "weapon_smg_mp5", "MP5" },
	{ "weapon_pumpshotgun", "Pump Shotgun" },
	{ "weapon_shotgun_chrome", "Chrome Shotgun" },
	{ "weapon_pistol_magnum", "Magnum" },
	{ "weapon_melee_baseball_bat", "Baseball Bat" },
	{ "weapon_melee_cricket_bat", "Cricket Bat" },
	{ "weapon_melee_crowbar", "Crowbar" },
	{ "weapon_melee_electric_guitar", "Electric Guitar" },
	{ "weapon_melee_fireaxe", "Fireaxe" },
	{ "weapon_melee_frying_pan", "Frying Pan" },
	{ "weapon_melee_golfclub", "Golf Club" },
	{ "weapon_melee_katana", "Katana" },
	{ "weapon_melee_machete", "Machete" }
};

ArrayList
	g_hSkins,
	g_hWeaponModels;

StringMap
	g_hSkinsByName,
	g_hWeaponModelsByClass,
	g_hPurchasedSkins,
	g_hOwnedSkins,
	g_hPlayerChoices,
	g_hLocalChanges,
	g_hTestChoices;

bool
	g_bReadyUpAvailable = false,
	g_bWorldModelsEnabled = false,
	g_bSkinsLoaded = false,
	g_bPlayersLoaded = false;

int g_iActiveWeaponRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iActiveSkin[MAXPLAYERS + 1] = { -1, ... };
int g_iActiveViewModel[MAXPLAYERS + 1] = { -1, ... };
int g_iActiveDefaultViewModel[MAXPLAYERS + 1] = { -1, ... };
int g_iActiveStockFamily[MAXPLAYERS + 1] = { -1, ... };

int g_iWeaponRef[MAX_WEAPON_ENTITIES] = { INVALID_ENT_REFERENCE, ... };
int g_iWeaponSkin[MAX_WEAPON_ENTITIES] = { -1, ... };
int g_iWeaponOriginalSkin[MAX_WEAPON_ENTITIES] = { 0, ... };

int g_iDroppedRef[MAX_WEAPON_ENTITIES] = { INVALID_ENT_REFERENCE, ... };
float g_fDroppedTime[MAX_WEAPON_ENTITIES];

int g_iAllowDownload[MAXPLAYERS + 1] = { -1, ... };
int g_iDownloadFilter[MAXPLAYERS + 1] = { -1, ... };

public void OnPluginStart()
{
	LoadTranslations("l4d2_weapon_skins.phrases");

	g_hEnabled = CreateConVar("weapon_skins_enabled", "0", "Enable the weapon skins", _, true, 0.0, true, 1.0);
	g_hApiUrl = CreateConVar("l4d2_web_url", "", "L4D2 web URL, shared by the plugins that talk to the site", FCVAR_PROTECTED);
	g_hApiSecret = CreateConVar("l4d2_web_secret", "", "L4D2 web secret key, shared by the plugins that talk to the site", FCVAR_PROTECTED);
	g_hKickNoDownloads = CreateConVar("weapon_skins_kick_no_downloads", "0", "Kick players whose game does not download the server files, so everyone can see the skins", _, true, 0.0, true, 1.0);
	g_hPileRadius = CreateConVar("weapon_skins_pile_radius", "120.0", "Radius, in game units, used to find primary weapons dropped close to each other", _, true, 0.0);
	g_hPreviewAll = CreateConVar("weapon_skins_preview_all", "0", "Test mode: every skin is downloaded on the next map and root admins can use any of them, without buying it and outside the ready-up", _, true, 0.0, true, 1.0);
	g_hPileMax = CreateConVar("weapon_skins_pile_max", "3", "Maximum number of dropped primary weapons kept inside the radius; the oldest ones are removed (0 = off)", _, true, 0.0);
	g_hEnabled.AddChangeHook(OnEnabledChanged);
	g_hApiUrl.AddChangeHook(OnApiUrlChanged);

	RegConsoleCmd("sm_skin", Command_Skin, "sm_skin [<skin> | next | prev | default | status] [weapon] - Weapon skins; admins also use on | off | test <skin|default> [weapon]");
	RegConsoleCmd("sm_skins", Command_Skin, "sm_skins [<skin> | next | prev | default | status] [weapon] - Weapon skins; admins also use on | off | test <skin|default> [weapon]");

	HookEvent("round_start", Event_RoundChanged, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundChanged, EventHookMode_PostNoCopy);

	AutoExecConfig(false);

	g_hSkins = new ArrayList(sizeof(WeaponSkin));
	g_hWeaponModels = new ArrayList(sizeof(WeaponModels));
	g_hSkinsByName = new StringMap();
	g_hWeaponModelsByClass = new StringMap();
	g_hPurchasedSkins = new StringMap();
	g_hOwnedSkins = new StringMap();
	g_hPlayerChoices = new StringMap();
	g_hLocalChanges = new StringMap();
	g_hTestChoices = new StringMap();

	LoadPlayersCache();

	CreateTimer(REFRESH_INTERVAL, Timer_Refresh, _, TIMER_REPEAT);

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

	int weapon = GetPlayerWeaponSlot(activator, GetSpawnSlot(entity));
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

	int weapon = GetPlayerWeaponSlot(activator, GetSpawnSlot(entity));
	if (weapon == -1)
	{
		return;
	}

	RefreshWorldModel(activator, weapon);
}

int GetSpawnSlot(int entity)
{
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	if (strncmp(classname, "weapon_pistol", 13) == 0 || strncmp(classname, "weapon_melee", 12) == 0)
	{
		return SECONDARY_SLOT;
	}

	return PRIMARY_SLOT;
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
}

public void OnConfigsExecuted()
{
	RefreshShop();
}

void OnApiUrlChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshShop();
}

void Event_RoundChanged(Event event, const char[] name, bool dontBroadcast)
{
	RefreshShop();
}

Action Timer_Refresh(Handle timer)
{
	if (HasHumanPlayer())
	{
		RefreshShop();
	}

	return Plugin_Continue;
}

bool HasHumanPlayer()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			return true;
		}
	}

	return false;
}

void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshWorldModelsState();
}

bool IsAdmin(int client)
{
	return CheckCommandAccess(client, "sm_weaponskins_admin", ADMFLAG_ROOT, true);
}

void ToggleSkins(int client, bool enabled)
{
	if (!IsAdmin(client))
	{
		CReplyToCommand(client, "%T %T", "Tag", client, "NoAccess", client);
		return;
	}

	SetEnabled(client, enabled);
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
	char action[16];
	GetCmdArg(1, action, sizeof(action));

	if (StrEqual(action, "status", false) || (client == 0 && args < 1))
	{
		CReplyToCommand(client, "%T %T", "Tag", client, IsEnabled() ? "StatusOn" : "StatusOff", client);

		if (client > 0)
		{
			RequestWallet(client);
		}

		return Plugin_Handled;
	}

	if (StrEqual(action, "on", false) || StrEqual(action, "off", false))
	{
		ToggleSkins(client, StrEqual(action, "on", false));
		return Plugin_Handled;
	}

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

	if (StrEqual(name, "next", false))
	{
		return CycleSkin(client, args, 1);
	}

	if (StrEqual(name, "prev", false))
	{
		return CycleSkin(client, args, -1);
	}

	if (StrEqual(name, "default", false))
	{
		SelectDefault(client, args, 2);
		return Plugin_Handled;
	}

	if (StrEqual(name, "test", false))
	{
		TestSkin(client, args);
		return Plugin_Handled;
	}

	if (!IsEnabled())
	{
		CPrintToChat(client, "%T %T", "Tag", client, "StatusOff", client);
		return Plugin_Handled;
	}

	char siteUrl[256];
	GetSiteUrl(siteUrl, sizeof(siteUrl));

	int skinIndex;
	if (!g_hSkinsByName.GetValue(name, skinIndex))
	{
		CPrintToChat(client, "%T %T", "Tag", client, "SkinUnknown", client, name, siteUrl);
		return Plugin_Handled;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	if (!HasPreviewAccess(client) && !OwnsSkin(client, skin.name))
	{
		CPrintToChat(client, "%T %T", "Tag", client, "SkinNotOwned", client, skin.name, siteUrl);
		return Plugin_Handled;
	}

	if (!CanChangeNow(client))
	{
		return Plugin_Handled;
	}

	SetChoice(client, skin.weapon, skin.name);

	if (!skin.ready)
	{
		ApplyChoiceToWeapon(client, skin.weapon);
		CPrintToChat(client, "%T %T", "Tag", client, "SkinNextMap", client, skin.name);
		return Plugin_Handled;
	}

	ApplyChoiceToWeapon(client, skin.weapon);

	char weaponName[32];
	GetWeaponDisplayName(skin.weapon, weaponName, sizeof(weaponName));
	CPrintToChat(client, "%T %T", "Tag", client, "SkinSelected", client, weaponName, skin.name);

	return Plugin_Handled;
}

void TestSkin(int client, int args)
{
	if (!IsAdmin(client))
	{
		CPrintToChat(client, "%T %T", "Tag", client, "NoAccess", client);
		return;
	}

	if (args < 2)
	{
		ReplyToCommand(client, "[WeaponSkins] Usage: sm_skin test <skin|default> [weapon]");
		return;
	}

	char name[64];
	GetCmdArg(2, name, sizeof(name));

	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return;
	}

	char weapon[64];
	char key[128];

	if (StrEqual(name, "default", false))
	{
		if (!ResolveWeapon(client, args, 3, weapon, sizeof(weapon)))
		{
			CPrintToChat(client, "%T %T", "Tag", client, "NoWeapon", client);
			return;
		}

		FormatEx(key, sizeof(key), "%s:%s", steamId, weapon);
		g_hTestChoices.Remove(key);
		ApplyChoiceToWeapon(client, weapon);

		ReplyToCommand(client, "[WeaponSkins] Test skin removed from %s.", weapon);
		return;
	}

	int skinIndex;
	if (!g_hSkinsByName.GetValue(name, skinIndex))
	{
		char siteUrl[256];
		GetSiteUrl(siteUrl, sizeof(siteUrl));
		CPrintToChat(client, "%T %T", "Tag", client, "SkinUnknown", client, name, siteUrl);
		return;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	if (!skin.ready)
	{
		ReplyToCommand(client, "[WeaponSkins] %s is not being downloaded yet, so it cannot be tested.", skin.name);
		return;
	}

	FormatEx(key, sizeof(key), "%s:%s", steamId, skin.weapon);
	g_hTestChoices.SetString(key, skin.name);
	ApplyChoiceToWeapon(client, skin.weapon);

	ReplyToCommand(client, "[WeaponSkins] Testing %s on %s until the map changes.", skin.name, skin.weapon);
}

void ShowHelp(int client)
{
	char siteUrl[256];
	GetSiteUrl(siteUrl, sizeof(siteUrl));

	CPrintToChat(client, "%T %T", "Tag", client, "HelpTitle", client);
	CPrintToChat(client, "%T", "HelpSite", client, siteUrl);
	CPrintToChat(client, "%T", "HelpCycle", client);
	CPrintToChat(client, "%T", "HelpChoose", client);
	CPrintToChat(client, "%T", "HelpDefault", client);
	CPrintToChat(client, "%T", "HelpStatus", client);
	CPrintToChat(client, "%T", "HelpReady", client);
}

Action CycleSkin(int client, int args, int direction)
{
	if (!IsEnabled())
	{
		CPrintToChat(client, "%T %T", "Tag", client, "StatusOff", client);
		return Plugin_Handled;
	}

	char weapon[64];
	if (!ResolveWeapon(client, args, 2, weapon, sizeof(weapon)))
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

		if (OwnsSkinFor(client, weapon))
		{
			CPrintToChat(client, "%T %T", "Tag", client, "SkinsNextMap", client, weaponName);
			return Plugin_Handled;
		}

		char siteUrl[256];
		GetSiteUrl(siteUrl, sizeof(siteUrl));
		CPrintToChat(client, "%T %T", "Tag", client, "NoSkinsForWeapon", client, weaponName, siteUrl);
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
		ApplyChoiceToWeapon(client, weapon);

		CPrintToChat(client, "%T %T", "Tag", client, "SkinDefault", client, weaponName);
		return Plugin_Handled;
	}

	g_hSkins.GetArray(available.Get(nextPosition), skin);
	delete available;

	SetChoice(client, weapon, skin.name);
	ApplyChoiceToWeapon(client, weapon);

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
	ApplyChoiceToWeapon(client, weapon);

	char weaponName[32];
	GetWeaponDisplayName(weapon, weaponName, sizeof(weaponName));
	CPrintToChat(client, "%T %T", "Tag", client, "SkinDefault", client, weaponName);
}

bool HasPreviewAccess(int client)
{
	return g_hPreviewAll.BoolValue && client > 0 && CheckCommandAccess(client, "sm_weaponskins_admin", ADMFLAG_ROOT, true);
}

bool CanChangeNow(int client)
{
	if (HasPreviewAccess(client))
	{
		return true;
	}

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
	bool preview = HasPreviewAccess(client);

	WeaponSkin skin;
	for (int i = 0; i < g_hSkins.Length; i++)
	{
		g_hSkins.GetArray(i, skin);

		if (!skin.ready || !StrEqual(skin.weapon, weapon))
		{
			continue;
		}

		if (preview || OwnsSkin(client, skin.name))
		{
			available.Push(i);
		}
	}

	return available;
}

bool OwnsSkin(int client, const char[] name)
{
	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return false;
	}

	return SteamIdOwnsSkin(steamId, name);
}

bool OwnsSkinFor(int client, const char[] weapon)
{
	WeaponSkin skin;
	for (int i = 0; i < g_hSkins.Length; i++)
	{
		g_hSkins.GetArray(i, skin);

		if (StrEqual(skin.weapon, weapon) && OwnsSkin(client, skin.name))
		{
			return true;
		}
	}

	return false;
}

bool SteamIdOwnsSkin(const char[] steamId, const char[] name)
{
	char key[128];
	FormatEx(key, sizeof(key), "%s:%s", steamId, name);

	return g_hOwnedSkins.ContainsKey(key);
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
	if (IsSkinnableEntity(active, weapon, maxlength))
	{
		return true;
	}

	if (IsSkinnableEntity(GetPlayerWeaponSlot(client, PRIMARY_SLOT), weapon, maxlength))
	{
		return true;
	}

	return IsSkinnableEntity(GetPlayerWeaponSlot(client, SECONDARY_SLOT), weapon, maxlength);
}

bool IsSkinnableEntity(int weapon, char[] key, int maxlength)
{
	if (weapon <= MaxClients || !IsValidEntity(weapon))
	{
		return false;
	}

	GetWeaponKey(weapon, key, maxlength);
	return IsSkinnableWeapon(key);
}

void GetWeaponKey(int weapon, char[] key, int maxlength)
{
	GetEntityClassname(weapon, key, maxlength);

	if (!StrEqual(key, "weapon_melee") || !HasEntProp(weapon, Prop_Data, "m_strMapSetScriptName"))
	{
		return;
	}

	char script[32];
	GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", script, sizeof(script));
	FormatEx(key, maxlength, "weapon_melee_%s", script);
}

void NormalizeWeapon(const char[] arg, char[] weapon, int maxlength)
{
	for (int i = 0; i < sizeof(g_sWeaponAliases); i++)
	{
		if (StrEqual(arg, g_sWeaponAliases[i][0], false))
		{
			strcopy(weapon, maxlength, g_sWeaponAliases[i][1]);
			return;
		}
	}

	if (StrContains(arg, "weapon_", false) == 0)
	{
		strcopy(weapon, maxlength, arg);
		return;
	}

	FormatEx(weapon, maxlength, "weapon_%s", arg);
	if (!IsSkinnableWeapon(weapon))
	{
		FormatEx(weapon, maxlength, "weapon_melee_%s", arg);
	}
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
	for (int i = 0; i < sizeof(g_sWeaponNames); i++)
	{
		if (StrEqual(weapon, g_sWeaponNames[i][0]))
		{
			strcopy(name, maxlength, g_sWeaponNames[i][1]);
			return;
		}
	}

	strcopy(name, maxlength, weapon);
}

void GetSiteUrl(char[] url, int maxlength)
{
	GetApiUrl(url, maxlength);
	StrCat(url, maxlength, "/skins");
}

bool GetApiUrl(char[] url, int maxlength)
{
	g_hApiUrl.GetString(url, maxlength);
	TrimTrailingSlash(url);

	return url[0] != '\0';
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
	SaveEquippedSkin(steamId, weapon, name);
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
		SaveEquippedSkin(steamId, weapon, "");
	}
}

void SaveEquippedSkin(const char[] steamId, const char[] weapon, const char[] name)
{
	char key[128];
	FormatEx(key, sizeof(key), "%s:%s", steamId, weapon);
	g_hLocalChanges.SetValue(key, GetEngineTime());

	if (name[0] != '\0' && !SteamIdOwnsSkin(steamId, name))
	{
		return;
	}

	char apiUrl[256];
	if (!GetApiUrl(apiUrl, sizeof(apiUrl)))
	{
		return;
	}

	char endpoint[320];
	FormatEx(endpoint, sizeof(endpoint), "%s/api/players/%s/skins/equip", apiUrl, steamId);

	char secret[256];
	g_hApiSecret.GetString(secret, sizeof(secret));

	JSONObject body = new JSONObject();
	body.SetString("weapon", weapon);
	body.SetString("skin", name);

	HTTPRequest request = new HTTPRequest(endpoint);
	request.SetHeader("Authorization", secret);
	request.Post(body, OnEquippedSkinSaved);

	delete body;
}

void OnEquippedSkinSaved(HTTPResponse response, any value)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogError("Could not save the equipped skin (HTTP %d)", response.Status);
	}
}

void RefreshShop()
{
	char apiUrl[256];
	if (!GetApiUrl(apiUrl, sizeof(apiUrl)))
	{
		return;
	}

	char endpoint[320];

	FormatEx(endpoint, sizeof(endpoint), "%s/api/skins", apiUrl);
	HTTPRequest skinsRequest = new HTTPRequest(endpoint);
	skinsRequest.Get(OnPurchasedSkinsResponse);

	FormatEx(endpoint, sizeof(endpoint), "%s/api/players/skins", apiUrl);
	HTTPRequest playersRequest = new HTTPRequest(endpoint);
	playersRequest.Get(OnPlayerSkinsResponse, GetEngineTime());
}

void OnPurchasedSkinsResponse(HTTPResponse response, any value)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogError("Could not load the purchased skins (HTTP %d)", response.Status);
		return;
	}

	JSONArray skins = view_as<JSONArray>(response.Data);
	if (!ReadPurchasedSkins(skins))
	{
		LogError("Ignored an invalid purchased skin list from the API");
		return;
	}

	SaveCache(skins, SKINS_CACHE_PATH);
}

void OnPlayerSkinsResponse(HTTPResponse response, any requestedAt)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogError("Could not load the player skins (HTTP %d)", response.Status);
		return;
	}

	JSONArray players = view_as<JSONArray>(response.Data);
	if (!ReadPlayerSkins(players, view_as<float>(requestedAt)))
	{
		LogError("Ignored an invalid player skin list from the API");
		return;
	}

	SaveCache(players, PLAYERS_CACHE_PATH);
}

bool ReadPurchasedSkins(JSONArray skins)
{
	StringMap purchased = new StringMap();

	for (int i = 0; i < skins.Length; i++)
	{
		JSONObject skin = view_as<JSONObject>(skins.Get(i));

		if (!skin.HasKey("id"))
		{
			delete skin;
			delete purchased;
			return false;
		}

		char id[64];
		skin.GetString("id", id, sizeof(id));
		purchased.SetValue(id, true);

		delete skin;
	}

	delete g_hPurchasedSkins;
	g_hPurchasedSkins = purchased;
	g_bSkinsLoaded = true;

	return true;
}

bool ReadPlayerSkins(JSONArray players, float requestedAt)
{
	StringMap owned = new StringMap();
	StringMap choices = new StringMap();

	for (int i = 0; i < players.Length; i++)
	{
		JSONObject player = view_as<JSONObject>(players.Get(i));

		if (!player.HasKey("communityId") || !player.HasKey("skins") || !player.HasKey("equipped"))
		{
			delete player;
			delete owned;
			delete choices;
			return false;
		}

		char communityId[32];
		player.GetString("communityId", communityId, sizeof(communityId));

		char key[128];
		char name[64];
		char weapon[64];

		JSONArray skins = view_as<JSONArray>(player.Get("skins"));
		for (int j = 0; j < skins.Length; j++)
		{
			skins.GetString(j, name, sizeof(name));
			FormatEx(key, sizeof(key), "%s:%s", communityId, name);
			owned.SetValue(key, true);
		}
		delete skins;

		JSONArray equipped = view_as<JSONArray>(player.Get("equipped"));
		for (int j = 0; j < equipped.Length; j++)
		{
			JSONObject item = view_as<JSONObject>(equipped.Get(j));

			if (item.HasKey("weapon") && item.HasKey("skin"))
			{
				item.GetString("weapon", weapon, sizeof(weapon));
				item.GetString("skin", name, sizeof(name));
				FormatEx(key, sizeof(key), "%s:%s", communityId, weapon);
				choices.SetString(key, name);
			}

			delete item;
		}
		delete equipped;

		delete player;
	}

	KeepLocalChanges(choices, requestedAt);

	StringMap previous = g_hOwnedSkins;
	bool notify = g_bPlayersLoaded;

	g_hOwnedSkins = owned;
	delete g_hPlayerChoices;
	g_hPlayerChoices = choices;
	g_bPlayersLoaded = true;

	if (notify)
	{
		NotifyNewPurchases(previous);
	}

	delete previous;

	return true;
}

void KeepLocalChanges(StringMap choices, float requestedAt)
{
	StringMapSnapshot snapshot = g_hLocalChanges.Snapshot();

	char key[128];
	char name[64];
	float changedAt;

	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, key, sizeof(key));
		g_hLocalChanges.GetValue(key, changedAt);

		if (requestedAt > changedAt + LOCAL_CHANGE_GRACE)
		{
			g_hLocalChanges.Remove(key);
			continue;
		}

		if (g_hPlayerChoices.GetString(key, name, sizeof(name)))
		{
			choices.SetString(key, name);
			continue;
		}

		choices.Remove(key);
	}

	delete snapshot;
}

void NotifyNewPurchases(StringMap previous)
{
	StringMapSnapshot snapshot = g_hOwnedSkins.Snapshot();

	char key[128];
	char parts[2][64];

	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, key, sizeof(key));

		if (previous.ContainsKey(key) || ExplodeString(key, ":", parts, sizeof(parts), sizeof(parts[])) != 2)
		{
			continue;
		}

		int client = FindClientBySteamId(parts[0]);
		if (client != 0)
		{
			NotifyPurchase(client, parts[1]);
		}
	}

	delete snapshot;
}

void NotifyPurchase(int client, const char[] name)
{
	int skinIndex;
	if (!g_hSkinsByName.GetValue(name, skinIndex))
	{
		return;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	char weaponName[32];
	GetWeaponDisplayName(skin.weapon, weaponName, sizeof(weaponName));

	if (!skin.ready)
	{
		CPrintToChat(client, "%T %T", "Tag", client, "PurchaseNextMap", client, skin.name, weaponName);
		return;
	}

	ApplyChoiceToWeapon(client, skin.weapon);
	CPrintToChat(client, "%T %T", "Tag", client, "PurchaseReady", client, skin.name, weaponName);
}

int FindClientBySteamId(const char[] steamId)
{
	char clientSteamId[32];

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetSteamId(client, clientSteamId, sizeof(clientSteamId)) && StrEqual(clientSteamId, steamId))
		{
			return client;
		}
	}

	return 0;
}

int CountOwnedSkins(const char[] steamId)
{
	StringMapSnapshot snapshot = g_hOwnedSkins.Snapshot();

	char prefix[40];
	FormatEx(prefix, sizeof(prefix), "%s:", steamId);

	char key[128];
	int count = 0;

	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, key, sizeof(key));

		if (StrContains(key, prefix) == 0)
		{
			count++;
		}
	}

	delete snapshot;

	return count;
}

void RequestWallet(int client)
{
	char steamId[32];
	char apiUrl[256];

	if (!GetSteamId(client, steamId, sizeof(steamId)) || !GetApiUrl(apiUrl, sizeof(apiUrl)))
	{
		return;
	}

	char endpoint[320];
	FormatEx(endpoint, sizeof(endpoint), "%s/api/players/%s/wallet", apiUrl, steamId);

	HTTPRequest request = new HTTPRequest(endpoint);
	request.Get(OnWalletResponse, GetClientUserId(client));
}

void OnWalletResponse(HTTPResponse response, any userId)
{
	int client = GetClientOfUserId(userId);
	if (client == 0)
	{
		return;
	}

	if (response.Status != HTTPStatus_OK)
	{
		CPrintToChat(client, "%T %T", "Tag", client, "WalletUnavailable", client);
		return;
	}

	char steamId[32];
	if (!GetSteamId(client, steamId, sizeof(steamId)))
	{
		return;
	}

	JSONObject wallet = view_as<JSONObject>(response.Data);

	char siteUrl[256];
	GetSiteUrl(siteUrl, sizeof(siteUrl));

	CPrintToChat(client, "%T %T", "Tag", client, "Wallet", client, wallet.GetInt("balance"), CountOwnedSkins(steamId), siteUrl);
}

void ApplyChoiceToWeapon(int client, const char[] weaponClass)
{
	char key[64];
	int weapon = GetPlayerWeaponSlot(client, PRIMARY_SLOT);
	if (!IsSkinnableEntity(weapon, key, sizeof(key)) || !StrEqual(key, weaponClass))
	{
		weapon = GetPlayerWeaponSlot(client, SECONDARY_SLOT);
		if (!IsSkinnableEntity(weapon, key, sizeof(key)) || !StrEqual(key, weaponClass))
		{
			return;
		}
	}

	if (weapon >= MAX_WEAPON_ENTITIES)
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
		RestoreViewModel(client, previous.viewModelIndex, previous.defaultViewModelIndex);
	}

	TrackWeapon(weapon);
	g_iWeaponSkin[weapon] = skinIndex;

	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == weapon)
	{
		g_iActiveWeaponRef[client] = g_iWeaponRef[weapon];
		g_iActiveSkin[client] = skinIndex;
		RefreshActiveViewModel(client, weapon);
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
	g_iActiveViewModel[client] = -1;
	g_iActiveStockFamily[client] = -1;

	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);

	if (IsFakeClient(client))
	{
		return;
	}

	if (g_iAllowDownload[client] == -1 || g_iDownloadFilter[client] == -1)
	{
		QueryDownloadSettings(client);
	}

	RefreshWorldModelsState();
}

public void OnClientConnected(int client)
{
	g_iAllowDownload[client] = -1;
	g_iDownloadFilter[client] = -1;

	if (IsFakeClient(client))
	{
		return;
	}

	QueryDownloadSettings(client);
}

public void OnClientDisconnect(int client)
{
	g_iActiveWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iActiveSkin[client] = -1;
	g_iActiveViewModel[client] = -1;
	g_iActiveStockFamily[client] = -1;
}

public void OnClientDisconnect_Post(int client)
{
	g_iAllowDownload[client] = -1;
	g_iDownloadFilter[client] = -1;

	RefreshWorldModelsState();
}

void QueryDownloadSettings(int client)
{
	int userId = GetClientUserId(client);
	QueryClientConVar(client, "cl_allowdownload", OnAllowDownloadQueried, userId);
	QueryClientConVar(client, "cl_downloadfilter", OnDownloadFilterQueried, userId);
}

void OnAllowDownloadQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any userId)
{
	if (GetClientOfUserId(userId) != client || result != ConVarQuery_Okay)
	{
		return;
	}

	g_iAllowDownload[client] = StringToInt(cvarValue) == 1 ? 1 : 0;

	if (g_iAllowDownload[client] == 0)
	{
		KickWithoutDownloads(client, cvarName, cvarValue, "cl_allowdownload 1");
	}

	RefreshWorldModelsState();
}

void OnDownloadFilterQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any userId)
{
	if (GetClientOfUserId(userId) != client || result != ConVarQuery_Okay)
	{
		return;
	}

	g_iDownloadFilter[client] = StrEqual(cvarValue, "all", false) || StrEqual(cvarValue, "nosounds", false) ? 1 : 0;

	if (g_iDownloadFilter[client] == 0)
	{
		KickWithoutDownloads(client, cvarName, cvarValue, "cl_downloadfilter all");
	}

	RefreshWorldModelsState();
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
		if (IsClientInGame(client) && !IsClientInKickQueue(client) && !CanClientSeeSkins(client))
		{
			return true;
		}
	}

	return false;
}

void KickWithoutDownloads(int client, const char[] cvarName, const char[] cvarValue, const char[] fix)
{
	if (!g_hKickNoDownloads.BoolValue || !IsEnabled() || IsClientInKickQueue(client))
	{
		return;
	}

	LogMessage("Kicked %L because %s is \"%s\"", client, cvarName, cvarValue);
	KickClient(client, "%T", "KickNoDownloads", client, cvarName, cvarValue, fix);
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

	if (!g_bSkinsLoaded)
	{
		LoadSkinsCache();
	}

	LoadWeaponModels(kv);
	LoadSkinDefinitions(kv);

	delete kv;
}

void LoadSkinsCache()
{
	JSONArray skins = ReadCache(SKINS_CACHE_PATH);
	if (skins == null)
	{
		return;
	}

	if (!ReadPurchasedSkins(skins))
	{
		LogError("Ignored an invalid purchased skin list in %s", SKINS_CACHE_PATH);
	}

	delete skins;
}

void LoadPlayersCache()
{
	JSONArray players = ReadCache(PLAYERS_CACHE_PATH);
	if (players == null)
	{
		return;
	}

	if (!ReadPlayerSkins(players, 0.0))
	{
		LogError("Ignored an invalid player skin list in %s", PLAYERS_CACHE_PATH);
	}

	delete players;
}

JSONArray ReadCache(const char[] file)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), file);

	if (!FileExists(path))
	{
		return null;
	}

	JSONArray data = JSONArray.FromFile(path);
	if (data == null)
	{
		LogError("Could not read %s", path);
	}

	return data;
}

void SaveCache(JSONArray data, const char[] file)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), file);

	if (!data.ToFile(path))
	{
		LogError("Could not write %s", path);
	}
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
		models.stockSkins = kv.GetNum("stock_skins", 0);

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

	if (!models.ready || (!g_hPreviewAll.BoolValue && !g_hPurchasedSkins.ContainsKey(skin.name)))
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

Action OnWeaponDrop(int client, int weapon)
{
	if (weapon > MaxClients && weapon < MAX_WEAPON_ENTITIES && GetPlayerWeaponSlot(client, PRIMARY_SLOT) == weapon)
	{
		TrackDroppedWeapon(weapon);
	}

	return Plugin_Continue;
}

void OnWeaponDropPost(int client, int weapon)
{
	if (GetWeaponSkin(client, weapon) == -1)
	{
		return;
	}

	CreateTimer(DROPPED_MODEL_DELAY, Timer_ApplyDroppedWorldModel, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);
}

void TrackDroppedWeapon(int weapon)
{
	int weaponRef = EntIndexToEntRef(weapon);
	g_iDroppedRef[weapon] = weaponRef;
	g_fDroppedTime[weapon] = GetGameTime();

	CreateTimer(PILE_CHECK_DELAY, Timer_CleanWeaponPile, weaponRef, TIMER_FLAG_NO_MAPCHANGE);
}

bool IsLooseDroppedWeapon(int weapon)
{
	return g_iDroppedRef[weapon] != INVALID_ENT_REFERENCE
		&& g_iDroppedRef[weapon] == EntIndexToEntRef(weapon)
		&& GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == -1;
}

Action Timer_CleanWeaponPile(Handle timer, int weaponRef)
{
	int weapon = EntRefToEntIndex(weaponRef);
	int maxWeapons = g_hPileMax.IntValue;

	if (weapon == INVALID_ENT_REFERENCE || maxWeapons <= 0 || !IsLooseDroppedWeapon(weapon))
	{
		return Plugin_Stop;
	}

	float radius = g_hPileRadius.FloatValue;
	float center[3];
	GetEntPropVector(weapon, Prop_Data, "m_vecAbsOrigin", center);

	ArrayList pile = new ArrayList();
	float position[3];

	for (int entity = MaxClients + 1; entity < MAX_WEAPON_ENTITIES; entity++)
	{
		if (g_iDroppedRef[entity] == INVALID_ENT_REFERENCE || !IsValidEntity(entity) || !IsLooseDroppedWeapon(entity))
		{
			continue;
		}

		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", position);
		if (GetVectorDistance(center, position) <= radius)
		{
			pile.Push(entity);
		}
	}

	while (pile.Length > maxWeapons)
	{
		int oldest = 0;
		for (int i = 1; i < pile.Length; i++)
		{
			if (g_fDroppedTime[pile.Get(i)] < g_fDroppedTime[pile.Get(oldest)])
			{
				oldest = i;
			}
		}

		RemoveEntity(pile.Get(oldest));
		pile.Erase(oldest);
	}

	delete pile;
	return Plugin_Stop;
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
		RefreshActiveViewModel(client, weapon);
	}

	if (g_iActiveSkin[client] != -1)
	{
		WeaponSkin skin;
		g_hSkins.GetArray(g_iActiveSkin[client], skin);

		ApplyWorldModel(weapon, skin);

		if (CanShowViewModel(client))
		{
			ApplyViewModel(client, skin.viewModelIndex, skin.family);
			return;
		}
	}

	if (g_iActiveViewModel[client] == -1)
	{
		return;
	}

	if (g_iActiveStockFamily[client] != -1 && CanUseCombinedViewModel(client))
	{
		ApplyViewModel(client, g_iActiveViewModel[client], g_iActiveStockFamily[client]);
		return;
	}

	RestoreViewModel(client, g_iActiveViewModel[client], g_iActiveDefaultViewModel[client]);
}

void RefreshActiveViewModel(int client, int weapon)
{
	g_iActiveViewModel[client] = -1;
	g_iActiveStockFamily[client] = -1;

	if (weapon <= MaxClients || !IsValidEntity(weapon))
	{
		return;
	}

	char key[64];
	GetWeaponKey(weapon, key, sizeof(key));

	int modelsIndex;
	if (!g_hWeaponModelsByClass.GetValue(key, modelsIndex))
	{
		return;
	}

	WeaponModels models;
	g_hWeaponModels.GetArray(modelsIndex, models);

	if (!models.ready)
	{
		return;
	}

	g_iActiveViewModel[client] = models.viewModelIndex;
	g_iActiveDefaultViewModel[client] = models.defaultViewModelIndex;

	if (models.stockSkins <= 0)
	{
		return;
	}

	int original = GetOriginalSkin(weapon);
	g_iActiveStockFamily[client] = original >= 0 && original < models.stockSkins ? original : 0;
}

bool CanShowViewModel(int client)
{
	return IsEnabled() && CanUseCombinedViewModel(client);
}

bool CanUseCombinedViewModel(int client)
{
	if (!CanClientSeeSkins(client))
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
	if (weapon <= MaxClients || weapon >= MAX_WEAPON_ENTITIES || g_iWeaponRef[weapon] == INVALID_ENT_REFERENCE || !IsValidEntity(weapon))
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
	GetWeaponKey(weapon, classname, sizeof(classname));

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

	if (!HasPreviewAccess(client) && !SteamIdOwnsSkin(steamId, name))
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

void ApplyViewModel(int client, int modelIndex, int family)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if (viewModel <= MaxClients || !IsValidEntity(viewModel))
	{
		return;
	}

	if (GetEntProp(viewModel, Prop_Send, "m_nModelIndex") != modelIndex)
	{
		SetEntProp(viewModel, Prop_Send, "m_nModelIndex", modelIndex);
	}

	if (GetEntProp(viewModel, Prop_Send, "m_nSkin") != family)
	{
		SetEntProp(viewModel, Prop_Send, "m_nSkin", family);
	}
}

void RestoreViewModel(int client, int modelIndex, int defaultModelIndex)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if (viewModel <= MaxClients || !IsValidEntity(viewModel))
	{
		return;
	}

	if (GetEntProp(viewModel, Prop_Send, "m_nModelIndex") != modelIndex)
	{
		return;
	}

	SetEntProp(viewModel, Prop_Send, "m_nModelIndex", defaultModelIndex);
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
