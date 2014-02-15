/* Explosive Stuff Spawner inspired by KTM's Explosive Oildrum Spawner! */

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#include "dbi.inc"
#include "menus.inc"
#include "death_spawn/spawn.sp"
#include "death_spawn/db.sp"
#include "death_spawn/save.sp"

#define ITEMS_PER_PANEL 6
#define NEXT_CODE 1
#define PREV_CODE 2
#define NAV_BUTTONS_COUNT 2
#define INDEX_OFFSET 1

#define VERSION "2.14"
#define DESCRIPTION "Spawn an exploding Object!"
#define TITLE "Death Spawn"

/* Keep track of the top menu */
new Handle:hAdminMenu = INVALID_HANDLE;

new SelectedPanelPage[MAXPLAYERS + 1];

/* Number of spawnables in database */
new SpawnableCount = 0;

new String:CurrentMap[256];

//plugin info
public Plugin:myinfo = 
{
	name = TITLE,
	author = "evilbateye",
	description = DESCRIPTION,
	version = VERSION,
	url = "https://www.facebook.com/evilbateye"
}

public Action:EventRomShot(Handle:event, const String:name[], bool:dontBroadcast)
{
	DB_loadMap(CurrentMap);
	
	Save_clearAll();
	
	return Plugin_Continue;
}

//Plugin start
public OnPluginStart()
{
	//DB setup
	DB_setUp();	
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));	
	DB_addMap(CurrentMap);	
	SpawnableCount = DB_spawnableCount();
	HookEvent("nmrih_round_begin", EventRomShot);
	
	//Save setup
	Save_setUp();	
		
	CreateConVar("death_spawn_version", VERSION, DESCRIPTION, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_deathspawn", ConsoleCommand_Spawn, ADMFLAG_CUSTOM6, DESCRIPTION);
	RegAdminCmd("sm_deathspawn_save", ConsoleCommand_SaveMap, ADMFLAG_CUSTOM6, "save items spawned by client");
	RegAdminCmd("sm_deathspawn_clear", ConsoleCommand_ClearMap, ADMFLAG_CUSTOM6, "delete items spawned by client");
	RegAdminCmd("sm_deathspawn_clearall", ConsoleCommand_ClearWholeMap, ADMFLAG_CUSTOM1, "delete all db entries for current map");
		
	/* See if the menu plugin is already ready */
	new Handle:topmenu;
	
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)) {
		
		/* If so, manually fire the callback */
		OnAdminMenuReady(topmenu);
	}
}

public OnPluginEnd()
{
	DB_close();
	Save_close();
}

//Admin menu callback
public OnAdminMenuReady(Handle:topmenu)
{
	/* Block us from being called twice */
	if (topmenu == hAdminMenu) return;
 
	/* Save the handle */
	hAdminMenu = topmenu;
			
	/* Create our own category */
	new TopMenuObject:category_id = AddToTopMenu(hAdminMenu, 
							 "sm_deathspawn_topmenuCategory",
							 TopMenuObject_Category,
							 Handle_Category,
							 INVALID_TOPMENUOBJECT,
							 _,
							 ADMFLAG_CUSTOM6);
	
	if(category_id == INVALID_TOPMENUOBJECT) {
		
		PrintToServer("[Death Spawn] Menu creation error - category button creation fail.");
		
		return;
	}
	
	/* Add spawn button to category */
	AddToTopMenu(hAdminMenu, 
				 "sm_deathspawn_menuSpawn",
				 TopMenuObject_Item,
				 Handle_Spawn,
				 category_id,
				 "sm_deathspawn_menuSpawn",
				 ADMFLAG_CUSTOM6);
	
	AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuSaveMap",
				 TopMenuObject_Item,
				 Handle_SaveMap,
				 category_id,
				 "sm_deathspawn_menuSaveMap",
				 ADMFLAG_CUSTOM6);
	
	AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuClearMap",
				 TopMenuObject_Item,
				 Handle_ClearMap,
				 category_id,
				 "sm_deathspawn_menuClearMap",
				 ADMFLAG_CUSTOM6);
	
	AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuClearWholeMap",
				 TopMenuObject_Item,
				 Handle_ClearWholeMap,
				 category_id,
				 "sm_deathspawn_menuClearWholeMap",
				 ADMFLAG_CUSTOM1);
}

