package com.watabou.towngenerator.ui;

/**
	A button that does one thing.
**/
class ActionButton extends Button {

	public function new( label:String, hint:String, action:Void->Void ) {
		super( label, hint );
		click.add( action );
	}
}
