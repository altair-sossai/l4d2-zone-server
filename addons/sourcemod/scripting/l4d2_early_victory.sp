#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <readyup>
#include <builtinvotes>
#include <colors>
#include <l4d2_hybrid_scoremod>

#define TRANSLATION_FILE "l4d2_early_victory.phrases"

#define VICTORY_SOUND "ui/pickup_secret01.wav"
#define SURRENDER_MIN_CHAPTER 2
#define SURRENDER_LIVE_DELAY 10.0

ConVar g_cvEnabled,
       g_cvChapter,
       g_cvMinDiff,
       g_cvVoteDuration,
       g_cvSlayDelay,
       g_cvChangeDelay;

bool g_bTriggered = false,
     g_bVoteResolved = false,
     g_bRoundOver = false;

bool g_bInitialQueueLocked = false;

Handle g_hVote = null,
       g_hCheckTimer = null,
       g_hCountdownTimer = null;

ConVar g_cvSurrenderEnabled, g_cvSurrenderCooldown, g_cvSurrenderPoints, g_cvSurrenderForceDelay,
       g_cvSurrenderSlayDelay;

enum SurrenderPhase
{
    Surrender_None,
    Surrender_WaitSlay,
    Surrender_WaitSecondRound,
    Surrender_WaitForceStart,
    Surrender_WaitLive,
    Surrender_WaitSecondSlay,
    Surrender_WaitRoundEnd,
    Surrender_WaitChange
}

SurrenderPhase g_SurrenderPhase = Surrender_None;
Handle g_hSurrenderTimer = null;
float g_flSurrenderDeadline;
float g_flSecondRoundStarted;
bool g_bSurrenderSecondHalf, g_bPreparingInfected = false;

bool g_bSurrenderVote = false, g_bEndingMatch = false, g_bApplyingScores = false;
float g_flLiveSince = -1.0, g_flNextSurrender[2];
int g_iSurrenderTeam = -1, g_iSurrenderRoster[MAXPLAYERS + 1],
    g_iFinalScores[2];

int g_iEligibleVoters = 0,
    g_iNextMapPick = -1,
    g_iCountdown = 0;

ArrayList g_hMapQueue = null;

char g_sOfficialFirstMaps[][] =
{
    "c1m1_hotel",
    "c2m1_highway",
    "c3m1_plankcountry",
    "c4m1_milltown_a",
    "c5m1_waterfront",
    "c8m1_apartment",
    "c10m1_caves",
    "c11m1_greenhouse",
    "c12m1_hilltop",
    "c13m1_alpinecreek",
};

char g_sOfficialCampaigns[][] =
{
    "Dead Center",
    "Dark Carnival",
    "Swamp Fever",
    "Hard Rain",
    "The Parish",
    "No Mercy",
    "Death Toll",
    "Dead Air",
    "Blood Harvest",
    "Cold Stream",
};

