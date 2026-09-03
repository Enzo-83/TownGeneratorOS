package com.watabou.towngenerator.mapping;

import openfl.display.Shape;
import openfl.display.CapsStyle;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.geom.Point;

import com.watabou.geom.Polygon;

import com.watabou.towngenerator.wards.*;
import com.watabou.towngenerator.building.CurtainWall;
import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.building.River;

using com.watabou.utils.ArrayExtender;
using com.watabou.utils.GraphicsExtender;
using com.watabou.utils.PointExtender;

class CityMap extends Sprite {

	public static var palette = Palette.DEFAULT;

	private var patches	: Array<PatchView>;

	private var brush	: Brush;

	public function new( model:Model ) {
		super();

		brush = new Brush( palette );

		var model = Model.instance;

		// First, so everything else is drawn over it: a road that crosses the
		// water reads as crossing it, and the buildings the river cleared are
		// simply not there to draw.
		if (model.river != null)
			drawRiver( model.river );

		for (road in model.roads) {
			var roadView = new Shape();
			drawRoad( roadView.graphics, road );
			addChild( roadView );
		}

		patches = [];
		for (patch in model.patches) {
			var patchView = new PatchView( patch );
			var patchDrawn = true;

			var g = patchView.graphics;
			switch (Type.getClass( patch.ward )) {
				case Castle:
					drawBuilding( g, patch.ward.geometry, palette.light, palette.dark, Brush.NORMAL_STROKE * 2 );
				case Cathedral:
					drawBuilding( g, patch.ward.geometry, palette.light, palette.dark, Brush.NORMAL_STROKE );
				case Market, CraftsmenWard, MerchantWard, GateWard, Slum, AdministrationWard, MilitaryWard, PatriciateWard, Farm:
					brush.setColor( g, palette.light, palette.dark );
					for (building in patch.ward.geometry)
						g.drawPolygon( building );
				case Park:
					brush.setColor( g, palette.medium );
					for (grove in patch.ward.geometry)
						g.drawPolygon( grove );
				default:
					patchDrawn = false;
			}

			patches.push( patchView );
			if (patchDrawn)
				addChild( patchView );
		}

		for (patch in patches)
			addChild( patch.hotArea );

		var walls = new Shape();
		addChild( walls );

		if (model.innerWall != null)
			drawInnerWall( walls.graphics, model.innerWall );

		if (model.wall != null)
			drawWall( walls.graphics, model.wall, false );

		if (model.citadel != null)
			drawWall( walls.graphics, cast( model.citadel.ward, Castle).wall, true );

		// After the walls, since a bridge carries a road over the water and a
		// wall crossing it is only a water gate.
		if (model.river != null)
			drawBridges( walls.graphics, model.river );

		// The bar first, so its caption — which arrives with the labels —
		// is drawn over it rather than under.
		addScaleBar( model );
		addLabels( model );
	}

	/**
		District names, landmark markers, and the settlement's own name above
		the map. Labels sit above everything else so a street never runs
		through a word.

		Where each one goes is `LabelPlan`'s decision, not this class's — the
		SVG exporter reads the same plan, which is what keeps the two from
		disagreeing about which labels a map has.
	**/
	private function addLabels( model:Model ):Void {
		var plan = LabelPlan.build( model );

		var markers = new Sprite();
		markers.mouseEnabled = false;
		addChild( markers );

		var mg = markers.graphics;
		mg.beginFill( palette.dark );
		for (marker in plan.markers)
			mg.drawCircle( marker.at.x, marker.at.y, marker.r );
		mg.endFill();

		var labels = new Sprite();
		labels.mouseEnabled = false;
		labels.mouseChildren = false;
		addChild( labels );

		for (label in plan.labels)
			labels.addChild( LabelView.render(
				label.text, label.at, label.angle, label.size, palette.dark, palette.paper ) );
	}

	public static function thousands( n:Int ):String {
		var s = Std.string( n );
		var out = "";
		var count = 0;
		var i = s.length - 1;
		while (i >= 0) {
			out = s.charAt( i ) + out;
			if (++count % 3 == 0 && i > 0)
				out = "," + out;
			i--;
		}
		return out;
	}

