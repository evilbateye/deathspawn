#if defined DEATH_SPAWN_PMSG
	#endinput
#endif
#define DEATH_SPAWN_PMSG

#include "sdkhooks.inc"

enum PlayerMsgEn
{
    entityRef,
    String:message[256],
    saveId,
	damage,
	radius,
	bool:bot
}

static Handle:hPMSGArr = INVALID_HANDLE;

PMSG_add(eRef, String:msg[], sid, exDamage, exRadius, bool:breakOnTouch)
{
	decl pmsg[PlayerMsgEn];
	
	pmsg[entityRef] = eRef;
	strcopy(pmsg[message], sizeof(pmsg[message]), msg);
	pmsg[saveId] = sid;
	pmsg[damage] = exDamage;
	pmsg[radius] = exRadius;
	pmsg[bot] = breakOnTouch;
				
	PushArrayArray(hPMSGArr, pmsg[0]);
	
	if (!SDKHookEx(eRef, SDKHook_OnTakeDamage, OnTakeDamage)) PrintToChatAll("Failed to hook SDKHook_OnTakeDamage on eref:%d", eRef);
	if (!SDKHookEx(eRef, SDKHook_EndTouch, EndTouch)) PrintToChatAll("Failed to hook SDKHook_EndTouch on eref:%d", eRef);
	//if (!SDKHookEx(eRef, SDKHook_StartTouch, StartTouch)) PrintToChatAll("Failed to hook SDKHook_StartTouch on eref:%d", eRef);
}

bool:PMSG_del(eRef, String:msg[], msgLen, &sid, &exDamage, &exRadius, &bool:breakOnTouch)
{
	new size = GetArraySize(hPMSGArr);
	
	for (new i = 0; i < size; i++) {
		
		decl pmsg[PlayerMsgEn];
		
		GetArrayArray(hPMSGArr, i, pmsg[0]);
		
		if (pmsg[entityRef] != eRef) continue;
		
		RemoveFromArray(hPMSGArr, i);
		SDKUnhook(eRef, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKUnhook(eRef, SDKHook_EndTouch, EndTouch);
		//SDKUnhook(eRef, SDKHook_StartTouch, StartTouch);
				
		strcopy(msg, msgLen, pmsg[message]);		
		sid = pmsg[saveId];
		exDamage = pmsg[damage];
		exRadius = pmsg[radius];
		breakOnTouch = pmsg[bot];
				
		return true;
	}
	
	return false;
}

PMSG_init()
{
	hPMSGArr = CreateArray(_:PlayerMsgEn);
}

PMSG_updateSaveId(eRef, sid)
{
	new size = GetArraySize(hPMSGArr);
	
	for (new i = 0; i < size; i++) {
	
		decl pmsg[PlayerMsgEn];
		
		GetArrayArray(hPMSGArr, i, pmsg[0]);
		
		if (pmsg[entityRef] != eRef) continue;
		
		
		pmsg[saveId] = sid
		
		SetArrayArray(hPMSGArr, i, pmsg[0]);
				
		return i;
	}
	
	return -1;
}

/*PMSG_updateLastAttacker(eRef, attacker)
{
	new size = GetArraySize(hPMSGArr);
	
	for (new i = 0; i < size; i++) {
	
		decl pmsg[PlayerMsgEn];
		
		GetArrayArray(hPMSGArr, i, pmsg[0]);
		
		if (pmsg[entityRef] != eRef) continue;
		
		
		pmsg[attackerRef] = attacker;
		
		SetArrayArray(hPMSGArr, i, pmsg[0]);
				
		return i;
	}
	
	return -1;
}*/

PMSG_close()
{
	ClearArray(hPMSGArr);
	CloseHandle(hPMSGArr);
}
