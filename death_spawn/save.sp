#if defined DEATH_SPAWN_SAVE
	#endinput
#endif
#define DEATH_SPAWN_SAVE

enum Save_saveToDBEn
{
	eref, 	 //entity reference
	eid,	 //entity table id (from our db)
	health,	 //maximum entity health
	damage,	 //damage of explosion placed on entity
	radius,	 //radius of explosion placed on entity
	bool:bot //break on touch	
}

static Handle:mContainer[MAXPLAYERS + 1]; //Each admin has one

Save_at(i, client, &eRef, &eId, &eHealth, &exDamage, &exRadius, &bool:breakOnTouch)
{	
	decl stdb[Save_saveToDBEn];
	GetArrayArray(mContainer[client], i, stdb[0]);
	
	eRef = stdb[eref];
	eId = stdb[eid];
	eHealth = stdb[health];
	exDamage = stdb[damage];
	exRadius = stdb[radius];
	breakOnTouch = stdb[bot];
}

Save_add(client, eIndex, eId, eHealth, exDamage, exRadius, bool:breakOnTouch)
{
	decl stdb[Save_saveToDBEn];
	stdb[eref] = eIndex;
	stdb[eid] = eId;
	stdb[health] = eHealth;
	stdb[damage] = exDamage;
	stdb[radius] = exRadius;
	stdb[bot] = breakOnTouch;
	PushArrayArray(mContainer[client], stdb[0]);
}

Save_size(client)
{
	return GetArraySize(mContainer[client]);
}

Save_setUp()
{
	for (new i = 1; i <= MAXPLAYERS; i++) {
		mContainer[i] = CreateArray(_:Save_saveToDBEn);
	}	
}

Save_clear(client)
{	
	ClearArray(mContainer[client]);
}

Save_clearAll()
{
	for (new i = 1; i <= MAXPLAYERS; i++) {
		ClearArray(mContainer[i]);
	}
}

Save_close()
{
	for (new i = 1; i <= MAXPLAYERS; i++) {
		ClearArray(mContainer[i]);
		CloseHandle(mContainer[i]);
	}
}

/*Save_delete(eIndex, client)
{
	new size = Save_size(client);
			
	for (new i = 0; i < size; i++) {
		
		if (GetArrayCell(mContainer[client][0], i) != eIndex) continue;
		
		RemoveFromArray(mContainer[client][0], i);
		
		RemoveFromArray(mContainer[client][1], i);
		
		return;
	}
}*/

Save_deleteNoCLient(eIndex)
{
	for (new h = 1; h <= MAXPLAYERS; h++) {

		new size = Save_size(h);
				
		for (new i = 0; i < size; i++) {
			
			decl stdb[Save_saveToDBEn];
			GetArrayArray(mContainer[h], i, stdb[0]);
			
			if (stdb[eref] != eIndex) continue;
			
			RemoveFromArray(mContainer[h], i);
			return;
		}
	}
}