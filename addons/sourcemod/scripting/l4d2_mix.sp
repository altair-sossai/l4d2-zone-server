#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_sound>
#include <l4d2util_constants>

#define MAX_STR_LEN 30

#define COND_HAS_ALREADY_VOTED 0
#define COND_NEED_MORE_VOTES 1
#define COND_START_MIX 2
#define COND_START_MIX_ADMIN 3
#define COND_NO_PLAYERS 4

#define STATE_FIRST_CAPT 0
#define STATE_SECOND_CAPT 1
#define STATE_NO_MIX 2
#define STATE_PICK_TEAMS 3

ConVar g_cvStartVotes,
       g_cvAdditionalPlayersAfterMix;

Menu g_mMixMenu;

StringMap g_smVoteResults,
          g_smSwapWhitelist,
          g_smPlayers;

int g_iCurrentState = STATE_NO_MIX,
    g_iMixCallsCount = 0,
    g_iRequiredStartVotes = 0,
    g_iMaxVoteCount = 0,
    g_iPickCount = 0,
    g_iSurvivorsPick = 0;

char g_sCurrentMaxVotedCaptainAuthId[MAX_STR_LEN],
     g_sSurvivorCaptainAuthId[MAX_STR_LEN],
     g_sInfectedCaptainAuthId[MAX_STR_LEN];

bool g_bIsMixAllowed = false,
     g_bIsPickingCaptain = false;

Handle g_hMixStartedForward,
       g_hMixStoppedForward,
       g_hCaptainVoteTimer;

public Plugin myinfo =
{
    name = "L4D2 Mix Manager",
    author = "Luckylock",
    description = "Provides ability to pick captains and teams through menus",
    version = "4",
    url = "https://github.com/LuckyServ/"
};

public void OnPluginStart()
{
    g_cvStartVotes = CreateConVar("l4d2_mix_start_votes", "2", "Number of votes required to start a mix", FCVAR_NOTIFY, true, 1.0);
    g_cvAdditionalPlayersAfterMix = CreateConVar("l4d2_mix_additional_players_after_mix", "2", "Additional players required to vote after each mix starts before the game goes live (0 disables)", FCVAR_NOTIFY, true, 0.0);
    g_iRequiredStartVotes = Clamp(g_cvStartVotes.IntValue, 1, Slots());

    RegConsoleCmd("sm_mix", Cmd_MixStart, "Mix command");
    RegAdminCmd("sm_stopmix", Cmd_MixStop, ADMFLAG_CHANGEMAP, "Mix command");

    AddCommandListener(Cmd_OnPlayerJoinTeam, "jointeam");

    g_smVoteResults = new StringMap();
    g_smSwapWhitelist = new StringMap();
    g_smPlayers = new StringMap();
    g_hMixStartedForward = CreateGlobalForward("OnMixStarted", ET_Event);
    g_hMixStoppedForward = CreateGlobalForward("OnMixStopped", ET_Event);
    
    PrecacheSound("buttons/blip1.wav");
}

public void OnMapStart()
{
    g_bIsMixAllowed = true;
    ResetMixVoteProgress();
    StopMix();
}

public void OnRoundIsLive()
{
    g_bIsMixAllowed = false;
    ResetMixVoteProgress();
    StopMix();
}

void StartMix()
{
    FakeClientCommandAll("sm_hide");
    Call_StartForward(g_hMixStartedForward);
    Call_Finish();
    EmitSoundToAll("buttons/blip1.wav"); 
}

void StopMix()
{
    g_iCurrentState = STATE_NO_MIX;
    FakeClientCommandAll("sm_show");
    Call_StartForward(g_hMixStoppedForward);
    Call_Finish();

    if (g_bIsPickingCaptain && g_hCaptainVoteTimer != null)
    {
        KillTimer(g_hCaptainVoteTimer);
    }

    g_iMixCallsCount = 0;

    if (g_smVoteResults != null)
    {
        g_smVoteResults.Clear();
    }
}

void ResetMixVoteProgress()
{
    g_iMixCallsCount = 0;
    g_iRequiredStartVotes = Clamp(g_cvStartVotes.IntValue, 1, Slots());

    if (g_smVoteResults != null)
    {
        g_smVoteResults.Clear();
    }
}

