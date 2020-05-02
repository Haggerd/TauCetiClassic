// A component you put on things you want to be bounded to other things.
// Warning! Can only be bounded to one thing at once.
/datum/component/bounded
	var/atom/bound_to
	var/min_dist = 0
	var/max_dist = 0

	// This callback can be used to customize how out-of-bounds situations are
	// resolved. Return TRUE if the situation was resolved.
	// This component will pass itself into it.
	var/datum/callback/resolve_callback

/datum/component/bounded/Initialize(atom/_bound_to, _min_dist, _max_dist, datum/callback/_resolve_callback)
	bound_to = _bound_to
	min_dist = _min_dist
	max_dist = _max_dist

	resolve_callback = _resolve_callback

	RegisterSignal(bound_to, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_LOC_MOVED), .proc/check_bounds)
	RegisterSignal(bound_to, list(COMSIG_PARENT_QDELETED), .proc/on_bound_destroyed)
	RegisterSignal(parent, list(COMSIG_MOVABLE_MOVED), .proc/check_bounds)
	RegisterSignal(parent, list(COMSIG_MOVABLE_PRE_MOVE), .proc/on_try_move)

	// First bounds update.
	check_bounds()

/datum/component/bounded/_RemoveFromParent()
	UnregisterSignal(bound_to, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_LOC_MOVED))
	bound_to = null

// This proc is called when we are for some reason out of bounds.
// The default bounds resolution does not take in count density, or etc.
/datum/component/bounded/proc/resolve_stranded()
	if(resolve_callback && resolve_callback.Invoke(src))
		return

	var/atom/movable/P = parent
	var/turf/T = get_turf(bound_to)

	var/new_x = P.x
	var/new_y = P.y

	// A very exotic case of item being in inventory, or some bull like that.
	var/did_jump = FALSE
	if(bound_to in parent)
		jump_out_of(parent, bound_to)
		did_jump = TRUE
	else if(parent in bound_to)
		jump_out_of(bound_to, parent)
		did_jump = TRUE

	if(did_jump)
		var/list/opts_x = list(-1, 1)
		var/list/opts_y = list(-1, 1)
		if(prob(50))
			opts_x += 0
		else
			opts_y += 0

		new_x = T.x + min_dist * pick(opts_x)
		new_y = T.y + min_dist * pick(opts_y)
		P.forceMove(locate(new_x, new_y, T.z))
		return

	if(P.x > T.x + max_dist)
		new_x = T.x + max_dist
	else if(P.x < T.x - max_dist)
		new_x = T.x - max_dist
	else if(P.x <= T.x + min_dist)
		new_x = T.x + min_dist
	else if(P.x >= T.x - min_dist)
		new_x = T.x - min_dist

	if(P.y > T.y + max_dist)
		new_y = T.y + max_dist
	else if(P.y < T.y - max_dist)
		new_y = T.y - max_dist
	else if(P.y <= T.y + min_dist)
		new_y = T.y + min_dist
	else if(P.y >= T.y - min_dist)
		new_y = T.y - min_dist

	P.forceMove(locate(new_x, new_y, T.z))

// Is called when bounds are inside bounded(or vice-versa), yet they shouldn't be.
/datum/component/bounded/proc/jump_out_of(atom/container, atom/movable/escapee)
	if(istype(escapee, /obj/item))
		if(istype(container, /obj/item/weapon/storage))
			var/obj/item/weapon/storage/S = container
			S.remove_from_storage(escapee, get_turf(container))
		else if(istype(container, /mob))
			var/mob/M = container
			M.drop_from_inventory(escapee, get_turf(container))

// This proc is called when the bounds move.
/datum/component/bounded/proc/check_bounds()
	var/dist = get_dist(parent, get_turf(bound_to))
	if(dist < min_dist || dist > max_dist)
		resolve_stranded()

// This proc is called when bound thing tries to move.
/datum/component/bounded/proc/on_try_move(datum/source, atom/newLoc, dir)
	var/dist = get_dist(newLoc, get_turf(bound_to))
	if(dist < min_dist || dist > max_dist)
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE
	return NONE

/datum/component/bounded/proc/on_bound_destroyed(force, qdel_hint)
	// Perhaps add an abilities to resolve this situation with a callback? ~Luduk
	qdel(src)
