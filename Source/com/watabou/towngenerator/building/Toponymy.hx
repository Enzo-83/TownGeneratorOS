package com.watabou.towngenerator.building;

import com.watabou.utils.Random;

import com.watabou.towngenerator.wards.*;

using com.watabou.utils.ArrayExtender;

/**
	District and settlement names.

	Compositional rather than Markov: the names this generator is imitating
	("Silver Rock", "North Slums", "Rose Gate", "Ostrich Market") are almost
	all modifier + head noun, and a head noun chosen from the ward's own type
	is what makes a market read as a market. A character-level chain trained
	on a small corpus produces mush and cannot be steered that way.
**/
class Toponymy {

	// Colours, materials, trades, plants, animals, weather — the stock of
	// things real districts get named after.
	static var MODIFIERS = [
		"Silver", "Golden", "Iron", "Copper", "Salt", "Glass", "Amber", "Pearl",
		"Marble", "Slate", "Flint", "Clay", "Chalk", "Ember", "Cinder",
		"Rose", "Elm", "Oak", "Ash", "Thorn", "Ivy", "Nettle", "Bramble", "Willow",
		"Crow", "Raven", "Magpie", "Sparrow", "Wren", "Heron", "Otter", "Hart",
		"Boar", "Ox", "Hound",
		"Blue", "Grey", "Black", "White", "Red", "Green", "Amber",
		"Old", "New", "High", "Low", "Deep", "Long", "Broad", "Narrow",
		"Bright", "Dark", "Quiet", "Hollow", "Crooked", "Blessed",
		"Frost", "Twilight", "Morning", "Winter", "Harvest",
		"Spice", "Milk", "Honey", "Barley", "Rye", "Tallow", "Pitch",
		"Mill", "Kiln", "Tanner", "Weaver", "Cooper", "Fletcher", "Chandler"
	];

	// Heads that suit any district.
	static var HEADS = [
		"Row", "Lane", "Walk", "Reach", "Rise", "Crest", "Hollow", "Green",
		"Court", "Yard", "Cross", "End", "Side", "Bank", "Steps", "Stair",
		"Hook", "Horn", "Bend", "Corner", "Quarter", "Town", "Ward", "Close",
		"Nook", "Mews", "Rookery", "Streets", "Gardens", "Hill", "Rock", "Water"
	];

	// Heads that say what the district is. A market called "Ostrich Market"
	// reads correctly; "Ostrich Rise" does not.
	static var TYPED_HEADS:Map<String, Array<String>> = [
		"Market"			=> ["Market", "Exchange", "Shambles", "Cross", "Stalls"],
		"Slum"				=> ["Slums", "Rookery", "Warren", "Bottoms", "Ditch"],
		"GateWard"			=> ["Gate", "Barbican", "Postern", "Bar"],
		"MilitaryWard"		=> ["Barracks", "Muster", "Arms", "Watch", "Butts"],
		"AdministrationWard"=> ["Court", "Chambers", "Rolls", "Bench", "Seal"],
		"PatriciateWard"	=> ["Heights", "Terrace", "Crescent", "Row", "Prospect"],
		"CraftsmenWard"		=> ["Forge", "Anvil", "Works", "Yards", "Kilns", "Wheel"],
		"MerchantWard"		=> ["Counting House", "Emporium", "Stalls", "Exchange"],
		"Park"				=> ["Green", "Gardens", "Grove", "Orchard", "Meadow"],
		"Cathedral"			=> ["Close", "Sanctuary", "Precinct", "Rest"],
		"Farm"				=> ["Fields", "Furlongs", "Crofts", "Acres"]
	];

	static var DIRECTIONS = ["North", "South", "East", "West", "Upper", "Lower", "Little", "Great"];

	// Settlement-name syllables, kept deliberately plain so a name the caller
	// supplies is always the more distinctive one.
	static var CITY_HEADS = ["ford", "bridge", "hollow", "march", "gate", "stead", "wick",
		"burn", "field", "moor", "hall", "reach", "vale", "haven", "crest", "barrow"];

	/**
		Names one district. `wardType` is the ward's class name; an unknown or
		null type just falls back to the general heads.

		`outer` biases towards a compass prefix, which is how the districts on
		the edge of a real city tend to get named.
	**/
	public static function district( wardType:String, outer:Bool = false ):String {
		var typed = wardType != null ? TYPED_HEADS.get( wardType ) : null;

		// A typed head most of the time, so a district usually announces itself.
		var head = (typed != null && Random.bool( 0.6 )) ? typed.random() : HEADS.random();

		if (outer && Random.bool( 0.35 ))
			return DIRECTIONS.random() + " " + head;

		var modifier = MODIFIERS.random();

		// Occasionally run the two together — "Carpentershorn", "Ghostlight".
		if (Random.bool( 0.12 ) && head.indexOf( " " ) == -1)
			return modifier + head.toLowerCase();

		if (Random.bool( 0.15 ))
			return modifier + " " + head + " District";

		return modifier + " " + head;
	}

	public static function settlement():String {
		var modifier = MODIFIERS.random();
		return Random.bool( 0.5 ) ?
			modifier + CITY_HEADS.random() :
			modifier + " " + capitalise( CITY_HEADS.random() );
	}

	static function capitalise( s:String ):String
		return s.charAt( 0 ).toUpperCase() + s.substr( 1 );
}
