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
#include "death_spawn/pmsg.sp"
#include "death_spawn/settings.sp"

#define ITEMS_PER_PANEL 6
#define NEXT_CODE 1
#define PREV_CODE 2
#define NAV_BUTTONS_COUNT 2
#define INDEX_OFFSET 1

#define SETTINGS_BOT_CODE 1
#define SETTINGS_HP_CODE 2
#define SETTINGS_DMG_CODE 3
#define SETTINGS_RAD_CODE 4

#define CATEGORY_SPAWN "spawn explode"
#define CATEGORY_SAVE "save"
#define CATEGORY_CLEAR_MEM "clear mem"
#define CATEGORY_CLEAR_DB "clear db"
#define CATEGORY_CLEAR_WHOLE_DB "clear whole db"
#define CATEGORY_SETTINGS "settings"

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

//****************
// HOOK FUNCTIONS
//****************

//ModEvents.res
/*
"player_hurt"
	{
		"userid"	"short"   	// user ID who was hurt			
		"attacker"	"short"	 	// user ID who attacked
		"weapon"	"string" 	// weapon name attacker used
	}

"player_death"				// a game event, name may be 32 charaters long
	{
		"userid"	"short"   	// user ID who died				
		"attacker"	"short"	 	// user ID who killed
		"weapon"	"string" 	// weapon name killed used 
	}
	
"npc_killed"
	{
		"entidx"	"short"
	"killeridx"	"short"
		"isturned"	"bool"
	}
*/

public OnEntityDestroyed(entity) {
	new dummy;
	PMSG_del(entity, "", 0, dummy, dummy, dummy, bool:dummy);
	Save_deleteNoCLient(entity);
}

public Action:EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	//new uid = GetEventInt(event, "userid");
	//new entref = GetEventInt(event, "attacker");
	//PrintToChatAll("[EventPlayerDeath] user:%d died to eref:%d", uid, entref);
	return Plugin_Continue;
}

public Action:OnTimerLoadMap(Handle:timer)
{
	DB_loadMap(CurrentMap);
	
	return Plugin_Continue;
}

public Action:EventRomShot(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.5, OnTimerLoadMap);
	
	Save_clearAll();
			
	return Plugin_Continue;
}

public OnMapStart()
{
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	DB_addMap(CurrentMap);
}

bool:processIncident(victim, attacker, bool:touch)
{	
	if (attacker < 1 || attacker > MaxClients) { return false; }
	
	if (!IsClientInGame(attacker)) return false;
	
	new String:msg[256];
	new bool:breakOnTouch;
	new saveTableId, dmg, rad;
		
	if (!PMSG_del(victim, msg, sizeof(msg), saveTableId, dmg, rad, breakOnTouch)) {
		//PrintToChatAll("eref:%d not in PMSG table", victim);
		return false;
	}
	//PrintToChatAll("[DS] deleting from PMSG eref:%d msg:%s save.id:%d", victim, msg, saveTableId);
	
	if (touch && !breakOnTouch) return false;
	
	if (!AcceptEntityInput(victim, "Kill")) {
		//PrintToChatAll("Kill victim request failed.");
		return false;
	}
	
	//Create explosion
	Spawn_spawnExplosion(victim, dmg, rad);
	
	//TODO: remove only for the creator, dont iterate all clients
	Save_deleteNoCLient(victim);

	//PrintToChat(attacker, "You triggered %s!", msg);
	
	decl String:Name[255], String:SteamId[255];
	GetClientAuthString(attacker, SteamId, 255);
	GetClientName(attacker, Name, 255);
	LogAction(attacker, attacker, "[Death Spawn] Client %s <%s> triggered %s", SteamId, Name, msg);
	PrintToChatAll("[DS] %s triggered %s.", Name, msg);
		
	new clientTableId = DB_addClient(attacker);
	
	if (clientTableId < 0) return false;
	
	//PrintToChatAll("[OnTakeDamage] saving traplog entry clientid:%d saveid:%d", clientTableId, saveTableId);
	
	DB_trapTriggered(clientTableId, saveTableId);
	
	return true;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:infDamage, &damagetype)
{
	//PrintToChatAll("[OnTakeDamage] last attacker of %d is %d", victim, attacker);
	
	new hp = GetEntProp(victim, Prop_Data, "m_iHealth");
	
	if (infDamage < hp) return Plugin_Continue;
		
	//PrintToChatAll("[OnTakeDamage] %d has %d HP but damage inflicted is %f, killing victim", victim, hp, infDamage);
		
	processIncident(victim, attacker, false);
	
	return Plugin_Continue;
}

