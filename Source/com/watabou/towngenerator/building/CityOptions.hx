package com.watabou.towngenerator.building;

import com.watabou.towngenerator.wards.*;

/**
	Where a deliberately placed ward is allowed to land.
**/
enum PlacementZone {
	// Inside the inner ring.
	Core;
	// Within the city, but outside the inner ring.
	BetweenWalls;
	// Anywhere inside the city.
	WithinCity;
	// Sharing an edge with the central plaza.
	NextToPlaza;
}

/**
	A ward the caller wants put somewhere on purpose, rather than
	left to the weighted shuffle in `Model.WARDS`.

	`name` is the district's label. Left null, `Toponymy` invents one —
	which is what every unplaced ward gets.
**/
typedef WardPlacement = {
	var ward : Class<Ward>;
	var zone : PlacementZone;
	var name : Null<String>;
	// `NoMarker` unless the name was prefixed. A district is an area, so it
	// is unmarked by default.
	var marker : MarkerKind;
}

/**
	What symbol, if any, marks a place on the map.

	A district is an area and a landmark is a point, and most places are one or
	the other — but not all. A temple that is an orchard is an area you can
	also stand in front of, and it wants both: the ward's own drawing, and a
	point to aim at.
**/
enum MarkerKind {
	NoMarker;
	// A filled dot. What every landmark had before there was a choice.
	Dot;
	// A ring — a round tower's footprint, which is how a plan draws one.
	Tower;
}

/**
	How much of the map is written on.

	The generated district names are the generator's own invention — colour for
	a GM's copy. The ones the caller typed, and the landmarks, are the places
	the world actually has. Splitting on that line is what makes a player's
	copy possible, and it costs nothing, because `Patch.nameFromCaller` already
	knows which is which.
**/
enum LabelMode {
	// Everything: generated district names, named ones, landmarks.
	AllLabels;
	// Only what the caller named, plus landmarks. A player's copy.
	NamedOnly;
	// The settlement's name and the scale bar, nothing else.
	NoLabels;
}

/**
	A point of interest, and where the caller wants it.

	`ward` and `zone` are alternatives, not a pair: a landmark says either what
	kind of district it belongs in or which part of the city. Left both null it
	is scattered, which is what every landmark did before placements existed.
**/
typedef Landmark = {
	var name : String;
	var ward : Null<Class<Ward>>;
	var zone : Null<PlacementZone>;
	// `Dot` unless the name was prefixed. A landmark is a point, so it is
	// always marked by something.
	var marker : MarkerKind;
}

/**
	Generation settings. Every field that can be `null` means
	"roll for it", which is what the generator did before this existed —
	so an untouched CityOptions reproduces upstream behaviour exactly.
**/
class CityOptions {

	public var size	: Int = 15;
	public var seed	: Int = -1;
	// Left null, the generator invents one.
	public var name	: String = null;

	public var plaza	: Null<Bool> = null;
	public var citadel	: Null<Bool> = null;
	public var walls	: Null<Bool> = null;

	// The second ring. A boundary rather than a defence: it gets no
	// towers, its gates are drawn as openings, and it never splits a patch.
	public var innerWall	: Bool = false;
	// How many patches the inner ring encloses.
	public var coreSize		: Int = 5;

	// How much of the map is labelled. Purely presentational: it is read when
	// the map is drawn, never while it is generated, so it cannot move a
	// single building.
	public var labels		: LabelMode = AllLabels;

	// A river across the map. Off unless asked for, and deliberately not
	// rolled: a roll would have to come out of the city's own random sequence
	// to be reproducible from the seed, and drawing from that sequence is the
	// one thing a river must not do. See `River`.
	public var river		: Bool = false;

	public var placements	: Array<WardPlacement> = [];

	// Named points of interest, distributed over the city's districts.
	public var landmarks	: Array<Landmark> = [];

	public function new() {}

