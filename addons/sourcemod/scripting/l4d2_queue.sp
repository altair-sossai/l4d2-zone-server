#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <readyup>
#include <colors>

ConVar g_cvDisconnectTimeout;

ArrayList g_aQueue;
ArrayList g_aTeamA;
ArrayList g_aTeamB;

int g_iWinningTeam = -1;

bool g_bFixingTeams = false;
bool g_bReorganizedThisGame = false;

enum struct Player
{
    char steamId[64];
    int expiresAt;
}

public Plugin myinfo =
{
    name = "L4D2 - Queue",
    author = "Altair Sossai",
    description = "Arranges players in a queue, showing who are the next players who should play",
    version = "2.0.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_queue.phrases");

    g_cvDisconnectTimeout = CreateConVar("l4d2_queue_disconnect_timeout", "300", "How many seconds a disconnected player stays in the queue before being removed", FCVAR_NOTIFY, true, 0.0);

    g_aQueue = new ArrayList(sizeof(Player));
    g_aTeamA = new ArrayList(ByteCountToCells(64));
    g_aTeamB = new ArrayList(ByteCountToCells(64));

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event);

    RegConsoleCmd("sm_fila", PrintQueueCmd, "Print the queue");
    RegConsoleCmd("sm_queue", PrintQueueCmd, "Print the queue");

    CreateTimer(2.0, WinningTeam_Timer, _, TIMER_REPEAT);
}

public void OnMixStarted()
{
    g_bFixingTeams = false;
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    g_bFixingTeams = false;

    if (L4D_HasMapStarted() && IsNewGame() && !g_bReorganizedThisGame)
    {
        ReorganizeQueue();
        g_bReorganizedThisGame = true;
    }

    CreateTimer(3.0, EnableFixTeam_Timer);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bFixingTeams || !IsNewGame())
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || IsFakeClient(client))
        return;

    CreateTimer(1.0, FixTeam_Timer);
}

Action WinningTeam_Timer(Handle timer)
{
    if (!L4D_HasMapStarted() || IsNewGame())
        return Plugin_Continue;

    g_bReorganizedThisGame = false;
    g_iWinningTeam = GetWinningTeam();

    return Plugin_Continue;
}

Action EnableFixTeam_Timer(Handle timer)
{
    if (!IsNewGame())
        return Plugin_Continue;

    g_bFixingTeams = true;
    FixTeams();
    CreateTimer(30.0, DisableFixTeam_Timer);

    return Plugin_Continue;
}

Action DisableFixTeam_Timer(Handle timer)
{
    g_bFixingTeams = false;

    return Plugin_Continue;
}

Action FixTeam_Timer(Handle timer)
{
    FixTeams();

    return Plugin_Continue;
}

public Action PrintQueueCmd(int client, int args)
{
    if (!IsValidClient(client) || IsFakeClient(client))
        return Plugin_Handled;

    PrintQueue(client);

    return Plugin_Handled;
}

public void OnRoundIsLive()
{
    g_bFixingTeams = false;

    if (IsNewGame())
        SnapshotTeams();
}

public void OnClientPostAdminCheck(int client)
{
    Enqueue(client);
}

public void OnClientDisconnect(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
        return;

    char steamId[64];
    if (!GetSteamId(client, steamId, sizeof(steamId)))
        return;

    int index = FindInQueue(steamId);
    if (index == -1)
        return;

    Player player;
    g_aQueue.GetArray(index, player);

    player.expiresAt = GetTime() + g_cvDisconnectTimeout.IntValue;
    g_aQueue.SetArray(index, player);
}

void Enqueue(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
        return;

    char steamId[64];
    if (!GetSteamId(client, steamId, sizeof(steamId)))
        return;

    RemoveExpiredPlayers();

    Player player;

    int index = FindInQueue(steamId);
    if (index != -1)
    {
        g_aQueue.GetArray(index, player);
        player.expiresAt = 0;
        g_aQueue.SetArray(index, player);
        return;
    }

    strcopy(player.steamId, sizeof(player.steamId), steamId);
    player.expiresAt = 0;

    g_aQueue.PushArray(player);
}

int ExpiresAtFor(const char[] steamId)
{
    if (GetClientUsingSteamId(steamId) != -1)
        return 0;

    return GetTime() + g_cvDisconnectTimeout.IntValue;
}

