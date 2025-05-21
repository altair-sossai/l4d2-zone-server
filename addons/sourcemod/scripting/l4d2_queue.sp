#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <readyup>
#include <colors>

#define L4D2_TEAM_SPECTATOR 1
#define L4D2_TEAM_SURVIVOR 2
#define L4D2_TEAM_INFECTED 3

#define MAX_MESSAGE_NAMES 6
#define MAX_SEQUENCE 9999

ConVar g_cvDebug;

ArrayList g_aQueue;

int g_iSequence = 1;

bool g_bFixTeam = false,
     g_bSkipEnable = false,
     g_bSkip[MAXPLAYERS + 1];

enum struct Player
{
    char steamId[64];
    int priority;
    bool winning;
}

public Plugin myinfo =
{
    name = "L4D2 - Queue",
    author = "Altair Sossai",
    description = "Arranges players in a queue, showing who are the next players who should play",
    version = "1.0.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    g_cvDebug = CreateConVar("l4d2_queue_debug", "0", "Debug info for the queue plugin", FCVAR_HIDDEN|FCVAR_SPONLY|FCVAR_CHEAT|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_aQueue = new ArrayList(sizeof(Player));

    AddCommandListener(Mix_Callback, "sm_mix");
    AddCommandListener(Spectate_Callback, "sm_spectate");
    AddCommandListener(Spectate_Callback, "sm_spec");
    AddCommandListener(Spectate_Callback, "sm_s");
    AddCommandListener(JoinTeam_Callback, "jointeam");

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event);

    RegConsoleCmd("sm_fila", PrintQueueCmd, "Print the queue");
    RegConsoleCmd("sm_queue", PrintQueueCmd, "Print the queue");

    RegAdminCmd("sm_fixteams", FixTeamsCmd, ADMFLAG_BAN, "Fix teams using the queue");
}

Action Mix_Callback(int client, char[] command, int args)
{
    if (!g_bFixTeam || !IsNewGame())
        return Plugin_Continue;

    int teamSize = TeamSize();

    if (NumberOfPlayersInTheTeam(L4D2_TEAM_SURVIVOR) == teamSize && NumberOfPlayersInTheTeam(L4D2_TEAM_INFECTED) == teamSize)
    {
        DisableFixTeam();
        DisableSkip();
        ClearSkipData();
    }

    return Plugin_Continue; 
}

Action Spectate_Callback(int client, char[] command, int args)
{
    if (!g_bFixTeam || !g_bSkipEnable || !IsValidClient(client) || IsFakeClient(client) || !IsNewGame())
        return Plugin_Continue;

    g_bSkip[client] = true;

    return Plugin_Continue; 
}

Action JoinTeam_Callback(int client, char[] command, int args)
{
    if (!g_bFixTeam || !g_bSkipEnable || args == 0 || !IsValidClient(client) || IsFakeClient(client) || !IsNewGame())
        return Plugin_Continue;

    char buffer[128];
    GetCmdArg(1, buffer, sizeof(buffer));

    if (StrEqual("1", buffer, false) || StrEqual("Spectator", buffer, false))
        g_bSkip[client] = true;

    return Plugin_Continue;
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    DisableFixTeam();
    DisableSkip();

    ClearSkipData();

    CreateTimer(1.5, EnableFixTeam_Timer);
    CreateTimer(20.0, EnableSkip_Timer);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bFixTeam || !IsNewGame() || !L4D_HasMapStarted())
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || IsFakeClient(client))
        return;

    CreateTimer(1.0, FixTeam_Timer);
}

Action EnableFixTeam_Timer(Handle timer)
{
    if (!IsNewGame())
        return Plugin_Continue;

    EnableFixTeam();
    FixTeams();
    CreateTimer(60.0, DisableFixTeam_Timer);

    return Plugin_Continue;
}

Action EnableSkip_Timer(Handle timer)
{
    if (!IsNewGame())
        return Plugin_Continue;

    EnableSkip();

    return Plugin_Continue;
}

