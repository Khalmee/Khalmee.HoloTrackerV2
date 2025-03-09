global function HoloTrackerV2Init


const float MAX_HOLOPILOT_DURATION = 10.0
array<entity> activeDecoys


void function HoloTrackerV2Init()
{
	if(!IsLobby())
	{
		thread DecoyScanningThread()
	}
}


void function DecoyScanningThread()
{
	array<entity> allDecoys
	
	while(true)
	{
		WaitFrame()
		if(!(!IsAlive(GetLocalClientPlayer()) || IsSpectating() || IsWatchingKillReplay()))
		{
			allDecoys = GetPlayerDecoyArray()
			
			foreach(d in allDecoys)
			{
				if( d != null && IsValid(d) && d.GetBossPlayer() == GetLocalClientPlayer() )
					TrackDecoy(d)
			}
		}
	}
}


void function TrackDecoy(entity decoy)
{
	foreach(d in activeDecoys)
	{
		if(decoy == d)
			return
	}
	
	thread DecoyTrackingThread(decoy)
}


void function DecoyTrackingThread(entity decoy){
	//Logger.Info("Thread began")
	
	//decoy.EndSignal( "OnDeath" )
	decoy.EndSignal( "OnDestroy" )
	
	activeDecoys.append(decoy)
	//Logger.Info("Decoy added to array")
	Logger.Info("ADDED: " + activeDecoys.len().tostring())
	Logger.Info(decoy.GetProjectileCreationTime().tostring())
	
	var rui = CreateCockpitRui( $"ui/overhead_icon_evac.rpak", MINIMAP_Z_BASE + 200 )
	RuiSetImage( rui, "icon", $"rui/menu/boosts/boost_icon_holopilot" )
	RuiSetBool( rui, "isVisible", true )
	RuiTrackFloat3( rui, "pos", decoy, RUI_TRACK_OVERHEAD_FOLLOW)
	RuiSetString( rui, "statusText", "#HOLOTRACKER_TIME_REMAINING" )
	RuiSetGameTime( rui, "finishTime", Time()+MAX_HOLOPILOT_DURATION )
	
	OnThreadEnd(
		function() : ( decoy, rui )
		{
			//while(decoy != null){ WaitFrame() } //wait till the decoy disappears (impossible)
			
			if(rui != null)
			{
				RuiDestroyIfAlive(rui)
				//rui = null //that's how it's done in vanilla, no idea why, it's illegal
				//Logger.Info("Attempted RUI destruction in OnThreadEnd")
			}
			
			activeDecoys.fastremovebyvalue(decoy)
			//Logger.Info("Decoy removed from array")
			Logger.Info("REMOVED: " + activeDecoys.len().tostring())
		}
	)
	
	waitthread DecoyWaitThread(decoy)
	
	if(rui != null)
	{
		RuiDestroyIfAlive(rui)
		//Logger.Info("Attempted RUI destruction after waitthread")
	}
	
	wait 20 //wait a long time so the decoy can dissolve in peace and not trigger the thread again, 4 seconds would be enough but better be safe than sorry
	
	//Logger.Info("Thread reached the end") //Should never happen
}


void function DecoyWaitThread(entity decoy)
{
	//The RUI must be destroyed after the decoy dies, or when its lifetime runs out.
	decoy.EndSignal( "OnDeath" )
	
	OnThreadEnd(
		function() : ( decoy )
		{
			
		}
	)
	
	float threadEndTime = Time() + MAX_HOLOPILOT_DURATION
	for(;;){
		WaitFrame()
		if(Time() > threadEndTime)
			break
	}
}

//Problem: Solve tracking after player death
//Decoys get destroyed once you enter spectator mode
//They get picked up again after respawn and their timer is reset
//
//Solution concept:
//Store active decoys on death
//Adjust time if newly detected decoy matches the saved one
//But how do we clean those up and store time?
//
//Alternatively, get spawn time and use that for time tracking, would be simple and perfect