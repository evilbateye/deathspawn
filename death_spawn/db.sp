#if defined DEATH_SPAWN_DB
	#endinput
#endif
#define DEATH_SPAWN_DB

#include <sourcemod>

#define DATABASE_NAME "death_spawn"

static Handle:db = INVALID_HANDLE;

DB_trapTriggered(clientTableId, saveTableId)
{
	decl String:query[256];	
	Format(query, sizeof(query), "SELECT * FROM traplog WHERE client_id='%d' AND save_id='%d'", clientTableId, saveTableId);
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return;
	}
	
	if (SQL_FetchRow(qHandle))
		Format(query, sizeof(query), "UPDATE traplog SET deaths=deaths+1 WHERE client_id='%d' AND save_id='%d'", clientTableId, saveTableId);
	else
		Format(query, sizeof(query), "INSERT INTO traplog (client_id, save_id) VALUES('%d','%d')", clientTableId, saveTableId);
	
	CloseHandle(qHandle);
	
	if (!SQL_FastQuery(db, query)) PrintToServer("Failed to query %s", query);
}

DB_addMap(String:mapName[])
{
	decl String:query[256];
	
	Format(query, sizeof(query), "SELECT * FROM map WHERE name='%s'", mapName);
	
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return;
	}
	
	if (SQL_FetchRow(qHandle)) {
		CloseHandle(qHandle);
		return;
	}
	
	Format(query, sizeof(query), "INSERT INTO map (name) VALUES ('%s')", mapName);
	
	if (!SQL_FastQuery(db, query)) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
	}
	
	CloseHandle(qHandle);
}

DB_loadMap(String:map[])
{
	new String:query[256];
	
	Format(query, sizeof(query), "SELECT * FROM model \
		JOIN save ON model.id=save.model_id \
		JOIN map ON save.map_id=map.id \
		WHERE map.name='%s'", map);
	
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return;
	}
	
	while (SQL_FetchRow(qHandle)) {
		
		new Float:pos[3], Float:angles[3];
		
		pos[0] = SQL_FetchFloat(qHandle, 4);
		pos[1] = SQL_FetchFloat(qHandle, 5);
		pos[2] = SQL_FetchFloat(qHandle, 6);
		
		angles[0] = SQL_FetchFloat(qHandle, 7);
		angles[1] = SQL_FetchFloat(qHandle, 8);
		angles[2] = SQL_FetchFloat(qHandle, 9);
		
		new String:path[MAX_SIZE_PATH];
		SQL_FetchString(qHandle, 2, path, sizeof(path));
		
		new eref = Spawn_spawnAtCoords(pos, angles, path, SQL_FetchInt(qHandle, 13), SQL_FetchInt(qHandle, 14));
		
		new String:msg[256];
		SQL_FetchString(qHandle, 13, msg, sizeof(msg));
		
		PMSG_add(eref, msg, SQL_FetchInt(qHandle, 3));
	}
	
	CloseHandle(qHandle);
}

DB_addClient(client)
{
	decl String:steamId[256], String:query[256], String:clientName[256];
	GetClientAuthString(client, steamId, sizeof(steamId));
	GetClientName(client, clientName, sizeof(clientName));
	
	Format(query, sizeof(query), "SELECT * FROM client WHERE authstring='%s'", steamId);
	
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return -1;
	}
	
	if (SQL_FetchRow(qHandle)) {
		
		new clientTableId = SQL_FetchInt(qHandle, 0);
		
		CloseHandle(qHandle);
		
		return clientTableId;
	}
	
	Format(query, sizeof(query), "INSERT INTO client (name, authstring) VALUES ('%s','%s')", clientName, steamId);
	
	if (!SQL_FastQuery(db, query)) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		CloseHandle(qHandle);
		return -1;
	}
	
	Format(query, sizeof(query), "SELECT * FROM client WHERE authstring='%s'", steamId);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return -1;
	}
	
	if (!SQL_FetchRow(qHandle)) {
		
		PrintToServer("Failed to query %s", query);
		CloseHandle(qHandle);
		return -1;
	}
	
	new clientTableId = SQL_FetchInt(qHandle, 0);
	
	CloseHandle(qHandle);
	
	return clientTableId;
}

