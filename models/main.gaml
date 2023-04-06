/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: waterflow from "Waterflow Field Elevation.gaml"
*/

model main

global {
	/** Insert the global definitions, variables and actions here */
	file elev_file <- file("../images/ITP_Reprojected_Filled.tif"); 
	file dem_file <- file("../images/ITP_colored_100.tif");
	file road_shapefile <- file("../includes/itp_road.shp");	
	file river_shapefile <- file("../includes/Channel_4.shp");
	file Precip_Average <- file("../includes/ITP_climate_reprojected.shp");
	
	graph road_network;
	graph river_network;
	
	field elev <- field(elev_file);
	field flow <- field(dem_file)+400;
	
	geometry shape <- envelope(elev_file);
	bool fill <- true;

	//Diffusion rate
	float diffusion_rate <- 0.6;
	list<point> drain_cells <- [];
	list<point> source_cells <- [];
	list<point> points <- elev points_in shape;
	map<point, list<point>> neighbors <- points as_map (each::(elev neighbors_of each));
	map<point, bool> done <- points as_map (each::false);
	map<point, float> h <- points as_map (each::flow[each]);
	float input_water;
	list<geometry> clean_lines;
	
	list<list<point>> connected_components ;
	list<rgb> colors;
	
	init {
		create climate from: Precip_Average;
		
		//clean_network(road_shapefile.contents,tolerance,split_lines,reduce_to_main_connected_components
		
		clean_lines <- clean_network(road_shapefile.contents,50.0,true,true);
		create road from: clean_lines;
		road_network <- as_edge_graph(road);	//create road from the clean lines
		
		//clean data, with the given options
		clean_lines <- clean_network(river_shapefile.contents,3.0,true,false);
		//create river from the clean lines
		create river from: clean_lines with: 
				[
					node_id::int(read("NODE_A")), 
					drain_node::int(read("NODE_B")), 
					basin::int(read("BASIN"))
				];		
		river_network <- as_edge_graph(river);
		
		//computed the connected components of the graph (for visualization purpose)
		connected_components <- list<list<point>>(connected_components_of(river_network));
		loop times: length(connected_components) {colors << rnd_color(255);}

		write ("Elev min height: "+min(h)+" max height: "+max(h));
		write ("Flow min height: "+min(h)+" max height: "+max(h));

		if (fill) {
			ask river{
				loop pp over: my_rcells{
					flow[pp] <- flow[pp] + 50.0;
				}	
			}
			
			loop pp over: points where (height(each) > 800){
				//write "Point: "+pp+" Height: "+height(pp);
				//flow[pp] <- flow[pp]+1.0;
			}
			
			//initial water content of the cells
			loop pp over: points where (height(each) > 800){
				if(height(pp) < 1150){			//more water on lowest point in the topography
					flow[pp] <- flow[pp]+100.0;	
				}//else{
				//	flow[pp] <- flow[pp]+1.0;	//initial water level
				//}
			}
			
			//add water on lowest point in the topography
			//loop pp over: points where (height(each) < 400 and height(each) > 0){
			//	flow[pp] <- flow[pp]+100.0;
			//}
		}

		loop i from: 0 to: elev.columns - 1 {
			if (elev[i, 0] < 255) {
				source_cells <<+ flow points_in (elev cell_at (i, 0));
			}
			if (elev[i, elev.rows - 1] < 0) {
				drain_cells <<+ flow points_in (elev cell_at (i, elev.rows - 1));
			}
		}
		source_cells <- remove_duplicates(source_cells);
		drain_cells <- remove_duplicates(drain_cells);
		
		write "source cells: "+length(source_cells);
		write "drain cells: "+length(drain_cells);
		
		//write "bands: "+length(elev.bands);
	}

	float height (point c) {
		return h[c] + flow[c];
	}
	
 
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
		//draw display_shape color: #red depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+200]};//200
		draw display_shape color: #red depth: 3.0;// at: {location.x,location.y,location.z} 200
	}
}
//Species to represent the roads
species road {
	geometry display_shape <- shape + 5.0;
	aspect default {
		//draw display_shape color: #black depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+250]};//250
		draw display_shape color: #black;// depth: 3.0 at: {location.x,location.y,location.z};//200
	}
}

species river {
	geometry display_shape <- shape + 5.0;
	list<point> my_rcells <- list<point>(flow points_in display_shape);
	int node_id; 
	int drain_node;
	int basin;
	
	aspect default {
		//draw display_shape color: #blue depth: 3 at: {location.x,location.y,terrain[point(location.x, location.y)]+250};//250
		draw display_shape color: #blue;// at: {location.x,location.y,location.z};//200
	}
	
}

experiment main type: gui {
//	parameter "Input water at source" var: input_water <- 1.0;
//	parameter "Fill the river" var: fill <- true;
	/** Insert here the definition of the input and output of the model */
	
	output {
		layout #split;
		display ITP type: opengl camera:#isometric{ 
			species climate aspect: default;
			species road aspect: default;
			species river aspect: default;			
			mesh elev scale: 2 color: palette([#white, #saddlebrown, #darkgreen]) refresh: true triangulation: true;
			mesh flow scale: 1 triangulation: true color: palette(reverse(brewer_colors("Blues"))) transparency: 0.75 no_data:400 ; 
			
			graphics "connected components" {
				loop i from: 0 to: length(connected_components) - 1 {
					loop j from: 0 to: length(connected_components[i]) - 1 {
						draw cross(25) color: colors[i] at: connected_components[i][j];	
					}
				}
			}
		}
	}
}
