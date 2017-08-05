#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <sqlx>
#include <reapi>
#include <csx>

#define PLUGIN "~Un!^Y~ T!^aNs PuB War"
#define VERSION "1.0"
#define AUTHOR "Fr0st3r.ftw aka Tejas Shirgaonkar"

//Game Description
new amx_warname

// 1 = first captain 2 = second captain.
new CaptainChoosenID
new WhoChoseThePlayer

//Ranking system.
new g_TotalKills[33]
new g_TotalDeaths[33]
new g_BombPlants[33]
new g_BombDefusions[33]
new g_TotalLeaves
new gMaxPlayers
new msgToDisplay[456] 


//get the current status of the HALF. By default false because no half started.
new bool:isFirstHalfStarted = false
new bool:isSecondHalfStarted = false

new gCptT
new gCptCT
new CaptainCount = 0
new bool:g_KnifeRound  = false

// Is Match Initialized ?
new bool:g_MatchInit = false

//Owner of: who started the match
new MatchStarterOwner = 0

//Check if captain is choosen
new bool:CaptainSChosen

// Is Match started !
new bool:g_MatchStarted = false


//Handle the score. By default to: 0 score.
new ScoreFtrstTeam = 0
new ScoreScondteam = 0

//Show menu to the first captain == winner
new ShowMenuFirst
new ShowMenuSecond

//Captains Chosen Teams.- 2 == CT & 1 == T
new FirstCaptainTeamName


//Store the name of the Captains.
new FirstCaptainName[52]
new SecondCaptainName[52]

//Temp captain Names !
new TempFirstCaptain[32]
new TempSecondCaptain[32]

//Store current map.
new szMapname[32]

new RoundCounter = 0



public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_clcmd("amx_startmatch", "ShowMenu", ADMIN_IMMUNITY, "Get All The players");    

    gMaxPlayers = get_maxplayers()

    //Change Game Description.
    amx_warname = register_cvar( "amx_warname", "-= WAR About To Start! =-" ); 
	register_forward( FM_GetGameDescription, "GameDesc" ); 

    
    register_event("SendAudio", "Event_RoundWon_T" , "a", "2&%!MRAD_terwin") 
    register_event("SendAudio", "Event_RoundWon_CT", "a", "2&%!MRAD_ctwin")
    
    register_event("DeathMsg", "Event_DeathMsg", "a")

    //block advertise by cs
    set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET);

    //Register Death.
    register_event("DeathMsg", "Event_DeathMsg_Knife", "a", "1>0")

    //For Knife round.
    register_event("CurWeapon", "Event_CurWeapon_NotKnife", "be", "1=1", "2!29")  
    
    //Round end event.
    register_logevent("round_end", 2, "1=Round_End")

    //Round start event.
    register_logevent("logevent_round_start", 2, "1=Round_Start")

    //Do not allow clients to join the team when they manually tries to join the team.
    register_clcmd("chooseteam", "cmdChooseTeam")
    register_clcmd("jointeam", "GoToTheSpec");

    //Stop or Restart the Match!
    register_clcmd("amx_stopmatch", "StopMatch", ADMIN_IMMUNITY, "Stop the Match!");
    register_clcmd("amx_restartmatch", "RestartMatch", ADMIN_IMMUNITY, "Restart the Match!");

    // T OR CT WIN.
    register_event( "SendAudio","on_TerroristWin","a","2=%!MRAD_terwin");
    register_event( "SendAudio","on_CTWin","a","2=%!MRAD_ctwin");


    //show score.
    register_clcmd("say !score", "ShowScoreToUser")

    //Get Team Players menu.
    register_clcmd("say /getmenu","GetMatchMenu")

    get_mapname(szMapname, charsmax(szMapname))


}




//Game description forward.
public GameDesc() 
{ 
	static gamename[32]; 
	get_pcvar_string( amx_warname, gamename, 31 ); 
	forward_return( FMV_STRING, gamename ); 
	return FMRES_SUPERCEDE; 
}  



//Event death.
public Event_DeathMsg_Knife()
{

    new attacker_one = read_data(1) 
	new victim_one = read_data(2) 

    if(g_MatchStarted)
    {
        if( victim_one != attacker_one && cs_get_user_team(attacker_one) != cs_get_user_team(victim_one)) 
        { 
            g_TotalKills[attacker_one]++
            g_TotalDeaths[victim_one]++

        }
    }


	return PLUGIN_HANDLED

}


public bomb_planted( planter )
{

   g_BombPlants[planter]++

}

public bomb_defused( defuser )
{
	g_BombDefusions[defuser]++
}


public GetMatchMenu(id)
{  
    if(CaptainSChosen)
    {
   

        if(id != CaptainChoosenID)
        {
          
            if(WhoChoseThePlayer == 1)
            {
                LetsSecondChoosePlayers(ShowMenuSecond)
            }

            if(WhoChoseThePlayer == 2)
            {
                LetsFirstChoosePlayers(ShowMenuFirst)
            }
            
        }
      
    }

    return PLUGIN_HANDLED
}

