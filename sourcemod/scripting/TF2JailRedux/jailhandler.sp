/* All non-gamemode oriented functions are at the bottom! */

public void ManageDownloads()
{
	PrecacheSound("vo/announcer_ends_60sec.mp3", true);
	PrecacheSound("vo/announcer_ends_30sec.mp3", true);
	PrecacheSound("vo/announcer_ends_10sec.mp3", true);
	PrecacheSound("vo/heavy_no03.mp3", true);

	char s[PLATFORM_MAX_PATH];
	for (int i = 1; i <= 5; i++)
	{
		if (i <= 5)
		{
			FormatEx(s, PLATFORM_MAX_PATH, "vo/announcer_ends_%isec.mp3", i);
			PrecacheSound(s, true);
		}
	}

	PrecacheSound("misc/rd_finale_beep01.wav", true);

	iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	iHalo = PrecacheModel("materials/sprites/glow01.vmt", true);
	iHalo2 = PrecacheModel("materials/sprites/halo01.vmt", true);

	// If a last request supports music, precache and prepare the sound file
	int len = gamemode.iLRs;
	LastRequest lr;
	for (int i = 0; i < len; ++i)
	{
		lr = LastRequest.At(i);
		if (lr == null)
			continue;

		lr.GetMusicFileName(s, sizeof(s));
		if (s[0] == '\0')
			continue;

		// If they included 'sound/', help them out
		if (!strncmp(s, "sound/", 6, false))
		{
			PrecacheSound(s[6], true);
			AddFileToDownloadsTable(s);
		}
		else PrepareSound(s);
	}

	Call_OnDownloads();
}

public void ManageSpawn(const JailFighter base, Event event)
{
	Call_OnPlayerSpawned(base, event);
}

public void PrepPlayer(int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsClientValid(client) || !IsPlayerAlive(client))
		return;

	if (gamemode.bAllowWeapons)
		return;

	JailFighter base = JailFighter(client);
	if (base.bSkipPrep)
	{
		base.bSkipPrep = false;
		return;
	}

	if (Call_OnPlayerPrepped(base) != Plugin_Continue)
		return;

	int team = GetClientTeam(client);
	bool killpda;

	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		switch (cvarTF2Jail[EngieBuildings].IntValue)
		{
			case 0:killpda = true;
			case 1:if (team != RED) killpda = true;
			case 2:if (team != BLU) killpda = true;
		}
	}
	else killpda = true;

	if (killpda)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
	}

	TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);

	if (team == RED)
		base.EmptyWeaponSlots();

	Call_OnPlayerPreppedPost(base);
}

public void ManageRoundStart()
{
	LastRequest lr = gamemode.GetCurrentLR();
	char hud[MAX_LRNAME_LENGTH];
	if (lr != null)
	{
		ExecuteLR(lr);

		lr.GetHudName(hud, sizeof(hud));
		if (hud[0] == '\0')
			lr.GetName(hud, sizeof(hud));
	}

	ManageLRHud(hud);
	Call_OnRoundStart();
}

public void ManageRoundStartPlayer(const JailFighter player)
{
	Call_OnRoundStartPlayer(player);
}

public void ManageOnRoundEnd(Event event)
{
	LastRequest lr = gamemode.GetCurrentLR();
	if (lr != null)
	{
		char buffer[256];
		lr.GetEndCommand(buffer, sizeof(buffer));
		if (buffer[0] != '\0')
		{
			DataPack pack;
			CreateDataTimer(0.5, ExecServerCmd, pack/*, TIMER_FLAG_NO_MAPCHANGE*/);
			pack.WriteString(buffer);
		}
	}
	Call_OnRoundEnd(event);
}

public void ManageRoundEnd(const JailFighter base, Event event)
{
	Call_OnRoundEndPlayer(base, event);
}

public void ManageWarden(const JailFighter base)
{
	gamemode.iWarden = base;
	gamemode.bWardenExists = true;
	gamemode.ResetVotes();
	base.WardenMenu();

	LastRequest lr = gamemode.GetCurrentLR();
	if (lr != null && lr.KillWeapons_Warden())
		TF2_AddCondition(base.index, TFCond_RestrictToMelee);	// This'll do, removed when warden is lost
}