Action DisableFixTeam_Timer(Handle timer)
{
    DisableFixTeam();

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

public Action FixTeamsCmd(int client, int args)
{
    if (!IsValidClient(client) || IsFakeClient(client) || !IsNewGame() || !IsInReady())
        return Plugin_Handled;

    bool fixTeaam = g_bFixTeam;

    EnableFixTeam();
    FixTeams();

    g_bFixTeam = fixTeaam;

    return Plugin_Handled;
}

public void OnRoundIsLive()
{
    DisableFixTeam();
    DisableSkip();
    ClearSkipData();
}

public void OnClientPutInServer(int client)
{
    Enqueue(client);

    if (client >= 1 && client <= MaxClients)
        g_bSkip[client] = false;
}

public void OnClientDisconnect(int client)
{
    if (client >= 1 && client <= MaxClients)
        g_bSkip[client] = false;
}

public void L4D2_OnEndVersusModeRound_Post(int client)
{
    UnqueueAllDisconnected();
    RequeuePlayers();
    PrintQueue(0);
}

void Enqueue(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
        return;

    char steamId[64];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

    if (strlen(steamId) == 0 || StrEqual(steamId, "BOT"))
        return;

    Player player;

    for (int i = 0; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);

        if (StrEqual(player.steamId, steamId))
            return;
    }

    strcopy(player.steamId, sizeof(player.steamId), steamId);

    player.priority = NextSequence();
    player.winning = false;

    g_aQueue.PushArray(player);
}

void UnqueueAllDisconnected()
{
    Player player;
    
    for (int i = 0; i < g_aQueue.Length; )
    {
        g_aQueue.GetArray(i, player);

        if (GetClientUsingSteamId(player.steamId) != -1)
        {
            i++;
            continue;
        }

        g_aQueue.Erase(i);
    }
}

void RequeuePlayers()
{
    if (IsNewGame())
        return;

    Player player;

    bool survivorsAreWinning = SurvivorsAreWinning();
    bool infectedAreWinning = !survivorsAreWinning;

    for (int i = 0; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        int team = GetClientTeam(client);

        if (team == L4D2_TEAM_SURVIVOR)
        {
            player.priority = survivorsAreWinning ? 0 : MAX_SEQUENCE;
            player.winning = survivorsAreWinning;
        }
        else if (team == L4D2_TEAM_INFECTED)
        {
            player.priority = infectedAreWinning ? 0 : MAX_SEQUENCE;
            player.winning = infectedAreWinning;
        }
        else
        {
            player.priority = NextSequence();
            player.winning = false;
        }

        g_aQueue.SetArray(i, player);
    }

    SortQueue();
    ResetSequence();

    for (int i = 0; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        player.priority = NextSequence();
        g_aQueue.SetArray(i, player);
    }
}

void SortQueue()
{
    g_aQueue.SortCustom(SortByPriority);
}

int SortByPriority(int index1, int index2, Handle array, Handle hndl)
{
    Player player1, player2;

    g_aQueue.GetArray(index1, player1);
    g_aQueue.GetArray(index2, player2);

    if (player1.priority < player2.priority)
        return -1;

    if (player1.priority > player2.priority)
        return 1;

    return 0;
}

int GetClientUsingSteamId(const char[] steamId) 
{
    char current[64];
   
    for (int client = 1; client <= MaxClients; client++) 
    {
        if (!IsValidClient(client) || IsFakeClient(client))
            continue;
        
        GetClientAuthId(client, AuthId_Steam2, current, sizeof(current));     
        
        if (StrEqual(steamId, current))
            return client;
    }
    
    return -1;
}

void PrintQueue(int target)
{
    if (IsNewGame())
        PrintWinners(target);

    PrintOtherPlayers(target);
}

void PrintWinners(int target)
{
    if (g_aQueue.Length == 0)
        return;

    Player player;
    char output[512];

    for (int i = 0; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);

        if (!player.winning)
            break;

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        if (strlen(output) == 0)
            FormatEx(output, sizeof(output), "{orange}Winners: {default}%N", client);
        else
            Format(output, sizeof(output), "%s{green}, {default}%N", output, client);
    }

    if (strlen(output) == 0)
        return;

    if (target == 0)
        CPrintToChatAll(output);
    else
        CPrintToChat(target, output);
}

