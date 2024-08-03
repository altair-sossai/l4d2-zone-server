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

#define HUMAN_CLIENT(%1) (IsClientInGame(%1) && !IsFakeClient(%1))
#define SURVIVOR_OR_INFECTED(%1) (HUMAN_CLIENT(%1) && (GetClientTeam(%1) == L4D2_TEAM_SURVIVOR || GetClientTeam(%1) == L4D2_TEAM_INFECTED))

enum struct Player
{
    char steamId[64];
    char name[MAX_NAME_LENGTH];
    float deadline;
}

ConVar
    hDaysBanned,
    hMaxRageQuit,
    hLimitUntilBanInMinutes,
    hMaxPlayersPunished,
    hPunishmentGapInSeconds;

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
    skip = false,
    inPause = false;

int rqs = 0;

float pauseStart;

ArrayList h_players;
ArrayList h_whiteList;

public void OnPluginStart()
{
    hDaysBanned = CreateConVar("rq_days_banned", "3", "Number of days banned if player abandons match", FCVAR_PROTECTED);
    hMaxRageQuit = CreateConVar("rq_max_ragequit", "5", "Number of players that can abandon the match before the punishments are disabled", FCVAR_PROTECTED);
    hLimitUntilBanInMinutes = CreateConVar("rq_limit_until_ban_in_minutes", "5", "Time limit in minutes for the player to return to the game", FCVAR_PROTECTED);
    hMaxPlayersPunished = CreateConVar("rq_max_players_punished", "3", "Number of players that can be punished at the same time", FCVAR_PROTECTED);
    hPunishmentGapInSeconds = CreateConVar("rq_punishment_gap_in_seconds", "15", "Time frame during which players will be penalized if they do not wait for the return of players who have disconnected from the server", FCVAR_PROTECTED);

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
    HookEvent("player_disconnect", PlayerDisconnect_Event, EventHookMode_Pre);

    h_players = new ArrayList();
    h_whiteList = new ArrayList();

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
    inPause = false;

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
}

public void L4D2_OnEndVersusModeRound_Post()
{
	skip = true;
}

void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(10.0, RoundStartTick);
}

void PlayerTeam_Event(Event hEvent, const char[] name, bool dontBroadcast)
{
    teamChanged = true;
}

void PlayerDisconnect_Event(Event hEvent, char[] sEventName, bool dontBroadcast)
{
    teamChanged = true;

    PreventPunishDeadSurvivorsLastRoundLastChapter(GetClientOfUserId(hEvent.GetInt("userid")));
}

Action RoundStartTick(Handle timer)
{
    skip = false;

    if (IsNewGame() || L4D_GetCurrentChapter() >= 5)
        DisablePunishments();

    return Plugin_Stop;
}

Action CheckPunishmentsTick(Handle timer)
{
    if (!enabled || skip || inPause)
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

    if (rqs >= hMaxRageQuit.IntValue)
    {
        DisablePunishments();
        return Plugin_Continue;
    }

    BanPlayersWhoTimeout();

    return Plugin_Continue;
}

void TryEnablePunishments()
{
    if (enabled || GameInProgress())
        return;

    int playersRequired = TeamSize() * 2;

    if (NumberOfPlayers() != playersRequired)
        return;

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
    skip = false;

    CPrintToChatAll("{default}This is a competitive match. {red}Ragequit {default}is not allowed. Punishment: {red}%d{default} day(s) ban!", hDaysBanned.IntValue);
}

void DisablePunishments()
{
    if (!enabled)
        return;

    enabled = false;
    h_players.Clear();
    h_whiteList.Clear();

    CPrintToChatAll("Punishments disabled.");
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

            CPrintToChatAll("{red}%s {default}returned to the game. Punishment canceled.", player.name);

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
            if (!IsClientInGame(client) || IsFakeClient(client))
                continue;

            GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
            
            found = StrEqual(player.steamId, steamId);
        }

        if (found)
            continue;

        player.deadline = GetEngineTime() + hLimitUntilBanInMinutes.FloatValue * 60.0;
        h_players.SetArray(i, player);

        CPrintToChatAll("{red}%s {default}has left the game. He has {red}%d {default}minutes to return, or he will receive {red}%d {default}day(s) ban.", player.name, hLimitUntilBanInMinutes.IntValue, hDaysBanned.IntValue);
        CPrintToChatAll("Use {green}!pause {default} to wait for his return.");
    }
}

void BanPlayersWhoTimeout()
{
    if (!AnyPlayerTimedOut())
        return;

    h_players.SortCustom(SortByDeadline);

    bool someonePunished = false;
    float limit = GetEngineTime() - hPunishmentGapInSeconds.FloatValue;

    Player player;
    for (int i = 0, punished = 0; punished <= hMaxPlayersPunished.IntValue && i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline == 0.0 || player.deadline > limit)
            break;

        if (h_whiteList.FindString(player.steamId) != -1)
            continue;

        CPrintToChatAll("{red}%s {default}has been banned for {red}%d {default}day(s) for abandoning the game.", player.name, hDaysBanned.IntValue);
        ServerCommand("sm_ban %s %d Automatic ban for abandoning the game", player.steamId, hDaysBanned.IntValue * 1440);

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

bool AnyPlayerTimedOut()
{
    Player player;
    float now = GetEngineTime();

    for (int i = 0; i < h_players.Length; i++)
    {
        h_players.GetArray(i, player);

        if (player.deadline != 0.0 && now >= player.deadline)
            return true;
    }

    return false;
}

void PreventPunishDeadSurvivorsLastRoundLastChapter(int client)
{
    if (client <= 0 || client > MaxClients)
        return;

    if (L4D_GetCurrentChapter() < 4 
    || GameRules_GetProp("m_bAreTeamsFlipped") == 0
    || GetClientTeam(client) != L4D_TEAM_SURVIVOR
    || IsPlayerAlive(client))
        return;

    char steamId[64];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

    h_whiteList.PushString(steamId);
}

bool GameInProgress()
{
    return !IsNewGame();
}

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0 && L4D2Direct_GetVSCampaignScore(1) == 0;
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

int TeamSize()
{
	return GetConVarInt(FindConVar("survivor_limit"));
}