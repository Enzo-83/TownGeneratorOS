package com.watabou.towngenerator.building;

import openfl.geom.Point;

import com.watabou.geom.Graph;
import com.watabou.geom.GeomUtils;
import com.watabou.geom.Polygon;
import com.watabou.utils.Rng;

using com.watabou.utils.ArrayExtender;
using com.watabou.utils.PointExtender;

/**
	Where a road crosses the water.
**/
typedef Bridge = {
	var at	: Point;
	// Along the road, so the bridge can be drawn across the current.
	var dir	: Point;
}

/**
	A river through the city.

	> ⛔ **A river must not change the city it runs through.**
	>
	> Everything the generator makes — the patches, the walls, the streets, the
	> wards, every building — comes out of one static `Random` in order. A
	> single draw from it here would shift all of them, and every seed already
	> chosen would produce a different city, including the landlocked ones that
	> will never have a river. So this draws from an `Rng` of its own, seeded
	> from the city's seed, and it runs **after** `buildGeometry` on a layout
	> that is already finished. Turning the river on and off leaves the same
	> city underneath it either way.
	>
	> The cost of that is that the wards do not know about the water: nobody
	> sites a district with reference to a river that does not exist yet. What
	> happens instead is that the buildings the river covers are taken away
	> afterwards — which is most of the visible effect, and the population
	> falls with them, because it is counted from the buildings that remain.

	The course follows patch boundaries, for the same reason the inner ring
	does: an edge is a line the generator has already agreed nothing is built
	on, so a river along one runs between the buildings rather than through
	them. It is then smoothed, which does move it off the edges — which is why
	the buildings are cleared by distance from the smoothed course rather than
	by which patch they belong to.
**/
class River {

	// A base, so a small town's river is not a ditch, plus a share of the
	// radius, so a metropolis's is not a stream. Rivers do not really scale
	// with cities, but a map of one has to stay readable at any size.
	static inline var BASE	= 3.0;
	static inline var SHARE	= 0.02;

	// What it costs the course to follow an edge a street already uses, or an
	// edge of the plaza. Both are legal, and both look wrong: a river down the
	// middle of the high street, a market square under water. Weighting rather
	// than forbidding, so an impossible layout still gets a river.
	static inline var STREET_TOLL	= 6.0;
	static inline var PLAZA_TOLL	= 20.0;

	// How far past the water's edge the bank is cleared.
	static inline var MARGIN = 0.5;

	// The centreline, smoothed.
	public var course	: Polygon;
	// The water itself, as one closed shape.
	public var banks	: Polygon;
	public var width	: Float;

	public var bridges	: Array<Bridge>;

	var model	: Model;
	var rng		: Rng;

	var graph	: Graph;
	var nodes	: Map<Point, Node>;
	var points	: Map<Node, Point>;

	/**
		Returns null when no course could be found, rather than throwing — the
		model's retry loop would otherwise rebuild the whole city looking for
		one, and a city with no river is a perfectly good city.
	**/
	public static function build( model:Model, seed:Int ):River {
		var river = new River( model, seed );
		return river.course == null ? null : river;
	}

	function new( model:Model, seed:Int ) {
		this.model = model;
		this.rng = new Rng( seed );

		width = BASE + model.cityRadius * SHARE;

		var found = findCourse();
		if (found == null)
			return;

		course = smooth( found );
		banks = bank( course );
		bridges = findBridges();

		clearBuildings();
	}

	// ------------------------------------------------------------- the course

	/**
		Two legs of a shortest path over the patch boundaries: from one side of
		the map to a point near the middle, and on to the other side.

		The middle leg is the point of it. A single crossing takes whichever
		way is shortest, which is usually a clip across one corner of the map
		that never comes near the town — and a river the city does not sit on
		is not worth drawing.
	**/
	function findCourse():Array<Point> {
		var angle = rng.float() * 2 * Math.PI;
		var dir = new Point( Math.cos( angle ), Math.sin( angle ) );

		buildGraph();

		// Off the edge of the map in both directions, and through the town
		// between them — offset a little to one side, so the water does not
		// run exactly over the centre every time.
		var side = dir.rotate90().scale( model.cityRadius * (rng.float() - 0.5) * 0.6 );

		var from	= furthest( dir.scale( -1 ) );
		var through	= nearest( side );
		var to		= furthest( dir );

		var first = path( from, through );
		var second = path( through, to );
		if (first == null || second == null)
			return null;

		// The junction is in both legs; drop one copy.
		return first.concat( second.slice( 1 ) );
	}

