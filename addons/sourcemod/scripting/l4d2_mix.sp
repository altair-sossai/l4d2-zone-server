#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools_sound>
#include <l4d2util_constants>
#include <builtinvotes>
#include <colors>

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
       g_cvAdditionalPlayersAfterMix,
       g_cvKickSpecsBlockTime,
       g_cvAbandonBanTime,
       g_cvCaptainVoteDuration;

Menu g_mMixMenu;

StringMap g_smVoteResults,
          g_smSwapWhitelist,
          g_smPlayers,
          g_smAbandoners;

int g_iCurrentState = STATE_NO_MIX,
    g_iMixCallsCount = 0,
    g_iRequiredStartVotes = 0,
    g_iMaxVoteCount = 0,
    g_iPickCount = 0,
    g_iSurvivorsPick = 0;

float g_fMixEndedTime = 0.0;

char g_sCurrentMaxVotedCaptainAuthId[MAX_STR_LEN],
     g_sSurvivorCaptainAuthId[MAX_STR_LEN],
     g_sInfectedCaptainAuthId[MAX_STR_LEN];

bool g_bIsMixAllowed = false;

int g_iMixVoteEligible = 0;

bool g_bMixVoteResolved = true;

char g_sVoteSurvivorCaptainAuthId[MAX_STR_LEN],
     g_sVoteInfectedCaptainAuthId[MAX_STR_LEN];

Handle g_hMixStartedForward,
       g_hMixStoppedForward,
       g_hCaptainVoteTimer,
       g_hMixVote;

public Plugin myinfo =
{
    name = "L4D2 Mix Manager",
    author = "Luckylock (co-author: Altair Sossai)",
    description = "Provides ability to pick captains and teams through menus",
    version = "5.0.0",
    url = "https://github.com/LuckyServ/"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_mix.phrases");

    g_cvStartVotes = CreateConVar("l4d2_mix_start_votes", "2", "Number of votes required to start a mix", FCVAR_NOTIFY, true, 1.0, true, 8.0);
    g_cvAdditionalPlayersAfterMix = CreateConVar("l4d2_mix_additional_players_after_mix", "2", "Additional players required to vote after each mix starts before the game goes live (0 disables)", FCVAR_NOTIFY, true, 0.0);
    g_cvKickSpecsBlockTime = CreateConVar("l4d2_mix_kickspecs_block_time", "40", "Seconds after a mix ends during which sm_kickspecs stays blocked (0 disables)", FCVAR_NOTIFY, true, 0.0);
    g_cvAbandonBanTime = CreateConVar("l4d2_mix_abandon_ban_time", "30", "Minutes a player is banned when they abandon a mix for a second time (0 disables the ban)", FCVAR_NOTIFY, true, 0.0);
    g_cvCaptainVoteDuration = CreateConVar("l4d2_mix_captain_vote_duration", "20", "How many seconds the captain proposal vote stays open when a player starts a mix by name", FCVAR_NOTIFY, true, 5.0);
    g_iRequiredStartVotes = Clamp(g_cvStartVotes.IntValue, 1, Slots());

    RegConsoleCmd("sm_mix", Cmd_MixStart, "Mix command");
    RegAdminCmd("sm_stopmix", Cmd_MixStop, ADMFLAG_CHANGEMAP, "Mix command");

    AddCommandListener(PlayerJoinTeam_CallBack, "jointeam");
    AddCommandListener(PlayerSpectate_CallBack, "sm_spectate");
    AddCommandListener(PlayerSpectate_CallBack, "sm_spec");
    AddCommandListener(PlayerSpectate_CallBack, "sm_s");
    AddCommandListener(KickSpecs_CallBack, "sm_kickspecs");

    HookEvent("player_team", Event_PlayerTeam);

    g_smVoteResults = new StringMap();
    g_smSwapWhitelist = new StringMap();
    g_smPlayers = new StringMap();
    g_smAbandoners = new StringMap();
    g_hMixStartedForward = CreateGlobalForward("OnMixStarted", ET_Event);
    g_hMixStoppedForward = CreateGlobalForward("OnMixStopped", ET_Event);
    
    PrecacheSound("buttons/blip1.wav");
}

/* =============================================================================
 * SourceMod lifecycle callbacks
 * ========================================================================== */

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

    if (g_smAbandoners != null)
        g_smAbandoners.Clear();
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

