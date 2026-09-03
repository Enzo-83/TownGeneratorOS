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
**/
typedef WardPlacement = {
	var ward : Class<Ward>;
	var zone : PlacementZone;
}

/**
	Generation settings. Every field that can be `null` means
	"roll for it", which is what the generator did before this existed —
	so an untouched CityOptions reproduces upstream behaviour exactly.
**/
class CityOptions {

	public var size	: Int = 15;
	public var seed	: Int = -1;

	public var plaza	: Null<Bool> = null;
	public var citadel	: Null<Bool> = null;
	public var walls	: Null<Bool> = null;

	// The second ring. A boundary rather than a defence: it gets no
	// towers, its gates are drawn as openings, and it never splits a patch.
	public var innerWall	: Bool = false;
	// How many patches the inner ring encloses.
	public var coreSize		: Int = 5;

	public var placements	: Array<WardPlacement> = [];

	public function new() {}

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
		"farm"				=> Farm,
		"common"			=> CommonWard
	];

	public static var ZONES:Map<String, PlacementZone> = [
		"core"		=> Core,
		"between"	=> BetweenWalls,
		"city"		=> WithinCity,
		"plaza"		=> NextToPlaza
	];

	/**
		Parses a placement list of the form

			craftsmen:core,market:plaza,park:between

		Unknown ward or zone names are skipped rather than thrown, so one
		typo in a URL costs you a district instead of the whole map.
		A missing zone defaults to `city`.
	**/
	public static function parsePlacements( spec:String ):Array<WardPlacement> {
		var result:Array<WardPlacement> = [];
		if (spec == null || StringTools.trim( spec ) == "")
			return result;

		for (entry in spec.split( "," )) {
			var parts = StringTools.trim( entry ).toLowerCase().split( ":" );
			if (parts[0] == "")
				continue;

			var ward = WARD_TYPES.get( parts[0] );
			if (ward == null)
				continue;

			var zone = parts.length > 1 ? ZONES.get( parts[1] ) : WithinCity;
			if (zone == null)
				zone = WithinCity;

			result.push( { ward: ward, zone: zone } );
		}

		return result;
	}
}
