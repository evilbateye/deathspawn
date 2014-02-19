#if defined DEATH_SPAWN_SPAWN
	#endinput
#endif
#define DEATH_SPAWN_SPAWN

#define MAX_SIZE_PATH 55
#define MAX_SIZE_NAME 25

#define DEFAULT_MODEL "models/props_junk/watermelon01.mdl"

//Command to spawn explosive object
Spawn_spawnAtCursor(index, Client, breakOnTouch, breakOnPressure)
{
	//Get spawnable from db
	new String:spawnablePath[MAX_SIZE_PATH], String:spawnableName[MAX_SIZE_NAME];
	
	new spawnableId = DB_spawnableAt(index, spawnableName, sizeof(spawnableName), spawnablePath, sizeof(spawnablePath));
	
	if (spawnableId < 0) return;
	
	Spawn_spawnAtCursorFromPath(spawnableName, spawnablePath, Client, spawnableId, breakOnTouch, breakOnPressure);
}

Spawn_spawnAtCursorFromPath(String:itemName[], String:itemPath[], Client, id, breakOnTouch, breakOnPressure)
{
	if (GetUserAdmin(Client) != INVALID_ADMIN_ID) {
			
		PrintToServer("Admin spawning item!");
		DB_addClient(Client);
	}
	
	new Float:AbsAngles[3], Float:pos[3], Float:FurnitureOrigin[3];
		
	GetClientAbsAngles(Client, AbsAngles);	
	
	GetCollisionPoint(Client, pos);
	
	FurnitureOrigin[0] = pos[0];
	FurnitureOrigin[1] = pos[1];
	FurnitureOrigin[2] = (pos[2] + 15);
	
	new eIndex = Spawn_spawnAtCoords(FurnitureOrigin, AbsAngles, itemPath, breakOnTouch, breakOnPressure);
	
	if (id >= 0) {
		
		Save_add(eIndex, id, Client);	
		
		new String:msg[256];
		Format(msg, sizeof(msg), "anonymous %s", itemName);
		
		PMSG_add(eIndex, msg, -1);
	}
	
	//Log
	decl String:Name[255], String:SteamId[255];
	GetClientAuthString(Client, SteamId, 255);
	GetClientName(Client, Name, 255);
	LogAction(Client, Client, "[Death Spawn] Client %s <%s> spawned an object!", SteamId, Name);
	PrintToServer("[Death Spawn] Client %s <%s> spawned an object!", SteamId, Name);
}

Spawn_spawnAtCoords(Float:pos[3], Float:angles[3], String:path[], breakOnTouch, breakOnPressure)
{
	//Spawn stuff:	
	new Stuff = CreateEntityByName("prop_physics_override");
	
	TeleportEntity(Stuff, pos, angles, NULL_VECTOR);
	
	DispatchKeyValue(Stuff, "model", path);
	DispatchKeyValue(Stuff, "health", "20");
	DispatchKeyValue(Stuff, "ExplodeDamage","120");
	DispatchKeyValue(Stuff, "ExplodeRadius","256");
	
	decl String:flags[5];
	IntToString(8192 + breakOnTouch * 16 + breakOnPressure * 32, flags, sizeof(flags));
	
	DispatchKeyValue(Stuff, "spawnflags", flags);
	
	DispatchSpawn(Stuff);
	
	ActivateEntity(Stuff);
	
	return Stuff;
}

stock GetCollisionPoint(client, Float:pos[3])
{
	decl Float:vOrigin[3], Float:vAngles[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace)) {
		
		TR_GetEndPosition(pos, trace);
		CloseHandle(trace);
		
		return;
	}
	
	CloseHandle(trace);
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients;
}
