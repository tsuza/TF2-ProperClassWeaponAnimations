#include <sourcemod>

#include <sdkhooks>
#include <sdktools>
#include <dhooks>

#include <tf2_stocks>

#include <tf_econ_data>
#include <tf2utils>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_NAME         "TF2-ProperClassWeaponAnimations"
#define PLUGIN_AUTHOR       "Zabaniya001"
#define PLUGIN_DESCRIPTION  "[TF2] Automatically set up the correct animations whenever a class is using a gun that isn't supposed to be used by them."
#define PLUGIN_URL          "https://github.com/Zabaniya001/TF2-ProperClassWeaponAnimations"

public Plugin myinfo = {
    name        =   PLUGIN_NAME,
    author      =   PLUGIN_AUTHOR,
    description =   PLUGIN_DESCRIPTION,
    version     =   "1.0.0",
    url         =   PLUGIN_URL
};

enum
{
	EF_BONEMERGE            = (1<<0),	// Performs bone merge on client side
	EF_BRIGHTLIGHT          = (1<<1),	// DLIGHT centered at entity origin
	EF_DIMLIGHT             = (1<<2),	// player flashlight
	EF_NOINTERP             = (1<<3),	// don't interpolate the next frame
	EF_NOSHADOW             = (1<<4),	// Don't cast no shadow
	EF_NODRAW               = (1<<5),	// don't draw entity
	EF_NORECEIVESHADOW      = (1<<6),	// Don't receive no shadow
	EF_BONEMERGE_FASTCULL   = (1<<7),	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
										// parent and uses the parent's bbox + the max extents of the aiment.
										// Otherwise, it sets up the parent's bones every frame to figure out where to place
										// the aiment, which is inefficient because it'll setup the parent's bones even if
										// the parent is not in the PVS.
	EF_ITEM_BLINK           = (1<<8),	// blink an item so that the user notices it.
	EF_PARENT_ANIMATES      = (1<<9),	// always assume that the parent entity is animating
}

char g_sViewModelsArms[][PLATFORM_MAX_PATH] = {
	"models/weapons/c_models/c_medic_arms.mdl",
	"models/weapons/c_models/c_scout_arms.mdl",
	"models/weapons/c_models/c_sniper_arms.mdl",
	"models/weapons/c_models/c_soldier_arms.mdl",
	"models/weapons/c_models/c_demo_arms.mdl",
	"models/weapons/c_models/c_medic_arms.mdl",
	"models/weapons/c_models/c_heavy_arms.mdl",
	"models/weapons/c_models/c_pyro_arms.mdl",
	"models/weapons/c_models/c_spy_arms.mdl",
	"models/weapons/c_models/c_engineer_arms.mdl",
};

static const char g_sPlayerModels[][] =
{
	"models/player/scout.mdl",
	"models/player/scout.mdl",
	"models/player/sniper.mdl",
	"models/player/soldier.mdl",
	"models/player/demo.mdl",
	"models/player/medic.mdl",
	"models/player/heavy.mdl",
	"models/player/pyro.mdl",
	"models/player/spy.mdl",
	"models/player/engineer.mdl"
};

enum struct WeaponModel
{
	int m_iArms;
	int m_iViewModel;
	int m_iPlayerModel;

	void Delete(int client)
	{
		int arms = EntRefToEntIndex(this.m_iArms);
		int viewmodel = EntRefToEntIndex(this.m_iViewModel);
		int playermodel = EntRefToEntIndex(this.m_iPlayerModel);

		if(arms != 0 && arms != -1)
		{
			TF2_RemoveWearable(client, arms);
			RemoveEntity(arms);
		}

		if(viewmodel != 0 && viewmodel != -1)
		{
			TF2_RemoveWearable(client, viewmodel);
			RemoveEntity(viewmodel);
		}

		if(playermodel != 0 && playermodel != -1)
		{
			TF2_RemoveWearable(client, playermodel);
			RemoveEntity(playermodel);
		}

		return;
	}
}

WeaponModel g_LastClientViewmodel[36];

ConVar g_cvPlayerModelBonemerge;

