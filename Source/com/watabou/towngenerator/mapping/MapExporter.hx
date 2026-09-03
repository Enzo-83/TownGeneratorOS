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

	static function addLabels( model:Model, colour:String ):String {
		var b = new StringBuf();
		b.add( '<g id="labels" fill="$colour" text-anchor="middle" font-family="Georgia, serif">\n' );

		for (patch in model.patches) {
			if (!patch.withinCity || patch.ward == null)
				continue;

			if (patch.landmark != null) {
				var centre = patch.shape.center;
				b.add( '<circle cx="${f(centre.x)}" cy="${f(centre.y)}" r="${f(model.cityRadius * 0.011)}" fill="$colour"/>\n' );
				b.add( text( patch.landmark, centre.x, centre.y + model.cityRadius * 0.038 + model.cityRadius * 0.011, model.cityRadius * 0.030, 0 ) );

			} else if (patch.ward.name != null) {
				var placement = LabelView.fit( patch.ward.name, patch.shape );
				if (placement != null)
					b.add( text( patch.ward.name, placement.at.x, placement.at.y + placement.size * 0.34,
						placement.size, LabelView.degrees( placement.angle ) ) );
			}
		}

		if (model.cityName != null) {
			b.add( text( model.cityName, 0, -model.cityRadius * 1.16, model.cityRadius * 0.14, 0 ) );
			b.add( text( '~${CityMap.thousands( model.population )} people · ${CityMap.thousands( model.buildingCount )} buildings',
				0, -model.cityRadius * 1.05, model.cityRadius * 0.038, 0 ) );
		}

		b.add( addScaleBar( model, colour ) );
		b.add( '</g>\n' );
		return b.toString();
	}

	static function addScaleBar( model:Model, colour:String ):String {
		var half = model.cityRadius * Model.METRES_PER_UNIT * 0.6;
		var metres = 50;
		for (candidate in [50, 100, 250, 500, 1000, 2000, 5000])
			if (candidate <= half)
				metres = candidate;

		var length = metres / Model.METRES_PER_UNIT;
		var x = -model.cityRadius;
		var y = model.cityRadius * 1.1;
		var tick = model.cityRadius * 0.02;
		var w = f( Brush.NORMAL_STROKE * 1.5 );

		var b = new StringBuf();
		b.add( '<g stroke="$colour" stroke-width="$w">\n' );
		b.add( '<line x1="${f(x)}" y1="${f(y)}" x2="${f(x + length)}" y2="${f(y)}"/>\n' );
		b.add( '<line x1="${f(x)}" y1="${f(y - tick)}" x2="${f(x)}" y2="${f(y + tick)}"/>\n' );
		b.add( '<line x1="${f(x + length)}" y1="${f(y - tick)}" x2="${f(x + length)}" y2="${f(y + tick)}"/>\n' );
		b.add( '<line x1="${f(x + length / 2)}" y1="${f(y)}" x2="${f(x + length / 2)}" y2="${f(y + tick)}"/>\n' );
		b.add( '</g>\n' );
		b.add( text( metres + " m", x + length / 2, y + tick * 4.4, model.cityRadius * 0.045, 0 ) );
		return b.toString();
	}

	// ------------------------------------------------------------ helpers

	static function text( s:String, x:Float, y:Float, size:Float, rotation:Float ):String {
		var escaped = StringTools.htmlEscape( s );
		return rotation == 0 ?
			'<text x="${f(x)}" y="${f(y)}" font-size="${f(size)}">$escaped</text>\n' :
			'<text transform="translate(${f(x)},${f(y)}) rotate(${f(rotation)})" font-size="${f(size)}">$escaped</text>\n';
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
