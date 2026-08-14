#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <readyup>
#include <colors>

#define MAX_QUEUE_MESSAGE_LENGTH 140

#define QUEUE_FILE "data/l4d2_queue.txt"
#define QUEUE_MAX_AGE (30 * 60)

#define SLOT_TAG "{orange}[%t] {default}%t", "Slot"
#define QUEUE_TAG "{orange}%t {default}%s", "Queue"

ConVar g_cvDisconnectTimeout;
ConVar g_cvEndMapDelay;

ArrayList g_aQueue;
ArrayList g_aTeamA;
ArrayList g_aTeamB;

int g_iWinningTeam = -1;

bool g_bFixingTeams = false,
     g_bQueueShown = false,
     g_bMixInProgress = false,
     g_bRoundOver = false;

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
    g_cvEndMapDelay = CreateConVar("l4d2_queue_endmap_delay", "8.0", "How many seconds after the map's second round ends before showing the queue to everyone (waits for the MVP/stats to be shown first)", FCVAR_NOTIFY, true, 0.0);

    g_aQueue = new ArrayList(sizeof(Player));
    g_aTeamA = new ArrayList(ByteCountToCells(64));
    g_aTeamB = new ArrayList(ByteCountToCells(64));

    LoadQueue();

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);

    RegConsoleCmd("sm_fila", PrintQueueCmd, "Print the queue");
    RegConsoleCmd("sm_queue", PrintQueueCmd, "Print the queue");

    RegConsoleCmd("sm_vaga", RequestSlotCmd, "Request a slot in the game");
    RegConsoleCmd("sm_slot", RequestSlotCmd, "Request a slot in the game");

    CreateTimer(3.0, WinningTeam_Timer, _, TIMER_REPEAT);
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    g_bFixingTeams = false;
    g_bQueueShown = false;
    g_bMixInProgress = false;
    g_bRoundOver = false;

    CreateTimer(2.5, EnableFixTeam_Timer);
    CreateTimer(30.0, SuggestSlotCommand_Timer);
}

public void L4D2_OnEndVersusModeRound_Post()
{
    g_bRoundOver = true;

    if (!GameRules_GetProp("m_bInSecondHalfOfRound"))
        return;

    if (g_bQueueShown)
        return;

    g_bQueueShown = true;

    SaveQueue();

    CreateTimer(g_cvEndMapDelay.FloatValue, ShowQueueEndMap_Timer);
}

Action ShowQueueEndMap_Timer(Handle timer)
{
    PrintQueue(0);

    return Plugin_Stop;
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bFixingTeams || !IsNewGame())
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsHumanClient(client))
        return;

    CreateTimer(1.0, FixTeam_Timer);
}

Action WinningTeam_Timer(Handle timer)
{
    if (IsNewGame() || !L4D_HasMapStarted())
        return Plugin_Continue;

    g_iWinningTeam = GetWinningTeam();

    return Plugin_Continue;
}

