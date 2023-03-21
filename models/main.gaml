/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: 
*/

model main

global {
	/** Insert the global definitions, variables and actions here */
	
	matrix<float> elevation_matrix <-  matrix<float>(image_file( "../images/ITP_Reprojected_Filled.tif") as_matrix {300, 300});
	init {
		elevation_matrix <- elevation_matrix * (30 / (min(elevation_matrix)-max(elevation_matrix)));
		ask elevation {
			grid_value <- elevation_matrix at {grid_x, grid_y};
		}
	}

	/*field itp_display <-  field(grid_file("../images/ITP_Reprojected_Filled.tif"));
	file road_shapefile <- file("../includes/itp_road.shp");
	
	geometry shape <- envelope(road_shapefile);
	
	init{
		//Initialization of the road using the shapefile of roads
		create road from: road_shapefile;
	}*/

}

grid elevation  width: 300 height: 300;

//Species to represent the roads
species road {
	aspect default {
		draw shape color: #red;
	} 

}

experiment main type: gui {
	/** Insert here the definition of the input and output of the model */
	list<rgb> palette <- palette([#white, #darkgreen]);
	output {
		display "ITP through mesh" type:opengl {
			grid elevation elevation: elevation_matrix texture: image_file( "../images/ITP_Reprojected_Filled.tif") triangulation: true refresh: false;
			species road;  
			
			//species road ;
			//mesh itp_display grayscale: true scale: 0.05 triangulation: true smooth: true refresh: false;
		}
	}
}