public Action:EndTouch(entity, other)
{
	processIncident(entity, other, true);
	
	return Plugin_Continue;
}

/*public Action:StartTouch(entity, other)
{
	PrintToChatAll("[StartTouch] %d touches %d", other, entity);
}*/

//******************
// PLUGIN LIFECYCLE
//******************

public OnPluginStart()
{
	//DB setup
	DB_setUp();	
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));	
	DB_addMap(CurrentMap);	
	SpawnableCount = DB_spawnableCount();
	HookEvent("nmrih_round_begin", EventRomShot);
	HookEvent("player_death", EventPlayerDeath)
			
	//Save setup
	Save_setUp();
	
	//PMSG setup
	PMSG_init();
	
	//Settings menu setup
	Menu_init();
		
	CreateConVar("death_spawn_version", VERSION, DESCRIPTION, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_deathspawn", ConsoleCommand_SpawnExploding, ADMFLAG_CUSTOM6, "spawn exploding object");
	//RegAdminCmd("sm_deathspawn_normal", ConsoleCommand_SpawnNormal, ADMFLAG_CUSTOM6, "spawn normal object");
	RegAdminCmd("sm_deathspawn_save", ConsoleCommand_SaveMap, ADMFLAG_CUSTOM6, "save items spawned by client");
	RegAdminCmd("sm_deathspawn_clear", ConsoleCommand_ClearMem, ADMFLAG_CUSTOM6, "delete from memory for client");
	RegAdminCmd("sm_deathspawn_cleardb", ConsoleCommand_ClearMap, ADMFLAG_CUSTOM6, "delete from db for client");
	//RegAdminCmd("sm_deathspawn_cleardball", ConsoleCommand_ClearWholeMap, ADMFLAG_CUSTOM1, "delete from db for all");
		
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
	PMSG_close();
}

//*********************
// ADMINMENU CALLBACKS
//*********************

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
				 "sm_deathspawn_menuSpawnExploding",
				 TopMenuObject_Item,
				 Handle_SpawnCategory,
				 category_id,
				 "sm_deathspawn_menuSpawnExploding",
				 ADMFLAG_CUSTOM6);
	
	AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuSaveMap",
				 TopMenuObject_Item,
				 Handle_SaveCategory,
				 category_id,
				 "sm_deathspawn_menuSaveMap",
				 ADMFLAG_CUSTOM6);
				 
	AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuMenu",
				 TopMenuObject_Item,
				 Handle_SettingsCategory,
				 category_id,
				 "sm_deathspawn_menuMenu",
				 ADMFLAG_CUSTOM6);
				 
	AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuClearMem",
				 TopMenuObject_Item,
				 Handle_ClearMemCategory,
				 category_id,
				 "sm_deathspawn_menuClearMem",
				 ADMFLAG_CUSTOM6);
	
	AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuClearMap",
				 TopMenuObject_Item,
				 Handle_ClearMapCategory,
				 category_id,
				 "sm_deathspawn_menuClearMap",
				 ADMFLAG_CUSTOM6);
	
	/*AddToTopMenu(hAdminMenu,
				 "sm_deathspawn_menuClearWholeMap",
				 TopMenuObject_Item,
				 Handle_ClearWholeMapCategory,
				 category_id,
				 "sm_deathspawn_menuClearWholeMap",
				 ADMFLAG_CUSTOM1);*/
}

public Handle_Category(Handle:menu, TopMenuAction:action, TopMenuObject:object, param, String:buffer[], bufferLength)
{
	if (action == TopMenuAction_DisplayOption || action == TopMenuAction_DisplayTitle) { Format(buffer, bufferLength, TITLE); }
}

