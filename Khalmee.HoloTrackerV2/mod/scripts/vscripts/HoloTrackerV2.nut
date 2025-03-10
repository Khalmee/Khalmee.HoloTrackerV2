global function HoloTrackerV2Init


const float MAX_HOLOPILOT_DURATION = 10.0
array<entity> activeDecoys


struct decoyData
{
	int eHandle
	float creationTime
	bool expired = false
}


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
	//decoy.EndSignal( "OnDestroy" )
	
	activeDecoys.append(decoy)
	//Logger.Info("Decoy added to array")
	Logger.Info("ADDED: " + activeDecoys.len().tostring())
	Logger.Info("ID: " + decoy.GetEntIndex().tostring() + " EH:" + decoy.Dev_GetEncodedEHandle().tostring())
	
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
	
	wait 5 //leave time for the decoy to dissolve
	
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
//Nah
//
//Remove the "OnDestroy" end signal
//RUI gets deleted only on timeout or death, so after the waitthread
//rest stays the same
//should make the RUI persist after player death (hopefully)
//THIS DOESN'T WORK because dissolving decoys get picked up after respawning, increasing wait time
//Increasing time doesn't seem to work, perhaps... the entity is different after respawn?
//-left the decoy alive
//-died
//-new rui was created after respawning
//-old decoy was still in the array i think
//
//Idea: Try to use entity index for storing data about active decoys, should hopefully be the same after death, need to check

//Would need to compare all active decoys with all tracked decoys
/*
foreach td in trackedDecoys
	if activeDecoys.contains(td)
		maintainTracking
	else
		startTracking
*/
//Problem: When to remove tracked decoy IDs?
//EHandle grants the most reliable way of tracking the decoy
//Solution concept:

//RUI gets deleted every death
//We need to restore it if the entity gets picked up again
//We need to store creation time and RUI status
//Set RUI status to false on:
//Timeout
//Decoy death
//Remove stored decoy data:
//Once decoy is permanently destroyed
//Which is, if it's eHandle is no longer detected in any of the existing local player decoys
//So, we still iterate through entities, so that we can tell when the decoy gets remade, so that we can run a refreshed RUI on it

//Could place decoy cleanup in scanning thread
//Should branch out the tracking function
//one track for fresh decoy, one for existing
//If destroy gets called on entering kill replay, could make it save the decoy if the timeout hasn't happened
//So, reenable the OnDestroy signal, and have an if(Time < 15) save the struct