void IncreaseRequiredStartVotes()
{
    g_iRequiredStartVotes = Clamp(g_iRequiredStartVotes + g_cvAdditionalPlayersAfterMix.IntValue, 1, Slots());
}

void FakeClientCommandAll(const char[] command)
{
    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            FakeClientCommand(client, command);
        }  
    }
}

Action Cmd_OnPlayerJoinTeam(int client, const char[] command, int argc)
{
    char authId[MAX_STR_LEN];
    char cmdArgBuffer[MAX_STR_LEN];
    int allowedTeam;
    int newTeam;

    if (argc >= 1)
    {

        GetCmdArg(1, cmdArgBuffer, MAX_STR_LEN);
        newTeam = StringToInt(cmdArgBuffer);

        if (g_iCurrentState != STATE_NO_MIX && newTeam != L4D2Team_Spectator && IsHuman(client))
        {

            GetClientAuthId(client, AuthId_SteamID64, authId, MAX_STR_LEN); 

            if (!g_smSwapWhitelist.GetValue(authId, allowedTeam) || allowedTeam != newTeam)
            {
                PrintToChat(client, "\x04Mix Manager: \x01 You can not join a team without being picked.");
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue; 
}

public void OnClientPutInServer(int client)
{
    char authId[MAX_STR_LEN];

    if (g_iCurrentState != STATE_NO_MIX && IsHuman(client))
    {
        GetClientAuthId(client, AuthId_SteamID64, authId, MAX_STR_LEN);
        ChangeClientTeamEx(client, L4D2Team_Spectator);
    }
}

Action Cmd_MixStop(int client, int args)
{
    if (g_iCurrentState != STATE_NO_MIX)
    {
        StopMix();
        PrintToChatAll("\x04Mix Manager: \x01Stopped by admin \x03%N\x01.", client);
    }
    else
    {
        PrintToChat(client, "\x04Mix Manager: \x01Not currently started.");
    }
    return Plugin_Handled;
}

Action Cmd_MixStart(int client, int args)
{
    if (TeamSize() == 1)
    {
        return Plugin_Handled;
    }

    if (g_iCurrentState != STATE_NO_MIX)
    {
        PrintToChat(client, "\x04Mix Manager: \x01Already started.");
        return Plugin_Handled;
    } 
    
    if (!g_bIsMixAllowed)
    {
        PrintToChat(client, "\x04Mix Manager: \x01Not allowed on live round.");
        return Plugin_Handled;
    } 
    
    if (GetClientTeam(client) == L4D2Team_Spectator && !GetAdminFlag(GetUserAdmin(client), Admin_Changemap))
    {
        PrintToChat(client, "\x04Mix Manager: \x01You can not start a mix as a spectator.");
        return Plugin_Handled;
    }

    int mixConditions = GetMixConditionsAfterVote(client);

    if (mixConditions == COND_START_MIX || mixConditions == COND_START_MIX_ADMIN)
    {
        if (mixConditions == COND_START_MIX_ADMIN)
        {
            PrintToChatAll("\x04Mix Manager: \x01Started by admin \x03%N\x01.", client);
        }
        else
        {
            PrintToChatAll("\x04Mix Manager: \x03%N \x01has voted to start a Mix.", client);
            PrintToChatAll("\x04Mix Manager: \x01Started by vote.");
        }

        g_iCurrentState = STATE_FIRST_CAPT;
        IncreaseRequiredStartVotes();
        StartMix();
        SwapAllPlayersToSpec();

        // Initialise values
        g_iMixCallsCount = 0;
        g_smVoteResults.Clear();
        g_smSwapWhitelist.Clear();
        g_iMaxVoteCount = 0;
        strcopy(g_sCurrentMaxVotedCaptainAuthId, MAX_STR_LEN, " ");
        g_iPickCount = 0;

        if (Menu_Initialise())
        {
            Menu_AddAllSpectators();
            Menu_DisplayToAllSpecs();
        }

        g_hCaptainVoteTimer = CreateTimer(11.0, Menu_StateHandler, _, TIMER_REPEAT);
        g_bIsPickingCaptain = true;
    }
    else if (mixConditions == COND_NEED_MORE_VOTES)
    {
        PrintToChatAll("\x04Mix Manager: \x03%N \x01has voted to start a Mix. (\x05%d \x01more to start)", client, g_iRequiredStartVotes - g_iMixCallsCount);
    }
    else if (mixConditions == COND_HAS_ALREADY_VOTED)
    {
        PrintToChat(client, "\x04Mix Manager: \x01You already voted to start a Mix.");
    }
    else if (mixConditions == COND_NO_PLAYERS)
    {
        PrintToChat(client, "\x04Mix Manager: \x01Join teams to start a mix.");
    }

    return Plugin_Handled;
}

int GetMixConditionsAfterVote(int client)
{
    bool dummy = false;
    char clientAuthId[MAX_STR_LEN];
    GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
    bool hasVoted = g_smVoteResults.GetValue(clientAuthId, dummy);

    if (!SavePlayers())
    {
        return COND_NO_PLAYERS;
    }

    if (GetAdminFlag(GetUserAdmin(client), Admin_Changemap))
    {
        return COND_START_MIX_ADMIN;
    }
    else if (hasVoted)
    {
        return COND_HAS_ALREADY_VOTED;
    }
    else if (++g_iMixCallsCount >= g_iRequiredStartVotes)
    {
        return COND_START_MIX; 
    }
    else
    {
        g_smVoteResults.SetValue(clientAuthId, true);
        return COND_NEED_MORE_VOTES;
    }
}

bool SavePlayers()
{
    char clientAuthId[MAX_STR_LEN];

    g_smPlayers.Clear();

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsSurvivor(client))
        {
            GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
        }
        else if (IsInfected(client))
        {
            GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
        }

        if (IsSurvivor(client) || IsInfected(client))
        {
            g_smPlayers.SetValue(clientAuthId, true);
        }
    }

    return g_smPlayers.Size == Slots();
}

bool Menu_Initialise()
{
    if (g_iCurrentState == STATE_NO_MIX) return false;

    g_mMixMenu = new Menu(Menu_MixHandler, MENU_ACTIONS_ALL);
    g_mMixMenu.ExitButton = false;

    switch(g_iCurrentState)
    {
        case STATE_FIRST_CAPT:
        {
            g_mMixMenu.SetTitle("Mix Manager - Pick first captain");
            return true;
        }

        case STATE_SECOND_CAPT:
        {
            g_mMixMenu.SetTitle("Mix Manager - Pick second captain");
            return true;
        }

        case STATE_PICK_TEAMS:
        {
            g_mMixMenu.SetTitle("Mix Manager - Pick team member(s)");
            return true;
        }
    }

    delete g_mMixMenu;
    return false;
}

void Menu_AddAllSpectators()
{
    char clientName[MAX_STR_LEN];
    char clientId[MAX_STR_LEN];

    g_mMixMenu.RemoveAllItems();

    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientSpec(client) && IsClientInPlayers(client))
        {
            GetClientAuthId(client, AuthId_SteamID64, clientId, MAX_STR_LEN);
            GetClientName(client, clientName, MAX_STR_LEN);
            g_mMixMenu.AddItem(clientId, clientName);
        }  
    }
}

