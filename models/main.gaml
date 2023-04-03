/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: waterflow from "Waterflow Field Elevation.gaml"
*/

model main

global {
	/** Insert the global definitions, variables and actions here */
	file dem_file <- file("../images/ITP_Elevation_resampled100.tif");
	file road_shapefile <- file("../includes/itp_road.shp");	
	file river_shapefile <- file("../includes/Channel_4.shp");
	file Precip_Average <- file("../includes/ITP_climate_reprojected.shp");
	
	graph road_network;
	graph river_network;
	
	field terrain <- field(dem_file);
	field flow <- field(terrain.columns,terrain.rows);
	
	geometry shape <- envelope(dem_file);
	bool fill <- true;

	//Diffusion rate
	float diffusion_rate <- 0.6;
	list<point> drain_cells <- [];
	list<point> source_cells <- [];
	list<point> points <- flow points_in shape;
	map<point, list<point>> neighbors <- points as_map (each::(terrain neighbors_of each));
	map<point, bool> done <- points as_map (each::false);
	map<point, float> h <- points as_map (each::terrain[each]);
	float input_water;

	

	init {
		//create climate from: Precip_Average;
		//create road from: road_shapefile;
		//road_network <- as_edge_graph(road);
		//create river from: river_shapefile;
		//river_network <- as_edge_graph(river);
		
		//write "Columns: "+terrain.columns+" Rows: "+terrain.rows;

		if (fill) {
			loop pp over: points where (height(each) < 360 and height(each) > 200){
				flow[pp] <- 3.0;
			}	
		}

		loop i from: 0 to: terrain.columns - 1 {
			write "i,0: "+terrain[i,0]+" i,-1: "+ terrain[i, terrain.rows - 1];
			if (terrain[i, 0] < 450) {
				source_cells <<+ flow points_in (terrain cell_at (i, 0));
			}
			if (terrain[i, terrain.rows - 1] < 250) {
				drain_cells <<+ flow points_in (terrain cell_at (i, terrain.rows - 1));
			}
		}
		source_cells <- remove_duplicates(source_cells);
		drain_cells <- remove_duplicates(drain_cells);
		
		write "source cells: "+length(source_cells);
		write "drain cells: "+length(drain_cells);
	}

/* */
	//Reflex to add water among the water cells
	reflex adding_input_water {
		loop p over: source_cells {
			flow[p] <- flow[p] + input_water;
		}
	}

	//Reflex for the drain cells to drain water
	reflex draining  {
		loop p over: drain_cells {
			flow[p] <- 0.0;
		}
	}


	float height (point c) {
		return h[c] + flow[c];
	}

	//Reflex to flow the water according to the altitude and the obstacle
	reflex flowing {
		done[] <- false;
		list<point> water <- points where (flow[each] > 0) sort_by (height(each));
		loop p over: points - water {
			done[p] <- true;
		}
		loop p over: water {
			float height <- height(p);
			loop flow_cell over: neighbors[p] where (done[each] and height > height(each)) {
				float water_flowing <- max(0.0, min((height - height(flow_cell)), flow[p] * diffusion_rate));
				flow[p] <- flow[p] - water_flowing;
				flow[flow_cell] <- flow[flow_cell] + water_flowing;
			}
		done[p] <- true;
		}
	}

}

species climate{
	geometry display_shape <- shape + 50.0;
	aspect default{
		draw display_shape color: #red depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+200]};//200
	}
}
//Species to represent the roads
species road {
	geometry display_shape <- shape + 2.0;
	aspect default {
		draw display_shape color: #black depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+250]};//250
	}
}

species river {
	list<point> my_rcells <- list<point>(flow cells_overlapping shape);
	geometry display_shape <- shape + 2.0;
	
	aspect default {
		draw display_shape color: #blue depth: 3 at: {location.x,location.y,terrain[point(location.x, location.y)]+250};//250
	}
}

experiment main type: gui {
	parameter "Input water at source" var: input_water <- 1.0;
	parameter "Fill the river" var: fill <- true;
	/** Insert here the definition of the input and output of the model */
	output {
		display ITP type: opengl camera:#isometric{  
			species climate aspect: default;
			species road aspect: default;
			species river aspect: default;			
			//mesh terrain scale: 3 triangulation: true  color: palette([#white, #saddlebrown, #darkgreen, #green]) refresh: false smooth: true;
			//mesh terrain color: terrain.bands refresh: false triangulation: true smooth: true;
			mesh terrain grayscale:true refresh: true triangulation: true ;
			mesh flow scale: 3 triangulation: true color: palette(reverse(brewer_colors("Blues"))) transparency: 0.5 no_data:0.0 ;
		}
	}
}
