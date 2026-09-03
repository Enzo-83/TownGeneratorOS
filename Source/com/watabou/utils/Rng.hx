package com.watabou.utils;

/**
	`Random`'s generator, with its own state.

	⛔ **This exists so that a feature can be random without being part of the
	city's sequence.** Every patch, street, ward and building comes out of the
	one static `Random` in order, so a single extra draw from it shifts all of
	them and every seed anyone has already chosen produces a different city.
	Anything added after the fact — the river is the first — takes a stream of
	its own, seeded from the city's seed so it is still reproducible, and the
	city itself is left exactly as it was.
**/
class Rng {

	static inline var g = 48271.0;
	static inline var n = 2147483647;

	var state : Int;

	public function new( seed:Int )
		state = (seed > 0 ? seed : 1);

	inline function next():Int
		return (state = Std.int( (state * g) % n ));

	public inline function float():Float
		return next() / n;

	public inline function bool( chance = 0.5 ):Bool
		return float() < chance;

	public inline function int( min:Int, max:Int ):Int
		return Std.int( min + next() / n * (max - min) );
}