/*DisplayFakeMainMenuPanel(client)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "death spawn");
	
	DrawPanelItem(panel, CATEGORY_CLEAR_DB);
	DrawPanelItem(panel, CATEGORY_CLEAR_MEM);
	DrawPanelItem(panel, CATEGORY_SAVE);
	DrawPanelItem(panel, CATEGORY_SETTINGS);
	DrawPanelItem(panel, CATEGORY_SPAWN);
			
	SendPanelToClient(panel, client, Handle_FakeMainMenu, MENU_TIME_FOREVER);
	CloseHandle(panel);
}*/

/*public Handle_FakeMainMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
		switch(param2) {
			case 1: {
				DB_clearWholeMap(CurrentMap);
				DisplayFakeMainMenuPanel(param1);
			}
			case 2: {
				Save_clear(param1);
				DisplayFakeMainMenuPanel(param1);
			}
			case 3: {
				DB_saveMap(CurrentMap, param1);
				DisplayFakeMainMenuPanel(param1);
			}
			case 4: DisplayCustomSettingsMenuPanel(param1);
			case 5: DisplaySpawnableItems(param1);
		}
	}
}*/

//Custom settings menu
public Handle_SettingsCategory(Handle:topmenu,
				   TopMenuAction:action,
				   TopMenuObject:object_id,
				   param,
				   String:buffer[],
				   maxlength)
{
	if (action == TopMenuAction_DisplayOption) { Format(buffer, maxlength, CATEGORY_SETTINGS);	}
	else if (action == TopMenuAction_SelectOption) { DisplayCustomSettingsMenuPanel(param); }
}

addSettingsOption(Handle:menu, String:keystr[], val)
{
	new String:text[20];
	Format(text, sizeof(text), "%s:%d", keystr, val);
	//DrawPanelItem(menu, text);
	AddMenuItem(menu, "", text);
}

DisplayCustomSettingsMenuPanel(client)
{
	/*new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "deathspawn settings");
	
	new mHP, mDmg, mRad, bool:mBot;
	Settings_get(client, mHP, mDmg, mRad, mBot);
	
	addSettingsOption(panel, "bot", mBot);
	addSettingsOption(panel, "hp", mHP);
	addSettingsOption(panel, "dmg", mDmg);
	addSettingsOption(panel, "rad", mRad);
				
	SendPanelToClient(panel, client, Handle_CustomSettings, MENU_TIME_FOREVER);
	CloseHandle(panel);*/
	
	new Handle:menu = CreateMenu(Handle_CustomSettings);
	SetMenuTitle(menu, "settings");
	SetMenuExitBackButton(menu, true);
	
	new mHP, mDmg, mRad, bool:mBot;
	Settings_get(client, mHP, mDmg, mRad, mBot);
	
	addSettingsOption(menu, "bot", mBot);
	addSettingsOption(menu, "hp", mHP);
	addSettingsOption(menu, "dmg", mDmg);
	addSettingsOption(menu, "rad", mRad);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Handle_CustomSettings(Handle:menu, MenuAction:action, param1, param2)
{	
	/*if (action == MenuAction_Select) {
		
		//test code
		new String:text[20];
		if (GetMenuItem(menu, param2, "", 0, _, text, sizeof(text)))
		{
			new String:pairs[2][10];
			ExplodeString(text, ":", pairs, sizeof(pairs), sizeof(pairs[]));
			
			new value = StringToInt(pairs[1]);
			
			if (strcmp(pairs[0], "bot") == 0) {
				
			} else if (strcmp(pairs[0], "hp") == 0) {
			
			} else if (strcmp(pairs[0], "dmg") == 0) {
			
			} else if (strcmp(pairs[0], "rad") == 0) {
			
			}
		}//end test code
		
		new mHP, mDmg, mRad, bool:mBot;
		Settings_get(param1, mHP, mDmg, mRad, mBot);
		
		switch(param2) {
			case SETTINGS_BOT_CODE: { Settings_set(param1, mHP, mDmg, mRad, !mBot); }
			case SETTINGS_HP_CODE: { Settings_set(param1, (mHP * 2) % 12700, mDmg, mRad, mBot); }
			case SETTINGS_DMG_CODE: { Settings_set(param1, mHP, (mDmg * 2) % 63000, mRad, mBot); }
			case SETTINGS_RAD_CODE: { Settings_set(param1, mHP, mDmg, (mRad * 2) % 12700, mBot); }
		}
		DisplayCustomSettingsMenuPanel(param1);
	}*/
	
	if (action == MenuAction_End) {	CloseHandle(menu); }
	else if (action == MenuAction_Cancel) {
		
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE) {
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
		
	} else if (action == MenuAction_Select) {
		
		new String:text[20];
		if (GetMenuItem(menu, param2, "", 0, _, text, sizeof(text)))
		{
			new String:pairs[2][10];
			ExplodeString(text, ":", pairs, sizeof(pairs), sizeof(pairs[]));
			
			new mHP, mDmg, mRad, bool:mBot;
			Settings_get(param1, mHP, mDmg, mRad, mBot);
			
			if (strcmp(pairs[0], "bot") == 0) Settings_set(param1, mHP, mDmg, mRad, !mBot);
			else if (strcmp(pairs[0], "hp") == 0) Settings_set(param1, (mHP * 2) % 12700, mDmg, mRad, mBot);
			else if (strcmp(pairs[0], "dmg") == 0) Settings_set(param1, mHP, (mDmg * 2) % 63000, mRad, mBot);
			else if (strcmp(pairs[0], "rad") == 0) Settings_set(param1, mHP, mDmg, (mRad * 2) % 12700, mBot);		
		}
		
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
			DisplayCustomSettingsMenuPanel(param1);
		}
	}
}

