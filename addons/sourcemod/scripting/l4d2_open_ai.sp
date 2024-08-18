#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>
#include <readyup>
#include <ripext>

public Plugin myinfo =
{
    name        = "L4D2 - Open AI Integration",
    author      = "Altair Sossai",
    description = "Integrates with Open AI to bring a summary of the last match",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar hOpenAiUrl;

public void OnPluginStart()
{
    hOpenAiUrl = CreateConVar("open_ai_url", "", "Open AI URL", FCVAR_PROTECTED);

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
}

void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(60.0, NewGameTick);
}

Action NewGameTick(Handle timer)
{
    if (IsNewGame() && IsInReady())
        ShowLastMatchSummary();

    return Plugin_Stop;
}

void ShowLastMatchSummary()
{
    char openAiUrl[100];
    GetConVarString(hOpenAiUrl, openAiUrl, sizeof(openAiUrl));

    HTTPRequest request = new HTTPRequest(openAiUrl);

    request.Get(ShowLastMatchSummaryResponse);
}

void ShowLastMatchSummaryResponse(HTTPResponse httpResponse, any value)
{
    if (httpResponse.Status != HTTPStatus_OK)
        return;

    JSONObject response = view_as<JSONObject>(httpResponse.Data);
    JSONArray phrases = view_as<JSONArray>(response.Get("phrases"));

    char message[250];

    for (int i = 0; i < phrases.Length; i++)
    {
        if (i == 0)
            CPrintToChatAll("{default}[{blue}ChatGPT{default}] Detalhes da última partida:");

        phrases.GetString(i, message, sizeof(message));
        CPrintToChatAll(message);
    }
}

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0 && L4D2Direct_GetVSCampaignScore(1) == 0;
}