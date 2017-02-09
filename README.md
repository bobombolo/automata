# automata v.0.1.0
### A minetest mod for growing various cellular automata, including conway's game of life...

### Installation
like any minetest mod just install the mod as "automata" in your mods folder

### What it Adds
2 Node types, 1 Tool, 1 Chat command

### Depends on
Nothing, optionally depends on WorldEdit in order to use chat command "//owncells ( see https://github.com/Uberi/Minetest-WorldEdit )

This mod provides a "Programmable" Cellular Automata block (Inactive Cell) which you place, then you select the Remote Control tool and punch it to bring up the activation form. Once activated, Inactive Cells become Active Cells and start growing according to the rules you've set. Active Cells turn into Inactive Cells when dug. 

![screenshot_171106351](https://cloud.githubusercontent.com/assets/12679496/8151532/cc76388c-12cc-11e5-8b88-5fb614530cc9.png) ![screenshot_170757605](https://cloud.githubusercontent.com/assets/12679496/8151497/23d0be64-12cc-11e5-9de6-b205246f328f.png)

### The Rules Form
"Using" the Remote will bring up a form, this form can be left blank to default to Conway's Game of Life rules. Otherwise custom rules can be entered in "code" in the survival/birth format, for example, conway cells are 8 neighbors, rule 23/3 which means if there are 3 neighbors an empty cell turns on, and already-active cells stay on if they have two or three neighbors, otherwise they turn off. (there are many online collections of Game of Life entities: http://www.argentum.freeserve.co.uk/lex.htm )

Remember that zero is a valid option (for survival at least, not birth -- in this version it is ignored) so that single nodes will grow with rules like n=4, 01234/14. The rest of the form fields also have defaults, but if set allow you to control the direction of growth, the plane that the automata operate in, the trail of dead cells they leave behind (can be set to "air"), etc.

1D automata follow the NKS "rules" as per: http://www.wolframscience.com/nksonline/page-53 . They also require an additional parameter for the calculation axis, obviously the growth axis and calculation axis can't be the same. 2D automata only need the growth axis set, even if growth is set to zero, because the calculation plane is implied by the growth axis (perpendicular to it). 3D automata actually have less options since their growth and calculation directions are all axis. For automata to grow properly, their trail should either be set to air, or they need to be set to "destructive" so that any trail they leave doesn't impede their natural growth in a later iteration.

The remote now has a "Manage" tab which allows you to see your own patterns and pause or resume them. Exporting from that tab is soon to come.

### Mode 1, activating inactive cells you have placed in the map:
When you hit "Activate" all inactive cells you have placed will start growing (this option will be missing if no inactive cells have been placed).

### Mode 2, activating a single node at your current location
When you hit "Single" a single cell will be placed at your current location and the rules you have filled out will be applied. This means the cell will die unless it has a zero in the survival rules: 0xx/xxx eg, 01234/14

### Mode 3, importing a Game of Life entity from the supplied .LIF collection 
Alternatively you can select a Game of Life pattern from the right-hand list. Double clicking will give a description. Some of these patterns are extremely large and are actually more like huge machines made of smaller patterns set in precise relation to eachother. Clicking "Import" will create the selected pattern, with the selected rules, relative to your current location. (Most of these patterns are intended for standard Conway 23/3 rules but some are intended for variations on these rules. If that is the case the alternate rules, or any you have entered, will be used -- .LIF collection by Al Hensel http://www.ibiblio.org/lifepatterns/lifebc.zip )

### Mode 4, using WorldEdit to set up patterns, import patterns, set up random field, etc.
If worldedit is installed, this mod adds a chat command, "//owncells" which allows capturing abandoned automata blocks (active or inactive, abandoned by player or game quit/crash) as well as capturing blocks created by worldedit (which until now have not been useful). This means that by marking a worldedit region, using "//replace stone automata:inactive" or "//mix air automata:inactive", etc, following up with "//owncells" will add these blocks to your "inactive blocks" so that you can activate them with the remote control. You can also mark a reqion around an aborted set of active blocks, or inactive blocks, and as long as they are not owned by a player still in the game (which they won't be if the game was quit and restarted) they also will be added to your inactive blocks to be activated by remote. (note: digging individual blocks does not respect ownership in any way, and manually digging an active block will remove it from whatever pattern it is part of as long as the pattern isn't already past that block in a current grow cycle, as will an inactive block that is dug be removed from any other player's inactive blocks.)

## Known Issues
- Large patterns (particularly 3D patterns, can cause serious lag)
- zero-neighbor birth rules ( odd numbered NKS codes ) are implemented for cells inside the pattern's rectangular extent, not, obviously, for the entire infinite field. ways of faking this might be addressed in future releases but it is disclosed here that this implementation will have a unique effect on such rules' patterns compared to software that assumes an infinite field for each iteration...

## Next Steps in Development (for v.0.2.0 milestone)
- importing from a larger library of saved patterns (.rle, .cells and .lif v1.06 support) http://conwaylife.com/wiki/Main_Page and showing a summary in the form
- an "Admin" tab visible to ops
- a priv for using this mod at all, or using destructive mode at least
- improve import / export / persistence functionality
- detection of dead (stable) patterns or sections of patterns
- other efficiency improvements to make calculations go faster

- non-totalistic rules for 2D and 3D where exact combinations of neighbors can be specified (ambitious)
- neighborhoods of depth greater than 1, as well as definable neighborhood shapes
- wireworld automata
- continuous automata and colorized automata
- zero neighbor birth rules applied to the entire "infinite field" rather than current approach
- cells that can change their own rules or use different rules give iteration number
- automata based on foldings, transformations, scale-repetitions, etc

For other known issues and planned improvements see: https://github.com/bobombolo/automata/issues

##New since v.0.0.9
- zero-neighbor-birth is now supported within the extent of the pattern (not in the infinite field, alas)

##New since v.0.0.8
- added chat command "//owncells" for activating automata blocks created by worldedit or reactivating cells orphaned by quit/crash (addresses import/export, persistence, cleanup of orphaned cells)
- fixed bug in manage tab form
- fixed bug in digging automata blocks
- field for conversion of NKS codes to readable codes for 1D and 2D patterns
- fixed bug preventing popup forms from showing (need better solution see issue #30)
- clicking on a LIF in the import tab shows a summary of the pattern

##New since v.0.0.7
- major efficiency boost thanks to:
    - re-factored to use voxelManip exclusively, eliminate unnecessary calls,
    - no reading from the map, most indexes and positions calculated by arithmetic
- ability to add more generations to a finished pattern
- easter egg: enter RAINBOW as the trail field and the pattern trail will be colored wool
- inactive cells now owned per-player (but any cell can be dug by anyone)

##New since v.0.0.6
- fixed a bug when pausing patterns in manage tab
- improved efficiency by double by storing hashed positions with their actual positions ie, {x,y,z} to reduce calls to minetest.hash_node_position() and minetest.get_position_from_hash()
- removed garbage code (duplicates from bad merge)

##New since v.0.0.5
- fixed some mashed up code from merge (duplicate minetest.register()s)
- refactored the growth period to be proportional to math.log(cell_count) (in seconds)

##New since v.0.0.4
- implemented the Lua Voxel Manipulator instead of set_node()
- small form bug fixes
- crafting recipes

##New since v.0.0.3
- improved form with management tab, better validation, persistence
- 1D automata introduced
- 3D automata introduced
- ability to start a single-cell automata of any type at player's current position
- "Manage" tab allows monitoring of your patterns, including pausing and resuming
- patterns can be set to be destructive or respect the environment


##New since v.0.0.2
- menu for creating Game of Life entities from a library of .lif v.1.05 files at current location

##New since v.0.0.1
- multiple cell activation solved with Remote Control
- eliminated all but two node types, active and inactive
- eliminated reliance on minetest.register_abm, node metadata
- eliminated use of NKS codes, now using 3/23 format
- patterns operate in all planes
- patterns can grow in either direction at any distance per iteration, or stay in plane
- efficiency greatly improved, started maintaining pmin and pmax
- much improved rule form and form validation

##License
Author: bobomb, License: WTFPL

##Screenshots

"Single" mode

![screenshot_2030436717](https://cloud.githubusercontent.com/assets/12679496/8044135/0b4ec964-0de8-11e5-9cc1-8a2c93e6fc1a.png)

![screenshot_2030482649](https://cloud.githubusercontent.com/assets/12679496/8044134/0b4c0a26-0de8-11e5-9b83-f38f1bfd6476.png)

"Import" mode

![screenshot_2030594267](https://cloud.githubusercontent.com/assets/12679496/8044137/0b579940-0de8-11e5-84d0-54588b532047.png)

![screenshot_2030616024](https://cloud.githubusercontent.com/assets/12679496/8044138/0b5d4340-0de8-11e5-8b84-6fe2a224337a.png)

![screenshot_11245761](https://cloud.githubusercontent.com/assets/12679496/8659575/2095d56e-2969-11e5-8cbb-a0e469373e5a.png)

"Activate" mode

![screenshot_2030738253](https://cloud.githubusercontent.com/assets/12679496/8044136/0b51f01c-0de8-11e5-84cf-36615741fc4b.png)

![screenshot_2030806016](https://cloud.githubusercontent.com/assets/12679496/8044139/0b643b1e-0de8-11e5-95df-e494ee3f5cbb.png)

1D Automata (uses NKS rules 0-255) (using RAINBOW mode)

![screenshot_32765381](https://cloud.githubusercontent.com/assets/12679496/8739282/f94baf2a-2bf6-11e5-939b-2a45fd057fc8.png)

3D Automata

![screenshot_168375193](https://cloud.githubusercontent.com/assets/12679496/8142096/e20f3642-112f-11e5-91c4-b7dde4739dec.png)

"Manage" tab

![screenshot_168492531](https://cloud.githubusercontent.com/assets/12679496/8142097/e210c25a-112f-11e5-9136-56ad3a99bb97.png)