public void OnPluginStart()
{
	g_cvPlayerModelBonemerge = CreateConVar("sm_tf2-properclassweaponanimations_playermodelbonemerge", "1", "Whether or not you want to have the player's model ( what others see ) have proper animations for the unintended weapon. Note that this will create one more entity.");

	GameData hGameData = new GameData("tf2.properclassweaponanims");

	DynamicDetour dhookTaunt = DynamicDetour.FromConf(hGameData, "CTFPlayer::Taunt");

	// It's not a big deal if the signature for CTFPlayer::Taunt has become invalid.
	if(dhookTaunt)
	{
		dhookTaunt.Enable(Hook_Pre, DHook_TauntPre);
		dhookTaunt.Enable(Hook_Post, DHook_TauntPost);
	}
	else
	{
		PrintToServer("[TF2-ProperClassWeaponAnimations] WARNING: The signature for CTFPlayer::Taunt is invalid. The plugin will continue functioning correctly, but players with unintended weapons won't be able to taunt.");
	}

	delete hGameData;

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	// late-load support
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
		
		OnClientPutInServer(client);
	}

	return;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

	return;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if(EntRefToEntIndex(g_LastClientViewmodel[client].m_iPlayerModel) != -1)
	{
		ReplacePlayerModel(client, "");
		UnhidePlayerModel(client);
	}
	
	g_LastClientViewmodel[client].Delete(client);

	return Plugin_Continue;
}

TFClassType original_class[36] = {TFClass_Unknown, ...};

