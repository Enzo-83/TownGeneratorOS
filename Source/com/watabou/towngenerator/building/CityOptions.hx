package com.watabou.towngenerator.building;

import com.watabou.towngenerator.wards.*;

/**
	Where a deliberately placed ward is allowed to land.
**/
enum PlacementZone {
	// Inside the inner ring.
	Core;
	// Between the two walls: inside the curtain wall, outside the inner ring.
	// With no curtain wall, simply outside the inner ring.
	BetweenWalls;
	// Anywhere inside the city.
	WithinCity;
	// Sharing an edge with the central plaza.
	NextToPlaza;
	// The middle of the map: the plaza's own patch when there is one, and
	// otherwise the patch nearest the centre.
	Centre;
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
	// Must share an edge with whatever was placed immediately before.
	var beside : Bool;
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
	// A square with the middle cut out: rooms around an open court, which is
	// what a riad is and how a plan draws one.
	Court;
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
	// Must share an edge with whatever was placed immediately before.
	var beside : Bool;
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

		An entry may lead with a ward type, a zone, or **both** — in either
		order — saying where the landmark belongs. Two tokens are an `and`:
		`cathedral:core:X` is a cathedral inside the inner ring. Without any
		token it is scattered, exactly as before this existed.
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
			var read = readTokens( entry, Dot );
			if (read.name == "")
				continue;

			result.push( { name: read.name, ward: read.ward, zone: read.zone, marker: read.marker, beside: read.beside } );
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
		Eats the leading tokens off an entry and hands back what they said.

		A token is a **ward type**, a **zone** or a **marker**, recognised by
		which vocabulary it belongs to rather than by its position — so
		`park:between:dot:The Orchard` and `dot:between:park:The Orchard` are
		the same thing, and everything after the last one it recognises is the
		name. A name may therefore still contain colons.

		⚠️ **This replaced a single-character prefix** (`*` a dot, `^` a tower).
		One character stopped being readable at the third marker: a riad is a
		real shape with a real name, and `court:` says so where `~` would not.
		The cost is that a place cannot be *called* "core" or "tower" on its
		own — which no place is, since a bare token has to be followed by a
		colon and something else to count at all.
	**/
	static function readTokens( entry:String, marker:MarkerKind ):{ ward:Class<Ward>, zone:PlacementZone, marker:MarkerKind, beside:Bool, name:String } {
		var text = StringTools.trim( entry );

		var ward:Class<Ward> = null;
		var zone:PlacementZone = null;
		var beside = false;

		while (true) {
			var colon = text.indexOf( ":" );
			if (colon <= 0)
				break;

			var token = StringTools.trim( text.substr( 0, colon ) ).toLowerCase();
			var rest = StringTools.trim( text.substr( colon + 1 ) );
			if (rest == "")
				break;

			var asWard = WARD_TYPES.get( token );
			var asZone = ZONES.get( token );
			var asMark = MARKERS.get( token );

			if (token == BESIDE)
				beside = true
			else if (asWard != null && ward == null)
				ward = asWard
			else if (asZone != null && zone == null)
				zone = asZone
			else if (asMark != null)
				marker = asMark
			else
				break;

			text = rest;
		}

		return { ward: ward, zone: zone, marker: marker, beside: beside, name: text };
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
		"plaza"		=> NextToPlaza,
		"centre"	=> Centre,
		"center"	=> Centre
	];

	/**
		`next` is a modifier, not a zone.

		⚠️ It was a zone first, and that was wrong: a zone is one slot, so
		`core:next:` could not be both and the parser stopped at the second
		token and swallowed the rest into the name. "Beside the last thing" is
		a *further* condition on a placement, not an alternative to saying
		where it is — `core:next:` has to mean **in the core and beside it**.
	**/
	public static inline var BESIDE = "next";

	public static var MARKERS:Map<String, MarkerKind> = [
		"none"	=> NoMarker,
		"dot"	=> Dot,
		"tower"	=> Tower,
		"court"	=> Court
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
			// A district with no ward type is nothing to place, so an unknown
			// first token costs you that district rather than the whole map.
			var read = readTokens( entry, NoMarker );
			if (read.ward == null)
				continue;

			result.push( {
				ward:	read.ward,
				zone:	read.zone != null ? read.zone : WithinCity,
				name:	read.name != "" ? read.name : null,
				marker:	read.marker,
				beside:	read.beside
			} );
		}

		return result;
	}
}
