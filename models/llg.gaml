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
	int NATIVE <- 0;
	int EXOTIC <- 1;
	
	/** Insert the global definitions, variables and actions here */
	file elev_file <- file("../images/ITP_Reprojected_Filled.tif"); //resolution 30m-by-30m
	file dem_file <- file("../images/ITP_colored_100.tif");		//resolution 100m-by-100m
	file road_shapefile <- file("../includes/Itp_Road.shp");	
	file river_shapefile <- file("../includes/River_S5.shp");
	file Precip_TAverage <- file("../includes/Monthly_Climate.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm, total mm of ET0 per month
	file Soil_Group <- file("../includes/soil_group_pH.shp");
//	file trees_shapefile <- shape_file("../includes/Initial_Distribution_Trees.shp");	//randomly positioned, actual
	file trees_shapefile <- shape_file("../includes/Dummy_Data50x50.shp");	//randomly positioned, dummy equal distribution
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
	
	//note: information about the trees can be compiled in a csv	
	float growth_rate_exotic <- 0.73 update: growth_rate_exotic;
	float max_dbh_exotic <- 110.8 update: max_dbh_exotic;
	float min_dbh_exotic <- 1.0 update: min_dbh_exotic;
	int ave_fruits_exotic <- 700 update: ave_fruits_exotic;
	
	float growth_rate_native <- 2.0 update: growth_rate_native;
	float max_dbh_native <- 130.0 update: max_dbh_native;
	float min_dbh_native <- 1.0 update: min_dbh_native;
	int ave_fruits_native <- 100 update: ave_fruits_native;
	
	//native, exotic
	list<float> min_water <- [1500.0, 1400.0];						//best grow, annual, monthly will be taken in consideration during the growth effect
	list<float> max_water <- [3500.0, 6000.0];						//best grow, annual
	list<float> min_pH <- [5.0, 6.0];								//temp value - best grow
	list<float> max_pH <- [6.7, 8.5];								//temp value - best grow
	list<float> min_temp <- [20.0, 11.0];							//temp value - best grow
	list<float> max_temp <- [34.0, 39.0];							//true value - best grow	

	//computed K based on Von Bertalanffy Growth Function 
	float mahogany_von_gr;
	float mayapis_von_gr; 
	
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
			//Actual
//			dbh <- float(read("Book2_DBH"));	
//			mh <- float(read("Book2_MH"));		
//			r <- float(read("Book2_R"));		
//			type <- ((read("Book2_Clas")) = "Native")? 0:1;	
			
			//Dummy
			dbh <- float(read("Dummy_Data"));	//Dummy_Data
			th <- float(read("Dummy_Da_1"));		//Dummy_Da_1
			r <- float(read("Dummy_Da_5"));		//Dummy_Da_5
			type <- ((read("Dummy_Da_3")) = "Native")? NATIVE:EXOTIC;	//Dummy_Da_3
			
			if(type = EXOTIC){ //exotic trees, mahogany
				age <- self.dbh/growth_rate_exotic;
				shade_tolerant <- false;
			}else{	//native trees are shade tolerant
				age <- self.dbh/growth_rate_native;
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
			 
			if(length(road crossing self)>0){
				has_road <- true;
			}
		}
		ask plot{
			do compute_neighbors;
			ask plot_trees{
				dbh <- calculateDBH();
				th <- calculateHeight();	
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

species trees{
	float dbh; //diameter at breast height
	float th; //total height
	float r; //distance from tree to a point 
	int type;  //0-mayapis; 1-mahogany; 2-fruit tree
	
	float ba;
	float dipy;
	float vol;
	
	float total_biomass <- 0.0;	//in kg
	float age;
	bool shade_tolerant;
	
	plot my_plot;
	bool is_mother_tree <- false;
	bool is_new_tree <- false;
	
	int count_fruits; 
	int temp;
	
	aspect default{
		draw circle(self.dbh, self.location) color: (type = NATIVE)?#forestgreen:#midnightblue border: #black at: {location.x,location.y,elev[point(location.x, location.y)]+450};
	}
	
	aspect geom3D{
//		if(self.is_mother_tree){
//			draw sphere(self.dbh) color: #turquoise at: {location.x,location.y,elev[point(location.x, location.y)]+400+(mh)};
//		}
		 
		if(is_new_tree){	//new tree
			draw sphere(self.dbh) color: #yellow at: {location.x,location.y,elev[point(location.x, location.y)]+400+(th)};
		}else{
			draw sphere(self.dbh) color: (type = NATIVE) ? #forestgreen :  #midnightblue at: {location.x,location.y,elev[point(location.x, location.y)]+400+(th)};	
		}
		draw circle(th/2) at: {location.x,location.y,elev[point(location.x, location.y)]+400} color: #brown depth: th;
		
	}
	
	//kill tree that are inside a basin
	reflex killTree{
		point tree_loc <- shape.location;
		if(my_plot = nil) {do die;}
		else{
			if(water_content[tree_loc]-275 > elev[tree_loc]){
				remove self from: my_plot.plot_trees;
				my_plot.is_near_water <- true;
				do die;
			}
		} 
	}
	
	//once the tree reaches 5 years old, it cannot be moved to a nursery anymore 
	reflex updateTreeStats when: age > 2{
		is_new_tree <- false;
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
		
		list<plot> nurseries;
		point mother_location <- point(self.location.x, self.location.y);
		ask university{
			nurseries <- my_nurseries;
		}
		
		//Trees 75 cm DBH were also more consistent producers.
		//produces more than 700 fruits/year 
		//geometry t_space <- my_plot.getRemainingSpace();	//get remaining space in the plot
		if(type=EXOTIC and age > 15 and (fruiting_months contains current_month)){		//exotic tree, dbh >= 75
			total_no_seeds <- int((ave_fruits_exotic/length(fruiting_months))*sfruit*fsurv*fgap*fviable);	//1-year old seeds
			if(total_no_seeds > 0){
				is_mother_tree <- true;
				geometry t_space <- my_plot.neighborhood_shape inter (circle(self.dbh+40, mother_location) - circle(self.dbh+20, mother_location));
				t_space <- my_plot.removeOccupiedSpace(t_space, trees inside t_space);	
				if(t_space != nil){
					self.temp <- 0;
					do recruitTree(total_no_seeds, t_space);
				}
			}else{is_mother_tree <- false;}
		}else if(type = NATIVE and age > 15 and current_month = 8){		//age >=15				//native tree, produces fruit every September
			total_no_seeds <- int((ave_fruits_native)*sfruit*fsurv*fgap*fviable);	//1-year old seeds
			if(total_no_seeds > 0){
				is_mother_tree <- true;
				geometry t_space <- my_plot.neighborhood_shape inter (circle(self.dbh+20, mother_location) - circle(self.dbh, mother_location));
				t_space <- my_plot.removeOccupiedSpace(t_space, trees inside t_space);
				if(t_space != nil){
					self.temp <- 0;
					do recruitTree(total_no_seeds, t_space);
				}
			}else{is_mother_tree <- false;}
		}
	}
	
	//if there is no nursery, put the recruit on the same plot as with the mother tree
	action recruitTree(int total_no_seeds, geometry t_space){
		//create new trees	
		list<trees> new_trees;
		loop i from: 0 to: total_no_seeds-1 {
			float new_dbh <- 0.7951687878;
			//setting location of the new tree 
			//make sure that there is sufficient space before putting the tree in the new location
			point new_location <- any_location_in(t_space);
			if(new_location = nil){break;}	//don't add seeds if there are no space

			trees instance;
			create trees{			
				age <- 1.0;
				type <- myself.type;	//mahogany
				shade_tolerant <- false;
				dbh <- new_dbh;
				location <- new_location+myself.location.z;	//place tree on an unoccupied portion of the parcel
				my_plot <- (plot closest_to(self));
				shape <- circle(dbh) translated_to location;
				my_plot.plot_trees << self;	//similar scenario different approach for adding specie to a list attribute of another specie
				is_new_tree <- true;
				instance <- self;
			}//add treeInstance all: true to: chosenParcel.parcelTrees;	add new tree to parcel's list of trees
			
			ask instance.my_plot{
				do updateTrees();
			}
			trees closest_tree <- instance.my_plot.plot_trees closest_to instance;
			if(closest_tree != nil and circle(closest_tree.dbh+10) overlaps circle(instance.dbh+10)){	//check if the instance overlaps another tree
				ask instance{
					remove self from: my_plot.plot_trees;
					do die;
				}
			}else{
				add instance to: new_trees;		//add new tree to list of new trees
				t_space <- t_space - circle(instance.dbh+20, new_location); 	//remove the tree's occupied space from the available space 
			}
		}
		if(t_space != nil){
		//	write "after adding trees tspace: "+t_space.area;
		}
		count_fruits <- length(new_trees);
	}

	//growth of tree
	float calculateDBH{
		if(type = NATIVE){ //mayapis
			return (max_dbh_native * (1-exp(-mayapis_von_gr * ((current_month/12)+age))))*growthCoeff(type);
		}else if(type = EXOTIC){	//mahogany
			return(max_dbh_exotic * (1-exp(-mahogany_von_gr * ((current_month/12)+age))))*growthCoeff(type);
		}
		/*if(length(trees overlapping (circle(self.dbh) translated_to self.location)) > 0){
			dbh <- prev_dbh;	//inhibit growth if it overlaps other trees; update this once height is added
		}*/
	}	
	
	//the best range
	//TO Update: use specific max and min per focused species
	float reduceGrowth(float curr, float min, float max){
		float ave <- (max + min)/2;
		float coeff;
		
		if(curr <= ave){
			coeff <- ((curr/(ave-min))+(min/(min - ave)));
		}else{
			coeff <- -((curr/(max-ave))+(max/(max-ave)));
		}
		
		if(coeff< 0.8){coeff <- 0.8;}
		if(coeff>1.0){coeff <- 1.0;}	//for the meantime if the coeff is very small or curr is greater than the max  value, do nothing
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
	//list<float> native_hcoeffs <- [6.364, 0.1308]; //a, b	
	//list<float> exotic_hcoeffs <- [6.9418, 0.0759]; //a, b
	float calculateHeight{
		matrix<float> hcoeffs <- matrix([[6.364, 0.1308],[6.9418, 0.0759]]);
		
		//1.4 + (b+a/dbh)^-2.5
		return 1.4 + (hcoeffs[{type,1}] + hcoeffs[{type,0}] / dbh)^-2.5;
	}
	
	reflex growTree{
		dbh <- calculateDBH();
		th <- calculateHeight();
	}
	
	//tree age
	reflex stepAge {
		age <- age + (1/12);
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

species plot{
	list<labour> my_laborers;
	geometry neighborhood_shape <- nil;
	list<trees> plot_trees<- [] update: plot_trees where !dead(each);
	soil my_soil <- soil closest_to location;
	climate my_climate <- climate closest_to location;
	float investment_cost;
	float projected_profit;
	list<investor> my_investors<-[];
	bool is_nursery <- false;
	bool is_itp <- false;
	bool is_investable <- false;
	bool is_near_water <- false;
	bool has_road <- false;
	bool is_candidate_nursery <- false; //true if there exist a mother tree in one of its trees;
	int rotation_years <- 0; 	//only set once an investor decided to invest on a plot
	
	action compute_neighbors {
		list<plot> my_neighborhood <- (plot select ((each distance_to self) < 5));
		
		loop mn over: my_neighborhood{
			neighborhood_shape <- neighborhood_shape + mn.shape;
		}
		
		write "My area: "+self.shape.area+" Neighbors area: "+neighborhood_shape.area;
	}
	
	aspect default{
		if(is_nursery){
			draw self.shape color: #gold;
		}else if(is_investable){
			draw self.shape color: #turquoise;
		}else{
			if(length(plot_trees) > 0){
				draw self.shape color: #gray;
			}else{
				draw self.shape color: #black;
			}
		}
	}
	
	action updateTrees{
		if(length(plot_trees where dead(each)) > 0){
			plot_trees <- plot_trees where !dead(each);
		}
	}
	
	//if there exist a mother tree in one of the trees inside the plot, it becomes a candidate nursery
	reflex checkifCandidateNursery{	// should be reflex
		do updateTrees;
		int mother_count <- length(plot_trees where each.is_mother_tree);
		is_candidate_nursery <- (mother_count > 0)?true:false;
	}
	
	//removes spaces occupied by trees
	//temp_shape can be the shape of a parcel
	//trees_inside can be the parcel_trees
	geometry removeOccupiedSpace(geometry temp_shape, list<trees> trees_inside){
		//remove from occupied spaces
		loop pt over: trees_inside{
			if(dead(pt)){ continue; }
			//geometry occupied_space <- circle(pt.dbh, pt.location);
			temp_shape <- temp_shape - circle(pt.dbh+20);//occupied_space; dbh+ room for growth
		}
		
		return temp_shape;
	}
	
	//compute the number of new tree that the plot can accommodate
	//given type of tree, returns the number of spaces that can be accommodate wildlings
	int getAvailableSpaces(int type){
		//remove from occupied spaces
		do updateTrees();
		geometry temp_shape <- removeOccupiedSpace(self.shape, self.plot_trees);
		
		float temp_dbh;
		ask university{
			temp_dbh <- managementDBHEstimate(type, planting_age);
		}
		geometry tree_shape <- circle(temp_dbh+20);
		
		if(temp_shape = nil){return 0;}
		else{
			return int(temp_shape.area/tree_shape.area);	//rough estimate of the number of available spaces for occupation
		}	
	}
	
	reflex checkNewTreeRecruit{ //should be reflex
		do updateTrees;
		
		list<trees> new_trees <- plot_trees where (each.is_new_tree);
		if(length(new_trees) > 0){
			ask university{
				if(length(my_nurseries) > 0){
					do newTreeAlert(myself, new_trees);	
				}else{
					//write "There are no nursery yet.";
				}
				
			}
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
	list<point> my_rcells <- water_content points_in display_shape;
	int node_id; 
	int drain_node;
	int strahler;
	
	aspect default {
		//draw display_shape color: #blue depth: 3 at: {location.x,location.y,terrain[point(location.x, location.y)]+250};//250
		draw display_shape color: #blue;// at: {location.x,location.y,location.z};//200
	}
	
	//remove trees inside the river
	init cleaning_river{
		ask plot overlapping self{
			ask self.plot_trees{
				do die;
			}
			do die;
		}
	}
}