public void ManageLRHud(const char[] name)
{
	char hud[MAX_LRNAME_LENGTH];
	strcopy(hud, sizeof(hud), name);
	Call_OnShowHud(hud, sizeof(hud));

	if (EnumTNPS[1].hHud != null)
	{
		for (int i = MaxClients; i; --i)
			if (IsClientInGame(i))
				ClearSyncHud(i, EnumTNPS[1].hHud);
		if (hud[0] != '\0')
			EnumTNPS[1].Display(hud);
	}
}

public void ManageTouch(const JailFighter toucher, const JailFighter touchee)
{
	Call_OnPlayerTouch(toucher, touchee);
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
	switch (cond)
	{
		case TFCond_Cloaked:
		{
			if (cvarTF2Jail[HideParticles].BoolValue)
			{
				JailFighter player = JailFighter(client);
				if (IsValidEntity(player.iRebelParticle))
					AcceptEntityInput(player.iRebelParticle, "Stop");

				if (IsValidEntity(player.iFreedayParticle))
					AcceptEntityInput(player.iFreedayParticle, "Stop");

				if (IsValidEntity(player.iWardenParticle))
					AcceptEntityInput(player.iWardenParticle, "Stop");

				if (IsValidEntity(player.iFreekillerParticle))
					AcceptEntityInput(player.iFreekillerParticle, "Stop");
			}
		}
		case TFCond_Disguising, TFCond_Disguised:
		{
			switch (cvarTF2Jail[Disguising].IntValue)
			{
				case 0:TF2_RemoveCondition(client, cond);
				case 1:if (GetClientTeam(client) == BLU) TF2_RemoveCondition(client, cond);
				case 2:if (GetClientTeam(client) == RED) TF2_RemoveCondition(client, cond);
			}
		}
		case TFCond_Charging:
		{
			switch (cvarTF2Jail[NoCharge].IntValue)
			{
				case 1:if (GetClientTeam(client) == BLU) TF2_RemoveCondition(client, cond);
				case 2:if (GetClientTeam(client) == RED) TF2_RemoveCondition(client, cond);
				case 3:TF2_RemoveCondition(client, cond);
			}
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	switch (cond)
	{
		case TFCond_Cloaked:
		{
			if (cvarTF2Jail[HideParticles].BoolValue)
			{
				JailFighter player = JailFighter(client);
				if (IsValidEntity(player.iRebelParticle))
					AcceptEntityInput(player.iRebelParticle, "Start");

				if (IsValidEntity(player.iFreedayParticle))
					AcceptEntityInput(player.iFreedayParticle, "Start");

				if (IsValidEntity(player.iWardenParticle))
					AcceptEntityInput(player.iWardenParticle, "Start");

				if (IsValidEntity(player.iFreekillerParticle))
					AcceptEntityInput(player.iFreekillerParticle, "Start");
			}
		}
	}
}

public void ManageRedThink(const JailFighter player)
{
	Call_OnRedThink(player);
}

public void ManageBlueThink(const JailFighter player)
{
	if (!gamemode.bDisableCriticals && cvarTF2Jail[BlueCritType].IntValue == 1)
	{
#if defined __tf_ontakedamage_included
		if (!g_bTFOTD)
#endif
		{
			TF2_AddCondition(player.index, TFCond_Buffed, 0.2);
		}
	}

	Call_OnBlueThink(player);
}

public void ManageWardenThink(const JailFighter player)
{
	Call_OnWardenThink(player);
}

public Action SoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (!bEnabled.BoolValue || !IsClientValid(entity))
		return Plugin_Continue;

	JailFighter base = JailFighter(entity);
	return Call_OnSoundHook(clients, numClients, sample, base, channel, volume, level, pitch, flags, soundEntry, seed);
}

public void ManageOnPreThink(const JailFighter base)
{
	Call_OnPreThink(base);
}

public void ManageHurtPlayer(const JailFighter attacker, const JailFighter victim, Event event)
{
	Call_OnPlayerHurt(victim, attacker, event);
}

public Action ManageOnTakeDamage(const JailFighter victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	Action action, action2;
	if (IsClientValid(attacker))
	{
		JailFighter base = JailFighter(attacker);
		if (base.bIsFreeday && victim.index != attacker)
		{	// Registers with Razorbacks ^^
			base.RemoveFreeday();
			PrintCenterTextAll("%t", "Attack Guard Lose Freeday", attacker);
		}

		if (victim.bIsFreeday && !base.bIsWarden)
		{
			damage = 0.0;
			action = Plugin_Changed;
		}

		if (victim.bSelectingLR && cvarTF2Jail[ImmunityDuringLRSelect].BoolValue)
		{
			damage = 0.0;
			action = Plugin_Changed;
		}

		if (hEngineConVars[0].BoolValue && gamemode.bWardenToggledFF
			&& GetClientTeam(victim.index) == BLU && GetClientTeam(attacker) == BLU
			&& cvarTF2Jail[FFType].IntValue == 1)
		{
			damage = 0.0;
			action = Plugin_Changed;
		}

		if (GetClientTeam(attacker) == BLU && cvarTF2Jail[BlueCritType].IntValue == 2 && !gamemode.bDisableCriticals)
		{
			damagetype |= DMG_CRIT;
			action = Plugin_Changed;
		}
		else if (GetClientTeam(attacker) == RED && GetClientTeam(victim.index) == BLU && gamemode.iRoundState == StateRunning)
			base.MarkRebel();
	}

	action2 = Call_OnTakeDamage(victim, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
	return (action > action2 ? action : action2);
}

public void ManagePlayerDeath(const JailFighter attacker, const JailFighter victim, Event event)
{
	Call_OnPlayerDied(victim, attacker, event);
}

public void CheckLivingPlayers()
{
	if (gamemode.iRoundState != StateRunning || gamemode.iTimeLeft < 0)
		return;

	if (!gamemode.bOneGuardLeft)
	{
		if (GetLivingPlayers(BLU) == 1)
		{
			if (cvarTF2Jail[RemoveFreedayOnLastGuard].BoolValue)
			{
				JailFighter base;
				for (int i = MaxClients; i; --i)
				{
					if (!IsClientInGame(i))
						continue;

					base = JailFighter(i);
					if (base.bIsFreeday)
						base.RemoveFreeday();
				}
			}
			gamemode.bOneGuardLeft = true;

			Action action = Call_OnLastGuard();

			if (action == Plugin_Continue)
				PrintCenterTextAll("%t", "One Guard Left");
			else if (action == Plugin_Stop)
				return;	// Avoid multi-calls if necessary
		}
	}
	if (!gamemode.bOnePrisonerLeft)
	{
		if (GetLivingPlayers(RED) == 1)
		{
			gamemode.bOnePrisonerLeft = true;

			if (Call_OnLastPrisoner() != Plugin_Continue)
				return;
		}
	}
	Call_OnCheckLivingPlayers();
}

public void ManageFreekilling(const JailFighter attacker)
{
	if (!cvarTF2Jail[FreeKillers].BoolValue)
		return;

	if (GetClientTeam(attacker.index) != BLU)
		return;

//	if (attacker.bIsAdmin) 	// Admin abuse :o
//		return;

	if (gamemode.iRoundState != StateRunning)
		return;

	if (gamemode.bIgnoreFreekillers || gamemode.bDisableKillSpree)
		return;

	if (attacker.bIsFreekiller)
	{
		attacker.ResetFreekillerTimer();
		return;
	}

	float currtime = GetGameTime();
	if (currtime <= attacker.flKillingSpree || attacker.flKillingSpree == 0.0)
		attacker.iKillCount++;
	else attacker.iKillCount = 0;

	if (attacker.iKillCount == cvarTF2Jail[FreeKill].IntValue)
	{
		attacker.MarkFreekiller();
		attacker.iKillCount = 0;
		attacker.flKillingSpree = 0.0;
	}
	else attacker.flKillingSpree = currtime + cvarTF2Jail[FreeKillTime].FloatValue;
}

public void ManageBuildingDestroyed(const JailFighter base, const int building, const int objecttype, Event event)
{
	Call_OnBuildingDestroyed(base, building, event);
}

public void ManageOnAirblast(const JailFighter airblaster, const JailFighter airblasted, Event event)
{
	Call_OnObjectDeflected(airblasted, airblaster, event);
}

public void ManageOnPlayerJarated(const JailFighter jarateer, const JailFighter jarateed, Event event)
{
	Call_OnPlayerJarated(jarateer, jarateed, event);
}

public void ManageUberDeployed(const JailFighter patient, const JailFighter medic, Event event)
{
	Call_OnUberDeployed(patient, medic, event);
}

public Action ManageMusic(char song[PLATFORM_MAX_PATH], float &time)
{
	return Call_OnPlayMusic(song, time);	// Defaults to Handled
}

public Action ManageTimeEnd()
{
	return Call_OnTimeEnd();
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

 	if (!IsClientValid(client))
 		return Plugin_Continue;

 	JailFighter base = JailFighter(client);
 	return Call_OnCalcAttack(base, weapon, weaponname, result);
}
// TODONT; get gud and find a way to clean this up
public void AddLRsToMenu(JailFighter player, Menu menu)
{
	int i, max, value, flags, len = gamemode.iLRs;
	char buffer[MAX_LRNAME_LENGTH*2], id[4], valuestr[16];
	LastRequest lr;

	bool vip = player.bIsVIP;

	for (i = 0; i < len; i++)
	{
		lr = LastRequest.At(i);
		if (lr == null || lr.IsDisabled())
			continue;

		max = lr.UsesPerMap();
		flags = ITEMDRAW_DEFAULT;
		valuestr[0] = '\0';

		Call_OnMenuAdd(player, lr, flags);

		if (!vip && lr.IsVIPOnly())
			flags |= ITEMDRAW_DISABLED;		// Pay2Win

		if (max > 0)
		{
			value = gamemode.hLRCount.Get(i);
			FormatEx(valuestr, sizeof(valuestr), " (%i/%i)", value, max);
			if (value >= max)
				flags |= ITEMDRAW_DISABLED;	// Disables after n selections
		}

		lr.GetName(buffer, MAX_LRNAME_LENGTH);
		StrCat(buffer, sizeof(buffer), valuestr);

		IntToString(i, id, sizeof(id));
		menu.AddItem(id, buffer, flags);
	}
}

public void AddLRToPanel(Menu &panel)
{
	char name[MAX_LRNAME_LENGTH*2], buffer[MAX_LRNAME_LENGTH], id[4];
	int i, len = gamemode.iLRs;
	LastRequest lr;

	for (i = 0; i < len; i++)
	{
		lr = LastRequest.At(i);
		if (lr == null)		// ._.
			continue;

		lr.GetName(name, MAX_LRNAME_LENGTH);
		lr.GetDescription(buffer, sizeof(buffer));

		Format(name, sizeof(name), "%s - %s", name, buffer);
		IntToString(i, id, sizeof(id));
		panel.AddItem(id, name);
	}
}

public int LRMenuHandler(Menu menu, MenuAction action, int client, int select)
{
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			LastRequest lr = LastRequest.At(select);
			if (lr == null)
				return ITEMDRAW_DEFAULT;
			if (lr.IsVIPOnly() && !JailFighter(client).bIsVIP)
				return ITEMDRAW_DISABLED;
			if (lr.UsesPerMap() > 0 && gamemode.hLRCount.Get(select) >= lr.UsesPerMap())
				return ITEMDRAW_DISABLED;
		}
		case MenuAction_Display:
			JailFighter(client).bSelectingLR = true;
		case MenuAction_Select:
		{
			if (!IsPlayerAlive(client))
				return 0;

			char strIndex[4]; menu.GetItem(select, strIndex, sizeof(strIndex));
			int request = StringToInt(strIndex);

			if (!(0 <= request < gamemode.iLRs))	// The fakest of news
				return 0;

			LastRequest lr = LastRequest.At(request);
			if (lr == null)
				return 0;

			JailFighter base;
			if (cvarTF2Jail[RemoveFreedayOnLR].BoolValue)
			{
				for (int i = MaxClients; i; --i)
				{
					if (!IsClientInGame(i))
						continue;
					base = JailFighter(i);
					if (!base.bIsFreeday)
						continue;

					base.RemoveFreeday();
				}
				CPrintToChatAll("%t %t", "Plugin Tag", "LR Chosen");
			}
			base = JailFighter(client);
			base.bSelectingLR = false;

			if (Call_OnLRPicked(lr, base) != Plugin_Continue)
				return 0;

			char buffer[256];
			lr.GetKv().GetString("Queue_Announce", buffer, sizeof(buffer));
			if (buffer[0] != '\0')
			{
				char name[32]; GetClientName(client, name, sizeof(name));
				ReplaceString(buffer, sizeof(buffer), "{NAME}", name);
				CPrintToChatAll("%t %s", "Plugin Tag", buffer);
			}

			switch (lr.GetFreedayType())
			{
				case 1: // Freeday For Yourself
					base.bIsQueuedFreeday = true;
				case 2: // Freeday For Clients
					FreedayforClientsMenu(client);
				case 3: // Freeday For All
				{
					// N/A
				}
			}

			gamemode.iLRPresetType = request;
			gamemode.bIsLRInUse = true;
			int value = gamemode.hLRCount.Get(request);
			gamemode.hLRCount.Set(request, value+1);

			Call_OnLRPickedPost(lr, base);

			if (lr.ActiveRound())
			{
				gamemode.iLRPresetType = -1;
				gamemode.iLRType = request;

				ExecuteLR(lr);
			}
		}
		case MenuAction_Cancel:
			JailFighter(client).bSelectingLR = false;
		case MenuAction_End:delete menu;
	}
	return 0;
}