public Plugin myinfo =
{
    name = "L4D2 - Early Victory",
    author = "Altair Sossai",
    description = "Ends decided matches or team-approved surrenders and rotates campaigns",
    version = "1.7.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations(TRANSLATION_FILE);

    g_hMapQueue = new ArrayList();

    g_cvEnabled = CreateConVar("l4d2_early_victory_enabled", "1", "Enable/disable the early victory (skip last map when the game is already decided)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvChapter = CreateConVar("l4d2_early_victory_chapter", "4", "Chapter (map index) that triggers the early victory", FCVAR_NOTIFY, true, 1.0);
    g_cvMinDiff = CreateConVar("l4d2_early_victory_min_diff", "15", "Minimum score lead (scoring team over the already-played team) required to start the early victory vote", FCVAR_NOTIFY, true, 1.0);
    g_cvVoteDuration = CreateConVar("l4d2_early_victory_vote_duration", "15", "Duration in seconds of early victory and surrender votes", FCVAR_NOTIFY, true, 5.0);
    g_cvSlayDelay = CreateConVar("l4d2_early_victory_slay_delay", "5.0", "How many seconds after announcing the victory before slaying everyone", FCVAR_NOTIFY, true, 0.0);
    g_cvChangeDelay = CreateConVar("l4d2_early_victory_change_delay", "3.0", "How many seconds after slaying everyone before changing to a random campaign", FCVAR_NOTIFY, true, 0.0);

    g_cvSurrenderEnabled = CreateConVar("l4d2_surrender_enabled", "1", "Enable team surrender votes", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSurrenderCooldown = CreateConVar("l4d2_surrender_cooldown", "60.0", "Seconds between surrender attempts by the same campaign team", FCVAR_NOTIFY, true, 0.0);
    g_cvSurrenderPoints = CreateConVar("l4d2_surrender_points", "250", "Points awarded above the higher team score to the opponent", FCVAR_NOTIFY, true, 1.0, true, 100000.0);
    g_cvSurrenderForceDelay = CreateConVar("l4d2_surrender_forcestart_delay", "8.0", "Seconds after the second round starts before forcing live; minimum allows PlayStats to initialize teams", FCVAR_NOTIFY, true, 6.0);
    g_cvSurrenderSlayDelay = CreateConVar("l4d2_surrender_second_slay_delay", "3.0", "Seconds live in the automatic second round before slaying everyone", FCVAR_NOTIFY, true, 1.0);

    RegConsoleCmd("sm_surrender", Surrender_Cmd);
    RegConsoleCmd("sm_render", Surrender_Cmd);
    
    RegServerCmd("l4d2_early_victory_queue", InitialQueue_Cmd, "Appends a single official campaign name to the next-campaign queue (e.g. l4d2_early_victory_queue \"The Parish\"). Use one command per line in your config to build the ordered rotation. Ignored once the queue is locked");
    RegServerCmd("l4d2_early_victory_queue_lock", InitialQueueLock_Cmd, "Locks the initial queue so later l4d2_early_victory_queue calls are ignored. Call this once right after the last campaign in your config");

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event);

    AddCommandListener(CallVote_Listener, "callvote");
    AddCommandListener(SurrenderForceStart_Listener, "sm_forcestart");
    AddCommandListener(SurrenderForceStart_Listener, "sm_fs");

    RegAdminCmd("sm_early_victory_debug", Debug_Cmd, ADMFLAG_ROOT, "Shows Early Victory internal values (scores and bonus breakdown) for debugging");

    RegAdminCmd("sm_setnextcampaign", NextMapMenu_Cmd, ADMFLAG_CHANGEMAP, "Opens a menu to queue the next campaigns (or clear them all) instead of a random draw");
}

public void OnMapStart()
{
    g_bEndingMatch = false;
    g_SurrenderPhase = Surrender_None;
    g_iSurrenderTeam = -1;
    g_flLiveSince = -1.0;
    g_flNextSurrender[0] = 0.0;
    g_flNextSurrender[1] = 0.0;
    PrecacheSound(VICTORY_SOUND);
    RemoveCurrentMapFromQueue();
}

public void OnMapEnd()
{
    CancelActiveVote();
    KillCheckTimer();
    KillCountdownTimer();
    delete g_hSurrenderTimer;
    g_SurrenderPhase = Surrender_None;
    g_bEndingMatch = false;
    g_iSurrenderTeam = -1;
    g_flLiveSince = -1.0;
}

Action InitialQueue_Cmd(int args)
{
    if (g_bInitialQueueLocked)
        return Plugin_Handled;

    if (args < 1)
    {
        LogError("[Early Victory] Usage: l4d2_early_victory_queue <campaign name>");
        return Plugin_Handled;
    }

    char name[64];
    GetCmdArg(1, name, sizeof(name));
    TrimString(name);

    if (name[0] == '\0')
        return Plugin_Handled;

    int index = FindCampaignIndex(name);

    if (index < 0)
    {
        LogError("[Early Victory] Unknown campaign in l4d2_early_victory_queue: '%s'", name);
        return Plugin_Handled;
    }

    g_hMapQueue.Push(index);

    return Plugin_Handled;
}

Action InitialQueueLock_Cmd(int args)
{
    g_bInitialQueueLocked = true;

    return Plugin_Handled;
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    g_flLiveSince = -1.0;
    CancelActiveVote();
    if (g_bEndingMatch)
    {
        if (g_SurrenderPhase == Surrender_WaitSecondRound && InSecondHalfOfRound())
        {
            g_bRoundOver = false;
            g_bSurrenderSecondHalf = true;
            g_flSecondRoundStarted = GetGameTime();
            g_SurrenderPhase = Surrender_WaitForceStart;
            g_flSurrenderDeadline = GetGameTime() + g_cvSurrenderForceDelay.FloatValue;
            CPrintToChatAll("%t", "SurrenderForceStart", RoundToCeil(g_cvSurrenderForceDelay.FloatValue));
        }
        return;
    }

    g_bTriggered = false;
    g_bVoteResolved = false;
    g_bRoundOver = false;
    g_bSurrenderVote = false;
    g_iSurrenderTeam = -1;
    g_hVote = null;
    g_iEligibleVoters = 0;
    g_iNextMapPick = -1;
    g_iCountdown = 0;

    KillCheckTimer();
    KillCountdownTimer();
}

public void OnRoundIsLive()
{
    g_flLiveSince = GetGameTime();
    if (g_bEndingMatch)
    {
        if (g_SurrenderPhase == Surrender_WaitForceStart || g_SurrenderPhase == Surrender_WaitLive)
        {
            g_SurrenderPhase = Surrender_WaitSecondSlay;
            g_flSurrenderDeadline = GetGameTime() + g_cvSurrenderSlayDelay.FloatValue;
            if (g_flSurrenderDeadline < g_flSecondRoundStarted + 6.0)
                g_flSurrenderDeadline = g_flSecondRoundStarted + 6.0;
            RequestFrame(PrepareSurrenderInfected_Frame);
            CPrintToChatAll("%t", "SurrenderSecondLive", RoundToCeil(g_flSurrenderDeadline - GetGameTime()));
        }
        return;
    }
    if (g_hCheckTimer != null)
        return;

    CreateTimer(5.0, StartCheck_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnRoundLiveCountdown()
{
    if (g_SurrenderPhase == Surrender_WaitForceStart && GetGameTime() < g_flSurrenderDeadline)
        RequestFrame(CancelEarlySurrenderCountdown_Frame);
}

void CancelEarlySurrenderCountdown_Frame(any data)
{
    if (g_SurrenderPhase == Surrender_WaitForceStart && GetGameTime() < g_flSurrenderDeadline && IsInReady())
    {
        for (int client = 1; client <= MaxClients; client++)
        {
            if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) < L4D_TEAM_SURVIVOR)
                continue;

            FakeClientCommand(client, "sm_unready");
            break;
        }
    }
}

Action SurrenderForceStart_Listener(int client, const char[] command, int argc)
{
    if (g_SurrenderPhase == Surrender_WaitForceStart && GetGameTime() < g_flSurrenderDeadline)
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    if (g_SurrenderPhase != Surrender_None && !g_bRoundOver && g_flLiveSince >= 0.0 && !IsInReady())
        MaterializeSurrenderInfected();

    return Plugin_Continue;
}

public void L4D2_OnEndVersusModeRound_Post()
{
    g_bRoundOver = true;

    CancelActiveVote();

    KillCheckTimer();

    if (g_SurrenderPhase != Surrender_None && g_SurrenderPhase != Surrender_WaitChange)
    {
        if (g_bSurrenderSecondHalf)
        {
            g_SurrenderPhase = Surrender_WaitChange;
            // PlayStats writes the second half one second after round_end.
            g_flSurrenderDeadline = GetGameTime() + SurrenderChangeDelay();
            CPrintToChatAll("%t", "SurrenderSaving");
            RequestFrame(RestoreSurrenderScores_Frame);
        }
        else
        {
            g_SurrenderPhase = Surrender_WaitSecondRound;
            CPrintToChatAll("%t", "SurrenderSwitching");
        }
    }
}

// Match readyup.inc's scalar declaration; the reason is intentionally unused.
public void OnReadyCountdownCancelled(int client, char sDisruptReason)
{
    if (g_SurrenderPhase == Surrender_WaitLive)
    {
        g_SurrenderPhase = Surrender_WaitForceStart;
        g_flSurrenderDeadline = GetGameTime() + g_cvSurrenderForceDelay.FloatValue;
    }
}

Action CallVote_Listener(int client, const char[] command, int argc)
{
    if (g_bEndingMatch)
    {
        if (client > 0 && IsClientInGame(client))
            CPrintToChat(client, "%t", "MatchEnding");
        return Plugin_Handled;
    }

    if (!g_cvEnabled.BoolValue || client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || argc < 1)
        return Plugin_Continue;

    if (IsInReady() || !InSecondHalfOfRound() || L4D_GetCurrentChapter() != g_cvChapter.IntValue)
        return Plugin_Continue;

    char voteType[32];
    GetCmdArg(1, voteType, sizeof(voteType));

    if (!StrEqual(voteType, "ChangeMission", false))
        return Plugin_Continue;

    if (g_cvSurrenderEnabled.BoolValue && SurrenderRoundAllowed())
        CPrintToChat(client, "%t", "MapVoteSurrender");
    else
        CPrintToChat(client, "%t", "MapVoteBlocked");

    return Plugin_Handled;
}

Action StartCheck_Timer(Handle timer)
{
    if (g_hCheckTimer != null)
        return Plugin_Stop;

    if (!g_cvEnabled.BoolValue || g_bTriggered || g_bRoundOver || !L4D_HasMapStarted())
        return Plugin_Stop;

    if (IsInReady() || !InSecondHalfOfRound())
        return Plugin_Stop;

    if (L4D_GetCurrentChapter() != g_cvChapter.IntValue || L4D_IsMissionFinalMap())
        return Plugin_Stop;

    g_hCheckTimer = CreateTimer(5.0, Check_Timer, _, TIMER_REPEAT);

    return Plugin_Stop;
}

Action Check_Timer(Handle timer)
{
    if (!g_cvEnabled.BoolValue || g_bTriggered || g_bRoundOver || !L4D_HasMapStarted())
    {
        g_hCheckTimer = null;
        return Plugin_Stop;
    }

    if (IsTankInPlay() || IsAnySurvivorIncapacitated())
        return Plugin_Continue;

    int scoringScore = ScoringTeamScore();
    int alreadyPlayedScore = AlreadyPlayedTeamScore();

    int leadDiff = scoringScore - alreadyPlayedScore;
    bool scoringTeamTookTheLead = leadDiff >= g_cvMinDiff.IntValue;

    int losingTeam = 0;

    if (scoringTeamTookTheLead)
    {
        losingTeam = L4D_TEAM_INFECTED;
    }
    else
    {
        int deficitDiff = alreadyPlayedScore - ScoringTeamMaxScore();
        bool scoringTeamCanNoLongerWin = deficitDiff >= g_cvMinDiff.IntValue;

        if (scoringTeamCanNoLongerWin)
            losingTeam = L4D_TEAM_SURVIVOR;
    }

    if (losingTeam == 0)
        return Plugin_Continue;

    if (g_bEndingMatch || g_hVote != null || IsBuiltinVoteInProgress() || CheckBuiltinVoteDelay() > 0)
        return Plugin_Continue;

    if (!HasHumanOnLosingTeam(losingTeam))
        return Plugin_Continue;

    g_bTriggered = true;
    g_hCheckTimer = null;

    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "Decided", scoringScore, alreadyPlayedScore);
    StartContinueVote(losingTeam);

    return Plugin_Stop;
}

