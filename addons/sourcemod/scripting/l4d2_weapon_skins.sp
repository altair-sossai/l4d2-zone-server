#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CONFIG_PATH "configs/weapon_skins.cfg"
#define MAX_WEAPON_ENTITIES 2048
#define DROPPED_MODEL_DELAY 0.1
#define OBS_MODE_IN_EYE 4

enum struct WeaponSkin
{
	char name[64];
	char weapon[64];
	char viewModel[PLATFORM_MAX_PATH];
	char worldModel[PLATFORM_MAX_PATH];
	char defaultViewModel[PLATFORM_MAX_PATH];
	char defaultWorldModel[PLATFORM_MAX_PATH];
	char models[PLATFORM_MAX_PATH];
	char materials[PLATFORM_MAX_PATH];
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
	description = "Applies custom weapon models, downloaded through FastDL, to specific players based on their SteamID.",
	version = "1.0.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

ArrayList g_hSkins;
StringMap g_hSkinsByName;
StringMap g_hPlayerSkins;

int g_iActiveWeaponRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iActiveSkin[MAXPLAYERS + 1] = { -1, ... };

int g_iWeaponRef[MAX_WEAPON_ENTITIES] = { INVALID_ENT_REFERENCE, ... };
int g_iWeaponSkin[MAX_WEAPON_ENTITIES] = { -1, ... };

int g_iAllowDownload[MAXPLAYERS + 1] = { -1, ... };
int g_iDownloadFilter[MAXPLAYERS + 1] = { -1, ... };

bool g_bWorldModelsEnabled = true;

public void OnPluginStart()
{
	g_hSkins = new ArrayList(sizeof(WeaponSkin));
	g_hSkinsByName = new StringMap();
	g_hPlayerSkins = new StringMap();

	RegAdminCmd("sm_weaponskin", Command_WeaponSkin, ADMFLAG_ROOT, "sm_weaponskin [skin] - Lists the loaded skins or tests one on yourself until the map changes");

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnMapStart()
{
	LoadSkins();
}

Action Command_WeaponSkin(int client, int args)
{
	if (args < 1)
	{
		ListSkins(client);
		return Plugin_Handled;
	}

	if (client == 0)
	{
		ReplyToCommand(client, "[WeaponSkins] This command can only be used in game.");
		return Plugin_Handled;
	}

	char name[64];
	GetCmdArg(1, name, sizeof(name));

	int skinIndex;
	if (!g_hSkinsByName.GetValue(name, skinIndex))
	{
		ReplyToCommand(client, "[WeaponSkins] Unknown skin \"%s\".", name);
		return Plugin_Handled;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	if (!skin.ready)
	{
		ReplyToCommand(client, "[WeaponSkins] Skin \"%s\" is not loaded. Check the error log.", name);
		return Plugin_Handled;
	}

	char key[96];
	FormatEx(key, sizeof(key), "%d:%s", GetSteamAccountID(client), skin.weapon);
	g_hPlayerSkins.SetValue(key, skinIndex);

	ApplySkinToActiveWeapon(client, skinIndex, skin);

	ReplyToCommand(client, "[WeaponSkins] Skin \"%s\" set for %s until the map changes.", name, skin.weapon);
	return Plugin_Handled;
}

void ListSkins(int client)
{
	WeaponSkin skin;
	for (int i = 0; i < g_hSkins.Length; i++)
	{
		g_hSkins.GetArray(i, skin);
		ReplyToCommand(client, "[WeaponSkins] %s (%s)%s", skin.name, skin.weapon, skin.ready ? "" : " - not loaded");
	}
}

void ApplySkinToActiveWeapon(int client, int skinIndex, WeaponSkin skin)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= MaxClients || weapon >= MAX_WEAPON_ENTITIES || !IsValidEntity(weapon))
	{
		return;
	}

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));

	if (!StrEqual(classname, skin.weapon))
	{
		return;
	}

	int previousSkin = GetAssignedWeaponSkin(weapon);
	if (previousSkin != -1 && previousSkin != skinIndex)
	{
		WeaponSkin previous;
		g_hSkins.GetArray(previousSkin, previous);
		RestoreWorldModel(weapon, previous);
		RestoreViewModel(client, previous);
	}

	g_iWeaponRef[weapon] = EntIndexToEntRef(weapon);
	g_iWeaponSkin[weapon] = skinIndex;
	g_iActiveWeaponRef[client] = g_iWeaponRef[weapon];
	g_iActiveSkin[client] = skinIndex;

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
		if (IsClientInGame(client) && !CanClientSeeSkins(client))
		{
			return true;
		}
	}

	return false;
}

void RefreshWorldModelsState()
{
	bool enabled = !HasClientWithoutSkins();
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
	g_hPlayerSkins.Clear();

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CONFIG_PATH);

	KeyValues kv = new KeyValues("WeaponSkins");
	if (!kv.ImportFromFile(path))
	{
		LogError("Could not read %s", path);
		delete kv;
		return;
	}

	LoadSkinDefinitions(kv);
	PrepareSkins();
	LoadPlayerSkins(kv);

	delete kv;
}