bool IsClientInPlayers(int client)
{
    bool dummy;
    char clientAuthId[MAX_STR_LEN];
    GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
    return g_smPlayers.GetValue(clientAuthId, dummy);
}

void Menu_DisplayToAllSpecs()
{
    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientSpec(client) && IsClientInPlayers(client))
        {
            g_mMixMenu.Display(client, 10);
        }
    }
}

int Menu_MixHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        if (g_iCurrentState == STATE_FIRST_CAPT || g_iCurrentState == STATE_SECOND_CAPT)
        {
            char authId[MAX_STR_LEN];
            menu.GetItem(param2, authId, MAX_STR_LEN);

            int voteCount = 0;

            if (!g_smVoteResults.GetValue(authId, voteCount))
            {
                voteCount = 0;
            }

            g_smVoteResults.SetValue(authId, ++voteCount, true);

            if (voteCount > g_iMaxVoteCount)
            {
                strcopy(g_sCurrentMaxVotedCaptainAuthId, MAX_STR_LEN, authId);
                g_iMaxVoteCount = voteCount;
            }
        }
        else if (g_iCurrentState == STATE_PICK_TEAMS)
        {
            char authId[MAX_STR_LEN]; 
            menu.GetItem(param2, authId, MAX_STR_LEN);
            int team = GetClientTeamEx(param1);

            if (team == L4D2Team_Spectator || (team == L4D2Team_Infected && g_iSurvivorsPick == 1) || (team == L4D2Team_Survivor && g_iSurvivorsPick == 0))
            {
                PrintToChatAll("\x04Mix Manager: \x01Captain \x03%N \x01found in the wrong team, aborting...", param1);
                StopMix();
            }
            else
            {
               
                if (SwapPlayerToTeam(authId, team, 0))
                {
                    int requiredPicks = Slots() - 2;
                    g_iPickCount++;
                    if (g_iPickCount >= requiredPicks)
                    {
                        PrintToChatAll("\x04Mix Manager: \x01 Teams are picked.");
                        StopMix();
                    }
                    else if (g_iPickCount != requiredPicks - 2)
                    {
                        g_iSurvivorsPick = g_iSurvivorsPick == 1 ? 0 : 1;
                    } 
                }
                else
                {
                    PrintToChatAll("\x04Mix Manager: \x01The team member who was picked was not found, aborting...", param1);
                    StopMix();
                }
            }
        }
    }

    return 0;
}