//Spawn explosive menu handler
public Handle_SpawnCategory(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) { Format(buffer, maxlength, CATEGORY_SPAWN); }
	else if (action == TopMenuAction_SelectOption) { DisplaySpawnableItems(param); }
}

//Display panel with spawnable items
DisplaySpawnableItems(client, pos = 0)
{		
	/*new Handle:panel = CreatePanel();
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
	CloseHandle(panel);*/
	
	new Handle:menu = CreateMenu(Handle_PanelItems);
	SetMenuTitle(menu, DESCRIPTION);
	SetMenuExitBackButton(menu, true);
	
	for (new i = 0; i < SpawnableCount; i++) {
		
		decl String:name[MAX_SIZE_NAME];
		DB_spawnableAt(i, name, sizeof(name));
		
		decl String:info[10];
		IntToString(i, info, sizeof(info));
		AddMenuItem(menu, info, name);
	}
	
	DisplayMenuAtItem(menu, client, pos, MENU_TIME_FOREVER);
}

//Triggers when item button is pressed
public Handle_PanelItems(Handle:menu, MenuAction:action, param1, param2)
{
	/*if (action == MenuAction_Select) {
		
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
		
		if (param2 < 1 || param2 > ITEMS_PER_PANEL + NAV_BUTTONS_COUNT) { return; }
		new index = param2 - NAV_BUTTONS_COUNT - INDEX_OFFSET;
		if ((SelectedPanelPage[param1] + index) >= SpawnableCount) return;
		
		PrintToChat(param1, "[DS][ItemMismatchDebug] You clicked at item no. %d.", SelectedPanelPage[param1] + index);
		
		new mHP, mDmg, mRad, bool:mBot;
		Settings_get(param1, mHP, mDmg, mRad, mBot);
		Spawn_spawnAtCursor(SelectedPanelPage[param1] + index, param1, mHP, mDmg, mRad, mBot);
						
		DisplaySpawnableItems(param1);
	}*/
	
	if (action == MenuAction_End) {	CloseHandle(menu); }
	else if (action == MenuAction_Cancel) {
		
		if (hAdminMenu != INVALID_HANDLE) {
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
		
	} else if (action == MenuAction_Select) {
		
		new String:info[10];
		if (GetMenuItem(menu, param2, info, sizeof(info), _, "", 0)) {
			
			new i = StringToInt(info);
			//PrintToChat(param1, "[DS] Handle spawn menu, i:%d", i);
			
			new mHP, mDmg, mRad, bool:mBot;
			Settings_get(param1, mHP, mDmg, mRad, mBot);
			
			Spawn_spawnAtCursor(i, param1, mHP, mDmg, mRad, mBot);
			
			if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
				DisplaySpawnableItems(param1, i - (i % 5));
			}
		}
	}
}