void RemoveExpiredPlayers()
{
    int now = GetTime();
    Player player;

    for (int i = 0; i < g_aQueue.Length; )
    {
        g_aQueue.GetArray(i, player);

        if (player.expiresAt != 0 && now >= player.expiresAt)
            g_aQueue.Erase(i);
        else
            i++;
    }
}

void SnapshotTeams()
{
    g_aTeamA.Clear();
    g_aTeamB.Clear();

    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    int teamA = flipped ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVOR;
    int teamB = flipped ? L4D_TEAM_SURVIVOR : L4D_TEAM_INFECTED;

    char steamId[64];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client) || IsFakeClient(client))
            continue;

        if (!GetSteamId(client, steamId, sizeof(steamId)))
            continue;

        int team = GetClientTeam(client);

        if (team == teamA)
            g_aTeamA.PushString(steamId);
        else if (team == teamB)
            g_aTeamB.PushString(steamId);
    }
}

void ReorganizeQueue()
{
    RemoveExpiredPlayers();

    if (g_aTeamA.Length == 0 && g_aTeamB.Length == 0)
        return;

    ArrayList winners = (g_iWinningTeam == 1) ? g_aTeamB : g_aTeamA;
    ArrayList losers = (g_iWinningTeam == 1) ? g_aTeamA : g_aTeamB;

    char steamId[64];
    Player player;

    // Remove winners and losers from the queue.
    for (int i = 0; i < g_aQueue.Length; )
    {
        g_aQueue.GetArray(i, player);

        if (winners.FindString(player.steamId) != -1)
        {
            g_aQueue.Erase(i);
            continue;
        }

        if (losers.FindString(player.steamId) != -1)
        {
            g_aQueue.Erase(i);
            continue;
        }

        i++;
    }

    // Add winners to the front of the queue.
    for (int i = 0; i < winners.Length; i++)
    {
        winners.GetString(i, steamId, sizeof(steamId));

        strcopy(player.steamId, sizeof(player.steamId), steamId);
        player.expiresAt = ExpiresAtFor(steamId);

        if (g_aQueue.Length == 0)
        {
            g_aQueue.PushArray(player);
        }
        else
        {
            g_aQueue.ShiftUp(0);
            g_aQueue.SetArray(0, player);
        }
    }

    // Add losers to the end of the queue.
    for (int i = 0; i < losers.Length; i++)
    {
        losers.GetString(i, steamId, sizeof(steamId));

        strcopy(player.steamId, sizeof(player.steamId), steamId);
        player.expiresAt = ExpiresAtFor(steamId);

        g_aQueue.PushArray(player);
    }

    g_aTeamA.Clear();
    g_aTeamB.Clear();
}

int FindInQueue(const char[] steamId)
{
    Player player;

    for (int i = 0; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);

        if (StrEqual(player.steamId, steamId))
            return i;
    }

    return -1;
}

bool IsStarter(const char[] steamId)
{
    return g_aTeamA.FindString(steamId) != -1 || g_aTeamB.FindString(steamId) != -1;
}

int GetClientUsingSteamId(const char[] steamId)
{
    char current[64];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client) || IsFakeClient(client))
            continue;

        if (!GetSteamId(client, current, sizeof(current)))
            continue;

        if (StrEqual(steamId, current))
            return client;
    }

    return -1;
}

void PrintQueue(int target)
{
    RemoveExpiredPlayers();

    if (g_aQueue.Length == 0 || g_aQueue.Length <= Slots())
        return;

    Player player;
    char output[MAX_MESSAGE_LENGTH];
    bool firstMessage = true;

    for (int i = 0, position = 1; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);

        if (IsStarter(player.steamId))
            continue;

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        char color[16] = "{default}";

        switch (GetClientTeam(client))
        {
            case L4D_TEAM_INFECTED:
                color = "{red}";
            case L4D_TEAM_SURVIVOR:
                color = "{blue}";
        }

        char entry[128];
        Format(entry, sizeof(entry), "{olive}%dº %s%N", position, color, client);

        // If the next name no longer fits, flush the current message and start a new one.
        if (strlen(output) != 0 && strlen(output) + 1 + strlen(entry) >= MAX_MESSAGE_LENGTH)
        {
            if (firstMessage)
            {
                if (target == 0)
                    CPrintToChatAll("{orange}%t {default}%s", "Queue", output);
                else
                    CPrintToChat(target, "{orange}%t {default}%s", "Queue", output);
            }
            else if (target == 0)
                CPrintToChatAll("%s", output);
            else
                CPrintToChat(target, "%s", output);

            output = "";
            firstMessage = false;
        }

        if (strlen(output) == 0)
            strcopy(output, sizeof(output), entry);
        else
            Format(output, sizeof(output), "%s %s", output, entry);

        position++;
    }

    if (strlen(output) == 0)
        return;

    if (firstMessage)
    {
        if (target == 0)
            CPrintToChatAll("{orange}%t {default}%s", "Queue", output);
        else
            CPrintToChat(target, "{orange}%t {default}%s", "Queue", output);
    }
    else if (target == 0)
        CPrintToChatAll("%s", output);
    else
        CPrintToChat(target, "%s", output);
}

