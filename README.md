deathspawn
==========

nmrih sourcemod plugin for spawning exploding items and saving them on a map

There is an example database with some items and sql script in the database folder.

The plugin has it's own category accesible through sm_admin menu.

the plugin recognizes these basic commands:
	
	sm_deathspawn <name|path> spawns an exploding item based on an item name or path.
	The name or path is selected from	deathspawn.sq3 database. You can also spawn an item 
	based on a path that isn't in the database, but that item can't be saved and doesn't 
	respawn when the game round reloads.
	
	sm_deathspawn_save takes all the items currently spawned on the map and saves them to 
	the database. When a new round starts the items are respawned on the coordinates they 
	were placed.
	
	sm_deathspawn_clear deletes all spawned items, but only the items that were spawned by 
	the admin that issued this command.
	
	sm_deathspawn_clearall deletes all spawnd items for the current map for all admins.