void PrepareSkins()
{
	WeaponSkin skin;
	for (int i = 0; i < g_hSkins.Length; i++)
	{
		g_hSkins.GetArray(i, skin);
		skin.ready = PrepareSkin(skin);
		g_hSkins.SetArray(i, skin);
	}
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
		kv.GetString("view_model", skin.viewModel, sizeof(skin.viewModel));
		kv.GetString("world_model", skin.worldModel, sizeof(skin.worldModel));
		kv.GetString("default_view_model", skin.defaultViewModel, sizeof(skin.defaultViewModel));
		kv.GetString("default_world_model", skin.defaultWorldModel, sizeof(skin.defaultWorldModel));
		kv.GetString("models", skin.models, sizeof(skin.models));
		kv.GetString("materials", skin.materials, sizeof(skin.materials));

		if (skin.weapon[0] == '\0' || skin.viewModel[0] == '\0' || skin.worldModel[0] == '\0' || skin.defaultViewModel[0] == '\0' || skin.defaultWorldModel[0] == '\0' || skin.models[0] == '\0' || skin.materials[0] == '\0')
		{
			LogError("Skin \"%s\" is missing required keys", skin.name);
			continue;
		}

		g_hSkinsByName.SetValue(skin.name, g_hSkins.PushArray(skin));
	}
	while (kv.GotoNextKey());

	kv.Rewind();
}

bool PrepareSkin(WeaponSkin skin)
{
	if (!FileExists(skin.viewModel) || !FileExists(skin.worldModel))
	{
		LogError("Skin \"%s\" models were not found on the server", skin.name);
		return false;
	}

	AddDirectoryToDownloadsTable(skin.models);
	AddDirectoryToDownloadsTable(skin.materials);

	skin.viewModelIndex = PrecacheModel(skin.viewModel, true);
	skin.worldModelIndex = PrecacheModel(skin.worldModel, true);
	skin.defaultViewModelIndex = PrecacheModel(skin.defaultViewModel, true);
	skin.defaultWorldModelIndex = PrecacheModel(skin.defaultWorldModel, true);

	return true;
}

void LoadPlayerSkins(KeyValues kv)
{
	if (!kv.JumpToKey("Players") || !kv.GotoFirstSubKey())
	{
		kv.Rewind();
		return;
	}

	do
	{
		char steamId[32];
		kv.GetSectionName(steamId, sizeof(steamId));

		int accountId = SteamIdToAccountId(steamId);
		if (accountId == 0)
		{
			LogError("Invalid SteamID \"%s\"", steamId);
			continue;
		}

		LoadPlayerWeapons(kv, accountId);
	}
	while (kv.GotoNextKey());

	kv.Rewind();
}

void LoadPlayerWeapons(KeyValues kv, int accountId)
{
	if (!kv.GotoFirstSubKey(false))
	{
		return;
	}

	do
	{
		char weapon[64];
		char skinName[64];
		kv.GetSectionName(weapon, sizeof(weapon));
		kv.GetString(NULL_STRING, skinName, sizeof(skinName));

		int skinIndex;
		if (!g_hSkinsByName.GetValue(skinName, skinIndex))
		{
			LogError("Unknown skin \"%s\"", skinName);
			continue;
		}

		WeaponSkin skin;
		g_hSkins.GetArray(skinIndex, skin);

		if (!StrEqual(skin.weapon, weapon))
		{
			LogError("Skin \"%s\" belongs to %s, not %s", skinName, skin.weapon, weapon);
			continue;
		}

		char key[96];
		FormatEx(key, sizeof(key), "%d:%s", accountId, weapon);
		g_hPlayerSkins.SetValue(key, skinIndex);
	}
	while (kv.GotoNextKey(false));

	kv.GoBack();
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

	int weaponRef = EntIndexToEntRef(weapon);
	if (g_iWeaponRef[weapon] != weaponRef)
	{
		g_iWeaponRef[weapon] = weaponRef;
		g_iWeaponSkin[weapon] = GetPlayerWeaponSkin(client, weapon);
	}

	return g_iWeaponSkin[weapon];
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
	int accountId = GetSteamAccountID(client);
	if (accountId == 0)
	{
		return -1;
	}

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));

	char key[96];
	FormatEx(key, sizeof(key), "%d:%s", accountId, classname);

	int skinIndex;
	if (!g_hPlayerSkins.GetValue(key, skinIndex))
	{
		return -1;
	}

	WeaponSkin skin;
	g_hSkins.GetArray(skinIndex, skin);

	if (!skin.ready)
	{
		return -1;
	}

	return skinIndex;
}

void ApplyViewModel(int client, WeaponSkin skin)
{
	int viewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if (viewModel <= MaxClients || !IsValidEntity(viewModel))
	{
		return;
	}

	if (GetEntProp(viewModel, Prop_Send, "m_nModelIndex") == skin.viewModelIndex)
	{
		return;
	}

	SetEntProp(viewModel, Prop_Send, "m_nModelIndex", skin.viewModelIndex);
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
}

void RestoreWorldModel(int weapon, WeaponSkin skin)
{
	if (GetEntProp(weapon, Prop_Send, "m_nModelIndex") == skin.worldModelIndex)
	{
		SetEntityModel(weapon, skin.defaultWorldModel);
	}

	if (!HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex"))
	{
		return;
	}

	if (GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") != skin.worldModelIndex)
	{
		return;
	}

	SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", skin.defaultWorldModelIndex);
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

	if (!HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex"))
	{
		return;
	}

	if (GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") == skin.worldModelIndex)
	{
		return;
	}

	SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", skin.worldModelIndex);
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

int SteamIdToAccountId(const char[] steamId)
{
	if (strncmp(steamId, "STEAM_", 6) != 0)
	{
		return 0;
	}

	char parts[3][16];
	if (ExplodeString(steamId[6], ":", parts, sizeof(parts), sizeof(parts[])) != 3)
	{
		return 0;
	}

	return StringToInt(parts[2]) * 2 + StringToInt(parts[1]);
}
