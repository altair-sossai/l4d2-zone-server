#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VOICE_LISTENALL 4
#define VOICE_TEAM 8

#define TEAM_SPEC 1

public Plugin myinfo = 
{
	name = "SpecLister",
	author = "Altair Sossai",
	description = "Allow spectators to hear all players",
	version = "1.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
}

public void OnPluginStart()
{
	HookEvent("player_team", PlayerTeam_Event);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return;

	int team = GetEventInt(event, "team");
	
	SetClientListeningFlags(client, team == TEAM_SPEC ? VOICE_LISTENALL : VOICE_TEAM);
}