package com.watabou.towngenerator.mapping;

import openfl.display.Sprite;
import openfl.geom.Point;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

import com.watabou.geom.Polygon;

/**
	District and settlement labels.

	The map is drawn in city units — a whole town is only a few hundred across —
	so a label sized directly in those units would be a 5pt TextField stretched
	up by the scene transform, and it would look it. Text is therefore always
	rasterised at `BASE_SIZE` and the sprite scaled *down* to fit.
**/
class LabelView {

	// Big enough that scaling down never softens the glyphs.
	static inline var BASE_SIZE = 64;

	// Below this, in city units, a label is unreadable clutter; skip it.
	static inline var MIN_FIT = 3.6;

	static inline var FONT = "Georgia,Times New Roman,serif";

	// How wide a glyph is relative to its point size, and how much of a
	// patch's depth a label may occupy. Both measured against the render.
	static inline var GLYPH_RATIO = 0.46;
	static inline var DEPTH_SHARE = 0.55;

	/**
		Fits `text` inside `shape`, trying a spread of angles and keeping the
		one that allows the largest legible size. Returns null when nothing
		fits — a patch too small or too thin to carry its own name.
	**/
	public static function forPatch( text:String, shape:Polygon, colour:Int ):Sprite {
		var placement = fit( text, shape );
		return placement == null ?
			null :
			build( text, placement.at, placement.angle, placement.size, colour );
	}

	/**
		Where a district label wants to sit, or null if it cannot fit legibly.
		Shared by the screen renderer and the SVG exporter so both agree.
	**/
	public static function fit( text:String, shape:Polygon ):Null<{at:Point, angle:Float, size:Float}> {
		if (text == null || text == "")
			return null;

		var centre = shape.center;

		var bestSize = 0.0;
		var bestAngle = 0.0;

		// Every 15 degrees over a half turn: text reads the same either way up,
		// so the other half is redundant.
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

			var size = Math.min( depth, width / (GLYPH_RATIO * text.length) );
			if (size > bestSize) {
				bestSize = size;
				bestAngle = angle;
			}
		}

		if (bestSize < MIN_FIT)
			return null;

		return { at: centre, angle: bestAngle, size: bestSize };
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
		A label at a fixed size and position — the settlement's own name.
	**/
	public static function freestanding( text:String, at:Point, size:Float, colour:Int ):Sprite
		return build( text, at, 0, size, colour );

	static function build( text:String, at:Point, angle:Float, size:Float, colour:Int ):Sprite {
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

		var holder = new Sprite();
		holder.mouseEnabled = false;
		holder.mouseChildren = false;
		holder.addChild( field );

		var scale = size / BASE_SIZE;
		holder.scaleX = holder.scaleY = scale;

		holder.rotation = degrees( angle );

		holder.x = at.x;
		holder.y = at.y;

		return holder;
	}
}
