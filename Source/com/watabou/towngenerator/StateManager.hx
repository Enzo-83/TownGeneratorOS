package com.watabou.towngenerator;

import com.watabou.utils.Random;
import com.watabou.towngenerator.building.CityOptions;
import com.watabou.towngenerator.building.Model;

#if html5
import js.Browser;
import js.html.URLSearchParams;
#end

class StateManager {

	private static inline var SIZE			= "size";
	private static inline var SEED			= "seed";
	private static inline var NAME			= "name";
	private static inline var PLAZA			= "plaza";
	private static inline var CITADEL		= "citadel";
	private static inline var WALLS			= "walls";
	private static inline var INNER_WALL	= "innerwall";
	private static inline var CORE			= "core";
	private static inline var DISTRICTS		= "districts";
	private static inline var LANDMARKS		= "landmarks";

	public static var size	: Int = 15;
	public static var seed	: Int = -1;
	// Empty means "let the generator invent one".
	public static var name	: String = "";

	// Null means "let the generator roll for it".
	public static var plaza		: Null<Bool> = null;
	public static var citadel	: Null<Bool> = null;
	public static var walls		: Null<Bool> = null;

	public static var innerWall	: Bool = false;
	public static var coreSize	: Int = 5;
	// Kept as written so it can be put back in the URL verbatim.
	public static var districts	: String = "";
	// Comma-separated points of interest.
	public static var landmarks	: String = "";

	public static function pullParams() {
		#if html5
		var params = new URLSearchParams( Browser.location.search );
		if (params != null) {
			var size1 = Std.parseInt( params.get( SIZE ) );
			if (size1 != null)size = (size1 >= 6 ? (size1 <= 40 ? size1: 40) : 6);

			var seed1 = Std.parseInt( params.get( SEED ) );
			if (seed1 != null) seed = (seed1 > 0 ? seed1 : -1);

			plaza	= boolParam( params, PLAZA );
			citadel	= boolParam( params, CITADEL );
			walls	= boolParam( params, WALLS );

			var inner1 = boolParam( params, INNER_WALL );
			if (inner1 != null) innerWall = inner1;

			var core1 = Std.parseInt( params.get( CORE ) );
			if (core1 != null) coreSize = (core1 >= 2 ? (core1 <= 30 ? core1 : 30) : 2);

			var districts1 = params.get( DISTRICTS );
			if (districts1 != null) districts = districts1;

			var name1 = params.get( NAME );
			if (name1 != null) name = name1;

			var landmarks1 = params.get( LANDMARKS );
			if (landmarks1 != null) landmarks = landmarks1;
		}
		#end
	}

	#if html5
	private static function boolParam( params:URLSearchParams, name:String ):Null<Bool> {
		var value = params.get( name );
		if (value == null)
			return null;
		return value == "1" || value.toLowerCase() == "true";
	}
	#end

	public static function toOptions():CityOptions {
		var options = new CityOptions();

		options.size		= size;
		options.seed		= seed;
		options.name		= name != "" ? name : null;
		options.plaza		= plaza;
		options.citadel		= citadel;
		options.walls		= walls;
		options.innerWall	= innerWall;
		options.coreSize	= coreSize;
		options.placements	= CityOptions.parsePlacements( districts );
		options.landmarks	= CityOptions.parseLandmarks( landmarks );

		return options;
	}

	/**
		Rebuilds the city from the parameters as they now stand, and puts them
		in the address bar.

		⚠️ **Both halves matter.** The size buttons used to push a fresh seed
		into the URL and then build with `new Model( size )`, which falls back
		to the seed inside the stale `Model.options` — so the address bar
		described a city that was never generated, and reloading it gave you a
		different map. Anything that regenerates goes through here.
	**/
	public static function regenerate():Void {
		pushParams();
		Model.options = toOptions();
		new Model( size, seed );
	}

	public static function pushParams() {
		if (seed == -1) {
			Random.reset();
			seed = Random.getSeed();
		}

		#if html5
		var loc = Browser.location;
		var search1 = loc.search;

		var search2 = '?$SIZE=$size&$SEED=$seed';
		if (plaza != null)		search2 += '&$PLAZA=' + (plaza ? "1" : "0");
		if (citadel != null)	search2 += '&$CITADEL=' + (citadel ? "1" : "0");
		if (walls != null)		search2 += '&$WALLS=' + (walls ? "1" : "0");
		if (innerWall) {
			search2 += '&$INNER_WALL=1';
			search2 += '&$CORE=$coreSize';
		}
		if (districts != "")	search2 += '&$DISTRICTS=' + StringTools.urlEncode( districts );
		if (name != "")			search2 += '&$NAME=' + StringTools.urlEncode( name );
		if (landmarks != "")	search2 += '&$LANDMARKS=' + StringTools.urlEncode( landmarks );

		// The next line is not entirely correct, it doesn't take into account hashes
		var url = search1 != "" ? loc.href.split( search1 ).join( search2 ) : loc.href + search2;
		Browser.window.history.replaceState( {size: size, seed: seed}, getStateName(), url );
		#end
	}

	private static function getStateName():String {
		return if (size >= 6 && size < 10)
			"Small Town"
		else if (size >= 10 && size < 15)
			"Large Town"
		else if (size >= 15 && size <24)
			"Small City"
		else if (size >= 24 && size < 40)
			"Large City"
		else if (size >= 40)
			"Metropilis"
		else
			"Unknown state";
	}
}