int CampaignTeam(int client)
{
    int survivorTeam = AreTeamsFlipped() ? 1 : 0;
    return GetClientTeam(client) == L4D_TEAM_SURVIVOR ? survivorTeam : 1 - survivorTeam;
}

bool SurrenderRoundAllowed()
{
    return L4D_GetCurrentChapter() >= SURRENDER_MIN_CHAPTER;
}

bool SurrenderReadyAvailable()
{
    ConVar readyMode = FindConVar("l4d_ready_enabled");
    ConVar autoReady = FindConVar("l4d_ready_autoready");
    return readyMode != null && (readyMode.IntValue == 1 || readyMode.IntValue == 3)
        && autoReady != null && !autoReady.BoolValue
        && GetCommandFlags("sm_forcestart") != INVALID_FCVAR_FLAGS
        && GetCommandFlags("sm_unready") != INVALID_FCVAR_FLAGS;
}

float SurrenderLiveTimeout()
{
    ConVar readyDelay = FindConVar("l4d_ready_delay");
    ConVar forceExtra = FindConVar("l4d_ready_force_extra");
    float timeout = 10.0;
    if (readyDelay != null)
        timeout += float(readyDelay.IntValue);
    if (forceExtra != null)
        timeout += float(forceExtra.IntValue);
    return timeout;
}

