/*
Tiers and Requirements

Pieces of scripture require certain follower counts, contruction value, and active caches in order to recite.
Drivers: Unlocked by default
Scripts: 5 servants and a cache
Applications: 8 servants, 3 caches, and 50 CV
Revenant: 10 servants and 100 CV
Judgement: 10 servants, 100 CV, and any existing AIs are converted or destroyed
*/

/datum/clockwork_scripture
	var/descname = "useless" //a simple name for the scripture's effect
	var/name = "scripture"
	var/desc = "Ancient Ratvarian lore. This piece seems particularly mundane."
	var/list/invocations = list() //Spoken over time in the ancient language of Ratvar. See clock_unsorted.dm for more details on the language and how to make it.
	var/channel_time = 10 //In deciseconds, how long a ritual takes to chant
	var/list/required_components = list("belligerent_eye" = 0, "vanguard_cogwheel" = 0, "guvax_capacitor" = 0, "replicant_alloy" = 0, "hierophant_ansible" = 0) //Components required
	var/list/consumed_components = list("belligerent_eye" = 0, "vanguard_cogwheel" = 0, "guvax_capacitor" = 0, "replicant_alloy" = 0, "hierophant_ansible" = 0) //Components consumed
	var/obj/item/clockwork/slab/slab //The parent clockwork slab
	var/mob/living/invoker //The slab's holder
	var/whispered = FALSE //If the invocation is whispered rather than spoken aloud
	var/usage_tip = "This piece seems to serve no purpose and is a waste of components." //A generalized tip that gives advice on a certain scripture
	var/invokers_required = 1 //How many people are required, assuming that a scripture requires multiple
	var/multiple_invokers_used = FALSE //If scripture requires more than one invoker
	var/multiple_invokers_optional = FALSE //If scripture can have multiple invokers to bolster its effects
	var/tier = SCRIPTURE_PERIPHERAL //The scripture's tier
	var/sort_priority = 1 //what position the scripture should have in a list of scripture. Should be based off of component costs/reqs, but you can't initial() lists.

//components the scripture used from a slab
	var/list/used_slab_components = list("belligerent_eye" = 0, "vanguard_cogwheel" = 0, "guvax_capacitor" = 0, "replicant_alloy" = 0, "hierophant_ansible" = 0)
//components the scripture used from the global cache
	var/list/used_cache_components = list("belligerent_eye" = 0, "vanguard_cogwheel" = 0, "guvax_capacitor" = 0, "replicant_alloy" = 0, "hierophant_ansible" = 0)

/datum/clockwork_scripture/proc/run_scripture()
	if(can_recite() && has_requirements() && check_special_requirements())
		if(slab.busy)
			invoker << "<span class='warning'>[slab] refuses to work, displaying the message: \"[slab.busy]!\"</span>"
			return 0
		slab.busy = "Invocation ([name]) in progress"
		if(!ratvar_awakens && !slab.no_cost)
			for(var/i in consumed_components)
				if(consumed_components[i])
					for(var/j in 1 to consumed_components[i])
						if(slab.stored_components[i])
							slab.stored_components[i]--
							used_slab_components[i]++
						else
							clockwork_component_cache[i]--
							used_cache_components[i]++
		else
			channel_time *= 0.5 //if ratvar has awoken or the slab has no cost, half channel time
		if(!check_special_requirements() || !recital() || !check_special_requirements() || !scripture_effects()) //if we fail any of these, refund components used
			for(var/i in used_slab_components)
				if(used_slab_components[i])
					if(slab)
						slab.stored_components[i] += consumed_components[i]
					else //if we can't find a slab add to the global cache
						clockwork_component_cache[i] += consumed_components[i]
			for(var/i in used_cache_components)
				if(used_cache_components[i])
					clockwork_component_cache[i] += consumed_components[i]
		else if(slab && !slab.no_cost) //if the slab exists and isn't debug, log the scripture as being used
			feedback_add_details("clockcult_scripture_recited", name)
	if(slab)
		slab.busy = null
	qdel(src)
	return 1

/datum/clockwork_scripture/proc/can_recite() //If the words can be spoken
	if(!ticker || !ticker.mode || !slab || !invoker)
		return 0
	if(!invoker.can_speak_vocal())
		invoker << "<span class='warning'>You are unable to speak the words of the scripture!</span>"
		return 0
	return 1

/datum/clockwork_scripture/proc/has_requirements() //if we have the components and invokers to do it
	if(!ratvar_awakens && !slab.no_cost)
		var/component_printout = "<span class='warning'>You lack the components to recite this piece of scripture!"
		var/failed = FALSE
		for(var/i in required_components)
			var/cache_components = clockwork_caches ? clockwork_component_cache[i] : 0
			var/total_components = slab.stored_components[i] + cache_components
			if(required_components[i] && total_components < required_components[i])
				component_printout += "\nYou have <span class='[get_component_span(i)]_small'><b>[total_components]/[required_components[i]]</b> \
				[get_component_name(i)][i != "replicant_alloy" ? "s":""].</span>"
				failed = TRUE
		if(failed)
			component_printout += "</span>"
			invoker << component_printout
			return 0
	if(multiple_invokers_used && !multiple_invokers_optional && !ratvar_awakens && !slab.no_cost)
		var/nearby_servants = 0
		for(var/mob/living/L in range(1, invoker))
			if(is_servant_of_ratvar(L) && L.stat == CONSCIOUS && L.can_speak_vocal())
				nearby_servants++
		if(nearby_servants < invokers_required)
			invoker << "<span class='warning'>There aren't enough non-mute servants nearby ([nearby_servants]/[invokers_required])!</span>"
			return 0
	return 1

/datum/clockwork_scripture/proc/check_special_requirements() //Special requirements for scriptures, checked three times during invocation
	return 1

/datum/clockwork_scripture/proc/recital() //The process of speaking the words
	if(!channel_time && invocations.len)
		if(multiple_invokers_used)
			for(var/mob/living/L in range(1, invoker))
				if(is_servant_of_ratvar(L) && L.stat == CONSCIOUS && L.can_speak_vocal())
					for(var/invocation in invocations)
						clockwork_say(L, text2ratvar(invocation), whispered)
		else
			for(var/invocation in invocations)
				clockwork_say(invoker, text2ratvar(invocation), whispered)
	invoker << "<span class='brass'>You [channel_time <= 0 ? "recite" : "begin reciting"] a piece of scripture entitled \"[name]\".</span>"
	if(!channel_time)
		return 1
	for(var/invocation in invocations)
		if(!do_after(invoker, channel_time / invocations.len, target = invoker))
			slab.busy = null
			return 0
		if(multiple_invokers_used)
			for(var/mob/living/L in range(1, invoker))
				if(is_servant_of_ratvar(L) && L.stat == CONSCIOUS && L.can_speak_vocal())
					clockwork_say(L, text2ratvar(invocation), whispered)
		else
			clockwork_say(invoker, text2ratvar(invocation), whispered)
	return 1

/datum/clockwork_scripture/proc/scripture_effects() //The actual effects of the recital after its conclusion



/datum/clockwork_scripture/channeled //Channeled scripture begins instantly but runs constantly
	var/list/chant_invocations = list("AYY LMAO")
	var/chant_amount = 5 //Times the chant is spoken
	var/chant_interval = 10 //Amount of deciseconds between times the chant is actually spoken aloud

/datum/clockwork_scripture/channeled/scripture_effects()
	for(var/i in 1 to chant_amount)
		if(!can_recite())
			break
		if(!do_after(invoker, chant_interval, target = invoker))
			break
		clockwork_say(invoker, text2ratvar(pick(chant_invocations)), whispered)
		chant_effects(i)
	if(invoker && slab)
		invoker << "<span class='brass'>You cease your chant.</span>"
		chant_end_effects()
	return 1

/datum/clockwork_scripture/channeled/proc/chant_effects(chant_number) //The chant's periodic effects
/datum/clockwork_scripture/channeled/proc/chant_end_effects() //The chant's effect upon ending



/datum/clockwork_scripture/create_object //Creates an object at the invoker's feet
	var/object_path = /obj/item/clockwork //The path of the object created
	var/creator_message = "<span class='brass'>You create a meme.</span>" //Shown to the invoker
	var/observer_message
	var/one_per_tile = FALSE
	var/prevent_path
	var/space_allowed = FALSE

/datum/clockwork_scripture/create_object/New()
	..()
	if(!prevent_path)
		prevent_path = object_path

/datum/clockwork_scripture/create_object/check_special_requirements()
	var/turf/T = get_turf(invoker)
	if(!space_allowed && isspaceturf(T))
		invoker << "<span class='warning'>You need solid ground to place this object!</span>"
		return 0
	if(one_per_tile && (locate(prevent_path) in T))
		invoker << "<span class='warning'>You can only place one of this object on each tile!</span>"
		return 0
	return 1

/datum/clockwork_scripture/create_object/scripture_effects()
	if(creator_message && observer_message)
		invoker.visible_message(observer_message, creator_message)
	else if(creator_message)
		invoker << creator_message
	new object_path (get_turf(invoker))
	return 1

/////////////
// DRIVERS //
/////////////

/datum/clockwork_scripture/channeled/belligerent //Belligerent: Channeled for up to fiteen times over thirty seconds. Forces non-servants that can hear the chant to walk. Nar-Sian cultists are burned.
	descname = "Channeled, Area Slowdown"
	name = "Belligerent"
	desc = "Forces all nearby non-servants to walk rather than run, doing minor damage. Chanted every two seconds for up to thirty seconds."
	chant_invocations = list("Punish their blindness!", "Take time, make slow!")
	chant_amount = 15
	chant_interval = 20
	required_components = list("belligerent_eye" = 1)
	usage_tip = "Useful for crowd control in a populated area and disrupting mass movement."
	tier = SCRIPTURE_DRIVER
	sort_priority = 1
	var/noncultist_damage = 2 //damage per chant to noncultists
	var/cultist_damage = 8 //damage per chant to non-walking cultists

