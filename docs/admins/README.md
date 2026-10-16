# Admin Commands Guide

🌐 **English** | [Português](README.pt.md) | [Español](README.es.md)

A quick guide to the server's admin commands. The first commands are the ones used most day to day; the further down you go, the less you will need them.

> The commands any player can use are in the [Player Commands Guide](../players/README.md).

---

## How to use commands

| Form | Example | Note |
|---|---|---|
| Chat with `!` | `!swap Miosha` | Everyone sees the command in the chat |
| Chat with `/` | `/swap Miosha` | The command is **silent**, only you see the reply |
| Console (`~`) | `sm_swap Miosha` | Replace the `!` with `sm_` |

**What `< >` and `[ ]` mean**

In this guide, `< >` and `[ ]` only show what you should type there. **Do not type the symbols**, replace everything with the value:

| In the guide | Means | You type |
|---|---|---|
| `!swapto <team> <player>` | `< >` = required | `!swapto 2 vorkyss` |
| `!hp [amount]` | `[ ]` = optional, you can leave it out | `!hp` or `!hp 50` |
| `!ban <target> <minutes> [reason]` | both together | `!ban #12 60` or `!ban #12 60 chat flood` |

❌ Wrong: `!swapto <2> <vorkyss>`

✅ Right: `!swapto 2 vorkyss`

**Names with spaces:** put the name in quotes `" "`. Without quotes, the game reads each word as a separate part of the command.

❌ Wrong: `!swapto 2 (LoD) Adeilson`

✅ Right: `!swapto 2 "(LoD) Adeilson"`

**How to pick the target (`<target>`)**

- **Part of the name:** `!swap mio` works if only one player has "mio" in their name.
- **`#userid`:** the safest way when the name has odd characters or looks like someone else's (see below how to find the number).
- **Groups:** `@all` (everyone), `@humans` (humans only), `@bots` (bots only), `@me` (yourself), `@aim` (whoever is in your crosshair).

**How to find the `#userid`**

Open the console (`~`) and type `status`. You will see something like this (the last columns are left out):

```
] status
hostname: L4D2 Zone
map     : c2m1_highway at: 0 x, 0 y, 0 z
players : 4 humans, 0 bots (8 max)

# userid name uniqueid connected ping loss state
#  12 "vorkyss" STEAM_1:0:11111111 25:14 45 0 active
#  15 "Feeh" STEAM_1:1:22222222 18:02 38 0 active
#  21 "♏" STEAM_1:0:33333333 07:45 60 0 active
#  23 "Finn ™" STEAM_1:1:44444444 02:10 52 0 active
```

The **first number** on each line is the `userid`. In the example, the name `♏` is hard to type, so just use its number:

```
!swap #21
!swapto 1 #21
```

This works in any command that asks for a `<target>` (kick, ban, mute, swap etc.).

> The `userid` changes every time the player reconnects. If they leave and come back, run `status` again.

> 💡 When in doubt, open the menu with **`!admin`**. Almost everything here (kick, ban, mute, change map, change teams) can also be done from it, without typing anything.

---

## Admin menu

| Command | What it does |
|---|---|
| `!admin` | Opens the admin menu (players, votes, maps, server commands) |

## Match config (ZoneMod)

| Command | What it does |
|---|---|
| `!forcematch <config> [map]` / `!fm <config> [map]` | Loads the competitive config. If you pass a map, the config loads straight on it. **Use `!fm zonemod` whenever the server has no config loaded** |
| `!resetmatch` | Turns the current config off and puts the server back in the default mode |
| `!forcechangematch <config> [map]` / `!fchmatch <config> [map]` | Switches to another config without turning the current one off first |

Examples:

```
!fm zonemod               -> loads ZoneMod on the current map
!fm zonemod c2m1_highway  -> loads ZoneMod straight on Dark Carnival
!fchmatch zm3v3           -> switches to ZoneMod 3v3
```