void CancelActiveVote()
{
    if (g_hVote != null && !g_bVoteResolved)
        CancelBuiltinVote();
}

public void OnClientDisconnect(int client)
{
    if (g_bSurrenderVote && g_iSurrenderRoster[client] != 0)
        CancelActiveVote();
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && g_bSurrenderVote && g_iSurrenderRoster[client] != 0
        && event.GetInt("oldteam") != event.GetInt("team"))
        CancelActiveVote();
}

Action Surrender_Cmd(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Handled;

    int team = GetClientTeam(client);
    if (team != L4D_TEAM_SURVIVOR && team != L4D_TEAM_INFECTED)
    {
        CPrintToChat(client, "%t", "SurrenderPlayersOnly");
        return Plugin_Handled;
    }

    if (!g_cvSurrenderEnabled.BoolValue || g_bEndingMatch || g_bRoundOver
        || !L4D_HasMapStarted() || IsInReady() || g_flLiveSince < 0.0)
    {
        CPrintToChat(client, "%t", "SurrenderUnavailable");
        return Plugin_Handled;
    }

    if (!SurrenderRoundAllowed())
    {
        CPrintToChat(client, "%t", "SurrenderTooEarly");
        return Plugin_Handled;
    }

    if (!InSecondHalfOfRound() && !SurrenderReadyAvailable())
    {
        CPrintToChat(client, "%t", "SurrenderReadyRequired");
        return Plugin_Handled;
    }

    float remaining = SURRENDER_LIVE_DELAY - (GetGameTime() - g_flLiveSince);
    if (remaining > 0.0)
    {
        CPrintToChat(client, "%t", "SurrenderWait", RoundToCeil(remaining));
        return Plugin_Handled;
    }

    int campaignTeam = CampaignTeam(client);
    remaining = g_flNextSurrender[campaignTeam] - GetGameTime();
    if (remaining > 0.0)
    {
        CPrintToChat(client, "%t", "SurrenderWait", RoundToCeil(remaining));
        return Plugin_Handled;
    }

    if (g_hVote != null || IsBuiltinVoteInProgress() || CheckBuiltinVoteDelay() > 0)
    {
        CPrintToChat(client, "%t", "SurrenderVoteBusy");
        return Plugin_Handled;
    }

    int[] players = new int[MaxClients];
    g_iEligibleVoters = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iSurrenderRoster[i] = 0;
        if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != team)
            continue;

        players[g_iEligibleVoters++] = i;
        g_iSurrenderRoster[i] = GetClientUserId(i);
    }

    g_hVote = CreateBuiltinVote(SurrenderVoteActionHandler, BuiltinVoteType_Custom_YesNo,
        BuiltinVoteAction_Cancel | BuiltinVoteAction_End);
    if (g_hVote == null)
    {
        CPrintToChat(client, "%t", "SurrenderVoteBusy");
        return Plugin_Handled;
    }

    g_iSurrenderTeam = campaignTeam;
    g_bSurrenderVote = true;
    g_bVoteResolved = false;

    char title[128];
    FormatEx(title, sizeof(title), "%T", "SurrenderVoteTitle", LANG_SERVER);
    SetBuiltinVoteArgument(g_hVote, title);
    SetBuiltinVoteInitiator(g_hVote, client);
    SetBuiltinVoteTeam(g_hVote, team);
    SetBuiltinVoteResultCallback(g_hVote, SurrenderVoteResultHandler);

    if (!DisplayBuiltinVote(g_hVote, players, g_iEligibleVoters, g_cvVoteDuration.IntValue))
    {
        delete g_hVote;
        g_bSurrenderVote = false;
        CPrintToChat(client, "%t", "SurrenderVoteBusy");
        return Plugin_Handled;
    }

    g_flNextSurrender[campaignTeam] = GetGameTime() + g_cvSurrenderCooldown.FloatValue;
    RequestFrame(SurrenderAutoVote_Frame, GetClientUserId(client));
    return Plugin_Handled;
}

void SurrenderAutoVote_Frame(any userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client)
        || !g_bSurrenderVote || g_bVoteResolved || g_hVote == null || g_bRoundOver
        || g_iSurrenderRoster[client] != userid)
        return;

    int team = GetClientTeam(client);
    if ((team == L4D_TEAM_SURVIVOR || team == L4D_TEAM_INFECTED) && CampaignTeam(client) == g_iSurrenderTeam)
        FakeClientCommand(client, "Vote Yes");
}

void SurrenderVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_Cancel:
        {
            if (!g_bVoteResolved)
            {
                g_bVoteResolved = true;
                g_flNextSurrender[g_iSurrenderTeam] = GetGameTime() + g_cvSurrenderCooldown.FloatValue;
                DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
                CPrintToChatAll("%t", "VoteCancelled");
            }
            g_bSurrenderVote = false;
        }
        case BuiltinVoteAction_End:
        {
            if (vote == g_hVote)
            {
                g_hVote = null;
                g_bSurrenderVote = false;
            }
            delete vote;
        }
    }
}

void SurrenderVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info,
    int num_items, const int[][] item_info)
{
    if (g_bVoteResolved || vote != g_hVote)
        return;

    int yesVotes = 0;
    for (int i = 0; i < num_clients; i++)
    {
        int client = client_info[i][BUILTINVOTEINFO_CLIENT_INDEX];
        if (client > 0 && client <= MaxClients && IsClientInGame(client)
            && g_iSurrenderRoster[client] == GetClientUserId(client)
            && CampaignTeam(client) == g_iSurrenderTeam
            && client_info[i][BUILTINVOTEINFO_CLIENT_ITEM] == BUILTINVOTES_VOTE_YES)
            yesVotes++;
    }

    g_bVoteResolved = true;
    g_bSurrenderVote = false;
    if (g_bRoundOver || g_bEndingMatch || IsInReady() || !SurrenderRoundAllowed()
        || !g_cvSurrenderEnabled.BoolValue || (!InSecondHalfOfRound() && !SurrenderReadyAvailable())
        || yesVotes * 2 <= g_iEligibleVoters)
    {
        g_flNextSurrender[g_iSurrenderTeam] = GetGameTime() + g_cvSurrenderCooldown.FloatValue;
        DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
        CPrintToChatAll("%t", "SurrenderRejected");
        return;
    }

    g_iFinalScores[0] = GetTeamAScore();
    g_iFinalScores[1] = GetTeamBScore();
    int opponent = 1 - g_iSurrenderTeam;
    int highest = g_iFinalScores[0] > g_iFinalScores[1] ? g_iFinalScores[0] : g_iFinalScores[1];
    g_iFinalScores[opponent] = highest + g_cvSurrenderPoints.IntValue;
    g_bEndingMatch = true;
    g_bTriggered = true;
    g_bSurrenderSecondHalf = InSecondHalfOfRound();
    g_SurrenderPhase = Surrender_WaitSlay;
    g_flSurrenderDeadline = GetGameTime() + g_cvSlayDelay.FloatValue;
    KillCheckTimer();
    ApplySurrenderScores();

    char message[128];
    FormatEx(message, sizeof(message), "%T", "SurrenderPassed", LANG_SERVER);
    DisplayBuiltinVotePass(vote, message);
    CPrintToChatAll("%t", "SurrenderResult", g_iFinalScores[g_iSurrenderTeam], g_iFinalScores[opponent]);
    g_iNextMapPick = PickNextMapIndex();
    EmitSoundToAll(VICTORY_SOUND);
    CPrintToChatAll("%t", "SurrenderClosing");
    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "NextMap", g_sOfficialCampaigns[g_iNextMapPick]);
    g_hSurrenderTimer = CreateTimer(1.0, SurrenderProgress_Timer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    MaterializeSurrenderInfected();
}

float SurrenderChangeDelay()
{
    return g_cvChangeDelay.FloatValue < 2.0 ? 2.0 : g_cvChangeDelay.FloatValue;
}

void RestoreSurrenderScores_Frame(any data)
{
    if (g_SurrenderPhase != Surrender_None)
        ApplySurrenderScores();
}

void PrepareSurrenderInfected_Frame(any data)
{
    if (g_SurrenderPhase != Surrender_None && !g_bRoundOver && !IsInReady())
        MaterializeSurrenderInfected();
}

void RetrySurrenderStart()
{
    LogError("[Early Victory] Surrender has not reached live. Check ReadyUp mode and commands; retrying in %.1f seconds.", g_cvSurrenderForceDelay.FloatValue);
    CPrintToChatAll("%t", "SurrenderStartRetry");
    g_SurrenderPhase = Surrender_WaitForceStart;
    g_flSurrenderDeadline = GetGameTime() + g_cvSurrenderForceDelay.FloatValue;
}

