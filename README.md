deathspawn
==========

Nmrih sourcemod plugin for spawning exploding items and saving them on a map.

There is an example database with some items and sql script in the database folder.

The plugin has it's own category accesible through sm_admin menu.

the plugin recognizes these basic commands:
	
	sm_deathspawn_explode <name|path> spawns an exploding item based on an item name or path.
	The name or path is selected from	deathspawn.sq3 database. You can also spawn an item 
	based on a path that isn't in the database, but that item can't be saved and doesn't 
	respawn when the game round reloads.
	
	sm_deathspawn_normal is same as above, but the item has the explode flags turned of. This
	is to ensure better manipulation with the item. When the item is placed at the desired
	location the player should insert the sm_deathspawn_save. This makes the item explodable
	again.
	
	sm_deathspawn_save takes all the items currently spawned on the map and saves them to 
	the database. When a new round starts the items are respawned on the coordinates they 
	were placed.
	
	sm_deathspawn_clear clears the memory. sm_deathspawn_save right after clear saves nothing
	to the database.
	
	sm_deathspawn_cleardb deletes all spawned items from the database, but only the items that
	were spawned by the admin that issued this command.
	
	sm_deathspawn_cleardball deletes all spawned items for the current map for all admins from
	the database.