Most used configs: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`.

## Ready-up and pause

| Command | What it does |
|---|---|
| `!forcestart` / `!fs` | Starts the round without waiting for everyone to `!ready`. With the game paused, it also unpauses |
| `!forcepause` | Pauses the game. **Only an admin can unpause** a pause made this way |
| `!forceunpause` | Unpauses without waiting for the teams to ready up (starts the countdown for the game to resume) |

> Use `!forcepause` when you need to sort something out (player replacement, someone stuck, an argument). Players cannot unpause until you use `!forceunpause`.

## Teams

| Command | What it does |
|---|---|
| `!swap <player1> [player2] ...` | Moves the listed players to the opposite team |
| `!swapto <team> <player1> [player2] ...` | Moves the players to a specific team: `1` = spectator, `2` = survivors, `3` = infected |
| `!swapto force <team> <player1> [player2] ...` | Same as above, but forces the move even if the team is full |
| `!swapteams` | Swaps the two whole teams (survivors ↔ infected) |
| `!fixbots` | Sets the number of survivor bots to the config's team size (e.g. 4 in 4v4), creating the missing ones |

Examples:

```
!swapto 1 Zenk            -> moves Zenk to spectator
!swapto 2 Guigo Vegueta   -> moves both to survivors
!swap #12                 -> moves player #12 to the opposite team
```

## Mix

| Command | What it does |
|---|---|
| `!mix` | Starts the mix **right away**, without a vote. Both captains are chosen by a player vote |
| `!mix <captain1>` | Starts the mix right away with `captain1` as the survivors' captain. The second captain is chosen by a vote |
| `!mix <captain1> <captain2>` | Starts the mix right away with both captains set: `captain1` on survivors and `captain2` on infected |
| `!stopmix` | Cancels the mix in progress (for example, if a captain left or is stalling the picks) |

Examples:

```
!mix                            -> starts the mix and the players vote for the captains
!mix vorkyss                    -> vorkyss is a captain, the other one comes from a vote
!mix vorkyss Feeh               -> vorkyss and Feeh are the captains
!mix "(LoD) Adeilson" Feeh      -> use quotes when the name has spaces or symbols
```

> - The captains must be **playing** (on survivors or infected), not in spectator.
> - You can use the full name or just the start of it.
> - Both teams must be **full**, and the mix can only start at the **beginning of a new game** (score 0 x 0), before the first round starts.
> - There is no mix in 1v1.
> - If someone leaves the server during the mix, the mix is cancelled. The first time the player only gets a warning; if they leave again, they are **banned for 60 minutes**.

## Moderation: kick, ban and mute

| Command | What it does |
|---|---|
| `!kick <target> [reason]` | Kicks the player from the server |
| `!ban <target> <minutes> [reason]` | Bans a player who **is on the server**. `0` = permanent |
| `!addban <minutes> <SteamID> [reason]` | Bans a player who **has already left** the server, using their SteamID |
| `!unban <SteamID>` | Removes the ban |
| `!mute <target>` / `!unmute <target>` | Blocks or allows the player's **voice** |
| `!gag <target>` / `!ungag <target>` | Blocks or allows the player's **text chat** |
| `!silence <target>` / `!unsilence <target>` | Blocks or allows **voice and chat** at the same time |

Examples:

```
!ban #12 60 insulting in chat
!ban #7 0 cheating
!addban 1440 STEAM_1:0:12345678 left before the ban
!unban STEAM_1:0:12345678
```

> ⚠️ Mute, gag and silence last **until the player leaves the server**. If the problem continues, use kick or ban.
>
> ⚠️ In ban reasons, write **only the reason**. Never put the player's IP or personal data.

## Map

| Command | What it does |
|---|---|
| `!map <map>` | Changes the map right away. E.g. `!map c2m1_highway` |

---

## Tank and Witch

| Command | What it does |
|---|---|
| `!givetank <player>` | Sets who will be the next Tank. The player must be on the **infected** team |
| `!tankshuffle` | Picks the Tank again at random |
| `!ftank <percentage>` | Forces the Tank spawn percentage. **Only works during the ready-up** and does not work on maps where the Tank has a fixed spawn |
| `!fwitch <percentage>` | Forces the Witch spawn percentage. **Only works during the ready-up** and does not work on maps where the Witch has a fixed spawn |

> Players can also ask for this through a vote with `!voteboss <tank> <witch>`. `!ftank`/`!fwitch` skips the vote.

## Score and campaign

| Command | What it does |
|---|---|
| `!setscores <survivors> <infected>` | Changes the score **right away**, without a vote (when a player uses it, a vote is started). **Only works during the ready-up**, before the round starts. `<survivors>` is the score of the team that is on survivors now |
| `!setnextcampaign` | Opens a menu to choose the next campaign(s) of the rotation, or clear the list |

> Useful when the server crashed in the middle of a match and you need to come back with the right score.

## Help during the match

| Command | What it does |
|---|---|
| `!hp [amount]` | Adds the amount (1 to 100, default: 100) to the health of every living survivor, without going over 100, and picks up anyone who is incapacitated |

## Spectators and casters

| Command | What it does |
|---|---|
| `!caster <player>` | Registers the player as a caster (commentator) |
| `!notcasting <player>` | Removes the player from the caster list |
| `!resetcasters` | Clears every registered caster |
| `!kickspecs` | Kicks the spectators **right away**, without a vote (casters and admins are not kicked) |
| `!broadcast` | Turns "talk to everyone" mode on/off: while on, **everyone hears your voice**, including both teams |

> Use `!broadcast` to give both teams a quick voice notice. Remember to turn it off afterwards.

## General moderation

| Command | What it does |
|---|---|
| `!slay <target>` | Kills the player |
| `!rename <target> <new name>` | Changes the player's name |
| `!who` | Shows the connected players and who is an admin |
| `!votekick <target>` | Starts a vote to kick the player |
| `!voteban <target>` | Starts a vote to ban the player |
| `!votemap <map>` | Starts a vote to change the map |

## Admin messages

| Command | What it does |
|---|---|
| `!say <message>` | Message to everyone in the chat, highlighted as an admin message |
| `!csay <message>` | Message in the **center of everyone's screen** |
| `!hsay <message>` | Message in everyone's hint box |
| `!psay <target> <message>` | Private message to a player |
| `!chat <message>` | Message that **only admins** see |

> Shortcut: in team chat (`say_team`), start the message with `@` to talk only to the admins. E.g. `@can someone help here?`

## Server

| Command | What it does |
|---|---|
| `!slots <number>` | Changes the number of server slots **right away**, without a vote (maximum 30). E.g. `!slots 10` |
| `!killlobbyres` | Removes the server's lobby reservation (lets in players who did not come through the lobby) |

## Weapon skins

| Command | What it does |
|---|---|
| `!skin on` / `!skin off` | Turns the skins on or off for everyone. **It stays that way after the map changes**, until another admin changes it or the server restarts |
| `!skin test <id>` | Tries the skin on yourself until the map changes, without buying it, being a survivor or being in the ready-up. Only works with skins that are already on the map's download list |
| `!skin test default [weapon]` | Removes the test skin |

`[weapon]`: `smg`, `mac`, `mp5`, `pump`, `chrome`, `magnum` (or `deagle`), `axe`, `katana`, `machete`, `bat`, `cricket`, `guitar`, `crowbar`, `golf` or `pan`. Without it, the weapon in your hand is used. `!skin test <id>` does not need it: the skin already defines the weapon.

Examples:

```
!skin off                     -> turns the skins off for everyone
!skin test hellsing-gold      -> tries the hellsing-gold skin
!skin test default smg        -> removes the test skin from the SMG
```

> The players' skin commands (`!skin`, `!skin <id>`, `!skin next`, `!skin prev`, `!skin default`, `!skin status`) are in the [Player Commands Guide](../players/README.md#weapon-skins). `!skin on/off` and `!skin test` only work for admins with **root** access.

### Skin shop (site)

Players buy skins at [l4d2.com.br/skins](https://l4d2.com.br/skins) with stars (1 star per SI damage MVP or common infected MVP in competitive matches, since the ranking started). Only the files of skins that at least one player bought go on the download list, starting from the map change after the purchase.

Purchases last until the end of the ranking season: at every ranking reset (every 2 months) they are **refunded automatically** and the stars go back to the players. Skins given as gifts are kept.

Site admins have the **Admin** menu at the top of [l4d2.com.br](https://l4d2.com.br):

| What to do | How |
|---|---|
| Change a skin's price | **Admin → Skin prices**: click the skin, change the value and click **Save**. It only applies to new purchases; whoever already bought it is not affected. **Reset to default** goes back to the catalog price |
| Give a skin as a gift | **Admin → Skin purchases → Give a skin** (or **Give as a gift** on the skin, in Skin prices): pick the player and the skin. The skin is equipped for the player and costs no stars |
| Refund a purchase | **Admin → Skin purchases**: click the purchase, then **Refund purchase** and **Confirm refund**. The stars paid go back to the player, the skin leaves their account and, if it was equipped, the weapon goes back to the default one |
| Refund everything | **Admin → Skin purchases → Refund everything**: tick the confirmation and click **Refund everything**. It refunds every purchase and every gift of every player, and it cannot be undone. If some items fail, run it again |
| Ban a player from the site chat | **Admin → Chat Bans → Add ban**: the player can no longer send messages to the server through the site chat |

> Stars always come from the ranking: admins do not change anyone's balance, they only give gifts or refund purchases. More details in [Skins operations → Common tasks](../weapon-skins/06-operations.md#common-tasks).

### Test mode: every skin

To check skins in game that nobody has bought yet:

1. `!cvar weapon_skins_preview_all 1`
2. Change the map, with `!fm zonemod` or `!map <map>`. The files of every skin go on the download list when the map loads.
3. Leave and rejoin the server to download the files. If you see ERROR, close and reopen the game.
4. Pick up the weapon and use `!skin next` / `!skin prev` to go through all of its skins, or `!skin <id>`. For root admins, purchase, team and ready-up are ignored.
5. When done: `!cvar weapon_skins_preview_all 0` and change the map. Only what was bought is downloaded again.

> ⚠️ While test mode is on, **every player who joins downloads every skin** (about 300 MB). Use it with the server empty and turn it off right after.

---

## Advanced commands

| Command | What it does |
|---|---|
| `!cvar <cvar> [value]` | Shows or changes a server cvar |
| `!rcon <command>` | Runs a command straight in the server console |
| `!execcfg <file>` | Runs a `.cfg` file from the server's `cfg/` folder |
| `!reloadadmins` | Reloads the admin list (after someone is added) |
| `!listcampaigns` | Lists every installed campaign in the console |
| `!refreshcampaigns` | Refreshes the campaign list of `!votecamp` |
| `!add_caster_id <SteamID>` | Adds the SteamID to the list of who can register themselves as a caster (`!cast`) |
| `!remove_caster_id <SteamID>` | Removes the SteamID from that list |
| `!printcasters` | Shows the list of caster SteamIDs |
| `statsreset` | **Console only.** Resets the current match stats (`!stats`, `!mvp`) |

> ⚠️ Be careful with `!cvar`, `!rcon` and `!execcfg`: they can break the match config. If something looks wrong, `!resetmatch` and then `!forcematch zonemod` fixes it.

---

## Tests and debug (do not use in a match)

These commands exist, but they are for **tests, debugging or fun**. Using them in a real match ruins the game.

### Fun and test commands

| Command | What it does |
|---|---|
| `!cchelp` | Lists every available test command |
| `!godmode <target>` | Makes the player immortal |
| `!teleport <target>` | Teleports the player to where you are aiming |
| `!revive <target>` | Picks up an incapacitated survivor |
| `!sethpplayer <target> <health>` | Sets the player's health |
| `!speedplayer <target> <speed>` | Changes the player's speed |
| `!panic` | Forces a horde event |
| `!slap`, `!burn`, `!freeze`, `!beacon`, `!noclip`, `!timebomb` | Fun commands: slap, fire, freeze, beacon, walk through walls, bomb |

### Maintenance and debug

| Command | What it does |
|---|---|
| `!crash` | **Crashes the server** so it restarts. Everyone is disconnected. Only use it if the server is broken and nobody is playing |
| `!early_victory_debug` | Shows the early victory internal values |
| `!tank_witch_debug_info` | Shows internal Tank and Witch spawn information |

---

## Common situations

**Server without a config / game in default mode**
1. `!forcematch zonemod`

**A player dropped in the middle of the round**
1. `!forcepause`
2. Wait for them to come back, or bring someone from the queue with `!swapto <team> <player>`
3. `!forceunpause`

**Unbalanced teams or a player on the wrong team**
1. `!swapto 1 <player>` to move them to spectator
2. `!swapto 2 <player>` or `!swapto 3 <player>` to put them on the right team
3. If a survivor is missing, `!fixbots`

**Stuck mix (a captain left or is not picking)**
1. `!stopmix`
2. Start another one with `!mix`, or set the captains right away with `!mix <captain1> <captain2>`

**The server crashed and the match came back with no score**
1. `!forcematch zonemod <map>` to come back on the map you were playing
2. Still in the ready-up, `!setscores <survivors> <infected>` with the previous score. As an admin, the score changes right away

**Toxic player**
1. `!gag` / `!mute` / `!silence` to stop it right away
2. If it continues: `!kick <target> <reason>`
3. If it is serious or repeated: `!ban <target> <minutes> <reason>`
