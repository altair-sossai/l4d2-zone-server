# Player Commands Guide

🌐 **English** | [Português](README.pt.md) | [Español](README.es.md)

Everything you can type in the server's chat, grouped by what you want to do.

---

## How to use commands

| Form | Example | Note |
|---|---|---|
| Chat with `!` | `!ready` | Everyone sees the command in chat |
| Chat with `/` | `/ready` | **Silent**, only you see the reply |
| Console (`~`) | `sm_ready` | Replace `!` with `sm_` |

**What `< >` and `[ ]` mean**

In this guide, `< >` and `[ ]` only show what goes in that spot. **Don't type the symbols**, replace the whole thing with the value:

| In the guide | Meaning | You type |
|---|---|---|
| `!mix <captain1> <captain2>` | `< >` = required | `!mix vorkyss Feeh` |
| `!roll [number]` | `[ ]` = optional, can be left out | `!roll` or `!roll 20` |

❌ Wrong: `!mix <vorkyss> <Feeh>`

✅ Right: `!mix vorkyss Feeh`

**Names with spaces:** put the name in quotes `" "`. Without quotes, the game reads each word as a separate part of the command.

❌ Wrong: `!mix (LoD) Adeilson Feeh`

✅ Right: `!mix "(LoD) Adeilson" Feeh`

---

## Ready-up (before the round starts)

| Command | What it does |
|---|---|
| `!ready` / `!r` | Marks you as ready. The round starts when everyone is ready |
| `!unready` / `!nr` | Removes your ready status |
| `!toggleready` | Switches between ready and not ready |
| `!hide` / `!show` | Hides or shows the ready-up panel (useful to see other menus) |
| `!return` | Takes you back to the saferoom if you get stuck during ready-up |

## Pause

| Command | What it does |
|---|---|
| `!pause` | Pauses the game |
| `!unpause` / `!ready` / `!r` | Marks your team as ready to resume. The game resumes when both teams are ready |
| `!unready` / `!nr` | Marks your team as not ready to resume |
| `!toggleready` | Switches your team between ready and not ready to resume |

> If a player crashes or disconnects during a live round, the game may pause automatically. Once they are back, use `!unpause` / `!ready` to resume.

---

## Teams and queue

| Command | What it does |
|---|---|
| `!spec` / `!s` | Moves you to spectators |
| `!fila` / `!queue` | Shows the waiting queue in order |
| `!vaga` / `!slot` | Claims a slot in the game if it's your turn in the queue |
| `!mix` | Votes to start a mix. Once enough players vote, everyone votes for the captains, and the captains pick the teams through a menu |
| `!mix <captain1> <captain2>` | Starts a vote proposing two captains: `captain1` on survivors and `captain2` on infected. If most players vote **yes**, the mix starts with them |
| `!teamflip` / `!tf` | Randomly picks a team (Survivor or Infected) for you, shown to everyone |
| `!kickspecs` | Starts a vote to kick spectators |

Examples:

```
!mix                           -> vote to start a mix
!mix vorkyss Feeh              -> propose vorkyss and Feeh as captains
!mix "(LoD) Adeilson" Feeh     -> use quotes when the name has spaces or symbols
```

> **About the mix:** both teams must be full and the mix can only start at the beginning of a new game (0 x 0). Captains must be playing (not spectating). There is no mix in 1v1. If someone leaves during a mix, the mix is canceled; doing it a second time gets you **banned for 60 minutes**.

> **About the queue (`!slot`):**
> - **Before the game starts (0 x 0):** if you are ahead of someone who is playing, `!slot` puts you in their place and they go to spectators.
> - **During the game:** only players from the starting teams can use `!slot`, to get back into their team in place of a substitute. If the substitute is controlling the Tank, wait until the Tank dies.
> - `!slot` does not work while a mix is running or while your lerp is invalid.
> - When a slot opens up, the server tells the next player in line to type `!slot`.

> **Tank alive:** survivors can't switch to spectators while the Tank is alive. Use `!pause` if you really need to change teams.

---

## Votes

| Command | What it does |
|---|---|
| `!match` / `!match <config>` | Starts a vote to load a config. Without a config, opens a menu to choose one. Ex.: `!match zonemod` |
| `!chmatch <config>` | Starts a vote to change to another config |
| `!rmatch` | Starts a vote to turn the current config off |
| `!votecamp` / `!votecampaign` | Opens a menu to vote for a campaign change (official and custom campaigns) |
| `!voteboss <tank> <witch>` | Votes to change the Tank and Witch spawn percentages (only during the ready-up of the first round of a map). `0` = no spawn, `-1` = keep current |
| `!setscores <survivors> <infected>` | Starts a vote to change the match score (players on a team only) |
| `!slots <number>` | Starts a vote to change the number of server slots. Ex.: `!slots 10` |

