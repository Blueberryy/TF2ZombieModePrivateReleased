#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>


#define TRACE_START 24.0
#define TRACE_END 64.0 //64.0
#define MAXENTITIES 2048

bool g_bHoldingProp[MAXENTITIES + 1] =  { false, ... };
bool g_bReleasingProp[MAXENTITIES + 1] =  { false, ... };
bool g_bNailed[MAXENTITIES + 1] =  { false, ... };

int g_iMapPrefixType;
int g_iZomTeamIndex;
int g_iHumTeamIndex;

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", OnRound);
}
public void OnMapStart() {
	zombimod();
	logGameRuleTeamRegister();
	PrecacheSound("physics/concrete/concrete_break3.wav", true);
	for (new i = 0; i <= MAXENTITIES; i++) {
		g_bHoldingProp[i] = false;
		g_bReleasingProp[i] = false;
		g_bNailed[i] = false;
	}
}
public void OnMapEnd() {
	for (new i = 0; i <= MAXENTITIES; i++) {
		g_bHoldingProp[i] = false;
		g_bReleasingProp[i] = false;
		g_bNailed[i] = false;
	}
}
public Action:OnRound(Handle:event, const String:name[], bool:dontBroadcast) {
	for (new i = 0; i <= MAXENTITIES; i++) {
		g_bHoldingProp[i] = false;
		g_bReleasingProp[i] = false;
		g_bNailed[i] = false;
	}
}
public Action:OnPlayerRunCmd(client, &buttons) {
	if ((buttons & IN_ATTACK2)) {
		int TracedEntity = TraceRayToEntity(client, 80.0);
		if (TracedEntity > 0) {  // Could be -1, were being more secure.
			decl String:ClassName[32];
			GetEntityClassname(TracedEntity, ClassName, sizeof(ClassName));
			if (g_bNailed[TracedEntity]) {
				PrintHintText(client, "Looking at:%d / ClassName:%s / It's nailed!", TracedEntity, ClassName);
			}
			if (FindEntityByClassname(TracedEntity, "prop_physics") != -1) {
				if (TF2_GetPlayerClass(client) == TFClass_Engineer && GetClientTeam(client) == g_iHumTeamIndex) {
					if (GetActiveIndex(client) == 7 && !g_bNailed[TracedEntity]) {  //Using stock Wrench
						PropToNail(TracedEntity);
						AcceptEntityInput(TracedEntity, "EnableCollision");
						SetVariantInt(255);
						AcceptEntityInput(TracedEntity, "alpha");
						g_bHoldingProp[TracedEntity] = false;
						g_bReleasingProp[TracedEntity] = false; // Cuz it's nailed.
						PrintHintText(client, "Looking at:%d / ClassName:%s", TracedEntity, ClassName);
					}
				}
			}
		}
	}
	else if ((buttons & IN_ATTACK)) {
		int TracedEntity = TraceRayToEntity(client, 80.0);
		if (TracedEntity > 0) {
			char ClassName[32];
			GetEntityClassname(TracedEntity, ClassName, sizeof(ClassName));
			if (FindEntityByClassname(TracedEntity, "prop_physics") != -1) {
				if (GetClientTeam(client) == g_iZomTeamIndex) {
					SDKHook(TracedEntity, SDKHook_OnTakeDamage, OnPropTookDamage);
				}
			}
		}
	}
	else if ((buttons & IN_SPEED)) {
		float start[3];
		float angle[3];
		float end[3];
		float normal[3];
		
		GetClientEyePosition(client, start);
		GetClientEyeAngles(client, angle);
		GetAngleVectors(angle, end, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(end, end);
		
		int TracedEntity = TraceRayToEntity(client, 180.0);
		if (TracedEntity > 0) {
			decl String:ClassName[32];
			GetEntityClassname(TracedEntity, ClassName, sizeof(ClassName));
			//PrintHintText(client, "Moving:%d / ClassName:%s", TracedEntity, ClassName);
			if (FindEntityByClassname(TracedEntity, "prop_physics") != -1) {
				if (TF2_GetPlayerClass(client) == TFClass_Engineer && GetActiveIndex(client) == 7 && GetClientTeam(client) == g_iHumTeamIndex) {
					if (TF2_HasGlow(TracedEntity) && !g_bNailed[TracedEntity]) {  //Were targetting node props %100.
						Move2(TracedEntity, start, angle, end, normal, 2);
						g_bReleasingProp[TracedEntity] = false;
					}
				}
			}
		}
	} else {
		int TracedEntity = TraceRayToEntity(client, 180.0);
		if (TracedEntity > 0) {
			SDKHook(TracedEntity, SDKHook_ShouldCollide, ShouldCollideOnDrop);
			if (IsPlayerStuckInEnt(client, TracedEntity) && GetClientTeam(client) == g_iHumTeamIndex) {
				if ((buttons & IN_RELOAD)) {
					SDKHook(TracedEntity, SDKHook_ShouldCollide, ShouldCollide);
				}
			}
			else if (!IsPlayerStuckInEnt(client, TracedEntity) && GetClientTeam(client) == g_iHumTeamIndex) {
				SDKHook(TracedEntity, SDKHook_ShouldCollide, ShouldCollideOnDrop);
			}
		}
	}
	if ((buttons & IN_ZOOM)) {
		float clientOrigin[3];
		float vecToPush[3];
		float EyeAnglesOfClient[3];
		
		GetClientAbsOrigin(client, clientOrigin);
		GetClientEyeAngles(client, EyeAnglesOfClient);
		
		int TracedEntityToDrop = TraceRayToEntity(client, 180.0);
		if (TracedEntityToDrop > 0) {
			if (g_bHoldingProp[TracedEntityToDrop]) {
				g_bReleasingProp[TracedEntityToDrop] = true;
				if (g_bReleasingProp[TracedEntityToDrop] && !g_bNailed[TracedEntityToDrop] && GetClientTeam(client) != g_iZomTeamIndex) {
					Drop(TracedEntityToDrop, clientOrigin, vecToPush, EyeAnglesOfClient);
					SDKHook(TracedEntityToDrop, SDKHook_ShouldCollide, ShouldCollideOnDrop);
					g_bReleasingProp[TracedEntityToDrop] = false;
				}
			}
			if (IsPlayerStuckInEnt(client, TracedEntityToDrop) && g_bNailed[TracedEntityToDrop] && GetClientTeam(client) == g_iHumTeamIndex) {
				float iPosition[3];
				GetClientEyePosition(client, iPosition);
				iPosition[0] += 0.001;
				//TeleportEntity(client, iPosition, NULL_VECTOR, NULL_VECTOR);
				AcceptEntityInput(TracedEntityToDrop, "DisableCollision");
			}
			else if (!IsPlayerStuckInEnt(client, TracedEntityToDrop) && g_bNailed[TracedEntityToDrop] && GetClientTeam(client) == g_iHumTeamIndex) {
				AcceptEntityInput(TracedEntityToDrop, "EnableCollision");
			}
		}
	}
}
public bool ShouldCollideOnDrop(int entity, int collisiongroup, int contentsmask, bool result) {
	result = true;
	return true;
}
stock TraceRayToEntity(int iClient, float Distance) {
	float vecEyeAngle[3];
	float vecEyePos[3];
	
	GetClientEyePosition(iClient, vecEyePos); //Eyes
	GetClientEyeAngles(iClient, vecEyeAngle); //Where the client is looking at
	
	TR_TraceRayFilter(vecEyePos, vecEyeAngle, MASK_SOLID, RayType_Infinite, TraceRayHitSelf, iClient);
	if (TR_DidHit(INVALID_HANDLE)) {
		float EndPos[3];
		int iEnt = TR_GetEntityIndex(INVALID_HANDLE);
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", EndPos);
		if (GetVectorDistance(vecEyePos, EndPos) < Distance) {
			return iEnt;
		} else {
			return -1;
		}
	}
	return -1;
}

public bool:TraceRayHitSelf(entity, mask, any:data) {
	return (entity != data);
}
PropToNail(iEnt) {
	FindEntityByClassname(iEnt, "prop_physics"); //Double Checking.
	if (iEnt != -1 && IsValidEntity(iEnt) && !g_bNailed[iEnt]) {
		SetEntProp(iEnt, Prop_Data, "m_takedamage", 2, 1);
		SetEntityMoveType(iEnt, MOVETYPE_NONE); //Let's Freeze That Prop
		SetEntProp(iEnt, Prop_Data, "m_iHealth", 1500);
		if (TF2_HasGlow(iEnt)) {
			TF2_RemoveGlow(iEnt);
		}
		TF2_CreateGlow(iEnt); //Let's create Outline (green)
		g_bNailed[iEnt] = true;
		SetVariantInt(255);
		AcceptEntityInput(iEnt, "alpha");
		EmitSoundToAll("weapons/crowbar/crowbar_impact2.wav");
	}
}


stock int TF2_CreateGlow(int iEnt)
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
	
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "RainbowGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchSpawn(ent);
	
	int color[4];
	
	color[0] = 0;
	color[1] = 255;
	color[2] = 0;
	color[3] = 255;
	
	SetVariantColor(color);
	AcceptEntityInput(ent, "SetGlowColor");
	
	AcceptEntityInput(ent, "Enable");
	
	//Change name back to old name because we don't need it anymore.
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
	
	return ent;
}

