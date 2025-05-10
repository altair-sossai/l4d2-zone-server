#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <sourcemod>
#include <readyup>
#include <left4dhooks>

#define L4D2_TEAM_SPECTATOR 1
#define L4D2_TEAM_SURVIVOR 2
#define L4D2_TEAM_INFECTED 3

#define MAX_MESSAGE_NAMES 6
#define MAX_SEQUENCE 9999

ArrayList h_Queue;

int sequence = 1;
bool fixTeam = false;

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
    h_Queue = new ArrayList(sizeof(Player));

    AddCommandListener(Mix_Callback, "sm_mix");

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event);

    RegConsoleCmd("sm_fila", PrintQueueCmd);
    RegConsoleCmd("sm_queue", PrintQueueCmd);
    RegConsoleCmd("sm_fixteams", FixTeamsCmd);
}

public void OnRoundIsLive()
{
    DisableFixTeam();
}

Action Mix_Callback(int client, char[] command, int args)
{
    DisableFixTeam();

    return Plugin_Continue; 
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    DisableFixTeam();
    CreateTimer(5.0, EnableFixTeam_Timer);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!L4D_HasMapStarted())
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    CreateTimer(1.0, FixTeam_Timer);
}

Action EnableFixTeam_Timer(Handle timer)
{
    EnableFixTeam();
    FixTeams();
    CreateTimer(60.0, DisableFixTeam_Timer);

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
    PrintQueue(client);

    return Plugin_Handled;
}

public Action FixTeamsCmd(int client, int args)
{
    if (!MustFixTheTeams())
    {
        CPrintToChat(client, "{red}[Queue]{default} Cannot fix teams: {lightgreen}queue is empty{default} or there are {lightgreen}enough slots for all players{default}.");
        return Plugin_Handled;
    }

    FixTeams();

    return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
    Enqueue(client);
}

public void L4D2_OnEndVersusModeRound_Post(int client)
{
    UnqueueAllDisconnected();
    RequeuePlayers();
    PrintQueue(0);
}

void Enqueue(int client)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    char steamId[64];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

    if (strlen(steamId) == 0 || StrEqual(steamId, "BOT"))
        return;

    Player player;

    for (int i = 0; i < h_Queue.Length; i++)
    {
        h_Queue.GetArray(i, player);

        if (StrEqual(player.steamId, steamId))
            return;
    }

    strcopy(player.steamId, sizeof(player.steamId), steamId);

    player.priority = NextSequence();
    player.winning = false;

    h_Queue.PushArray(player);
}

void UnqueueAllDisconnected()
{
    Player player;
    
    for (int i = 0; i < h_Queue.Length; )
    {
        h_Queue.GetArray(i, player);

        if (GetClientUsingSteamId(player.steamId) != -1)
        {
            i++;
            continue;
        }

        h_Queue.Erase(i);
    }
}

void RequeuePlayers()
{
    if (IsNewGame())
        return;

    Player player;

    bool survivorsAreWinning = SurvivorsAreWinning();
    bool infectedAreWinning = !survivorsAreWinning;

    for (int i = 0; i < h_Queue.Length; i++)
    {
        h_Queue.GetArray(i, player);

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

        h_Queue.SetArray(i, player);
    }

    SortQueue();
    ResetSequence();

    for (int i = 0; i < h_Queue.Length; i++)
    {
        h_Queue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        player.priority = NextSequence();
        h_Queue.SetArray(i, player);
    }
}

void SortQueue()
{
    h_Queue.SortCustom(SortByPriority);
}

int SortByPriority(int index1, int index2, Handle array, Handle hndl)
{
    Player player1, player2;

    h_Queue.GetArray(index1, player1);
    h_Queue.GetArray(index2, player2);

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
        if (!IsClientInGame(client) || IsFakeClient(client))
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
    if (h_Queue.Length == 0)
        return;

    Player player;
    char output[512];

    for (int i = 0; i < h_Queue.Length; i++)
    {
        h_Queue.GetArray(i, player);

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
    if (h_Queue.Length == 0)
        return;

    Player player;
    char output[512];

    bool isNewGame = IsNewGame();

    for (int i = 0, count = 0, position = 1; i < h_Queue.Length; i++)
    {
        h_Queue.GetArray(i, player);

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
    if (!MustFixTheTeams())
        return;

    PrintToConsoleAll("[Queue] Fixing teams...");

    int slots = Slots();
    int[] nextPlayers = new int[slots];

    for (int np = 0; np < slots; np++)
        nextPlayers[np] = -1;

    for (int i = 0, np = 0; i < h_Queue.Length && slots > np; i++)
    {
        Player player;
        h_Queue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        nextPlayers[np++] = client;
    }

    for (int np = 0; np < slots; np++)
        PrintToConsoleAll("[Queue] Next player %d: %d", np + 1, nextPlayers[np]);

    bool found = false;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == L4D2_TEAM_SPECTATOR)
            continue;

        found = false;

        for (int np = 0; !found && np < slots; np++)
            found = nextPlayers[np] == client;
        
        if (!found)
            MovePlayerToTeam(client, L4D2_TEAM_SPECTATOR);
    }

    int teamSize = TeamSize();

    for (int np = 0; np < slots; np++)
    {
        int client = nextPlayers[np];

        if (client == -1 || GetClientTeam(client) != L4D2_TEAM_SPECTATOR)
            continue;

        for (int team = L4D2_TEAM_SURVIVOR; team <= L4D2_TEAM_INFECTED; team++)
        {
            if (NumberOfPlayersInTheTeam(team) < teamSize)
            {
                MovePlayerToTeam(client, team);
                break;
            }
        }
    }
}

bool MustFixTheTeams()
{
    if (!fixTeam || !IsNewGame())
        return false;

    int availableSlots = Slots();

    if (h_Queue.Length <= availableSlots)
        return false;

    for (int i = 0; i < h_Queue.Length && availableSlots > 0; i++)
    {
        Player player;
        h_Queue.GetArray(i, player);

        int client = GetClientUsingSteamId(player.steamId);
        if (client == -1)
            continue;

        if (GetClientTeam(client) == L4D2_TEAM_SPECTATOR)
            return true;

        availableSlots--;
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
        if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != team)
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
    sequence = 1;
}

int NextSequence()
{
    return sequence++;
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
    fixTeam = true;
}

void DisableFixTeam()
{
    fixTeam = false;
}