/datum/clockwork_scripture/channeled/belligerent/chant_effects(chant_number)
	for(var/mob/living/carbon/C in hearers(7, invoker))
		var/number_legs = C.get_num_legs()
		if(!is_servant_of_ratvar(C) && !C.null_rod_check() && number_legs) //you have legs right
			C.apply_damage(noncultist_damage * 0.5, BURN, "l_leg")
			C.apply_damage(noncultist_damage * 0.5, BURN, "r_leg")
			if(C.m_intent != "walk")
				if(!iscultist(C))
					C << "<span class='warning'>Your leg[number_legs > 1 ? "s shiver":" shivers"] with pain!</span>"
				else //Cultists take extra burn damage
					C << "<span class='warning'>Your leg[number_legs > 1 ? "s burn":" burns"] with pain!</span>"
					C.apply_damage(cultist_damage * 0.5, BURN, "l_leg")
					C.apply_damage(cultist_damage * 0.5, BURN, "r_leg")
				C.m_intent = "walk"



/datum/clockwork_scripture/create_object/judicial_visor //Judicial Visor: Creates a judicial visor.
	descname = "Delayed Area Stun Glasses"
	name = "Judicial Visor"
	desc = "Forms a visor that, when worn, will grant the ability to form a flame in your hand that can be activated at an area to smite it, stunning, muting, and damaging the nonfaithful. \
	Cultists of Nar-Sie will be set on fire, though they will be stunned for half the time."
	invocations = list("Grant me the flames of Engine!")
	channel_time = 10
	required_components = list("belligerent_eye" = 2)
	consumed_components = list("belligerent_eye" = 1)
	whispered = TRUE
	object_path = /obj/item/clothing/glasses/judicial_visor
	creator_message = "<span class='brass'>You form a judicial visor, which is capable of smiting the unworthy.</span>"
	usage_tip = "The visor has a thirty-second cooldown once used, and the marker it creates has a delay of 3 seconds before exploding."
	tier = SCRIPTURE_DRIVER
	space_allowed = TRUE
	sort_priority = 2



/datum/clockwork_scripture/vanguard //Vanguard: Provides twenty seconds of stun immunity. At the end of the twenty seconds, 25% of all stuns absorbed are applied to the invoker.
	descname = "Self Stun Immunity"
	name = "Vanguard"
	desc = "Provides twenty seconds of stun immunity. At the end of the twenty seconds, the invoker is stunned for the equivalent of 25% of all stuns they absorbed. \
	Excessive absorption will cause unconsciousness."
	invocations = list("Shield me...", "...from darkness!")
	channel_time = 30
	required_components = list("vanguard_cogwheel" = 1)
	usage_tip = "You cannot reactivate Vanguard while still shielded by it."
	tier = SCRIPTURE_DRIVER
	sort_priority = 3

/datum/clockwork_scripture/vanguard/check_special_requirements()
	if(islist(invoker.stun_absorption) && invoker.stun_absorption["vanguard"] && invoker.stun_absorption["vanguard"]["end_time"] > world.time)
		invoker << "<span class='warning'>You are already shielded by a Vanguard!</span>"
		return 0
	return 1

/datum/clockwork_scripture/vanguard/scripture_effects()
	invoker.apply_status_effect(STATUS_EFFECT_VANGUARD)
	return 1



/datum/clockwork_scripture/sentinels_compromise //Sentinel's Compromise: Allows the invoker to select a nearby servant convert their brute and burn damage into half as much toxin damage.
	descname = "Convert Brute/Burn to Half Toxin"
	name = "Sentinel's Compromise"
	desc = "Heals all brute and burn damage on a nearby living, friendly servant, but deals 50% of the damage they had as toxin damage."
	invocations = list("Mend the wounds of...", "...my inferior flesh.")
	channel_time = 30
	required_components = list("vanguard_cogwheel" = 2)
	consumed_components = list("vanguard_cogwheel" = 1)
	usage_tip = "The Compromise is very fast to invoke."
	tier = SCRIPTURE_DRIVER
	sort_priority = 4

/datum/clockwork_scripture/sentinels_compromise/scripture_effects()
	var/list/nearby_cultists = list()
	for(var/mob/living/C in range(7, invoker))
		if(C.stat != DEAD && is_servant_of_ratvar(C) && (C.getBruteLoss() || C.getFireLoss()))
			nearby_cultists += C
	if(!nearby_cultists.len)
		invoker << "<span class='warning'>There are no eligible servants nearby!</span>"
		return 0
	var/mob/living/L = input(invoker, "Choose a fellow servant to heal.", name) as null|anything in nearby_cultists
	if(!L || !invoker || !invoker.canUseTopic(slab))
		return 0
	var/brutedamage = L.getBruteLoss()
	var/burndamage = L.getFireLoss()
	var/totaldamage = brutedamage + burndamage
	if(!totaldamage)
		invoker << "<span class='warning'>[L] is not burned or bruised!</span>"
		return 0
	L.adjustToxLoss(totaldamage * 0.5)
	L.adjustBruteLoss(-brutedamage)
	L.adjustFireLoss(-burndamage)
	var/healseverity = max(round(totaldamage*0.05, 1), 1) //shows the general severity of the damage you just healed, 1 glow per 20
	var/targetturf = get_turf(L)
	for(var/i in 1 to healseverity)
		PoolOrNew(/obj/effect/overlay/temp/heal, list(targetturf, "#1E8CE1"))
	invoker << "<span class='brass'>You bathe [L] in Inath-neq's power!</span>"
	L.visible_message("<span class='warning'>A blue light washes over [L], mending [L.p_their()] bruises and burns!</span>", \
	"<span class='heavy_brass'>You feel Inath-neq's power healing your wounds, but a deep nausea overcomes you!</span>")
	playsound(targetturf, 'sound/magic/Staff_Healing.ogg', 50, 1)
	return 1



/datum/clockwork_scripture/guvax //Guvax: Converts anyone adjacent to the invoker after completion.
	descname = "Melee Area Convert"
	name = "Guvax"
	desc = "Enlists all nearby living unshielded creatures into servitude to Ratvar. Also purges holy water from nearby Servants."
	invocations = list("Enlighten this heathen!", "All are insects before Engine!", "Purge all untruths and honor Engine.")
	channel_time = 50
	required_components = list("guvax_capacitor" = 1)
	usage_tip = "Only works on those in melee range and does not penetrate mindshield implants. Much more efficient than a Sigil of Submission at low Servant amounts."
	tier = SCRIPTURE_DRIVER
	sort_priority = 5

/datum/clockwork_scripture/guvax/run_scripture()
	var/servants = 0
	for(var/mob/living/M in living_mob_list)
		if(is_servant_of_ratvar(M) && (ishuman(M) || issilicon(M)))
			servants++
	if(servants > 5)
		servants -= 5
		channel_time = min(channel_time + servants*10, 200) //if above 5 servants, is much slower
	return ..()

/datum/clockwork_scripture/guvax/scripture_effects()
	for(var/mob/living/L in hearers(1, get_turf(invoker))) //Affects silicons
		if(!is_servant_of_ratvar(L))
			if(L.stat != DEAD)
				add_servant_of_ratvar(L)
		else
			if(L.reagents && L.reagents.has_reagent("holywater"))
				L.reagents.remove_reagent("holywater", 1000)
				L << "<span class='heavy_brass'>Ratvar's light flares, banishing the darkness. Your devotion remains intact!</span>"
	return 1



/datum/clockwork_scripture/channeled/taunting_tirade //Taunting Tirade: Channeled for up to five times over thirty seconds. Confuses non-servants that can hear it and allows movement for a brief time after each channel
	descname = "Channeled, Mobile Area Confusion"
	name = "Taunting Tirade"
	desc = "Weakens, confuses and dizzies all nearby non-servants with a short invocation, then allows movement for five seconds. Chanted every second for up to thirty seconds."
	chant_invocations = list("Hostiles on my back!", "Enemies on my trail!", "Gonna try and shake my tail.", "Bogeys on my six!")
	chant_amount = 5
	chant_interval = 10
	required_components = list("guvax_capacitor" = 2)
	consumed_components = list("guvax_capacitor" = 1)
	usage_tip = "Useful for fleeing attackers, as few will be able to follow someone using this scripture."
	tier = SCRIPTURE_DRIVER
	sort_priority = 6
	var/flee_time = 47 //allow fleeing for 5 seconds
	var/grace_period = 3 //very short grace period so you don't have to stop immediately
	var/datum/progressbar/progbar

/datum/clockwork_scripture/channeled/taunting_tirade/chant_effects(chant_number)
	for(var/mob/living/L in hearers(7, invoker))
		if(!is_servant_of_ratvar(L) && !L.null_rod_check())
			L.confused = min(L.confused + 20, 100)
			L.dizziness = min(L.dizziness + 20, 100)
			L.Weaken(1)
	invoker.visible_message("<span class='warning'>[invoker] is suddenly covered with a thin layer of dark purple smoke!</span>")
	invoker.color = "#AF0AAF"
	animate(invoker, color = initial(invoker.color), time = flee_time+grace_period)
	if(chant_number != chant_amount) //if this is the last chant, we don't have a movement period because the chant is over
		var/endtime = world.time + flee_time
		var/starttime = world.time
		progbar = new(invoker, flee_time, invoker)
		progbar.bar.color = "#AF0AAF"
		animate(progbar.bar, color = initial(progbar.bar.color), time = flee_time+grace_period)
		while(world.time < endtime)
			sleep(1)
			progbar.update(world.time - starttime)
		qdel(progbar)
		sleep(grace_period)

