#pragma semicolon 1
#pragma newdecls required

#include <ripext>
#include <sourcemod>
#include <left4dhooks>

public Plugin myinfo =
{
    name        = "L4D2 - Game Info Sync",
    author      = "Altair Sossai",
    description = "Syncs game info with Game Info API",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar
    hUrl,
    hSecretKey,
    hConfigurationName;

JSONObject 
    ConfigurationCommand,
    RoundCommand,
    ScoreboardCommand;

HTTPRequest
    ConfigurationRequest,
    RoundRequest,
    ScoreboardRequest;

char ConfigurationName[64];

public void OnPluginStart()
{
    hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);

    HookEvent("round_start", RoundStart_Event);

    CreateTimer(5.0, Every_5_Seconds_Timer, _, TIMER_REPEAT);
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    CreateTimer(5.0, RoundStart_Timer);
}

Action RoundStart_Timer(Handle timer)
{
    SendConfiguration();
    SendRound();

    return Plugin_Continue;
}

Action Every_5_Seconds_Timer(Handle hTimer)
{
    SendScoreboard();

    return Plugin_Continue;
}

void SendConfiguration()
{
    if (ConfigurationCommand == null)
        ConfigurationCommand = new JSONObject();

    ConfigurationCommand.SetInt("teamSize", GetConVarInt(FindConVar("survivor_limit")));

    if (hConfigurationName == null)
        hConfigurationName = FindConVar("l4d_ready_cfg_name");

    if (hConfigurationName != null)
        hConfigurationName.GetString(ConfigurationName, sizeof(ConfigurationName));

    if (strlen(ConfigurationName) > 0)
        ConfigurationCommand.SetString("name", ConfigurationName);

    if (ConfigurationRequest == null)
        ConfigurationRequest = BuildHTTPRequest("/api/game-info/configuration");
    
    ConfigurationRequest.Put(ConfigurationCommand, DoNothing);
}

void SendRound()
{
    if (RoundCommand == null)
        RoundCommand = new JSONObject();

    RoundCommand.SetInt("areTeamsFlipped", GameRules_GetProp("m_bAreTeamsFlipped"));
    RoundCommand.SetInt("maxChapterProgressPoints", L4D_GetVersusMaxCompletionScore());

    if (RoundRequest == null)
        RoundRequest = BuildHTTPRequest("/api/game-info/round");

    RoundRequest.Put(RoundCommand, DoNothing);
}

void SendScoreboard()
{
    if (ScoreboardCommand == null)
        ScoreboardCommand = new JSONObject();

    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    int survivorIndex = flipped ? 1 : 0;
    int infectedIndex = flipped ? 0 : 1;

    ScoreboardCommand.SetInt("survivorScore", L4D2Direct_GetVSCampaignScore(survivorIndex));
    ScoreboardCommand.SetInt("infectedScore", L4D2Direct_GetVSCampaignScore(infectedIndex));

    if (ScoreboardRequest == null)
        ScoreboardRequest = BuildHTTPRequest("/api/game-info/scoreboard");

    ScoreboardRequest.Put(ScoreboardCommand, DoNothing);
}

void DoNothing(HTTPResponse httpResponse, any value)
{
}

HTTPRequest BuildHTTPRequest(char[] path)
{
    char url[255];
    GetConVarString(hUrl, url, sizeof(url));
    StrCat(url, sizeof(url), path);

    char secretKey[100];
    GetConVarString(hSecretKey, secretKey, sizeof(secretKey));

    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("Authorization", secretKey);

    return request;
}