public void OnClientDisconnect(int client)
{
    if (g_iCurrentState != STATE_NO_MIX && IsClientInPlayers(client))
    {
        HandleMixAbandon(client);
        StopMix();
    }
}

/* =============================================================================
 * Commands (sm_mix / sm_stopmix)
 * ========================================================================== */

Action Cmd_MixStart(int client, int args)
{
    if (TeamSize() == 1)
    {
        CPrintToChat(client, "%t %t", "MixTag", "UnavailableOneVsOne");
        return Plugin_Handled;
    }

    if (g_iCurrentState != STATE_NO_MIX)
    {
        CPrintToChat(client, "%t %t", "MixTag", "AlreadyStarted");
        return Plugin_Handled;
    } 
    
    if (!g_bIsMixAllowed || !IsNewGame())
    {
        CPrintToChat(client, "%t %t", "MixTag", "NotAllowedLive");
        return Plugin_Handled;
    }

    if (g_hMixVote != null)
    {
        CPrintToChat(client, "%t %t", "MixTag", "MixVoteInProgress");
        return Plugin_Handled;
    }

    if (args >= 1 && GetAdminFlag(GetUserAdmin(client), Admin_Changemap))
    {
        char survivorAuthId[MAX_STR_LEN];
        char infectedAuthId[MAX_STR_LEN];

        if (args >= 2)
        {
            if (!ValidateCaptainPair(client, survivorAuthId, infectedAuthId, MAX_STR_LEN))
                return Plugin_Handled;

            CPrintToChatAll("%t %t", "MixTag", "StartedByAdmin", client);
            StartMixWithCaptains(survivorAuthId, infectedAuthId);

            return Plugin_Handled;
        }

        if (!ResolveCaptainByName(client, 1, survivorAuthId, MAX_STR_LEN))
            return Plugin_Handled;

        if (!SavePlayers())
        {
            CPrintToChat(client, "%t %t", "MixTag", "JoinTeams");
            return Plugin_Handled;
        }

        CPrintToChatAll("%t %t", "MixTag", "StartedByAdmin", client);

        BeginMix();

        if (AssignFirstCaptain(survivorAuthId, 0))
            StartCaptainVote();

        return Plugin_Handled;
    }

    if (GetClientTeam(client) == L4D2Team_Spectator && !GetAdminFlag(GetUserAdmin(client), Admin_Changemap))
    {
        CPrintToChat(client, "%t %t", "MixTag", "SpectatorCannotStart");
        return Plugin_Handled;
    }

    if (args >= 2)
    {
        char survivorAuthId[MAX_STR_LEN];
        char infectedAuthId[MAX_STR_LEN];

        if (!ValidateCaptainPair(client, survivorAuthId, infectedAuthId, MAX_STR_LEN))
            return Plugin_Handled;

        StartCaptainProposalVote(client, survivorAuthId, infectedAuthId);
        return Plugin_Handled;
    }

    int mixConditions = GetMixConditionsAfterVote(client);

    if (mixConditions == COND_START_MIX || mixConditions == COND_START_MIX_ADMIN)
    {
        if (mixConditions == COND_START_MIX_ADMIN)
            CPrintToChatAll("%t %t", "MixTag", "StartedByAdmin", client);
        else
        {
            CPrintToChatAll("%t %t", "MixTag", "VoteCast", client);
            CPrintToChatAll("%t %t", "MixTag", "StartedByVote");
        }

        BeginMix();
        StartCaptainVote();
    }
    else if (mixConditions == COND_NEED_MORE_VOTES)
        CPrintToChatAll("%t %t", "MixTag", "VoteProgress", client, g_iRequiredStartVotes - g_iMixCallsCount);
    else if (mixConditions == COND_HAS_ALREADY_VOTED)
        CPrintToChat(client, "%t %t", "MixTag", "AlreadyVoted");
    else if (mixConditions == COND_NO_PLAYERS)
        CPrintToChat(client, "%t %t", "MixTag", "JoinTeams");

    return Plugin_Handled;
}

Action Cmd_MixStop(int client, int args)
{
    if (g_iCurrentState != STATE_NO_MIX)
    {
        StopMix();
        CPrintToChatAll("%t %t", "MixTag", "StoppedByAdmin", client);
    }
    else
        CPrintToChat(client, "%t %t", "MixTag", "NotStarted");
    return Plugin_Handled;
}

