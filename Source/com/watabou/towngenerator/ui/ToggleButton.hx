package com.watabou.towngenerator.ui;

/**
	A button that reports one thing about the city on screen and flips it.

	`on` is read from the finished `Model`, not from `StateManager`, so it
	shows what the map actually has rather than what was asked for. Those
	differ whenever a parameter was left to be rolled — which is the default
	for the walls, the citadel and the plaza.
**/
class ToggleButton extends Button {

	public function new( label:String, on:Bool, hint:String, set:Bool->Void ) {
		super( label + (on ? " on" : " off"), hint );
		click.add( function() set( !on ) );
	}
}