/datum/clockwork_scripture/channeled/taunting_tirade/chant_end_effects()
	qdel(progbar)



/datum/clockwork_scripture/replicant //Replicant: Creates a new clockwork slab. Doesn't use create_object because of its unique behavior.
	descname = "New Clockwork Slab"
	name = "Replicant"
	desc = "Creates a new clockwork slab."
	invocations = list("Metal, become greater!")
	channel_time = 10
	required_components = list("replicant_alloy" = 1)
	whispered = TRUE
	usage_tip = "This is inefficient as a way to produce components, as the slab produced must be held by someone with no other slabs to produce components."
	tier = SCRIPTURE_DRIVER
	sort_priority = 7

/datum/clockwork_scripture/replicant/scripture_effects()
	invoker <<  "<span class='brass'>You copy a piece of replicant alloy and command it into a new slab.</span>" //No visible message, for stealth purposes
	var/obj/item/clockwork/slab/S = new(get_turf(invoker))
	invoker.put_in_hands(S) //Put it in your hands if possible
	return 1



/datum/clockwork_scripture/create_object/tinkerers_cache //Tinkerer's Cache: Creates a tinkerer's cache.
	descname = "Necessary, Shares Components"
	name = "Tinkerer's Cache"
	desc = "Forms a cache that can store an infinite amount of components. All caches are linked and will provide components to slabs."
	invocations = list("Constructing...", "...a cache!")
	channel_time = 50
	required_components = list("belligerent_eye" = 0, "vanguard_cogwheel" = 0, "guvax_capacitor" = 0, "replicant_alloy" = 2, "hierophant_ansible" = 0)
	consumed_components = list("belligerent_eye" = 0, "vanguard_cogwheel" = 0, "guvax_capacitor" = 0, "replicant_alloy" = 1, "hierophant_ansible" = 0)
	object_path = /obj/structure/destructible/clockwork/cache
	creator_message = "<span class='brass'>You form a tinkerer's cache, which is capable of storing components, which will automatically be used by slabs.</span>"
	observer_message = "<span class='warning'>A hollow brass spire rises and begins to blaze!</span>"
	usage_tip = "Slabs will draw components from the global cache after the slab's own repositories, making caches very efficient."
	tier = SCRIPTURE_DRIVER
	one_per_tile = TRUE
	sort_priority = 8

/datum/clockwork_scripture/create_object/tinkerers_cache/New()
	var/cache_cost_increase = min(round(clockwork_caches*0.2), 5)
	for(var/i in required_components)
		if(i != "replicant_alloy")
			required_components[i] += cache_cost_increase
	for(var/i in consumed_components)
		if(i != "replicant_alloy")
			consumed_components[i] += cache_cost_increase
	return ..()



/datum/clockwork_scripture/create_object/wraith_spectacles //Wraith Spectacles: Creates a pair of wraith spectacles.
	descname = "Xray Vision Glasses"
	name = "Wraith Spectacles"
	desc = "Fabricates a pair of glasses that provides true sight but quickly damage vision, eventually causing blindness if worn for too long."
	invocations = list("Show the truth of this world to me!")
	channel_time = 10
	required_components = list("hierophant_ansible" = 1)
	whispered = TRUE
	object_path = /obj/item/clothing/glasses/wraith_spectacles
	creator_message = "<span class='brass'>You form a pair of wraith spectacles, which will grant true sight when worn.</span>"
	usage_tip = "\"True sight\" means that you are able to see through walls and in darkness."
	tier = SCRIPTURE_DRIVER
	space_allowed = TRUE
	sort_priority = 9



/datum/clockwork_scripture/create_object/sigil_of_transgression //Sigil of Transgression: Creates a sigil of transgression.
	descname = "Stun Trap"
	name = "Sigil of Transgression"
	desc = "Wards a tile with a sigil. The next person to cross the sigil will be smitten and unable to move. Nar-Sian cultists are stunned altogether."
	invocations = list("Divinity, dazzle...", "...those who tresspass here!")
	channel_time = 50
	required_components = list("hierophant_ansible" = 2)
	consumed_components = list("hierophant_ansible" = 1)
	whispered = TRUE
	object_path = /obj/effect/clockwork/sigil/transgression
	creator_message = "<span class='brass'>A sigil silently appears below you. The next non-servant to cross it will be immobilized.</span>"
	usage_tip = "The sigil, while fairly powerful in its stun, does not induce muteness in its victim."
	tier = SCRIPTURE_DRIVER
	one_per_tile = TRUE
	sort_priority = 10

/////////////
// SCRIPTS //
/////////////

/datum/clockwork_scripture/create_object/ocular_warden //Ocular Warden: Creates an ocular warden.
	descname = "Turret"
	name = "Ocular Warden"
	desc = "Forms an automatic short-range turret that deals low sustained damage to the unenlightened in its range."
	invocations = list("Guardians...", "...of the Engine...", "...defend us!")
	channel_time = 120
	required_components = list("belligerent_eye" = 2, "replicant_alloy" = 1)
	consumed_components = list("belligerent_eye" = 1, "replicant_alloy" = 1)
	object_path = /obj/structure/destructible/clockwork/ocular_warden
	creator_message = "<span class='brass'>You form an ocular warden, which will focus its searing gaze upon nearby unenlightened.</span>"
	observer_message = "<span class='warning'>A brass eye takes shape and slowly rises into the air, its red iris glaring!</span>"
	usage_tip = "Although powerful, the warden is very weak and should optimally be placed behind barricades."
	tier = SCRIPTURE_SCRIPT
	one_per_tile = TRUE
	space_allowed = TRUE
	sort_priority = 11

/datum/clockwork_scripture/create_object/ocular_warden/check_special_requirements()
	for(var/obj/structure/destructible/clockwork/ocular_warden/W in range(3, invoker))
		invoker << "<span class='alloy'>You sense another ocular warden too near this location. Placing another this close would cause them to fight.</span>" //fluff message
		return 0
	return ..()


/datum/clockwork_scripture/channeled/volt_void //Volt Void: Channeled for up to thirty times over thirty seconds. Consumes power from most power storages and deals slight burn damage to the invoker.
	descname = "Channeled, Area Power Drain"
	name = "Volt Void" //Alternative name: "On all levels but physical, I am a power sink"
	desc = "Drains energy from nearby power sources, dealing burn damage if the total power consumed is above a threshhold. Channeled every second for a maximum of thirty seconds."
	chant_invocations = list("Draw charge to this shell!")
	chant_amount = 30
	chant_interval = 10
	required_components = list("guvax_capacitor" = 1, "hierophant_ansible" = 2)
	consumed_components = list("guvax_capacitor" = 1, "hierophant_ansible" = 1)
	usage_tip = "If standing on a Sigil of Transmission, will transfer power to it. Augumented limbs will also be healed unless above a very high threshhold."
	tier = SCRIPTURE_SCRIPT
	sort_priority = 20
	var/total_power_drained = 0
	var/power_damage_threshhold = 3000
	var/augument_damage_threshhold = 6000

/datum/clockwork_scripture/channeled/volt_void/chant_effects(chant_number)
	playsound(invoker, 'sound/effects/EMPulse.ogg', 50, 1)
	var/power_drained = 0
	for(var/atom/movable/A in view(7, invoker))
		power_drained += A.power_drain(TRUE)
	var/obj/effect/clockwork/sigil/transmission/ST = locate(/obj/effect/clockwork/sigil/transmission) in get_turf(invoker)
	if(ST && power_drained >= 50)
		var/sigil_drain = 0
		while(power_drained >= 50)
			ST.modify_charge(-50)
			power_drained -= 50
			sigil_drain += 10
		power_drained += sigil_drain //readd part of the power given to the sigil to the power drained this cycle
		ST.visible_message("<span class='warning'>[ST] flares a brilliant orange!</span>")
	total_power_drained += power_drained
	if(power_drained >= 100 && total_power_drained >= power_damage_threshhold)
		var/power_damage = power_drained * 0.01
		invoker.visible_message("<span class='warning'>[invoker] flares a brilliant orange!</span>", "<span class='warning'>You feel the warmth of electricity running into your body.</span>")
		if(ishuman(invoker))
			var/mob/living/carbon/human/H = invoker
			for(var/X in H.bodyparts)
				var/obj/item/bodypart/BP = X
				if(ratvar_awakens || (BP.status == BODYPART_ROBOTIC && total_power_drained < augument_damage_threshhold)) //if ratvar is alive, it won't damage and will always heal augumented limbs
					if(BP.heal_damage(power_damage, power_damage, 1, 0)) //heals one point of burn and brute for every ~100W drained on augumented limbs
						H.update_damage_overlays()
				else
					if(BP.receive_damage(0, power_damage))
						H.update_damage_overlays()
		else if(isanimal(invoker))
			var/mob/living/simple_animal/A = invoker
			A.adjustHealth(-power_damage) //if a simple animal is using volt void, just heal it
	return 1



