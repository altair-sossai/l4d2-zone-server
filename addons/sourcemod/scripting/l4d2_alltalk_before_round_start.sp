#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define FIRST_MAP_DELAY 10.0

ConVar g_AllTalk;

public Plugin myinfo =
{
	name		= "L4D2 - All Talk",
	author		= "Altair Sossai",
	description = "Enables all talk before the first round starts, then turns it off once the round goes live",
	version		= "1.1.0",
	url			= "https://github.com/altair-sossai/l4d2-server-manager-client"
};

public void OnPluginStart()
{
	LoadTranslations("l4d2_alltalk_before_round_start.phrases");

	g_AllTalk = FindConVar("sv_alltalk");
}

public void OnMapStart()
{
	CreateTimer(FIRST_MAP_DELAY, EnableOnFirstMap_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action EnableOnFirstMap_Timer(Handle timer)
{
	int teamAScore = L4D2Direct_GetVSCampaignScore(0);
	int teamBScore = L4D2Direct_GetVSCampaignScore(1);

	SetAllTalk(teamAScore == 0 && teamBScore == 0);

	return Plugin_Continue;
}

public void OnRoundIsLive()
{
	SetAllTalk(false);
}

void SetAllTalk(bool enabled)
{
	if (g_AllTalk == null || enabled == g_AllTalk.BoolValue)
		return;

	g_AllTalk.BoolValue = enabled;

	CPrintToChatAll("%t", enabled ? "AllTalkEnabled" : "AllTalkDisabled");
}
