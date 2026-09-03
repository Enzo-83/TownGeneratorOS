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

	public var placements	: Array<WardPlacement> = [];

	// Named points of interest, distributed over the city's districts.
	public var landmarks	: Array<String> = [];

	public function new() {}

	/**
		Splits a comma-separated landmark list. Names may contain spaces;
		they may not contain commas.
	**/
	public static function parseLandmarks( spec:String ):Array<String> {
		var result:Array<String> = [];
		if (spec == null)
			return result;

		for (entry in spec.split( "," )) {
			var name = StringTools.trim( entry );
			if (name != "")
				result.push( name );
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

			result.push( { ward: ward, zone: zone, name: name != "" ? name : null } );
		}

		return result;
	}
}