/datum/clockwork_scripture/create_object/clockwork_proselytizer //Clockwork Proselytizer: Creates a clockwork proselytizer.
	descname = "Necessary, Converts Objects"
	name = "Clockwork Proselytizer"
	desc = "Forms a device that, when used on certain objects, converts them into their Ratvarian equivalents. It requires replicant alloys to function."
	invocations = list("With this device...", "...his presence shall be made known.")
	channel_time = 20
	required_components = list("guvax_capacitor" = 1, "replicant_alloy" = 2)
	consumed_components = list("guvax_capacitor" = 1, "replicant_alloy" = 1)
	whispered = TRUE
	object_path = /obj/item/clockwork/clockwork_proselytizer/preloaded
	creator_message = "<span class='brass'>You form a clockwork proselytizer, which is already pre-loaded with a small amount of replicant alloy.</span>"
	usage_tip = "Clockwork walls cause adjacent tinkerer's caches to generate components passively, making them a vital tool. Clockwork floors heal servants standing on them."
	tier = SCRIPTURE_SCRIPT
	space_allowed = TRUE
	sort_priority = 17



/datum/clockwork_scripture/fellowship_armory //Fellowship Armory: Arms the invoker and nearby servants with Ratvarian armor.
	descname = "Area Servant Armor"
	name = "Fellowship Armory"
	desc = "Equips the invoker and any nearby servants with Ratvarian armor. This armor provides high melee resistance but a weakness to lasers. \
	It grows faster to invoke with more nearby servants."
	invocations = list("Shield me...", "...with the...", "... fragments of Engine!")
	channel_time = 110 //effectively 100 because it counts the invoker
	required_components = list("vanguard_cogwheel" = 2, "replicant_alloy" = 1)
	consumed_components = list("vanguard_cogwheel" = 1, "replicant_alloy" = 1)
	usage_tip = "Before using, advise adjacent allies to remove their helmets, external suits, gloves, and shoes."
	tier = SCRIPTURE_SCRIPT
	multiple_invokers_used = TRUE
	multiple_invokers_optional = TRUE
	sort_priority = 14

/datum/clockwork_scripture/fellowship_armory/run_scripture()
	for(var/mob/living/L in range(1, invoker))
		if(is_servant_of_ratvar(L) && L.can_speak_vocal())
			channel_time = max(channel_time - 10, 0)
	return ..()

/datum/clockwork_scripture/fellowship_armory/scripture_effects()
	for(var/mob/living/L in range(1, invoker))
		if(!is_servant_of_ratvar(L))
			continue
		L.visible_message("<span class='warning'>Strange armor appears on [L]!</span>", "<span class='heavy_brass'>A bright shimmer runs down your body, equipping you with Ratvarian armor.</span>")
		playsound(L, 'sound/magic/clockwork/fellowship_armory.ogg', 50, 1)
		L.equip_to_slot_or_del(new/obj/item/clothing/head/helmet/clockwork(null), slot_head)
		L.equip_to_slot_or_del(new/obj/item/clothing/suit/armor/clockwork(null), slot_wear_suit)
		L.equip_to_slot_or_del(new/obj/item/clothing/gloves/clockwork(null), slot_gloves)
		L.equip_to_slot_or_del(new/obj/item/clothing/shoes/clockwork(null), slot_shoes)
	return 1



/datum/clockwork_scripture/function_call //Function Call: Grants the invoker the ability to call forth a Ratvarian spear that deals significant damage to silicons.
	descname = "Summonable Spear"
	name = "Function Call"
	desc = "Grants the invoker the ability to call forth a powerful Ratvarian spear every three minutes. The spear will deal significant damage to Nar-Sie's dogs and silicon lifeforms, but will \
	vanish three minutes after being summoned."
	invocations = list("Grant me...", "...the might of brass!")
	channel_time = 20
	required_components = list("replicant_alloy" = 2, "hierophant_ansible" = 1)
	consumed_components = list("replicant_alloy" = 1, "hierophant_ansible" = 1)
	whispered = TRUE
	usage_tip = "You can impale human targets with the spear by pulling them, then attacking. Throwing the spear at a mob will do massive damage and stun them, but break the spear."
	tier = SCRIPTURE_SCRIPT
	sort_priority = 18

/datum/clockwork_scripture/function_call/check_special_requirements()
	for(var/datum/action/innate/function_call/F in invoker.actions)
		invoker << "<span class='warning'>You have already bound a Ratvarian spear to yourself!</span>"
		return 0
	return invoker.can_hold_items()

/datum/clockwork_scripture/function_call/scripture_effects()
	invoker.visible_message("<span class='warning'>A shimmer of yellow light infuses [invoker]!</span>", \
	"<span class='brass'>You bind a Ratvarian spear to yourself. Use the \"Function Call\" action button to call it forth.</span>")
	var/datum/action/innate/function_call/F = new()
	F.Grant(invoker)
	return 1


/datum/clockwork_scripture/spatial_gateway
	descname = "Teleport Gate"
	name = "Spatial Gateway"
	desc = "Tears open a miniaturized gateway in spacetime to any conscious servant that can transport objects or creatures to its destination. \
	Each servant assisting in the invocation adds one additional use and four additional seconds to the gateway's uses and duration."
	invocations = list("Spatial Gateway...", "...activate!")
	channel_time = 80
	required_components = list("vanguard_cogwheel" = 1, "hierophant_ansible" = 2)
	consumed_components = list("vanguard_cogwheel" = 1, "hierophant_ansible" = 1)
	multiple_invokers_used = TRUE
	multiple_invokers_optional = TRUE
	usage_tip = "This gateway is strictly one-way and will only allow things through the invoker's portal."
	tier = SCRIPTURE_SCRIPT
	sort_priority = 19

/datum/clockwork_scripture/spatial_gateway/check_special_requirements()
	if(!isturf(invoker.loc))
		invoker << "<span class='warning'>You must not be inside an object to use this scripture!</span>"
		return 0
	var/other_servants = 0
	for(var/mob/living/L in living_mob_list)
		if(is_servant_of_ratvar(L) && !L.stat != DEAD)
			other_servants++
	for(var/obj/structure/destructible/clockwork/powered/clockwork_obelisk/O in all_clockwork_objects)
		other_servants++
	if(!other_servants)
		invoker << "<span class='warning'>There are no other servants or clockwork obelisks!</span>"
		return 0
	return 1

/datum/clockwork_scripture/spatial_gateway/scripture_effects()
	var/portal_uses = 0
	var/duration = 0
	for(var/mob/living/L in range(1, invoker))
		if(!L.stat && is_servant_of_ratvar(L))
			portal_uses++
			duration += 40 //4 seconds
	if(ratvar_awakens)
		portal_uses = max(portal_uses, 100) //Very powerful if Ratvar has been summoned
		duration = max(duration, 100)
	return slab.procure_gateway(invoker, duration, portal_uses)



/datum/clockwork_scripture/create_object/soul_vessel //Soul Vessel: Creates a soul vessel
	descname = "Clockwork Posibrain"
	name = "Soul Vessel"
	desc = "Forms an ancient positronic brain with an overriding directive to serve Ratvar."
	invocations = list("Herd the souls of...", "...the blasphemous damned!")
	channel_time = 30
	required_components = list("vanguard_cogwheel" = 1, "guvax_capacitor" = 2)
	consumed_components = list("vanguard_cogwheel" = 1, "guvax_capacitor" = 1)
	whispered = TRUE
	object_path = /obj/item/device/mmi/posibrain/soul_vessel
	creator_message = "<span class='brass'>You form a soul vessel, which can be used in-hand to attract spirits, or used on an unconscious or dead human to extract their consciousness.</span>"
	usage_tip = "The vessel can be used as a teleport target for Spatial Gateway, though it is generally better-used by placing it in a shell."
	tier = SCRIPTURE_SCRIPT
	space_allowed = TRUE
	sort_priority = 16



/datum/clockwork_scripture/create_object/cogscarab //Cogscarab: Creates an empty cogscarab shell
	descname = "Constructor Soul Vessel Shell"
	name = "Cogscarab"
	desc = "Creates a small shell fitted for soul vessels. Adding an active soul vessel to it results in a small construct with tools and an inbuilt proselytizer."
	invocations = list("Call forth...", "...the workers of Armorer.")
	channel_time = 60
	required_components = list("belligerent_eye" = 2, "hierophant_ansible" = 1)
	consumed_components = list("belligerent_eye" = 1, "hierophant_ansible" = 1)
	object_path = /obj/structure/destructible/clockwork/shell/cogscarab
	creator_message = "<span class='brass'>You form a cogscarab, a constructor soul vessel receptable.</span>"
	observer_message = "<span class='warning'>The slab disgorges a puddle of black metal that contracts and forms into a strange shell!</span>"
	usage_tip = "Useless without a soul vessel and should not be created without one."
	tier = SCRIPTURE_SCRIPT
	sort_priority = 12



/datum/clockwork_scripture/create_object/sigil_of_submission //Sigil of Submission: Creates a sigil of submission.
	descname = "Conversion Trap"
	name = "Sigil of Submission"
	desc = "Places a luminous sigil that will enslave any valid beings standing on it after a time."
	invocations = list("Divinity, enlighten...", "...those who trespass here!")
	channel_time = 60
	required_components = list("belligerent_eye" = 1, "guvax_capacitor" = 2)
	consumed_components = list("belligerent_eye" = 1, "guvax_capacitor" = 1)
	whispered = TRUE
	object_path = /obj/effect/clockwork/sigil/submission
	creator_message = "<span class='brass'>A luminous sigil appears below you. The next non-servant to cross it will be enslaved after a brief time if they do not move.</span>"
	usage_tip = "This is not a primary conversion method - use Guvax for that. It is advantageous as a trap, however, as it will transmit the name of the newly-converted."
	tier = SCRIPTURE_SCRIPT
	one_per_tile = TRUE
	sort_priority = 15


//////////////////
// APPLICATIONS //
//////////////////

