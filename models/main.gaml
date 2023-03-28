/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: 
*/

model main

global {
	/** Insert the global definitions, variables and actions here */
	grid_file grid_data <- grid_file("../images/elevation.tif");
	file road_shapefile <- file("../includes/itp_road.shp");	
	file river_shapefile <- file("../includes/Channel_4.shp");
	file Precip_Average <- file("../includes/ITP_climate_data_complete.shp", true);
	
	geometry shape <- envelope(grid_data);
	
	field elevation <- field(grid_data);			
	field water_available <- field(elevation.columns, elevation.rows, 0.0);
	list<point> points <- list<point>(water_available cells_in shape);

	init{
		create climate from: Precip_Average;
		create road from: road_shapefile;
		create river from: river_shapefile;
	} 

}

species climate{
	
}
//Species to represent the roads
species road {
	aspect default {
		draw shape color: #black;
	} 
}

species river {
	aspect default {
		draw shape color: #blue;
	} 
}

experiment main type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display ITP type: opengl{  
			species road aspect: default;
			species river aspect: default;
			mesh elevation grayscale:true scale: 0 refresh: true triangulation: true ;
		}
	}
}