public RestartMatch(id,lvl,cid)
{
    if(!cmd_access(id,lvl,cid,0))
        return PLUGIN_HANDLED
    
    if(g_MatchInit || g_MatchStarted || g_KnifeRound)
    {
        //Log AMX, Who stopped the match!.
        new MatchRestarterName[32] 
        get_user_name(id, MatchRestarterName, charsmax(MatchRestarterName)) 

        new MatchRestarterAuthID[32] 
        get_user_authid(id, MatchRestarterAuthID, 31)

        log_amx("Admin %s with ID = %i and AuthID %s has restarted the Match !",MatchRestarterName,id,MatchRestarterAuthID)

        server_cmd("mp_freezetime 999");

        set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"Admin has restarted the Match ! ^n Captains will be chosen shortly..")

        set_task(8.0,"RestartMatchTask",id)

        return PLUGIN_HANDLED

    } 
    return PLUGIN_HANDLED
}

public RestartMatchTask(id)
{

    LoadPubSettings()
    ShowMenuSpecial(id)   
}

//Stop the Match.
public StopMatch(id,lvl, cid)
{

    if(!cmd_access(id, lvl, cid, 0))
		return PLUGIN_HANDLED;


    if(g_MatchInit || g_MatchStarted || g_KnifeRound)
    {
        //Log AMX, Who stopped the match!.
        new MatchStopperName[32] 
        get_user_name(id, MatchStopperName, charsmax(MatchStopperName)) 

        new MatchStopperAuthID[32] 
        get_user_authid(id, MatchStopperAuthID, 31)

        log_amx("Admin %s with AuthID %s has stopped the Match !",MatchStopperName,MatchStopperAuthID)

        server_cmd("mp_freezetime 999");

        set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"Admin has Stopped the Match ! ^n Server will restart now.")

        set_task(8.0,"RestartServerForStoppingMatch")

        return PLUGIN_HANDLED

    } 
    return PLUGIN_HANDLED
}


//Stop match special when owner is not there.
public StopMatchSpecial()
{

    if(g_MatchInit || g_MatchStarted || g_KnifeRound)
    {
        

        server_cmd("mp_freezetime 999");

        set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"Match Lord has Left the Game ! ^n Server will restart now.")

        set_task(4.0,"RestartServerForStoppingMatch")

    } 
    return PLUGIN_HANDLED
}

public RestartServerForStoppingMatch()
{
    new CurrentMap[33]
    get_mapname(CurrentMap,32)

    server_cmd("changelevel %s",CurrentMap)

    return PLUGIN_HANDLED
}


public GoToTheSpec(id)
{
    if(g_MatchInit || g_KnifeRound)
    {   
        if(is_user_connected(id))
        {
            set_task(3.0,"TransferToSpec",id)
        }
    }
}


//Terrorist Win event.
public on_TerroristWin()
{

    //Terrorrist Knife round winner.
    if(g_KnifeRound == true)
    {
        
        // T WOWN.
        ShowMenuFirst = gCptT
        ShowMenuSecond = gCptCT

        //Set Names of the Captain. because captain may leave the game.
        get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
        get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName)) 

        set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

        set_task(2.0,"FirstCaptainWonKnifeRoundMessage",gCptT)

        g_KnifeRound = false
        LoadMatchSettings()
    }

}

//CT WIN Event.
public on_CTWin()
{

    if(g_KnifeRound)
    {
        	
            // CT WON.
            ShowMenuFirst = gCptCT
            ShowMenuSecond = gCptT

             //Set Names of the Captain. because captain may leave the game.
            get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
            get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName)) 

             g_KnifeRound = false
        

            set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

            set_task(2.0,"SecondCaptWonKnifeRoundWonMessage",gCptCT)
            
            LoadMatchSettings()
    }
    
   
}


//ROUND START Event.
public logevent_round_start()
{


    if(g_KnifeRound)
    {

        set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"-= Knife Round Begins =- ^n Captain: %s ^n Vs. ^n Captain: %s",TempFirstCaptain,TempSecondCaptain)  

        chatcolor(0,"!t[ECS WAR] !g !tKnife Round !yhas !gbeen started ! ")
        chatcolor(0,"!t[ECS WAR] !g Knife War: !yCaptain- !t %s !gVs. !yCaptain- !t%s",TempFirstCaptain,TempSecondCaptain)
        chatcolor(0,"!t[ECS WAR] !g Knife War: !yCaptain- !t %s !gVs. !yCaptain- !t%s",TempFirstCaptain,TempSecondCaptain)
     
    }
    
    if(g_MatchStarted)
    {
        //Show Score info in Hud on every round start.
        ShowScoreHud()
        set_task(3.0,"ShowScoreOnRoundStart")
    }
}

//When Client join the server and if match is initialized or Knife round is running transfer player to spec.
public client_putinserver(id)
{

    g_TotalKills[id]    = 0
    g_TotalDeaths[id]   = 0
    g_BombPlants[id]    = 0
    g_BombDefusions[id] = 0

    if(g_MatchInit || g_KnifeRound)
    {
        //Transfer player to spec.
        set_task(7.0,"TransferToSpec",id)
    }

}

//Menu for restart !
public ShowMenuSpecial(id)
{

    //Store who started the match!.
    MatchStarterOwner = id

    //Log AMX, Who stopped the match!.
    new MatchStarterName[32] 
    get_user_name(id, MatchStarterName, charsmax(MatchStarterName)) 

    new MatchStarterAuthID[32] 
    get_user_authid(id, MatchStarterAuthID, 31)

    log_amx("Admin %s with AuthID %s has started the Match !",MatchStarterName,MatchStarterAuthID)

    // Match has been initialized! 
    g_MatchInit = true

   


    // TASK 1 - To Move All the players in Spec.
    cmdTransferAllInSpec();

    //Send message to players about message.
    MatchInitHudMessage()


    //Task 2 - Show Players Menu to who started the match.
    set_task(5.0, "ShowMenuPlayers", id)
    

	return PLUGIN_HANDLED;
}



