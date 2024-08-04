#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <readyup>
#include <pause>
#include <colors>

#define L4D2_TEAM_SPECTATOR 1
#define L4D2_TEAM_SURVIVOR 2
#define L4D2_TEAM_INFECTED 3

#define SURVIVOR_OR_INFECTED(%1) (IsClientInGame(%1) && !IsFakeClient(%1) && (GetClientTeam(%1) == L4D2_TEAM_SURVIVOR || GetClientTeam(%1) == L4D2_TEAM_INFECTED))

enum struct Player
{
    char steamId[64];
    char name[MAX_NAME_LENGTH];
    float deadline;
}

ConVar
    hBanDuration,
    hMaxAbandonmentBeforeNoPenalty,
    hReturnTimeLimitMinutes,
    hReadyStateAdditionalTimeMinutes,
    hMaxSimultaneousPunishments,
    hPenaltyTimeFrameSeconds;

public Plugin myinfo =
{
    name        = "L4D2 - Rage quit prevent",
    author      = "Altair Sossai",
    description = "Prevent rage quit in L4D2",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

bool 
    enabled = false,
    teamChanged = false,
    inTransition = false,
    inPause = false;

int rqs = 0;

float pauseStart;

ArrayList h_players;
ArrayList h_whiteList;

public void OnPluginStart()
{
    hBanDuration = CreateConVar("rq_ban_duration_days", "3", "Number of days a player is banned if they abandon a match", FCVAR_PROTECTED);
    hMaxAbandonmentBeforeNoPenalty = CreateConVar("rq_max_abandonment_before_no_penalty", "5", "Number of players that can abandon the match before penalties are disabled", FCVAR_PROTECTED);
    hReturnTimeLimitMinutes = CreateConVar("rq_return_time_limit_minutes", "5", "Time limit in minutes for a player to return to the game before being banned", FCVAR_PROTECTED);
    hReadyStateAdditionalTimeMinutes = CreateConVar("rq_ready_state_additional_time_minutes", "5", "Additional time in minutes added when the game is in the ready state", FCVAR_PROTECTED);
    hMaxSimultaneousPunishments = CreateConVar("rq_max_simultaneous_punishments", "3", "Maximum number of players that can be punished at the same time", FCVAR_PROTECTED);
    hPenaltyTimeFrameSeconds = CreateConVar("rq_penalty_time_frame_seconds", "15", "Time frame in seconds during which players will be penalized if they leave before disconnected players return", FCVAR_PROTECTED);

    h_players = new ArrayList(sizeof(Player));
    h_whiteList = new ArrayList(ByteCountToCells(64));

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
    HookEvent("player_disconnect", PlayerDisconnect_Event, EventHookMode_Pre);

    CreateTimer(2.5, CheckPunishmentsTick, _, TIMER_REPEAT);
}

public void OnRoundIsLive()
{
    TryEnablePunishments();
}

public void OnClientPutInServer(int client)
{
    teamChanged = true;
}

public void OnClientDisconnect(int client)
{
    teamChanged = true;
}

public void OnPause()
{
    inPause = true;
    pauseStart = GetEngineTime();
}

public void OnUnpause()
{
    float pausedTime = GetEngineTime() - pauseStart;

    Player player;
    for (int i = 0; i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline == 0.0)
            continue;

        player.deadline += pausedTime;

        h_players.SetArray(i, player);
    }

    inPause = false;
}

public void L4D2_OnEndVersusModeRound_Post()
{
	inTransition = true;
}

void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(10.0, RoundStartTick);
    CreateTimer(30.0, DisableInTransitionTick);
}

void PlayerTeam_Event(Event hEvent, const char[] name, bool dontBroadcast)
{
    teamChanged = true;
}

void PlayerDisconnect_Event(Event hEvent, char[] sEventName, bool dontBroadcast)
{
    teamChanged = true;

    PreventPunishDeadSurvivorsOnLastRound(GetClientOfUserId(hEvent.GetInt("userid")));
}

Action CheckPunishmentsTick(Handle timer)
{
    if (!enabled || inTransition || inPause)
        return Plugin_Continue;

    if (teamChanged)
    {
        ClearCounterOfWhoReturned();
        StartCounterForWhoLeft();

        teamChanged = false;
        rqs = NumberOfPlayersWhoLeft();

        return Plugin_Continue;
    }

    if (rqs == 0)
        return Plugin_Continue;

    if (rqs >= hMaxAbandonmentBeforeNoPenalty.IntValue)
    {
        DisablePunishments();
        return Plugin_Continue;
    }

    BanPlayersWhoTimeout();

    return Plugin_Continue;
}

Action RoundStartTick(Handle timer)
{
    if (IsNewGame() || L4D_GetCurrentChapter() >= 5)
        DisablePunishments();

    return Plugin_Stop;
}

Action DisableInTransitionTick(Handle timer)
{
    inTransition = false;

    return Plugin_Stop;
}

