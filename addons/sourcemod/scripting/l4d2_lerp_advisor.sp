#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <lerpmonitor>
#include <readyup>
#include <colors>

#define LERP_COMMANDS "cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100"

ConVar g_cvEnabled,
       g_cvMinLerp,
       g_cvMaxLerp;

bool g_bLerpMonitorIsAvailable = false;
bool g_bReadyUpIsAvailable = false;

int g_iLastNotify[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "L4D2 - Lerp Advisor",
    author = "Altair Sossai",
    description = "Only warns players with an invalid lerp about the network commands they should run themselves (never changes any client setting)",
    version = "2.0.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_lerp_advisor.phrases");

    g_cvEnabled = CreateConVar("l4d2_lerp_advisor_enabled", "1", "Enable the lerp advisory message", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
}

public void OnConfigsExecuted()
{
    g_cvMinLerp = FindConVar("sm_min_lerp");
    g_cvMaxLerp = FindConVar("sm_max_lerp");
}

public void OnAllPluginsLoaded()
{
    g_bLerpMonitorIsAvailable = LibraryExists("lerpmonitor");
    g_bReadyUpIsAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "lerpmonitor"))
    {
        g_bLerpMonitorIsAvailable = true;
        g_cvMinLerp = FindConVar("sm_min_lerp");
        g_cvMaxLerp = FindConVar("sm_max_lerp");
    }

    if (StrEqual(name, "readyup"))
        g_bReadyUpIsAvailable = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "lerpmonitor"))
        g_bLerpMonitorIsAvailable = false;

    if (StrEqual(name, "readyup"))
        g_bReadyUpIsAvailable = false;
}

public void OnClientPutInServer(int client)
{
    g_iLastNotify[client] = 0;
}

public void OnClientPostAdminCheck(int client)
{
    if (!g_cvEnabled.BoolValue || !IsHumanClient(client))
        return;

    CreateTimer(5.0, CheckLerp_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    int team = event.GetInt("team");
    if (team != L4D_TEAM_SURVIVOR && team != L4D_TEAM_INFECTED)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsHumanClient(client))
        return;

    CreateTimer(1.0, CheckLerp_Timer, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

Action CheckLerp_Timer(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !g_cvEnabled.BoolValue || !IsHumanClient(client))
        return Plugin_Stop;

    if (!g_bLerpMonitorIsAvailable || g_cvMinLerp == null || g_cvMaxLerp == null)
        return Plugin_Stop;

    if (g_bReadyUpIsAvailable && !IsInReady())
        return Plugin_Stop;

    if (IsLerpValid(LM_GetCurrentLerpTime(client)))
        return Plugin_Stop;

    int now = GetTime();
    if (now - g_iLastNotify[client] < 3)
        return Plugin_Stop;

    g_iLastNotify[client] = now;

    SuggestCommands(client);

    return Plugin_Stop;
}

void SuggestCommands(int client)
{
    CPrintToChat(client, "{default}<{olive}Lerp{default}> %t", "LerpAdvisorInstruction");
    CPrintToChat(client, "%s", LERP_COMMANDS);

    PrintToConsole(client, "%s", LERP_COMMANDS);
}

bool IsLerpValid(float lerp)
{
    return lerp >= g_cvMinLerp.FloatValue && lerp <= g_cvMaxLerp.FloatValue;
}

bool IsHumanClient(int client)
{
    if (client <= 0 || client > MaxClients)
        return false;

    if (!IsClientInGame(client))
        return false;

    return !IsFakeClient(client);
}