//Choose Captains and Initialize Match.
public ShowMenu(id, lvl, cid)
{
	if(!cmd_access(id, lvl, cid, 0))
		return PLUGIN_HANDLED;

    if(g_MatchInit || g_MatchStarted)
    return PLUGIN_HANDLED


    MatchStarterOwner = id

    //Match initialized. 
    set_cvar_string("amx_warname","[ECS-WAR] Initialized!")

    //Log AMX, Who stopped the match!.
    new MatchStarterName[32] 
    get_user_name(id, MatchStarterName, charsmax(MatchStarterName)) 

    new MatchStarterAuthID[32] 
    get_user_authid(id, MatchStarterAuthID, 31)

    log_amx("Admin %s with ID = %i and  AuthID %s has started the Match !",MatchStarterName,id,MatchStarterAuthID)


     //Set force spawn to 1
    

    // Match has been initialized! 
    g_MatchInit = true

    // TASK 1 - To Move All the players in Spec.
    cmdTransferAllInSpec();

    //Send message to players about message.
    MatchInitHudMessage()


    //Task 2 - Show Players Menu to who started the match.
    set_task(3.0, "ShowMenuPlayers", id)
    

	return PLUGIN_HANDLED;
}

//Show HUD Message and Print message to inform player about match started !
public MatchInitHudMessage()
{
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"The Match has been Initialized ! ^n Captains will be chosen by the Match Lord.")

    chatcolor(0,"!t[ECS WAR] !g The Match has been !tInitialized.")
    chatcolor(0,"!t[ECS WAR] !g The Match has been !tInitialized.")
    chatcolor(0,"!t[ECS WAR] !g Captains will be !tchosen.")
}

public ShowMenuPlayers(id)
{
    set_cvar_string("amx_warname","Captain Selection!")

    

    new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "y" );
    menu_display( id, iMenu );

    return PLUGIN_CONTINUE;
}

MakePlayerMenu( id, const szMenuTitle[], const szMenuHandler[] )
{
    new iMenu = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[33];
    get_players( iPlayers, iNum, "h" );

    new PlayerName[128]

    for(new i=0;i<iNum;i++)
    {
        iPlayer = iPlayers[i];
        
        
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(get_user_team(iPlayer) == 3 )
        {
            
            get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

            formatex(PlayerName,127,"%s)",szPlayerName)

            formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
            menu_additem( iMenu, PlayerName, szUserId, 0 );

        }
        
        
    }


    return iMenu;
}

public PlayersMenuHandler( id, iMenu, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        // Recreate menu because user's team has been changed.
        new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
        menu_setprop( iMenu, MPROP_NUMBER_COLOR, "y" );
        menu_display( id, iMenu );

        return PLUGIN_HANDLED;
    }

    new szUserId[32], szPlayerName[32], iPlayer, iCallback;

    menu_item_getinfo( iMenu, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

    if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
    {
      
        if(CaptainCount == 0)
        {
            
            //cs_set_user_team(iPlayer, CS_TEAM_CT)
            rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)

            new ChosenCaptain[32] 
            get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
            chatcolor(0,"!t[ECS WAR] !gPlayer  !t%s chosen !yas  First !tCaptain! ", ChosenCaptain)  

            CaptainCount++  

            //Temp captain name.
            get_user_name(iPlayer, TempFirstCaptain, charsmax(TempFirstCaptain)) 
          

            //Assign CT Captain
            gCptCT = iPlayer

            //Recreate menu.
            menu_destroy(iMenu)
            new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
            menu_setprop( iMenu, MPROP_NUMBER_COLOR, "y" );
            menu_display( id, iMenu );

            return PLUGIN_HANDLED;

        }

        if(CaptainCount == 1)
        {
            
            //cs_set_user_team(iPlayer, CS_TEAM_T)
            rg_set_user_team(iPlayer,TEAM_TERRORIST,MODEL_AUTO,true)


            new ChosenCaptain[32] 
            get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
            chatcolor(0,"!t[ECS WAR] !gPlayer  !t%s chosen !yas Second !tCaptain! ", ChosenCaptain)  

            CaptainCount++


             //Temp captain name.
            get_user_name(iPlayer, TempSecondCaptain, charsmax(TempSecondCaptain)) 

            //Assign T Captain
            gCptT = iPlayer

            //Set it to true because captains have been chosen.
            CaptainSChosen = true

            //Announcement.
            set_dhudmessage(255, 0, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	        show_dhudmessage(0,"Get Ready Captains! ^n The Knife Round will Start in 10 seconds....")
            chatcolor(0,"!t[ECS WAR] !gAttention ! !yThe !tKnife Round !gWill Start in 10 seconds!")

            //Start knife round.
            set_task(10.0,"Knife_Round")

            //Captain choosing is over so destroy menu.
            menu_destroy(iMenu)
            return PLUGIN_HANDLED;
        }

        
    }
    
    // Recreate menu because user's team has been changed.
    new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "y" );
    menu_display( id, iMenu );

    return PLUGIN_HANDLED;
}

public Knife_Round()
{

    set_cvar_string("amx_warname","Captain Knife WAR")
    server_cmd("mp_autokick 0")
    server_cmd("mp_autoteambalance 0")
    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 
    set_task(10.0,"SetKnifeRoundTrue")
}