public Handle_SaveCategory(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) { Format(buffer, maxlength, CATEGORY_SAVE); }
	else if (action == TopMenuAction_SelectOption) { 
		DB_saveMap(CurrentMap, param);
		
		if (hAdminMenu != INVALID_HANDLE) {
			DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
		}
	}
}

public Handle_ClearMemCategory(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) { Format(buffer, maxlength, CATEGORY_CLEAR_MEM); }
	else if (action == TopMenuAction_SelectOption) { 
		Save_clear(param);
		
		if (hAdminMenu != INVALID_HANDLE) {
			DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
		}
	}
}

public Handle_ClearMapCategory(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) { Format(buffer, maxlength, CATEGORY_CLEAR_DB); }
	else if (action == TopMenuAction_SelectOption) { 
		DB_clearMap(CurrentMap, param);
		
		if (hAdminMenu != INVALID_HANDLE) {
			DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
		}
	}
}

public Handle_ClearWholeMapCategory(Handle:topmenu,
					 TopMenuAction:action,
					 TopMenuObject:object_id,
					 param,
					 String:buffer[],
					 maxlength)
{
	if (action == TopMenuAction_DisplayOption) { Format(buffer, maxlength, CATEGORY_CLEAR_WHOLE_DB); }
	else if (action == TopMenuAction_SelectOption) { 
		DB_clearWholeMap(CurrentMap);
		
		if (hAdminMenu != INVALID_HANDLE) {
			DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
		}
	}
}

//****************************
// CONSOLE COMMANDS CALLBACKS
//****************************

public Action:ConsoleCommand_SpawnExploding(Client, args)
{
	decl String:arg1[MAX_SIZE_PATH], String:name[MAX_SIZE_NAME], String:path[MAX_SIZE_PATH];
	
	if (args >= 1) GetCmdArg(1, arg1, sizeof(arg1));
		
	new id = DB_IdNamePath(arg1, name, sizeof(name), path, sizeof(path));
	
	new mHP, mDmg, mRad, bool:mBot;
	Settings_get(Client, mHP, mDmg, mRad, mBot);
	
	if (id < 0) {
		Spawn_extractNameFromPath(arg1, name, sizeof(name));
		Spawn_spawnAtCursorFromPath(name, arg1, Client, -1, mHP, mDmg, mRad, mBot);
	} else Spawn_spawnAtCursorFromPath(name, path, Client, id, mHP, mDmg, mRad, mBot);
	
	return Plugin_Handled;
}

/*public Action:ConsoleCommand_SpawnNormal(Client, args)
{
	new String:arg1[MAX_SIZE_PATH], String:name[MAX_SIZE_NAME], String:path[MAX_SIZE_PATH];
	
	if (args >= 1) GetCmdArg(1, arg1, sizeof(arg1));
	
	new id = DB_IdNamePath(arg1, name, sizeof(name), path, sizeof(path));
	
	if (id < 0) {
		
		Spawn_extractNameFromPath(arg1, name, sizeof(name));
		
		Spawn_spawnAtCursorFromPath(name, arg1, Client, -1, 1, 1);
		
	} else Spawn_spawnAtCursorFromPath(name, path, Client, id, 0, 0);
	
	return Plugin_Handled;
}*/

public Action:ConsoleCommand_SaveMap(Client, args)
{
	DB_saveMap(CurrentMap, Client);
	return Plugin_Handled;
}

public Action:ConsoleCommand_ClearMem(Client, args)
{
	Save_clear(Client);
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