void TryEnablePunishments()
{
    if (enabled || !IsNewGame())
        return;

    int playersRequired = GetConVarInt(FindConVar("survivor_limit")) * 2;

    if (NumberOfPlayers() != playersRequired)
        return;

    h_players.Clear();
    h_whiteList.Clear();

    char steamId[64];
    char name[MAX_NAME_LENGTH];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!SURVIVOR_OR_INFECTED(client))
            continue;

        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        GetClientName(client, name, sizeof(name));

        Player player;

        strcopy(player.steamId, sizeof(player.steamId), steamId);
        strcopy(player.name, sizeof(player.name), name);

        player.deadline = 0.0;

        h_players.PushArray(player);
    }

    if(h_players.Length != playersRequired)
        return;

    enabled = true;
    teamChanged = true;
    inTransition = false;

    CPrintToChatAll("{red}Rage quit {default}results in {red}%d day(s) {default}of ban", hBanDuration.IntValue);
}

void DisablePunishments()
{
    if (!enabled)
        return;

    enabled = false;
    h_players.Clear();
    h_whiteList.Clear();

    CPrintToChatAll("{default}Rage quit punishment has been {red}disabled");
}

void ClearCounterOfWhoReturned()
{
    Player player;
    char steamId[64];

    for (int i = 0; i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline == 0.0)
            continue;

        for (int client = 1; client <= MaxClients; client++)
        {
            if (!SURVIVOR_OR_INFECTED(client))
                continue;

            GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
            if (!StrEqual(player.steamId, steamId))
                continue;

            player.deadline = 0.0;
            h_players.SetArray(i, player);

            break;
        }
    }
}

void StartCounterForWhoLeft()
{
    bool found;
    Player player;
    char steamId[64];

    for (int i = 0; i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline != 0.0)
            continue;

        found = false;

        for (int client = 1; !found && client <= MaxClients; client++)
        {
            if (!SURVIVOR_OR_INFECTED(client))
                continue;

            GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
            
            found = StrEqual(player.steamId, steamId);
        }

        if (found)
            continue;

        int minutes = hReturnTimeLimitMinutes.IntValue;

        if (IsInReady())
            minutes += hReadyStateAdditionalTimeMinutes.IntValue;

        player.deadline = GetEngineTime() + minutes * 60.0;
        h_players.SetArray(i, player);

        CPrintToChatAll("{green}%s {default}left the game. Return in {red}%d mins {default}or receive a {red}%d day(s){default} of ban.", player.name, minutes, hBanDuration.IntValue);
        CPrintToChatAll("Use {green}!pause {default} to wait for his return.");
    }
}

void BanPlayersWhoTimeout()
{
    if (!AnyPlayerTimedOut())
        return;

    h_players.SortCustom(SortByDeadline);

    bool someonePunished = false;
    int maxSimultaneousPunishments = hMaxSimultaneousPunishments.IntValue;
    float limit = GetEngineTime() - hPenaltyTimeFrameSeconds.FloatValue;

    Player player;
    for (int i = 0, punished = 0; punished <= maxSimultaneousPunishments && i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline == 0.0)
            continue;

        if (player.deadline >= limit)
            break;

        if (h_whiteList.FindString(player.steamId) != -1)
            continue;

        ServerCommand("sm_addban %d %s Banned for leaving the game", hBanDuration.IntValue * 1440, player.steamId);
        KickPlayer(player.steamId);

        CPrintToChatAll("{green}%s {default}is banned for {red}%d day(s) {default}for rage quit", player.name, hBanDuration.IntValue);

        someonePunished = true;
        punished++;
    }

    if (someonePunished)
        DisablePunishments();
}

int SortByDeadline(int index1, int index2, Handle array, Handle hndl)
{
    Player player1, player2;

    h_players.GetArray(index1, player1);
    h_players.GetArray(index2, player2);

    if (player1.deadline < player2.deadline)
        return -1;

    if (player1.deadline > player2.deadline)
        return 1;

    return 0;
}

void KickPlayer(const char[] steamId)
{
    char temp[64];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;

        GetClientAuthId(client, AuthId_Steam2, temp, sizeof(temp));
        if (!StrEqual(steamId, temp))
            continue;

        KickClient(client, "Banned for leaving the game. Duration: %d days.", hBanDuration.IntValue);

        return;
    }
}

bool AnyPlayerTimedOut()
{
    Player player;
    float now = GetEngineTime();

    for (int i = 0; i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline != 0.0 && now > player.deadline)
            return true;
    }

    return false;
}

void PreventPunishDeadSurvivorsOnLastRound(int client)
{
    if (client <= 0 || client > MaxClients)
        return;

    if (L4D_GetCurrentChapter() >= 4 && InSecondHalfOfRound() && GetClientTeam(client) == L4D_TEAM_SURVIVOR && !IsPlayerAlive(client))
    {
        char steamId[64];
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

        h_whiteList.PushString(steamId);
    }
}

int NumberOfPlayersWhoLeft()
{
    int count = 0;

    Player player;
    for (int i = 0; i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline != 0.0)
            count++;
    }

    return count;
}

int NumberOfPlayers()
{
    int count = 0;

    for (int client = 1; client <= MaxClients; client++)
        if (SURVIVOR_OR_INFECTED(client))
            count++;

    return count;
}

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0 && L4D2Direct_GetVSCampaignScore(1) == 0;
}

bool InSecondHalfOfRound()
{
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}