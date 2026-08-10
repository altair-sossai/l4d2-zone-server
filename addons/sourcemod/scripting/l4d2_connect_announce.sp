#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>

#define EARLY_GRACE_PERIOD 25.0

bool g_bEarly;

public Plugin myinfo =
{
	name		= "L4D2 - Connect Announce",
	author		= "pa4H",
	description = "Announces in chat when a player connects, ignoring the initial rush right after the map loads",
	version		= "1.0.0",
	url			= "vk.com/pa4h1337"
};

public void OnPluginStart()
{
	LoadTranslations("l4d2_connect_announce.phrases");

	g_bEarly = true;
}

public void OnMapStart()
{
	g_bEarly = true;
	CreateTimer(EARLY_GRACE_PERIOD, EndEarlyGrace_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action EndEarlyGrace_Timer(Handle timer)
{
	g_bEarly = false;
	return Plugin_Stop;
}

public void OnClientAuthorized(int client)
{
	if (g_bEarly || IsFakeClient(client))
		return;

	CPrintToChatAll("%t", "PlayerLoading", client);
}