public SetKnifeRoundTrue()
{
    g_KnifeRound = true
}

//Round end Checker
public round_end()
{

    if(g_MatchStarted)
    {

       
       //Increment rounds.
        RoundCounter++


        ShowScoreHud()
        CheckForWinningTeam()

        if(RoundCounter == 15)
        {
            
            server_cmd("mp_freezetime 999")

            set_task(7.0,"SwapTeamsMessage")
            
        }

 
    }
}


//Choose the team.
public ChooseTeam(id)
{
    set_cvar_string("amx_warname","Captain Team Selection")

    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Captain %s will Choose Team and Players First !",FirstCaptainName)
    
    new TeamChooser = MakeTeamSelectorMenu( id, "Please Choose the Team.", "TeamHandler" );
    menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "y" );
    menu_display( id, TeamChooser );

}

MakeTeamSelectorMenu( id, const szMenuTitle[], const szMenuHandler[])
{
     new TeamChooser = menu_create( szMenuTitle, szMenuHandler );
     menu_additem( TeamChooser, "Counter-Terrorist" );
     menu_additem( TeamChooser, "Terrorist");

     return TeamChooser;
}

public TeamHandler(id, TeamChooser, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        // Recreate menu because user's team has been changed.
        new TeamChooser = MakeTeamSelectorMenu( id, "Please Choose the Team.", "TeamHandler" );
        menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "y" );
        menu_display( id, TeamChooser );

        return PLUGIN_HANDLED;
    }


    switch(iItem)
    {
        //Chosen CT.
        case 0:
        {
            chatcolor(0,"!t[ECS WAR] !gCaptain !t%s !ychosen Team- !gCounter-Terrorist",FirstCaptainName)

            FirstCaptainTeamName = 2
         

            if(get_user_team(id) != 2)
            {
                SwapPlayer()
            
            }
            set_cvar_string("amx_warname","=[ Players Selection ]=")
            set_task(5.0,"LetsFirstChoosePlayers",id)
        }
        //Chosen T.
        case 1:
        {

            FirstCaptainTeamName = 1
        

            chatcolor(0,"!t[ECS WAR] !gCaptain !t%s !ychosen Team- !gTerrorist",FirstCaptainName)

            if(get_user_team(id) != 1)
            {
                SwapPlayer()
            }

            set_cvar_string("amx_warname","Players Selection")
            set_task(5.0,"LetsFirstChoosePlayers",id)
        }
    }
    return PLUGIN_HANDLED;
}

// MENU TO CHOOSE PLAYERS !!!
public LetsFirstChoosePlayers(id)
{
     

    new players[32], count;     
    get_players(players, count,"eh","SPECTATOR"); 

    if(count > 0)
    {
        new iChoosePlayers = LetsFirstChoosePlayersMenu( id, "Choose A player.", "LetsFirstChoosePlayersHandler" );
        menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "y" );
        menu_display( id, iChoosePlayers );
        
        return PLUGIN_HANDLED;
    }
    else
    {
        //TEAMS ARE SET BECAUSE NO PLAYERS IN SPEC!


        

        set_cvar_string("amx_warname","Teams Are Set!")

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	    show_dhudmessage(0,"Teams are SET ! ^n ^n First Half will start Now.......")

        set_task(2.0, "GiveRestartRound"); 

        set_task(4.0,"LiveOnThreeRestart");

        set_task(8.0,"StartMatch")

        return PLUGIN_HANDLED;
    }



    
}

LetsFirstChoosePlayersMenu(id, const szMenuTitle[], const szMenuHandler[])
{


    new iChoosePlayers = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[32];
    get_players( iPlayers, iNum, "h" );

    new PlayerName[128]

    for(new i = 0 ;i<iNum;i++)
    {
        iPlayer = iPlayers[i];
       
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(get_user_team(iPlayer) == 3 )
        {             
            get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

            formatex(PlayerName,127,"%s",szPlayerName)

            formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
            menu_additem( iChoosePlayers, PlayerName, szUserId, 0 );

        }
        
    
    }
    return iChoosePlayers;
}

public LetsFirstChoosePlayersHandler( id, iChoosePlayers, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        new iChoosePlayers = LetsFirstChoosePlayersMenu( id, "Choose A player.", "LetsFirstChoosePlayersHandler" );
        menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "y" );
        menu_display( id, iChoosePlayers );
        
        return PLUGIN_HANDLED;
    }

    new szUserId[32], szPlayerName[32], iPlayer,  iCallback;
    menu_item_getinfo( iChoosePlayers, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

    if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
    {

        

        new ChoosenPlayer[32] 
        get_user_name(iPlayer, ChoosenPlayer, charsmax(ChoosenPlayer)) 
     

     

        

        if(!is_user_connected(iPlayer))
        {
            new iChoosePlayers = LetsFirstChoosePlayersMenu( id, "Choose A player.", "LetsFirstChoosePlayersHandler" );
            menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "y" );
            menu_display( id, iChoosePlayers );
            
            return PLUGIN_HANDLED;
        }
        else
        {
            CaptainChoosenID = id
            WhoChoseThePlayer = 1
            //cs_set_user_team(iPlayer, cs_get_user_team(id))
            
            new CsTeams:team = cs_get_user_team(id)

            if(team == CS_TEAM_CT)
            {
                //transfer player to ct.
                rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)
            }

            if(team == CS_TEAM_T)
            {
                //transfer player to Terrorist.
                rg_set_user_team(iPlayer,TEAM_TERRORIST,MODEL_AUTO,true)
            }

            
            LetsSecondChoosePlayers(ShowMenuSecond)
            return PLUGIN_HANDLED;
        }
    }
