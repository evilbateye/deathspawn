#if defined DEATH_SPAWN_SAVE
	#endinput
#endif
#define DEATH_SPAWN_SAVE

/* Each player has 2 handles to indexes and ids of entities he created */
new Handle:mContainer[MAXPLAYERS + 1][2];

Save_size(client)
{
	return GetArraySize(mContainer[client][0]);
}

Save_at(entity[], i, client)
{
	entity[0] = GetArrayCell(mContainer[client][0], i);
	entity[1] = GetArrayCell(mContainer[client][1], i);
}

Save_setUp()
{
	for (new i = 1; i <= MAXPLAYERS; i++) {
		mContainer[i][0] = CreateArray();
		mContainer[i][1] = CreateArray();
	}	
}

Save_clear(client)
{	
	ClearArray(mContainer[client][0]);
	ClearArray(mContainer[client][1]);
}

Save_clearAll()
{
	for (new i = 1; i <= MAXPLAYERS; i++) {
		
		ClearArray(mContainer[i][0]);			
		ClearArray(mContainer[i][1]);
	}
}

Save_close()
{
	for (new i = 1; i <= MAXPLAYERS; i++) {
	
		ClearArray(mContainer[i][0]);
		ClearArray(mContainer[i][1]);
		
		CloseHandle(mContainer[i][0]);
		CloseHandle(mContainer[i][1]);
	}
}

Save_add(eIndex, eId, client)
{
	PushArrayCell(mContainer[client][0], eIndex);
	PushArrayCell(mContainer[client][1], eId);
}

Save_delete(eIndex)
{
	new bool:end = false;

	for (new i = 1; i <= MAXPLAYERS && !end; i++) {
	
		new size = Save_size(i);
	
		for (new j = 0; j < size; j++) {
					
			if (GetArrayCell(mContainer[i][0], j) != eIndex) continue;
				
			RemoveFromArray(mContainer[i][0], j);
			RemoveFromArray(mContainer[i][1], j);
			
			end = true;
			break;
		}
	}
}