stock bool TF2_HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			//AcceptEntityInput(index, "Kill");
			return true;
			//AcceptEntityInput(index, "Kill");
		}
	}
	
	return false;
}
stock TF2_RemoveGlow(int iEnt) {
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1) {
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt) {
			AcceptEntityInput(index, "Kill");
		}
	}
}
stock TF2_GlowColour(int iEnt) {
	int index = -1;
	int color[4];
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1) {
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt) {
			color[0] = 255;
			color[1] = 255;
			color[2] = 0;
			color[3] = 255;
			SetVariantColor(color);
			AcceptEntityInput(index, "SetGlowColor");
		}
	}
}

stock GetActiveIndex(iClient)
{
	return GetWeaponIndex(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"));
}
stock GetWeaponIndex(iWeapon)
{
	return IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}
void Move2(int iEnt, Float:start[3], Float:angle[3], Float:end[3], Float:normal[3], int Multiplier) {
	if (iEnt == iEnt && IsValidEntity(iEnt) && !IsValidClient(iEnt)) {
		start[0] = start[0] + end[0] * TRACE_START;
		start[1] = start[1] + end[1] * TRACE_START;
		start[2] = start[2] + end[2] * TRACE_START;
		
		end[0] = start[0] + end[0] * TRACE_END * Multiplier;
		end[1] = start[1] + end[1] * TRACE_END * Multiplier;
		end[2] = start[2] + end[2] * TRACE_END * Multiplier;
		TR_TraceRayFilter(start, end, CONTENTS_SOLID, RayType_EndPoint, TraceRayHitSelf, 0);
		if (TR_DidHit(null)) {
			TR_GetEndPosition(end, null);
			TR_GetPlaneNormal(null, normal);
			GetVectorAngles(normal, normal);
			normal[0] = normal[0] * 2;
			normal[1] = normal[1] * 2;
			normal[2] = normal[2] * 2;
			//AcceptEntityInput(iEnt, "DisableCollision");
			SDKHook(iEnt, SDKHook_ShouldCollide, ShouldCollide);
			SetEntityRenderMode(iEnt, RENDER_TRANSALPHA);
			SetVariantInt(120);
			AcceptEntityInput(iEnt, "alpha");
			g_bHoldingProp[iEnt] = true;
			TeleportEntity(iEnt, end, NULL_VECTOR, NULL_VECTOR);
		}
	}
}
public bool ShouldCollide(int entity, int collisiongroup, int contentsmask, bool result) {
	result = false;
	return false;
}
void Drop(int iEnt, Float:vecToBase[3], Float:vecToPush[3], Float:EyeAngles[3]) {
	if (iEnt != -1 && !IsValidClient(iEnt)) {
		SetVariantInt(255);
		AcceptEntityInput(iEnt, "alpha");
		vecToPush[0] = (vecToBase[0] + (100 * Cosine(DegToRad(EyeAngles[1])))); //angle forward
		vecToPush[1] = (vecToBase[1] + (100 * Sine(DegToRad(EyeAngles[1])))); //angle right
		vecToPush[2] = (vecToBase[2] + 10);
		TeleportEntity(iEnt, vecToPush, NULL_VECTOR, NULL_VECTOR);
		//g_bReleasingProp[iEnt] = true;
		SetEntityMoveType(iEnt, MOVETYPE_VPHYSICS);
	}
}
stock bool IsValidClient(client, bool:nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
void RotateProp(int iEnt, Float:start[3], Float:angle[3], Float:end[3], Float:normal[3]) {
	if (iEnt != -1 && IsValidEntity(iEnt) && !IsValidClient(iEnt)) {
		start[0] = start[0] + end[0] * TRACE_START;
		start[1] = start[1] + end[1] * TRACE_START;
		start[2] = start[2] + end[2] * TRACE_START;
		
		end[0] = start[0] + end[0] * TRACE_END * 2;
		end[1] = start[1] + end[1] * TRACE_END * 2;
		end[2] = start[2] + end[2] * TRACE_END * 2;
		TR_TraceRayFilter(start, end, CONTENTS_SOLID, RayType_EndPoint, TraceRayHitSelf, 0);
		if (TR_DidHit(null)) {
			TR_GetEndPosition(end, null);
			TR_GetPlaneNormal(null, normal);
			GetVectorAngles(normal, normal);
			normal[0] = normal[0] + 90.0;
			//normal[1] = normal[1] + 90.0;
			//normal[2] = normal[2] + 90.0;
			TeleportEntity(iEnt, end, normal, NULL_VECTOR);
			//SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
			//SetEntityRenderMode(iEnt, RENDER_NONE);
		}
	}
}
/*void Move(int iEnt, Float:start[3], Float:angle[3], Float:end[3], Float:normal[3]) {
	if (iEnt != -1 && IsValidEntity(iEnt) && !IsValidClient(iEnt)) {
		start[0] = start[0] + end[0] * TRACE_START;
		start[1] = start[1] + end[1] * TRACE_START;
		start[2] = start[2] + end[2] * TRACE_START;
		
		end[0] = start[0] + end[0] * TRACE_END * 2;
		end[1] = start[1] + end[1] * TRACE_END * 2;
		end[2] = start[2] + end[2] * TRACE_END * 2;
		TR_TraceRayFilter(start, end, CONTENTS_SOLID, RayType_EndPoint, TraceRayHitSelf, 0);
		if (TR_DidHit(null)) {
			TR_GetEndPosition(end, null);
			TR_GetPlaneNormal(null, normal);
			GetVectorAngles(normal, normal);
			normal[0] = normal[0] * angle[0] / 2;
			normal[1] = normal[1] * angle[1] / 2;
			normal[2] = normal[2] * angle[2] / 2;
			TeleportEntity(iEnt, end, normal, NULL_VECTOR);
			//SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
			//SetEntityRenderMode(iEnt, RENDER_NONE);
		}
	}
}*/

//SDKHook(iEnt, SDKHook_OnTakeDamage, OnPropTookDamage);
//SDKHook(iEnt, SDKHook_StartTouch, Human_Touch);

public Action:OnPropTookDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	int cHP = GetEntProp(victim, Prop_Data, "m_iHealth");
	float flPos[3];
	if (IsValidClient(attacker)) {
		PrintHintText(attacker, "Prop Health:%d", cHP);
		GetClientAbsOrigin(attacker, flPos);
		EmitSoundToAll("physics/concrete/concrete_break3.wav", victim, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, flPos, NULL_VECTOR, true, 0.0);
		//GetClientAbsOrigin(attacker, flPos);
		TF2_GlowColour(victim);
	}
}
/*
public Action:Human_Touch(int iEnt, int client) {
	if (GetEntProp(client, Prop_Data, "m_nSolidType") && !(GetEntProp(client, Prop_Data, "m_usSolidFlags") & 0x0004))
	{
		if (IsValidClient(client) && IsPlayerAlive(client))
		{
			if (GetClientTeam(client) == g_iHumTeamIndex) {
				//decl Float:iEntVector[3], Float:ClientVector[3];
				CreateTimer(0.0, Teleport, client, TIMER_FLAG_NO_MAPCHANGE);
				//GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", iEntVector);
				//GetClientAbsOrigin(client, ClientVector);
				//ClientVector[0] = ClientVector[0] + iEntVector[0];
				//ClientVector[1] = ClientVector[1] + iEntVector[1];
				//ClientVector[2] = ClientVector[2] + iEntVector[2];
				//TeleportEntity(client, ClientVector, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}
public Action:Teleport(Handle:timer, any:client) {
	decl Float:clientVector[3], Float:EyeAngles[3];
	GetClientAbsOrigin(client, clientVector);
	GetClientEyeAngles(client, EyeAngles);
	if (EyeAngles[1] > 0) {
		clientVector[0] = clientVector[0] + 30;
	} else {
		clientVector[0] = clientVector[0] - 30;
	}
	TeleportEntity(client, clientVector, NULL_VECTOR, NULL_VECTOR);
}
*/
logGameRuleTeamRegister() {  //Registers the Team indexes (Most likely usage for OnMapStart() )
	if (g_iMapPrefixType == 1 || g_iMapPrefixType == 2) {
		g_iZomTeamIndex = 3; //We'll set Blue team as a zombie for those maps
		g_iHumTeamIndex = 2; //We'll set Red team as a human for those maps
	} //If the map is ZF or ZM 
	else if (g_iMapPrefixType == 3 || g_iMapPrefixType == 4 || g_iMapPrefixType == 5 || g_iMapPrefixType == 6) {
		g_iZomTeamIndex = 2; //We'll set Red team as a zombie for those maps
		g_iHumTeamIndex = 3; //We'll set Blue team as a zombie for those maps
	} // If the map is ZM, ZS, ZOM, ZE
}
zombimod()
{
	g_iMapPrefixType = 0;
	decl String:mapv[32];
	GetCurrentMap(mapv, sizeof(mapv));
	if (!StrContains(mapv, "zf_", false)) {
		g_iMapPrefixType = 1;
	}
	else if (!StrContains(mapv, "szf_", false)) {
		g_iMapPrefixType = 2;
	}
	else if (!StrContains(mapv, "zm_", false)) {
		g_iMapPrefixType = 3;
	}
	else if (!StrContains(mapv, "zom_", false)) {
		g_iMapPrefixType = 4;
	}
	else if (!StrContains(mapv, "zs_", false)) {
		g_iMapPrefixType = 5;
	}
	else if (!StrContains(mapv, "ze_", false)) {
		g_iMapPrefixType = 6;
	}
}
stock bool IsPlayerStuckInEnt(int client, int ent)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	GetClientEyeAngles(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayHitOnlyEnt, ent);
	return TR_DidHit();
}

public bool TraceRayHitOnlyEnt(int entity, int contentsMask, any data)
{
	return entity == data;
} 