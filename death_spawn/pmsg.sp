#if defined DEATH_SPAWN_PMSG
	#endinput
#endif
#define DEATH_SPAWN_PMSG

#include "sdkhooks.inc"

enum PlayerMsgEn
{
    entityRef,
    String:message[256],
    saveId
}

static Handle:hPMSGArr = INVALID_HANDLE;

PMSG_init()
{
	hPMSGArr = CreateArray(_:PlayerMsgEn);
}

PMSG_add(eref, String:msg[], sid)
{
	decl pmsg[PlayerMsgEn];
	
	pmsg[entityRef] = eref;
	strcopy(pmsg[message], sizeof(pmsg[message]), msg);
	pmsg[saveId] = sid;
		
	PushArrayArray(hPMSGArr, pmsg[0]);
	
	SDKHook(eref, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);	
}

PMSG_del(eref, String:msg[], msgLen)
{
	new size = GetArraySize(hPMSGArr);
	
	for (new i = 0; i < size; i++) {
		
		decl pmsg[PlayerMsgEn];
		
		GetArrayArray(hPMSGArr, i, pmsg[0]);
		
		if (pmsg[entityRef] != eref) continue;
		
		
		strcopy(msg, msgLen, pmsg[message]);
		
		RemoveFromArray(hPMSGArr, i);
		
		SDKUnhook(eref, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);
		
		return pmsg[saveId];
	}
	
	return -1;
}

PMSG_close()
{
	ClearArray(hPMSGArr);
	
	CloseHandle(hPMSGArr);
}
