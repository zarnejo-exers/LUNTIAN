/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Tags: waterwater_content from "Waterwater_content Field Elevation.gaml"
*/

model llg
import "actors.gaml"

global {
	int NB_TS <- 12; //monthly timestep, constant
	
	/** Insert the global definitions, variables and actions here */
	file elev_file <- file("../images/ITP_Reprojected_Filled.tif"); //resolution 30m-by-30m
	file dem_file <- file("../images/ITP_colored_100.tif");		//resolution 100m-by-100m
	file road_shapefile <- file("../includes/Itp_Road.shp");	
	file river_shapefile <- file("../includes/River_S5.shp");
	file Precip_TAverage <- file("../includes/Monthly_Climate.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm, total mm of ET0 per month
	file Soil_Group <- file("../includes/soil_group_pH.shp");
	file trees_shapefile <- shape_file("../includes/Initial_Distribution_Trees.shp");	//randomly positioned
	file Plot_shapefile <- shape_file("../includes/parcel-polygon-100mx100m.shp");
	
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
	
	//information about the trees can be compiled in a csv	
	float growth_rate_exotic <- 0.73 update: growth_rate_exotic;
	float max_dbh_exotic <- 110.8 update: max_dbh_exotic;
	float min_dbh_exotic <- 1.0 update: min_dbh_exotic;
	int ave_fruits_exotic <- 700 update: ave_fruits_exotic;
	
	float growth_rate_native <- 2.0 update: growth_rate_native;
	float max_dbh_native <- 130.0 update: max_dbh_native;
	float min_dbh_native <- 1.0 update: min_dbh_native;
	int ave_fruits_native <- 100 update: ave_fruits_native;
	
	list<float> min_water <- [1500.0, 2000.0];						//best grow, annual
	list<float> max_water <- [3500.0, 4000.0];						//best grow, annual
	list<float> min_pH <- [4.5, 6.5];								//temp value - best grow
	list<float> max_pH <- [7.5, 7.5];								//temp value - best grow
	list<float> min_temp <- [20.0, 20.0];							//temp value - best grow
	list<float> max_temp <- [34.0, 7.5];							//true value - best grow	

	//computed K based on Von Bertalanffy Growth Function 
	float mahogany_von_gr;
	float mayapis_von_gr;
	
	int nursery_count <- 1 update: nursery_count;

	
	init {
		create climate from: Precip_TAverage {
			temperature <- [float(get("1_TAvg")),float(get("2_TAvg")),float(get("3_TAvg")),float(get("4_TAvg")),float(get("5_TAvg")),float(get("6_TAvg")),float(get("7_TAvg")),float(get("8_TAvg")),float(get("9_TAvg")),float(get("10_TAvg")),float(get("11_TAvg")),float(get("12_TAvg"))];
			precipitation <- [float(get("1_Prec")),float(get("2_Prec")),float(get("3_Prec")),float(get("4_Prec")),float(get("5_Prec")),float(get("6_Prec")),float(get("7_Prec")),float(get("8_Prec")),float(get("9_Prec")),float(get("10_Prec")),float(get("11_Prec")),float(get("12_Prec"))];
			etp <- [float(get("1_ETP")),float(get("2_ETP")),float(get("3_ETP")),float(get("4_ETP")),float(get("5_ETP")),float(get("6_ETP")),float(get("7_ETP")),float(get("8_ETP")),float(get("9_ETP")),float(get("10_ETP")),float(get("11_ETP")),float(get("12_ETP"))];
		
			total_precipitation <- sum(precipitation);	
		}
		create soil from: Soil_Group with: [id::int(get("VALUE")), soil_pH::float(get("Average_pH"))];
		
		//clean_network(road_shapefile.contents,tolerance,split_lines,reduce_to_main_connected_components
		
		clean_lines <- clean_network(road_shapefile.contents,50.0,true,true);
		create road from: clean_lines;
		road_network <- as_edge_graph(road);	//create road from the clean lines
		
		//Identify drain cells
		loop pp over: points where (water_content[each]>400){	//look inside the area of concern, less than 400 means not part of concern
			list<point> edge_points <- neighbors[pp] where (water_content[each] = 400);
			if(length(edge_points) > 0){
				drain_cells <+ pp;
			}	
		}
		drain_cells <- remove_duplicates(drain_cells);
		float min_height <- drain_cells min_of (water_content[each]);
		drain_cells <- drain_cells where (water_content[each] < min_height+20);

		//Determine initial amount of water
		loop pp over: points where (water_content[each] > 400){
			soil closest_soil <- soil closest_to pp;	//closest soil descriptor to the point
			water_content[pp] <- water_content[pp] + (0.2 * closest_soil.S);
			water_before_runoff[pp] <- 0.2 * closest_soil.S;	//Ia
		}
		
		create trees from: trees_shapefile{
			dbh <- float(read("Book2_DBH"));
			th <- float(read("Book2_TH"));
			mh <- float(read("Book2_MH"));	
			r <- float(read("Book2_R"));
			type <- ((read("Book2_Clas")) = "Native")? 0:1;
			
			if(type = 1){ //exotic trees, mahogany
				age <- int(self.dbh/growth_rate_exotic);
				shade_tolerant <- false;
			}else{	//native trees are shade tolerant
				age <- int(self.dbh/growth_rate_native);
				shade_tolerant <- true;
			}
		}	
		do computeGrowthRate;
		
		create plot from: Plot_shapefile{
			if(water_content[self.location] <= 400){
				do die;
			}
			
			 plot_trees <- trees inside self;
			 loop p over: plot_trees{
			 	p.my_plot <- self;
			 }
		}
		
		//clean data, with the given options
		clean_lines <- clean_network(river_shapefile.contents,3.0,true,false);
		//create river from the clean lines
		create river from: clean_lines {
			node_id <- int(read("NODE_A")); 
			drain_node <- int(read("NODE_B")); 
			strahler <- int(read("ORDER_CELL"));
		}
		river_network <- as_edge_graph(river);
		
		//computed the connected components of the graph (for visualization purpose)
		connected_components <- list<list<point>>(connected_components_of(river_network));
		loop times: length(connected_components) {colors << rnd_color(255);}
	}
	
	action computeGrowthRate{
		 mahogany_von_gr <- growth_rate_exotic / (max_dbh_exotic - min_dbh_exotic);
		 mayapis_von_gr <- growth_rate_native / (max_dbh_native - min_dbh_native);
		 
		 write "growth rate mahogany: "+mahogany_von_gr;
		 write "growth_rate_mayapis: "+mayapis_von_gr;
	}
	
	//base on the current month, add precipitation
	reflex addingPrecipitation{
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
	reflex waterFlow{
		done[] <- false;
		inflow[] <- 0.0;
		list<point> water <- points where (water_content[each] > 400) sort_by (water_content[each]);
		loop p over: points - water {
			done[p] <- true;
		}
		loop p over: water {
			soil closest_soil <- soil closest_to p;	//closest soil descriptor to the point
			remaining_precip[p] <- remaining_precip[p] + inflow[p];	//add inflow
			inflow[p] <- 0.0;	//set inflow back to 0
			
			//determine if there will be a runoff
			if(remaining_precip[p] > water_before_runoff[p]){	//there will be runoff
				//write "Water runoff";
				//compute for Q, where Q = (RP-Ia)^2 / ((RP-Ia+S)
				float Q <- ((remaining_precip[p] - water_before_runoff[p])^2)/(remaining_precip[p] - water_before_runoff[p]+closest_soil.S);
				
				//subtract runoff from remaining_precip
				water_before_runoff[p] <- (remaining_precip[p] - Q);	//in mm
				
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
	
	reflex waterViz{
		loop pp over: points where (water_content[each] > 0){
			water_content[pp] <- water_before_runoff[pp] + 400;
		}
	}

	reflex drainCells{
		loop pp over: drain_cells{
			water_content[pp] <- 0;
			water_before_runoff[pp] <- 0;
		}
	}
}

species plot{
	list<trees> plot_trees;
	soil my_soil <- soil closest_to location;
	climate my_climate <- climate closest_to location;
	float investment_value;
	bool is_nursery <- false;
	
	aspect default{
		if(length(plot_trees) > 0){
			draw self.shape color: #gray;
		}else{
			draw self.shape color: #black;
		}
	}
	
	action computeReqInvestment{
		
	}
	
	reflex updateTrees{
		if(length(plot_trees where dead(each)) > 0){
			plot_trees <- plot_trees where !dead(each);
		}
	}
	
}

species soil{
	float S; //potential maximum soil moisture 
	int curve_number; 
	int id;
	float soil_pH;
	
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
	float total_precipitation;
	int year <- 0;
	
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
	int strahler;
	
	aspect default {
		//draw display_shape color: #blue depth: 3 at: {location.x,location.y,terrain[point(location.x, location.y)]+250};//250
		draw display_shape color: #blue;// at: {location.x,location.y,location.z};//200
	}
	
	init cleaning_river{
		ask plot overlapping self{
			ask self.plot_trees{
				do die;
			}
			do die;
		}
	}
}

species trees{
	float dbh; //diameter at breast height
	float th; //total height
	float mh; //merchantable height
	float r; //distance from tree to a point 
	int type;  //0-mayapis; 1-mahogany; 2-fruit tree
	
	float ba;
	float dipy;
	float vol;
	
	float total_biomass <- 0.0;	//in kg
	int age;
	bool shade_tolerant;
	
	plot my_plot;
	bool is_mother_tree <- false;
	
	aspect default{
		draw circle(self.dbh, shape.location) color: (type = 0)?#forestgreen:#midnightblue border: #black at: {location.x,location.y,elev[point(location.x, location.y)]+450};
	}
	
	aspect geom3D{
		draw cylinder(min(0.1, self.dbh/100), min(1, self.dbh/100)) color: #saddlebrown at: {location.x,location.y,elev[point(location.x, location.y)]+450};
		draw sphere(self.dbh) color: (type = 0) ? #forestgreen :  #midnightblue at: {location.x,location.y,elev[point(location.x, location.y)]+450 +  min(1, self.dbh/100)};
	}
	
	//kill tree that are inside a basin
	reflex killTree{
		point tree_loc <- shape.location;
		if(my_plot = nil) {do die;}
		else{
			if(water_content[tree_loc]-275 > elev[tree_loc]){
				remove self from: my_plot.plot_trees;
				do die;
			}
		} 
	}
	
	//recruitment of tree
	//mahogany fruit production every January, February, March, August, and December 
	reflex fruitProduction{
		list<int> fruiting_months <- [0,1,2,7,11];
		
		float sfruit <- 42.4;
		float fsurv <- 0.085;
		float fgap <- 0.026;
		float fviable <- 0.618;
		int total_no_seeds <- 0;
		//Trees 75 cm DBH were also more consistent producers.
		//produces more than 700 fruits/year 
		if(dbh >= 75 and ([0,1,2,7,11] contains current_month) and type = 1){
			total_no_seeds <- int((ave_fruits_exotic/length(fruiting_months))*sfruit*fsurv*fgap*fviable);	//1-year old seeds
			if(total_no_seeds > 0){
				is_mother_tree <- true;
				geometry t_space <- circle((self.dbh)+(40), self.location)- circle((self.dbh)+(20), self.location);
				do recruitTree(total_no_seeds, t_space);	
			}else{is_mother_tree <- false;}
		}else if(type = 0 and age > 15 and current_month = 8){
			total_no_seeds <- int((ave_fruits_native)*sfruit*fsurv*fgap*fviable);	//1-year old seeds
			if(total_no_seeds > 0){
				is_mother_tree <- true;
				geometry t_space <- circle((self.dbh)+(40), self.location);
				do recruitTree(total_no_seeds, t_space);
			}else{is_mother_tree <- false;}
		}	
	}
	
	action recruitTree(int total_no_seeds, geometry t_space){
		//determine available space in the parcel within 20m to 40m
		list<trees> t_inside_zone <- my_plot.plot_trees inside t_space; 
		
		if(length(t_inside_zone) > 0){	//check if there are trees inside the zone, then remove the spaces occupied by the trees 
			//do not include spaces occupied by trees
			ask t_inside_zone{
				if(empty(t_space)){break;} //stop when there's no more space 
				geometry occupied_spaces <- circle(self.dbh) translated_to self.location;
				t_space <- t_space - occupied_spaces;
			}
		}
		//create new trees	
		int count <- 0;
		loop i from: 0 to: total_no_seeds-1 {
			//setting location of the new tree 
			point new_location <- any_location_in(t_space);
			geometry new_shape;
			if(new_location = nil){break;}	//don't add seeds if there are no space
			else{
				new_shape <- circle(dbh) translated_to new_location;
				if(new_shape.area > t_space.area){break;}	//don't add if tree is greater than available space
				else{
					t_space <- t_space - new_shape;
				}
			}
			create trees{			
				age <- 1;
				type <- myself.type;	//mahogany
				shade_tolerant <- false;
				dbh <- 0.7951687878;
				location <- new_location;	//place tree on an unoccupied portion of the parcel
				//location <- any_location_in(myself.chosenParcel.shape);	//same as above
				my_plot <- plot(agent_closest_to(self));
				my_plot <- self.my_plot;
				myself.my_plot.plot_trees << self;	//similar scenario different approach for adding specie to a list attribute of another specie
				shape <- new_shape;
			}//add treeInstance all: true to: chosenParcel.parcelTrees;	//add new tree to parcel's list of trees
		}
	}
	
	//growth of tree
	reflex growDiameter {	
		float cur_month <- (cycle mod 12)/12;
		//write "cur_month: "+cur_month;
		if(type = 0){ //mayapis
			dbh <- (max_dbh_native * (1-exp(-mayapis_von_gr * (cur_month+age))))*growthCoeff(type);
		}else if(type = 1){	//mahogany
			dbh <- (max_dbh_exotic * (1-exp(-mahogany_von_gr * (cur_month+age))))*growthCoeff(type);
		}
	}	
	
	//the best range
	float reduceGrowth(float curr, float min, float max){
		float ave <- (max + min)/2;
		float coeff;
		
		if(curr <= ave){
			coeff <- ((curr/(ave-min)) + (min/(min - ave)));
		}else{
			coeff <- -((curr/(max-ave))+(max/(max-ave)));
		}
		
		if(coeff<= 0.01 or coeff > 1.0){coeff <- 1.0;}	//for the meantime, if the coeff is very small or curr is greater than the max  value
		return coeff;
	}
	
	float growthCoeff(int t_type){
		float curr_temp <- my_plot.my_climate.temperature[current_month];
		float curr_pH <- my_plot.my_soil.soil_pH;
		float curr_water <- water_content[location];
		float percent_precip <- my_plot.my_climate.precipitation[current_month]/my_plot.my_climate.total_precipitation;
		
		float g_coeff <- 1.0;
		g_coeff <- g_coeff * reduceGrowth(curr_temp, min_temp[t_type], max_temp[t_type]);	//coefficient given temperature
		g_coeff <- g_coeff * reduceGrowth(curr_pH, min_pH[t_type], max_pH[t_type]);			//coefficient given soil pH
		g_coeff <- g_coeff * reduceGrowth(curr_water, min_water[t_type]*percent_precip, max_water[t_type]*percent_precip);//coefficient given water (considering only the percentage of precipitation given current month over the total annual precipitation)
		
		return g_coeff;
	}
	//height of tree
	
	//tree age
	reflex stepAge when: (cycle mod 12)=0 {
		age <- age + 1;
	}
	
	//tree mortality
	reflex determineMortality{
		float e <- exp(-2.917 - 1.897 * ((shade_tolerant)?1:0) - 0.079 * dbh);
		float proba_dead <- (e/(e+1));
		
		if(flip(proba_dead)){
			remove self from: my_plot.plot_trees;
			do die;
		}
	}
}
