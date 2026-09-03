package com.watabou.towngenerator.mapping;

import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Matrix;
import openfl.utils.ByteArray;

import com.watabou.geom.Polygon;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.wards.*;

#if html5
import js.Browser;
import js.html.Blob;
import js.html.Uint8Array;
import js.html.URL;
#end

using com.watabou.utils.ArrayExtender;

/**
	Getting a map out of the generator.

	SVG is written from the model rather than captured from the screen, so the
	output is real vector geometry you can pull apart in an editor — which is
	the point of exporting rather than screenshotting. PNG is a straight raster
	of the rendered map at a fixed large width.
**/
class MapExporter {

	static inline var PNG_WIDTH = 2048;

	// The exported frame, as a multiple of cityRadius. Matches TownScene so
	// the title and scale bar are inside the picture.
	static inline var MARGIN = 1.3;

	// ---------------------------------------------------------------- SVG

	public static function svg( model:Model ):String {
		var palette = CityMap.palette;
		var r = model.cityRadius * MARGIN;
		var span = r * 2;

		var b = new StringBuf();
		b.add( '<?xml version="1.0" encoding="UTF-8"?>\n' );
		b.add( '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${f(-r)} ${f(-r)} ${f(span)} ${f(span)}" width="2048" height="2048">\n' );
		b.add( '<rect x="${f(-r)}" y="${f(-r)}" width="${f(span)}" height="${f(span)}" fill="${hex(palette.paper)}"/>\n' );

		b.add( '<g id="roads" fill="none" stroke-linecap="round">\n' );
		for (road in model.roads) {
			b.add( '<polyline points="${points(road)}" stroke="${hex(palette.medium)}" stroke-width="${f(Ward.MAIN_STREET + Brush.NORMAL_STROKE)}"/>\n' );
			b.add( '<polyline points="${points(road)}" stroke="${hex(palette.paper)}" stroke-width="${f(Ward.MAIN_STREET - Brush.NORMAL_STROKE)}"/>\n' );
		}
		b.add( '</g>\n' );

		b.add( '<g id="buildings">\n' );
		for (patch in model.patches) {
			if (patch.ward == null || patch.ward.geometry == null)
				continue;

			switch (Type.getClass( patch.ward )) {
				case Castle:
					for (block in patch.ward.geometry)
						b.add( shape( block, hex( palette.light ), hex( palette.dark ), Brush.NORMAL_STROKE * 2 ) );
				case Cathedral:
					for (block in patch.ward.geometry)
						b.add( shape( block, hex( palette.light ), hex( palette.dark ), Brush.NORMAL_STROKE ) );
				case Market, CraftsmenWard, MerchantWard, GateWard, Slum,
					 AdministrationWard, MilitaryWard, PatriciateWard, Farm:
					for (block in patch.ward.geometry)
						b.add( shape( block, hex( palette.light ), hex( palette.dark ), Brush.NORMAL_STROKE ) );
				case Park:
					for (grove in patch.ward.geometry)
						b.add( shape( grove, hex( palette.medium ), null, 0 ) );
				default:
			}
		}
		b.add( '</g>\n' );

		b.add( '<g id="walls">\n' );
		if (model.innerWall != null)
			addInnerWall( b, model.innerWall, hex( palette.dark ) );
		if (model.wall != null)
			addWall( b, model.wall, hex( palette.dark ) );
		if (model.citadel != null)
			addWall( b, cast( model.citadel.ward, Castle ).wall, hex( palette.dark ) );
		b.add( '</g>\n' );

		b.add( addLabels( model, hex( palette.dark ) ) );

		b.add( '</svg>\n' );
		return b.toString();
	}

	static function addWall( b:StringBuf, wall:com.watabou.towngenerator.building.CurtainWall, colour:String ):Void {
		b.add( '<polygon points="${points( wall.shape )}" fill="none" stroke="$colour" stroke-width="${f(Brush.THICK_STROKE)}"/>\n' );

		if (wall.towers != null)
			for (t in wall.towers)
				b.add( '<circle cx="${f(t.x)}" cy="${f(t.y)}" r="${f(Brush.THICK_STROKE)}" fill="$colour"/>\n' );
	}

	// Open at its gates and thinner, exactly as it is drawn on screen.
	static function addInnerWall( b:StringBuf, wall:com.watabou.towngenerator.building.CurtainWall, colour:String ):Void {
		var len = wall.shape.length;
		for (i in 0...len) {
			var v0 = wall.shape[i];
			var v1 = wall.shape[(i + 1) % len];
			if (wall.gates.contains( v0 ) || wall.gates.contains( v1 ))
				continue;
			b.add( '<line x1="${f(v0.x)}" y1="${f(v0.y)}" x2="${f(v1.x)}" y2="${f(v1.y)}" stroke="$colour" stroke-width="${f(Brush.NORMAL_STROKE * 1.5)}"/>\n' );
		}
	}

