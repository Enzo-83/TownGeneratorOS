package com.watabou.towngenerator.mapping;

import openfl.geom.Point;
import openfl.geom.Rectangle;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.building.River;

import com.watabou.towngenerator.mapping.LabelView.Placement;

/**
	A label that has found somewhere to go: a `Placement` with the words.
**/
typedef PlannedLabel = {
	> Placement,
	var text : String;
}

/**
	A landmark's dot, in map units.
**/
typedef Marker = {
	var at	: Point;
	var r	: Float;
}

/**
	Where the scale bar goes. The bar itself is lines, not text, so each
	renderer draws it — but both take its dimensions from here, and its
	caption is planned as a label like any other.
**/
typedef ScaleBar = {
	var metres	: Int;
	var length	: Float;
	var x		: Float;
	var y		: Float;
	var tick	: Float;
}

/**
	Every label on one map, and where each one goes.

	`LabelView.fit` sizes a label against its own patch and knows nothing about
	its neighbours, so two names in small adjacent patches used to overprint
	each other. This keeps the boxes already spoken for and tests each new
	label against them, dropping or shrinking on overlap. The released
	generator solved this properly in 0.11.1 with straight-skeleton placement;
	this is most of the benefit for a fraction of the work.

	> ⚠️ The order labels are placed in **is** the priority order, since
	> whatever is placed first cannot be pushed aside. It runs title, scale
	> caption, landmarks, hand-named districts, generated names — most
	> deliberate first, and only the last group may be dropped.

	This exists as a plan rather than as a pass inside each renderer because
	there are two of them. `CityMap` draws to the screen and `MapExporter`
	writes SVG, and collision rejection depends on placement order, so two
	parallel loops would drift into disagreeing about which labels a map even
	has. Both consume this instead.
**/
class LabelPlan {

	// Label sizes, as a share of cityRadius. Everything on the map is a share
	// of it, because the view and the export both scale to fit the city — so
	// a share is what renders at a constant size, and a constant in city
	// units is what does not.
	static inline var TITLE		= 0.14;
	static inline var SUBTITLE	= 0.038;
	static inline var CAPTION	= 0.045;
	static inline var LANDMARK	= 0.030;

	// The smallest label worth printing, and the floor under every label
	// `reserve` places. Matches the 3.6 city units this was tuned at on a
	// size-24 city, where cityRadius is about 112.
	static inline var LEGIBLE	= 0.032;

	// A landmark's dot, and the gap between it and the name below it.
	static inline var MARKER	= 0.011;
	static inline var GAP		= 0.010;

	public var labels	: Array<PlannedLabel>;
	public var markers	: Array<Marker>;

	// District names left with nowhere legible to go. Generated names only —
	// a name the caller wrote by hand is never dropped. Same purpose as
	// `Model.placementWarnings`: it tells you the map is missing something
	// rather than leaving you to notice.
	public var dropped	: Array<String>;

	var taken	: Array<Rectangle>;
	var floor	: Float;

	function new() {
		labels	= [];
		markers	= [];
		dropped	= [];
		taken	= [];
	}

	public static function build( model:Model ):LabelPlan {
		var plan = new LabelPlan();
		var r = model.cityRadius;

		plan.floor = r * LEGIBLE;

		if (model.cityName != null) {
			plan.reserve( model.cityName, new Point( 0, -r * 1.16 ), 0, r * TITLE );
			plan.reserve(
				'~${CityMap.thousands( model.population )} people · ${CityMap.thousands( model.buildingCount )} buildings',
				new Point( 0, -r * 1.05 ), 0, r * SUBTITLE );
		}

		var bar = scaleBar( model );
		plan.reserve( bar.metres + " m",
			new Point( bar.x + bar.length / 2, bar.y + bar.tick * 3.4 ), 0, r * CAPTION );

		// The water is spoken for before any label is. A district whose patch
		// the river runs through still has a name, and printing it mid-current
		// is the one placement that reads as a mistake rather than a squeeze.
		if (model.river != null)
			plan.reserveWater( model.river );

		// Landmarks next, because a landmark cannot be dropped: it is a place
		// the caller asked for by name, and the dot is drawn whether the name
		// fits or not. District labels are what gives way.
		for (patch in model.patches) {
			if (!patch.withinCity || patch.ward == null || patch.landmark == null)
				continue;

			var centre = patch.shape.center;
			plan.markers.push( { at: centre, r: r * MARKER } );

			var size = Math.max( r * LANDMARK, plan.floor );

			// Measured out from the dot rather than set as a share of the
			// radius: the size has a floor under it, so on a small town a
			// fixed share put the name straight through its own marker.
			var clearance = r * (MARKER + GAP) + size * LabelView.BOX_HEIGHT / 2;

			// Below the dot by default, above it when below is already taken —
			// which is what two landmarks in neighbouring patches produce.
			var below = new Point( centre.x, centre.y + clearance );
			var at = plan.free( patch.landmark, below, size ) ?
				below :
				new Point( centre.x, centre.y - clearance );

			plan.reserve( patch.landmark, at, 0, size );
		}

		// Hand-named districts before generated ones, and insistently: a name
		// the caller typed is the one label that must not silently disappear.
		for (byCaller in [true, false])
			for (patch in model.patches) {
				if (!patch.withinCity || patch.ward == null ||
					patch.landmark != null || patch.ward.name == null ||
					patch.nameFromCaller != byCaller)
					continue;

				var name = patch.ward.name;
				var placement = byCaller ?
					LabelView.fitInsistent( name, patch.shape, plan.floor, plan.taken ) :
					LabelView.fit( name, patch.shape, plan.floor, plan.taken );

				if (placement == null)
					plan.dropped.push( name );
				else
					plan.reserve( name, placement.at, placement.angle, placement.size );
			}

		return plan;
	}

	/**
		A bar of a round number of metres. In map units, so it stays truthful
		at whatever zoom the scene applies.
	**/
	public static function scaleBar( model:Model ):ScaleBar {
		var half = model.cityRadius * Model.METRES_PER_UNIT * 0.6;

		var metres = 50;
		for (candidate in [50, 100, 250, 500, 1000, 2000, 5000])
			if (candidate <= half)
				metres = candidate;

		return {
			metres:	metres,
			length:	metres / Model.METRES_PER_UNIT,
			x:		-model.cityRadius,
			y:		model.cityRadius * 1.1,
			tick:	model.cityRadius * 0.02
		};
	}

	/**
		The river's course as a chain of boxes, taken but unlabelled.

		Per segment rather than one box for the whole course: the course is
		smoothed into many short segments, so a box round each is close to the
		water's actual shape, where one round the lot would reserve half the
		map.
	**/
	function reserveWater( river:River ):Void {
		var half = river.width / 2;

		for (i in 0...river.course.length - 1) {
			var a = river.course[i];
			var b = river.course[i + 1];

			var left	= Math.min( a.x, b.x ) - half;
			var top		= Math.min( a.y, b.y ) - half;
			var right	= Math.max( a.x, b.x ) + half;
			var bottom	= Math.max( a.y, b.y ) + half;

			taken.push( new Rectangle( left, top, right - left, bottom - top ) );
		}
	}

	function free( text:String, at:Point, size:Float ):Bool
		return LabelView.clear( text, { at: at, angle: 0.0, size: size }, taken );

	function reserve( text:String, at:Point, angle:Float, size:Float ):Void {
		var legible = Math.max( size, floor );
		labels.push( { text: text, at: at, angle: angle, size: legible } );
		taken.push( LabelView.box( text, at, angle, legible ) );
	}
}