return PLUGIN_HANDLED;

}



// MENU TO CHOOSE PLAYERS !!!
public LetsSecondChoosePlayers(id)
{


    new players[32], count;     
    get_players(players, count,"eh","SPECTATOR"); 

    if(count > 0)
    {
        new iChoosePlayers = LetsSecondChoosePlayersMenu( id, "Choose A player.", "LetsSecondChoosePlayersHandler" );
        menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "y" );
        menu_display( id, iChoosePlayers );

        return PLUGIN_HANDLED;
    }
    else
    {
        //TEAMS ARE SET BECAUSE NO PLAYERS IN SPEC!

        set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	    show_dhudmessage(0,"Teams are SET ! ^n ^n First Half will start Now.......")
        
        set_task(2.0, "GiveRestartRound"); 

        set_task(4.0,"LiveOnThreeRestart");

        set_task(8.0,"StartMatch")

        return PLUGIN_HANDLED;
    }
    
}

LetsSecondChoosePlayersMenu(id, const szMenuTitle[], const szMenuHandler[])
{
    new iChoosePlayers = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[32];
    get_players( iPlayers, iNum, "h" );

    new PlayerName[128]

    for(new i = 0;i<iNum;i++)
    {
        iPlayer = iPlayers[i];    
 
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(get_user_team(iPlayer) == 3 )
        {
             
            get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

            formatex(PlayerName,127,"%s",szPlayerName)

            formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
            menu_additem( iChoosePlayers, PlayerName, szUserId, 0 );

        }
      
        
    }
    return iChoosePlayers;
}

public LetsSecondChoosePlayersHandler( id, iChoosePlayers, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        new iChoosePlayers = LetsSecondChoosePlayersMenu( id, "Choose A player.", "LetsSecondChoosePlayersHandler" );
        menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "y" );
        menu_display( id, iChoosePlayers ); 
        return PLUGIN_HANDLED;
    }

    new szUserId[32], szPlayerName[32], iPlayer, iCallback;
    menu_item_getinfo( iChoosePlayers, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

    if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
    {
       

        new ChoosenPlayer[32] 
        get_user_name(iPlayer, ChoosenPlayer, charsmax(ChoosenPlayer)) 
     


        if(!is_user_connected(iPlayer))
        {
            new iChoosePlayers = LetsSecondChoosePlayersMenu( id, "Choose A player.", "LetsSecondChoosePlayersHandler" );
            menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "y" );
            menu_display( id, iChoosePlayers ); 
            return PLUGIN_HANDLED;
        }
        else
        {   
            WhoChoseThePlayer = 2
            CaptainChoosenID = id
            //cs_set_user_team(iPlayer, cs_get_user_team(id))
            
            new CsTeams:team = cs_get_user_team(id)

            if(team == CS_TEAM_CT)
            {
                //transfer player to ct.
                rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)
            }

            if(team == CS_TEAM_T)
            {
                //transfer player to Terrorist.
                rg_set_user_team(iPlayer,TEAM_TERRORIST,MODEL_AUTO,true)
            }

            
            LetsFirstChoosePlayers(ShowMenuFirst);
            return PLUGIN_HANDLED;
        }
        
    }

    return PLUGIN_HANDLED;
}


public client_disconnected(id)
{
    if(CaptainSChosen || g_KnifeRound)
    {
        if(id == gCptCT || id == gCptT)
        {

            if(is_user_connected(MatchStarterOwner))
            {
                set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8, -1)
                show_hudmessage(0,"Restarting the Match! ^n One of the Captain left the Game.")

                RestartMatchTask(MatchStarterOwner)
            }
            else
            {

                StopMatchSpecial()
            }

        }
    }

    if(g_MatchStarted)
    {

        g_TotalLeaves++
        
    }


    
}