Action EnableFixTeam_Timer(Handle timer)
{
    if (!IsNewGame() || g_iWinningTeam == -1)
        return Plugin_Continue;
    
    ReorganizeQueue();

    g_bFixingTeams = true;
    FixTeams();
    CreateTimer(60.0, DisableFixTeam_Timer);

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

Action PrintQueueCmd(int client, int args)
{
    if (!IsHumanClient(client))
        return Plugin_Handled;

    PrintQueue(client);

    return Plugin_Handled;
}

Action RequestSlotCmd(int client, int args)
{
    if (!IsHumanClient(client) || g_bRoundOver)
        return Plugin_Handled;

    if (g_bFixingTeams)
    {
        CPrintToChat(client, SLOT_TAG, "SlotFixing");
        return Plugin_Handled;
    }

    if (g_bMixInProgress)
    {
        CPrintToChat(client, SLOT_TAG, "SlotNotAvailable");
        return Plugin_Handled;
    }

    if (IsInReady() && IsNewGame())
        return RequestSlotReadyUp(client);

    return RequestSlotInGame(client);
}

Action RequestSlotReadyUp(int client)
{
    int currentTeam = GetClientTeam(client);
    if (IsSurvivorOrInfected(currentTeam))
        return Plugin_Handled;

    if (MoveToFirstOpenTeam(client))
    {
        CPrintToChat(client, SLOT_TAG, "SlotJoined");
        return Plugin_Handled;
    }

    RemoveExpiredPlayers();

    char steamId[64];
    if (!GetSteamId(client, steamId, sizeof(steamId)))
        return Plugin_Handled;

    int requesterIndex = FindInQueue(steamId);
    if (requesterIndex == -1)
        return Plugin_Handled;

    int lastClient = -1;

    Player player;

    for (int i = g_aQueue.Length - 1; i > requesterIndex; i--)
    {
        g_aQueue.GetArray(i, player);

        int c = GetClientUsingSteamId(player.steamId);
        if (c == -1)
            continue;

        int team = GetClientTeam(c);
        if (IsSurvivorOrInfected(team))
        {
            lastClient = c;
            break;
        }
    }

    if (lastClient == -1)
    {
        CPrintToChat(client, SLOT_TAG, "SlotAllAhead");
        return Plugin_Handled;
    }

    ClaimSlot(client, lastClient, GetClientTeam(lastClient));

    return Plugin_Handled;
}

Action RequestSlotInGame(int client)
{
    char steamId[64];
    if (!GetSteamId(client, steamId, sizeof(steamId)))
        return Plugin_Handled;

    if (!IsStarter(steamId))
    {
        CPrintToChat(client, SLOT_TAG, "SlotStartersOnly");
        return Plugin_Handled;
    }

    int targetTeam = StarterCurrentTeam(steamId);
    if (!IsSurvivorOrInfected(targetTeam))
        return Plugin_Handled;

    if (GetClientTeam(client) == targetTeam)
        return Plugin_Handled;

    if (NumberOfPlayersInTheTeam(targetTeam) < TeamSize())
    {
        MovePlayerToTeam(client, targetTeam);
        CPrintToChat(client, SLOT_TAG, "SlotJoined");
        return Plugin_Handled;
    }

    RemoveExpiredPlayers();

    int substitute = -1;

    Player player;

    for (int i = g_aQueue.Length - 1; i >= 0; i--)
    {
        g_aQueue.GetArray(i, player);

        if (IsStarter(player.steamId))
            continue;

        int c = GetClientUsingSteamId(player.steamId);
        if (c == -1 || c == client)
            continue;

        if (GetClientTeam(c) != targetTeam)
            continue;

        substitute = c;
        break;
    }

    if (substitute == -1)
        return Plugin_Handled;

    if (IsControllingTank(substitute))
    {
        CPrintToChat(client, SLOT_TAG, "SlotTankControlled", substitute);
        return Plugin_Handled;
    }

    ClaimSlot(client, substitute, targetTeam);

    return Plugin_Handled;
}

public void OnMixStarted()
{
    g_bFixingTeams = false;
    g_bMixInProgress = true;
}

public void OnMixStopped()
{
    g_bMixInProgress = false;
}

public void OnRoundIsLive()
{
    g_bFixingTeams = false;
    g_bMixInProgress = false;

    if (IsNewGame())
        SnapshotTeams();

    SaveQueue();
}

public void OnClientPostAdminCheck(int client)
{
    Enqueue(client);
}

Action SuggestSlotCommand_Timer(Handle timer)
{
    if (!IsInReady() || !IsNewGame() || ConnectedPlayers() <= Slots())
        return Plugin_Stop;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsHumanClient(client))
            continue;

        if (GetClientTeam(client) != L4D_TEAM_SPECTATOR)
            continue;

        CPrintToChat(client, SLOT_TAG, "SlotSuggestion");
    }

    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    if (!IsHumanClient(client))
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
    if (!IsHumanClient(client))
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
    g_iWinningTeam = -1;
    g_aTeamA.Clear();
    g_aTeamB.Clear();

    int teamA = CurrentSideOf(0);
    int teamB = CurrentSideOf(1);

    char steamId[64];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsHumanClient(client))
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

    if (g_iWinningTeam == -1 || (g_aTeamA.Length == 0 && g_aTeamB.Length == 0))
        return;

    ArrayList winners = (g_iWinningTeam == 1) ? g_aTeamB : g_aTeamA;
    ArrayList losers = (g_iWinningTeam == 1) ? g_aTeamA : g_aTeamB;

    char steamId[64];
    Player player;

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

    for (int i = 0; i < losers.Length; i++)
    {
        losers.GetString(i, steamId, sizeof(steamId));

        strcopy(player.steamId, sizeof(player.steamId), steamId);
        player.expiresAt = ExpiresAtFor(steamId);

        g_aQueue.PushArray(player);
    }

    g_iWinningTeam = -1;
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

