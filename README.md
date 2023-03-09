# automata v.0.1.2
### A minetest mod for growing various cellular automata, including conway's game of life and giant procedural trees.
Now with sound!

![3Dautomata](https://user-images.githubusercontent.com/25610408/224127381-1d18b4f3-ab54-4dd1-ae6c-861a62127414.png)

### Installation
like any minetest mod just install the mod as "automata" in your mods folder

### What it Adds
2 Node types, 1 Tool, 1 Chat command

### Depends on
Nothing, optionally depends on WorldEdit in order to use chat command "//owncells ( see https://github.com/Uberi/Minetest-WorldEdit )

This mod provides a "Programmable" Cellular Automata block (Inactive Cell) which you place, then you select the Remote Control tool and punch it to bring up the activation form. Once activated, Inactive Cells become Active Cells and start growing according to the rules you've set. Active Cells turn into Inactive Cells when dug. 

![screenshot_171106351](https://cloud.githubusercontent.com/assets/12679496/8151532/cc76388c-12cc-11e5-8b88-5fb614530cc9.png) ![screenshot_170757605](https://cloud.githubusercontent.com/assets/12679496/8151497/23d0be64-12cc-11e5-9de6-b205246f328f.png)

### The Rules Form
"Using" the Remote will bring up a form, Cstom rules can be entered in "code" in the survival/birth format, for example, conway cells are 8 neighbors, rule 23/3 which means if there are 3 neighbors an empty cell turns on, and already-active cells stay on if they have two or three neighbors, otherwise they turn off. (there are many online collections of Game of Life entities: http://www.argentum.freeserve.co.uk/lex.htm )

Remember that zero is a valid option (for survival at least, not birth -- in this version it is ignored) so that single nodes will grow with rules like n=4, 01234/14. The rest of the form fields also have defaults, but if set allow you to control the direction of growth, the plane that the automata operate in, the trail of dead cells they leave behind (can be set to "air"), etc.

1D automata follow the NKS "rules" as per: http://www.wolframscience.com/nksonline/page-53 . They also require an additional parameter for the calculation axis, obviously the growth axis and calculation axis can't be the same. 2D automata only need the growth axis set, even if growth is set to zero, because the calculation plane is implied by the growth axis (perpendicular to it). 3D automata actually have less options since their growth and calculation directions are all axis. For automata to grow properly, their trail should either be set to air, or they need to be set to "destructive" so that any trail they leave doesn't impede their natural growth in a later iteration.

Trees are an example of a 3D automata with non-totalistic rules meaning that not just the total neighbor count is considered but rather specific neighbor states are considered like in the case of 1D automata. Trees are also probabilistic and these probabilities can be adjusted in the form to get different growth characteristics.

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

For other known issues and planned improvements see: https://github.com/bobombolo/automata/issues

## New since v.0.1.1
- sound to accompany each growth cycle that is tuned to the pattern itself from total cell count, birth count and death count
- the speed of growth can now be controlled by setting a delay in miliseconds.
- RAINBOW mode has been changed to sequences, for which there is a new tab

## New since v.0.1.0
- tree mode has been added. Trees are an example of a non-totalistic, probabilistic 3D cellular automata (26n). The Tree tab allows the user to control the probabilities and heights of the growth.

## New since v.0.0.9
- zero-neighbor-birth is now supported within the extent of the pattern (not in the infinite field, alas)

## New since v.0.0.8
- added chat command "//owncells" for activating automata blocks created by worldedit or reactivating cells orphaned by quit/crash (addresses import/export, persistence, cleanup of orphaned cells)
- fixed bug in manage tab form
- fixed bug in digging automata blocks
- field for conversion of NKS codes to readable codes for 1D and 2D patterns
- fixed bug preventing popup forms from showing (need better solution see issue #30)
- clicking on a LIF in the import tab shows a summary of the pattern

## New since v.0.0.7
- major efficiency boost thanks to:
    - re-factored to use voxelManip exclusively, eliminate unnecessary calls,
    - no reading from the map, most indexes and positions calculated by arithmetic
- ability to add more generations to a finished pattern
- easter egg: enter RAINBOW as the trail field and the pattern trail will be colored wool
- inactive cells now owned per-player (but any cell can be dug by anyone)

## New since v.0.0.6
- fixed a bug when pausing patterns in manage tab
- improved efficiency by double by storing hashed positions with their actual positions ie, {x,y,z} to reduce calls to minetest.hash_node_position() and minetest.get_position_from_hash()
- removed garbage code (duplicates from bad merge)

## New since v.0.0.5
- fixed some mashed up code from merge (duplicate minetest.register()s)
- refactored the growth period to be proportional to math.log(cell_count) (in seconds)

## New since v.0.0.4
- implemented the Lua Voxel Manipulator instead of set_node()
- small form bug fixes
- crafting recipes

## New since v.0.0.3
- improved form with management tab, better validation, persistence
- 1D automata introduced
- 3D automata introduced
- ability to start a single-cell automata of any type at player's current position
- "Manage" tab allows monitoring of your patterns, including pausing and resuming
- patterns can be set to be destructive or respect the environment


## New since v.0.0.2
- menu for creating Game of Life entities from a library of .lif v.1.05 files at current location

## New since v.0.0.1
- multiple cell activation solved with Remote Control
- eliminated all but two node types, active and inactive
- eliminated reliance on minetest.register_abm, node metadata
- eliminated use of NKS codes, now using 3/23 format
- patterns operate in all planes
- patterns can grow in either direction at any distance per iteration, or stay in plane
- efficiency greatly improved, started maintaining pmin and pmax
- much improved rule form and form validation

## License
Author: bobomb, License: WTFPL

## Screenshots

2D "Single" mode

![2Dform](https://user-images.githubusercontent.com/25610408/224129373-e1f3f2cf-0e8f-4f1b-8ffa-7e8231a77fb9.png)
![2Dresult](https://user-images.githubusercontent.com/25610408/224129861-f09c71be-e373-4a2e-8ab0-691b157272d4.png)

Game of Life "Import" mode

![importLIF](https://user-images.githubusercontent.com/25610408/224130826-1a83a988-e17c-4ede-894b-1e18f1502d64.png)
![importResult](https://user-images.githubusercontent.com/25610408/224131164-bb7e2fdc-c85d-4320-86d8-6034f3d33a2f.png)

"Activate" mode

![placeCell](https://user-images.githubusercontent.com/25610408/224131678-1a16c74e-ace3-4f67-984b-78caa76777dc.png)

"Tree" mode
![treeForm](https://user-images.githubusercontent.com/25610408/224132113-e5441cb3-b86e-4579-963c-04bca71ecb27.png)
![treeResult](https://user-images.githubusercontent.com/25610408/224132385-b5d31a6a-e335-4322-85ca-0b96bf69094c.png)

1D Automata rule 90

![1Dform](https://user-images.githubusercontent.com/25610408/224133031-d622584c-8ca2-4e40-9109-9b966ee02b13.png)
![1Dresult](https://user-images.githubusercontent.com/25610408/224133277-87914a48-ec2c-49a2-9b27-c3e9cde91a73.png)

3D Automata

![3Dform](https://user-images.githubusercontent.com/25610408/224133889-71c2d34f-aa7a-4f08-9ed3-f12fa8ddd44e.png)
![3Dresult](https://user-images.githubusercontent.com/25610408/224134169-8af07d33-cb4d-4cf1-96e0-8be099ae6c56.png)

"Manage" tab

![manage](https://user-images.githubusercontent.com/25610408/224134541-d46b7754-34d8-4e3c-b4a4-462f40998c6f.png)

"Sequences"

![sequences](https://user-images.githubusercontent.com/25610408/224130322-bb2916b8-604a-4b46-86f0-fc04bf80b0fc.png)