	/**
		Every patch boundary, as a graph. Nothing is blocked — a river crosses
		a city wall, which is what a water gate is for.
	**/
	function buildGraph():Void {
		graph = new Graph();
		nodes = new Map();
		points = new Map();

		function node( v:Point ):Node {
			var n = nodes.get( v );
			if (n == null) {
				nodes.set( v, n = graph.add() );
				points.set( n, v );
			}
			return n;
		}

		for (patch in model.patches) {
			var v1 = patch.shape.last();
			for (v2 in patch.shape) {
				var v0 = v1; v1 = v2;

				var toll = 1.0;
				if (model.plaza != null && model.plaza.shape.findEdge( v0, v1 ) != -1)
					toll = PLAZA_TOLL;
				else if (onArtery( v0, v1 ))
					toll = STREET_TOLL;

				node( v0 ).link( node( v1 ), Point.distance( v0, v1 ) * toll );
			}
		}
	}

	function onArtery( v0:Point, v1:Point ):Bool {
		for (artery in model.arteries)
			if (artery.contains( v0 ) && artery.contains( v1 ))
				return true;
		return false;
	}

	function path( from:Point, to:Point ):Array<Point> {
		if (from == to)
			return [from];

		var found = graph.aStar( nodes.get( from ), nodes.get( to ) );
		if (found == null)
			return null;

		// aStar walks back from the goal, so the path arrives reversed.
		var route = [for (n in found) points.get( n )];
		route.reverse();
		return route;
	}

	// The patch vertex furthest along a direction, which is on the edge of the
	// map rather than of the city — a river runs off the paper.
	function furthest( dir:Point ):Point {
		var best:Point = null;
		var score = Math.NEGATIVE_INFINITY;
		for (patch in model.patches)
			for (v in patch.shape) {
				var d = v.dot( dir );
				if (d > score) {
					score = d;
					best = v;
				}
			}
		return best;
	}

	function nearest( at:Point ):Point {
		var best:Point = null;
		var score = Math.POSITIVE_INFINITY;
		for (patch in model.patches)
			for (v in patch.shape) {
				var d = Point.distance( v, at );
				if (d < score) {
					score = d;
					best = v;
				}
			}
		return best;
	}

	/**
		Rounds the corners off. The endpoints stay put, exactly as
		`Model.buildStreets` keeps a street's ends on their gates.

		⚠️ **The short segments go first.** A patch boundary can turn through
		most of a right angle between two vertices a couple of units apart, and
		offsetting a corner that sharp folds the far bank back over itself —
		which draws as a notch out of the river. Dropping the vertices closer
		together than the water is wide removes the corners that do it, and the
		smoothing passes soften what is left.
	**/
	function smooth( raw:Array<Point> ):Polygon {
		var trimmed:Polygon = raw.length > 3 ?
			new Polygon( raw ).filterShort( width ) : raw;

		var result:Polygon = [for (v in trimmed) v.clone()];

		for (pass in 0...3) {
			var smoothed = result.smoothVertexEq( 2 );
			for (i in 1...result.length - 1)
				result[i].set( smoothed[i] );
		}

		return result;
	}

	// -------------------------------------------------------------- the water

	/**
		The course given width: one side of it out and the other side back.
	**/
	function bank( line:Polygon ):Polygon {
		var half = width / 2;

		var left:Array<Point> = [];
		var right:Array<Point> = [];

		for (i in 0...line.length) {
			var normal = normalAt( line, i ).norm( half );
			left.push( line[i].add( normal ) );
			right.push( line[i].subtract( normal ) );
		}

		right.reverse();
		return left.concat( right );
	}

	// Perpendicular to the course, averaged across the corner so the width
	// stays even through a bend.
	function normalAt( line:Polygon, i:Int ):Point {
		var before	= line[i > 0 ? i - 1 : 0];
		var after	= line[i < line.length - 1 ? i + 1 : line.length - 1];

		var along = after.subtract( before );
		return along.length == 0 ? new Point( 0, 1 ) : along.rotate90().norm( 1 );
	}

	// ------------------------------------------------------------- the bridges