/datum/clockwork_scripture/create_object/anima_fragment //Anima Fragment: Creates an empty anima fragment
	descname = "Fast Soul Vessel Shell"
	name = "Anima Fragment"
	desc = "Creates a large shell fitted for soul vessels. Adding an active soul vessel to it results in a powerful construct with decent health, notable melee power, \
	and exceptional speed, though taking damage will temporarily slow it down."
	invocations = list("Call forth...", "...the soldiers of Armorer.")
	channel_time = 80
	required_components = list("belligerent_eye" = 1, "vanguard_cogwheel" = 1, "replicant_alloy" = 3)
	consumed_components = list("belligerent_eye" = 1, "vanguard_cogwheel" = 1, "replicant_alloy" = 2)
	object_path = /obj/structure/destructible/clockwork/shell/fragment
	creator_message = "<span class='brass'>You form an anima fragment, a powerful soul vessel receptable.</span>"
	observer_message = "<span class='warning'>The slab disgorges a puddle of black metal that expands and forms into a strange shell!</span>"
	usage_tip = "Useless without a soul vessel and should not be created without one."
	tier = SCRIPTURE_APPLICATION
	sort_priority = 25



/datum/clockwork_scripture/create_object/sigil_of_accession //Sigil of Accession: Creates a sigil of accession.
	descname = "Permenant Conversion Trap"
	name = "Sigil of Accession"
	desc = "Places a luminous sigil much like a Sigil of Submission, but it will remain even after successfully converting a non-implanted target. \
	It will penetrate mindshield implants once before disappearing."
	invocations = list("Divinity, enslave...", "...all who trespass here!")
	channel_time = 70
	required_components = list("belligerent_eye" = 3, "guvax_capacitor" = 1, "hierophant_ansible" = 1)
	consumed_components = list("belligerent_eye" = 2, "guvax_capacitor" = 1, "hierophant_ansible" = 1)
	whispered = TRUE
	object_path = /obj/effect/clockwork/sigil/submission/accession
	prevent_path = /obj/effect/clockwork/sigil/submission
	creator_message = "<span class='brass'>A luminous sigil appears below you. All non-servants to cross it will be enslaved after a brief time if they do not move.</span>"
	usage_tip = "It will remain after converting a target, unless that target has a mindshield implant, which it will break to convert them, but consume itself in the process."
	tier = SCRIPTURE_APPLICATION
	one_per_tile = TRUE
	sort_priority = 22



/datum/clockwork_scripture/create_object/sigil_of_transmission
	descname = "Structure Battery"
	name = "Sigil of Transmission"
	desc = "Scribes a sigil beneath the invoker which stores power to power clockwork structures."
	invocations = list("Divinity...", "...power our creations!")
	channel_time = 70
	required_components = list("vanguard_cogwheel" = 1, "guvax_capacitor" = 1, "hierophant_ansible" = 3)
	consumed_components = list("vanguard_cogwheel" = 1, "guvax_capacitor" = 1, "hierophant_ansible" = 2)
	whispered = TRUE
	object_path = /obj/effect/clockwork/sigil/transmission
	creator_message = "<span class='brass'>A sigil silently appears below you. It will automatically power clockwork structures adjecent to it.</span>"
	usage_tip = "Can be recharged by using Volt Void while standing on it."
	tier = SCRIPTURE_APPLICATION
	one_per_tile = TRUE
	sort_priority = 26



/datum/clockwork_scripture/create_object/vitality_matrix
	descname = "Damage Trap"
	name = "Vitality Matrix"
	desc = "Scribes a sigil beneath the invoker which drains life from any living non-servants that cross it. Servants that cross it, however, will be healed based on how much it drained from non-servants. \
	Dead servants can be revived by this sigil if it has enough stored vitality."
	invocations = list("Divinity...", "...steal their life...", "...for these shells!")
	channel_time = 70
	required_components = list("belligerent_eye" = 1, "vanguard_cogwheel" = 3, "hierophant_ansible" = 1)
	consumed_components = list("belligerent_eye" = 1, "vanguard_cogwheel" = 2, "hierophant_ansible" = 1)
	whispered = TRUE
	object_path = /obj/effect/clockwork/sigil/vitality
	creator_message = "<span class='brass'>A vitality matrix appears below you. It will drain life from non-servants and heal servants that cross it.</span>"
	usage_tip = "To revive a servant, the sigil must have 20 vitality plus the target servant's non-oxygen damage. It will still heal dead servants if it lacks the vitality to outright revive them."
	tier = SCRIPTURE_APPLICATION
	one_per_tile = TRUE
	sort_priority = 23


/datum/clockwork_scripture/memory_allocation //Memory Allocation: Finds a willing ghost and makes them into a clockwork marauders for the invoker.
	descname = "Guardian"
	name = "Memory Allocation"
	desc = "Allocates part of your consciousness to a Clockwork Marauder, a vigilent fighter that lives within you, able to be \
	called forth by Speaking its True Name or if you become exceptionally low on health.<br> \
	It gains Fatigue as it is attacked, weakening it. Marauders cannot move too far from their hosts, \
	and will gain Fatigue at an increasing rate as they grow farther away. At maximum Fatigue, the marauder is forced to return to you and will be unable to manifest until its Fatigue is at zero."
	invocations = list("Fright's will...", "...call forth...")
	channel_time = 100
	required_components = list("belligerent_eye" = 1, "vanguard_cogwheel" = 1, "guvax_capacitor" = 3)
	consumed_components = list("belligerent_eye" = 1, "vanguard_cogwheel" = 1, "guvax_capacitor" = 2)
	usage_tip = "Marauders are useful as personal bodyguards and frontline warriors, although they do little damage."
	tier = SCRIPTURE_APPLICATION
	sort_priority = 24

/datum/clockwork_scripture/memory_allocation/check_special_requirements()
	for(var/mob/living/simple_animal/hostile/clockwork/marauder/M in living_mob_list)
		if(M.host == invoker)
			invoker << "<span class='warning'>You can only house one marauder at a time!</span>"
			return 0
	return 1

/datum/clockwork_scripture/memory_allocation/scripture_effects()
	return create_marauder()

/datum/clockwork_scripture/memory_allocation/proc/create_marauder()
	invoker.visible_message("<span class='warning'>A yellow tendril appears from [invoker]'s [slab.name] and impales itself in [invoker.p_their()] forehead!</span>", \
	"<span class='heavy_brass'>A tendril flies from [slab] into your forehead. You begin waiting while it painfully rearranges your thought pattern...</span>")
	invoker.notransform = TRUE //Vulnerable during the process
	slab.busy = "Thought modification in process"
	if(!do_after(invoker, 50, target = invoker))
		invoker.visible_message("<span class='warning'>The tendril, covered in blood, retracts from [invoker]'s head and back into the [slab.name]!</span>", \
		"<span class='heavy_brass'>Total agony overcomes you as the tendril is forced out early!</span>")
		invoker.notransform = FALSE
		invoker.Stun(5)
		invoker.Weaken(5)
		invoker.apply_damage(10, BRUTE, "head")
		slab.busy = null
		return 0
	clockwork_say(invoker, text2ratvar("...the mind made..."))
	invoker.notransform = FALSE
	slab.busy = null
	if(!check_special_requirements())
		return 0
	invoker << "<span class='warning'>The tendril shivers slightly as it selects a marauder...</span>"
	var/list/marauder_candidates = pollCandidates("Do you want to play as the clockwork marauder of [invoker.real_name]?", ROLE_SERVANT_OF_RATVAR, null, FALSE, 100)
	if(!check_special_requirements())
		return 0
	if(!marauder_candidates.len)
		invoker.visible_message("<span class='warning'>The tendril retracts from [invoker]'s head, sealing the entry wound as it does so!</span>", \
		"<span class='warning'>The tendril was unsuccessful! Perhaps you should try again another time.</span>")
		return 0
	clockwork_say(invoker, text2ratvar("...sword and shield!"))
	var/mob/dead/observer/theghost = pick(marauder_candidates)
	var/mob/living/simple_animal/hostile/clockwork/marauder/M = new(invoker)
	M.key = theghost.key
	M.host = invoker
	M << M.playstyle_string
	M << "<b>Your true name is \"[M.true_name]\". You can change this <i>once</i> by using the Change True Name verb in your Marauder tab.</b>"
	add_servant_of_ratvar(M, TRUE)
	invoker.visible_message("<span class='warning'>The tendril retracts from [invoker]'s head, sealing the entry wound as it does so!</span>", \
	"<span class='heavy_brass'>The procedure was successful! [M.true_name], a clockwork marauder, has taken up residence in your mind. Communicate with it via the \"Linked Minds\" ability in the \
	Clockwork tab.</span>")
	invoker.verbs += /mob/living/proc/talk_with_marauder
	return 1



/datum/clockwork_scripture/create_object/interdiction_lens //Interdiction Lens: Creates a powerful totem that disables radios and cameras and drains power into nearby sigils.
	descname = "Structure, Disables Machinery"
	name = "Interdiction Lens"
	desc = "Creates a clockwork totem that sabotages nearby machinery and funnels drained power into nearby Sigils of Transmission."
	invocations = list("May this totem...", "...shroud the false suns!")
	channel_time = 80
	required_components = list("belligerent_eye" = 1, "replicant_alloy" = 4, "hierophant_ansible" = 1)
	consumed_components = list("belligerent_eye" = 1, "replicant_alloy" = 3, "hierophant_ansible" = 1)
	object_path = /obj/structure/destructible/clockwork/powered/interdiction_lens
	creator_message = "<span class='brass'>You form an interdiction lens, which disrupts cameras and radios and drains power.</span>"
	observer_message = "<span class='warning'>A brass totem rises from the ground, a purple gem appearing in its center!</span>"
	invokers_required = 2
	multiple_invokers_used = TRUE
	usage_tip = "If it fails to funnel power into a nearby Sigil of Transmission and fails to disable even one thing, it will disable itself for two minutes."
	tier = SCRIPTURE_APPLICATION
	one_per_tile = TRUE
	sort_priority = 29



