#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <readyup>
#include <colors>

ConVar g_cvNewGameTimeout;
ConVar g_cvOngoingGameTimeout;
ConVar g_cvSurvivorLimit;
ConVar g_cvInfectedLimit;

float g_fLastActivity[MAXPLAYERS + 1];
int g_iLastMouse[MAXPLAYERS + 1][2];
bool g_bShouldCheckAfk;

public Plugin myinfo =
{
    name = "L4D2 - AFK to Spectator",
    author = "Altair Sossai",
    description = "Moves AFK players to spectators during ready-up when another player is waiting",
    version = "1.0.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_afk_to_spec.phrases");

    g_cvNewGameTimeout = CreateConVar(
        "l4d2_afk_to_spec_new_game_timeout",
        "180",
        "Seconds a player may remain AFK during ready-up when the score is 0-0",
        FCVAR_NOTIFY,
        true,
        1.0
    );

    g_cvOngoingGameTimeout = CreateConVar(
        "l4d2_afk_to_spec_ongoing_game_timeout",
        "360",
        "Seconds a player may remain AFK during ready-up after the game has started",
        FCVAR_NOTIFY,
        true,
        1.0
    );

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_cvInfectedLimit = FindConVar("z_max_player_zombies");

    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);

    CreateTimer(10.0, CheckAfk_Timer, _, TIMER_REPEAT);

    g_bShouldCheckAfk = IsInReady();

    float now = GetEngineTime();

    for (int client = 1; client <= MaxClients; client++)
        g_fLastActivity[client] = now;
}

public void OnClientPutInServer(int client)
{
    ResetActivity(client);
}

public void OnReadyUpInitiate()
{
    g_bShouldCheckAfk = true;

    float now = GetEngineTime();

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsHumanClient(client))
            g_fLastActivity[client] = now;
    }
}

public void OnRoundIsLive()
{
    g_bShouldCheckAfk = false;
}

public void OnMapEnd()
{
    g_bShouldCheckAfk = false;
}

public void OnClientDisconnect(int client)
{
    g_fLastActivity[client] = 0.0;
    g_iLastMouse[client][0] = 0;
    g_iLastMouse[client][1] = 0;
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bShouldCheckAfk)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsHumanClient(client))
        ResetActivity(client);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
    if (!g_bShouldCheckAfk || !IsHumanClient(client))
        return;

    if (mouse[0] != g_iLastMouse[client][0] || mouse[1] != g_iLastMouse[client][1])
    {
        g_iLastMouse[client][0] = mouse[0];
        g_iLastMouse[client][1] = mouse[1];
        ResetActivity(client);
    }
    else if (buttons || impulse)
    {
        ResetActivity(client);
    }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args)
{
    if (g_bShouldCheckAfk && IsHumanClient(client))
        ResetActivity(client);

    return Plugin_Continue;
}

Action CheckAfk_Timer(Handle timer)
{
    if (!g_bShouldCheckAfk || !TeamsAreFull() || !HasWaitingSpectator())
        return Plugin_Continue;

    float timeout = IsNewGame()
        ? g_cvNewGameTimeout.FloatValue
        : g_cvOngoingGameTimeout.FloatValue;

    MoveAfkPlayersToSpectator(timeout);

    return Plugin_Continue;
}

void MoveAfkPlayersToSpectator(float timeout)
{
    float now = GetEngineTime();

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsHumanClient(client) || !IsPlaying(client))
            continue;

        float afkTime = now - g_fLastActivity[client];
        if (afkTime < timeout)
            continue;

        int afkSeconds = RoundToFloor(afkTime);

        ChangeClientTeam(client, L4D_TEAM_SPECTATOR);
        CPrintToChatAll("{orange}[%t] {default}%t", "AfkToSpec", "MovedToSpectator", client, afkSeconds);
    }
}

bool TeamsAreFull()
{
    if (g_cvSurvivorLimit == null || g_cvInfectedLimit == null)
        return false;

    return CountHumanPlayers(L4D_TEAM_SURVIVOR) >= g_cvSurvivorLimit.IntValue
        && CountHumanPlayers(L4D_TEAM_INFECTED) >= g_cvInfectedLimit.IntValue;
}

bool HasWaitingSpectator()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsHumanClient(client) && GetClientTeam(client) == L4D_TEAM_SPECTATOR)
            return true;
    }

    return false;
}

int CountHumanPlayers(int team)
{
    int count = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsHumanClient(client) && GetClientTeam(client) == team)
            count++;
    }

    return count;
}

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0
        && L4D2Direct_GetVSCampaignScore(1) == 0;
}

bool IsPlaying(int client)
{
    int team = GetClientTeam(client);
    return team == L4D_TEAM_SURVIVOR || team == L4D_TEAM_INFECTED;
}

bool IsHumanClient(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && !IsFakeClient(client);
}

void ResetActivity(int client)
{
    g_fLastActivity[client] = GetEngineTime();
}
