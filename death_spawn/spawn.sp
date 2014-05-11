#if defined DEATH_SPAWN_SPAWN
	#endinput
#endif
#define DEATH_SPAWN_SPAWN

#define MAX_SIZE_PATH 55
#define MAX_SIZE_NAME 25

#define DEFAULT_MODEL "models/props_junk/watermelon01.mdl"

Spawn_spawnExplosion(eref, damage, radius)
{
	new Float:pos[3];
	GetEntPropVector(eref, Prop_Send, "m_vecOrigin", pos);
	
	new String:damagestr[10/*max int32 cip*/]
	IntToString(damage, damagestr, sizeof(damagestr));
	
	new String:radiusstr[10/*max int32 cip*/]
	IntToString(radius, radiusstr, sizeof(radiusstr));
	
	new explosion = CreateEntityByName("env_explosion");
	TeleportEntity(explosion, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(explosion, "iMagnitude", damagestr);
	DispatchKeyValue(explosion, "iRadiusOverride", radiusstr);
	DispatchSpawn(explosion)
	ActivateEntity(explosion);
	AcceptEntityInput(explosion, "Explode");
	AcceptEntityInput(explosion, "Kill");
	//DispatchKeyValue(explosion, "spawnflags", "0");
	/*
		FLAGS
        1 : No Damage
        2 : Repeatable
        4 : No Fireball
        8 : No Smoke
        16 : No Decal
        32 : No Sparks
        64 : No Sound
        128 : Random Orientation
        256 : No Fireball Smoke
        512 : No particles
        1024 : No DLights
        2048 : Don't clamp Min
        4096 : Don't clamp Max
        8192 : Damage above surface only
        16384 : Generic damage
	*/
}

Spawn_extractNameFromPath(String:path[], String:name[], nameLen)
{
	new read = 0, ptr = 0;
	
	while (read > -1) {
		
		ptr += read;
		
		read = SplitString(path[read], "/", "", 0);
	}
	
	strcopy(name, nameLen, path[ptr]);
}

//Command to spawn explosive object
Spawn_spawnAtCursor(index, Client, health, damage, radius, bool:breakOnTouch)
{
	//Get spawnable from db
	new String:spawnablePath[MAX_SIZE_PATH], String:spawnableName[MAX_SIZE_NAME];
	
	new spawnableId = DB_spawnableAt(index, spawnableName, sizeof(spawnableName), spawnablePath, sizeof(spawnablePath));
	
	//PrintToChat(Client, "[DS][ItemMismatchDebug] The item has id:%d and name:%s extracted from table model.", spawnableId, spawnableName);
	
	if (spawnableId < 0) return;
	
	Spawn_spawnAtCursorFromPath(spawnableName, spawnablePath, Client, spawnableId, health, damage, radius,  breakOnTouch);
}

Spawn_spawnAtCursorFromPath(String:itemName[], String:itemPath[], Client, id, health, damage, radius, bool:breakOnTouch)
{
	DB_addClient(Client);
	
	new Float:AbsAngles[3], Float:pos[3], Float:FurnitureOrigin[3];
		
	GetClientAbsAngles(Client, AbsAngles);	
	
	GetCollisionPoint(Client, pos);
	
	FurnitureOrigin[0] = pos[0];
	FurnitureOrigin[1] = pos[1];
	FurnitureOrigin[2] = (pos[2] + 15);
	
	new eIndex = Spawn_spawnAtCoords(FurnitureOrigin, AbsAngles, itemPath, health);
	
	if (id >= 0) Save_add(Client, eIndex, id, health, damage, radius, breakOnTouch);
	
	new String:msg[256];
	Format(msg, sizeof(msg), "anonymous %s", itemName);
	
	PMSG_add(eIndex, msg, -1, damage, radius, breakOnTouch);
	
	//PrintToChat(Client, "[DS] spawning eref:%d msg:%s", eIndex, msg);
	//PrintToChat(Client, "[DS][ItemMismatchDebug] The item was saved into PMSG with eref:%d and msg:%s.", eIndex, msg);
	
	//Log
	decl String:Name[255], String:SteamId[255];
	GetClientAuthString(Client, SteamId, 255);
	GetClientName(Client, Name, 255);
	LogAction(Client, Client, "[Death Spawn] Client %s <%s> spawned an object!", SteamId, Name);
	PrintToServer("[Death Spawn] Client %s <%s> spawned an object!", SteamId, Name);
}

Spawn_spawnAtCoords(Float:pos[3], Float:angles[3], String:path[], health)
{
	//Spawn stuff:	
	new Stuff = CreateEntityByName("prop_physics_override");
	
	TeleportEntity(Stuff, pos, angles, NULL_VECTOR);
	
	DispatchKeyValue(Stuff, "model", path);
	
	new String:healthstr[10];
	IntToString(health, healthstr, sizeof(healthstr));
	DispatchKeyValue(Stuff, "health", healthstr);
	//DispatchKeyValue(Stuff, "ExplodeDamage","120");
	//DispatchKeyValue(Stuff, "ExplodeRadius","256");
	
	//decl String:flags[5];
	//IntToString(8192, flags, sizeof(flags));
	
	DispatchKeyValue(Stuff, "spawnflags", "8192");
	
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