//Triggers when cathegory button is pressed
public Handle_Category(Handle:menu, TopMenuAction:action, TopMenuObject:object, param, String:buffer[], bufferLength)
{
	if (action == TopMenuAction_DisplayOption || action == TopMenuAction_DisplayTitle) {
	
		Format(buffer, bufferLength, TITLE);
	}
}

//Triggers when "spawn" button is pressed
public Handle_Spawn(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		
		Format(buffer, maxlength, "spawn");
		
	} else if (action == TopMenuAction_SelectOption) {
		
		DisplaySpawnableItems(param);
	}
}

//Display panel with spawnable items
DisplaySpawnableItems(client)
{		
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, DESCRIPTION);
	
	new itemsToShow = ITEMS_PER_PANEL;
	
	if (SelectedPanelPage[client] + ITEMS_PER_PANEL > SpawnableCount) itemsToShow = SpawnableCount % itemsToShow;
	
	DrawPanelItem(panel, "next");
	
	DrawPanelItem(panel, "prev");
	
	for (new i = SelectedPanelPage[client]; i < SelectedPanelPage[client] + itemsToShow; i++) {
		
		decl String:name[MAX_SIZE_NAME];
		
		DB_spawnableAt(i, name, sizeof(name));
		
		DrawPanelItem(panel, name);
	}
	
	SendPanelToClient(panel, client, Handle_PanelItems, MENU_TIME_FOREVER);
	
	CloseHandle(panel);
}

//Triggers when item button is pressed
public Handle_PanelItems(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Cancel) {
		
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE) {
			
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
		
	} else if (action == MenuAction_Select) {
		
		if (param2 == NEXT_CODE) {
			
			if (!(SelectedPanelPage[param1] + ITEMS_PER_PANEL > SpawnableCount)) SelectedPanelPage[param1] += ITEMS_PER_PANEL;
			
			DisplaySpawnableItems(param1);
			
			return;
		}
		
		if (param2 == PREV_CODE) {
			
			if (!(SelectedPanelPage[param1] - ITEMS_PER_PANEL < 0)) SelectedPanelPage[param1] -= ITEMS_PER_PANEL;
			
			DisplaySpawnableItems(param1);
			
			return;
		}
		
		if (param2 < 1 || param2 > ITEMS_PER_PANEL + NAV_BUTTONS_COUNT) return;
		
		new index = param2 - NAV_BUTTONS_COUNT - INDEX_OFFSET;
		
		if ((SelectedPanelPage[param1] + index) >= SpawnableCount) return;
						
		Spawn_spawnAtCursor(SelectedPanelPage[param1] + index, param1);
		
		DisplaySpawnableItems(param1);
	}
}

public Handle_SaveMap(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		
		Format(buffer, maxlength, "save client stuff");
		
	} else if (action == TopMenuAction_SelectOption) {
		
		DB_saveMap(CurrentMap, param);
	}
}

public Handle_ClearMap(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		
		Format(buffer, maxlength, "clear client stuff");
		
	} else if (action == TopMenuAction_SelectOption) {
		
		DB_clearMap(CurrentMap, param);
	}
}

public Handle_ClearWholeMap(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) {
		
		Format(buffer, maxlength, "clear map");
		
	} else if (action == TopMenuAction_SelectOption) {
		
		DB_clearWholeMap(CurrentMap);
	}
}

public OnMapStart()
{
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	DB_addMap(CurrentMap);
}

public OnEntityDestroyed(eIndex)
{
	Save_delete(eIndex);
}

public Action:ConsoleCommand_Spawn(Client, args)
{
	new String:arg1[MAX_SIZE_PATH];	
	
	if (args >= 1) GetCmdArg(1, arg1, sizeof(arg1));
	
	new id = DB_spawnablePathFromName(arg1, arg1, sizeof(arg1));
	
	Spawn_spawnAtCursorFromPath(arg1, Client, id);
	
	return Plugin_Handled;
}

public Action:ConsoleCommand_SaveMap(Client, args)
{
	DB_saveMap(CurrentMap, Client);
	
	return Plugin_Handled;
}

public Action:ConsoleCommand_ClearMap(Client, args)
{
	DB_clearMap(CurrentMap, Client);
	
	return Plugin_Handled;
}

public Action:ConsoleCommand_ClearWholeMap(Client, args)
{
	DB_clearWholeMap(CurrentMap);
	
	return Plugin_Handled;
}