Action SurrenderProgress_Timer(Handle timer)
{
    if (g_SurrenderPhase == Surrender_None)
    {
        g_hSurrenderTimer = null;
        return Plugin_Stop;
    }

    float remaining = g_flSurrenderDeadline - GetGameTime();
    switch (g_SurrenderPhase)
    {
        case Surrender_WaitSlay, Surrender_WaitSecondSlay:
        {
            if (remaining <= 0.0 && !g_bRoundOver)
            {
                MaterializeSurrenderInfected();
                g_SurrenderPhase = g_bSurrenderSecondHalf ? Surrender_WaitRoundEnd : Surrender_WaitSecondRound;
                ServerCommand("sm_slay @all");
            }
        }
        case Surrender_WaitForceStart:
        {
            if (remaining <= 0.0)
            {
                if (IsInReady() && SurrenderReadyAvailable())
                {
                    g_SurrenderPhase = Surrender_WaitLive;
                    g_flSurrenderDeadline = GetGameTime() + SurrenderLiveTimeout();
                    ServerCommand("sm_forcestart");
                }
                else
                    RetrySurrenderStart();
            }
        }
        case Surrender_WaitLive:
        {
            if (remaining <= 0.0)
                RetrySurrenderStart();
        }
        case Surrender_WaitChange:
        {
            if (remaining <= 0.0)
            {
                ApplySurrenderScores();
                g_hSurrenderTimer = null;
                ChangeMap_Timer(null);
                return Plugin_Stop;
            }
        }
    }

    if (g_SurrenderPhase == Surrender_WaitChange)
        PrintHintTextToAll("%t", "CeremonyCountdown", g_sOfficialCampaigns[g_iNextMapPick], RoundToCeil(remaining));
    else
        PrintHintTextToAll("%t", "SurrenderClosing");

    return Plugin_Continue;
}

void MaterializeSurrenderInfected()
{
    if (g_bPreparingInfected)
        return;

    g_bPreparingInfected = true;
    // The API requires infected statistics, and PlayStats omits players with no spawns.
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != L4D_TEAM_INFECTED)
            continue;

        if (!IsPlayerAlive(client))
            L4D_RespawnPlayer(client);

        if (IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_isGhost") != 0)
            L4D_MaterializeFromGhost(client);
    }
    g_bPreparingInfected = false;
}

void ApplySurrenderScores()
{
    g_bApplyingScores = true;
    L4D2Direct_SetVSCampaignScore(0, g_iFinalScores[0]);
    L4D2Direct_SetVSCampaignScore(1, g_iFinalScores[1]);
    g_bApplyingScores = false;
}

public Action L4D_OnSetCampaignScores(int &scoreA, int &scoreB)
{
    if (g_SurrenderPhase == Surrender_None)
        return Plugin_Continue;

    scoreA = g_iFinalScores[0];
    scoreB = g_iFinalScores[1];
    return Plugin_Changed;
}

public void L4D_OnSetCampaignScores_Post(int scoreA, int scoreB)
{
    // Reapply through the native so PlayStats sees the final scores regardless of hook order.
    if (g_SurrenderPhase != Surrender_None && !g_bApplyingScores)
        ApplySurrenderScores();
}

Action Debug_Cmd(int client, int args)
{
    int scoringScore = ScoringTeamScore();
    int alreadyPlayedScore = AlreadyPlayedTeamScore();

    int campaign = L4D2Direct_GetVSCampaignScore(AreTeamsFlipped() ? 1 : 0);
    int maxCompletion = L4D_GetVersusMaxCompletionScore();

    int healthBonus = SMPlus_GetHealthBonus();
    int damageBonus = SMPlus_GetDamageBonus();
    int pillsBonus = SMPlus_GetPillsBonus();
    int currentBonus = healthBonus + damageBonus + pillsBonus;

    int teamSize = GetConVarInt(FindConVar("survivor_limit"));
    int maxPillsBonus = SMPlus_GetMaxPillsBonus();
    int pointsPerPill = teamSize > 0 ? maxPillsBonus / teamSize : 0;

    ConVar cvPillsLimit = FindConVar("confogl_pills_limit");
    int pillsLimit = cvPillsLimit != null ? cvPillsLimit.IntValue : -1;
    int pillsMargin = MapPillsBonusMargin();

    int maxScore = ScoringTeamMaxScore();

    int leadDiff = scoringScore - alreadyPlayedScore;
    int deficitDiff = alreadyPlayedScore - maxScore;

    bool scoringTeamTookTheLead = leadDiff >= g_cvMinDiff.IntValue;
    bool scoringTeamCanNoLongerWin = deficitDiff >= g_cvMinDiff.IntValue;

    ReplyToCommand(client, "===== Early Victory Debug =====");
    ReplyToCommand(client, "Chapter: %d (trigger: %d) | 2nd half: %d | InReady: %d | RoundOver: %d | Flipped: %d", L4D_GetCurrentChapter(), g_cvChapter.IntValue, InSecondHalfOfRound(), IsInReady(), g_bRoundOver, AreTeamsFlipped());
    ReplyToCommand(client, "Surrender phase: %d | campaign team: %d | ending: %d | live since: %.1f | final A/B: %d / %d", g_SurrenderPhase, g_iSurrenderTeam, g_bEndingMatch, g_flLiveSince, g_iFinalScores[0], g_iFinalScores[1]);
    ReplyToCommand(client, "Scoring team score: %d", scoringScore);
    ReplyToCommand(client, "Already-played team score: %d", alreadyPlayedScore);
    ReplyToCommand(client, "min_diff: %d", g_cvMinDiff.IntValue);
    ReplyToCommand(client, "--- Bonus (scoremod) ---");
    ReplyToCommand(client, "Health: %d | Damage: %d | Pills: %d => Current total: %d", healthBonus, damageBonus, pillsBonus, currentBonus);
    ReplyToCommand(client, "Max pills bonus: %d | Team size: %d | Points per pill: %d", maxPillsBonus, teamSize, pointsPerPill);
    ReplyToCommand(client, "confogl_pills_limit: %d => Map pills margin: %d", pillsLimit, pillsMargin);
    ReplyToCommand(client, "--- Max reachable (scoring team) ---");
    ReplyToCommand(client, "campaign(%d) + maxCompletion(%d) + currentBonus(%d) + pillsMargin(%d) = %d", campaign, maxCompletion, currentBonus, pillsMargin, maxScore);
    ReplyToCommand(client, "--- Verdict ---");
    ReplyToCommand(client, "leadDiff: %d => scoringTeamTookTheLead: %d", leadDiff, scoringTeamTookTheLead);
    ReplyToCommand(client, "deficitDiff: %d => scoringTeamCanNoLongerWin: %d", deficitDiff, scoringTeamCanNoLongerWin);
    ReplyToCommand(client, "===============================");

    return Plugin_Handled;
}