public MRESReturn DHook_TauntPre(int client, DHookParam hParams)
{
	//Dont allow taunting if disguised or cloaked
	if (TF2_IsPlayerInCondition(client, TFCond_Disguising) || TF2_IsPlayerInCondition(client, TFCond_Disguised) || TF2_IsPlayerInCondition(client, TFCond_Cloaked))
		return MRES_Supercede;
	
	//Player wants to taunt, set class to whoever can actually taunt with active weapon
	
	int active_weapon = TF2_GetActiveWeapon(client);

	if (active_weapon <= MaxClients)
		return MRES_Ignored;
	
	if(EntRefToEntIndex(g_LastClientViewmodel[client].m_iArms) == -1)
		return MRES_Ignored;
	
	TFClassType player_class = TF2_GetPlayerClass(client);
	
	int taunt_default_class = TF2_GetDefaultClassForWeapon(active_weapon, player_class);

	original_class[client] = player_class;

	if(view_as<TFClassType>(taunt_default_class) != TFClass_Unknown && view_as<TFClassType>(taunt_default_class) != player_class)
	{
		TF2_SetPlayerClass(client, view_as<TFClassType>(taunt_default_class), _, false);
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_TauntPost(int client, DHookParam hParams)
{
	if(EntRefToEntIndex(g_LastClientViewmodel[client].m_iArms) == -1)
		return MRES_Ignored;

	if(original_class[client] != TF2_GetPlayerClass(client))
		TF2_SetPlayerClass(client, original_class[client], _, false);
	
	original_class[client] = TFClass_Unknown;

	return MRES_Ignored;
}

void OnWeaponEquipPost(int client, int weapon)
{
	TFClassType player_class = TF2_GetPlayerClass(client);

	int weapon_default_class = TF2_GetDefaultClassForWeapon(weapon, player_class);

	if(weapon_default_class == view_as<int>(player_class))
		return;
	
	SetEntityModel(weapon, g_sViewModelsArms[weapon_default_class]);
	SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex"));
	SetEntProp(weapon, Prop_Send, "m_iViewModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex")); // Animations are still borked unless you set this. Special thanks to Ficool2 for letting me know.

	return;
}

void OnWeaponSwitchPost(int client, int weapon)
{
	static int last_weapon_list[36] = {-1, ...};

	if(!IsValidEntity(weapon))
		return;

	int last_weapon = EntRefToEntIndex(last_weapon_list[client]);

	if(last_weapon == weapon)
		return;
	
	if(EntRefToEntIndex(g_LastClientViewmodel[client].m_iPlayerModel) != -1)
	{
		ReplacePlayerModel(client, "");
		UnhidePlayerModel(client);
	}

	g_LastClientViewmodel[client].Delete(client);

	last_weapon_list[client] = EntIndexToEntRef(weapon);

	TFClassType player_class = TF2_GetPlayerClass(client);

	int weapon_default_class = TF2_GetDefaultClassForWeapon(weapon, player_class);

	if(weapon_default_class == view_as<int>(player_class))
		return;
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(EntIndexToEntRef(client));
	hPack.WriteCell(EntIndexToEntRef(weapon));
	
	RequestFrame(Frame_OnDrawWeapon, hPack);

	return;
}

void Frame_OnDrawWeapon(DataPack hPack)
{
	hPack.Reset();

	int client = EntRefToEntIndex(hPack.ReadCell());
	int weapon = EntRefToEntIndex(hPack.ReadCell());

	delete hPack;

	if(weapon != TF2_GetActiveWeapon(client))
		return;

	OnDrawWeapon(client, weapon);

	return;
}

void OnDrawWeapon(int client, int weapon)
{
	if(weapon <= 0 || weapon > 2048)
		return;

	if(client <= 0 || client > MaxClients)
		return;

	if(!IsClientInGame(client) || !IsValidEntity(weapon))
		return;
	
	int viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

	SetEntProp(viewmodel, Prop_Send, "m_fEffects", EF_NODRAW);

	g_LastClientViewmodel[client].m_iArms        =  EntIndexToEntRef(ApplyWeaponModel(client, PrecacheModel(g_sViewModelsArms[TF2_GetPlayerClass(client)]), true, weapon)); // Arms
	g_LastClientViewmodel[client].m_iViewModel   =  EntIndexToEntRef(ApplyWeaponModel(client, GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex"), true, weapon)); // Viewmodel weapon

	if(g_cvPlayerModelBonemerge.BoolValue)
	{
		ReplacePlayerModel(client, g_sPlayerModels[TF2_GetDefaultClassForWeapon(weapon, TF2_GetPlayerClass(client))]);
		HidePlayerModel(client);

		g_LastClientViewmodel[client].m_iPlayerModel = EntIndexToEntRef(ApplyWeaponModel(client, PrecacheModel(g_sPlayerModels[TF2_GetPlayerClass(client)]), false, weapon)); // Bonemerged og player model
	}

	return;
}

int ApplyWeaponModel(int client, int model_index, bool isViewmodel, int weapon = -1)
{
	int entity = CreateWearable(client, model_index, isViewmodel);

	if(entity != -1 && weapon != -1)
		SetEntPropEnt(entity, Prop_Send, "m_hWeaponAssociatedWith", weapon);

	return entity;
}

int CreateWearable(int client, int model_index, bool isViewmodel)
{
	int entity = CreateEntityByName(isViewmodel ? "tf_wearable_vm" : "tf_wearable");

	if(!IsValidEntity(entity))
		return -1;

	SetEntProp(entity, Prop_Send, "m_nModelIndex", model_index);
	SetEntProp(entity, Prop_Send, "m_fEffects",  EF_BONEMERGE | EF_BONEMERGE_FASTCULL);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_nSkin", GetClientTeam(client));
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 11);
	SetEntProp(entity, Prop_Send, "m_iEntityQuality", 1);
	SetEntProp(entity, Prop_Send, "m_iEntityLevel", -1);
	SetEntProp(entity, Prop_Send, "m_iItemIDLow", 2048);
	SetEntProp(entity, Prop_Send, "m_iItemIDHigh", 0);
	SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
	SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);

	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	DispatchSpawn(entity);

	SetVariantString("!activator");
	ActivateEntity(entity);

	TF2Util_EquipPlayerWearable(client, entity);

	return entity;
}

stock static int TF2_GetDefaultClassForWeapon(int weapon, TFClassType player_class = TFClass_Unknown)
{
	int weapon_id = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

	if((player_class != TFClass_Unknown) && (TF2Econ_GetItemLoadoutSlot(weapon_id, player_class) != -1))
		return view_as<int>(player_class);

	for(TFClassType class = TFClass_Scout; class < TFClass_Engineer; class++)
	{
		int slot = TF2Econ_GetItemLoadoutSlot(weapon_id, class);

		if(slot == -1)
			continue;

		return view_as<int>(class);
	}

	return view_as<int>(TFClass_Unknown);
}

stock static int TF2_GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

stock static void HidePlayerModel(int client)
{
	SetEntityRenderMode(client, RENDER_TRANSALPHA);
	SetEntityRenderColor(client, 0, 0, 0, 0);

	return;
}

stock static void UnhidePlayerModel(int client)
{
	SetEntityRenderMode(client, RENDER_TRANSALPHA);
	SetEntityRenderColor(client, 255, 255, 255, 255);

	return;
}

stock static void ReplacePlayerModel(int client, char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModelWithClassAnimations");

	return;
}