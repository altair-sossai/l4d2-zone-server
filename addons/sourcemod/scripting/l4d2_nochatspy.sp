#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

ConVar g_hCvarEnable;

public Plugin myinfo =
{
	name = "L4D2 Chat-Spy Preventer",
	author = "Altair Sossai",
	description = "Don't broadcast the player_say event to clients, so 3rd party programs can't read the other team's team chat.",
	version = "1.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
	g_hCvarEnable = CreateConVar("l4d2_nochatspy_enable", "1", "Stop sending the player_say event to clients (1 = block, 0 = vanilla behaviour).", FCVAR_NONE, true, 0.0, true, 1.0);

	HookEvent("player_say", Event_PlayerSay, EventHookMode_Pre);
}

Action Event_PlayerSay(Event event, const char[] name, bool dontBroadcast)
{
	// The server fires player_say for both say and say_team, and by default it is sent to every client that asks for it, whatever their team.
	// The game itself never listens to this event on the client (chat is drawn from the SayText2 user message, which respects teams), only 3rd party programs do.
	// Server-side listeners (other plugins) still receive it, only the network broadcast is stopped.

	if (g_hCvarEnable.BoolValue)
	{
		event.BroadcastDisabled = true;
	}

	return Plugin_Continue;
}