bool ResolveCaptainByName(int client, int argIndex, char[] authId, int maxlen)
{
    char name[MAX_STR_LEN];
    GetCmdArg(argIndex, name, sizeof(name));

    int target = FindTarget(client, name, true, false);

    if (target <= 0)
        return false;

    if (!IsSurvivor(target) && !IsInfected(target))
    {
        CPrintToChat(client, "%t %t", "MixTag", "CaptainNotPlaying", target);
        return false;
    }

    GetClientAuthId(target, AuthId_SteamID64, authId, maxlen);

    return true;
}

bool ValidateCaptainPair(int client, char[] survivorAuthId, char[] infectedAuthId, int maxlen)
{
    if (!ResolveCaptainByName(client, 1, survivorAuthId, maxlen))
        return false;

    if (!ResolveCaptainByName(client, 2, infectedAuthId, maxlen))
        return false;

    if (StrEqual(survivorAuthId, infectedAuthId))
    {
        CPrintToChat(client, "%t %t", "MixTag", "SameCaptainTwice");
        return false;
    }

    if (!SavePlayers())
    {
        CPrintToChat(client, "%t %t", "MixTag", "JoinTeams");
        return false;
    }

    return true;
}

/* =============================================================================
 * Mix start / stop
 * ========================================================================== */

void BeginMix()
{
    g_iCurrentState = STATE_FIRST_CAPT;
    StartMix();

    g_smSwapWhitelist.Clear();
    SwapAllPlayersToSpec();

    g_iMixCallsCount = 0;
    g_smVoteResults.Clear();
    g_iMaxVoteCount = 0;
    strcopy(g_sCurrentMaxVotedCaptainAuthId, MAX_STR_LEN, " ");
    g_iPickCount = 0;
}

void StartCaptainVote()
{
    if (Menu_Initialise())
    {
        Menu_AddAllSpectators();
        Menu_DisplayToAllSpecs();
    }

    g_hCaptainVoteTimer = CreateTimer(11.0, Menu_StateHandler, _, TIMER_REPEAT);
}

void StartMixWithCaptains(const char[] survivorAuthId, const char[] infectedAuthId)
{
    BeginMix();

    if (AssignFirstCaptain(survivorAuthId, 0))
        AssignSecondCaptain(infectedAuthId, 0);
}

void StartCaptainProposalVote(int client, const char[] survivorAuthId, const char[] infectedAuthId)
{
    int[] players = new int[MaxClients];
    g_iMixVoteEligible = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsSurvivor(i) || IsInfected(i))
            players[g_iMixVoteEligible++] = i;
    }

    g_hMixVote = CreateBuiltinVote(MixVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

    if (g_hMixVote == null)
        return;

    int survivor = GetClientFromAuthId(survivorAuthId);
    int infected = GetClientFromAuthId(infectedAuthId);

    char survivorName[MAX_NAME_LENGTH];
    char infectedName[MAX_NAME_LENGTH];
    GetClientName(survivor, survivorName, sizeof(survivorName));
    GetClientName(infected, infectedName, sizeof(infectedName));

    char title[128];
    FormatEx(title, sizeof(title), "%T", "CaptainVoteTitle", LANG_SERVER, survivorName, infectedName);
    SetBuiltinVoteArgument(g_hMixVote, title);
    SetBuiltinVoteInitiator(g_hMixVote, BUILTINVOTES_SERVER_INDEX);
    SetBuiltinVoteResultCallback(g_hMixVote, MixVoteResultHandler);

    strcopy(g_sVoteSurvivorCaptainAuthId, MAX_STR_LEN, survivorAuthId);
    strcopy(g_sVoteInfectedCaptainAuthId, MAX_STR_LEN, infectedAuthId);
    g_bMixVoteResolved = false;

    if (!DisplayBuiltinVote(g_hMixVote, players, g_iMixVoteEligible, g_cvCaptainVoteDuration.IntValue))
    {
        CloseHandle(g_hMixVote);
        g_hMixVote = null;
        ResetMixVote();
    }
}

void MixVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_End:
        {
            if (vote == g_hMixVote)
                g_hMixVote = null;

            CloseHandle(vote);
        }

        case BuiltinVoteAction_Cancel:
        {
            if (!g_bMixVoteResolved)
            {
                g_bMixVoteResolved = true;
                DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
            }
        }
    }
}