public void ManageClientStartVariables(const JailFighter base)
{
	Call_OnClientInduction(base);
}

public void ResetVariables(const JailFighter base, const bool compl)
{
	base.iCustom = 0;
	base.iKillCount = 0;
	base.iRebelParticle = -1;
	base.iWardenParticle = -1;
	base.iFreedayParticle = -1;
	base.iFreekillerParticle = -1;
	base.iHealth = 0;
	base.bIsWarden = false;
	base.bLockedFromWarden = false;
	base.bInJump = false;
	base.bUnableToTeleport = false;
	base.bIsRebel = false;
	base.bIsFreekiller = false;
	base.bSkipPrep = false;
	base.flSpeed = 0.0;
	base.flKillingSpree = 0.0;
	base.flHealTime = 0.0;
	if (compl)
	{
		base.bIsMuted = false;
		base.bIsVIP = false;
		base.bIsAdmin = false;
	}
	Call_OnVariableReset(base);
}

public void ManageEntityCreated(int ent, const char[] classname)
{
	if (Call_OnEntCreated(ent, classname) != Plugin_Continue)
		return;

	if (StrContains(classname, "tf_ammo_pack", false) != -1)
		SDKHook(ent, SDKHook_Spawn, KillOnSpawn);

	if (cvarTF2Jail[KillPointServerCommand].BoolValue && !strncmp(classname, "point_serverc", 13, false))
		SDKHook(ent, SDKHook_Spawn, KillOnSpawn);

	if (cvarTF2Jail[DroppedWeapons].BoolValue && !strcmp(classname, "tf_dropped_weapon"))
		SDKHook(ent, SDKHook_Spawn, KillOnSpawn);

	if (!strcmp(classname, "func_breakable") && cvarTF2Jail[VentHit].BoolValue)
		SDKHook(ent, SDKHook_SpawnPost, HookVent);

	if (!strcmp(classname, "obj_dispenser") || !strcmp(classname, "obj_sentrygun") || !strcmp(classname, "obj_teleporter"))
		SDKHook(ent, SDKHook_Spawn, OnBuildingSpawn);
}

public void ManageWardenMenu(Menu menu)
{
	Call_OnWMenuAdd(menu);
}

public int WardenMenuHandler(Menu menu, MenuAction action, int client, int select)
 {
 	switch (action)
	{
		case MenuAction_Select:
		{
			JailFighter player = JailFighter(client);
			if (!player.bIsWarden)
			{
				CPrintToChat(client, "%t %t", "Plugin Tag", "Not Warden");
				return;
			}

			char info[32]; menu.GetItem(select, info, sizeof(info));
			char infoout[32];
			StringToLower(info, infoout, sizeof(info));
			if (Call_OnWMenuSelect(player, infoout) != Plugin_Continue)
				return;

			FakeClientCommandEx(client, infoout);
			menu.DisplayAt(client, GetMenuSelectionPosition(), 0);
			Call_OnWMenuSelectPost(player, infoout);
		}
	}
}