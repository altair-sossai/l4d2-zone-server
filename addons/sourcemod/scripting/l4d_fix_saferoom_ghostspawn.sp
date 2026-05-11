#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "2.1.0"

public Plugin myinfo =
{
	name = "[L4D & 2] Fix Saferoom Ghost Spawn",
	author = "Forgetest",
	description = "Fix a glitch that ghost can spawn in saferoom while it shouldn't.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

int g_iOffs_LastSurvivorLeftStartArea;
Address gpTheDirector;

ConVar g_hCvarEnabled;
ConVar g_hCvarDoorRange;
ConVar g_hCvarDebug;

public void OnPluginStart()
{
	g_hCvarEnabled = CreateConVar(
		"l4d_fix_saferoom_ghostspawn_enable",
		"1",
		"Enable the saferoom ghost spawn exploit fix.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 1.0
	);

	g_hCvarDoorRange = CreateConVar(
		"l4d_fix_saferoom_ghostspawn_door_range",
		"350.0",
		"Max distance from a closed checkpoint door for the fallback spawn block.",
		FCVAR_NOTIFY,
		true, 64.0,
		true, 1024.0
	);

	g_hCvarDebug = CreateConVar(
		"l4d_fix_saferoom_ghostspawn_debug",
		"0",
		"Log blocked saferoom ghost spawn attempts.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 1.0
	);

	GameData gd = new GameData("l4d_fix_saferoom_ghostspawn");
	if (!gd)
		SetFailState("Missing gamedata \"l4d_fix_saferoom_ghostspawn\"");
	
	g_iOffs_LastSurvivorLeftStartArea = gd.GetOffset("CDirector::m_bLastSurvivorLeftStartArea");
	if (g_iOffs_LastSurvivorLeftStartArea == -1)
		SetFailState("Missing offset \"CDirector::m_bLastSurvivorLeftStartArea\"");
	
	delete gd;
	
	LateLoad();
}

void LateLoad()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && L4D_IsPlayerGhost(i))
			L4D_OnEnterGhostState(i);
	}
}

public void OnAllPluginsLoaded()
{
	gpTheDirector = L4D_GetPointer(POINTER_DIRECTOR);
}

public Action L4D_OnMaterializeFromGhostPre(int client)
{
	if (!g_hCvarEnabled.BoolValue || !IsValidGhostInfected(client))
		return Plugin_Continue;

	if (!IsClosedSaferoomSpawnAttempt(client))
		return Plugin_Continue;

	BlockGhostSpawn(client);
	return Plugin_Handled;
}

public void L4D_OnEnterGhostState(int client)
{
	if (!g_hCvarEnabled.BoolValue || !IsValidGhostInfected(client))
		return;
	
	SDKHook(client, SDKHook_PreThinkPost, SDK_OnPreThink_Post);
}