public DoRanking()
{
    new KillerName[256], DeathsName[256], BombPName[256], BombDName[256]
	new players[32], pnum, tempid
	new topKillerID, topDeathsID, topBombPID, topBombDID
	new topKills, topDeaths, topBombP, topBombD

	get_players(players, pnum)

    for ( new i ; i < pnum ; i++ )
	{
		tempid = players[i]
		
		if ( g_TotalKills[tempid] >= topKills && g_TotalKills[tempid] )
		{
			topKills = g_TotalKills[tempid]
			topKillerID = tempid
		}
		
		if ( g_TotalDeaths[tempid] >= topDeaths && g_TotalDeaths[tempid] )
		{
			topDeaths = g_TotalDeaths[tempid]
			topDeathsID = tempid
		}
		
		if ( g_BombPlants[tempid] >= topBombP && g_BombPlants[tempid] )
		{
			topBombP = g_BombPlants[tempid]
			topBombPID = tempid
		}
		
		if ( g_BombDefusions[tempid] >= topBombD && g_BombDefusions[tempid] )
		{
			topBombD = g_BombDefusions[tempid]
			topBombDID = tempid
		}
	}
	
	if ( 1 <= topKillerID <= gMaxPlayers )
		get_user_name(topKillerID, KillerName, charsmax(KillerName))
	if ( 1 <= topDeathsID <= gMaxPlayers )
		get_user_name(topDeathsID, DeathsName, charsmax(DeathsName))
	if ( 1 <= topBombPID <= gMaxPlayers )
		get_user_name(topBombPID, BombPName, charsmax(BombPName))
	if ( 1 <= topBombDID <= gMaxPlayers )
		get_user_name(topBombDID, BombDName, charsmax(BombDName))
	
	for ( new i ; i < pnum ; i++ )
	{
		tempid = players[i]
		
		if ( g_TotalKills[tempid] == topKills && tempid != topKillerID && g_TotalKills[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(KillerName, charsmax(KillerName) - strlen(BombDName) , lineToAdd)
		}
		
		if ( g_TotalDeaths[tempid] == topDeaths && tempid != topDeathsID && g_TotalDeaths[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(DeathsName, charsmax(DeathsName) - strlen(DeathsName) , lineToAdd)
		}
		
		if ( g_BombPlants[tempid] == topBombP && tempid != topBombPID && g_BombPlants[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(BombPName, charsmax(BombPName) - strlen(BombPName) , lineToAdd)
		}
		
		if ( g_BombDefusions[tempid] == topBombD && tempid != topBombDID && g_BombDefusions[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(BombDName, charsmax(BombDName) - strlen(BombDName) , lineToAdd)
		}
	}
	

    msgToDisplay = "Match Player Rankings^n-----------------------------^n^nTop Kills - %s [%d Kills]^nTop Deaths - %s [%d Deaths]^nTop Bomb Plants - %s [%d Bomb Plants]^nTop Bomb Defusions - %s [%d Bomb Defusions]^nECS-WAR Total Leavers - %d"
	format(msgToDisplay, charsmax(msgToDisplay), msgToDisplay, strlen(KillerName) ? KillerName : "NONE", topKills, strlen(DeathsName) ? DeathsName : "NONE", topDeaths,
			strlen(BombPName) ? BombPName : "NONE", topBombP, strlen(BombDName) ? BombDName : "NONE", topBombD, g_TotalLeaves)
			
    new taskId = 6969        
	set_task(1.0, "displayRankingTable", taskId, msgToDisplay, strlen(msgToDisplay), "b")

}

public displayRankingTable(msgToDisplay[], taskId)
{
	set_hudmessage(135, 135, 135, -1.0, -1.0,  0, 6.0, 6.0, 0.5, 0.15, -1)
	show_hudmessage(0, msgToDisplay)
}


// ====================== FUNCTIONS!! ===========================================================================================

//Prevent from choosing team while match is going on.
public cmdChooseTeam(id)
{
    if(g_MatchInit || g_KnifeRound || g_MatchStarted)
    {
        
        if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
        return PLUGIN_HANDLED;
        chatcolor(id, "!g[ECS WAR] !tYou cannot !gchoose !ta team !ywhile !gMatch !yis !tgoing on.");
        return PLUGIN_HANDLED;
    }
	
    return PLUGIN_CONTINUE;
}

//Checking for knife
public Event_CurWeapon_NotKnife(id)
{
    if ( !g_KnifeRound ) 
		return 

	if( !user_has_weapon(id, CSW_KNIFE ) )
		give_item(id, "weapon_knife") 
	    engclient_cmd(id, "weapon_knife")
}


//Swap teams.
public cmdTeamSwap()
{
	
	new players[32], num
	get_players(players, num)
	
	new player
	for(new i = 0; i < num; i++)
	{
		player = players[i]

        
        //rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)
		rg_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? TEAM_CT:TEAM_TERRORIST,MODEL_AUTO,true)
	}
	
	return PLUGIN_HANDLED
}

public SwapPlayer()
{

	new players[32], num
	get_players(players, num)
	
	new player
	for(new i = 0; i < num; i++)
	{
		player = players[i]
        if(get_user_team(player) != 3)
        {

            rg_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? TEAM_CT:TEAM_TERRORIST,MODEL_AUTO,true)
        }
	}
	
	return PLUGIN_HANDLED
}

public cmdTransferAllInSpec()
{

	new Players[32] 
	new playerCount, player 
	get_players(Players, playerCount, "h")

	for(new i=0; i < playerCount; i++)
	{  
        player = Players[i]

        if(is_user_connected(player))
        {
            new CsTeams:team = cs_get_user_team(player)

            if(!(team == CS_TEAM_UNASSIGNED) || !(team == CS_TEAM_SPECTATOR) )
            {
                user_kill(player)
                //cs_set_user_team(player, CS_TEAM_SPECTATOR)
                set_task(3.0,"DoTransferSpec",player)
            }
            else
            {
                user_kill(player)
            }
        }

	}

	return PLUGIN_HANDLED;
}


public DoTransferSpec(id)
{
    if(is_user_connected(id))
    {
        user_kill(id)
        rg_set_user_team(id, TEAM_SPECTATOR,MODEL_AUTO,true)
    }
    
}

public StartMatch()
{

    server_cmd("mp_forcechasecam 2")
    server_cmd("mp_forcecamera 2")
    server_cmd("mp_autokick 1")

    set_cvar_string("amx_warname","[ECS-WAR] Started!")

     //Set allow jetpack to one
    

    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    g_MatchInit = false
    
    CaptainSChosen = false
    
    //EXEC some CFG over here.    
    chatcolor(0,"!t[ECS WAR] !yPlease !gTry !yNot to !tLeave !gThe Match!")
    chatcolor(0,"!t[ECS WAR] !tFirst Half !gStarted")
    chatcolor(0,"!t[ECS WAR] !gAttention ! !yThe !tMatch !yHas Been !g STARTED !")

    new ServerName[512]

    //change server name
    // formatex(ServerName,charsmax(ServerName),"[ECS WAR]- %s VS. %s In Progress",FirstCaptainName,SecondCaptainName)
    formatex(ServerName,charsmax(ServerName),"iGC |[ECS WAR]- %s VS. %s In Progress",FirstCaptainName,SecondCaptainName)

    server_cmd("hostname ^"%s^"",ServerName)

    ServerName[0] = 0

    set_task(11.0,"MatchStartedTrue")


    //Set the status of half to first half.
    isFirstHalfStarted = true



    set_task(12.0,"FirstHalfHUDMessage")

}


//Swap Team Message !.
public SwapTeamsMessage()
{

    GiveRestartRound()

    set_task(3.0,"TeamSwapMessage")

    set_task(7.0,"FirstHalfCompletedHUDMessage")

    set_task(12.0,"SwapTeamsAndRestartMatch")
}
//Swap teams and restart the match.
public SwapTeamsAndRestartMatch()
{
    //Swap Teams.
    cmdTeamSwap()

    GiveRestartRound();

    set_task(2.0,"LiveOnThreeRestart");

    //Give Restart
    set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    chatcolor(0,"!t[ECS WAR] !gTeams !yHave Been !gSwapped !");
    chatcolor(0,"!t[ECS WAR] !gSecond half !yhas been !gStarted !");

    //Set first half status to zero.
    isFirstHalfStarted = false
    isSecondHalfStarted = true
    set_task(14.0,"SecondHalfHUDMessage")

    LoadMatchSettings()

}


public ShowScoreHud()
{

    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
        {
            format(score_message, 1023, "* [ECS-WAR] Team [ %s ] winning %i to  %i ",FirstCaptainName,ScoreFtrstTeam,ScoreScondteam)

            set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0, score_message)
        }

        if(ScoreScondteam > ScoreFtrstTeam)
        {
            format(score_message, 1023, "* [ECS-WAR] Team [ %s ] winning %i To %i",SecondCaptainName,ScoreScondteam,ScoreFtrstTeam)

            set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0, score_message)
        }

        if(ScoreFtrstTeam == ScoreScondteam)
        {
            format(score_message, 1023, "* [ECS-WAR] Both Teams Have Won %i Rounds.",ScoreScondteam)

            set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0, score_message)
        }
}

