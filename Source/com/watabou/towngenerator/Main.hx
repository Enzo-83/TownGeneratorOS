package com.watabou.towngenerator;

import openfl.system.Capabilities;

import com.watabou.coogee.Game;
import com.watabou.coogee.BitmapText.BitmapFont;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;

class Main extends Game {

	// Paper on a dark slab: the menu's own rows.
	public static var uiFont	: BitmapFont;
	// The same font in the middle tone, for the one piece of text this UI
	// puts straight onto the map. `uiFont` is the paper colour, so on the
	// paper background it would be invisible.
	public static var hintFont	: BitmapFont;

	public function new () {
		StateManager.pullParams();
		StateManager.pushParams();

		stage.color = CityMap.palette.paper;

		// The controls are on the right mouse button, so the browser's own
		// context menu has to go. ⚠️ This is what does it: lime only calls
		// preventDefault on the contextmenu event when OpenFL has cancelled
		// the mouse event under it, and OpenFL only cancels it when this is
		// false. There is no separate hook to reach for.
		stage.showDefaultContextMenu = false;

		uiFont = BitmapFont.get( "font", CityMap.palette.paper );
		uiFont.letterSpacing = 1;
		uiFont.baseLine = 8;

		hintFont = BitmapFont.get( "font", CityMap.palette.medium );
		hintFont.letterSpacing = 1;
		hintFont.baseLine = 8;

		Model.options = StateManager.toOptions();
		new Model( StateManager.size, StateManager.seed );

		super( TownScene );
	}

	override public function getScale( w:Int, h:Int ):Float {
		return Std.int( Capabilities.screenDPI / 24 );
	}
}