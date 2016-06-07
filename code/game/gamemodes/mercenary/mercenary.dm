/*
	MERCENARY ROUNDTYPE
*/

var/list/codenames = list(
	"male" = list("King", "Czar", "Boss", "Kingpin", "Director", "Emperor", "Duke", "Lord", "Baron"),
	"female" = list("Queen", "Czar", "Boss", "Kingpin", "Director", "Empress", "Duchess", "Lady", "Baronet")
	)

var/list/codenames_last = list(
	"male" = list("King", "Czar", "Boss", "Kingpin", "Director", "Emperor", "Duke", "Lord", "Baron"),
	"female" = list("Queen", "Czar", "Boss", "Kingpin", "Director", "Empress", "Duchess", "Lady", "Baronet")
	)

/datum/game_mode
	var/datum/contract/merc_contract = null

/datum/game_mode/mercenary
	name = "mercenary"
	config_tag = "mercenary"
	required_players = 1
	required_players_secret = 25 // 25 players - 5 players to be the nuke ops = 20 players remaining
	required_enemies = 1
	recommended_enemies = 5

	var/const/agents_possible = 5 //If we ever need more syndicate agents.
	var/const/waittime_l = 600 //lower bound on time before intercept arrives (in tenths of seconds)
	var/const/waittime_h = 1800 //upper bound on time before intercept arrives (in tenths of seconds)

/datum/game_mode/mercenary/announce()

/datum/game_mode/mercenary/can_start()
	if(!..())
		return 0

	var/list/possible_syndicates = get_players_for_role(BE_OPERATIVE)
	if(possible_syndicates.len < 1)
		return 0

	return 1

/datum/game_mode/mercenary/pre_setup()
	var/list/possible_syndicates = get_players_for_role(BE_OPERATIVE)

	// Merc number should scale to active crew.
	var/n_players = num_players()
	var/agent_number = n_players//Clamp((n_players/5), 2, 6)

	if(possible_syndicates.len < agent_number)
		agent_number = possible_syndicates.len

	for(var/i; i < agent_number; i++)
		var/datum/mind/new_syndicate = pick(possible_syndicates)
		new_syndicate.antagonist = new /datum/antagonist/mercenary(new_syndicate)
		new_syndicate.antagonist.randomize_character()
		new_syndicate.assigned_role = "MODE" //So they aren't chosen for other jobs.

		syndicates += new_syndicate
		possible_syndicates -= new_syndicate //So it doesn't pick the same guy each time.
		agent_number--

	return 1

/datum/game_mode/mercenary/post_setup()
	var/datum/faction/faction = faction_controller.get_faction("Gorlex Mercenaries")


	var/list/contract_candidates = subtypes(/datum/contract/mercenary)
	var/path = pick(contract_candidates)
	var/datum/contract/mercenary/contract = new path(faction)

	while(isnull(contract) && contract_candidates.len)
		contract_candidates -= path
		if(!contract_candidates.len)
			break
		path = pick(contract_candidates)
		contract = new path(faction)

	if(isnull(contract)) // shiieet
		world << "<B><font color=red>The mercenary gamemode couldn't find a contract! Something has gone horribly wrong!</font></B>"
		return 0
	merc_contract = contract

	var/spawnpos = 1
	for(var/datum/mind/synd_mind in syndicates)
		if(spawnpos > synd_spawn.len)
			spawnpos = 1
		synd_mind.current.loc = synd_spawn[spawnpos]

		var/codename = pick(codenames[synd_mind.current.gender])
		codenames[synd_mind.current.gender] -= codename
		synd_mind.character.name = "[codename] Gorlex"
		synd_mind.current.name = "[codename] Gorlex"
		synd_mind.current.real_name = "[codename] Gorlex"

		merc_contract.start(synd_mind.current)
		synd_mind.antagonist.setup()

		spawnpos++
		update_synd_icons_added(synd_mind)

	update_all_synd_icons()

	spawn (rand(waittime_l, waittime_h))
		send_intercept()

	return ..()

/datum/game_mode/mercenary/check_finished()
	..()
	if( merc_contract.finished )
		return 1
	return 0

/datum/game_mode/proc/are_operatives_dead()
	for(var/datum/mind/operative_mind in syndicates)
		if (!istype(operative_mind.current,/mob/living/carbon/human))
			if(operative_mind.current)
				if(operative_mind.current.stat!=2)
					return 0
	return 1

/datum/game_mode/proc/auto_declare_completion_mercenary()
	if( syndicates.len )
		var/text = ""

		if( merc_contract.completed )
			feedback_set_details("round_end_result","win - mercenary")
			text += "<font size=3 color=red><B>Mercenary Victory!</B></font><br>"
			text += "<B>The Gorlex operatives have completed their contract!</B><br><br>"
			text += "Their contract was:<br>"
			text += "<B>[merc_contract.informal_name]</B>"
		else
			feedback_set_details("round_end_result","lose - mercenary - failed contract")
			text += "<font size=3 color=green><B>Crew Victory!</B></font><br>"
			text += "<B>The crew prevented the Gorlex operatives from completing their objective!</B><br><br>"
			text += "Their contract was:<br>"
			text += "<B>[merc_contract.informal_name]</B>"
		text += "<br><br>"

		text += "<font size=2>The mercenaries were:</font><br>"
		for(var/datum/mind/syndicate in syndicates)
			text += "<B>[syndicate.character.name]</B>, played by <B>[syndicate.key]</B><br>"

		world << text
	return 1