bool AreCaptainsAndTeamsReady(const char[] survivorAuthId, const char[] infectedAuthId)
{
    int survivor = GetClientFromAuthId(survivorAuthId);
    int infected = GetClientFromAuthId(infectedAuthId);

    if (survivor <= 0 || infected <= 0)
        return false;

    if (!IsSurvivor(survivor) && !IsInfected(survivor))
        return false;

    if (!IsSurvivor(infected) && !IsInfected(infected))
        return false;

    return SavePlayers();
}

void MixVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    if (g_bMixVoteResolved)
        return;

    g_bMixVoteResolved = true;

    int yesVotes = 0;

    for (int i = 0; i < num_items; i++)
    {
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
        {
            yesVotes = item_info[i][BUILTINVOTEINFO_ITEM_VOTES];
            break;
        }
    }

    if (yesVotes * 2 <= g_iMixVoteEligible)
    {
        DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
        CPrintToChatAll("%t %t", "MixTag", "CaptainVoteFailed");
        return;
    }

    char survivorAuthId[MAX_STR_LEN];
    char infectedAuthId[MAX_STR_LEN];
    strcopy(survivorAuthId, MAX_STR_LEN, g_sVoteSurvivorCaptainAuthId);
    strcopy(infectedAuthId, MAX_STR_LEN, g_sVoteInfectedCaptainAuthId);

    if (!AreCaptainsAndTeamsReady(survivorAuthId, infectedAuthId))
    {
        DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
        CPrintToChatAll("%t %t", "MixTag", "CaptainVotePlayerLeft");
        return;
    }

    char message[128];
    FormatEx(message, sizeof(message), "%T", "CaptainVotePass", LANG_SERVER);
    DisplayBuiltinVotePass(vote, message);

    CPrintToChatAll("%t %t", "MixTag", "StartedByVote");
    StartMixWithCaptains(survivorAuthId, infectedAuthId);
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
    if (g_iCurrentState != STATE_NO_MIX)
        g_fMixEndedTime = GetEngineTime();

    g_iCurrentState = STATE_NO_MIX;
    FakeClientCommandAll("sm_show");
    Call_StartForward(g_hMixStoppedForward);
    Call_Finish();

    Handle captainVoteTimer = g_hCaptainVoteTimer;

    g_hCaptainVoteTimer = null;

    if (captainVoteTimer != null)
        KillTimer(captainVoteTimer);

    g_iMixCallsCount = 0;

    if (g_smVoteResults != null)
        g_smVoteResults.Clear();

    if (g_smSwapWhitelist != null)
        g_smSwapWhitelist.Clear();

    ResetMixVote();
}

void ResetMixVote()
{
    g_bMixVoteResolved = true;

    if (g_hMixVote != null)
    {
        g_hMixVote = null;

        if (IsBuiltinVoteInProgress())
            CancelBuiltinVote();
    }

    g_iMixVoteEligible = 0;
    strcopy(g_sVoteSurvivorCaptainAuthId, MAX_STR_LEN, "");
    strcopy(g_sVoteInfectedCaptainAuthId, MAX_STR_LEN, "");
}

void ResetMixVoteProgress()
{
    g_iMixCallsCount = 0;
    g_iRequiredStartVotes = Clamp(g_cvStartVotes.IntValue, 1, Slots());

    if (g_smVoteResults != null)
        g_smVoteResults.Clear();
}

void IncreaseRequiredStartVotes()
{
    g_iRequiredStartVotes = Clamp(g_iRequiredStartVotes + g_cvAdditionalPlayersAfterMix.IntValue, 1, Slots());
}

void HandleMixAbandon(int client)
{
    char authId[MAX_STR_LEN];
    char ip[64];
    int banTime = g_cvAbandonBanTime.IntValue;

    if (banTime <= 0 || !GetClientAuthId(client, AuthId_SteamID64, authId, MAX_STR_LEN))
    {
        CPrintToChatAll("%t %t", "MixTag", "PlayerLeft", client);
        return;
    }

    bool dummy;

    if (!g_smAbandoners.GetValue(authId, dummy))
    {
        g_smAbandoners.SetValue(authId, true);
        CPrintToChatAll("%t %t", "MixTag", "PlayerLeftWarning", client, banTime);
        return;
    }

    bool hasIp = GetClientIP(client, ip, sizeof(ip));

    BanClient(client, banTime, BANFLAG_AUTHID, "Abandoned the mix", "Abandoned the mix", "l4d2_mix");

    if (hasIp)
        BanIdentity(ip, banTime, BANFLAG_IP, "Abandoned the mix", "l4d2_mix");

    CPrintToChatAll("%t %t", "MixTag", "PlayerLeftBan", client, banTime);
}