Action Menu_StateHandler(Handle timer, any data)
{
    switch(g_iCurrentState)
    {
        case STATE_FIRST_CAPT:
        {
            int numVotes = 0;
            g_smVoteResults.GetValue(g_sCurrentMaxVotedCaptainAuthId, numVotes);
            g_smVoteResults.Clear();
           
            if (SwapPlayerToTeam(g_sCurrentMaxVotedCaptainAuthId, L4D2Team_Survivor, numVotes))
            {
                strcopy(g_sSurvivorCaptainAuthId, MAX_STR_LEN, g_sCurrentMaxVotedCaptainAuthId);
                g_iCurrentState = STATE_SECOND_CAPT;
                g_iMaxVoteCount = 0;

                if (Menu_Initialise())
                {
                    Menu_AddAllSpectators();
                    Menu_DisplayToAllSpecs();
                }
            }
            else
            {
                PrintToChatAll("\x04Mix Manager: \x01Failed to find first captain with at least 1 vote from spectators, aborting...");
                StopMix();
            }

            strcopy(g_sCurrentMaxVotedCaptainAuthId, MAX_STR_LEN, " ");
        }

        case STATE_SECOND_CAPT:
        {
            int numVotes = 0;
            g_smVoteResults.GetValue(g_sCurrentMaxVotedCaptainAuthId, numVotes);
            g_smVoteResults.Clear();

            if (SwapPlayerToTeam(g_sCurrentMaxVotedCaptainAuthId, L4D2Team_Infected, numVotes))
            {
                strcopy(g_sInfectedCaptainAuthId, MAX_STR_LEN, g_sCurrentMaxVotedCaptainAuthId);
                g_iCurrentState = STATE_PICK_TEAMS;
                CreateTimer(0.5, Menu_StateHandler); 
            }
            else
            {
                PrintToChatAll("\x04Mix Manager: \x01Failed to find second captain with at least 1 vote from spectators, aborting...");
                StopMix();
            }

            strcopy(g_sCurrentMaxVotedCaptainAuthId, MAX_STR_LEN, " ");
        }

        case STATE_PICK_TEAMS:
        {
            g_bIsPickingCaptain = false;
            g_iSurvivorsPick = GetURandomInt() & 1;
            CreateTimer(1.0, Menu_TeamPickHandler, _, TIMER_REPEAT);
        }
    }

    if (g_iCurrentState == STATE_NO_MIX || g_iCurrentState == STATE_PICK_TEAMS)
    {
        return Plugin_Stop; 
    }
    else
    {
        return Plugin_Handled;
    }
}

