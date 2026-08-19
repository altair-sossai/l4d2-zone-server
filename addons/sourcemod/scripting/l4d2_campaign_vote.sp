#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#define TAG "{green}[Campaigns] {default}"

char g_OfficialCampaigns[][2][] =
{
    { "L4D2C1",  "Dead Center" },
    { "L4D2C2",  "Dark Carnival" },
    { "L4D2C3",  "Swamp Fever" },
    { "L4D2C4",  "Hard Rain" },
    { "L4D2C5",  "The Parish" },
    { "L4D2C6",  "The Passing" },
    { "L4D2C7",  "The Sacrifice" },
    { "L4D2C8",  "No Mercy" },
    { "L4D2C9",  "Crash Course" },
    { "L4D2C10", "Death Toll" },
    { "L4D2C11", "Dead Air" },
    { "L4D2C12", "Blood Harvest" },
    { "L4D2C13", "Cold Stream" },
    { "L4D2C14", "The Last Stand" }
};

char g_IgnoredCampaigns[][] =
{
    "credits"
};

public Plugin myinfo =
{
    name        = "L4D2 Campaign Vote",
    author      = "Altair Sossai",
    description = "Lets any player pick a campaign from a menu and start a changemission vote",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_campaign_vote.phrases");

    RegConsoleCmd("sm_votecampaign", VoteCampaignCmd, "Opens the campaign menu to start a map change vote");
    RegConsoleCmd("sm_votecamp", VoteCampaignCmd, "Opens the campaign menu to start a map change vote");
}

public Action VoteCampaignCmd(int client, int args)
{
    if (client == 0)
    {
        CReplyToCommand(client, "%s%t", TAG, "PlayerOnly");
        return Plugin_Handled;
    }

    Menu menu = BuildCampaignMenu(client);
    if (menu == null)
    {
        CReplyToCommand(client, "%s%t", TAG, "ReadError");
        return Plugin_Handled;
    }

    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

Menu BuildCampaignMenu(int client)
{
    DirectoryListing dir = OpenDirectory("missions", true, NULL_STRING);
    if (dir == null)
        return null;

    Menu menu = new Menu(MenuHandler_Campaigns);

    char title[128];
    Format(title, sizeof(title), "%T", "MenuTitle", client);
    menu.SetTitle(title);

    char fileName[PLATFORM_MAX_PATH];
    FileType type;

    while (dir.GetNext(fileName, sizeof(fileName), type))
    {
        if (type != FileType_File)
            continue;

        int len = strlen(fileName);
        if (len < 4 || strcmp(fileName[len - 4], ".txt", false) != 0)
            continue;

        char path[PLATFORM_MAX_PATH];
        Format(path, sizeof(path), "missions/%s", fileName);

        char displayName[128];
        char shortName[64];

        KeyValues kv = new KeyValues("Mission");
        bool imported = kv.ImportFromFile(path);

        if (imported)
        {
            kv.GetString("DisplayTitle", displayName, sizeof(displayName), "");
            kv.GetString("Name", shortName, sizeof(shortName), "");
        }

        delete kv;

        if (!imported || shortName[0] == '\0')
            continue;

        if (IsIgnoredCampaign(shortName))
            continue;

        ResolveDisplayName(shortName, displayName, sizeof(displayName));
        menu.AddItem(shortName, displayName);
    }

    delete dir;

    if (menu.ItemCount == 0)
    {
        delete menu;
        return null;
    }

    return menu;
}

public int MenuHandler_Campaigns(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        if (client < 1 || !IsClientInGame(client))
            return 0;

        char shortName[64];
        menu.GetItem(param2, shortName, sizeof(shortName));

        FakeClientCommand(client, "callvote changemission %s", shortName);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

bool IsIgnoredCampaign(const char[] shortName)
{
    for (int i = 0; i < sizeof(g_IgnoredCampaigns); i++)
    {
        if (StrEqual(shortName, g_IgnoredCampaigns[i], false))
            return true;
    }

    return false;
}

void ResolveDisplayName(const char[] shortName, char[] displayName, int maxlen)
{
    for (int i = 0; i < sizeof(g_OfficialCampaigns); i++)
    {
        if (StrEqual(shortName, g_OfficialCampaigns[i][0], false))
        {
            strcopy(displayName, maxlen, g_OfficialCampaigns[i][1]);
            return;
        }
    }

    if (displayName[0] == '\0' || displayName[0] == '#' || displayName[0] == '$')
        strcopy(displayName, maxlen, shortName);
}
