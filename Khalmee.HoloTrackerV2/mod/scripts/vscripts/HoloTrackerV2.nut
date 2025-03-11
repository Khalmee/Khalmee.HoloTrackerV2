global function HoloTrackerV2Init


struct decoyData
{
	int eHandle
	float creationTime
	bool expired = false
}


const float MAX_HOLOPILOT_DURATION = 10.0
const float HOLOPILOT_DISSOLVE_TIME = 5.0
array<entity> activeDecoys
array<decoyData> trackedDecoyData


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
		if( IsAlive(GetLocalClientPlayer()) && !IsSpectating() && !IsWatchingKillReplay() )
		{
			CleanUpExpiredDecoyData()
			
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


void function DecoyTrackingThread(entity decoy)
{
	decoy.EndSignal( "OnDestroy" )
	
	//Set up fresh decoy data
	decoyData localTrackedDecoy
	localTrackedDecoy.eHandle = decoy.Dev_GetEncodedEHandle()
	localTrackedDecoy.creationTime = Time()
	localTrackedDecoy.expired = false
	
	bool shouldSaveDecoyData = true
	
	foreach( d in trackedDecoyData )
	{
		if( d.eHandle == localTrackedDecoy.eHandle )
		{
			localTrackedDecoy = d //Copy decoy data if the decoy was tracked earlier
			//Logger.Info( "Existing decoy detected!" )
			shouldSaveDecoyData = false
			break
		}
	}
	
	//Label decoy ENTITY as tracked
	activeDecoys.append(decoy)
	//Logger.Info("ADDED: " + activeDecoys.len().tostring())
	//Logger.Info("ID: " + decoy.GetEntIndex().tostring() + " EH:" + decoy.Dev_GetEncodedEHandle().tostring())
	
	var rui = null
	
	if( !localTrackedDecoy.expired )
	{
		//Set up RUI
		rui = CreateCockpitRui( $"ui/overhead_icon_evac.rpak", MINIMAP_Z_BASE + 200 )
		RuiSetImage( rui, "icon", $"rui/menu/boosts/boost_icon_holopilot" )
		RuiSetBool( rui, "isVisible", true )
		RuiTrackFloat3( rui, "pos", decoy, RUI_TRACK_OVERHEAD_FOLLOW)
		RuiSetString( rui, "statusText", "#HOLOTRACKER_TIME_REMAINING" )
		RuiSetGameTime( rui, "finishTime", localTrackedDecoy.creationTime+MAX_HOLOPILOT_DURATION )
	}
	
	OnThreadEnd(
		function() : ( decoy, rui, shouldSaveDecoyData, localTrackedDecoy )
		{
			//Remove RUI
			if(rui != null)
			{
				RuiDestroyIfAlive(rui)
			}
			
			//Decoy entity shouldn't exist by now, remove from entity array
			activeDecoys.fastremovebyvalue(decoy)
			//Logger.Info("REMOVED: " + activeDecoys.len().tostring())
			
			//Save decoy data
			if( shouldSaveDecoyData && localTrackedDecoy.creationTime + MAX_HOLOPILOT_DURATION + HOLOPILOT_DISSOLVE_TIME >= Time() )
			{
				trackedDecoyData.append( localTrackedDecoy )
			}
			
			//Logger.Info( "DATA: " + trackedDecoyData.len().tostring() )
		}
	)
	
	waitthread DecoyWaitThread( decoy, localTrackedDecoy.creationTime )
	
	//Remove RUI
	if(rui != null)
	{
		RuiDestroyIfAlive(rui)
	}
	
	localTrackedDecoy.expired = true //Marking decoy as expired to not create a fresh RUI if it gets detected again
	
	wait HOLOPILOT_DISSOLVE_TIME //leave some time for the decoy to dissolve
}


void function DecoyWaitThread(entity decoy, float creationTime)
{
	//The RUI must be destroyed either after the decoy dies, or when its lifetime runs out.
	decoy.EndSignal( "OnDeath" )
	
	OnThreadEnd(
		function() : ( decoy )
		{
			
		}
	)
	
	for(;;){
		WaitFrame()
		if(Time() >= creationTime + MAX_HOLOPILOT_DURATION)
			break
	}
}


void function CleanUpExpiredDecoyData()
{
	foreach( d in trackedDecoyData )
	{
		if( d.creationTime + MAX_HOLOPILOT_DURATION + HOLOPILOT_DISSOLVE_TIME < Time() )
		{
			trackedDecoyData.fastremovebyvalue( d )
			//Logger.Info( "Attempted decoy data cleanup, remaining:" + trackedDecoyData.len().tostring() )
		}
	}
}