/* =============================================================================
 * Start vote counting
 * ========================================================================== */

int GetMixConditionsAfterVote(int client)
{
    bool dummy = false;
    char clientAuthId[MAX_STR_LEN];
    GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
    bool hasVoted = g_smVoteResults.GetValue(clientAuthId, dummy);

    if (!SavePlayers())
        return COND_NO_PLAYERS;

    if (GetAdminFlag(GetUserAdmin(client), Admin_Changemap))
        return COND_START_MIX_ADMIN;
    else if (hasVoted)
        return COND_HAS_ALREADY_VOTED;
    else if (++g_iMixCallsCount >= g_iRequiredStartVotes)
        return COND_START_MIX; 
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
            GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
        else if (IsInfected(client))
            GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);

        if (IsSurvivor(client) || IsInfected(client))
            g_smPlayers.SetValue(clientAuthId, true);
    }

    return g_smPlayers.Size == Slots();
}

/* =============================================================================
 * Captain & team picking (state machine)
 * ========================================================================== */

bool AssignFirstCaptain(const char[] authId, int numVotes)
{
    if (SwapPlayerToTeam(authId, L4D2Team_Survivor, numVotes))
    {
        strcopy(g_sSurvivorCaptainAuthId, MAX_STR_LEN, authId);
        g_iCurrentState = STATE_SECOND_CAPT;
        return true;
    }

    CPrintToChatAll("%t %t", "MixTag", "FirstCaptainNotFound");
    StopMix();
    return false;
}

bool AssignSecondCaptain(const char[] authId, int numVotes)
{
    if (SwapPlayerToTeam(authId, L4D2Team_Infected, numVotes))
    {
        strcopy(g_sInfectedCaptainAuthId, MAX_STR_LEN, authId);
        g_iCurrentState = STATE_PICK_TEAMS;
        CreateTimer(0.5, Menu_StateHandler);
        return true;
    }

    CPrintToChatAll("%t %t", "MixTag", "SecondCaptainNotFound");
    StopMix();
    return false;
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

            if (AssignFirstCaptain(g_sCurrentMaxVotedCaptainAuthId, numVotes))
            {
                g_iMaxVoteCount = 0;

                if (Menu_Initialise())
                {
                    Menu_AddAllSpectators();
                    Menu_DisplayToAllSpecs();
                }
            }

            strcopy(g_sCurrentMaxVotedCaptainAuthId, MAX_STR_LEN, " ");
        }

        case STATE_SECOND_CAPT:
        {
            int numVotes = 0;
            g_smVoteResults.GetValue(g_sCurrentMaxVotedCaptainAuthId, numVotes);
            g_smVoteResults.Clear();

            AssignSecondCaptain(g_sCurrentMaxVotedCaptainAuthId, numVotes);

            strcopy(g_sCurrentMaxVotedCaptainAuthId, MAX_STR_LEN, " ");
        }

        case STATE_PICK_TEAMS:
        {
            g_iSurvivorsPick = GetURandomInt() & 1;
            CreateTimer(1.0, Menu_TeamPickHandler, _, TIMER_REPEAT);
        }
    }

    if (g_iCurrentState == STATE_NO_MIX || g_iCurrentState == STATE_PICK_TEAMS)
    {
        if (timer == g_hCaptainVoteTimer)
            g_hCaptainVoteTimer = null;

        return Plugin_Stop; 
    }
    else
        return Plugin_Handled;
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
               captain = GetClientFromAuthId(g_sSurvivorCaptainAuthId);
            else
               captain = GetClientFromAuthId(g_sInfectedCaptainAuthId);

            if (captain > 0)
            {
                if (GetSpectatorsCount() > 0)
                {
                    if (g_mMixMenu.ItemCount == 1)
                    {
                        char lastAuthId[MAX_STR_LEN];
                        g_mMixMenu.GetItem(0, lastAuthId, MAX_STR_LEN);
                        ProcessTeamPick(captain, lastAuthId);
                    }
                    else
                        g_mMixMenu.Display(captain, 1);
                }
                else
                {
                    CPrintToChatAll("%t %t", "MixTag", "NoSpectators");
                    StopMix();
                    return Plugin_Stop;
                }
            }
            else
            {
                CPrintToChatAll("%t %t", "MixTag", "CaptainNotFound");
                StopMix();
                return Plugin_Stop;
            }

            return Plugin_Continue;
        }
    }
    return Plugin_Stop;
}