void KillCheckTimer()
{
    if (g_hCheckTimer == null)
        return;

    KillTimer(g_hCheckTimer);
    g_hCheckTimer = null;
}

void StartContinueVote(int losingTeam)
{
    g_bVoteResolved = false;
    g_bSurrenderVote = false;
    g_iEligibleVoters = 0;

    int[] players = new int[MaxClients];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != losingTeam)
            continue;

        players[g_iEligibleVoters++] = i;
    }

    if (g_iEligibleVoters == 0)
    {
        CPrintToChatAll("%t", "VoteEnd");
        ScheduleEarlyVictory();
        return;
    }

    g_hVote = CreateBuiltinVote(ContinueVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

    if (g_hVote == null)
    {
        ScheduleEarlyVictory();
        return;
    }

    char title[128];
    FormatEx(title, sizeof(title), "%T", "VoteTitle", LANG_SERVER);
    SetBuiltinVoteArgument(g_hVote, title);
    SetBuiltinVoteInitiator(g_hVote, BUILTINVOTES_SERVER_INDEX);
    SetBuiltinVoteResultCallback(g_hVote, ContinueVoteResultHandler);

    if (!DisplayBuiltinVote(g_hVote, players, g_iEligibleVoters, g_cvVoteDuration.IntValue))
    {
        CloseHandle(g_hVote);
        g_hVote = null;
        ScheduleEarlyVictory();
    }
}

void ContinueVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_End:
        {
            if (vote == g_hVote)
                g_hVote = null;

            CloseHandle(vote);
        }
        case BuiltinVoteAction_Cancel:
        {
            if (!g_bVoteResolved)
            {
                g_bVoteResolved = true;
                DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
                CPrintToChatAll("%t", "VoteCancelled");
            }
        }
    }
}

void ContinueVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    if (g_bVoteResolved)
        return;

    int yesVotes = 0;

    for (int i = 0; i < num_items; i++)
    {
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
        {
            yesVotes = item_info[i][BUILTINVOTEINFO_ITEM_VOTES];
            break;
        }
    }

    g_bVoteResolved = true;

    int noVotes = g_iEligibleVoters - yesVotes;
    if (noVotes * 2 > g_iEligibleVoters)
    {
        DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
        CPrintToChatAll("%t", "VoteEnd");
        ScheduleEarlyVictory();
        return;
    }

    char message[128];
    FormatEx(message, sizeof(message), "%T", "VoteContinue", LANG_SERVER);
    DisplayBuiltinVotePass(vote, message);
    CPrintToChatAll("%t", "VoteContinue");
}

void ScheduleEarlyVictory()
{
    g_bEndingMatch = true;
    g_iNextMapPick = PickNextMapIndex();

    PrecacheSound(VICTORY_SOUND);
    EmitSoundToAll(VICTORY_SOUND);

    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "NextMap", g_sOfficialCampaigns[g_iNextMapPick]);

    g_iCountdown = RoundToNearest(g_cvSlayDelay.FloatValue + g_cvChangeDelay.FloatValue);

    KillCountdownTimer();
    Countdown_Timer(null);
    g_hCountdownTimer = CreateTimer(1.0, Countdown_Timer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    CreateTimer(g_cvSlayDelay.FloatValue, Slay_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Countdown_Timer(Handle timer)
{
    if (g_iCountdown <= 0)
    {
        g_hCountdownTimer = null;
        return Plugin_Stop;
    }

    char hint[192];
    FormatEx(hint, sizeof(hint), "%T", "CeremonyCountdown", LANG_SERVER, g_sOfficialCampaigns[g_iNextMapPick], g_iCountdown);
    PrintHintTextToAll(hint);

    g_iCountdown--;

    return Plugin_Continue;
}

Action Slay_Timer(Handle timer)
{
    ServerCommand("sm_slay @all");

    CreateTimer(g_cvChangeDelay.FloatValue, ChangeMap_Timer, _, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Stop;
}

Action ChangeMap_Timer(Handle timer)
{
    KillCountdownTimer();

    if (g_iNextMapPick < 0)
        g_iNextMapPick = PickNextMapIndex();

    ServerCommand("changelevel %s", g_sOfficialFirstMaps[g_iNextMapPick]);

    return Plugin_Stop;
}

void KillCountdownTimer()
{
    if (g_hCountdownTimer == null)
        return;

    KillTimer(g_hCountdownTimer);
    g_hCountdownTimer = null;
}

int ScoringTeamScore()
{
    return AreTeamsFlipped() ? GetTeamBScore() : GetTeamAScore();
}

int AlreadyPlayedTeamScore()
{
    return AreTeamsFlipped() ? GetTeamAScore() : GetTeamBScore();
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

bool AreTeamsFlipped()
{
    return GameRules_GetProp("m_bAreTeamsFlipped") != 0;
}

bool InSecondHalfOfRound()
{
    return GameRules_GetProp("m_bInSecondHalfOfRound") != 0;
}

bool IsTankInPlay()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != L4D_TEAM_INFECTED || !IsPlayerAlive(i))
            continue;

        if (GetEntProp(i, Prop_Send, "m_zombieClass") == view_as<int>(L4D2ZombieClass_Tank))
            return true;
    }

    return false;
}

bool IsAnySurvivorIncapacitated()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != L4D_TEAM_SURVIVOR || !IsPlayerAlive(i))
            continue;

        if (GetEntProp(i, Prop_Send, "m_isIncapacitated") != 0)
            return true;
    }

    return false;
}