	/**
		Where a road meets the water. Crossings are transversal because the
		course pays a toll to follow a street rather than cross one, so a
		bridge is a short bar across the current rather than a road that runs
		along it.
	**/
	function findBridges():Array<Bridge> {
		var result:Array<Bridge> = [];

		for (road in model.arteries)
			for (i in 0...road.length - 1) {
				var a0 = road[i];
				var a1 = road[i + 1];

				for (j in 0...course.length - 1) {
					var at = crossing( a0, a1, course[j], course[j + 1] );
					if (at == null)
						continue;

					var dir = a1.subtract( a0 );
					if (dir.length > 0)
						add( result, { at: at, dir: dir.norm( 1 ) } );
					break;
				}
			}

		if (!result.some( function( b:Bridge ) return b.at.length < model.cityRadius ))
			forceCrossing( result );

		return result;
	}

	// One bridge per crossing. A road turns a corner mid-river often enough
	// that two of its segments both cross, and two bridges a few units apart
	// draw as one lumpy one.
	function add( found:Array<Bridge>, bridge:Bridge ):Void {
		for (b in found)
			if (Point.distance( b.at, bridge.at ) < width * 2)
				return;
		found.push( bridge );
	}

	/**
		A crossing where the water passes closest to the middle of the city.

		⚠️ **Without this a town can be cut in half and left that way.** The
		street network is built before the river exists and knows nothing about
		it, so whether any street happens to cross the water is luck — and on a
		small town, where there are only two or three streets, the luck is
		usually bad. A settlement that straddles a river has a crossing; that
		is most of why it is a settlement.
	**/
	function forceCrossing( found:Array<Bridge> ):Void {
		var at:Point = null;
		var dir:Point = null;
		var best = Math.POSITIVE_INFINITY;

		for (i in 0...course.length - 1) {
			var mid = GeomUtils.interpolate( course[i], course[i + 1], 0.5 );
			if (mid.length >= best)
				continue;

			var along = course[i + 1].subtract( course[i] );
			if (along.length == 0)
				continue;

			best = mid.length;
			at = mid;
			dir = along.rotate90().norm( 1 );
		}

		// Only if the water actually runs through the place.
		if (at != null && best < model.cityRadius)
			found.push( { at: at, dir: dir } );
	}

	// Where two segments cross, or null. Not GeomUtils.intersectLines, which
	// answers for the infinite lines and would put bridges wherever a road and
	// the river happen to be pointing at each other.
	static function crossing( a0:Point, a1:Point, b0:Point, b1:Point ):Point {
		var d1 = a1.subtract( a0 );
		var d2 = b1.subtract( b0 );

		var denom = d1.x * d2.y - d1.y * d2.x;
		if (denom == 0)
			return null;

		var dx = b0.x - a0.x;
		var dy = b0.y - a0.y;

		var t = (dx * d2.y - dy * d2.x) / denom;
		var u = (dx * d1.y - dy * d1.x) / denom;

		if (t < 0 || t > 1 || u < 0 || u > 1)
			return null;

		return new Point( a0.x + d1.x * t, a0.y + d1.y * t );
	}

	// ------------------------------------------------------------- the clearing

	/**
		Takes away the buildings the water covers, and the population with
		them: `Model.buildingCount` is what the figure is calculated from, so
		it is recounted rather than adjusted.
	**/
	function clearBuildings():Void {
		var reach = width / 2 + MARGIN;

		for (patch in model.patches) {
			var ward = patch.ward;
			if (ward == null || ward.geometry == null)
				continue;

			// Any corner in the water, not the middle of the building: a block
			// clipped by the bank is still a block standing in the river.
			ward.geometry = ward.geometry.filter(
				function( block:Polygon ) return !touchesWater( block, reach ) );
		}

		model.recountBuildings();
	}

	function touchesWater( block:Polygon, reach:Float ):Bool {
		for (v in block)
			if (distanceTo( v ) <= reach)
				return true;
		return false;
	}

	/**
		How far a point is from the course. Squared distance to each segment,
		which is the honest measure — nearest *vertex* would leave buildings
		standing in the middle of a long straight reach.
	**/
	public function distanceTo( p:Point ):Float {
		var best = Math.POSITIVE_INFINITY;
		for (i in 0...course.length - 1) {
			var d = distanceToSegment( p, course[i], course[i + 1] );
			if (d < best)
				best = d;
		}
		return best;
	}

	static function distanceToSegment( p:Point, a:Point, b:Point ):Float {
		var dx = b.x - a.x;
		var dy = b.y - a.y;
		var len2 = dx * dx + dy * dy;

		var t = len2 == 0 ? 0.0 : ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
		t = t < 0 ? 0 : (t > 1 ? 1 : t);

		var qx = a.x + dx * t;
		var qy = a.y + dy * t;

		return Math.sqrt( (p.x - qx) * (p.x - qx) + (p.y - qy) * (p.y - qy) );
	}
}