void ProcessTeamPick(int captain, const char[] authId)
{
    int team = GetClientTeamEx(captain);

    if (team == L4D2Team_Spectator || (team == L4D2Team_Infected && g_iSurvivorsPick == 1) || (team == L4D2Team_Survivor && g_iSurvivorsPick == 0))
    {
        CPrintToChatAll("%t %t", "MixTag", "CaptainWrongTeam", captain);
        StopMix();
        return;
    }

    if (SwapPlayerToTeam(authId, team, 0))
    {
        int requiredPicks = Slots() - 2;
        g_iPickCount++;
        if (g_iPickCount >= requiredPicks)
        {
            CPrintToChatAll("%t %t", "MixTag", "TeamsPicked");
            IncreaseRequiredStartVotes();
            StopMix();
        }
        else if (g_iPickCount != requiredPicks - 2)
            g_iSurvivorsPick = g_iSurvivorsPick == 1 ? 0 : 1;
    }
    else
    {
        CPrintToChatAll("%t %t", "MixTag", "PickedMemberNotFound");
        StopMix();
    }
}

int Menu_MixHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Display)
    {
        char title[128];

        switch (g_iCurrentState)
        {
            case STATE_FIRST_CAPT:
                FormatEx(title, sizeof(title), "%T", "MenuPickFirstCaptain", param1);

            case STATE_SECOND_CAPT:
                FormatEx(title, sizeof(title), "%T", "MenuPickSecondCaptain", param1);

            case STATE_PICK_TEAMS:
                FormatEx(title, sizeof(title), "%T", "MenuPickTeamMembers", param1);
        }

        Panel panel = view_as<Panel>(param2);
        panel.SetTitle(title);
    }
    else if (action == MenuAction_Select)
    {
        if (g_iCurrentState == STATE_FIRST_CAPT || g_iCurrentState == STATE_SECOND_CAPT)
        {
            char authId[MAX_STR_LEN];
            menu.GetItem(param2, authId, MAX_STR_LEN);

            int candidate = GetClientFromAuthId(authId);

            if (candidate > 0)
                CPrintToChatAll("%t %t", "MixTag", "CaptainVoteCast", param1, candidate);

            int voteCount = 0;

            if (!g_smVoteResults.GetValue(authId, voteCount))
                voteCount = 0;

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
            ProcessTeamPick(param1, authId);
        }
    }

    return 0;
}

/* =============================================================================
 * Menu building
 * ========================================================================== */

