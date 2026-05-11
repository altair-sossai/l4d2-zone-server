#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.0"
#define INVALID_TOUCH_TIME -9999.0

public Plugin myinfo =
{
	name = "[L4D & 2] Fix Ghost Door Spawn",
	author = "Altair, SirPlease",
	description = "Blocks ghost infected materialization when close to a door.",
	version = PLUGIN_VERSION,
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar g_hCvarEnabled;
ConVar g_hCvarBlockTime;
ConVar g_hCvarTolerance;
ConVar g_hCvarDebug;

float g_fLastDoorProximity[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_hCvarEnabled = CreateConVar(
		"l4d_fix_ghost_door_spawn_enable",
		"1",
		"Enable the ghost door spawn exploit fix.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 1.0
	);

	g_hCvarBlockTime = CreateConVar(
		"l4d_fix_ghost_door_spawn_block_time",
		"0.35",
		"How long to block ghost infected materialization after touching or being near a door.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 2.0
	);

	g_hCvarTolerance = CreateConVar(
		"l4d_fix_ghost_door_spawn_tolerance",
		"96.0",
		"Distance tolerance from door origin to mark ghost infected materialization as unsafe.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 256.0
	);

	g_hCvarDebug = CreateConVar(
		"l4d_fix_ghost_door_spawn_debug",
		"0",
		"Log ghost door proximity and blocked materialization attempts.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 1.0
	);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	ResetDoorProximityTimes();
	HookExistingDoors();
}

public void OnMapStart()
{
	ResetDoorProximityTimes();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetDoorProximityTimes();
}

public void OnClientDisconnect(int client)
{
	g_fLastDoorProximity[client] = INVALID_TOUCH_TIME;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsDoorClassname(classname))
		SDKHook(entity, SDKHook_Touch, SDK_OnDoorTouch);
}

Action SDK_OnDoorTouch(int door, int client)
{
	if (!g_hCvarEnabled.BoolValue || !IsValidGhostInfected(client))
		return Plugin_Continue;

	MarkDoorProximity(client);

	if (g_hCvarDebug.BoolValue)
		LogMessage("Ghost %N touched door %d.", client, door);

	return Plugin_Continue;
}

public void L4D_OnEnterGhostState(int client)
{
	if (!IsValidGhostInfected(client))
		return;

	g_fLastDoorProximity[client] = INVALID_TOUCH_TIME;

	SDKUnhook(client, SDKHook_PreThinkPost, SDK_OnPreThinkPost);
	SDKHook(client, SDKHook_PreThinkPost, SDK_OnPreThinkPost);
}

void SDK_OnPreThinkPost(int client)
{
	if (!IsValidGhostInfected(client))
	{
		SDKUnhook(client, SDKHook_PreThinkPost, SDK_OnPreThinkPost);
		return;
	}

	if (IsNearAnyDoor(client))
		MarkDoorProximity(client);
}

public Action L4D_OnMaterializeFromGhostPre(int client)
{
	if (!g_hCvarEnabled.BoolValue || !IsValidGhostInfected(client))
		return Plugin_Continue;

	if (!IsNearAnyDoor(client) && !HasRecentDoorProximity(client))
		return Plugin_Continue;

	BlockGhostSpawn(client);
	return Plugin_Handled;
}

bool IsValidGhostInfected(int client)
{
	return client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& !IsFakeClient(client)
		&& GetClientTeam(client) == L4D_TEAM_INFECTED
		&& L4D_IsPlayerGhost(client);
}

bool IsNearAnyDoor(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	return IsNearEntityByClassname(origin, "prop_door_rotating")
		|| IsNearEntityByClassname(origin, "prop_door_rotating_checkpoint");
}

bool IsNearEntityByClassname(const float origin[3], const char[] classname)
{
	float doorOrigin[3];
	float tolerance = g_hCvarTolerance.FloatValue;
	int entity = INVALID_ENT_REFERENCE;

	while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", doorOrigin);

		if (GetVectorDistance(origin, doorOrigin, false) <= tolerance)
			return true;
	}

	return false;
}

bool HasRecentDoorProximity(int client)
{
	if (g_fLastDoorProximity[client] == INVALID_TOUCH_TIME)
		return false;

	return GetGameTime() - g_fLastDoorProximity[client] <= g_hCvarBlockTime.FloatValue;
}

void MarkDoorProximity(int client)
{
	g_fLastDoorProximity[client] = GetGameTime();
}

void BlockGhostSpawn(int client)
{
	int spawnstate = L4D_GetPlayerGhostSpawnState(client);
	L4D_SetPlayerGhostSpawnState(client, spawnstate | L4D_SPAWNFLAG_RESTRICTEDAREA);

	if (g_hCvarDebug.BoolValue)
		LogMessage("Blocked ghost spawn near door for %N.", client);
}

bool IsDoorClassname(const char[] classname)
{
	return StrEqual(classname, "prop_door_rotating", false)
		|| StrEqual(classname, "prop_door_rotating_checkpoint", false);
}

void HookExistingDoors()
{
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != INVALID_ENT_REFERENCE)
		SDKHook(entity, SDKHook_Touch, SDK_OnDoorTouch);

	entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
		SDKHook(entity, SDKHook_Touch, SDK_OnDoorTouch);
}

void ResetDoorProximityTimes()
{
	for (int i = 1; i <= MaxClients; ++i)
		g_fLastDoorProximity[i] = INVALID_TOUCH_TIME;
}
