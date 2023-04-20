/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: waterwater_content from "Waterwater_content Field Elevation.gaml"
*/

model main

global {
	int NB_TS <- 12; //monthly timestep, constant
	
	/** Insert the global definitions, variables and actions here */
	file elev_file <- file("../images/ITP_Reprojected_Filled.tif"); //resolution 30m-by-30m
	file dem_file <- file("../images/ITP_colored_100.tif");		//resolution 100m-by-100m
	file road_shapefile <- file("../includes/Itp_Road.shp");	
	file river_shapefile <- file("../includes/River_Channel.shp");
	file Precip_TAverage <- file("../includes/Monthly_Climate.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm, total mm of ET0 per month
	file Soil_Group <- file("../includes/Soil_Group.shp");
	
	graph road_network;
	graph river_network;
	
	field elev <- field(elev_file);
	field water_content <- field(dem_file)+400;
	field water_before_runoff <- field(water_content.columns, water_content.rows, 0.0);	// Ia
	field remaining_precip <- field(water_content.columns, water_content.rows, 0.0);	// RP in mm
	field inflow <- field(water_content.columns, water_content.rows, 0.0);	// RP
	
	geometry shape <- envelope(elev_file);
	bool fill <- true;

	map<point, climate> cell_climate;
	
	//Diffusion rate
	list<point> points <- water_content points_in shape; //elev
	map<point, list<point>> neighbors <- points as_map (each::(water_content neighbors_of each));
	map<point, bool> done <- points as_map (each::false);
	map<point, float> h <- points as_map (each::water_content[each]);
	float input_water;
	list<geometry> clean_lines;
	list<point> drain_cells <- [];
	
	list<list<point>> connected_components ;
	list<rgb> colors;
	
	int current_month <- 0 update:(cycle mod NB_TS);
	
	init {
		create climate from: Precip_TAverage with: 
		[
			temperature::[float(get("1_TAvg")),float(get("2_TAvg")),float(get("3_TAvg")),float(get("4_TAvg")),float(get("5_TAvg")),float(get("6_TAvg")),float(get("7_TAvg")),float(get("8_TAvg")),float(get("9_TAvg")),float(get("10_TAvg")),float(get("11_TAvg")),float(get("12_TAvg"))],
			precipitation::[float(get("1_Prec")),float(get("2_Prec")),float(get("3_Prec")),float(get("4_Prec")),float(get("5_Prec")),float(get("6_Prec")),float(get("7_Prec")),float(get("8_Prec")),float(get("9_Prec")),float(get("10_Prec")),float(get("11_Prec")),float(get("12_Prec"))],
			etp::[float(get("1_ETP")),float(get("2_ETP")),float(get("3_ETP")),float(get("4_ETP")),float(get("5_ETP")),float(get("6_ETP")),float(get("7_ETP")),float(get("8_ETP")),float(get("9_ETP")),float(get("10_ETP")),float(get("11_ETP")),float(get("12_ETP"))]
		];
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
		
		//Identify drain cells
		write "Before Drain cells count: "+length(drain_cells)+" Lowest Elev: "+min(elev) + " Lowest water: "+min(water_content);
		loop pp over: points where (water_content[each]>400){	//look inside the area of concern, less than 400 means not part of concern
			list<point> edge_points <- neighbors[pp] where (water_content[each] = 400);
			if(length(edge_points) > 1){
				drain_cells <+ pp;	
			}	
		}
		drain_cells <- remove_duplicates(drain_cells);
		float min_height <- drain_cells min_of (water_content[each]);
		
		drain_cells <- drain_cells where (water_content[each] < min_height+10);
		//get the Top 10 drain cells with minimum elevation 
		write "After Drain cells count: "+length(drain_cells)+" length of points: "+length(points where (elev[each] < 0));

		//Determine initial amount of water
		loop pp over: points where (water_content[each] > 400){
			soil closest_soil <- soil closest_to pp;	//closest soil descriptor to the point
			water_content[pp] <- water_content[pp] + (0.2 * closest_soil.S);
			water_before_runoff[pp] <- 0.2 * closest_soil.S;	//Ia
		}
	}
	
	//base on the current month, add precipitation
	reflex adding_precipitation{
		write "Current month: "+current_month;
		
		//Determine initial amount of water
		loop pp over: points where (water_content[each] > 400){
			climate closest_clim <- climate closest_to pp;	//closest climate descriptor to the point
			float precip_value <- closest_clim.precipitation[current_month];
			float etp_value <- closest_clim.etp[current_month];
			
			remaining_precip[pp] <- (precip_value - etp_value > 0)? precip_value - etp_value : 0;
		}
	}
	
	//sort pixel based on elevation
	//from highest elevation pixel down
	//	add inflow to remaining_precip
	//	determine if there will be a runoff: RP > Ia
	//		yes: compute for Q, where Q = (RP-Ia)^2 / ((RP-Ia+S) 
	//  subtract runoff from remaining_precip, Ia = RP - Q w
	//  distribute runoff to lower elevation neighbors (add to neighbor's inflow)
	reflex water_flow{
		done[] <- false;
		list<point> water <- points where (water_content[each] > 400) sort_by (elev[each]);
		loop p over: points - water {
			done[p] <- true;
		}
		loop p over: water {
			soil closest_soil <- soil closest_to p;	//closest soil descriptor to the point
			remaining_precip[p] <- remaining_precip[p] + inflow[p];	//add inflow
			inflow[p] <- 0;	//set inflow back to 0
			
			//determine if there will be a runoff
			if(remaining_precip[p] > water_before_runoff[p]){	//there will be runoff
				//compute for Q, where Q = (RP-Ia)^2 / ((RP-Ia+S)
				float Q <- ((remaining_precip[p] - water_before_runoff[p])^2)/(remaining_precip[p] - water_before_runoff[p]+closest_soil.S);
				
				//subtract runoff from remaining_precip
				water_before_runoff[p] <- (remaining_precip[p] - Q);	//in mm
				write "WBF: "+water_before_runoff[p];
				
				//distribute runoff to lower elevation neighbors (add to neighbor's inflow)
				float height <- elev[p];
				list<point> downflow_neighbors <- neighbors[p] where (!done[each] and height > elev[each]);
				int neighbor_count <- length(downflow_neighbors); 
				loop pp over: downflow_neighbors{
					inflow[pp] <- inflow[pp] + (Q/neighbor_count);
				}
			}
			done[p] <- true;
		}
	}
	
	reflex water_viz{
		loop pp over: points where (water_content[each] > 0){
			water_content[pp] <- water_before_runoff[pp] + 400;
		}
	}

	reflex drain_cells{
		loop pp over: drain_cells{
			water_content[pp] <- 0;
			water_before_runoff[pp] <- 0;
		}
	}
}

species soil{
	float S; //potential maximum soil moisture 
	int curve_number; 
	int id;
	
	geometry display_shape <- shape + 50.0;
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
	list<float> temperature;						
	list<float> precipitation;
	list<float> etp;
	
	geometry display_shape <- shape + 50.0;
	aspect default{
		//draw display_shape color: #red depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+200]};//200
		draw display_shape color: #yellow depth: 3.0;// at: {location.x,location.y,location.z} 200
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
			species soil aspect: default;
			species climate aspect: default;
			species river aspect: default;	
			species road aspect: default;					
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