public CheckForWinningTeam()
{
    if(ScoreFtrstTeam >= 16)
    {
        //Change description of the game.
          
        new GameDescBuffer[32]
        formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreFtrstTeam,ScoreScondteam)
            
        set_cvar_string("amx_warname",GameDescBuffer)
        //screenshot_setup()
        server_cmd("mp_freezetime 99999");
        set_task(7.0,"FirstTeamWinnerMessage")
    }

    if(ScoreScondteam >= 16)
    {   

        new GameDescBuffer[32]
        formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreScondteam,ScoreFtrstTeam)
        set_cvar_string("amx_warname",GameDescBuffer)

        //screenshot_setup()
        server_cmd("mp_freezetime 99999");
        set_task(7.0,"SecondTeamWinnerMessage") 
    }
   
    if((ScoreFtrstTeam == 15) & (ScoreScondteam == 15))
    {

        set_cvar_string("amx_warname","WAR Draw!")

        server_cmd("mp_freezetime 99999");
        server_cmd("sv_restart 1"); 
        
        set_task(2.0,"MatchDrawMessage")
    }
}
// Transfer a player to spec.
public TransferToSpec(id)
{
    if(is_user_connected(id))
    {
        new CsTeams:team = cs_get_user_team(id)
   
        if( is_user_connected(id) && (team != CS_TEAM_UNASSIGNED) && (team != CS_TEAM_SPECTATOR) )
        {
            new TransferedName[32] 
            get_user_name(id, TransferedName, charsmax(TransferedName))

            user_kill(id)

            set_task(3.0,"DoTransferSpec",id)

        }
    }
    
    
    return PLUGIN_HANDLED
}


//Winner message. - First team won!
public FirstTeamWonTheMatch()
{
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ]  Won The Match !! ^n GG WP To Team %s ..",FirstCaptainName,FirstCaptainName)

    set_cvar_string("amx_warname","-= WAR About To Start! =-")
}

//Winner message. - Second team won!
public SecondTeamWonTheMatch()
{
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ] Won The Match !! ^n GG WP To Team %s  !",SecondCaptainName,SecondCaptainName)

    set_cvar_string("amx_warname","-= WAR About To Start! =-")
}

//Match is draw!
public MatchDraw()
{
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"= { Match Draw } = ^n GG WP To Both Teams :D")
    set_cvar_string("amx_warname","-= WAR About To Start! =-")
  
}


//Load Match settings because match has been started !
public LoadMatchSettings()
{

    // server_cmd("amxx pause ad_manager.amxx")
    server_cmd("sv_alltalk 0")
    server_cmd("mp_autoteambalance 0")
    server_cmd("mp_freezetime 8")
}

