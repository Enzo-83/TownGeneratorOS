package com.watabou.towngenerator.ui;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.geom.Point;

import msignal.Signal.Signal0;

import com.watabou.coogee.BitmapText;

import com.watabou.towngenerator.mapping.CityMap;

class Button extends Sprite {

	// Wide enough for "Citadel off" — a toggle has to say which way it is
	// pointing, and a button that only fits "Citadel" cannot.
	public static inline var WIDTH	= 62;
	public static inline var HEIGHT	= 13;

	public var click	: Signal0 = new Signal0();

	private var face	: Bitmap;
	private var hint	: String;

	/**
		`hint` is what the tooltip says. Buttons in this UI are five words of
		bitmap font on a dark slab, which is not enough room to explain
		anything, so anything that needs explaining says it on hover.
	**/
	public function new( label:String, ?hint:String ) {
		super();

		this.hint = hint;

		face = new Bitmap();
		addChild( face );
		setLabel( label );

		buttonMode = true;
		addEventListener( MouseEvent.MOUSE_DOWN, onClickHandler );

		if (hint != null) {
			addEventListener( MouseEvent.ROLL_OVER, onRollOver );
			addEventListener( MouseEvent.ROLL_OUT, onRollOut );
		}
	}

	/**
		Redraws the face. A toggle changes what it says when it is clicked.
	**/
	public function setLabel( label:String ):Void {
		var txtBmp = new BitmapText( Main.uiFont, label ).bitmapData;
		var bmp = new BitmapData( WIDTH, HEIGHT, false, CityMap.palette.dark );
		bmp.copyPixels( txtBmp, txtBmp.rect, new Point( 5, (HEIGHT - Main.uiFont.baseLine) >> 1 ), null, null, true );
		face.bitmapData = bmp;
	}

	private function onClickHandler( e:MouseEvent ) click.dispatch();

	private function onRollOver( e:MouseEvent ) Tooltip.instance.set( hint );

	private function onRollOut( e:MouseEvent ) Tooltip.instance.set( null );
}
