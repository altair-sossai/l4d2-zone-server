#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>

public Plugin myinfo =
{
    name        = "L4D2 - Localhost",
    author      = "Altair Sossai",
    description = "Open localhost website",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar 
    hLocalhostUrl,
    hLocalhostType;

public void OnPluginStart()
{
    hLocalhostUrl = CreateConVar("localhost_url", "", "URL used to perform local tests", FCVAR_PROTECTED);
    hLocalhostType = CreateConVar("localhost_type", "url", "Type of content to be displayed, url|text", FCVAR_PROTECTED);

    RegConsoleCmd("sm_localhost", LocalHostCmd);
}

Action LocalHostCmd(int client, int args)
{
    char localHostUrl[100];
    GetConVarString(hLocalhostUrl, localHostUrl, sizeof(localHostUrl));

    char localHostType[10];
    GetConVarString(hLocalhostType, localHostType, sizeof(localHostType));

    if (StrEqual(localHostType, "url"))
    {
        ShowMOTDPanel(client, "localhost", localHostUrl, MOTDPANEL_TYPE_URL);
        return Plugin_Handled;
    }

    if (StrEqual(localHostType, "text"))
    {
        HTTPRequest request = new HTTPRequest(localHostUrl);

        request.Get(LocalHostResponse, client);

        return Plugin_Handled;
    }

    return Plugin_Handled;
}

void LocalHostResponse(HTTPResponse httpResponse, any client)
{
    if (httpResponse.Status != HTTPStatus_OK)
        return;

    JSONObject response = view_as<JSONObject>(httpResponse.Data);
    
    char content[40000];
    response.GetString("content", content, sizeof(content));

    ShowMOTDPanel(client, "localhost", content, MOTDPANEL_TYPE_TEXT);
}