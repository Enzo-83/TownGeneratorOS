package com.watabou.towngenerator;

import openfl.display.Sprite;
import openfl.events.KeyboardEvent;

import com.watabou.coogee.Scene;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;
import com.watabou.towngenerator.mapping.MapExporter;
import com.watabou.towngenerator.ui.Menu;
import com.watabou.towngenerator.ui.Tooltip;

class TownScene extends Scene {

	private var menu	: Menu;
	private var map		: CityMap;

	public function new() {
		super();

		map = new CityMap( Model.instance );
		addChild( map );

		menu = new Menu( map );
		addChild( menu );

		// After the menu, so a tooltip is drawn over the button it belongs to.
		addChild( new Tooltip() );
	}

	// The keys the exporters have always answered to. The menu does the same
	// two things where they can be found.
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

		menu.x = rWidth - menu.width - 1;
		menu.y = 1;
	}
}
