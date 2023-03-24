/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: 
*/

model main

global {
	/** Insert the global definitions, variables and actions here */
	file itp_elevation <-  image_file("../images/elevation.tif");
	file road_shapefile <- file("../includes/itp_road.shp");
	file river_shapefile <- file("../includes/Channel_4.shp");
	//file climate_data <- file("../includes/ITP_climate_data_complete.shp"); 
	
	geometry shape <- envelope(itp_elevation);
	
	init{
		create river from: river_shapefile;
		create road from: road_shapefile;
		
		
	}

}

grid parcel neighbors: 8 parallel: true {
	//rgb color <- #lightblue;
	
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
		display "ITP"{  
			grid parcel border: #black;
			species road aspect: default;
			species river aspect: default;
			//image file("../images/elevation.tif") refresh: false;	
		}
	}
}