static DB_getId(String:table[], String:whereCol[], String:whereVal[])
{
	decl String:query[256];
	Format(query, sizeof(query), "SELECT * FROM %s WHERE %s='%s'", table, whereCol, whereVal);
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return -1;
	}
	
	if (!SQL_FetchRow(qHandle)) {
		
		CloseHandle(qHandle);
		PrintToServer("Failed to fetch %s from %s", whereVal, table);
		return -1;
	}
	
	new id = SQL_FetchInt(qHandle, 0);
	CloseHandle(qHandle);
	return id;
}

DB_getString(String:str[], strLen, colidx, String:table[], val)
{
	decl String:query[256];
	Format(query, sizeof(query), "SELECT * FROM %s WHERE id='%d'", table, val);
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return;
	}
	
	if (!SQL_FetchRow(qHandle)) {
		
		CloseHandle(qHandle);
		PrintToServer("Failed to fetch id from %s", table);
		return;
	}	
	
	SQL_FetchString(qHandle, colidx, str, strLen);
	
	CloseHandle(qHandle);
}

DB_IdNamePath(String:nameOrPath[], String:name[], nameLen, String:path[], pathLen)
{
	decl String:query[256];
	Format(query, sizeof(query), "SELECT * FROM model WHERE name='%s' OR path='%s'", nameOrPath, nameOrPath);	
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return -1;
	}
	
	if (!SQL_FetchRow(qHandle)) {
		
		CloseHandle(qHandle);
		PrintToServer("Failed to fetch model with name %s", nameOrPath);
		return -1;
	}
	
	SQL_FetchString(qHandle, 1, name, nameLen);
	SQL_FetchString(qHandle, 2, path, pathLen);
	new id = SQL_FetchInt(qHandle, 0);
	
	CloseHandle(qHandle);
	
	return id;
}

DB_saveMap(String:map[], client)
{
	new mapId = DB_getId("map", "name", map);
	if (mapId < 0) return;
	
	decl String:steamId[256];
	GetClientAuthString(client, steamId, sizeof(steamId));
	new clientId = DB_getId("client", "authstring", steamId);
	if (clientId < 0) return;
			
	new size = Save_size(client);
	
	for (new i = 0; i < size; i++) {
		
		new entity[2];
		Save_at(entity, i, client);
		
		/* Make entity explodable in case it was spawned in normal mode */
		DispatchKeyValue(entity[0], "spawnflags", "8240");
		
		new Float:pos[3];
		GetEntPropVector(entity[0], Prop_Send, "m_vecOrigin", pos);  
		
		new Float:ang[3];
		GetEntPropVector(entity[0], Prop_Data, "m_angRotation", ang);
		
		decl String:itemName[MAX_SIZE_NAME];
		DB_getString(itemName, sizeof(itemName), 1, "model", entity[1]);
		
		decl String:playermsg[256];
		Format(playermsg, sizeof(playermsg), "anonymous %s", itemName);
	
		decl String:query[256];	
		Format(query, sizeof(query), "INSERT INTO save (x, y, z, ax, ay, az, model_id, map_id, client_id, msg) \
			VALUES ('%f', '%f', '%f', '%f', '%f', '%f', '%d', '%d', '%d', '%s')",
			pos[0], pos[1], pos[2], ang[0], ang[1], ang[2], entity[1], mapId, clientId, playermsg);
		
		if (!SQL_FastQuery(db, query)) {
		
			new String:error[256];
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
	}
	
	Save_clear(client);
}

DB_clearMap(String:map[], client)
{
	decl String:query[256], String:steamId[256];
	GetClientAuthString(client, steamId, sizeof(steamId));
	
	Format(query, sizeof(query), "SELECT * FROM save \
		JOIN map ON save.map_id=map.id \
		JOIN client ON save.client_id=client.id \
		WHERE map.name='%s' AND client.authstring='%s'", map, steamId);
	
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return;
	}
	
	while (SQL_FetchRow(qHandle)) {
		
		new saveId = SQL_FetchInt(qHandle, 0);
		
		Format(query, sizeof(query), "DELETE FROM save WHERE id='%d'", saveId);
		
		if (!SQL_FastQuery(db, query)) {
			
			new String:error[256];
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
	}
	
	CloseHandle(qHandle);
}

DB_clearWholeMap(String:map[])
{
	decl String:query[256];
	
	Format(query, sizeof(query), "SELECT * FROM save \
		JOIN map ON save.map_id=map.id \
		WHERE map.name='%s'", map);
	
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return;
	}
	
	while (SQL_FetchRow(qHandle)) {
		
		new saveId = SQL_FetchInt(qHandle, 0);
		
		Format(query, sizeof(query), "DELETE FROM save WHERE id='%d'", saveId);
		
		if (!SQL_FastQuery(db, query)) {
			
			new String:error[256];
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
	}
	
	CloseHandle(qHandle);
}

DB_spawnableAt(index, String:name[], nameLen, String:path[] = "", pathLen = 0)
{
	decl String:query[256];
	
	Format(query, sizeof(query), "SELECT * FROM model LIMIT 1 OFFSET %d", index);
	
	new Handle:qHandle = SQL_Query(db, query);
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return -1;
	}
	
	if (!SQL_FetchRow(qHandle)) {
		
		CloseHandle(qHandle);
		PrintToServer("Failed to fetch row %d", index);
		return -1;
	}
	
	SQL_FetchString(qHandle, 1, name, nameLen);
	
	if (pathLen) SQL_FetchString(qHandle, 2, path, pathLen);
			
	new id = SQL_FetchInt(qHandle, 0);
	
	CloseHandle(qHandle);
	
	return id;
}

