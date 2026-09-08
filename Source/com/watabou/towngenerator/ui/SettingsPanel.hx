package com.watabou.towngenerator.ui;

import com.watabou.towngenerator.building.CityOptions;
import com.watabou.towngenerator.mapping.CityMap;

#if html5
import js.Browser;
import js.html.DivElement;
import js.html.Element;
import js.html.InputElement;
import js.html.KeyboardEvent;
import js.html.TextAreaElement;
#end

/**
	The parameters, as a form.

	Everything here can be typed into the address bar instead, and the address
	bar is still the save format — this writes back through
	`StateManager.regenerate`, so a map is always a URL you can keep. But the
	two list parameters are long, structured and full of colons, and editing
	`districts=market:between:The Velvet Road,…` in a browser's address bar is
	miserable in a way the toggles are not. That is what this is for; the
	booleans stay on the right-click menu, where one click is already less work
	than a form.

	> ⚠️ **Built out of DOM elements rather than drawn in the canvas.** This is
	> a web app — `js.Browser` is already used for the URL and the export
	> blobs. A real `<textarea>` brings selection, keyboard navigation,
	> undo and copy-paste with it; OpenFL has an editable `TextField` and none
	> of the rest, so the same panel drawn in the canvas would be many times
	> the work and still behave worse. Nothing here touches `CityMap`, so the
	> exports are unaffected — the panel cannot appear in a PNG.
**/
class SettingsPanel {

#if html5

	static var root		: DivElement;
	static var apply	: Void->Void;

	static var fName	: InputElement;
	static var fSeed	: InputElement;
	static var fSize	: InputElement;
	static var fCore	: InputElement;
	static var fDistricts	: TextAreaElement;
	static var fLandmarks	: TextAreaElement;

	public static var isOpen(get,never) : Bool;
	static function get_isOpen():Bool
		return root != null;

	public static function open( onApply:Void->Void ):Void {
		if (root != null)
			return;

		apply = onApply;
		build();

		// Capture phase, so this runs before the bubble-phase listener lime
		// puts on the same window. See `swallow`.
		Browser.window.addEventListener( "keydown", swallow, true );
	}

	public static function close():Void {
		if (root == null)
			return;

		Browser.window.removeEventListener( "keydown", swallow, true );
		root.remove();
		root = null;
	}

	/**
		⛔ **Keys typed in here must not reach the scene.** OpenFL listens for
		keydown on `window`, and `S` and `P` are the export shortcuts — so
		without this, typing a district name with an "s" in it downloads an
		SVG. Lime registers in the bubble phase; a capture-phase listener on
		the same target runs first and stops the event before it ever arrives.
	**/
	static function swallow( e:KeyboardEvent ):Void {
		if (root == null || !root.contains( cast e.target ))
			return;

		e.stopPropagation();

		if (e.key == "Escape")
			close();
	}

	// ------------------------------------------------------------- building

	static function css( colour:Int ):String
		return "#" + StringTools.hex( colour, 6 );

	static function build():Void {
		var palette = CityMap.palette;
		var ink = css( palette.dark );
		var paper = css( palette.paper );
		var edge = css( palette.medium );

		root = Browser.document.createDivElement();
		root.style.cssText =
			"position:fixed; inset:0; z-index:100;" +
			"display:flex; align-items:center; justify-content:center;" +
			"background:rgba(0,0,0,0.35); font:13px/1.5 Georgia,'Times New Roman',serif;";

		// A click on the backdrop is a dismissal; one inside the panel is not.
		root.addEventListener( "mousedown", function( e ) {
			if (e.target == root)
				close();
		} );

		var panel = Browser.document.createDivElement();
		panel.style.cssText =
			'background:$paper; color:$ink; border:1px solid $edge;' +
			"width:min(680px,92vw); max-height:88vh; overflow:auto;" +
			"padding:18px 20px; box-shadow:0 6px 28px rgba(0,0,0,0.4);";
		root.appendChild( panel );

		var title = Browser.document.createElement( "div" );
		title.textContent = "Settings";
		title.style.cssText = "font-size:20px; margin:0 0 12px;";
		panel.appendChild( title );

		fName	= field( panel, "Name", StateManager.name, "text", "Left blank, the generator invents one" );
		fSeed	= field( panel, "Seed", Std.string( StateManager.seed ), "number", "The whole city, in one number" );
		fSize	= field( panel, "Size", Std.string( StateManager.size ), "number", "6 to 40" );
		fCore	= field( panel, "Core", Std.string( StateManager.coreSize ), "number", "Patches inside the inner ring, 2 to 30" );

		fDistricts	= area( panel, "Districts", StateManager.districts,
			"ward:zone:marker:Name, comma separated — the ward is required, the rest optional" );
		fLandmarks	= area( panel, "Landmarks", StateManager.landmarks,
			"[tokens:]Name, comma separated — a bare name is scattered" );

		panel.appendChild( vocabulary( ink, edge ) );

		var note = Browser.document.createElement( "div" );
		note.innerHTML =
			"Walls, ring, citadel, plaza, river and labels stay on the right-click menu.<br>" +
			"<b>Adding or removing a district or landmark changes the city</b>, even at the " +
			"same seed &mdash; each one is placed out of the same sequence the buildings come from. " +
			"Renaming one does not.";
		note.style.cssText = 'margin:14px 0 0; color:$edge; font-size:12px; line-height:1.6;';
		panel.appendChild( note );

		var row = Browser.document.createDivElement();
		row.style.cssText = "display:flex; gap:8px; justify-content:flex-end; margin-top:16px;";
		row.appendChild( button( "Cancel", false, function() close() ) );
		row.appendChild( button( "Apply", true, submit ) );
		panel.appendChild( row );

		Browser.document.body.appendChild( root );
		fName.focus();
	}

