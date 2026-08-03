#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <readyup>
#include <builtinvotes>
#include <colors>

#define TRANSLATION_FILE "l4d2_early_victory.phrases"

ConVar g_cvEnabled,
       g_cvChapter,
       g_cvVoteDuration,
       g_cvSlayDelay,
       g_cvChangeDelay;

bool g_bTriggered = false,
     g_bVoteResolved = false,
     g_bRoundOver = false;

Handle g_hVote = null;

int g_iEligibleVoters = 0;

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

public Plugin myinfo =
{
    name = "L4D2 - Early Victory",
    author = "Altair Sossai",
    description = "When a game is already decided on the 4th map, slays everyone, announces the victory and rotates to a random official campaign instead of playing the last map",
    version = "1.1.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations(TRANSLATION_FILE);

    g_cvEnabled = CreateConVar("l4d2_early_victory_enabled", "1", "Enable/disable the early victory (skip last map when the game is already decided)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvChapter = CreateConVar("l4d2_early_victory_chapter", "4", "Chapter (map index) that triggers the early victory", FCVAR_NOTIFY, true, 1.0);
    g_cvVoteDuration = CreateConVar("l4d2_early_victory_vote_duration", "15", "How many seconds the losing team has to vote whether to continue playing", FCVAR_NOTIFY, true, 5.0);
    g_cvSlayDelay = CreateConVar("l4d2_early_victory_slay_delay", "5.0", "How many seconds after announcing the victory before slaying everyone", FCVAR_NOTIFY, true, 0.0);
    g_cvChangeDelay = CreateConVar("l4d2_early_victory_change_delay", "3.0", "How many seconds after slaying everyone before changing to a random campaign", FCVAR_NOTIFY, true, 0.0);

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);

    CreateTimer(3.0, Check_Timer, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    g_bTriggered = false;
    g_bVoteResolved = false;
    g_bRoundOver = false;
    g_hVote = null;
    g_iEligibleVoters = 0;
}

public void OnMapEnd()
{
    g_bTriggered = false;
    g_bVoteResolved = false;
    g_hVote = null;
    g_iEligibleVoters = 0;
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    g_bRoundOver = false;
}

public void L4D2_OnEndVersusModeRound_Post()
{
    g_bRoundOver = true;
}

Action Check_Timer(Handle timer)
{
    if (!g_cvEnabled.BoolValue || g_bTriggered || !L4D_HasMapStarted())
        return Plugin_Continue;

    if (IsInReady())
        return Plugin_Continue;

    if (L4D_GetCurrentChapter() != g_cvChapter.IntValue || L4D_IsMissionFinalMap())
        return Plugin_Continue;

    if (!InSecondHalfOfRound())
        return Plugin_Continue;

    int scoringScore = ScoringTeamScore();
    int alreadyPlayedScore = AlreadyPlayedTeamScore();

    if (scoringScore <= alreadyPlayedScore)
        return Plugin_Continue;

    if (IsBuiltinVoteInProgress() || CheckBuiltinVoteDelay() > 0)
        return Plugin_Continue;

    if (!HasHumanOnLosingTeam())
        return Plugin_Continue;

    g_bTriggered = true;

    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "Decided", scoringScore, alreadyPlayedScore);
    StartContinueVote();

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
    char nextMap[64];
    PickRandomMap(nextMap, sizeof(nextMap));

    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "NextMap", nextMap);

    ServerCommand("changelevel %s", nextMap);

    return Plugin_Stop;
}

void PickRandomMap(char[] buffer, int maxlength)
{
    char currentMap[64];
    GetCurrentMap(currentMap, sizeof(currentMap));

    char currentCampaign[8];
    ExtractCampaignToken(currentMap, currentCampaign, sizeof(currentCampaign));

    int total = sizeof(g_sOfficialFirstMaps);
    int[] candidates = new int[total];
    int count = 0;

    char token[8];

    for (int i = 0; i < total; i++)
    {
        ExtractCampaignToken(g_sOfficialFirstMaps[i], token, sizeof(token));

        if (StrEqual(token, currentCampaign))
            continue;

        candidates[count++] = i;
    }

    int pick = candidates[GetRandomInt(0, count - 1)];

    strcopy(buffer, maxlength, g_sOfficialFirstMaps[pick]);
}

void ExtractCampaignToken(const char[] map, char[] buffer, int maxlength)
{
    buffer[0] = '\0';

    if (map[0] != 'c')
    {
        strcopy(buffer, maxlength, map);
        return;
    }

    int j = 0;
    buffer[j++] = 'c';

    int length = strlen(map);
    for (int i = 1; i < length && j < maxlength - 1; i++)
    {
        if (!IsCharNumeric(map[i]))
            break;

        buffer[j++] = map[i];
    }

    buffer[j] = '\0';
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

bool HasHumanOnLosingTeam()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        if (GetClientTeam(i) == L4D_TEAM_INFECTED)
            return true;
    }

    return false;
}

bool InSecondHalfOfRound()
{
    return GameRules_GetProp("m_bInSecondHalfOfRound") != 0;
}

void StartContinueVote()
{
    g_iEligibleVoters = 0;

    int[] players = new int[MaxClients];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != L4D_TEAM_INFECTED)
            continue;

        players[g_iEligibleVoters++] = i;
    }

    if (g_iEligibleVoters == 0)
    {
        CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "VoteEnd");
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
                CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "VoteCancelled");
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
        CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "VoteEnd");
        ScheduleEarlyVictory();
        return;
    }

    char message[128];
    FormatEx(message, sizeof(message), "%T", "VoteContinue", LANG_SERVER);
    DisplayBuiltinVotePass(vote, message);
    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "VoteContinue");
}

void ScheduleEarlyVictory()
{
    CreateTimer(g_cvSlayDelay.FloatValue, Slay_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}