	/**
		Parses a landmark list of the form

			Temple of the Dawn,cathedral:Shrine of the Deep,core:The Silent Temple

		An entry may lead with a ward type or a zone saying where the landmark
		belongs. Without one it is scattered, exactly as before this existed.
		Names may contain spaces and colons; they may not contain commas, which
		is what separates one entry from the next.

		⚠️ **A leading token is read as a placement only when it names a ward
		or a zone *and* something follows it.** So "Old Market: The Hall" is a
		landmark called exactly that, while "market: The Hall" is a landmark
		called "The Hall" sited in a market. That ambiguity is the price of not
		inventing a second separator, and it only bites a name whose first word
		before a colon happens to be one of eleven ward names or four zones.
	**/
	public static function parseLandmarks( spec:String ):Array<Landmark> {
		var result:Array<Landmark> = [];
		if (spec == null)
			return result;

		for (entry in spec.split( "," )) {
			var text = StringTools.trim( entry );
			if (text == "")
				continue;

			var ward:Class<Ward> = null;
			var zone:PlacementZone = null;

			var colon = text.indexOf( ":" );
			if (colon > 0) {
				var token = StringTools.trim( text.substr( 0, colon ) ).toLowerCase();
				var rest = StringTools.trim( text.substr( colon + 1 ) );

				if (rest != "") {
					ward = WARD_TYPES.get( token );
					zone = ZONES.get( token );

					if (ward != null || zone != null)
						text = rest;
				}
			}

			var marked = readMarker( text, Dot );
			result.push( { name: marked.name, ward: ward, zone: zone, marker: marked.marker } );
		}

		return result;
	}

	// Concrete wards only. CommonWard is deliberately absent: it is the base
	// class, its constructor takes minSq/gridChaos/sizeChaos as well, and
	// building one with just (model, patch) leaves minSq null — which makes
	// Ward.createAlleys recurse until the stack gives out. Castle is absent
	// too; it belongs to the citadel and builds its own wall.
	public static var WARD_TYPES:Map<String, Class<Ward>> = [
		"craftsmen"			=> CraftsmenWard,
		"merchant"			=> MerchantWard,
		"cathedral"			=> Cathedral,
		"administration"	=> AdministrationWard,
		"slum"				=> Slum,
		"patriciate"		=> PatriciateWard,
		"market"			=> Market,
		"military"			=> MilitaryWard,
		"park"				=> Park,
		"gate"				=> GateWard,
		"farm"				=> Farm
	];

	/**
		Reads a symbol prefix off the front of a name.

			*The Reaper's Orchard   — mark it with a dot
			^The Temple of the Awoken Steel — mark it with a tower

		One character rather than another field, because a name is everything
		after the last spec token and may itself contain colons — there is no
		room for a fourth field without taking that away.

		⚠️ A name that genuinely starts with `*` or `^` cannot be written. That
		is the trade, and it is a cheap one: no place in a city is called
		"*Anything".
	**/
	public static function readMarker( name:String, fallback:MarkerKind ):{ name:String, marker:MarkerKind } {
		if (name == null || name.length < 2)
			return { name: name, marker: fallback };

		var mark = switch (name.charAt( 0 )) {
			case "*":	Dot;
			case "^":	Tower;
			default:	null;
		}

		return mark == null ?
			{ name: name, marker: fallback } :
			{ name: StringTools.trim( name.substr( 1 ) ), marker: mark };
	}

	public static var LABEL_MODES:Map<String, LabelMode> = [
		"all"	=> AllLabels,
		"named"	=> NamedOnly,
		"none"	=> NoLabels
	];

	public static var ZONES:Map<String, PlacementZone> = [
		"core"		=> Core,
		"between"	=> BetweenWalls,
		"city"		=> WithinCity,
		"plaza"		=> NextToPlaza
	];

	/**
		Parses a placement list of the form

			craftsmen:core,market:plaza:The Velvet Road,park:between

		Unknown ward or zone names are skipped rather than thrown, so one
		typo in a URL costs you a district instead of the whole map.
		A missing zone defaults to `city`; a missing name is generated.

		Only the ward and zone tokens are case-folded. A name is kept exactly
		as it was written, since that is the entire point of supplying one —
		which is why the whole entry is no longer lowercased before splitting.
		A name may contain spaces and colons; it may not contain a comma,
		which is what separates one placement from the next.
	**/
	public static function parsePlacements( spec:String ):Array<WardPlacement> {
		var result:Array<WardPlacement> = [];
		if (spec == null || StringTools.trim( spec ) == "")
			return result;

		for (entry in spec.split( "," )) {
			var parts = StringTools.trim( entry ).split( ":" );

			var ward = WARD_TYPES.get( StringTools.trim( parts[0] ).toLowerCase() );
			if (ward == null)
				continue;

			var zone = parts.length > 1 ?
				ZONES.get( StringTools.trim( parts[1] ).toLowerCase() ) : WithinCity;
			if (zone == null)
				zone = WithinCity;

			// Everything after the zone is the name, rejoined, so a colon in
			// "St Mark: the Elder" survives the split.
			var name = parts.length > 2 ?
				StringTools.trim( parts.slice( 2 ).join( ":" ) ) : "";

			var marked = readMarker( name != "" ? name : null, NoMarker );
			result.push( { ward: ward, zone: zone, name: marked.name, marker: marked.marker } );
		}

		return result;
	}
}