Action Menu_TeamPickHandler(Handle timer)
{
    if (g_iCurrentState == STATE_PICK_TEAMS)
    {

        if (Menu_Initialise())
        {
            Menu_AddAllSpectators();
            int captain;

            if (g_iSurvivorsPick == 1)
            {
               captain = GetClientFromAuthId(g_sSurvivorCaptainAuthId);
            }
            else
            {
               captain = GetClientFromAuthId(g_sInfectedCaptainAuthId);
            }

            if (captain > 0)
            {
                if (GetSpectatorsCount() > 0)
                {
                    g_mMixMenu.Display(captain, 1);
                }
                else
                {
                    PrintToChatAll("\x04Mix Manager: \x01No more spectators to choose from, aborting...");
                    StopMix();
                    return Plugin_Stop;
                }
            }
            else
            {
                PrintToChatAll("\x04Mix Manager: \x01Failed to find the captain, aborting...");
                StopMix();
                return Plugin_Stop;
            }

            return Plugin_Continue;
        }
    }
    return Plugin_Stop;
}

void SwapAllPlayersToSpec()
{
    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            ChangeClientTeamEx(client, L4D2Team_Spectator);
        }
    }
}

bool SwapPlayerToTeam(const char[] authId, int team, int numVotes)
{
    int client = GetClientFromAuthId(authId);
    bool foundClient = client > 0;

    if (foundClient)
    {
        g_smSwapWhitelist.SetValue(authId, team);
        ChangeClientTeamEx(client, team);

        switch(g_iCurrentState)
        {
            case STATE_FIRST_CAPT:
            {
                PrintToChatAll("\x04Mix Manager: \x01First captain is \x03%N\x01. (\x05%d \x01votes)", client, numVotes);
            }
            
            case STATE_SECOND_CAPT:
            {
                PrintToChatAll("\x04Mix Manager: \x01Second captain is \x03%N\x01. (\x05%d \x01votes)", client, numVotes);
            }

            case STATE_PICK_TEAMS:
            {
                if (g_iSurvivorsPick == 1)
                {
                    PrintToChatAll("\x04Mix Manager: \x03%N \x01was picked (survivors).", client);
                }
                else
                {
                    PrintToChatAll("\x04Mix Manager: \x03%N \x01was picked (infected).", client);
                }
            }
        }
    }

    return foundClient;
}

public void OnClientDisconnect(int client)
{
    if (g_iCurrentState != STATE_NO_MIX && IsClientInPlayers(client))
    {
        PrintToChatAll("\x04Mix Manager: \x01Player \x03%N \x01has left the game, aborting...", client);
        StopMix();
    }
}

int GetClientFromAuthId(const char[] authId)
{
    char clientAuthId[MAX_STR_LEN];
    int client = 0;
    int i = 0;
    
    while (client == 0 && i < MaxClients)
    {
        ++i;

        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            GetClientAuthId(i, AuthId_SteamID64, clientAuthId, MAX_STR_LEN); 

            if (StrEqual(authId, clientAuthId))
            {
                client = i;
            }
        }
    }

    return client;
}

bool IsClientSpec(int client)
{
    return IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1;
}

int GetSpectatorsCount()
{
    int count = 0;

    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientSpec(client))
        {
            ++count;
        }
    }

    return count;
}

int Clamp(int value, int minimum, int maximum)
{
    if (value < minimum)
    {
        return minimum;
    }

    if (value > maximum)
    {
        return maximum;
    }

    return value;
}

int Slots()
{
    return TeamSize() * 2;
}

int TeamSize()
{
    return GetConVarInt(FindConVar("survivor_limit"));
}

bool ChangeClientTeamEx(int client, int team)
{
    if (GetClientTeamEx(client) == team)
    {
        return true;
    }

    if (team != L4D2Team_Survivor)
    {
        ChangeClientTeam(client, team);
        return true;
    }
    else
    {
        int bot = FindSurvivorBot();

        if (bot > 0)
        {
            int flags = GetCommandFlags("sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
            FakeClientCommand(client, "sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags);
            return true;
        }
    }
    return false;
}

int GetClientTeamEx(int client)
{
    return GetClientTeam(client);
}

int FindSurvivorBot()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && IsFakeClient(client) && GetClientTeamEx(client) == L4D2Team_Survivor)
        {
            return client;
        }
    }
    return -1;
}

bool IsSurvivor(int client)
{                                                                               
    return IsHuman(client)
        && GetClientTeam(client) == 2; 
}

bool IsInfected(int client)
{                                                                               
    return IsHuman(client)
        && GetClientTeam(client) == 3; 
}

bool IsHuman(int client)
{
    return IsClientInGame(client) && !IsFakeClient(client);
}
