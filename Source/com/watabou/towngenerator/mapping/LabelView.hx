package com.watabou.towngenerator.mapping;

import openfl.display.Sprite;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

import com.watabou.geom.Polygon;

/**
	Where one label sits and how big it is. In map units, and centred on the
	glyphs rather than anchored to a baseline, because the screen renderer
	centres a sprite and only the SVG writer needs a baseline.
**/
typedef Placement = {
	var at		: Point;
	var angle	: Float;
	var size	: Float;
}

/**
	District and settlement labels.

	The map is drawn in city units — a whole town is only a few hundred across —
	so a label sized directly in those units would be a 5pt TextField stretched
	up by the scene transform, and it would look it. Text is therefore always
	rasterised at `BASE_SIZE` and the sprite scaled *down* to fit.

	This class sizes and rotates one label. It does not decide which labels a
	map gets or in what order — that is `LabelPlan`, which owns the list of
	boxes already spoken for and hands it back in here as `avoid`.
**/
class LabelView {

	// Big enough that scaling down never softens the glyphs.
	static inline var BASE_SIZE = 64;

	static inline var FONT = "Georgia,Times New Roman,serif";

	// How wide a glyph is relative to its point size, and how much of a
	// patch's depth a label may occupy. Both measured against the render.
	static inline var GLYPH_RATIO = 0.46;
	static inline var DEPTH_SHARE = 0.55;

	// What a collision box measures, as a share of the label's size.
	//
	// ⚠️ **These are deliberately not `GLYPH_RATIO`.** That one is an average,
	// tuned so a label looks right inside its patch, and it *understates* the
	// wide names: measured against Georgia, the mean advance is 0.50 em and
	// "Hound Works" is 0.57, so boxes built from 0.46 let labels overprint
	// each other by a tenth of their width and the rejection quietly failed to
	// reject. A fitting ratio wants the average; a collision box wants the
	// worst case, and BOX_RATIO is the widest name in a real map's label set.
	// BOX_HEIGHT is ascent plus descent, 0.91 em, rounded up.
	static inline var BOX_RATIO = 0.57;
	public static inline var BOX_HEIGHT = 1.0;

	// A margin around every label, as a share of its own size, so neighbours
	// clear each other rather than merely failing to overlap.
	static inline var PAD = 0.12;

	// How far below the centre of the glyphs the baseline sits. The screen
	// renderer centres its sprite; SVG anchors text at the baseline, so it
	// shifts by this and the two then agree.
	public static inline var BASELINE = 0.34;

	// Sizes to fall back through when the largest that fits the patch runs
	// into a label that is already placed.
	static var SHRINK = [1.0, 0.85, 0.7, 0.55];

	// How far the paper-coloured halo reaches beyond the glyphs, as a share
	// of the label's size.
	//
	// The map is drawn almost entirely in one ink — buildings, alleys, roads,
	// walls — so a bare glyph laid over a block of houses has to be picked out
	// of the hatching before it can be read. A halo is what cartography does
	// about that: it clears just enough of the drawing to read the word
	// without hiding what the word is sitting on, which is what a filled box
	// behind the text would do.
	public static inline var HALO = 0.05;

	// The halo is drawn as copies of the text offset around a circle, because
	// a TextField has no stroke. Eight is enough that the ring reads as solid
	// at this radius; fewer leaves scallops between the copies.
	static inline var HALO_STEPS = 8;

	/**
		Where a district label wants to sit, or null if it cannot fit legibly.

		`floor` is the smallest size worth printing, which the caller supplies
		because it depends on the map rather than on the text. ⚠️ **It is not a
		constant in city units.** The view scales to fit `cityRadius`, so a
		label of a given size in city units renders larger on a small town than
		on a metropolis; an absolute floor made a size-6 town's population line
		nearly as large as its own title. `LabelPlan` derives it from the
		radius, which is what makes it the same size on screen for every map.

		`avoid` is the boxes already spoken for. The largest size at any angle
		that clears all of them wins; passing null skips the test entirely and
		gives the plain best fit, which is what this did before collisions
		were considered at all.
	**/
	public static function fit( text:String, shape:Polygon, floor:Float, ?avoid:Array<Rectangle> ):Null<Placement> {
		for (option in options( text, shape, floor ))
			if (avoid == null || clear( text, option, avoid ))
				return option;

		return null;
	}

	/**
		Every placement worth considering, largest first — each angle at each
		fallback size. Largest first means a smaller label at a roomier angle
		is preferred over shrinking the best one, and a bigger placement is
		never passed over for a smaller one.
	**/
	static function options( text:String, shape:Polygon, floor:Float ):Array<Placement> {
		var centre = shape.center;

		var result:Array<Placement> = [];
		for (c in sizeByAngle( text, shape ))
			for (shrink in SHRINK) {
				var size = c.size * shrink;
				if (size >= floor)
					result.push( { at: centre, angle: c.angle, size: size } );
			}

		result.sort( function( a:Placement, b:Placement )
			return a.size < b.size ? 1 : (a.size > b.size ? -1 : 0) );

		return result;
	}

