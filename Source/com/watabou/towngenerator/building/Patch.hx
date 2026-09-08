package com.watabou.towngenerator.building;

import openfl.geom.Point;

import com.watabou.geom.Polygon;
import com.watabou.geom.Voronoi.Region;

import com.watabou.towngenerator.building.CityOptions.MarkerKind;
import com.watabou.towngenerator.wards.Ward;

class Patch {

	public var shape	: Polygon;
	public var ward 	: Ward;

	public var withinWalls	: Bool;
	public var withinCity	: Bool;
	// Inside the inner ring, when the city has one.
	public var withinInnerWall	: Bool;
	// A named point of interest sited here, if any.
	public var landmark		: String;
	// True when the caller named this district in `districts=` rather than
	// leaving it to `Toponymy`. Such a name is never overwritten by a landmark
	// and its label is never dropped for want of room.
	public var nameFromCaller	: Bool;
	// What symbol marks this patch, if any. A landmark always has one; a
	// district only when the caller asked for it, which is what lets a temple
	// be an area and a point at once.
	public var marker			: MarkerKind;

	public inline function new( vertices:Array<Point> ) {
		this.shape = new Polygon( vertices );

		withinCity		= false;
		withinWalls		= false;
		withinInnerWall	= false;
		nameFromCaller	= false;
		marker			= NoMarker;
	}

	public static function fromRegion( r:Region ):Patch
		return new Patch( [for (tr in r.vertices) tr.c] );
}