DB_spawnableCount()
{
	new Handle:qHandle = SQL_Query(db, "SELECT * FROM model");
	
	if (qHandle == INVALID_HANDLE) {
		
		new String:error[256];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		return 0;
	}
	
	new count = SQL_GetRowCount(qHandle);
	
	CloseHandle(qHandle)
	
	return count;
}

DB_setUp()
{
	if (db != INVALID_HANDLE) return;
	
	new String:error[256];	
	new Handle:kv = CreateKeyValues("uniqueRandomString");
	
	//Establish connection
	KvSetString(kv, "driver", "sqlite");
	KvSetString(kv, "database", DATABASE_NAME);
	
	//FIXME foreign keys=true, not sure if needed or how to input during connection
	db = SQL_ConnectCustom(kv, error, sizeof(error), true);
	
	if (db == INVALID_HANDLE) {
		
		CloseHandle(kv);
		PrintToServer("[Death Spawn] DB connection error - %s.", error);
		return;
	}
	
	//Create tables if they dont exist
	SQL_Query(db, "CREATE TABLE IF NOT EXISTS model(\
		id INTEGER PRIMARY KEY,\
		name TEXT,\
		path TEXT)");
	
	SQL_Query(db, "CREATE TABLE IF NOT EXISTS map(\
		id INTEGER PRIMARY KEY,\
		name TEXT)");
		
	SQL_Query(db, "CREATE TABLE IF NOT EXISTS client(\
		id INTEGER PRIMARY KEY,\
		name TEXT,\
		authstring TEXT)");
		
	SQL_Query(db, "CREATE TABLE IF NOT EXISTS save(\
		id INTEGER PRIMARY KEY,\
		x REAL,	y REAL,	z REAL,\
		ax REAL, ay REAL, az REAL,\
		model_id INTEGER REFERENCES model(id) ON DELETE CASCADE ON UPDATE CASCADE,\
		map_id INTEGER REFERENCES map(id) ON DELETE CASCADE ON UPDATE CASCADE,\
		client_id INTEGER REFERENCES client(id) ON DELETE CASCADE ON UPDATE CASCADE,\
		msg TEXT,\
		break_on_touch INTEGER DEFAULT 1,\
		break_on_pressure INTEGER DEFAULT 1\
		)");
		
	SQL_Query(db, "CREATE TABLE IF NOT EXISTS traplog (\
		client_id INTEGER REFERENCES client(id) ON DELETE CASCADE ON UPDATE CASCADE,\
		save_id INTEGER REFERENCES save(id) ON DELETE CASCADE ON UPDATE CASCADE,\
		deaths INTEGER DEFAULT 0,\
		primary key (client_id, save_id)\
	)");
	
	CloseHandle(kv);
}

DB_close()
{
	CloseHandle(db);
}