	/**
		The scale bar's rules. Its caption is a label, and comes with the rest
		of them from `LabelPlan`.
	**/
	private function addScaleBar( model:Model ):Void {
		var s = LabelPlan.scaleBar( model );

		var bar = new Sprite();
		bar.mouseEnabled = false;
		var g = bar.graphics;

		g.lineStyle( Brush.NORMAL_STROKE * 1.5, palette.dark );
		g.moveTo( s.x, s.y );
		g.lineTo( s.x + s.length, s.y );
		g.moveTo( s.x, s.y - s.tick );
		g.lineTo( s.x, s.y + s.tick );
		g.moveTo( s.x + s.length, s.y - s.tick );
		g.lineTo( s.x + s.length, s.y + s.tick );
		// Midpoint, so the bar can be read at half its length too.
		g.moveTo( s.x + s.length / 2, s.y );
		g.lineTo( s.x + s.length / 2, s.y + s.tick );

		addChild( bar );
	}

	/**
		The water: a band in the middle tone with its banks drawn, which tells
		it apart from a park (no outline) and from a road (paper down the
		middle).
	**/
	private function drawRiver( river:River ):Void {
		var water = new Shape();
		var g = water.graphics;

		g.lineStyle( Brush.NORMAL_STROKE, palette.dark );
		g.beginFill( palette.medium );
		g.drawPolygon( river.banks );
		g.endFill();

		addChild( water );
	}

	/**
		A bridge, drawn the way a road is: a dark casing with the paper colour
		down the middle, so the deck reads as continuous with the road either
		side of it.
	**/
	private function drawBridges( g:Graphics, river:River ):Void {
		var span = river.width * 0.8;

		for (bridge in river.bridges) {
			var half = bridge.dir.norm( span );
			var from = bridge.at.subtract( half );
			var to = bridge.at.add( half );

			g.lineStyle( Ward.MAIN_STREET + Brush.NORMAL_STROKE * 3, palette.dark, false, null, CapsStyle.NONE );
			g.moveToPoint( from );
			g.lineToPoint( to );

			g.lineStyle( Ward.MAIN_STREET, palette.paper, false, null, CapsStyle.NONE );
			g.moveToPoint( from );
			g.lineToPoint( to );
		}
	}

	private function drawRoad( g:Graphics, road:Street ):Void {
		g.lineStyle( Ward.MAIN_STREET + Brush.NORMAL_STROKE, palette.medium, false, null, CapsStyle.NONE );
		g.drawPolyline( road );

		g.lineStyle( Ward.MAIN_STREET - Brush.NORMAL_STROKE, palette.paper );
		g.drawPolyline( road );
	}

	private function drawWall( g:Graphics, wall:CurtainWall, large:Bool ):Void {
		g.lineStyle( Brush.THICK_STROKE, palette.dark );
		g.drawPolygon( wall.shape );

		for (gate in wall.gates)
			drawGate( g, wall.shape, gate );

		for (t in wall.towers)
			drawTower( g, t, Brush.THICK_STROKE * (large ? 1.5 : 1) );
	}

	/**
		The inner ring, drawn as what it is: a boundary rather than a defence.
		Thinner than the curtain wall, no towers, and left open at its gates —
		it marks where the city ends, it does not hold the line there.
	**/
	private function drawInnerWall( g:Graphics, wall:CurtainWall ):Void {
		g.lineStyle( Brush.NORMAL_STROKE * 1.5, palette.dark );

		var len = wall.shape.length;
		for (i in 0...len) {
			var v0 = wall.shape[i];
			var v1 = wall.shape[(i + 1) % len];

			if (wall.gates.contains( v0 ) || wall.gates.contains( v1 ))
				continue;

			g.moveToPoint( v0 );
			g.lineToPoint( v1 );
		}
	}

	private function drawTower( g:Graphics, p:Point, r:Float ) {
		brush.noStroke( g );
		g.beginFill( palette.dark );
		g.drawCircle( p.x, p.y, r );
		g.endFill();
	}

	private function drawGate( g:Graphics, wall:Polygon, gate:Point ) {
		g.lineStyle( Brush.THICK_STROKE * 2, palette.dark, false, null, CapsStyle.NONE );

		var dir = wall.next( gate ).subtract( wall.prev( gate ) );
		dir.normalize( Brush.THICK_STROKE * 1.5 );
		g.moveToPoint( gate.subtract( dir ) );
		g.lineToPoint( gate.add( dir ) );
	}

	private function drawBuilding( g:Graphics, blocks:Array<Polygon>, fill:Int, line:Int, thickness:Float ):Void {
		brush.setStroke( g, line, thickness * 2 );
		for (block in blocks) {
			g.drawPolygon( block );
		}

		brush.noStroke( g );
		brush.setFill( g, fill );
		for (block in blocks) {
			g.drawPolygon( block );
		}
	}
}