package com.watabou.towngenerator;

import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.ui.Keyboard;

import com.watabou.coogee.BitmapText;
import com.watabou.coogee.Game;
import com.watabou.coogee.Scene;
import com.watabou.utils.Random;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;
import com.watabou.towngenerator.mapping.MapExporter;
import com.watabou.towngenerator.ui.ContextMenu;
import com.watabou.towngenerator.ui.Tooltip;

class TownScene extends Scene {

	private var map		: CityMap;
	private var menu	: ContextMenu;
	private var hint	: BitmapText;

	public function new() {
		super();

		map = new CityMap( Model.instance );
		addChild( map );

		hint = new BitmapText( Main.hintFont, "right-click for options" );
		hint.visible = !ContextMenu.everOpened;
		addChild( hint );

		addChild( new Tooltip() );

		// Above the tooltip: while the menu is open it is the only thing the
		// mouse is talking to.
		menu = buildMenu();
		addChild( menu );
	}

	/**
		Everything the generator can be told to do, in one gesture.

		A toggle reads its state from the finished `Model` rather than from
		`StateManager`, so it reports what the map on screen actually has. The
		two differ whenever a parameter was left to be rolled, which is the
		default for the walls, the citadel and the plaza.
	**/
	private function buildMenu():ContextMenu {
		var model = Model.instance;
		var menu = new ContextMenu();

		menu.item( "Small Town", null, function() resize( 6, 10 ) );
		menu.item( "Large Town", null, function() resize( 10, 15 ) );
		menu.item( "Small City", null, function() resize( 15, 24 ) );
		menu.item( "Large City", null, function() resize( 24, 40 ) );

		menu.separator();

		menu.item( "New City", null, function() {
			StateManager.seed = Random.getSeed();
			regenerate();
		} );

		menu.separator();

		toggle( menu, "Walls", model.wall != null,
			function( on ) { StateManager.walls = on; regenerate(); } );
		toggle( menu, "Ring", model.innerWall != null,
			function( on ) { StateManager.innerWall = on; regenerate(); } );
		toggle( menu, "Citadel", model.citadel != null,
			function( on ) { StateManager.citadel = on; regenerate(); } );
		toggle( menu, "Plaza", model.plaza != null,
			function( on ) { StateManager.plaza = on; regenerate(); } );
		toggle( menu, "River", model.river != null,
			function( on ) { StateManager.river = on; regenerate(); } );

		menu.separator();

		menu.item( "Save SVG", null, function() MapExporter.downloadSvg( Model.instance ) );
		menu.item( "Save PNG", null, function() MapExporter.downloadPng( map, Model.instance ) );

		menu.pack();
		return menu;
	}

	private function toggle( menu:ContextMenu, label:String, on:Bool, set:Bool->Void ):Void
		menu.item( label, on ? "on" : "off", function() set( !on ) );

	// A new size somewhere in the band, and a new seed with it. The buttons
	// this replaced drew their size once when they were built, so clicking
	// one twice gave the same size twice.
	private function resize( minSize:Int, maxSize:Int ):Void {
		StateManager.size = minSize + Std.int( Math.random() * (maxSize - minSize) );
		StateManager.seed = Random.getSeed();
		regenerate();
	}

	private function regenerate():Void {
		Tooltip.instance.set( null );
		StateManager.regenerate();
		Game.switchScene( TownScene );
	}

	override public function activate():Void {
		super.activate();
		stage.addEventListener( MouseEvent.RIGHT_MOUSE_DOWN, onRightClick );
	}

	override public function deactivate():Void {
		super.deactivate();
		stage.removeEventListener( MouseEvent.RIGHT_MOUSE_DOWN, onRightClick );
	}

	private function onRightClick( e:MouseEvent ):Void {
		hint.visible = false;
		menu.open( new Point( mouseX, mouseY ), rWidth, rHeight );
	}

	// S saves vector, P saves raster, as they always have. Both are in the
	// menu too, which is where anyone who has not read the README will look.
	override private function onKeyDown( e:KeyboardEvent ):Void {
		// Escape closes the menu rather than reaching Scene's own handler,
		// which quits.
		if (e.keyCode == Keyboard.ESCAPE && menu.isOpen) {
			menu.close();
			return;
		}

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

		hint.x = 3;
		hint.y = rHeight - hint.height - 3;
	}
}
