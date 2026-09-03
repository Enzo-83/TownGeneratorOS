package com.watabou.towngenerator.ui;

import com.watabou.coogee.Game;
import com.watabou.utils.Random;

class CitySizeButton extends Button {

	private var size : Int;

	public function new( label:String, minSize:Int, maxSize:Int ) {
		super( label, "A new city of this size" );

		size = minSize + Std.int( Math.random() * (maxSize - minSize) );

		click.add( onClick );
	}

	private function onClick():Void {
		StateManager.size = size;
		StateManager.seed = Random.getSeed();

		Tooltip.instance.set( null );
		StateManager.regenerate();
		Game.switchScene( TownScene );
	}
}