void SDK_OnPreThink_Post(int client)
{
	if (!IsClientInGame(client))
		return;
	
	if (!L4D_IsPlayerGhost(client))
	{
		SDKUnhook(client, SDKHook_PreThinkPost, SDK_OnPreThink_Post);
	}
	else
	{
		if (!g_hCvarEnabled.BoolValue)
			return;

		if (IsClosedSaferoomSpawnAttempt(client))
		{
			BlockGhostSpawn(client);
			return;
		}

		int spawnstate = L4D_GetPlayerGhostSpawnState(client);
		if (spawnstate & L4D_SPAWNFLAG_RESTRICTEDAREA)
			return;
		
		Address area = L4D_GetLastKnownArea(client);
		if (area == Address_Null)
			return;
		
		if (HasLastSurvivorLeftStartArea()) // therefore free spawn in saferoom
			return;
		
		// Some stupid maps like Blood Harvest finale and The Passing finale have CHECKPOINT inside a FINALE marked area.
		int spawnattr = L4D_GetNavArea_SpawnAttributes(area);
		if (~spawnattr & NAV_SPAWN_CHECKPOINT || spawnattr & NAV_SPAWN_FINALE)
			return;
		
		/**
		 * Game code looks like this:
		 *
		 * ```cpp
		 * 	CNavArea* area = GetLastKnownArea();
		 * 	if ( area && !area->IsOverlapping(GetAbsOrigin(), 100.0) )
		 *  	area = NULL;
		 * ```
		 *
		 * "area" will then be checked for in restricted area, except when it's NULL.
		 */
		
		float origin[3];
		GetClientAbsOrigin(client, origin);
		if (NavArea_IsOverlapping(area, origin)) // make sure it's the exact case
			return;
		
		static const float kflExtendedRange = 300.0; // adjustable, 300 units should be fair enough
		if ((area = L4D_GetNearestNavArea(origin, kflExtendedRange, false, true, true, 2)) != Address_Null)
		{
			spawnattr = L4D_GetNavArea_SpawnAttributes(area);
			if (spawnattr & NAV_SPAWN_CHECKPOINT && ~spawnattr & NAV_SPAWN_FINALE)
				L4D_SetPlayerGhostSpawnState(client, spawnstate | L4D_SPAWNFLAG_RESTRICTEDAREA);
		}
	}
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

bool IsClosedSaferoomSpawnAttempt(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	if (IsPositionInsideClosedCheckpoint(origin))
		return true;

	Address area = L4D_GetLastKnownArea(client);
	if (IsCheckpointArea(area) && IsNearClosedCheckpointDoor(origin))
		return true;

	area = L4D_GetNearestNavArea(origin, g_hCvarDoorRange.FloatValue, false, true, true, 2);
	return IsCheckpointArea(area) && IsNearClosedCheckpointDoor(origin);
}

bool IsPositionInsideClosedCheckpoint(float origin[3])
{
	int door = L4D_GetCheckpointFirst();
	if (IsClosedCheckpointDoor(door) && L4D_IsPositionInFirstCheckpoint(origin))
		return true;

	door = L4D_GetCheckpointLast();
	if (IsClosedCheckpointDoor(door) && L4D_IsPositionInLastCheckpoint(origin))
		return true;

	return false;
}

bool IsNearClosedCheckpointDoor(float origin[3])
{
	return IsNearDoor(origin, L4D_GetCheckpointFirst()) || IsNearDoor(origin, L4D_GetCheckpointLast());
}

bool IsNearDoor(float origin[3], int door)
{
	if (!IsClosedCheckpointDoor(door))
		return false;

	float doorOrigin[3];
	GetEntPropVector(door, Prop_Send, "m_vecOrigin", doorOrigin);
	return GetVectorDistance(origin, doorOrigin, false) <= g_hCvarDoorRange.FloatValue;
}

bool IsClosedCheckpointDoor(int door)
{
	if (door <= MaxClients || !IsValidEntity(door))
		return false;

	int state = GetEntProp(door, Prop_Data, "m_eDoorState");
	return state == DOOR_STATE_CLOSED || state == DOOR_STATE_CLOSING_IN_PROGRESS;
}

bool IsCheckpointArea(Address area)
{
	if (area == Address_Null)
		return false;

	int spawnattr = L4D_GetNavArea_SpawnAttributes(area);
	return (spawnattr & NAV_SPAWN_CHECKPOINT) && !(spawnattr & NAV_SPAWN_FINALE);
}

void BlockGhostSpawn(int client)
{
	int spawnstate = L4D_GetPlayerGhostSpawnState(client);
	L4D_SetPlayerGhostSpawnState(client, spawnstate | L4D_SPAWNFLAG_RESTRICTEDAREA);

	if (g_hCvarDebug.BoolValue)
		LogMessage("Blocked saferoom ghost spawn for %N.", client);
}

bool HasLastSurvivorLeftStartArea()
{
	return LoadFromAddress(gpTheDirector + view_as<Address>(g_iOffs_LastSurvivorLeftStartArea), NumberType_Int8);
}

bool NavArea_IsOverlapping(Address area, const float pos[3], float tolerance = 100.0)
{
	float center[3], size[3];
	L4D_GetNavAreaCenter(area, center);
	L4D_GetNavAreaSize(area, size);
	
	return ( pos[0] + tolerance >= center[0] - size[0] * 0.5 && pos[0] - tolerance <= center[0] + size[0] * 0.5
		&& pos[1] + tolerance >= center[1] - size[1] * 0.5 && pos[1] - tolerance <= center[1] + size[1] * 0.5 );
}