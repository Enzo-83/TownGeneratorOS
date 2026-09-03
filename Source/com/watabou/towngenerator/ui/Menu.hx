package com.watabou.towngenerator.ui;

import openfl.display.Sprite;

import com.watabou.coogee.Game;
import com.watabou.utils.Random;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;
import com.watabou.towngenerator.mapping.MapExporter;

/**
	The controls, down the right-hand edge.

	Everything here was previously either a URL parameter you had to know about
	or an unmarked keypress — `S` wrote an SVG and `P` a PNG, and nothing on
	screen said so. Both keys still work; this makes them findable.

	It is rebuilt from scratch on every regeneration, because a toggle shows
	the state of the city on screen and that changes underneath it.
**/
class Menu extends Sprite {

	// A blank row between groups of buttons.
	static inline var GAP = 5.0;

	var pos	: Float = 0;

	public function new( map:CityMap ) {
		super();

		var model = Model.instance;

		add( new CitySizeButton( "Small Town", 6, 10 ) );
		add( new CitySizeButton( "Large Town", 10, 15 ) );
		add( new CitySizeButton( "Small City", 15, 24 ) );
		add( new CitySizeButton( "Large City", 24, 40 ) );

		gap();

		add( new ActionButton( "New City", "Another city the same size", function() {
			StateManager.seed = Random.getSeed();
			rebuild();
		} ) );

		gap();

		add( new ToggleButton( "Walls", model.wall != null,
			"A curtain wall, with towers and gates",
			function( on ) { StateManager.walls = on; rebuild(); } ) );

		add( new ToggleButton( "Ring", model.innerWall != null,
			"An inner boundary, not a fortification",
			function( on ) { StateManager.innerWall = on; rebuild(); } ) );

		add( new ToggleButton( "Citadel", model.citadel != null,
			"A castle inside its own wall",
			function( on ) { StateManager.citadel = on; rebuild(); } ) );

		add( new ToggleButton( "Plaza", model.plaza != null,
			"A market square the streets run to",
			function( on ) { StateManager.plaza = on; rebuild(); } ) );

		gap();

		add( new ActionButton( "Save SVG", "Vector map, from the model not the screen (S)",
			function() MapExporter.downloadSvg( Model.instance ) ) );

		add( new ActionButton( "Save PNG", "The map as drawn, 2048 by 2048 (P)",
			function() MapExporter.downloadPng( map, Model.instance ) ) );
	}

	function add( button:Button ):Void {
		button.y = pos;
		pos += Button.HEIGHT + 1;
		addChild( button );
	}

	function gap():Void
		pos += GAP;

	// The tooltip belongs to the old scene and the mouse is over a button that
	// is about to stop existing, so clear it before the scene goes.
	static function rebuild():Void {
		Tooltip.instance.set( null );
		StateManager.regenerate();
		Game.switchScene( TownScene );
	}
}