//Load PuB settings because Match is over!
public LoadPubSettings()
{

    set_cvar_string("amx_warname","-= WAR About To Start! =-")

    //Set some zero.
    CaptainChoosenID = 0
    WhoChoseThePlayer = 0
    g_TotalLeaves = 0
    g_TotalKills[0] = 0
    g_TotalDeaths[0] = 0
    g_BombPlants[0] = 0
    g_BombDefusions[0] = 0
    msgToDisplay[0] = 0
    remove_task(6969)

    //ALL HALF STATUS TO FALSE.
    isFirstHalfStarted = false
    isSecondHalfStarted = false


    FirstCaptainTeamName = 0

    MatchStarterOwner = 0
    CaptainSChosen = false

    g_KnifeRound = false

    
    g_MatchInit = false
    g_MatchStarted = false
    RoundCounter = 0

    gCptT = 0
    gCptCT = 0
    CaptainCount = 0

    ScoreFtrstTeam = 0
    ScoreScondteam = 0
  
    ShowMenuFirst = 0
    ShowMenuSecond = 0

  
   
    FirstCaptainName[0] = 0
    SecondCaptainName[0] = 0
  
    TempFirstCaptain[0] = 0
    TempSecondCaptain[0] = 0

    server_cmd("exec server.cfg")
    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 
    

}

public FirstTeamWinnerMessage()
{

    GiveRestartRound()


    set_task(3.0,"MatchIsOverHUDMessage")
    set_task(7.0,"SecondHalfCompletedHUDMessage")
    set_task(13.0,"FirstTeamWonTheMatch")
    set_task(20.0,"DoRanking")
    set_task(32.0,"LoadPubSettings")
}

public SecondTeamWinnerMessage()
{
    GiveRestartRound()

    set_task(3.0,"MatchIsOverHUDMessage")
    set_task(7.0,"SecondHalfCompletedHUDMessage")
    set_task(13.0,"SecondTeamWonTheMatch")
    set_task(20.0,"DoRanking")
    set_task(32.0,"LoadPubSettings")
}

public MatchDrawMessage()
{
    set_task(3.0,"MatchIsOverHUDMessage")
    set_task(7.0,"SecondHalfCompletedHUDMessage")       
    set_task(13.0,"MatchDraw")
    set_task(20.0,"DoRanking")
    set_task(32.0,"LoadPubSettings")
}

public SecondCaptWonKnifeRoundWonMessage(id)
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"Captain [ %s ] Won the Knife Round !",FirstCaptainName)

    chatcolor(0,"!t[ECS WAR] !gCaptain !t%s !gWon !ythe !tKnife Round !",FirstCaptainName)

    set_task(5.0,"ChooseTeam",gCptCT)
  
}

public FirstCaptainWonKnifeRoundMessage(id)
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"Captain [ %s ] Won the Knife Round !",FirstCaptainName)

    chatcolor(0,"!t[ECS WAR] !gCaptain !t%s !gWon !ythe !tKnife Round !",FirstCaptainName)

    set_task(5.0,"ChooseTeam",gCptT)
    
}

public ShowScoreToUser(id)
{
    if(g_MatchStarted)
    {

        if(isFirstHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
            {
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
            {    
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
            {
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
            {
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
        }

        if(isSecondHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
            {
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
            {    
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
            {
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
            {
                chatcolor(id,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
        }
    }
}

public ShowScoreOnRoundStart()
{

    new players[32],num,iPlayer
    get_players(players,num,"h");
    

    for(new i=0;i<num;i++)
    {
        iPlayer = players[i];

        if(isFirstHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(iPlayer) == 2))
            {
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
            {    
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
            {
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
            {
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponents !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
        }

        if(isSecondHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(iPlayer) == 2))
            {
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
            {    
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
            {
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
            {
                chatcolor(iPlayer,"!t[ECS WAR] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
        }
    }
    
}

//To restart the round.
public GiveRestartRound( ) 
{ 
    server_cmd( "sv_restartround ^"1^"" ); 
} 

//All MESSAGES.
public FirstHalfHUDMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ First Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!! GL & HF","LIVE !!! GL & HF","LIVE !!! GL & HF")
}

public SecondHalfHUDMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Second Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!!","LIVE !!! ","LIVE !!! ")
}

public FirstHalfCompletedHUDMessage()
{
    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ First Half Score }= ^n %s - %i ^n Winning to ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ First Falf Score }= ^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "Both Teams Have Won %i Rounds.",ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }
}


public SecondHalfCompletedHUDMessage()
{

    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ Match Score }=^n %s - %i ^n Winning To ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ Match Score }=^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "={ Match Score }=^n Both Teams Have Won %i Rounds.",ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

}

public MatchIsOverHUDMessage()
{
    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Match Is Over }=")
}

public TeamSwapMessage()
{
    set_dhudmessage(255, 255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"First Half Over! ^n Teams will be swapped Automatically. Please do not change the Team! ^n Second Half will start Now!")
}

public MatchStartedTrue()
{
    g_MatchStarted = true
}

public LiveOnThreeRestart()
{

    set_dhudmessage(42, 255, 212, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"-{ LiVe On 3 RestartS } - ^n -== LO3 =-")
}



/*
*	STOCKS
*
*/
//For color chat
stock chatcolor(const id, const input[], any:...)
{
        new count = 1, players[32]
        static msg[191]
        vformat(msg, 190, input, 3)
       
        replace_all(msg, 190, "!g", "^4") // Green Color
        replace_all(msg, 190, "!y", "^1") // Default Color
        replace_all(msg, 190, "!t", "^3") // Team Color
        replace_all(msg, 190, "!m", "^0") // Team2 Color   

        if (id) players[0] = id; else get_players(players, count, "ch")
        {
                for (new i = 0; i < count; i++)
                {
                        if (is_user_connected(players[i]))
                        {
                                message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i])
                                write_byte(players[i]);
                                write_string(msg);
                                message_end();
                        }
                }
        }
}