void PrintOtherPlayers(int target)
{
    if (g_aQueue.Length == 0)
        return;

    Player player;
    char output[512];

    bool isNewGame = IsNewGame();

    for (int i = 0, count = 0, position = 1; i < g_aQueue.Length; i++)
    {
        g_aQueue.GetArray(i, player);

        if (isNewGame && player.winning)
            continue;

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        if (!isNewGame)
        {
            int team = GetClientTeam(client);
            if (team == L4D2_TEAM_SURVIVOR || team == L4D2_TEAM_INFECTED)
                continue;
        }

        if (position == 1)
            FormatEx(output, sizeof(output), "{orange}Fila: {blue}%dº {default}%N", position, client);
        else
            Format(output, sizeof(output), "%s {blue}%dº {default}%N", output, position, client);

        count++;
        position++;

        if (count == MAX_MESSAGE_NAMES)
        {
            if (target == 0)
                CPrintToChatAll(output);
            else
                CPrintToChat(target, output);

            output = "";
            count = 0;
        }
    }

    if (strlen(output) == 0)
        return;

    if (target == 0)
        CPrintToChatAll(output);
    else
        CPrintToChat(target, output);
}

void FixTeams()
{
    PrintDebug("FixTeams() called");

    bool mustFixTheTeams = MustFixTheTeams();

    PrintDebug("MustFixTheTeams() returned %s", mustFixTheTeams ? "true" : "false");

    if (!mustFixTheTeams) 
        return;

    DisableFixTeam();

    int slots = Slots();
    int[] nextPlayers = new int[slots];

    PrintDebug("Slots: %d", slots);
    PrintDebug("Queue length: %d", g_aQueue.Length);

    for (int np = 0; np < slots; np++)
        nextPlayers[np] = -1;

    Player player;

    PrintDebug("Filling nextPlayers[]");

    for (int i = 0, np = 0; i < g_aQueue.Length && np < slots; i++)
    {
        g_aQueue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);

        if (client == -1)
            PrintDebug("#%d - Client: %d, SteamId: %s", i, client, player.steamId);
        else
            PrintDebug("#%d - Client: %d (%N), SteamId: %s, Skip: %s", i, client, client, player.steamId, g_bSkip[client] ? "true" : "false");

        if (client == -1 || g_bSkip[client])
            continue;

        nextPlayers[np++] = client;
    }

    PrintDebug("nextPlayers[] filled");

    for (int np = 0; np < slots; np++)
    {
        if (nextPlayers[np] == -1)
            PrintDebug("nextPlayers[%d]: %d", np, nextPlayers[np]);
        else
            PrintDebug("nextPlayers[%d]: %d (%N)", np, nextPlayers[np], nextPlayers[np]);
    }

    bool found = false;

    PrintDebug("Moving players to spectator team");

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client))
            continue;

        PrintDebug("Client %d (%N), IsValidClient: %d, IsFakeClient: %d, Team: %d", client, client, IsValidClient(client), IsFakeClient(client), GetClientTeam(client));

        if (IsFakeClient(client) || GetClientTeam(client) == L4D2_TEAM_SPECTATOR)
            continue;

        found = false;

        for (int np = 0; !found && np < slots; np++)
            found = nextPlayers[np] == client;
        
        PrintDebug("Client %d (%N), found: %s", client, client, found ? "true" : "false");

        if (!found)
        {
            PrintDebug("Moving client %d (%N) to spectator team", client, client);
            MovePlayerToTeam(client, L4D2_TEAM_SPECTATOR);
        }
    }

    int teamSize = TeamSize();

    PrintDebug("Team size: %d", teamSize);
    PrintDebug("Moving players to teams");

    for (int np = 0; np < slots; np++)
    {
        int client = nextPlayers[np];

        if (client == -1)
            PrintDebug("#%d - Client: %d", np, client);
        else
            PrintDebug("#%d - Client: %d (%N), Team: %d", np, client, client, GetClientTeam(client));

        if (client == -1 || GetClientTeam(client) != L4D2_TEAM_SPECTATOR)
            continue;

        for (int team = L4D2_TEAM_SURVIVOR; team <= L4D2_TEAM_INFECTED; team++)
        {
            PrintDebug("Team %d - Count: %d", team, NumberOfPlayersInTheTeam(team));

            if (NumberOfPlayersInTheTeam(team) < teamSize)
            {
                PrintDebug("Moving client %d (%N) to team %d", client, client, team);
                MovePlayerToTeam(client, team);
                break;
            }
            else
            {
                PrintDebug("Team %d is full", team);
            }
        }
    }

    EnableFixTeam();

    PrintDebug("FixTeams() finished");
}

