# PadRP

A controller-first roleplay suite for World of Warcraft.

PadRP is designed for players who want a smooth, low-friction RP experience on a gamepad, Steam Deck, or couch setup—without giving up full profile customization or compatibility with the rest of the RP community. *(Works seamlessly with mouse & keyboard too!)*

## Why PadRP?

Traditional RP addons are built around mouse-heavy character sheets and dozens of keybinds. PadRP rethinks the RP workflow for controllers:

* **Native Gamepad Navigation:** Navigate tabs, lists, profiles, and dossiers using `[LB]`/`[RB]`, D-pad, `[A]` to select, and `[B]` to go back.
* **Cross-Addon Compatibility (MSP):** Powered by the Mary Sue Protocol (`LibMSP`), PadRP communicates directly with Total RP 3 (TRP3), MyRolePlay (MRP), XRP, and other MSP-compatible addons. You can read their profiles, and they can read yours.
* **Zero Setup Clutter:** Everything you need for everyday roleplay is ready out of the box—no extra modules or complex configuration required.

## Main Features

### 360° RP Flyout Wheel
A radial wheel built for mid-stride RP on a controller (aim with the Right Stick or D-Pad, flip pages with `[LB]`/`[RB]`, confirm with `[A]`, back with `[B]`):
* **RP Status Hub:** Toggle IC / OOC, change Walk-Up status (Welcome / Ask First / Closed), swap "Currently" presets, `/sit`, or open the main PadRP menu.
* **Base Emotes:** Ships with 16 starter emotes ready to go, plus a searchable catalog of 150+ WoW emotes you can toggle on/off and customize with your own icons in the Emotes tab.
* **Custom `/e` Emotes:** Create and trigger your own custom emote lines with `%name` and `%target` token substitution.
* **Target Standing:** Quickly tag your current player target's standing (Ally, Friendly, Neutral, Acquaintance, Marked, Unfriendly, Rival).
* **Dice Roller:** Built-in d20, d100, d12, d10, d8, d6, d4, and Coin Flip—no typing `/roll` required.

### Character Profiles & Dossier
* **Full Profile Editor:** Customize your character's identity, titles, custom colors, RP style preferences, First Glances (up to 5 slots with custom icons), appearance, and backstory/history.
* **Profile Manager:** Create, switch, cycle, back up, and share profiles via export/import strings.
* **RP Directory:** Keep track of characters you've encountered, organized by standing.
* **Player Dossier:** Inspect other players' full RP profiles in a clean, controller-friendly window.

### World & Target Views
* **Enhanced Tooltips:** TRP3-style player tooltips showing RP names, titles, IC/OOC status, walk-up flags, and standing.
* **Target HUD Toast:** Optional floating notification when targeting or hovering over RP players for quick profile inspection.
* **Friendly Nameplates:** Optional RP names, class colors, `IC | OOC` status tags, and standing indicators directly on friendly nameplates.

### Gratitude Studio
* Automatically detects helpful buffs, heals, resurrections, summons, and portals from other players.
* Respond automatically or on-demand via **Quick Thank** using customizable IC, OOC, resurrection, summon, and special phrase pools—with built-in cooldowns and anti-spam protection.

### RP Chat Tools
* Display RP names in chat.
* Automatic long-message splitting with `...` continuation markers.
* Character name / nickname mention alerts and `[Target]` chat highlighting.
* Quick spoken-language cycling.

## Installation

1. Download the latest release of **PadRP**.
2. Extract the `PadRP` folder into your World of Warcraft addons directory:
   ```text
   World of Warcraft\_retail_\Interface\AddOns\PadRP
   ```
3. Restart World of Warcraft (or type `/reload` if updating an existing install).

## Getting Started & Controls

### Slash Commands

| Command | Action |
| :--- | :--- |
| `/padrp` or `/padtoggle` | Open or close the main PadRP menu |
| `/padwheel` or `/padrp wheel` | Open or close the 360° RP Flyout Wheel |
| `/padrp minimap` | Toggle the minimap button |
| `/padrp scan` | Manually scan nearby players for RP profiles |
| `/padrp resetcam` | Restore gamepad camera speed if the wheel was interrupted |

### Controller Keybindings & Macro Tip

Open **Options → Keybindings → AddOns → PadRP** to bind any of the following to a single button:
* Open / Close RP Flyout Wheel
* Open / Close Main Menu
* Toggle IC / OOC
* Cycle Walk-Up Status
* Sit / Rest (`/sit`)
* Quick Thank Helper
* Inspect Target RP

> **Tip for Trigger Combos (Native Gamepad):** WoW's built-in Keybindings menu only accepts a single controller button per bind. If you want to open the Flyout Wheel with a trigger combo (like `LT` + a button), create a simple WoW macro containing `/padwheel` and place it on any action bar slot on your trigger layer.

## Solo-Dev Note

PadRP was prototyped and built by one developer out of a love for roleplaying on a controller. If you run into a bug, have a Steam Deck / gamepad quirk to report, or have an idea for future updates as they come, feel free to open an issue or leave a comment where you downloaded the addon.

Thanks for trying out PadRP—have fun out there!

You can find me in game on Forever's RP Servers: **Malachar Grey**
