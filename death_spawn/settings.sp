#if defined DEATH_SPAWN_SETTINGS
	#endinput
#endif
#define DEATH_SPAWN_SETTINGS

enum Menu_PlayerMenuEn
{
	health,
	damage,
	radius,
	bool:bot
}

static menuArr[MAXPLAYERS + 1][Menu_PlayerMenuEn];

Settings_set(client, eHP, exDmg, exRad, bool:breakOnTouch)
{
	menuArr[client][health] = eHP;
	menuArr[client][damage] = exDmg;
	menuArr[client][radius] = exRad;
	menuArr[client][bot] = breakOnTouch;
}

Settings_get(client, &eHP, &exDmg, &exRad, &bool:breakOnTouch)
{
	eHP = menuArr[client][health];
	exDmg = menuArr[client][damage];
	exRad = menuArr[client][radius];
	breakOnTouch = menuArr[client][bot];
}

Menu_init()
{
	for (new i = 1; i <= MAXPLAYERS; i++) {
		menuArr[i][health] = 100;
		menuArr[i][damage] = 1000;
		menuArr[i][radius] = 100;
		menuArr[i][bot] = true;
	}
}