int StarterCurrentTeam(const char[] steamId)
{
    if (g_aTeamA.FindString(steamId) != -1)
        return CurrentSideOf(0);

    if (g_aTeamB.FindString(steamId) != -1)
        return CurrentSideOf(1);

    return L4D_TEAM_SPECTATOR;
}

int CurrentSideOf(int campaignTeam)
{
    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    if (campaignTeam == 0)
        return flipped ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVOR;

    return flipped ? L4D_TEAM_SURVIVOR : L4D_TEAM_INFECTED;
}

int GetClientUsingSteamId(const char[] steamId)
{
    char current[64];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsHumanClient(client))
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
    char output[MAX_QUEUE_MESSAGE_LENGTH];
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

        int team = GetClientTeam(client);

        if (IsSurvivorOrInfected(team))
            color = "{blue}";

        char entry[128];
        Format(entry, sizeof(entry), "{olive}%dº %s%N", position, color, client);

        if (strlen(output) != 0 && strlen(output) + 1 + strlen(entry) >= MAX_QUEUE_MESSAGE_LENGTH)
        {
            SendQueueLine(target, output, firstMessage);

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

    SendQueueLine(target, output, firstMessage);
}

void SendQueueLine(int target, const char[] line, bool withHeader)
{
    if (withHeader)
    {
        if (target == 0)
            CPrintToChatAll(QUEUE_TAG, line);
        else
            CPrintToChat(target, QUEUE_TAG, line);
    }
    else if (target == 0)
        CPrintToChatAll("%s", line);
    else
        CPrintToChat(target, "%s", line);
}

void FixTeams()
{
    RemoveExpiredPlayers();

    if (TeamsAreExactlyQueueFront())
    {
        g_bFixingTeams = false;
        return;
    }

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
        if (!IsHumanClient(client) || GetClientTeam(client) == L4D_TEAM_SPECTATOR)
            continue;

        found = false;

        for (int np = 0; !found && np < slots; np++)
            found = nextPlayers[np] == client;

        if (!found)
            MovePlayerToTeam(client, L4D_TEAM_SPECTATOR);
    }

    for (int np = 0; np < slots; np++)
    {
        int client = nextPlayers[np];

        if (client == -1 || GetClientTeam(client) != L4D_TEAM_SPECTATOR)
            continue;

        MoveToFirstOpenTeam(client);
    }

    g_bFixingTeams = !TeamsAreExactlyQueueFront();
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