/datum/clockwork_scripture/create_object/mending_motor //Mending Motor: Creates a prism that will quickly heal mechanical servants/clockwork structures and consume replicant alloy.
	descname = "Structure, Repairs Other Structures"
	name = "Mending Motor"
	desc = "Creates a mechanized prism that will rapidly repair damage to clockwork creatures, converted cyborgs, and clockwork structures. Requires replicant alloy or power to function."
	invocations = list("May this prism...", "...mend our dents and scratches!")
	channel_time = 80
	required_components = list("vanguard_cogwheel" = 4, "guvax_capacitor" = 1, "replicant_alloy" = 1)
	consumed_components = list("vanguard_cogwheel" = 3, "guvax_capacitor" = 1, "replicant_alloy" = 1)
	object_path = /obj/structure/destructible/clockwork/powered/mending_motor/prefilled
	creator_message = "<span class='brass'>You form a mending motor, which will consume power or replicant alloy to mend the wounds of mechanized servants.</span>"
	observer_message = "<span class='warning'>An onyx prism forms in midair and sprouts tendrils to support itself!</span>"
	invokers_required = 2
	multiple_invokers_used = TRUE
	usage_tip = "Powerful healing but power use is very inefficient, and its alloy use is little better."
	tier = SCRIPTURE_APPLICATION
	one_per_tile = TRUE
	sort_priority = 27



/datum/clockwork_scripture/create_object/clockwork_obelisk //Clockwork Obelisk: Creates a powerful obelisk that can be used to broadcast messages or open a gateway to any servant or clockwork obelisk.
	descname = "Structure, Teleportation Hub"
	name = "Clockwork Obelisk"
	desc = "Creates a clockwork obelisk that can broadcast messages over the Hierophant Network or open a Spatial Gateway to any living servant or clockwork obelisk."
	invocations = list("May this obelisk...", "...take us to all places!")
	channel_time = 80
	required_components = list("vanguard_cogwheel" = 1, "replicant_alloy" = 1, "hierophant_ansible" = 4)
	consumed_components = list("vanguard_cogwheel" = 1, "replicant_alloy" = 1, "hierophant_ansible" = 3)
	object_path = /obj/structure/destructible/clockwork/powered/clockwork_obelisk
	creator_message = "<span class='brass'>You form a clockwork obelisk which can broadcast messages or produce Spatial Gateways.</span>"
	observer_message = "<span class='warning'>A brass obelisk appears handing in midair!</span>"
	invokers_required = 2
	multiple_invokers_used = TRUE
	usage_tip = "Producing a gateway has a high power cost. Gateways to or between clockwork obelisks recieve double duration and uses."
	tier = SCRIPTURE_APPLICATION
	one_per_tile = TRUE
	sort_priority = 30



/datum/clockwork_scripture/create_object/mania_motor //Mania Motor: Creates a powerful obelisk that can be used to broadcast messages or open a gateway to any servant or clockwork obelisk.
	descname = "Structure, Area Denial"
	name = "Mania Motor"
	desc = "Creates a mania motor which will cause brain damage and hallucinations in nearby non-servant humans. It will also try to convert humans directly adjecent to the motor."
	invocations = list("May this transmitter...", "...break the will of all who oppose us!")
	channel_time = 80
	required_components = list("guvax_capacitor" = 4, "replicant_alloy" = 1, "hierophant_ansible" = 1)
	consumed_components = list("guvax_capacitor" = 3, "replicant_alloy" = 1, "hierophant_ansible" = 1)
	object_path = /obj/structure/destructible/clockwork/powered/mania_motor
	creator_message = "<span class='brass'>You form a mania motor which will cause brain damage and hallucinations in nearby humans while active.</span>"
	observer_message = "<span class='warning'>A two-pronged machine rises from the ground!</span>"
	invokers_required = 2
	multiple_invokers_used = TRUE
	usage_tip = "Eligible human servants next to the motor will be converted at an additional power cost. It will also cure hallucinations and brain damage in nearby servants."
	tier = SCRIPTURE_APPLICATION
	one_per_tile = TRUE
	sort_priority = 28



/datum/clockwork_scripture/create_object/tinkerers_daemon //Tinkerer's Daemon: Creates a shell that can be attached to a tinkerer's cache to grant it passive component creation.
	descname = "Component Generator"
	name = "Tinkerer's Daemon"
	desc = "Forms a daemon shell that can be attached to a tinkerer's cache to add new components at a healthy rate. It will only function if it is outnumbered by servants by a ratio of 5:1."
	invocations = list("Collect Engine parts...", "...that yet hold greatness!")
	channel_time = 80
	required_components = list("belligerent_eye" = 3, "vanguard_cogwheel" = 3, "guvax_capacitor" = 3, "replicant_alloy" = 3, "hierophant_ansible" = 3)
	consumed_components = list("belligerent_eye" = 1, "vanguard_cogwheel" = 1, "guvax_capacitor" = 1, "replicant_alloy" = 1, "hierophant_ansible" = 1)
	object_path = /obj/item/clockwork/daemon_shell
	creator_message = "<span class='brass'>You form a daemon shell. Attach it to a tinkerer's cache to increase its rate of production.</span>"
	usage_tip = "Vital to your success!"
	tier = SCRIPTURE_APPLICATION
	space_allowed = TRUE
	sort_priority = 21

/datum/clockwork_scripture/create_object/tinkerers_daemon/check_special_requirements()
	var/servants = 0
	for(var/mob/living/L in living_mob_list)
		if(is_servant_of_ratvar(L))
			servants++
	if(servants * 0.2 < clockwork_daemons)
		invoker << "<span class='nezbere'>\"Daemons are already disabled, making more of them would be a waste.\"</span>"
		return 0
	if(servants * 0.2 < clockwork_daemons+1)
		invoker << "<span class='nezbere'>\"This daemon would be useless, friend.\"</span>"
		return 0
	return ..()

//////////////
// REVENANT //
//////////////
//Revenant scriptures are different than any others. They are all very powerful, but also very costly and have drawbacks. This might be a very long invocation time or a very high component cost.

/datum/clockwork_scripture/invoke_nezbere //Invoke Nezbere, the Brass Eidolon: Invokes Nezbere, bolstering the strength of many clockwork items for one minute.
	descname = "Structure Buff"
	name = "Invoke Nezbere, the Brass Eidolon"
	desc = "Taps the limitless power of Nezbere, one of Ratvar's four generals. The restless toil of the Eidolon will empower a wide variety of clockwork apparatus for a full minute - notably, \
	clockwork proselytizers will cost no replicant alloy to use."
	invocations = list("I call upon you, Armorer!!", "Let your machinations reign on this miserable station!!", "Let your power flow through the tools of your master!!")
	channel_time = 150
	required_components = list("belligerent_eye" = 3, "vanguard_cogwheel" = 3, "guvax_capacitor" = 3, "replicant_alloy" = 6)
	consumed_components = list("belligerent_eye" = 3, "vanguard_cogwheel" = 3, "guvax_capacitor" = 3, "replicant_alloy" = 6)
	usage_tip = "Ocular wardens will become empowered, clockwork proselytizers will require no alloy, tinkerer's daemons will produce twice as quickly, \
	and interdiction lenses, mending motors, mania motors, and clockwork obelisks will all require no power."
	tier = SCRIPTURE_REVENANT
	sort_priority = 33
	invokers_required = 3
	multiple_invokers_used = TRUE

/datum/clockwork_scripture/invoke_nezbere/check_special_requirements()
	if(!slab.no_cost && clockwork_generals_invoked["nezbere"] > world.time)
		invoker << "<span class='nezbere'>\"[text2ratvar("Not just yet, friend. Patience is a virtue.")]\"</span>\n\
		<span class='warning'>Nezbere has already been invoked recently! You must wait several minutes before calling upon the Brass Eidolon.</span>"
		return 0
	if(!slab.no_cost && ratvar_awakens)
		invoker << "<span class='nezbere'>\"[text2ratvar("Our master is here already. You do not require my help, friend.")]\"</span>\n\
		<span class='warning'>Nezbere will not grant his power while Ratvar's dwarfs his own!</span>"
		return 0
	return 1

/datum/clockwork_scripture/invoke_nezbere/scripture_effects()
	new/obj/effect/clockwork/general_marker/nezbere(get_turf(invoker))
	hierophant_message("<span class='nezbere'>[text2ratvar("Armorer: \"I heed your call, champions. May your artifacts bring ruin upon the heathens that oppose our master!")]\"</span>", FALSE, invoker)
	clockwork_generals_invoked["nezbere"] = world.time + CLOCKWORK_GENERAL_COOLDOWN
	playsound(invoker, 'sound/magic/clockwork/invoke_general.ogg', 50, 0)
	for(var/obj/structure/destructible/clockwork/ocular_warden/W in all_clockwork_objects) //Ocular wardens have increased damage and radius
		W.damage_per_tick *= 1.5
		W.sight_range *= 2
	for(var/obj/item/clockwork/clockwork_proselytizer/P in all_clockwork_objects) //Proselytizers no longer require alloy
		P.uses_alloy = FALSE
	for(var/obj/item/clockwork/tinkerers_daemon/D in all_clockwork_objects) //Daemons produce components twice as quickly
		D.production_time *= 0.5
	for(var/obj/structure/destructible/clockwork/powered/M in all_clockwork_objects) //Powered clockwork structures no longer need power
		M.needs_power = FALSE
	spawn(600)
		for(var/obj/structure/destructible/clockwork/ocular_warden/W in all_clockwork_objects)
			W.damage_per_tick = initial(W.damage_per_tick)
			W.sight_range = initial(W.sight_range)
		for(var/obj/item/clockwork/clockwork_proselytizer/P in all_clockwork_objects)
			P.uses_alloy = initial(P.uses_alloy)
		for(var/obj/item/clockwork/tinkerers_daemon/D in all_clockwork_objects)
			D.production_time = initial(D.production_time)
		for(var/obj/structure/destructible/clockwork/powered/M in all_clockwork_objects)
			M.needs_power = initial(M.needs_power)
	return 1