	/**
		Every label the screen renderer draws, from the same plan, so the two
		cannot disagree about which ones a map has. A plan places a label by
		its centre; SVG anchors text at its baseline, hence the shift.
	**/
	static function addLabels( model:Model, colour:String ):String {
		var plan = LabelPlan.build( model );

		var paper = hex( CityMap.palette.paper );

		var b = new StringBuf();
		b.add( '<g id="labels" fill="$colour" text-anchor="middle" font-family="Georgia, serif">\n' );

		b.add( addScaleBar( model, colour ) );

		for (marker in plan.markers)
			b.add( '<circle cx="${f(marker.at.x)}" cy="${f(marker.at.y)}" r="${f(marker.r)}" fill="$colour"/>\n' );

		// The halo the screen draws as eight offset copies is a stroke under
		// the fill here. `paint-order` keeps it to one element per label, so
		// the group is still something you can pull apart in an editor.
		for (label in plan.labels)
			b.add( text( label.text, label.at.x, label.at.y,
				label.size, LabelView.degrees( label.angle ),
				'stroke="$paper" stroke-width="${f(label.size * LabelView.HALO * 2)}" stroke-linejoin="round" paint-order="stroke"' ) );

		b.add( '</g>\n' );
		return b.toString();
	}

	// The bar's rules only. Its caption is a label like any other, and comes
	// from the plan with the rest of them.
	static function addScaleBar( model:Model, colour:String ):String {
		var s = LabelPlan.scaleBar( model );
		var w = f( Brush.NORMAL_STROKE * 1.5 );

		var b = new StringBuf();
		b.add( '<g stroke="$colour" stroke-width="$w">\n' );
		b.add( '<line x1="${f(s.x)}" y1="${f(s.y)}" x2="${f(s.x + s.length)}" y2="${f(s.y)}"/>\n' );
		b.add( '<line x1="${f(s.x)}" y1="${f(s.y - s.tick)}" x2="${f(s.x)}" y2="${f(s.y + s.tick)}"/>\n' );
		b.add( '<line x1="${f(s.x + s.length)}" y1="${f(s.y - s.tick)}" x2="${f(s.x + s.length)}" y2="${f(s.y + s.tick)}"/>\n' );
		b.add( '<line x1="${f(s.x + s.length / 2)}" y1="${f(s.y)}" x2="${f(s.x + s.length / 2)}" y2="${f(s.y + s.tick)}"/>\n' );
		b.add( '</g>\n' );
		return b.toString();
	}

	// ------------------------------------------------------------ helpers

	/**
		One label, centred on (`x`, `y`).

		⚠️ **The baseline shift goes inside the rotation, not before it.** SVG
		anchors text at its baseline and the plan gives a centre, so the two
		differ by `BASELINE` — but that offset is along the glyphs' own down
		axis, not the page's. Applied outside, a label rotated 90° came out a
		third of its height off along the page's x instead, which put it
		somewhere neither the screen renderer nor the collision box had it.
	**/
	static function text( s:String, x:Float, y:Float, size:Float, rotation:Float, extra = "" ):String {
		var escaped = StringTools.htmlEscape( s );
		var baseline = f( size * LabelView.BASELINE );
		return rotation == 0 ?
			'<text x="${f(x)}" y="${f(y + size * LabelView.BASELINE)}" font-size="${f(size)}" $extra>$escaped</text>\n' :
			'<text transform="translate(${f(x)},${f(y)}) rotate(${f(rotation)})" y="$baseline" font-size="${f(size)}" $extra>$escaped</text>\n';
	}

	static function shape( poly:Polygon, fill:String, stroke:String, width:Float ):String {
		var attrs = stroke != null ? 'stroke="$stroke" stroke-width="${f(width)}"' : 'stroke="none"';
		return '<polygon points="${points( poly )}" fill="$fill" $attrs/>\n';
	}

	static function points( poly:Polygon ):String {
		var parts = [];
		for (v in poly)
			parts.push( f( v.x ) + "," + f( v.y ) );
		return parts.join( " " );
	}

	// Two decimals is well under a pixel at export size and keeps the file small.
	static function f( value:Float ):String
		return Std.string( Math.round( value * 100 ) / 100 );

	static function hex( colour:Int ):String
		return "#" + StringTools.hex( colour, 6 );

	// ------------------------------------------------------------ download

	public static function downloadSvg( model:Model ):Void {
		#if html5
		var name = (model.cityName != null ? model.cityName : "city");
		save( name + ".svg", cast svg( model ), "image/svg+xml" );
		#end
	}

	public static function downloadPng( source:DisplayObject, model:Model ):Void {
		#if html5
		var r = model.cityRadius * MARGIN;
		var scale = PNG_WIDTH / (r * 2);

		var matrix = new Matrix();
		matrix.translate( r, r );
		matrix.scale( scale, scale );

		var bitmap = new BitmapData( PNG_WIDTH, PNG_WIDTH, false, CityMap.palette.paper );
		bitmap.draw( source, matrix );

		var bytes:ByteArray = bitmap.encode( bitmap.rect, new PNGEncoderOptions() );
		bytes.position = 0;

		var buffer = new Uint8Array( bytes.length );
		for (i in 0...bytes.length)
			buffer[i] = bytes.readUnsignedByte();

		var name = (model.cityName != null ? model.cityName : "city");
		save( name + ".png", cast buffer, "image/png" );
		#end
	}

	#if html5
	static function save( filename:String, payload:Dynamic, mime:String ):Void {
		var blob = new Blob( [payload], { type: mime } );
		var url = URL.createObjectURL( blob );

		var anchor = Browser.document.createAnchorElement();
		anchor.href = url;
		anchor.download = filename;
		Browser.document.body.appendChild( anchor );
		anchor.click();
		anchor.remove();

		URL.revokeObjectURL( url );
	}
	#end
}
