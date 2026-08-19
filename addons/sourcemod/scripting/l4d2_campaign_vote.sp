#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

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

    RegConsoleCmd("sm_votecampaign", voteCampaign_CMD, "Opens the campaign menu to start a map change vote");
    RegConsoleCmd("sm_votecamp",     voteCampaign_CMD, "Opens the campaign menu to start a map change vote");
}

public Action voteCampaign_CMD(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[Campaigns] %t", "PlayerOnly");
        return Plugin_Handled;
    }

    Menu menu = BuildCampaignMenu(client);
    if (menu == null)
    {
        CPrintToChat(client, "{green}[Campaigns] {default}%t", "ReadError");
        return Plugin_Handled;
    }

    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

Menu BuildCampaignMenu(int client)
{
    DirectoryListing dir = OpenDirectory("missions", true, NULL_STRING);
    if (dir == null)
    {
        return null;
    }

    Menu menu = new Menu(MenuHandler_Campaigns);

    char title[128];
    Format(title, sizeof(title), "%T", "MenuTitle", client);
    menu.SetTitle(title);

    char fileName[PLATFORM_MAX_PATH];
    FileType type;

    while (dir.GetNext(fileName, sizeof(fileName), type))
    {
        if (type != FileType_File)
        {
            continue;
        }

        int len = strlen(fileName);
        if (len < 4 || strcmp(fileName[len - 4], ".txt", false) != 0)
        {
            continue;
        }

        char path[PLATFORM_MAX_PATH];
        Format(path, sizeof(path), "missions/%s", fileName);

        KeyValues kv = new KeyValues("Mission");
        if (kv.ImportFromFile(path))
        {
            char displayName[128];
            char shortName[64];

            kv.GetString("DisplayTitle", displayName, sizeof(displayName), "");
            kv.GetString("Name", shortName, sizeof(shortName), "");

            if (shortName[0] != '\0')
            {
                ResolveDisplayName(shortName, displayName, sizeof(displayName));
                menu.AddItem(shortName, displayName);
            }
        }

        delete kv;
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

void ResolveDisplayName(const char[] shortName, char[] displayName, int maxlen)
{
    if (StrEqual(shortName, "L4D2C1", false))
    {
        strcopy(displayName, maxlen, "Dead Center");
        return;
    }

    if (StrEqual(shortName, "L4D2C2", false))
    {
        strcopy(displayName, maxlen, "Dark Carnival");
        return;
    }

    if (StrEqual(shortName, "L4D2C3", false))
    {
        strcopy(displayName, maxlen, "Swamp Fever");
        return;
    }

    if (StrEqual(shortName, "L4D2C4", false))
    {
        strcopy(displayName, maxlen, "Hard Rain");
        return;
    }

    if (StrEqual(shortName, "L4D2C5", false))
    {
        strcopy(displayName, maxlen, "The Parish");
        return;
    }

    if (StrEqual(shortName, "L4D2C6", false))
    {
        strcopy(displayName, maxlen, "The Passing");
        return;
    }

    if (StrEqual(shortName, "L4D2C7", false))
    {
        strcopy(displayName, maxlen, "The Sacrifice");
        return;
    }

    if (StrEqual(shortName, "L4D2C8", false))
    {
        strcopy(displayName, maxlen, "No Mercy");
        return;
    }

    if (StrEqual(shortName, "L4D2C9", false))
    {
        strcopy(displayName, maxlen, "Crash Course");
        return;
    }

    if (StrEqual(shortName, "L4D2C10", false))
    {
        strcopy(displayName, maxlen, "Death Toll");
        return;
    }

    if (StrEqual(shortName, "L4D2C11", false))
    {
        strcopy(displayName, maxlen, "Dead Air");
        return;
    }

    if (StrEqual(shortName, "L4D2C12", false))
    {
        strcopy(displayName, maxlen, "Blood Harvest");
        return;
    }

    if (StrEqual(shortName, "L4D2C13", false))
    {
        strcopy(displayName, maxlen, "Cold Stream");
        return;
    }

    if (StrEqual(shortName, "L4D2C14", false))
    {
        strcopy(displayName, maxlen, "The Last Stand");
        return;
    }

    if (displayName[0] == '\0' || displayName[0] == '#' || displayName[0] == '$')
    {
        strcopy(displayName, maxlen, shortName);
    }
}