Main configs: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`. `!match` without a config opens a menu with every config installed on the server.

---

## Match information

| Command | What it does |
|---|---|
| `!boss` / `!tank` / `!witch` | Shows where the Tank and Witch will spawn (%) and who will be the Tank |
| `!cur` / `!current` | Shows how far the survivors have progressed in the map (%) |
| `!health` / `!bonus` / `!damage` | Shows the current survivor bonus |
| `!mapinfo` | Shows the map's distance and bonus values |
| `!cfg` / `!changelog` | Shows what the current config changes |
| `!lerps` | Lists every player's lerp |
| `!rates` | Lists every player's network settings |

## Stats and ranking

| Command | What it does |
|---|---|
| `!stats` | Survivor stats for the round. Type `!stats help` to see every option |
| `!mvp` | Survivor MVP for the round |
| `!mvpme` | Your own MVP stats |
| `!skill` | Skill stats (skeets, levels, crowns...) |
| `!ff` | Friendly fire stats |
| `!acc` | Accuracy stats |
| `!stats_auto <flags>` | Chooses which stats are shown automatically at the end of the round. `-1` = none, `0` = server default. Type `!stats_auto help` for details |
| `!ranking` | Shows your position in the server ranking |

---

## Weapon skins

| Command | What it does |
|---|---|
| `!skin` / `!skins` | Shows the skins help and the link to the skin shop |
| `!skin <id>` / `!skins <id>` | Uses one of your skins. Ex.: `!skin hellsing-gold` |
| `!skin next [weapon]` / `!skin prev [weapon]` | Cycles through the skins you own for that weapon. After the last one, it goes back to the default skin |
| `!skin default [weapon]` | Goes back to the default skin |
| `!skin status` | Shows whether the skins are on, how many stars you have and how many skins you own |

`[weapon]` is optional. Without it, the command uses the weapon in your hand (or your primary weapon, then your secondary weapon: melee or Magnum). Values: `smg`, `mac`, `mp5`, `pump`, `chrome`, `magnum` (or `deagle`), `axe`, `katana`, `machete`, `bat`, `cricket`, `guitar`, `crowbar`, `golf`, `pan`.

Examples:

```
!skin hellsing-gold     -> uses the hellsing-gold skin
!skin next              -> next skin for the weapon in your hand
!skin next pump         -> next skin for the pump shotgun
!skin next magnum       -> next skin for the Magnum
!skin default chrome    -> chrome shotgun back to the default skin
```

> **About skins:**
> - There are skins for the SMG, MAC-10 (silenced SMG), MP5, pump shotgun, chrome shotgun, Magnum (Desert Eagle) and the melee weapons (fireaxe, katana, machete, baseball bat, cricket bat, electric guitar, crowbar, golf club and frying pan).
> - **Buying:** skins are bought in the shop at [l4d2.com.br/skins](https://l4d2.com.br/skins) (log in with Steam) with **stars**: every SI damage MVP and every common infected MVP in competitive matches is worth 1 star. Your whole history counts, since the ranking began.
> - **When it shows up:** a skin you buy is **equipped right away** and shows up on the server **from the next map change**, because its files are sent to everyone when the map loads. You can also equip a skin or go back to the default skin on the site; that change also shows up from the next map change.
> - **How long it lasts:** a skin you buy lasts until the **ranking reset** (every 2 months). At the reset it is refunded automatically and its stars come back to you, so you can buy it again. Skins you receive as a **gift** are kept forever.
> - **Changing in game:** `!skin <id>`, `!skin next`, `!skin prev` and `!skin default` only work while you are a **survivor** and during the **ready-up**, on any map. Your choice is saved and loaded the next time you play.
> - The skin stays with the weapon: if you drop it, whoever picks it up uses it with your skin.

> **Downloads must be on:** the skin files are sent when the map loads, so players with downloads off are kicked. The kick message says which setting is wrong and the console command that fixes it:
> - `cl_allowdownload` is `0`: type `cl_allowdownload 1`
> - `cl_downloadfilter` is `mapsonly` or `none`: type `cl_downloadfilter all`
>
> Then reconnect. The menu option **Options > Multiplayer > Custom Server Content > Allow All** only changes `cl_downloadfilter`, so if the message is about `cl_allowdownload`, use the console. If it keeps happening, check that setting in your `autoexec.cfg` or `config.cfg`.

---

## Spectators

| Command | What it does |
|---|---|
| `!hear` | Chooses whose voice you hear: survivors, infected, spectators only, or everyone. Ex.: `!hear survivors` |
| `!spechud` | Shows or hides the spectator HUD |
| `!tankhud` | Shows or hides the Tank HUD |
| `!cast` | Registers you as a caster (only for authorized casters) |
| `!notcasting` / `!uncast` | Removes you from casters |

---

## In-game

### Infected

| Command | What it does |
|---|---|
| `!warp <1-4>` / `!warp <name>` | While in ghost mode, teleports you to a survivor |

### Tank rock throw

| Command | Key | Throw |
|---|---|---|
| `!overhand` | Reload | Two-handed overhand |
| `!underhand` | Use | Underhand |
| `!overonehand` | M2 | One-handed overhand |

### Survivors

| Command | What it does |
|---|---|
| `!secondary` | Turns on/off switching to the melee weapon when you pick one up |

---

## Fun

| Command | What it does |
|---|---|
| `!coinflip` / `!cf` / `!flip` | Flips a coin (heads or tails) |
| `!roll [number]` / `!picknumber [number]` | Rolls a die. Ex.: `!roll 20` |

---

## Server rules

- **Friendly fire:** repeatedly damaging your own team gets you kicked automatically, and the game is paused.
- **AFK:** during ready-up, players who stay AFK for too long are moved to spectators when someone else is waiting to play.
- **Lerp:** if your lerp is outside the allowed range, you can't claim a slot with `!slot`, and the server shows the commands to fix it. Paste them into your console:

```
cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100
```

Need help? Talk to an admin on the server.