bool TeamsAreExactlyQueueFront()
{
    int slots = Slots();

    if (g_aQueue.Length < slots)
        return false;

    if (NumberOfPlayersInTheTeam(L4D_TEAM_SURVIVOR) + NumberOfPlayersInTheTeam(L4D_TEAM_INFECTED) != slots)
        return false;

    Player player;

    for (int i = 0; i < slots; i++)
    {
        g_aQueue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            return false;

        int team = GetClientTeam(client);
        if (!IsSurvivorOrInfected(team))
            return false;
    }

    return true;
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

void ClaimSlot(int client, int bumped, int team)
{
    MovePlayerToTeam(bumped, L4D_TEAM_SPECTATOR);
    MovePlayerToTeam(client, team);

    CPrintToChat(client, SLOT_TAG, "SlotClaimed", bumped);
    CPrintToChat(bumped, SLOT_TAG, "SlotLost", client);
}

bool MoveToFirstOpenTeam(int client)
{
    int teamSize = TeamSize();

    for (int team = L4D_TEAM_SURVIVOR; team <= L4D_TEAM_INFECTED; team++)
    {
        if (NumberOfPlayersInTheTeam(team) < teamSize)
        {
            MovePlayerToTeam(client, team);
            return true;
        }
    }

    return false;
}

int NumberOfPlayersInTheTeam(int team)
{
    int count = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsHumanClient(client) || GetClientTeam(client) != team)
            continue;

        count++;
    }

    return count;
}

bool IsSurvivorOrInfected(int team)
{
    return team == L4D_TEAM_SURVIVOR || team == L4D_TEAM_INFECTED;
}

int ConnectedPlayers()
{
    int count = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsHumanClient(client))
            count++;
    }

    return count;
}

bool IsControllingTank(int client)
{
    if (GetClientTeam(client) != L4D_TEAM_INFECTED || !IsPlayerAlive(client))
        return false;

    return GetEntProp(client, Prop_Send, "m_zombieClass") == view_as<int>(L4D2ZombieClass_Tank);
}

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0
        && L4D2Direct_GetVSCampaignScore(1) == 0;
}

int GetWinningTeam()
{
    return GetTeamAScore() >= GetTeamBScore() ? 0 : 1;
}

int GetTeamAScore()
{
    return GetTeamTotalScore(0, 1);
}

int GetTeamBScore()
{
    return GetTeamTotalScore(1, 2);
}

int GetTeamTotalScore(int campaignTeam, int logicalTeam)
{
    int score = L4D2Direct_GetVSCampaignScore(campaignTeam);

    if (g_bRoundOver)
        return score;

    int mapScore = L4D_GetTeamScore(logicalTeam);

    if (mapScore > 0)
        score += mapScore;

    return score;
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

bool IsHumanClient(int client)
{
    return IsValidClient(client) && !IsFakeClient(client);
}

void LoadQueue()
{
    g_aQueue.Clear();

    LoadQueueFromFile();

    for (int client = 1; client <= MaxClients; client++)
        Enqueue(client);
}

void LoadQueueFromFile()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), QUEUE_FILE);

    if (!FileExists(path))
        return;

    File file = OpenFile(path, "r");
    if (file == null)
        return;

    char line[128];

    if (!file.ReadLine(line, sizeof(line)))
    {
        delete file;
        DeleteFile(path);
        return;
    }

    int now = GetTime();
    int savedAt = StringToInt(line);

    if (now - savedAt > QUEUE_MAX_AGE)
    {
        delete file;
        DeleteFile(path);
        return;
    }

    int expiresAt = now + g_cvDisconnectTimeout.IntValue;

    Player player;

    while (file.ReadLine(line, sizeof(line)))
    {
        TrimString(line);

        if (strlen(line) == 0)
            continue;

        strcopy(player.steamId, sizeof(player.steamId), line);
        player.expiresAt = GetClientUsingSteamId(line) != -1 ? 0 : expiresAt;

        g_aQueue.PushArray(player);
    }

    delete file;
    DeleteFile(path);
}

void SaveQueue()
{
    RemoveExpiredPlayers();

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), QUEUE_FILE);

    if (g_aQueue.Length == 0)
    {
        if (FileExists(path))
            DeleteFile(path);

        return;
    }

    File file = OpenFile(path, "w");
    if (file == null)
        return;

    file.WriteLine("%d", GetTime());

    Player player;

    for (int i = 0; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);
        file.WriteLine("%s", player.steamId);
    }

    delete file;
}