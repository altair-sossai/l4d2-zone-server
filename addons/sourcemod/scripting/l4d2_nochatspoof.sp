#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

ConVar g_hCvarEnable;
ConVar g_hCvarMaxBlanks;

public Plugin myinfo =
{
	name = "L4D2 Chat-Spoof Preventer",
	author = "Altair Sossai",
	description = "Block chat messages with line breaks, control or invisible characters, so players can't hide their name, fake server messages or clear everyone's chat.",
	version = "1.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
	g_hCvarEnable = CreateConVar("l4d2_nochatspoof_enable", "1", "Block chat messages with line breaks, control or invisible characters (1 = block, 0 = vanilla behaviour).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCvarMaxBlanks = CreateConVar("l4d2_nochatspoof_max_blanks", "16", "Block chat messages with more consecutive blank characters than this, so the line can't be wrapped to hide the name (0 = no limit).", FCVAR_NONE, true, 0.0);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	// Modified clients can send say with carriage returns (or other characters the chat box can't type).
	// The chat HUD draws each one as a new line, which pushes the "name :" prefix out of view and leaves the text alone,
	// so it looks like a server message ("Server shutting down"), or, with nothing after it, wipes everyone's chat.

	if (client > 0 && g_hCvarEnable.BoolValue && IsSpoofedMessage(sArgs))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsSpoofedMessage(const char[] text)
{
	int maxBlanks = g_hCvarMaxBlanks.IntValue;
	int blanks = 0;
	bool hasVisible = false;

	for (int i = 0; text[i] != '\0'; )
	{
		int codepoint;
		int length = DecodeUtf8(text, i, codepoint);

		// Broken UTF-8 (e.g. a message cut in the middle of an accented letter) can't move lines, so it's just skipped.
		if (length == 0)
		{
			i++;
			continue;
		}

		i += length;

		if (IsForbidden(codepoint))
		{
			return true;
		}

		if (IsBlank(codepoint))
		{
			if (maxBlanks > 0 && ++blanks > maxBlanks)
			{
				return true;
			}

			continue;
		}

		blanks = 0;
		hasVisible = true;
	}

	return !hasVisible;
}

int DecodeUtf8(const char[] text, int pos, int &codepoint)
{
	int lead = text[pos] & 0xFF;
	int length, minimum;

	if (lead < 0x80)
	{
		codepoint = lead;
		return 1;
	}

	if ((lead & 0xE0) == 0xC0)
	{
		length = 2;
		minimum = 0x80;
		codepoint = lead & 0x1F;
	}
	else if ((lead & 0xF0) == 0xE0)
	{
		length = 3;
		minimum = 0x800;
		codepoint = lead & 0x0F;
	}
	else if ((lead & 0xF8) == 0xF0)
	{
		length = 4;
		minimum = 0x10000;
		codepoint = lead & 0x07;
	}
	else
	{
		return 0;
	}

	for (int k = 1; k < length; k++)
	{
		// Also stops at the terminator, since '\0' isn't a continuation byte.
		int next = text[pos + k] & 0xFF;

		if ((next & 0xC0) != 0x80)
		{
			return 0;
		}

		codepoint = (codepoint << 6) | (next & 0x3F);
	}

	if (codepoint < minimum || codepoint > 0x10FFFF || (codepoint >= 0xD800 && codepoint <= 0xDFFF))
	{
		return 0;
	}

	return length;
}

bool IsForbidden(int cp)
{
	return cp < 0x20                            // C0 controls: \r, \n, \t...
		|| (cp >= 0x7F && cp <= 0x9F)           // DEL and C1 controls
		|| cp == 0x034F                         // combining grapheme joiner
		|| cp == 0x115F || cp == 0x1160         // Hangul fillers
		|| cp == 0x17B4 || cp == 0x17B5         // Khmer invisible vowels
		|| cp == 0x180E                         // Mongolian vowel separator
		|| (cp >= 0x200B && cp <= 0x200F)       // zero width characters and direction marks
		|| (cp >= 0x2028 && cp <= 0x202E)       // line/paragraph separators and direction overrides
		|| (cp >= 0x2060 && cp <= 0x206F)       // word joiner, invisible operators, direction isolates
		|| cp == 0x2800                         // blank Braille pattern
		|| cp == 0x3164                         // Hangul filler
		|| cp == 0xFEFF                         // zero width no-break space
		|| cp == 0xFFA0                         // halfwidth Hangul filler
		|| (cp >= 0xFFF9 && cp <= 0xFFFB)       // interlinear annotation
		|| (cp >= 0xE0000 && cp <= 0xE007F);    // tags
}

bool IsBlank(int cp)
{
	return cp == 0x20
		|| cp == 0xA0
		|| cp == 0x1680
		|| (cp >= 0x2000 && cp <= 0x200A)
		|| cp == 0x202F
		|| cp == 0x205F
		|| cp == 0x3000;
}
