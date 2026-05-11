#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Fix Ghost Door Spawn",
	author = "Altair, SirPlease",
	description = "Blocks ghost infected materialization near door positions.",
	version = PLUGIN_VERSION,
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar g_hCvarEnabled;
ConVar g_hCvarDistance;
ConVar g_hCvarDebug;

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

	g_hCvarDistance = CreateConVar(
		"l4d_fix_ghost_door_spawn_distance",
		"96.0",
		"Distance around door positions where ghost infected materialization is blocked.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 256.0
	);

	g_hCvarDebug = CreateConVar(
		"l4d_fix_ghost_door_spawn_debug",
		"0",
		"Log blocked materialization attempts.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 1.0
	);
}

public Action L4D_OnMaterializeFromGhostPre(int client)
{
	if (!g_hCvarEnabled.BoolValue || !IsValidGhostInfected(client))
		return Plugin_Continue;

	if (!IsClientInsideDoorArea(client))
		return Plugin_Continue;

	BlockGhostSpawn(client);
	return Plugin_Handled;
}

bool IsClientInsideDoorArea(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	return IsPositionInsideDoorArea(origin);
}

bool IsPositionInsideDoorArea(const float origin[3])
{
	return IsPositionNearDoorsByClassname(origin, "prop_door_rotating")
		|| IsPositionNearDoorsByClassname(origin, "prop_door_rotating_checkpoint");
}

bool IsPositionNearDoorsByClassname(const float origin[3], const char[] classname)
{
	float doorOrigin[3];
	float maxDistance = g_hCvarDistance.FloatValue;
	int entity = INVALID_ENT_REFERENCE;

	while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", doorOrigin);

		if (GetVectorDistance(origin, doorOrigin, false) <= maxDistance)
			return true;
	}

	return false;
}

void BlockGhostSpawn(int client)
{
	int spawnstate = L4D_GetPlayerGhostSpawnState(client);
	L4D_SetPlayerGhostSpawnState(client, spawnstate | L4D_SPAWNFLAG_RESTRICTEDAREA);

	if (g_hCvarDebug.BoolValue)
		LogMessage("Blocked ghost spawn near door for %N.", client);
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
