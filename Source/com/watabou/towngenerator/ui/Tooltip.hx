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

	/**
		Silences the tooltip while something is in front of the map.

		⚠️ Clearing it once as the context menu opens is not enough. The cursor
		is still over a patch, and the patch keeps raising its label from under
		the menu — so the tooltip comes back, at whatever position it last had,
		which is the top-left corner if it has never been moved.
	**/
	public static var blocked(default, set) : Bool = false;
	static function set_blocked( value:Bool ):Bool {
		blocked = value;
		if (value && instance != null)
			instance.visible = false;
		return value;
	}

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

	private function onMouseMove( e:MouseEvent ) {
		place();
		e.updateAfterEvent();
	}

	/**
		Beside the cursor, but kept on screen.

		⚠️ Not simply `mouseX + 4`. The map fills the window now that the
		buttons are gone, so a patch can be pointed at right against the right
		or bottom edge, and its label would open off the side of the window.
	**/
	private function place() {
		if (stage == null || parent == null)
			return;

		// The scene is scaled by Game.layout, so the stage is this many
		// scene units across.
		var limitX = stage.stageWidth / parent.scaleX;
		var limitY = stage.stageHeight / parent.scaleY;

		x = Math.max( 0, Math.min( parent.mouseX + 4, limitX - width - 1 ) );
		y = Math.max( 0, Math.min( parent.mouseY, limitY - height - 1 ) );
	}

	public function set( txt:String ) {
		visible = (txt != null && !blocked);

		if (visible) {
			var bmp:BitmapData = cache[txt];
			if (bmp == null) {
				var txtBmp = new BitmapText( Main.uiFont, txt ).bitmapData;
				bmp = new BitmapData( txtBmp.width + 4, txtBmp.height + 2, false, CityMap.palette.dark );
				bmp.copyPixels( txtBmp, txtBmp.rect, new Point( 2, 1 ), null, null, true );
				cache[txt] = bmp;
			}
			bitmapData = bmp;

			// ⚠️ Positioned here as well as on mouse move. Regenerating the
			// city builds a new scene under a cursor that has not moved, so
			// the patch beneath it raises its label straight away — and
			// without this the label appears in the top-left corner and stays
			// there until the mouse is nudged.
			place();
		}
	}
}
