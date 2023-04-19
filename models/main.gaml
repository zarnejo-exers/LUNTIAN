/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: waterwater_content from "Waterwater_content Field Elevation.gaml"
*/

model main

global {
	/** Insert the global definitions, variables and actions here */
	file elev_file <- file("../images/ITP_Reprojected_Filled.tif"); //resolution 30m-by-30m
	file dem_file <- file("../images/ITP_colored_100.tif");		//resolution 100m-by-100m
	file road_shapefile <- file("../includes/Itp_Road.shp");	
	file river_shapefile <- file("../includes/River_Channel.shp");
	file Precip_Average <- file("../includes/Monthly_Climate.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm
	file ETO <- file("../includes/Monthly_ETP_Luzon.shp"); //total mm of ET0 per month
	file Soil_Group <- file("../includes/Soil_Group.shp");
	
	graph road_network;
	graph river_network;
	
	field elev <- field(elev_file);
	field water_content <- field(dem_file)+400;
	
	geometry shape <- envelope(elev_file);
	bool fill <- true;

	map<point, climate> cell_climate;
	
	//Diffusion rate
	float diffusion_rate <- 0.6;
	list<point> drain_cells <- [];
	list<point> source_cells <- [];
	list<point> points <- water_content points_in shape; //elev
	map<point, list<point>> neighbors <- points as_map (each::(elev neighbors_of each));
	map<point, bool> done <- points as_map (each::false);
	map<point, float> h <- points as_map (each::water_content[each]);
	float input_water;
	list<geometry> clean_lines;
	
	list<list<point>> connected_components ;
	list<rgb> colors;
	
	init {
		create climate from: Precip_Average;
		create soil from: Soil_Group with: [id::int(get("VALUE"))];
		
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

		//Determine initial amount of water
		loop pp over: points where (water_content[each] > 400){
			soil closest_soil <- soil closest_to pp;	//closest soil descriptor to the point
			water_content[pp] <- water_content[pp] + (0.2 * closest_soil.S);
		}
		
		/* 
		if (fill) {
			ask river{
				loop pp over: my_rcells{
					water_content[pp] <- water_content[pp] + 50.0;
				}	
			}
			
			loop pp over: points where (height(each) > 800){
				//write "Point: "+pp+" Height: "+height(pp);
				//water_content[pp] <- water_content[pp]+1.0;
			}
			
			//initial water content of the cells
			loop pp over: points where (height(each) > 800){
				if(height(pp) < 1150){			//more water on lowest point in the topography
					water_content[pp] <- water_content[pp]+100.0;	
				}//else{
				//	water_content[pp] <- water_content[pp]+1.0;	//initial water level
				//}
			}
			
			//add water on lowest point in the topography
			//loop pp over: points where (height(each) < 400 and height(each) > 0){
			//	water_content[pp] <- water_content[pp]+100.0;
			//}
		}

		loop i from: 0 to: elev.columns - 1 {
			if (elev[i, 0] < 255) {
				source_cells <<+ water_content points_in (elev cell_at (i, 0));
			}
			if (elev[i, elev.rows - 1] < 0) {
				drain_cells <<+ water_content points_in (elev cell_at (i, elev.rows - 1));
			}
		}
		source_cells <- remove_duplicates(source_cells);
		drain_cells <- remove_duplicates(drain_cells);
		*/
	}

	/* 
	float height (point c) {
		return h[c] + water_content[c];
	}
	
 
	//Reflex to add water among the water cells
	reflex adding_input_water {
		loop p over: source_cells {
			water_content[p] <- water_content[p] + input_water;
		}
	}

	//Reflex for the drain cells to drain water
	reflex draining  {
		loop p over: drain_cells {
			water_content[p] <- 0.0;
		}
	}

	//Reflex to water_content the water according to the altitude and the obstacle
	reflex water_contenting {
		done[] <- false;
		list<point> water <- points where (water_content[each] > 0) sort_by (height(each));
		loop p over: points - water {
			done[p] <- true;
		}
		loop p over: water {
			float height <- height(p);
			loop water_content_cell over: neighbors[p] where (done[each] and height > height(each)) {
				float water_water_contenting <- max(0.0, min((height - height(water_content_cell)), water_content[p] * diffusion_rate));
				water_content[p] <- water_content[p] - water_water_contenting;
				water_content[water_content_cell] <- water_content[water_content_cell] + water_water_contenting;
			}
		done[p] <- true;
		}
	}
	
	*/

}

species soil{
	geometry display_shape <- shape + 50.0;
	float S; //potential maximum soil moisture 
	int curve_number; 
	int id;
	
	aspect default{
		//draw display_shape color: #red depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+200]};//200
		draw display_shape color: #brown depth: 3.0;// at: {location.x,location.y,location.z} 200
	}
	
	init{
		curve_number <- (id = 3)? 70: 77;	//see https://engineering.purdue.edu/mapserve/LTHIA7/documentation/scs.htm
		S <- (1000/curve_number) - 10;
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
	list<point> my_rcells <- list<point>(water_content points_in display_shape);
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
			mesh water_content scale: 1 triangulation: true color: palette(reverse(brewer_colors("Blues"))) transparency: 0.75 no_data:400 ; 
			
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