bool Menu_Initialise()
{
    if (g_iCurrentState == STATE_NO_MIX) return false;

    delete g_mMixMenu;

    g_mMixMenu = new Menu(Menu_MixHandler, MENU_ACTIONS_ALL);
    g_mMixMenu.ExitButton = false;

    switch(g_iCurrentState)
    {
        case STATE_FIRST_CAPT:
        {
            g_mMixMenu.SetTitle("%T", "MenuPickFirstCaptain", LANG_SERVER);
            return true;
        }

        case STATE_SECOND_CAPT:
        {
            g_mMixMenu.SetTitle("%T", "MenuPickSecondCaptain", LANG_SERVER);
            return true;
        }

        case STATE_PICK_TEAMS:
        {
            g_mMixMenu.SetTitle("%T", "MenuPickTeamMembers", LANG_SERVER);
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

void Menu_DisplayToAllSpecs()
{
    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientSpec(client) && IsClientInPlayers(client))
            g_mMixMenu.Display(client, 10);
    }
}

/* =============================================================================
 * Team-change enforcement
 * ========================================================================== */

Action PlayerJoinTeam_CallBack(int client, const char[] command, int argc)
{
    if (g_iCurrentState == STATE_NO_MIX || argc < 1 || !IsHuman(client))
        return Plugin_Continue;

    char cmdArgBuffer[MAX_STR_LEN];
    GetCmdArg(1, cmdArgBuffer, MAX_STR_LEN);
    int newTeam = StringToInt(cmdArgBuffer);

    if (newTeam != GetExpectedTeam(client))
    {
        if (newTeam != L4D2Team_Spectator)
            CPrintToChat(client, "%t %t", "MixTag", "JoinWithoutPick");

        return Plugin_Stop;
    }

    return Plugin_Continue;
}

Action PlayerSpectate_CallBack(int client, const char[] command, int argc)
{
    if (g_iCurrentState == STATE_NO_MIX || !IsHuman(client))
        return Plugin_Continue;

    if (GetExpectedTeam(client) != L4D2Team_Spectator)
        return Plugin_Stop;

    return Plugin_Continue;
}

Action KickSpecs_CallBack(int client, const char[] command, int argc)
{
    if (client == 0 || !IsHuman(client))
        return Plugin_Continue;

    if (g_iCurrentState != STATE_NO_MIX)
    {
        CPrintToChat(client, "%t %t", "MixTag", "KickSpecsDuringMix");
        return Plugin_Handled;
    }

    float blockTime = g_cvKickSpecsBlockTime.FloatValue;

    if (blockTime <= 0.0 || g_fMixEndedTime <= 0.0)
        return Plugin_Continue;

    float elapsed = GetEngineTime() - g_fMixEndedTime;

    if (elapsed < blockTime)
    {
        CPrintToChat(client, "%t %t", "MixTag", "KickSpecsCooldown", RoundToCeil(blockTime - elapsed));
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (g_iCurrentState == STATE_NO_MIX || GetEventBool(event, "disconnect"))
        return;

    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (client < 1 || !IsHuman(client))
        return;

    if (GetEventInt(event, "team") != GetExpectedTeam(client))
        RequestFrame(Frame_EnforceTeam, GetEventInt(event, "userid"));
}

void Frame_EnforceTeam(any userId)
{
    if (g_iCurrentState == STATE_NO_MIX)
        return;

    int client = GetClientOfUserId(userId);

    if (client < 1 || !IsHuman(client))
        return;

    int expectedTeam = GetExpectedTeam(client);

    if (GetClientTeam(client) != expectedTeam)
        ChangeClientTeamEx(client, expectedTeam);
}

int GetExpectedTeam(int client)
{
    char authId[MAX_STR_LEN];
    int assignedTeam;

    GetClientAuthId(client, AuthId_SteamID64, authId, MAX_STR_LEN);

    if (g_smSwapWhitelist.GetValue(authId, assignedTeam))
        return assignedTeam;

    return L4D2Team_Spectator;
}

/* =============================================================================
 * Team / player manipulation
 * ========================================================================== */

void SwapAllPlayersToSpec()
{
    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
            ChangeClientTeamEx(client, L4D2Team_Spectator);
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
                if (numVotes > 0)
                    CPrintToChatAll("%t %t", "MixTag", "FirstCaptain", client, numVotes);
                else
                    CPrintToChatAll("%t %t", "MixTag", "FirstCaptainNoVotes", client);
            }

            case STATE_SECOND_CAPT:
            {
                if (numVotes > 0)
                    CPrintToChatAll("%t %t", "MixTag", "SecondCaptain", client, numVotes);
                else
                    CPrintToChatAll("%t %t", "MixTag", "SecondCaptainNoVotes", client);
            }

            case STATE_PICK_TEAMS:
            {
                if (g_iSurvivorsPick == 1)
                    CPrintToChatAll("%t %t", "MixTag", "PickedSurvivors", client);
                else
                    CPrintToChatAll("%t %t", "MixTag", "PickedInfected", client);
            }
        }
    }

    return foundClient;
}

bool ChangeClientTeamEx(int client, int team)
{
    if (GetClientTeamEx(client) == team)
        return true;

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

int FindSurvivorBot()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && IsFakeClient(client) && GetClientTeamEx(client) == L4D2Team_Survivor)
            return client;
    }
    return -1;
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
                client = i;
        }
    }

    return client;
}

/* =============================================================================
 * Helpers / predicates
 * ========================================================================== */

void FakeClientCommandAll(const char[] command)
{
    for (int client = 1; client <= MaxClients; ++client)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
            FakeClientCommand(client, command);
    }
}

bool IsClientInPlayers(int client)
{
    bool dummy;
    char clientAuthId[MAX_STR_LEN];
    GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
    return g_smPlayers.GetValue(clientAuthId, dummy);
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
            ++count;
    }

    return count;
}

int GetClientTeamEx(int client)
{
    return GetClientTeam(client);
}

int Clamp(int value, int minimum, int maximum)
{
    if (value < minimum)
        return minimum;

    if (value > maximum)
        return maximum;

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

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0
        && L4D2Direct_GetVSCampaignScore(1) == 0;
}