	/**
		Like `fit`, but never gives up.

		A district the caller named by hand in `districts=` is the one label on
		the map that must not silently vanish: the whole reason for typing a
		name is to see it printed. When nothing legible fits — a patch too
		small, or every size already taken — it is printed at the floor anyway,
		overflowing its patch. Reserve these before the generated names, and
		the generated names are the ones that move.
	**/
	public static function fitInsistent( text:String, shape:Polygon, floor:Float, ?avoid:Array<Rectangle> ):Null<Placement> {
		var placed = fit( text, shape, floor, avoid );
		if (placed != null)
			return placed;

		var candidates = sizeByAngle( text, shape );
		if (candidates.length == 0)
			return null;

		// Nothing clears everything, so take the least bad rather than simply
		// the biggest: two hand-named districts in neighbouring patches are
		// both going to be printed, and where they touch is worth choosing.
		var choices = options( text, shape, floor );
		if (choices.length == 0)
			// Not even the smallest legible size fits the patch. Print it at
			// the floor anyway, overflowing — a name the caller typed is the
			// one label on the map that must never silently disappear.
			for (c in candidates)
				choices.push( { at: shape.center, angle: c.angle, size: floor } );

		var best:Placement = null;
		var least = Math.POSITIVE_INFINITY;
		for (choice in choices) {
			var spilt = overlap( text, choice, avoid );
			if (spilt < least || (spilt == least && choice.size > best.size)) {
				least = spilt;
				best = choice;
			}
		}

		return best;
	}

	/**
		The largest size the patch allows at each of a spread of angles.

		Every 15 degrees over a half turn: text reads the same either way up,
		so the other half is redundant.
	**/
	static function sizeByAngle( text:String, shape:Polygon ):Array<{angle:Float, size:Float}> {
		var result:Array<{angle:Float, size:Float}> = [];
		if (text == null || text == "")
			return result;

		var centre = shape.center;

		var steps = 12;
		for (i in 0...steps) {
			var angle = Math.PI * i / steps;
			var cos = Math.cos( -angle );
			var sin = Math.sin( -angle );

			var minX = Math.POSITIVE_INFINITY, maxX = Math.NEGATIVE_INFINITY;
			var minY = Math.POSITIVE_INFINITY, maxY = Math.NEGATIVE_INFINITY;

			for (v in shape) {
				var dx = v.x - centre.x;
				var dy = v.y - centre.y;
				var x = dx * cos - dy * sin;
				var y = dx * sin + dy * cos;
				if (x < minX) minX = x;
				if (x > maxX) maxX = x;
				if (y < minY) minY = y;
				if (y > maxY) maxY = y;
			}

			// The bounding box overstates a concave patch, so pull the label
			// in from both dimensions rather than trusting the extremes.
			var width = (maxX - minX) * 0.78;
			var depth = (maxY - minY) * DEPTH_SHARE;

			result.push( { angle: angle, size: Math.min( depth, width / (GLYPH_RATIO * text.length) ) } );
		}

		return result;
	}

	/**
		The axis-aligned box a label occupies, padding included.

		Axis-aligned overstates a rotated label, which is the safe direction to
		be wrong in: it turns down a few placements that would in fact have
		been fine, and never accepts one that collides. Testing the rotated
		rectangles exactly means a separating-axis test, and the handful of
		placements it would rescue are not worth carrying one.
	**/
	public static function box( text:String, at:Point, angle:Float, size:Float ):Rectangle {
		var hw = size * (BOX_RATIO * text.length / 2 + PAD);
		var hh = size * (BOX_HEIGHT / 2 + PAD);

		var cos = Math.abs( Math.cos( angle ) );
		var sin = Math.abs( Math.sin( angle ) );

		var w = hw * cos + hh * sin;
		var h = hw * sin + hh * cos;

		return new Rectangle( at.x - w, at.y - h, w * 2, h * 2 );
	}

	public static function clear( text:String, placement:Placement, avoid:Array<Rectangle> ):Bool {
		var b = box( text, placement.at, placement.angle, placement.size );
		for (taken in avoid)
			if (taken.intersects( b ))
				return false;
		return true;
	}

	// How much of the map a placement would print over. Only consulted once
	// nothing clear is left.
	static function overlap( text:String, placement:Placement, avoid:Array<Rectangle> ):Float {
		if (avoid == null)
			return 0;

		var b = box( text, placement.at, placement.angle, placement.size );

		var total = 0.0;
		for (taken in avoid) {
			var shared = taken.intersection( b );
			total += shared.width * shared.height;
		}

		return total;
	}

	/**
		Degrees for a fitted angle, flipped past vertical so text never
		renders upside down.
	**/
	public static function degrees( angle:Float ):Float {
		var d = angle * 180 / Math.PI;
		return d > 90 ? d - 180 : d;
	}

	/**
		The label itself, centred on `at`, over a halo in `halo`.
	**/
	public static function render( text:String, at:Point, angle:Float, size:Float, colour:Int, halo:Int ):Sprite {
		var holder = new Sprite();
		holder.mouseEnabled = false;
		holder.mouseChildren = false;

		var reach = HALO * BASE_SIZE;
		for (i in 0...HALO_STEPS) {
			var a = Math.PI * 2 * i / HALO_STEPS;
			var copy = glyphs( text, halo );
			copy.x += Math.cos( a ) * reach;
			copy.y += Math.sin( a ) * reach;
			holder.addChild( copy );
		}

		holder.addChild( glyphs( text, colour ) );

		// Rasterised at BASE_SIZE and scaled down, never sized in city units
		// directly — see the class comment.
		holder.scaleX = holder.scaleY = size / BASE_SIZE;

		holder.rotation = degrees( angle );

		holder.x = at.x;
		holder.y = at.y;

		return holder;
	}

	static function glyphs( text:String, colour:Int ):TextField {
		var field = new TextField();
		field.defaultTextFormat = new TextFormat( FONT, BASE_SIZE, colour );
		field.autoSize = TextFieldAutoSize.LEFT;
		field.selectable = false;
		field.mouseEnabled = false;
		field.text = text;

		// Centre the glyphs on the sprite's origin so rotation pivots on the
		// middle of the word rather than its top-left corner.
		field.x = -field.width / 2;
		field.y = -field.height / 2;

		return field;
	}
}
