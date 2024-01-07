#include <sourcemod>
#include <sdktools>
#include <colors>

#define L4D2_TEAM_SURVIVOR 2

public Plugin myinfo = 
{
	name = "Show witch HP on respawn",
	author = "Altair Sossai",
	description = "Show witch HP on respawn",
	version = "1.0.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

Handle g_hCvarWitchHealth = INVALID_HANDLE;

public void OnPluginStart()
{
	g_hCvarWitchHealth = FindConVar("z_witch_health");

	HookEvent("witch_spawn", Event_WitchSpawn, EventHookMode_PostNoCopy);
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	float health = GetConVarFloat(g_hCvarWitchHealth);
	if (health == 1000.0)
		return;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != L4D2_TEAM_SURVIVOR)
			continue;
		
		CPrintToChat(client, "{red}Witch{default} has {red}%.0f{default} HP", health);
	}
}
