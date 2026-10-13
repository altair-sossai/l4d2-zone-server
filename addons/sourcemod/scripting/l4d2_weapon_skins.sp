#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CONFIG_PATH "configs/weapon_skins.cfg"
#define MAX_WEAPON_ENTITIES 2048

enum struct WeaponSkin
{
	char weapon[64];
	char viewModel[PLATFORM_MAX_PATH];
	char worldModel[PLATFORM_MAX_PATH];
	char defaultWorldModel[PLATFORM_MAX_PATH];
	char materials[PLATFORM_MAX_PATH];
	int viewModelIndex;
	int worldModelIndex;
	int defaultWorldModelIndex;
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
StringMap g_hPlayerSkins;

int g_iActiveWeaponRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iActiveSkin[MAXPLAYERS + 1] = { -1, ... };

int g_iWeaponRef[MAX_WEAPON_ENTITIES] = { INVALID_ENT_REFERENCE, ... };
int g_iWeaponSkin[MAX_WEAPON_ENTITIES] = { -1, ... };

public void OnPluginStart()
{
	g_hSkins = new ArrayList(sizeof(WeaponSkin));
	g_hPlayerSkins = new StringMap();

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

public void OnClientPutInServer(int client)
{
	g_iActiveWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iActiveSkin[client] = -1;

	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnClientDisconnect(int client)
{
	g_iActiveWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iActiveSkin[client] = -1;
}

void LoadSkins()
{
	g_hSkins.Clear();
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

	StringMap skinsByName = new StringMap();

	LoadSkinDefinitions(kv, skinsByName);
	LoadPlayerSkins(kv, skinsByName);

	delete skinsByName;
	delete kv;
}

void LoadSkinDefinitions(KeyValues kv, StringMap skinsByName)
{
	if (!kv.JumpToKey("Skins") || !kv.GotoFirstSubKey())
	{
		kv.Rewind();
		return;
	}

	do
	{
		char name[64];
		kv.GetSectionName(name, sizeof(name));

		WeaponSkin skin;
		kv.GetString("weapon", skin.weapon, sizeof(skin.weapon));
		kv.GetString("view_model", skin.viewModel, sizeof(skin.viewModel));
		kv.GetString("world_model", skin.worldModel, sizeof(skin.worldModel));
		kv.GetString("default_world_model", skin.defaultWorldModel, sizeof(skin.defaultWorldModel));
		kv.GetString("materials", skin.materials, sizeof(skin.materials));

		if (!PrepareSkin(name, skin))
		{
			continue;
		}

		skinsByName.SetValue(name, g_hSkins.PushArray(skin));
	}
	while (kv.GotoNextKey());

	kv.Rewind();
}

bool PrepareSkin(const char[] name, WeaponSkin skin)
{
	if (skin.weapon[0] == '\0' || skin.viewModel[0] == '\0' || skin.worldModel[0] == '\0' || skin.defaultWorldModel[0] == '\0')
	{
		LogError("Skin \"%s\" is missing required keys", name);
		return false;
	}

	if (!FileExists(skin.viewModel) || !FileExists(skin.worldModel))
	{
		LogError("Skin \"%s\" models were not found on the server", name);
		return false;
	}

	AddModelToDownloadsTable(skin.viewModel);
	AddModelToDownloadsTable(skin.worldModel);

	if (skin.materials[0] != '\0')
	{
		AddDirectoryToDownloadsTable(skin.materials);
	}

	skin.viewModelIndex = PrecacheModel(skin.viewModel, true);
	skin.worldModelIndex = PrecacheModel(skin.worldModel, true);
	skin.defaultWorldModelIndex = PrecacheModel(skin.defaultWorldModel, true);

	return true;
}

void LoadPlayerSkins(KeyValues kv, StringMap skinsByName)
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

		LoadPlayerWeapons(kv, skinsByName, accountId);
	}
	while (kv.GotoNextKey());

	kv.Rewind();
}

void LoadPlayerWeapons(KeyValues kv, StringMap skinsByName, int accountId)
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
		if (!skinsByName.GetValue(skinName, skinIndex))
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
	RefreshWorldModel(client, weapon);
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
	ApplyViewModel(client, skin);
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

void ApplyWorldModel(int weapon, WeaponSkin skin)
{
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

void AddModelToDownloadsTable(const char[] model)
{
	char base[PLATFORM_MAX_PATH];
	strcopy(base, sizeof(base), model);
	ReplaceString(base, sizeof(base), ".mdl", "", false);

	static const char extensions[][] = { ".mdl", ".vvd", ".dx90.vtx", ".phy" };

	char file[PLATFORM_MAX_PATH];
	for (int i = 0; i < sizeof(extensions); i++)
	{
		FormatEx(file, sizeof(file), "%s%s", base, extensions[i]);

		if (FileExists(file))
		{
			AddFileToDownloadsTable(file);
		}
	}
}

void AddDirectoryToDownloadsTable(const char[] directory)
{
	DirectoryListing listing = OpenDirectory(directory);
	if (listing == null)
	{
		LogError("Could not open materials folder %s", directory);
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
