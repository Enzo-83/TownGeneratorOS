package com.watabou.towngenerator.ui;

import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.events.MouseEvent;
import openfl.geom.Point;

import com.watabou.coogee.BitmapText;

import com.watabou.towngenerator.mapping.CityMap;

using com.watabou.utils.DisplayObjectExtender;

class Tooltip extends Bitmap {

	public static var instance : Tooltip;

	private static var cache : Map<String, BitmapData> = new Map();

	public function new() {
		instance = this;

		super();

		this.onActivate( activation );

		set( null );
	}

	private function activation( active:Bool )
		if (active) {
			stage.addEventListener( MouseEvent.MOUSE_MOVE, onMouseMove );
			stage.addEventListener( MouseEvent.MOUSE_DOWN, onMouseMove );
		} else {
			stage.removeEventListener( MouseEvent.MOUSE_MOVE, onMouseMove );
			stage.removeEventListener( MouseEvent.MOUSE_DOWN, onMouseMove );
		}

	/**
		Beside the cursor, but kept on screen.

		⚠️ Not simply `mouseX + 4`. The menu is against the right-hand edge, so
		every tooltip it raises starts off the side of the window and the one
		place a hint is most needed is the one place it could not be read.
	**/
	private function onMouseMove( e:MouseEvent ) {
		// The scene is scaled by Game.layout, so the stage is this many
		// scene units across.
		var limitX = stage.stageWidth / parent.scaleX;
		var limitY = stage.stageHeight / parent.scaleY;

		x = Math.max( 0, Math.min( parent.mouseX + 4, limitX - width - 1 ) );
		y = Math.max( 0, Math.min( parent.mouseY, limitY - height - 1 ) );

		e.updateAfterEvent();
	}

	public function set( txt:String ) {
		visible = (txt != null);
		if (visible) {
			var bmp:BitmapData = cache[txt];
			if (bmp == null) {
				var txtBmp = new BitmapText( Main.uiFont, txt ).bitmapData;
				bmp = new BitmapData( txtBmp.width + 4, txtBmp.height + 2, false, CityMap.palette.dark );
				bmp.copyPixels( txtBmp, txtBmp.rect, new Point( 2, 1 ), null, null, true );
				cache[txt] = bmp;
			}
			bitmapData = bmp;
		}
	}
}