bool HasHumanOnLosingTeam(int losingTeam)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        if (GetClientTeam(i) == losingTeam)
            return true;
    }

    return false;
}

int ScoringTeamMaxScore()
{
    int campaign = L4D2Direct_GetVSCampaignScore(AreTeamsFlipped() ? 1 : 0);
    int currentBonus = SMPlus_GetHealthBonus() + SMPlus_GetDamageBonus() + SMPlus_GetPillsBonus();

    return campaign + L4D_GetVersusMaxCompletionScore() + currentBonus + MapPillsBonusMargin();
}

int MapPillsBonusMargin()
{
    int teamSize = GetConVarInt(FindConVar("survivor_limit"));
    if (teamSize <= 0)
        return 0;

    int maxPillsBonus = SMPlus_GetMaxPillsBonus();
    int currentPillsBonus = SMPlus_GetPillsBonus();

    int remainingPillsBonus = maxPillsBonus - currentPillsBonus;
    if (remainingPillsBonus <= 0)
        return 0;

    ConVar cvPillsLimit = FindConVar("confogl_pills_limit");
    int pillsLimit = cvPillsLimit != null ? cvPillsLimit.IntValue : -1;

    if (pillsLimit < 0)
        return remainingPillsBonus;

    int margin = pillsLimit * (maxPillsBonus / teamSize);

    return margin < remainingPillsBonus ? margin : remainingPillsBonus;
}

Action NextMapMenu_Cmd(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
        return Plugin_Handled;

    ShowNextMapMenu(client);

    return Plugin_Handled;
}

void ShowNextMapMenu(int client)
{
    Menu menu = new Menu(NextMapMenuHandler);

    char title[128];
    FormatEx(title, sizeof(title), "%T", "MenuTitle", client, g_hMapQueue.Length);
    menu.SetTitle(title);

    char info[8];
    for (int i = 0; i < sizeof(g_sOfficialCampaigns); i++)
    {
        IntToString(i, info, sizeof(info));
        menu.AddItem(info, g_sOfficialCampaigns[i]);
    }

    char clearLabel[64];
    FormatEx(clearLabel, sizeof(clearLabel), "%T", "MenuClear", client);
    menu.AddItem("clear", clearLabel);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int NextMapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "clear"))
            {
                g_hMapQueue.Clear();
                CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "QueueCleared");
            }
            else
            {
                int index = StringToInt(info);
                g_hMapQueue.Push(index);
                AnnounceQueue();
            }

            if (IsClientInGame(param1))
                ShowNextMapMenu(param1);
        }
        case MenuAction_End:
            delete menu;
    }

    return 0;
}

void AnnounceQueue()
{
    char list[512];

    for (int i = 0; i < g_hMapQueue.Length; i++)
    {
        int index = g_hMapQueue.Get(i);

        if (i > 0)
            StrCat(list, sizeof(list), "{default}, ");

        Format(list, sizeof(list), "%s{green}%s", list, g_sOfficialCampaigns[index]);
    }

    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "QueueList", list);
}

int PickNextMapIndex()
{
    while (g_hMapQueue.Length > 0)
    {
        int index = g_hMapQueue.Get(0);
        g_hMapQueue.Erase(0);

        if (index >= 0 && index < sizeof(g_sOfficialFirstMaps))
            return index;
    }

    return GetRandomInt(0, sizeof(g_sOfficialFirstMaps) - 1);
}

int FindCampaignIndex(const char[] name)
{
    for (int i = 0; i < sizeof(g_sOfficialCampaigns); i++)
        if (StrEqual(g_sOfficialCampaigns[i], name, false))
            return i;

    return -1;
}

void RemoveCurrentMapFromQueue()
{
    if (g_hMapQueue.Length == 0)
        return;

    int index = GetCurrentMapIndex();
    if (index < 0)
        return;

    for (int i = g_hMapQueue.Length - 1; i >= 0; i--)
        if (g_hMapQueue.Get(i) == index)
            g_hMapQueue.Erase(i);
}

int GetCurrentMapIndex()
{
    char currentMap[64];
    GetCurrentMap(currentMap, sizeof(currentMap));

    for (int i = 0; i < sizeof(g_sOfficialFirstMaps); i++)
        if (StrEqual(g_sOfficialFirstMaps[i], currentMap, false))
            return i;

    return -1;
}
