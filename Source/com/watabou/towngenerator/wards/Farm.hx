package com.watabou.towngenerator.wards;

import openfl.geom.Point;

import com.watabou.geom.GeomUtils;
import com.watabou.geom.Polygon;
import com.watabou.utils.Random;
import com.watabou.utils.Rng;

import com.watabou.towngenerator.building.Cutter;

using com.watabou.utils.ArrayExtender;

/**
	A farm: a farmhouse, and the fields it works.

	Upstream drew only the farmhouse — a four-unit square somewhere in a patch
	that could be a hundred units across — so a farm was an unexplained speck
	in an empty space, and the only way to find out it was a farm at all was to
	hover over it. The fields are what make it read as one.
**/
class Farm extends Ward {

	// Kept out of `geometry`, which is buildings — and buildings are what the
	// population is counted from. A farm placed inside the city with
	// `districts=farm:…` would otherwise report every field as a house.
	public var fields	: Array<Polygon>;

	// A parcel this size or smaller is not divided again. In map units, so at
	// four metres to the unit a field is somewhere around half a hectare to a
	// hectare — small, which is what open-field farming looks like.
	static inline var MIN_FIELD = 260.0;

	// Cheap insurance against the recursion that already bites `createAlleys`:
	// a patch is at most this many bisections deep however large it is.
	static inline var MAX_DEPTH = 5;

	// A margin around the patch, so two neighbouring farms have a boundary
	// between them rather than one shared line.
	static inline var HEDGE = 1.0;

	override public function createGeometry() {
		// ⛔ Unchanged, and it must stay that way. These three draws come out
		// of the one static `Random` that every patch, street and building is
		// built from, so adding to them — or reordering them — moves every
		// building in every city generated afterwards. The fields below are
		// deliberately not part of this.
		var housing = Polygon.rect( 4, 4 );
		var pos = GeomUtils.interpolate( patch.shape.random(), patch.shape.centroid, 0.3 + Random.float() * 0.4 );
		housing.rotate( Random.float() * Math.PI );
		housing.offset( pos );

		geometry = Ward.createOrthoBuilding( housing, 8, 0.5 );

		fields = divide();
	}

	/**
		The patch, cut up into parcels.

		⛔ **Draws from an `Rng` of its own, never from `Random`.** Fields are
		being added to a generator whose every seed is already spoken for; one
		draw from the shared sequence here would move every building in every
		city that has a farm in it. Same reasoning as `River`, and the same
		remedy — except that this does not even need a seed passed in, because
		the patch's own position is already a stable, per-farm number.
	**/
	function divide():Array<Polygon> {
		var centre = patch.shape.centroid;
		var rng = new Rng( Std.int( Math.abs( centre.x * 977 + centre.y * 331 ) ) + 1 );

		var enclosure = patch.shape.shrinkEq( HEDGE );
		if (enclosure == null || enclosure.length < 3)
			return [];

		return parcel( enclosure, rng, 0 );
	}

	/**
		Halves a parcel across its longest edge until the pieces are small
		enough, which follows the shape of the patch and so gives the wonky
		quadrilaterals fields actually come in — rather than the pie slices a
		radial cut from the centre would.
	**/
	static function parcel( poly:Polygon, rng:Rng, depth:Int ):Array<Polygon> {
		if (depth >= MAX_DEPTH || poly.square <= MIN_FIELD)
			return [poly];

		// Off centre and off square, or every field is the same field.
		var ratio = 0.5 + (rng.float() - 0.5) * 0.4;
		var angle = (rng.float() - 0.5) * 0.5;

		var halves = Cutter.bisect( poly, longestEdge( poly ), ratio, angle, 0 );
		if (halves.length < 2)
			return [poly];

		var result:Array<Polygon> = [];
		for (half in halves)
			result = result.concat( parcel( half, rng, depth + 1 ) );

		return result;
	}

	static function longestEdge( poly:Polygon ):Point
		return poly.min( function( v:Point ) return -poly.vector( v ).length );

	override public inline function getLabel() return "Farm";
}
