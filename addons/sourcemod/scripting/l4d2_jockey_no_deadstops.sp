#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define Z_JOCKEY 5
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

public Plugin myinfo = 
{
	name = "[L4D2] No Jockey Deadstops",
	author = "Altair",
	description = "Prevents deadstops but allows m2s on standing jockeys",
	version = "1.0.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnRoundIsLive()
{
    PrintToChatAll("Jockey Deadstops disabled — M2 does not stop Jockeys (like Hunters)");
    PrintToChatAll("Jockey Deadstops disabled — M2 does not stop Jockeys (like Hunters)");
    PrintToChatAll("Jockey Deadstops disabled — M2 does not stop Jockeys (like Hunters)");
}

public Action L4D_OnShovedBySurvivor(int shover, int shovee, const float vecDir[3])
{
    return Shove_Handler(shover, shovee);
}

public Action L4D2_OnEntityShoved(int shover, int shovee, int weapon, float vecDir[3], bool bIsHighPounce)
{
    return Shove_Handler(shover, shovee);
}

Action Shove_Handler(int shover, int shovee)
{
    if (!IsClientInGame(shover) || !IsClientInGame(shovee))
        return Plugin_Continue;

    if (!IsJockey(shovee))
        return Plugin_Continue;

	if (HasTarget(shovee))
		return Plugin_Continue;

    if (!IsAttachable(shovee))
        return Plugin_Continue;

    return Plugin_Handled;
}

bool HasTarget(int jockey)
{
	int target = GetEntPropEnt(jockey, Prop_Send, "m_jockeyVictim");

	return (target > 0 && target <= MaxClients && IsSurvivor(target) && IsPlayerAlive(target));
}

bool IsJockey(int client)
{
    return (client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && GetClientTeam(client) == TEAM_INFECTED
        && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_JOCKEY
        && !GetEntProp(client, Prop_Send, "m_isGhost", 1));
}

bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR);
}

bool IsAttachable(int jockey)
{
    return (!(GetEntityFlags(jockey) & FL_ONGROUND));
}