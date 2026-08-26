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

enum struct Campaign
{
    char name[64];
    char title[128];
    char menuText[256];
}

bool g_CustomTitlesCampaignsLocked = false,
     g_IgnoredCampaignsLocked = false;

ArrayList g_Campaigns = null;

StringMap g_CustomTitlesCampaigns = null,
          g_IgnoredCampaigns = null;

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

    InitCustomTitlesCampaigns();
    InitIgnoredCampaigns();

    RegConsoleCmd("sm_votecampaign", VoteCampaignCmd, "Opens the campaign menu to start a map change vote");
    RegConsoleCmd("sm_votecamp", VoteCampaignCmd, "Opens the campaign menu to start a map change vote");

    RegServerCmd("l4d2_campaign_vote_title", CustomTitleCampaignCmd, "Sets a custom title for a campaign name (e.g. l4d2_campaign_vote_title \"L4D2C1\" \"My Custom Title\"). Ignored once the list is locked");
    RegServerCmd("l4d2_campaign_vote_title_lock", CustomTitleCampaignLockCmd, "Locks the custom titles list so later l4d2_campaign_vote_title calls are ignored. Call this once right after the last entry in your config");

    RegServerCmd("l4d2_campaign_vote_ignore", IgnoreCampaignCmd, "Adds a campaign name to be hidden from the vote menu (e.g. l4d2_campaign_vote_ignore \"credits\"). Ignored once the list is locked");
    RegServerCmd("l4d2_campaign_vote_ignore_lock", IgnoreCampaignLockCmd, "Locks the ignored list so later l4d2_campaign_vote_ignore calls are ignored. Call this once right after the last entry in your config");

    RegAdminCmd("sm_listcampaigns", ListCampaignsCmd, ADMFLAG_GENERIC, "Lists in console the raw name and DisplayTitle of every campaign found in the missions folder");
}

public Action VoteCampaignCmd(int client, int args)
{
    if (!IsHumanClient(client))
        return Plugin_Handled;

    Menu menu = BuildCampaignMenu(client);
    if (menu == null)
    {
        CReplyToCommand(client, "%s%t", TAG, "ReadError");
        return Plugin_Handled;
    }

    if (!menu.Display(client, MENU_TIME_FOREVER))
        delete menu;

    return Plugin_Handled;
}

Action CustomTitleCampaignCmd(int args)
{
    if (args < 2)
    {
        LogError("[Campaigns] Usage: l4d2_campaign_vote_title <name> <title>");
        return Plugin_Handled;
    }

    char name[64];
    GetCmdArg(1, name, sizeof(name));
    TrimString(name);

    if (StringEmpty(name))
    {
        LogError("[Campaigns] Usage: l4d2_campaign_vote_title <name> <title>");
        return Plugin_Handled;
    }

    char title[128];
    GetCmdArg(2, title, sizeof(title));
    TrimString(title);

    if (StringEmpty(title))
    {
        LogError("[Campaigns] Usage: l4d2_campaign_vote_title <name> <title>");
        return Plugin_Handled;
    }

    AddCustomTitleCampaign(name, title);

    return Plugin_Handled;
}

Action CustomTitleCampaignLockCmd(int args)
{
    g_CustomTitlesCampaignsLocked = true;

    return Plugin_Handled;
}

Action IgnoreCampaignCmd(int args)
{
    if (args < 1)
    {
        LogError("[Campaigns] Usage: l4d2_campaign_vote_ignore <name>");
        return Plugin_Handled;
    }

    char name[64];
    GetCmdArg(1, name, sizeof(name));
    TrimString(name);

    if (StringEmpty(name))
    {
        LogError("[Campaigns] Usage: l4d2_campaign_vote_ignore <name>");
        return Plugin_Handled;
    }

    AddIgnoredCampaign(name);

    return Plugin_Handled;
}

Action IgnoreCampaignLockCmd(int args)
{
    g_IgnoredCampaignsLocked = true;

    return Plugin_Handled;
}

Action ListCampaignsCmd(int client, int args)
{
    DirectoryListing dir = OpenDirectory("missions", true, NULL_STRING);
    if (dir == null)
    {
        CReplyToCommand(client, "%s%t", TAG, "ReadError");
        return Plugin_Handled;
    }

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

        KeyValues kv = new KeyValues("Mission");
        if (!kv.ImportFromFile(path))
        {
            delete kv;
            continue;
        }

        char name[64];
        kv.GetString("Name", name, sizeof(name), "");

        char displayTitle[128];
        kv.GetString("DisplayTitle", displayTitle, sizeof(displayTitle), "");

        delete kv;

        PrintToConsole(client, "%s | %s", name, displayTitle);
    }

    delete dir;

    CReplyToCommand(client, "%s%t", TAG, "ListPrintedToConsole");

    return Plugin_Handled;
}

Menu BuildCampaignMenu(int client)
{
    if (!EnsureCampaignCache())
        return null;

    Menu menu = new Menu(MenuHandler_Campaigns);

    char title[128];
    Format(title, sizeof(title), "%T", "MenuTitle", client);
    menu.SetTitle(title);

    Campaign campaign;

    for (int i = 0; i < g_Campaigns.Length; i++)
    {
        g_Campaigns.GetArray(i, campaign);

        menu.AddItem(campaign.name, campaign.menuText);
    }

    return menu;
}