	static function label( parent:Element, text:String, hint:String ):Void {
		var l = Browser.document.createElement( "div" );
		l.textContent = text;
		l.style.cssText = "margin:12px 0 3px; font-weight:bold;";
		parent.appendChild( l );

		if (hint != null) {
			var h = Browser.document.createElement( "div" );
			h.textContent = hint;
			h.style.cssText = 'margin:0 0 4px; font-size:12px; color:${css( CityMap.palette.medium )};';
			parent.appendChild( h );
		}
	}

	static function boxStyle():String {
		var ink = css( CityMap.palette.dark );
		var edge = css( CityMap.palette.medium );
		return 'width:100%; box-sizing:border-box; padding:5px 7px; color:$ink;' +
			'background:#fff; border:1px solid $edge; font:13px/1.4 Consolas,Menlo,monospace;';
	}

	static function field( parent:Element, name:String, value:String, kind:String, hint:String ):InputElement {
		label( parent, name, hint );

		var input = Browser.document.createInputElement();
		input.type = kind;
		input.value = value;
		input.style.cssText = boxStyle();
		parent.appendChild( input );

		return input;
	}

	static function area( parent:Element, name:String, value:String, hint:String ):TextAreaElement {
		label( parent, name, hint );

		var box = Browser.document.createTextAreaElement();
		box.value = value;
		box.rows = 3;
		box.spellcheck = false;
		box.style.cssText = boxStyle() + "resize:vertical;";
		parent.appendChild( box );

		return box;
	}

	/**
		The tokens, read off the maps that define them rather than typed out
		here — a second list would only drift from the first.
	**/
	static function vocabulary( ink:String, edge:String ):Element {
		function names<T>( map:Map<String, T> ):String {
			var out = [for (k in map.keys()) k];
			out.sort( function( a, b ) return a < b ? -1 : (a > b ? 1 : 0) );
			return out.join( "  " );
		}

		var box = Browser.document.createElement( "div" );
		box.style.cssText =
			'margin:16px 0 0; padding:10px 12px; border:1px solid $edge;' +
			"font:12px/1.7 Consolas,Menlo,monospace;";

		box.innerHTML =
			"<b>wards</b> &nbsp;" + names( CityOptions.WARD_TYPES ) + "<br>" +
			"<b>zones</b> &nbsp;" + names( CityOptions.ZONES ) + "<br>" +
			"<b>markers</b> &nbsp;" + names( CityOptions.MARKERS ) + "<br>" +
			"<b>modifier</b> &nbsp;" + CityOptions.BESIDE + " &nbsp;— beside whatever was placed before";

		return box;
	}

	static function button( text:String, primary:Bool, action:Void->Void ):Element {
		var ink = css( CityMap.palette.dark );
		var paper = css( CityMap.palette.paper );
		var edge = css( CityMap.palette.medium );

		var b = Browser.document.createButtonElement();
		b.textContent = text;
		b.style.cssText =
			'padding:6px 16px; cursor:pointer; border:1px solid $edge; font:13px Georgia,serif;' +
			(primary ? 'background:$ink; color:$paper;' : 'background:transparent; color:$ink;');
		b.addEventListener( "click", function( _ ) action() );

		return b;
	}

	// -------------------------------------------------------------- applying

	static function clamp( raw:String, min:Int, max:Int, fallback:Int ):Int {
		var value = Std.parseInt( raw );
		if (value == null)
			return fallback;
		return value < min ? min : (value > max ? max : value);
	}

	static function submit():Void {
		StateManager.name		= StringTools.trim( fName.value );
		StateManager.size		= clamp( fSize.value, 6, 40, StateManager.size );
		StateManager.coreSize	= clamp( fCore.value, 2, 30, StateManager.coreSize );
		StateManager.districts	= StringTools.trim( fDistricts.value );
		StateManager.landmarks	= StringTools.trim( fLandmarks.value );

		// A blank or unreadable seed means "give me a new city", which is what
		// clearing the field obviously ought to do.
		var seed = Std.parseInt( StringTools.trim( fSeed.value ) );
		StateManager.seed = (seed != null && seed > 0) ? seed : -1;

		close();
		apply();
	}

#else

	public static var isOpen(get,never) : Bool;
	static function get_isOpen():Bool
		return false;

	public static function open( onApply:Void->Void ):Void {}

	public static function close():Void {}

#end
}