/datum/clockwork_scripture/invoke_sevtug //Invoke Sevtug, the Formless Pariah: Causes massive global hallucinations, braindamage, confusion, and dizziness to all humans on the same zlevel.
	descname = "Global Hallucination"
	name = "Invoke Sevtug, the Formless Pariah"
	desc = "Taps the limitless power of Sevtug, one of Ratvar's four generals. The mental manipulation ability of the Pariah allows its wielder to cause mass hallucinations and confusion \
	for all non-servant humans on the same z-level as them. The power of this scripture falls off somewhat with distance, and certain things may reduce its effects."
	invocations = list("I call upon you, Fright!!", "Let your power shatter the sanity of the weak-minded!!", "Let your tendrils hold sway over all!!")
	channel_time = 150
	required_components = list("belligerent_eye" = 3, "vanguard_cogwheel" = 3, "guvax_capacitor" = 6, "hierophant_ansible" = 3)
	consumed_components = list("belligerent_eye" = 3, "vanguard_cogwheel" = 3, "guvax_capacitor" = 6, "hierophant_ansible" = 3)
	usage_tip = "Causes brain damage, hallucinations, confusion, and dizziness in massive amounts."
	tier = SCRIPTURE_REVENANT
	sort_priority = 32
	invokers_required = 3
	multiple_invokers_used = TRUE
	var/list/mindbreaksayings = list("\"Oh, great. I get to shatter some minds.\"", "\"More minds to crush.\"", \
	"\"Really, this is almost boring.\"", "\"None of these minds have anything interesting in them.\"", "\"Maybe I can instill a little bit of terror in this one.\"", \
	"\"What a waste of my power.\"", "\"I'm sure I could just control these minds instead, but they never ask.\"")

/datum/clockwork_scripture/invoke_sevtug/check_special_requirements()
	if(!slab.no_cost && clockwork_generals_invoked["sevtug"] > world.time)
		invoker << "<span class='sevtug'>\"[text2ratvar("Is it really so hard - even for a simpleton like you - to grasp the concept of waiting?")]\"</span>\n\
		<span class='warning'>Sevtug has already been invoked recently! You must wait several minutes before calling upon the Formless Pariah.</span>"
		return 0
	if(!slab.no_cost && ratvar_awakens)
		invoker << "<span class='sevtug'>\"[text2ratvar("Do you really think anything I can do right now will compare to Engine's power?")]\"</span>\n\
		<span class='warning'>Sevtug will not grant his power while Ratvar's dwarfs his own!</span>"
		return 0
	return ..()

/datum/clockwork_scripture/invoke_sevtug/scripture_effects()
	new/obj/effect/clockwork/general_marker/sevtug(get_turf(invoker))
	hierophant_message("<span class='sevtug'>[text2ratvar("Fright: \"I heed your call, idiots. Get going and use this chance while it lasts!")]\"</span>", FALSE, invoker)
	clockwork_generals_invoked["sevtug"] = world.time + CLOCKWORK_GENERAL_COOLDOWN
	playsound(invoker, 'sound/magic/clockwork/invoke_general.ogg', 50, 0)
	var/hum = get_sfx('sound/effects/screech.ogg') //like playsound, same sound for everyone affected
	var/turf/T = get_turf(invoker)
	for(var/mob/living/carbon/human/H in living_mob_list)
		if(H.z == invoker.z && !is_servant_of_ratvar(H))
			var/distance = 0
			distance += get_dist(T, get_turf(H))
			var/messaged = FALSE
			var/visualsdistance = max(150 - distance, 5)
			var/minordistance = max(200 - distance*2, 5)
			var/majordistance = max(150 - distance*3, 5)
			if(H.null_rod_check())
				visualsdistance = round(visualsdistance * 0.25)
				minordistance = round(minordistance * 0.25)
				majordistance = round(majordistance * 0.25)
				H << "<span class='sevtug'>[text2ratvar("Oh, a void weapon. How annoying, I may as well not bother.")]</span>\n\
				<span class='warning'>Your holy weapon glows a faint orange in an attempt to defend your mind!</span>"
				messaged = TRUE
			if(H.isloyal())
				visualsdistance = round(visualsdistance * 0.5) //half effect for shielded targets
				minordistance = round(minordistance * 0.5)
				majordistance = round(majordistance * 0.5)
				if(!messaged)
					H << "<span class='sevtug'>[text2ratvar("Oh, look, a mindshield. Cute, I suppose I'll humor it.")]</span>"
					messaged = TRUE
			if(!messaged && prob(visualsdistance))
				H << "<span class='sevtug'>[text2ratvar(pick(mindbreaksayings))]</span>"
			H.playsound_local(T, hum, visualsdistance, 1)
			flash_color(H, flash_color="#AF0AAF", flash_time=visualsdistance*10)
			H.set_drugginess(visualsdistance + H.druggy)
			H.dizziness = minordistance + H.dizziness
			H.hallucination = minordistance + H.hallucination
			H.confused = majordistance + H.confused
			H.setBrainLoss(majordistance + H.getBrainLoss())
	return 1



/datum/clockwork_scripture/invoke_nzcrentr //Invoke Nzcrentr, the Eternal Thunderbolt: Imbues an immense amount of energy into the invoker. After several seconds, everyone nearby will be hit with a devastating chain lightning blast.
	descname = "Lightning Blast"
	name = "Invoke Nzcrentr, the Eternal Thunderbolt"
	desc = "Taps the limitless power of Nzcrentr, one of Ratvar's four generals. The immense energy Nzcrentr wields will allow you to imbue a tiny fraction of it into your body. After several \
	seconds, anyone nearby will be struck by a devastating lightning bolt."
	invocations = list("I call upon you, Amperage!!", "Let your energy flow through me!!", "Let your boundless power shatter stars!!")
	channel_time = 150
	required_components = list("belligerent_eye" = 3, "guvax_capacitor" = 3, "replicant_alloy" = 3, "hierophant_ansible" = 6)
	consumed_components = list("belligerent_eye" = 3, "guvax_capacitor" = 3, "replicant_alloy" = 3, "hierophant_ansible" = 6)
	usage_tip = "Struck targets will also be knocked down for about sixteen seconds."
	tier = SCRIPTURE_REVENANT
	sort_priority = 34

/datum/clockwork_scripture/invoke_nzcrentr/check_special_requirements()
	if(!slab.no_cost && clockwork_generals_invoked["nzcrentr"] > world.time)
		invoker << "<span class='nzcrentr'>\"[text2ratvar("The boss says you have to wait. Hey, do you think he would mind if I killed you? ...He would? Ok.")]\"</span>\n\
		<span class='warning'>Nzcrentr has already been invoked recently! You must wait several minutes before calling upon the Forgotten Arbiter.</span>"
		return 0
	return 1