bool EnsureCampaignCache()
{
    if (g_Campaigns != null)
        return true;

    DirectoryListing dir = OpenDirectory("missions", true, NULL_STRING);
    if (dir == null)
        return false;

    ArrayList campaigns = new ArrayList(sizeof(Campaign));
    StringMap titleCount = new StringMap();

    ReadCampaigns(dir, campaigns, titleCount);

    delete dir;

    if (campaigns.Length == 0)
    {
        delete titleCount;
        delete campaigns;
        return false;
    }

    UpdateDuplicateMenuText(campaigns, titleCount);

    campaigns.SortCustom(CompareCampaignsByMenuText);

    delete titleCount;

    g_Campaigns = campaigns;

    return true;
}

void ReadCampaigns(DirectoryListing dir, ArrayList campaigns, StringMap titleCount)
{
    char fileName[PLATFORM_MAX_PATH];
    FileType type;

    StringMap seenNames = new StringMap();

    while (dir.GetNext(fileName, sizeof(fileName), type))
    {
        if (type != FileType_File)
            continue;

        int len = strlen(fileName);
        if (len < 4 || strcmp(fileName[len - 4], ".txt", false) != 0)
            continue;

        char path[PLATFORM_MAX_PATH];
        Format(path, sizeof(path), "missions/%s", fileName);

        KeyValues kv = new KeyValues("Mission");
        if (!kv.ImportFromFile(path))
        {
            delete kv;
            continue;
        }

        char name[64];
        kv.GetString("Name", name, sizeof(name), "");

        char displayTitle[128];
        kv.GetString("DisplayTitle", displayTitle, sizeof(displayTitle), "");

        delete kv;

        if (StringEmpty(name))
            continue;

        if (!IsValidCampaignName(name))
        {
            LogError("Invalid campaign name \"%s\" in \"%s\".", name, path);
            continue;
        }

        if (g_IgnoredCampaigns.ContainsKey(name))
            continue;

        if (!seenNames.SetString(name, "", false))
            continue;

        ResolveDisplayName(name, displayTitle, sizeof(displayTitle));

        Campaign campaign;
        strcopy(campaign.name, sizeof(campaign.name), name);
        strcopy(campaign.title, sizeof(campaign.title), displayTitle);
        strcopy(campaign.menuText, sizeof(campaign.menuText), displayTitle);
        campaigns.PushArray(campaign);

        int count = 0;
        titleCount.GetValue(displayTitle, count);
        titleCount.SetValue(displayTitle, count + 1);
    }

    delete seenNames;
}

bool IsValidCampaignName(const char[] name)
{
    for (int i = 0; name[i] != '\0'; i++)
    {
        if (!IsCharAlpha(name[i]) && !IsCharNumeric(name[i]) && name[i] != '_' && name[i] != '-')
            return false;
    }

    return true;
}

void InitCustomTitlesCampaigns()
{
    g_CustomTitlesCampaigns = new StringMap();
}

void AddCustomTitleCampaign(const char[] name, const char[] title)
{
    if (g_CustomTitlesCampaignsLocked)
        return;

    g_CustomTitlesCampaigns.SetString(name, title, false);
}

void InitIgnoredCampaigns()
{
    g_IgnoredCampaigns = new StringMap();

    AddIgnoredCampaign("credits");
}

void AddIgnoredCampaign(const char[] name)
{
    if (g_IgnoredCampaignsLocked)
        return;

    g_IgnoredCampaigns.SetString(name, "", false);
}

void ResolveDisplayName(const char[] name, char[] displayTitle, int maxlen)
{
    if (g_CustomTitlesCampaigns.GetString(name, displayTitle, maxlen))
        return;

    for (int i = 0; i < sizeof(g_OfficialCampaigns); i++)
    {
        if (StrEqual(name, g_OfficialCampaigns[i][0], false))
        {
            strcopy(displayTitle, maxlen, g_OfficialCampaigns[i][1]);
            return;
        }
    }

    if (StringEmpty(displayTitle) || displayTitle[0] == '#' || displayTitle[0] == '$')
        strcopy(displayTitle, maxlen, name);
}

void UpdateDuplicateMenuText(ArrayList campaigns, StringMap titleCount)
{
    Campaign campaign;

    for (int i = 0; i < campaigns.Length; i++)
    {
        campaigns.GetArray(i, campaign);

        int count = 0;
        titleCount.GetValue(campaign.title, count);

        if (count == 1)
            continue;

        Format(campaign.menuText, sizeof(campaign.menuText), "%s (%s)", campaign.title, campaign.name);
        campaigns.SetArray(i, campaign);
    }
}

int CompareCampaignsByMenuText(int index1, int index2, Handle array, Handle data)
{
    ArrayList campaigns = view_as<ArrayList>(array);

    Campaign campaign1;
    Campaign campaign2;
    campaigns.GetArray(index1, campaign1);
    campaigns.GetArray(index2, campaign2);

    return strcmp(campaign1.menuText, campaign2.menuText, false);
}

public int MenuHandler_Campaigns(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        if (!IsHumanClient(client))
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

bool IsHumanClient(int client)
{
    return IsValidClient(client) && !IsFakeClient(client);
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients)
        return false;

    return IsClientInGame(client);
}

bool StringEmpty(const char[] str)
{
    return strlen(str) == 0;
}
