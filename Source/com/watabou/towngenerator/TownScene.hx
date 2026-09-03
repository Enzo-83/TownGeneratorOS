package com.watabou.towngenerator;

import openfl.display.Sprite;
import openfl.events.KeyboardEvent;

import com.watabou.coogee.Scene;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;
import com.watabou.towngenerator.mapping.MapExporter;
import com.watabou.towngenerator.ui.CitySizeButton;
import com.watabou.towngenerator.ui.Tooltip;

class TownScene extends Scene {

	private var buttons	: Sprite;
	private var map		: CityMap;

	public function new() {
		super();

		map = new CityMap( Model.instance );
		addChild( map );

		addChild( new Tooltip() );

		buttons = new Sprite();
		addChild( buttons );

		var smallTown = new CitySizeButton( "Small Town", 6, 10 );
		var largeTown = new CitySizeButton( "Large Town", 10, 15 );
		var smallCity = new CitySizeButton( "Small City", 15, 24 );
		var largeCity = new CitySizeButton( "Large City", 24, 40 );

		var pos = 0.0;
		for (btn in [smallTown, largeTown, smallCity, largeCity]) {
			btn.y = pos;
			pos += btn.height + 1;
			buttons.addChild( btn );
		}

	}

	// S saves vector, P saves raster. The released generator puts these behind
	// a menu; a menu is a bigger job than the exporters themselves.
	override private function onKeyDown( e:KeyboardEvent ):Void {
		super.onKeyDown( e );

		switch (e.keyCode) {
			case 83: MapExporter.downloadSvg( Model.instance );
			case 80: MapExporter.downloadPng( map, Model.instance );
			default:
		}
	}

	private var scale(get,set) : Float;
	private inline function get_scale():Float
		return map.scaleX;
	private function set_scale( value:Float ):Float
		return (map.scaleX = map.scaleY = value);

	override public function layout():Void {
		map.x = rWidth / 2;
		map.y = rHeight / 2;

		// Leave room beyond the city itself for the title above it and the
		// scale bar below; both are drawn in map units and would be clipped
		// by a fit that stops at cityRadius.
		var extent = Model.instance.cityRadius * 1.3;
		var scaleX = rWidth / extent;
		var scaleY = rHeight / extent;
		var scMin = Math.min( scaleX, scaleY );
		var scMax = Math.max( scaleX, scaleY );
		scale = (scMax / scMin > 2 ? scMax / 2 : scMin) * 0.5;

		buttons.x = rWidth - buttons.width - 1;
		buttons.y = 1;
	}
}
