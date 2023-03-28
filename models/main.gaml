/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: 
*/

model main

global {
	/** Insert the global definitions, variables and actions here */
	file dem_file <- file("../images/ITP_Elevation_colored.tif");
	file road_shapefile <- file("../includes/itp_road.shp");	
	file river_shapefile <- file("../includes/Channel_4.shp");
	file Precip_Average <- file("../includes/ITP_climate_reprojected.shp");
	
	geometry shape <- envelope(dem_file);
	field terrain <- field(dem_file) * 1.5;
	
	graph road_network;
	graph river_network;
				
	field water_available <- field(terrain.columns, terrain.rows, 0.0);
	list<point> points <- list<point>(water_available cells_in shape);

	init{
		create climate from: Precip_Average;
		create road from: road_shapefile;
		road_network <- as_edge_graph(road);
		create river from: river_shapefile;
		river_network <- as_edge_graph(river);
		
		write "Columns: "+terrain.columns+" Rows: "+terrain.rows;
	}

}

species climate{
	geometry display_shape <- shape + 50.0;
	aspect default{
		draw display_shape color: #red depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+200]};
	}
}
//Species to represent the roads
species road {
	geometry display_shape <- shape + 2.0;
	aspect default {
		draw display_shape color: #black depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+250]};
	}
}

species river {
	list<point> my_rcells <- list<point>(water_available cells_overlapping shape);
	geometry display_shape <- shape + 2.0;
	
	aspect default {
		draw display_shape color: #blue depth: 3 at: {location.x,location.y,terrain[point(location.x, location.y)]+250};
	}
}

experiment main type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display ITP type: opengl{  
			species climate aspect: default;
			species road aspect: default;
			species river aspect: default;			
			mesh terrain scale: 3 triangulation: true  color: palette([#white, #saddlebrown, #darkgreen, #green]) refresh: false smooth: true;
			//mesh terrain color: terrain.bands refresh: false triangulation: true smooth: true;
			//mesh elevation grayscale:true scale: 0 refresh: true triangulation: true ;
		}
	}
}