bool MustFixTheTeams()
{
    PrintDebug("MustFixTheTeams() called");
    PrintDebug("g_bFixTeam: %s", g_bFixTeam ? "true" : "false");

    if (!g_bFixTeam)
        return false;

    int availableSlots = Slots();

    PrintDebug("Queue length: %d", g_aQueue.Length);
    PrintDebug("Available slots: %d", availableSlots);

    if (g_aQueue.Length <= availableSlots)
        return false;

    Player player;

    for (int i = 0; i < g_aQueue.Length && availableSlots > 0; i++)
    {
        g_aQueue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);

        if (client == -1)
            PrintDebug("#%d - Client: %d, SteamId: %s", i, client, player.steamId);
        else
            PrintDebug("#%d - Client: %d (%N), SteamId: %s, Skip: %s, Team: %d", i, client, client, player.steamId, g_bSkip[client] ? "true" : "false", GetClientTeam(client));

        if (client == -1 || g_bSkip[client])
            continue;

        if (GetClientTeam(client) == L4D2_TEAM_SPECTATOR)
            return true;

        availableSlots--;

        PrintDebug("Available slots: %d", availableSlots);
    }

    return false;
}

void MovePlayerToTeam(int client, int team)
{
    if (team != L4D2_TEAM_SPECTATOR && NumberOfPlayersInTheTeam(team) >= TeamSize())
        return;

    switch (team)
    {
        case L4D2_TEAM_SPECTATOR:
            ChangeClientTeam(client, L4D2_TEAM_SPECTATOR); 

        case L4D2_TEAM_SURVIVOR:
            FakeClientCommand(client, "jointeam 2");

        case L4D2_TEAM_INFECTED:
            ChangeClientTeam(client, L4D2_TEAM_INFECTED);
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

bool SurvivorsAreWinning()
{
    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    int survivorIndex = flipped ? 1 : 0;
    int infectedIndex = flipped ? 0 : 1;

    int survivorScore = L4D2Direct_GetVSCampaignScore(survivorIndex);
    int infectedScore = L4D2Direct_GetVSCampaignScore(infectedIndex);

    return survivorScore >= infectedScore;
}

void ResetSequence()
{
    g_iSequence = 1;
}

int NextSequence()
{
    return g_iSequence++;
}

int Slots()
{
    return TeamSize() * 2;
}

int TeamSize()
{
    return GetConVarInt(FindConVar("survivor_limit"));
}

void EnableFixTeam()
{
    g_bFixTeam = true;
}

void DisableFixTeam()
{
    g_bFixTeam = false;
}

void EnableSkip()
{
    g_bSkipEnable = true;
}

void DisableSkip()
{
    g_bSkipEnable = false;
}

void ClearSkipData()
{
    for (int client = 1; client <= MaxClients; client++)
        g_bSkip[client] = false;
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients) 
        return false;

    return IsClientInGame(client);
}

void PrintDebug(const char[] format, any ...)
{
    if (!g_cvDebug.BoolValue)
        return;

    char msg[256];
    VFormat(msg, sizeof(msg), format, 2);
    PrintToConsoleAll("[QUEUE] %s", msg);
}