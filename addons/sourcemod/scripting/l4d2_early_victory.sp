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

#define ZOMBIECLASS_TANK 8

#define VICTORY_SOUND "ui/pickup_secret01.wav"

ConVar g_cvEnabled,
       g_cvChapter,
       g_cvMinDiff,
       g_cvVoteDuration,
       g_cvSlayDelay,
       g_cvChangeDelay;

bool g_bTriggered = false,
     g_bVoteResolved = false,
     g_bRoundOver = false;

Handle g_hVote = null,
       g_hCheckTimer = null,
       g_hCountdownTimer = null;

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
    description = "When a game is already decided on the 4th map, slays everyone, announces the victory and rotates to a random official campaign instead of playing the last map",
    version = "1.5.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations(TRANSLATION_FILE);

    g_hMapQueue = new ArrayList();

    g_cvEnabled = CreateConVar("l4d2_early_victory_enabled", "1", "Enable/disable the early victory (skip last map when the game is already decided)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvChapter = CreateConVar("l4d2_early_victory_chapter", "4", "Chapter (map index) that triggers the early victory", FCVAR_NOTIFY, true, 1.0);
    g_cvMinDiff = CreateConVar("l4d2_early_victory_min_diff", "15", "Minimum score lead (scoring team over the already-played team) required to start the early victory vote", FCVAR_NOTIFY, true, 1.0);
    g_cvVoteDuration = CreateConVar("l4d2_early_victory_vote_duration", "15", "How many seconds the losing team has to vote whether to continue playing", FCVAR_NOTIFY, true, 5.0);
    g_cvSlayDelay = CreateConVar("l4d2_early_victory_slay_delay", "5.0", "How many seconds after announcing the victory before slaying everyone", FCVAR_NOTIFY, true, 0.0);
    g_cvChangeDelay = CreateConVar("l4d2_early_victory_change_delay", "3.0", "How many seconds after slaying everyone before changing to a random campaign", FCVAR_NOTIFY, true, 0.0);

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);

    AddCommandListener(CallVote_Listener, "callvote");

    RegAdminCmd("sm_early_victory_debug", Debug_Cmd, ADMFLAG_ROOT, "Shows Early Victory internal values (scores and bonus breakdown) for debugging");

    RegAdminCmd("sm_setnextmap", NextMapMenu_Cmd, ADMFLAG_CHANGEMAP, "Opens a menu to queue the next campaigns (or clear them all) instead of a random draw");
}

public void OnMapStart()
{
    PrecacheSound(VICTORY_SOUND);
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    g_bTriggered = false;
    g_bVoteResolved = false;
    g_bRoundOver = false;
    g_hVote = null;
    g_iEligibleVoters = 0;
    g_iNextMapPick = -1;
    g_iCountdown = 0;

    KillCheckTimer();
    KillCountdownTimer();
}

public void OnRoundIsLive()
{
    if (g_hCheckTimer != null)
        return;

    CreateTimer(5.0, StartCheck_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void L4D2_OnEndVersusModeRound_Post()
{
    g_bRoundOver = true;

    KillCheckTimer();
}

Action CallVote_Listener(int client, const char[] command, int argc)
{
    if (!g_cvEnabled.BoolValue || client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || argc < 1)
        return Plugin_Continue;

    if (IsInReady() || !InSecondHalfOfRound() || L4D_GetCurrentChapter() != g_cvChapter.IntValue)
        return Plugin_Continue;

    char voteType[32];
    GetCmdArg(1, voteType, sizeof(voteType));

    if (!StrEqual(voteType, "ChangeMission", false))
        return Plugin_Continue;

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

    if (IsBuiltinVoteInProgress() || CheckBuiltinVoteDelay() > 0)
        return Plugin_Continue;

    if (!HasHumanOnLosingTeam(losingTeam))
        return Plugin_Continue;

    g_bTriggered = true;
    g_hCheckTimer = null;

    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "Decided", scoringScore, alreadyPlayedScore);
    StartContinueVote(losingTeam);

    return Plugin_Stop;
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

        if (GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK)
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
