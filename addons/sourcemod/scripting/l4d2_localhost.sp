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
    char url[100];
    GetConVarString(hLocalhostUrl, url, sizeof(url));

    char type[10];
    GetConVarString(hLocalhostType, type, sizeof(type));

    if (StrEqual(type, "url"))
    {
        ShowMOTDPanel(client, "localhost", url, MOTDPANEL_TYPE_URL);
        return Plugin_Handled;
    }

    if (StrEqual(type, "text"))
    {
        HTTPRequest request = new HTTPRequest(url);

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