/datum/clockwork_scripture/invoke_nzcrentr/scripture_effects()
	new/obj/effect/clockwork/general_marker/nzcrentr(get_turf(invoker))
	clockwork_generals_invoked["nzcrentr"] = world.time + CLOCKWORK_GENERAL_COOLDOWN
	hierophant_message("<span class='nzcrentr'>[text2ratvar("Amperage: \"[invoker.real_name] has called forth my power. Hope they do not shatter under it!")]\"</span>", FALSE, invoker)
	invoker.visible_message("<span class='warning'>[invoker] begins to radiate a blinding light!</span>", \
	"<span class='nzcrentr'>\"[text2ratvar("The boss says it's okay to do this. Don't blame me if you die from it.")]\"</span>\n \
	<span class='userdanger'>You feel limitless power surging through you!</span>")
	playsound(invoker, 'sound/magic/clockwork/invoke_general.ogg', 50, 0)
	playsound(invoker, 'sound/magic/lightning_chargeup.ogg', 100, 0)
	animate(invoker, color = list(rgb(255, 255, 255), rgb(255, 255, 255), rgb(255, 255, 255), rgb(0,0,0)), time = 88) //Gradual advancement to extreme brightness
	sleep(88)
	if(invoker)
		invoker.visible_message("<span class='warning'>Massive bolts of energy emerge from across [invoker]'s body!</span>", \
		"<span class='nzcrentr'>\"[text2ratvar("I told you you wouldn't be able to handle it.")]\"</span>\n \
		<span class='userdanger'>TOO... MUCH! CAN'T... TAKE IT!</span>")
		playsound(invoker, 'sound/magic/lightningbolt.ogg', 100, 0)
		if(invoker.stat == CONSCIOUS)
			animate(invoker, color = initial(invoker.color), time = 10)
			for(var/mob/living/L in view(7, invoker))
				if(is_servant_of_ratvar(L))
					continue
				invoker.Beam(L, icon_state = "nzcrentrs_power", time = 10)
				var/randdamage = rand(40, 60)
				if(iscarbon(L))
					L.electrocute_act(randdamage, "Nzcrentr's power", 1, randdamage)
				else
					L.adjustFireLoss(randdamage)
					L.visible_message(
					"<span class='danger'>[L] was shocked by Nzcrentr's power!</span>", \
					"<span class='userdanger'>You feel a powerful shock coursing through your body!</span>", \
					"<span class='italics'>You hear a heavy electrical crack.</span>" \
					)
				L.Weaken(8)
				playsound(L, 'sound/magic/LightningShock.ogg', 50, 1)
		else
			playsound(invoker, 'sound/magic/Disintegrate.ogg', 50, 1)
			invoker.gib()
		return 1
	else
		return 0



/datum/clockwork_scripture/invoke_inathneq //Invoke Inath-neq, the Resonant Cogwheel: Grants invulnerability and stun immunity for 15 seconds
	descname = "Area Invuln"
	name = "Invoke Inath-neq, the Resonant Cogwheel"
	desc = "Taps the limitless power of Inath-neq, one of Ratvar's four generals. The benevolence of Inath-Neq will grant complete invulnerability to all servants in range for fifteen seconds."
	invocations = list("I call upon you, Vanguard!!", "Let the Resonant Cogs turn once more!!", "Grant me and my allies the strength to vanquish our foes!!")
	channel_time = 150
	required_components = list("vanguard_cogwheel" = 6, "guvax_capacitor" = 3, "replicant_alloy" = 3, "hierophant_ansible" = 3)
	consumed_components = list("vanguard_cogwheel" = 6, "guvax_capacitor" = 3, "replicant_alloy" = 3, "hierophant_ansible" = 3)
	usage_tip = "Those affected by this scripture are only weak to things that outright destroy bodies, such as bombs or the singularity."
	tier = SCRIPTURE_REVENANT
	sort_priority = 31
	var/total_duration = 150

/datum/clockwork_scripture/invoke_inathneq/check_special_requirements()
	if(!slab.no_cost && clockwork_generals_invoked["inath-neq"] > world.time)
		invoker << "<span class='inathneq'>\"[text2ratvar("I cannot lend you my aid yet, champion. Please be careful.")]\"</span>\n\
		<span class='warning'>Inath-neq has already been invoked recently! You must wait several minutes before calling upon the Resonant Cogwheel.</span>"
		return 0
	return 1

/datum/clockwork_scripture/invoke_inathneq/scripture_effects()
	new/obj/effect/clockwork/general_marker/inathneq(get_turf(invoker))
	hierophant_message("<span class='inathneq'>[text2ratvar("Vanguard: \"I lend you my aid, champions! Let glory guide your blows!")]\"</span>", FALSE, invoker)
	clockwork_generals_invoked["inath-neq"] = world.time + CLOCKWORK_GENERAL_COOLDOWN
	playsound(invoker, 'sound/magic/clockwork/invoke_general.ogg', 50, 0)
	if(invoker.real_name == "Lucio")
		clockwork_say(invoker, text2ratvar("Aww, let's break it DOWN!!"))
	for(var/mob/living/L in range(7, invoker))
		if(!is_servant_of_ratvar(L) || L.stat == DEAD)
			continue
		L.apply_status_effect(STATUS_EFFECT_INATHNEQS_ENDOWMENT)
	return 1



/datum/clockwork_scripture/ark_of_the_clockwork_justiciar //Ark of the Clockwork Justiciar: Creates a Gateway to the Celestial Derelict.
	descname = "Win Condition"
	name = "Ark of the Clockwork Justiciar"
	desc = "Pulls from the power of all of Ratvar's servants and generals to construct a massive machine used to tear apart a rift in spacetime to the Celestial Derelict. This gateway will \
	call forth Ratvar from his exile after some time."
	invocations = list("ARMORER! FRIGHT! AMPERAGE! VANGUARD! I CALL UPON YOU!!", \
	"THE TIME HAS COME FOR OUR MASTER TO BREAK THE CHAINS OF EXILE!!", \
	"LEND US YOUR AID! ENGINE COMES!!")
	channel_time = 150
	required_components = list("belligerent_eye" = 10, "vanguard_cogwheel" = 10, "guvax_capacitor" = 10, "replicant_alloy" = 10, "hierophant_ansible" = 10)
	consumed_components = list("belligerent_eye" = 10, "vanguard_cogwheel" = 10, "guvax_capacitor" = 10, "replicant_alloy" = 10, "hierophant_ansible" = 10)
	invokers_required = 5
	multiple_invokers_used = TRUE
	usage_tip = "The gateway is completely vulnerable to attack during its five-minute duration. It will periodically give indication of its general position to everyone on the station \
	as well as being loud enough to be heard throughout the entire sector. Defend it with your life!"
	tier = SCRIPTURE_JUDGEMENT
	sort_priority = 35

/datum/clockwork_scripture/ark_of_the_clockwork_justiciar/New()
	if(ticker && ticker.mode && ticker.mode.clockwork_objective != CLOCKCULT_GATEWAY)
		invocations = list("ARMORER! FRIGHT! AMPERAGE! VANGUARD! I CALL UPON YOU!!", \
		"THIS STATION WILL BE A BEACON OF HOPE IN THE DARKNESS OF SPACE!!", \
		"HELP US MAKE THIS SHOW ENGINE'S GLORY!!")
	..()

/datum/clockwork_scripture/ark_of_the_clockwork_justiciar/check_special_requirements()
	if(!slab.no_cost)
		if(ratvar_awakens)
			invoker << "<span class='big_brass'>\"I am already here, idiot.\"</span>"
			return 0
		for(var/obj/structure/destructible/clockwork/massive/celestial_gateway/G in all_clockwork_objects)
			var/area/gate_area = get_area(G)
			invoker << "<span class='userdanger'>There is already a gateway at [gate_area.map_name]!</span>"
			return 0
		var/area/A = get_area(invoker)
		var/turf/T = get_turf(invoker)
		if(!T || T.z != ZLEVEL_STATION || istype(A, /area/shuttle))
			invoker << "<span class='warning'>You must be on the station to activate the Ark!</span>"
			return 0
		if(clockwork_gateway_activated)
			if(ticker && ticker.mode && ticker.mode.clockwork_objective != CLOCKCULT_GATEWAY)
				invoker << "<span class='nezbere'>\"Look upon his works. Is it not glorious?\"</span>"
			else
				invoker << "<span class='warning'>Ratvar's recent banishment renders him too weak to be wrung forth from Reebe!</span>"
			return 0
	return 1

/datum/clockwork_scripture/ark_of_the_clockwork_justiciar/scripture_effects()
	var/turf/T = get_turf(invoker)
	new/obj/effect/clockwork/general_marker/inathneq(T)
	if(ticker && ticker.mode && ticker.mode.clockwork_objective == CLOCKCULT_GATEWAY)
		T.visible_message("<span class='inathneq'>\"[text2ratvar("Engine, come forth and show your servants your mercy!")]\"</span>")
	else
		T.visible_message("<span class='inathneq'>\"[text2ratvar("We will show all the mercy of Engine!")]\"</span>")
	playsound(T, 'sound/magic/clockwork/invoke_general.ogg', 30, 0)
	sleep(10)
	if(!check_special_requirements())
		return 0
	new/obj/effect/clockwork/general_marker/sevtug(T)
	if(ticker && ticker.mode && ticker.mode.clockwork_objective == CLOCKCULT_GATEWAY)
		T.visible_message("<span class='sevtug'>\"[text2ratvar("Engine, come forth and show this station your decorating skills!")]\"</span>")
	else
		T.visible_message("<span class='sevtug'>\"[text2ratvar("We will show all Engine's decorating skills.")]\"</span>")
	playsound(T, 'sound/magic/clockwork/invoke_general.ogg', 45, 0)
	sleep(10)
	if(!check_special_requirements())
		return 0
	new/obj/effect/clockwork/general_marker/nezbere(T)
	if(ticker && ticker.mode && ticker.mode.clockwork_objective == CLOCKCULT_GATEWAY)
		T.visible_message("<span class='nezbere'>\"[text2ratvar("Engine, come forth and shine your light across this realm!!")]\"</span>")
	else
		T.visible_message("<span class='nezbere'>\"[text2ratvar("We will show all Engine's light!!")]\"</span>")
	playsound(T, 'sound/magic/clockwork/invoke_general.ogg', 60, 0)
	sleep(10)
	if(!check_special_requirements())
		return 0
	new/obj/effect/clockwork/general_marker/nzcrentr(T)
	if(ticker && ticker.mode && ticker.mode.clockwork_objective == CLOCKCULT_GATEWAY)
		T.visible_message("<span class='nzcrentr'>\"[text2ratvar("Engine, come forth.")]\"</span>")
	else
		T.visible_message("<span class='nezbere'>\"[text2ratvar("We will show all Engine's power!")]\"</span>")
	playsound(T, 'sound/magic/clockwork/invoke_general.ogg', 75, 0)
	sleep(10)
	if(check_special_requirements())
		var/obj/structure/destructible/clockwork/massive/celestial_gateway/CG = new/obj/structure/destructible/clockwork/massive/celestial_gateway(T)
		if(ticker && ticker.mode && ticker.mode.clockwork_objective != CLOCKCULT_GATEWAY)
			CG.ratvar_portal = FALSE
			hierophant_message("<span class='big_brass'>This newly constructed gateway will not free Ratvar, \
			and will instead simply proselytize and convert everything and everyone on the station.</span>", TRUE)
		playsound(T, 'sound/magic/clockwork/invoke_general.ogg', 100, 0)
		var/list/open_turfs = list()
		for(var/turf/open/OT in orange(1, T))
			var/list/dense_objects = list()
			for(var/obj/O in OT)
				if(O.density && !O.CanPass(invoker, OT, 5))
					dense_objects |= O
			if(!dense_objects.len)
				open_turfs |= OT
		if(open_turfs.len)
			for(var/mob/living/L in T)
				L.forceMove(pick(open_turfs)) //shove living mobs off of the gate's new location
		return 1
	return 0
