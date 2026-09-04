package com.watabou.towngenerator.ui;

import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.geom.Point;

import com.watabou.coogee.BitmapText;

import com.watabou.towngenerator.mapping.CityMap;

/**
	One line of the menu: a caption, optionally a state right-aligned against
	the far edge, and something to do when it is clicked.
**/
class MenuRow extends Sprite {

	public static inline var HEIGHT	= 13;
	static inline var PAD			= 6;

	var action	: Void->Void;

	var caption	: BitmapText;
	var state	: BitmapText;
	var span	: Float = 0;

	public function new( text:String, state:String, action:Void->Void ) {
		super();

		this.action = action;

		var top = (HEIGHT - Main.uiFont.baseLine) >> 1;

		caption = new BitmapText( Main.uiFont, text );
		caption.x = PAD;
		caption.y = top;
		addChild( caption );

		if (state != null) {
			this.state = new BitmapText( Main.uiFont, state );
			this.state.y = top;
			addChild( this.state );
		}

		buttonMode = true;
		addEventListener( MouseEvent.MOUSE_OVER, onOver );
		addEventListener( MouseEvent.MOUSE_OUT, onOut );
		addEventListener( MouseEvent.MOUSE_DOWN, onDown );
	}

	// What the row would like to be, before the menu makes them all agree.
	public var contentWidth(get,never) : Float;
	function get_contentWidth():Float
		return PAD * 2 + caption.width + (state == null ? 0 : PAD * 2 + state.width);

	public function setWidth( w:Float ):Void {
		span = w;
		if (state != null)
			state.x = w - PAD - state.width;
		fill( CityMap.palette.dark );
	}

	// A sprite's own graphics draw beneath its children, so this is a
	// background rather than a lid over the caption.
	function fill( colour:Int ):Void {
		graphics.clear();
		graphics.beginFill( colour );
		graphics.drawRect( 0, 0, span, HEIGHT );
		graphics.endFill();
	}

	function onOver( e:MouseEvent ) fill( CityMap.palette.medium );

	function onOut( e:MouseEvent ) fill( CityMap.palette.dark );

	function onDown( e:MouseEvent ) {
		e.stopPropagation();
		action();
	}
}

/**
	The controls, on the right mouse button.

	They used to be a column of buttons down the edge of the window, which is
	what the generator this forked from had. The released one dropped that for
	a context menu, and it is the better trade: the map is the whole point of
	the window, and a menu that is only there when it is asked for costs it
	nothing.

	⚠️ **The one thing a context menu costs is that nothing on screen says it
	is there** — which is exactly the complaint that got the buttons built in
	the first place, when export was on an unmarked `S`. Hence the hint in
	`TownScene`, which shows until the menu has been opened once.
**/
class ContextMenu extends Sprite {

	// The blank between two groups of rows.
	static inline var GAP = 4;

	// Set the first time it is opened, so the hint can stop nagging. Static
	// because regenerating the city builds a new scene, and having found the
	// menu once you have found it for good.
	public static var everOpened	= false;

	// Catches the click that dismisses the menu. A full-window sprite rather
	// than a listener on the stage, so the click that closes the menu is
	// swallowed rather than also landing on whatever is underneath.
	var shade	: Sprite;
	var panel	: Sprite;

	var rows	: Array<MenuRow>;
	var pos		: Float = 0;

	public function new() {
		super();

		shade = new Sprite();
		shade.addEventListener( MouseEvent.MOUSE_DOWN, function( e:MouseEvent ) close() );
		addChild( shade );

		panel = new Sprite();
		addChild( panel );

		rows = [];

		visible = false;
	}

	public function item( label:String, state:String, action:Void->Void ):Void {
		var row = new MenuRow( label, state, function() {
			close();
			action();
		} );

		row.y = pos;
		pos += MenuRow.HEIGHT;

		panel.addChild( row );
		rows.push( row );
	}

	public function separator():Void
		pos += GAP;

	/**
		Makes every row the width of the widest, and draws the panel behind
		them — which is also what fills the gaps the separators leave.
	**/
	public function pack():Void {
		var w = 0.0;
		for (row in rows)
			w = Math.max( w, row.contentWidth );

		for (row in rows)
			row.setWidth( w );

		var g = panel.graphics;
		g.clear();
		g.lineStyle( 1, CityMap.palette.medium );
		g.beginFill( CityMap.palette.dark );
		g.drawRect( -0.5, -0.5, w + 1, pos + 1 );
		g.endFill();
	}

	/**
		Opens at the cursor, kept inside a window `limitX` by `limitY`.

		⚠️ Not simply *at* the cursor. The map fills the window, so the places
		you right-click include its corners, and a menu that hangs off the
		bottom right is unusable exactly where the city is most interesting.
	**/
	public function open( at:Point, limitX:Float, limitY:Float ):Void {
		everOpened = true;

		var w = panel.width;
		var h = panel.height;

		panel.x = Math.max( 0, Math.min( at.x, limitX - w ) );
		panel.y = Math.max( 0, Math.min( at.y, limitY - h ) );

		var g = shade.graphics;
		g.clear();
		g.beginFill( 0, 0 );
		g.drawRect( 0, 0, limitX, limitY );
		g.endFill();

		// The map is not being pointed at while this is up, even though the
		// cursor is still over it.
		Tooltip.blocked = true;

		visible = true;
	}

	public function close():Void {
		visible = false;
		Tooltip.blocked = false;
	}

	public var isOpen(get,never) : Bool;
	inline function get_isOpen():Bool
		return visible;
}