void FixTeams()
{
    RemoveExpiredPlayers();

    if (!MustFixTheTeams())
        return;

    g_bFixingTeams = false;

    int slots = Slots();
    int[] nextPlayers = new int[slots];

    for (int np = 0; np < slots; np++)
        nextPlayers[np] = -1;

    Player player;

    for (int i = 0, np = 0; i < g_aQueue.Length && np < slots; i++)
    {
        g_aQueue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        nextPlayers[np++] = client;
    }

    bool found = false;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client))
            continue;

        if (IsFakeClient(client) || GetClientTeam(client) == L4D_TEAM_SPECTATOR)
            continue;

        found = false;

        for (int np = 0; !found && np < slots; np++)
            found = nextPlayers[np] == client;

        if (!found)
            MovePlayerToTeam(client, L4D_TEAM_SPECTATOR);
    }

    int teamSize = TeamSize();

    for (int np = 0; np < slots; np++)
    {
        int client = nextPlayers[np];

        if (client == -1 || GetClientTeam(client) != L4D_TEAM_SPECTATOR)
            continue;

        for (int team = L4D_TEAM_SURVIVOR; team <= L4D_TEAM_INFECTED; team++)
        {
            if (NumberOfPlayersInTheTeam(team) < teamSize)
            {
                MovePlayerToTeam(client, team);
                break;
            }
        }
    }

    g_bFixingTeams = true;
}

bool MustFixTheTeams()
{
    if (!g_bFixingTeams)
        return false;

    int availableSlots = Slots();

    if (g_aQueue.Length <= availableSlots)
        return false;

    Player player;

    for (int i = 0; i < g_aQueue.Length && availableSlots > 0; i++)
    {
        g_aQueue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        if (GetClientTeam(client) == L4D_TEAM_SPECTATOR)
            return true;

        availableSlots--;
    }

    return false;
}

void MovePlayerToTeam(int client, int team)
{
    if (team != L4D_TEAM_SPECTATOR && NumberOfPlayersInTheTeam(team) >= TeamSize())
        return;

    switch (team)
    {
        case L4D_TEAM_SPECTATOR:
            ChangeClientTeam(client, L4D_TEAM_SPECTATOR);

        case L4D_TEAM_SURVIVOR:
            FakeClientCommand(client, "jointeam 2");

        case L4D_TEAM_INFECTED:
            ChangeClientTeam(client, L4D_TEAM_INFECTED);
    }
}

int NumberOfPlayersInTheTeam(int team)
{
    int count = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client) || IsFakeClient(client) || GetClientTeam(client) != team)
            continue;

        count++;
    }

    return count;
}

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0
        && L4D2Direct_GetVSCampaignScore(1) == 0;
}

int GetWinningTeam()
{
    int mapScoreA = L4D_GetTeamScore(1);
    int mapScoreB = L4D_GetTeamScore(2);

    if (mapScoreA < 0)
        mapScoreA = 0;

    if (mapScoreB < 0)
        mapScoreB = 0;

    int teamAScore = L4D2Direct_GetVSCampaignScore(0) + mapScoreA;
    int teamBScore = L4D2Direct_GetVSCampaignScore(1) + mapScoreB;

    return teamAScore >= teamBScore ? 0 : 1;
}

bool GetSteamId(int client, char[] buffer, int maxlength)
{
    if (!GetClientAuthId(client, AuthId_Steam2, buffer, maxlength))
        return false;

    return strlen(buffer) != 0 && !StrEqual(buffer, "BOT");
}

int Slots()
{
    return TeamSize() * 2;
}

int TeamSize()
{
    return GetConVarInt(FindConVar("survivor_limit"));
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients)
        return false;

    return IsClientInGame(client);
}
