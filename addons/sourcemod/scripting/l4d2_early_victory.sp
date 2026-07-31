#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define TRANSLATION_FILE "l4d2_early_victory.phrases"

ConVar g_cvEnabled;
ConVar g_cvChapter;
ConVar g_cvSlayDelay;
ConVar g_cvChangeDelay;

bool g_bTriggered = false;

char g_sOfficialFirstMaps[][] =
{
    "c1m1_hotel",
    "c2m1_highway",
    "c3m1_plankcountry",
    "c4m1_milltown_a",
    "c5m1_waterfront",
    "c6m1_riverbank",
    "c7m1_docks",
    "c8m1_apartment",
    "c9m1_alleys",
    "c10m1_caves",
    "c11m1_greenhouse",
    "c12m1_hilltop",
    "c13m1_alpinecreek",
    "c14m1_junkyard"
};

public Plugin myinfo =
{
    name = "L4D2 - Early Victory",
    author = "Altair Sossai",
    description = "When a game is already decided on the 4th map, slays everyone, announces the victory and rotates to a random official campaign instead of playing the last map",
    version = "1.0.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations(TRANSLATION_FILE);

    g_cvEnabled = CreateConVar("l4d2_early_victory_enabled", "1", "Enable/disable the early victory (skip last map when the game is already decided)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvChapter = CreateConVar("l4d2_early_victory_chapter", "4", "Chapter (map index) that triggers the early victory", FCVAR_NOTIFY, true, 1.0);
    g_cvSlayDelay = CreateConVar("l4d2_early_victory_slay_delay", "5.0", "How many seconds after announcing the victory before slaying everyone", FCVAR_NOTIFY, true, 0.0);
    g_cvChangeDelay = CreateConVar("l4d2_early_victory_change_delay", "3.0", "How many seconds after slaying everyone before changing to a random campaign", FCVAR_NOTIFY, true, 0.0);

    CreateTimer(3.0, Check_Timer, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    g_bTriggered = false;
}

public void OnMapEnd()
{
    g_bTriggered = false;
}

Action Check_Timer(Handle timer)
{
    if (!g_cvEnabled.BoolValue || g_bTriggered || !L4D_HasMapStarted())
        return Plugin_Continue;

    if (L4D_GetCurrentChapter() != g_cvChapter.IntValue || L4D_IsMissionFinalMap())
        return Plugin_Continue;

    if (!InSecondHalfOfRound())
        return Plugin_Continue;

    if (ScoringTeamScore() <= AlreadyPlayedTeamScore())
        return Plugin_Continue;

    g_bTriggered = true;

    CPrintToChatAll("{orange}[%t]{default} %t", "Tag", "Decided", ScoringTeamScore(), AlreadyPlayedTeamScore());

    CreateTimer(g_cvSlayDelay.FloatValue, Slay_Timer, _, TIMER_FLAG_NO_MAPCHANGE);

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
    int score = L4D_GetTeamScore(1);

    if (score < 0)
        score = 0;

    return L4D2Direct_GetVSCampaignScore(0) + score;
}

int GetTeamBScore()
{
    int score = L4D_GetTeamScore(2);

    if (score < 0)
        score = 0;

    return L4D2Direct_GetVSCampaignScore(1) + score;
}

bool AreTeamsFlipped()
{
    return GameRules_GetProp("m_bAreTeamsFlipped") != 0;
}

bool InSecondHalfOfRound()
{
    return GameRules_GetProp("m_bInSecondHalfOfRound") != 0;
}
