/**
* Name: main
* Based on the internal skeleton template. 
* Author: zenith
* Contains the following species: rivers, roads, climate, soil, plot, trees
* Tags: waterwater_content from "Waterwater_content Field Elevation.gaml"
*/

model llg
import "university_si.gaml"

global {
	int NB_TS <- 12; //monthly timestep, constant
	int NATIVE <- 0;
	int EXOTIC <- 1;
	int SEEDLING <- 0;
	int SAPLING <- 1;
	int POLE <- 2;
	int ADULT <- 3;
	
	file trees_shapefile <- shape_file("../includes/TREES_WITH_RIVER.shp");	//mixed species
	file plot_shapefile <- shape_file("../includes/ITP_WITH_RIVER.shp");
//	file trees_shapefile <- shape_file("../includes/TREES_INIT.shp");	//mixed species
//	file plot_shapefile <- shape_file("../includes/ITP_GRID_NORIVER.shp");
	file road_shapefile <- file("../includes/ITP_Road.shp");
	file river_shapefile <- file("../includes/River_S5.shp");
	file Precip_TAverage <- file("../includes/CLIMATE_COMP.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm, total mm of ET0 per month
	file Soil_Group <- file("../includes/soil_group_pH.shp");
	file water_file <- file("../images/water_level.tif");
	file elev_file <- file("../images/ITP_Reprojected_Filled.tif"); //resolution 30m-by-30m
	
	float growth_rate_exotic <- 1.25 update: growth_rate_exotic;//https://www.researchgate.net/publication/258164722_Growth_performance_of_sixty_tree_species_in_smallholder_reforestation_trials_on_Leyte_Philippines
	float growth_rate_native <- 0.72 update: growth_rate_native;	//https://www.researchgate.net/publication/258164722_Growth_performance_of_sixty_tree_species_in_smallholder_reforestation_trials_on_Leyte_Philippines
	
	//note: information about the trees can be compiled in a csv	
	float max_dbh_exotic <- 110.8 update: max_dbh_exotic;
	float min_dbh_exotic <- 1.0 update: min_dbh_exotic;
	//int ave_fruits_exotic <- 700 update: ave_fruits_exotic;
	float exotic_price_per_volume <- 70.0 update: exotic_price_per_volume;
	
	float max_dbh_native <- 130.0 update: max_dbh_native;
	float min_dbh_native <- 1.0 update: min_dbh_native;
	//int ave_fruits_native <- 100 update: ave_fruits_native;
	float native_price_per_volume <- 70.0 update: native_price_per_volume;

	field elev <- field(elev_file);	
	field water_content <- field(water_file);
	graph road_network;
	graph river_network;
	field remaining_precip <- field(water_content.columns, water_content.rows, 0.0);	// RP in mm
	field inflow <- field(water_content.columns, water_content.rows, 0.0);	// RP

	list<point> points <- water_content points_in shape; //elev
	map<point, list<point>> neighbors <- points as_map (each::(water_content neighbors_of each));
	map<point, bool> done <- points as_map (each::false);
	map<point, float> h <- points as_map (each::water_content[each]);
	float input_water;
	
	list<float> min_water <- [1500.0, 1400.0];						//best grow, annual, monthly will be taken in consideration during the growth effect
	list<float> max_water <- [3500.0, 6000.0];						//best grow, annual
	list<float> min_pH <- [5.0, 6.0];								//temp value - best grow
	list<float> max_pH <- [6.7, 8.5];								//temp value - best grow
	list<float> min_temp <- [20.0, 11.0];							//temp value - best grow
	list<float> max_temp <- [34.0, 39.0];							//true value - best grow
	
	map<point, climate> cell_climate;
	int current_month <- 0 update:(cycle mod NB_TS);
	map<int, list<float>> max_dbh_per_class <- map<int,list>([NATIVE::[5.0,10.0,20.0,100.0],EXOTIC::[1.0,5.0,30.0,150.0]]);	
	
	//Note: 0->January; 11-> December
	list<int> fruiting_months_N <- [4,5,6];	//seeds fall to the ground, ready to be harvested
	list<int> flowering_months_E <- [2,3,4,5];
	list<int> fruiting_months_E <- [11, 0, 1, 2];
	
	list<point> drain_cells <- [];
	
	geometry shape <- envelope(Soil_Group);	//TODO: Soil_Group [for experimenting smaller area] or plot_shapefile [for the larger area]
	list<geometry> clean_lines;
	list<list<point>> connected_components ;
	list<rgb> colors;
	
	list<plot> entrance_plot;
	
	init{
		write "Begin initialization";
		create climate from: Precip_TAverage {
			temperature <- [float(get("1_TAvg")),float(get("2_TAvg")),float(get("3_TAvg")),float(get("4_TAvg")),float(get("5_TAvg")),float(get("6_TAvg")),float(get("7_TAvg")),float(get("8_TAvg")),float(get("9_TAvg")),float(get("10_TAvg")),float(get("11_TAvg")),float(get("12_TAvg"))];
			precipitation <- [float(get("1_Prec")),float(get("2_Prec")),float(get("3_Prec")),float(get("4_Prec")),float(get("5_Prec")),float(get("6_Prec")),float(get("7_Prec")),float(get("8_Prec")),float(get("9_Prec")),float(get("10_Prec")),float(get("11_Prec")),float(get("12_Prec"))];
			etp <- [float(get("1_ETP")),float(get("2_ETP")),float(get("3_ETP")),float(get("4_ETP")),float(get("5_ETP")),float(get("6_ETP")),float(get("7_ETP")),float(get("8_ETP")),float(get("9_ETP")),float(get("10_ETP")),float(get("11_ETP")),float(get("12_ETP"))];
		
			total_precipitation <- sum(precipitation);	
		}
		write "Done reading climate...";
		create soil from: Soil_Group with: [id::int(get("VALUE")), soil_pH::float(get("Average_pH"))];
		//clean_network(road_shapefile.contents,tolerance,split_lines,reduce_to_main_connected_components
		clean_lines <- clean_network(road_shapefile.contents,50.0,true,true);
		create road from: clean_lines{
			shape <- shape + 15#m;
		}
		road_network <- as_edge_graph(road);	//create road from the clean lines
		write "Done reading road...";
		
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
		write "Done reading soil...";
		
		
		create trees from: trees_shapefile{
			dbh <- float(read("Book2_DBH"));
			mh <- float(read("Book2_MH"));		
			th <- float(read("Book2_TH"));		
			r <- float(read("Book2_R"));		
			type <- (string(read("Book2_Clas")) = "Native")? NATIVE:EXOTIC;	
			th <- calculateHeight(dbh, type);
			basal_area <- #pi * (dbh^2)/40000;
			do setState();
			
			if(mh > th){
				float temp_ <- mh;
				mh <- th;
				th <- temp_;
			}
			
			if(type = EXOTIC){ //exotic trees, mahogany
				age <- self.dbh/growth_rate_exotic;
				shade_tolerant <- false;
			}else{	//native trees are shade tolerant
				age <- self.dbh/growth_rate_native;
				shade_tolerant <- true;
			}
		}
		write "Done reading trees...";
		
		clean_lines <- clean_network(river_shapefile.contents,3.0,true,false);
		create river from: clean_lines {
			node_id <- int(read("NODE_A")); 
			drain_node <- int(read("NODE_B")); 
			strahler <- int(read("ORDER_CELL"));
			basin <- int(read("BASIN"));
		}
		
		create plot from: plot_shapefile{
			//remove sections that are part of road
			plot_trees <- trees inside self.shape;
			
			list<road> road_crossing <- road intersecting self;
			if(length(road_crossing)>0){
				has_road <- true;
				ask road_crossing{
					do removeRoadSection(myself);
				}
			}
		
			ask plot_trees{
				my_plot <- myself;
				my_neighbors <- my_plot.plot_trees select (each.state = ADULT and (each distance_to self) <= 20#m);
			}

			id <- int(read("id"));
			closest_clim <- climate closest_to self;
			stand_basal_area <- plot_trees sum_of (each.basal_area);
			
			river closest_river <- river closest_to self;
			distance_to_river <- closest_river distance_to self;
			
			if(distance_to_river <= 100#m){
				is_near_water <- true;
			}
		}
		
		
		
		river_network <- as_edge_graph(river);
		//computed the connected components of the graph (for visualization purpose)
		connected_components <- list<list<point>>(connected_components_of(river_network));
		loop times: length(connected_components) {colors << rnd_color(255);}
		entrance_plot <- reverse(sort_by(plot where (!each.has_road and each.plot_trees != nil), each.location.y))[0::200];	//entrance_plot is the first 100 lowest point
		write "End initialization";
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
			if(remaining_precip[p] > water_content[p]){	//there will be runoff
				//write "Water runoff";
				//compute for Q, where Q = (RP-Ia)^2 / ((RP-Ia+S)
				float Q <- ((remaining_precip[p] - water_content[p])^2)/(remaining_precip[p] - water_content[p]+closest_soil.S);
				
				//subtract runoff from remaining_precip
				water_content[p] <- (remaining_precip[p] - Q);	//in mm
				
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
	
	reflex drainCells{
		loop pp over: drain_cells{
			water_content[pp] <- 0;
		}
	}
}

species trees{
	float dbh; //diameter at breast height
	float th; //total height
	float mh;	//merchantable height
	float r; //distance from tree to a point 
	int type;  //0-palosapis; 1-mahogany
	float age;
	bool shade_tolerant;
	plot my_plot;
	int state; 
	float neighborh_effect <- 1.0; 
	float diameter_increment <- 0.0; 
	
	float cr <- 1/5;	//by default 
	float crown_diameter <- (cr*dbh) update: (cr*dbh);	//crown diameter
	float basal_area <- #pi * (dbh^2)/40000 update: #pi * (dbh^2)/40000;	//http://ifmlab.for.unb.ca/People/Kershaw/Courses/For1001/Erdle_Version/TAE-BasalArea&Volume.pdf in m2
	
	int counter_to_next_recruitment <- 0;	//ensures that tree only recruits once a year
	int number_of_recruits <- 0;
	bool is_mother_tree <- false;
	
	int number_of_fruits <- 0;
	int has_fruit_growing <- 0;	//timer once there are fruits, from 12 - 0, where fruits now has grown into 1-year old seedlings
	bool has_flower <- false;
	bool is_new_tree <- false;
	bool is_marked <- false;
	
	list<trees> my_neighbors; 	
	
	//STATUS: CHECKED
	aspect geom3D{
		if(crown_diameter != 0){
			//this is the crown
			// /2 since parameter asks for radius
			if(is_marked){
				draw sphere((self.crown_diameter/2)#m) color: #black at: {location.x,location.y,elev[point(location.x, location.y)]+400+th#m};
			}else if(type = NATIVE){
				draw sphere((self.crown_diameter/2)#m) color: #darkgreen at: {location.x,location.y,elev[point(location.x, location.y)]+400+th#m};
			}else{
				draw sphere((self.crown_diameter/2)#m) color: #violet at: {location.x,location.y,elev[point(location.x, location.y)]+400+th#m};
			}
			
			//this is the stem
			switch state{
				match SEEDLING{
					draw circle((dbh/2)#cm) at: {location.x,location.y, elev[point(location.x, location.y)]+400} color: #yellow depth: th#m;		
				}
				match SAPLING{
					draw circle((dbh/2)#cm) at: {location.x,location.y, elev[point(location.x, location.y)]+400} color: #green depth: th#m;
				}
				match POLE{
					draw circle((dbh/2)#cm) at: {location.x,location.y, elev[point(location.x, location.y)]+400} color: #blue depth: th#m;
				}
				match ADULT{
					draw circle((dbh/2)#cm) at: {location.x,location.y, elev[point(location.x, location.y)]+400} color: #red depth: th#m;
				}
			}
			
		}	
	}
	
	aspect default{
		if(crown_diameter != 0){
			//this is the crown
			// /2 since parameter asks for radius
			if(is_marked){
				draw sphere((self.crown_diameter/2)#m) color: #black at: {location.x,location.y,th#m};
			}else if(type = NATIVE){
				draw sphere((self.crown_diameter/2)#m) color: #darkgreen at: {location.x,location.y,th#m};
			}else{
				draw sphere((self.crown_diameter/2)#m) color: #violet at: {location.x,location.y,th#m};
			}
			
			//this is the stem
			switch state{
				match SEEDLING{
					draw circle((dbh/2)#cm) at: {location.x,location.y} color: #yellow depth: th#m;		
				}
				match SAPLING{
					draw circle((dbh/2)#cm) at: {location.x,location.y} color: #green depth: th#m;
				}
				match POLE{
					draw circle((dbh/2)#cm) at: {location.x,location.y} color: #blue depth: th#m;
				}
				match ADULT{
					draw circle((dbh/2)#cm) at: {location.x,location.y} color: #red depth: th#m;
				}
			}
			
		}		
	}
	
	//STATUS: CHECKED
	float calculateHeight(float temp_dbh, int t_type){
		float predicted_height; 
		switch t_type{
			match EXOTIC {
				predicted_height <- (1.3 + (12.39916 * (1 - exp(-0.105*dbh)))^1.79);	//https://www.cifor-icraf.org/publications/pdf_files/Books/BKrisnawati1110.pdf 
			}
			match NATIVE {
				predicted_height <- 1.3+(dbh/(1.5629+0.3461*dbh))^3;	//https://d-nb.info/1002231884/34		
			}
		}
		
		return predicted_height;	//in meters	
	}
	
	//in cubic meters
	float calculateVolume(float temp_dbh, int t_type){
		return -0.08069 + 0.31144 * ((temp_dbh*0.01)^2) * calculateHeight(temp_dbh, t_type);	//Nguyen, T. T. (2009). Modelling Growth and Yield of Dipterocarp Forests in Central Highlands of Vietnam [Ph.D. Dissertation]. Technische Universität München.	
	}

	//STATUS: CHECKED, but needs neighbor effect
	//growth of tree
	//assume: growth coefficient doesn't apply on plots for ITP 
	//note: monthly increment 
	//returns diameter_increment
	float computeDiameterIncrement{
		if(type = EXOTIC){ //mahogany 
			switch(dbh){
				match_between [0, 19.99] {
					return (((1.01+(0.10*my_plot.is_dry))/12));
				}
				match_between [20, 29.99] {return ((0.86+(0.17*my_plot.is_dry))/12);}
				match_between [30, 39.99] {return ((0.90+(0.10*my_plot.is_dry))/12);}
				match_between [40, 49.99] {return ((0.75+(0.14*my_plot.is_dry))/12);}
				match_between [50, 59.99] {return ((1.0+(0.06*my_plot.is_dry))/12);}
				match_between [60, 69.99] {return ((1.16+(0.06*my_plot.is_dry))/12);}
				default {return ((1.38+(0.26*my_plot.is_dry))/12);}	//>70
			}
		}else if(type = NATIVE){	//dipterocarp, after: anisoptera costata
			return (((0.1726*(dbh^0.5587)) + (-0.0215*dbh) + (-0.0020*basal_area))/12); 
		}
	}		
	
	//doesn't yet inhibit growth of tree
	action treeGrowthIncrement{
		float prev_dbh <- dbh;
		float prev_th <- th;
		float ni <- 1-neighborhoodInteraction();
		float gcoeff <- (type = NATIVE)?my_plot.growth_coeff_N:my_plot.growth_coeff_E;

		diameter_increment <- computeDiameterIncrement()*ni*gcoeff;
		dbh <- dbh + diameter_increment;	 
		if(dbh > max_dbh_per_class[type][ADULT]){
			dbh <- max_dbh_per_class[type][ADULT];
		}
		th <- calculateHeight(dbh, type);
		do setState();
	}
	
	//tree age
	//once the tree reaches 5 years old, it cannot be moved to a nursery anymore
	action stepAge {
		age <- age + (1/12);
	}
	
	//STATUS: CHECKED
	//tree mortality
	//true = dead
	bool checkMortality{
		float p_dead <- 0.0;
		float e <- exp(-2.917 - 1.897 * (shade_tolerant?1:0) - 0.079 * dbh);
		p_dead <- (e/(e+1));
		return flip(p_dead);	
	}
	
	//put the recruit on the same plot as with the mother tree
	action recruitTree(int total_recruits, geometry t_space){
		//create new trees	
		loop i from: 0 to: total_recruits {
			//setting location of the new tree 
			//make sure that there is sufficient space before putting the tree in the new location
			point new_location <- any_location_in(t_space);
			if(new_location = nil){
				break;
			}	//don't add seeds if there are no space

			create trees{
				dbh <- (type=NATIVE)?growth_rate_native:growth_rate_exotic;
				type <- myself.type;
				age <-1.0; 
				location <- new_location;
				my_plot <- plot closest_to self;	//assigns the plot where the tree is located
				shade_tolerant <- myself.shade_tolerant;
				is_new_tree <- true;
				t_space <- t_space - circle((dbh/2)#cm);	//remove from available spaces the space occupied by new tree
				th <- calculateHeight(dbh, type);
				basal_area <- #pi * (dbh^2)/40000;
				add self to: my_plot.plot_trees;
				do setState();	
			}//add treeInstance all: true to: chosenParcel.parcelTrees;	add new tree to parcel's list of trees
		}
	}
	
	//return unoccupied places within 20m from the mother tree
	geometry getTreeSpaceForRecruitment{
		geometry recruitment_space <- circle((dbh/2)#cm + 20#m);	//recruitment space
		list<trees> trees_inside <- trees inside recruitment_space;
		ask trees_inside{
			recruitment_space <- recruitment_space - circle((dbh/2)#cm);	//remove the space occupied by tree
		} 
		return recruitment_space inter world.shape;	//TODO: change my_plot.shape to world.shape for simulation on entire area
	}
	
	//recruitment of tree
	//compute probability of bearing fruit
	//mahogany fruit maturing: December to March
	//when bearingfruit and season of fruit maturing, compute # of produced fruits
	//compute # of 1-year old seedling 
	//geometry t_space <- my_plot.getRemainingSpace();	//get remaining space in the plot
	int getNumberOfFruitsE{
		float x0 <- 0.296+(0.025*dbh);
		float x1 <- (0.0003*(dbh^2));
		float x2 <- -1.744*((10^-6)*(dbh^3));
		float alpha <- exp(x0+x1+x2);
		float beta <- 1.141525;
		return int(alpha/beta);	//returns mean of the gamma distribution, alpha beta
	}
	
	bool isFlowering{
		float x0 <- 9.624+(3.201*diameter_increment);
		float x1 <- -1.265*(diameter_increment^2);
		float x2 <- 0.21*dbh;
		float x3 <- -0.182*(max(0, (dbh-40)));
		float e <- exp(x0+x1+x2+x3);
		float p_producing <- e/(1+e);
		
		return flip(p_producing);
	}
		
	action treeRecruitment{
		switch type{
			match NATIVE {
				//number of recruits is calculated per plot and recruits are assigned to tree
				if(number_of_recruits > 0 and is_mother_tree and fruiting_months_N contains current_month){	//fruit ready to be picked during the fruiting_months_N		
					do recruitTree(number_of_recruits, getTreeSpaceForRecruitment());	
					is_mother_tree <- false;
					number_of_recruits <- 0;
					counter_to_next_recruitment <- 12;
				}else if(counter_to_next_recruitment > 0){
					counter_to_next_recruitment <- counter_to_next_recruitment - 1;
				}
			}
			match EXOTIC{
				if((age>=12 and state=ADULT and !is_mother_tree) and !has_flower and (flowering_months_E contains current_month)){	//checking if the adult tree has borne flowers
					has_flower <- isFlowering();	//compute the probability of flowering
					is_mother_tree <- (has_flower)?true:false;	//turn the tree into a mother tree
				}else if(is_mother_tree and has_flower and fruiting_months_E contains current_month){//checks if the flowers have turned into fruits
					number_of_fruits <- getNumberOfFruitsE();
					has_fruit_growing <- 12;
					has_flower <- false;	
				}else if(has_fruit_growing > 0){	//gives time for fruits to mature
					has_fruit_growing <- has_fruit_growing-1;
				}else if(number_of_fruits >0 and has_fruit_growing=0){	//fruits have matured
					//compute for fgap
					geometry recruitment_space <- circle((dbh/2)#cm + 20#m);	//recruitment space
					geometry actual_space_available <- getTreeSpaceForRecruitment();
					
					if(actual_space_available != nil){
						float fgap <- 1- (actual_space_available.area / recruitment_space.area);
					
						int total_no_1yearold <- int(number_of_fruits *42.4 *0.085*fgap*0.618);//42.4->mean # of viable seeds per fruit, 0.085-> seeds that germinate and became 1-year old 
						do recruitTree(total_no_1yearold, actual_space_available);	
					}
						
					number_of_fruits <- 0;
					is_mother_tree <- false;
				}
			}
		}
	}
	
	//based on Vanclay(1994) schematic representation of growth model
	reflex growthModel when: location != point(0,0,0){	//trees with location = nil are currently in the "bags" of laborers, meaning, gathered as seedling 
		if(checkMortality()){
			remove self from: my_plot.plot_trees;
			if(state = ADULT){
				do updateNeighborhood(true);	//given its neighborhood, add itself on their neighborhood
			}
			do die;	
		}
		else{	//tree recruits, tree grows, tree ages
			do treeRecruitment();
			do treeGrowthIncrement();
			do stepAge();
		}

	}
	
	//ni goes from [0,1], with 1 being a very strong influence
	float neighborhoodInteraction{
		float ni <- 0.0;
		ask my_neighbors{
			float dis <- self distance_to myself;
			if(dis > 0.0){
				ni <- ni + ((basal_area * ((myself.type = type)?1:0.5))/dis);	
			}
		}
		
		//write "NI: "+ni+" average: "+ni/length(my_neighbors);
		if(ni > 1.0){	 
			ni <- 1.0;
		}
		return ni;
	}	
	
	//Called when either: (1) a tree has just recently became adult; or (2) an adult tree has died
	action updateNeighborhood(bool is_remove){
		ask my_neighbors{
			if(!is_remove){
				add myself to: my_neighbors;	
			}else{
				remove myself from: my_neighbors;
			}
		}	
	}
	
	action setState{
		if(dbh >= max_dbh_per_class[type][POLE]){
			if(state != ADULT){
				do updateNeighborhood(false);	//given its neighborhood, add itself on their neighborhood
			}
			state <- ADULT;
		}else if(dbh < max_dbh_per_class[type][POLE] and dbh >= max_dbh_per_class[type][SAPLING]){
			state <- POLE;
		}else if(dbh < max_dbh_per_class[type][SAPLING] and dbh >= max_dbh_per_class[type][SEEDLING]){
			if(my_plot != nil and my_plot.is_nursery and state != SAPLING){
				ask university_si{
					add myself to: my_saplings;
				}
			}
			state <- SAPLING;
		}else if(dbh > 0){
			state <- SEEDLING;
		}
	}
}

species plot{
	list<trees> plot_trees<- [];
	int id;
	climate closest_clim;
	int is_dry; 
	float stand_basal_area <- plot_trees sum_of (each.basal_area) update: plot_trees sum_of (each.basal_area);
	int native_count <- plot_trees count (each.type = NATIVE) update: plot_trees count (each.type = NATIVE);
	geometry neighborhood_shape <- nil;
	float my_pH <- (soil closest_to location).soil_pH;
	climate my_climate <- climate closest_to location;
	float distance_to_river;
	
	float curr_precip <- my_climate.precipitation[current_month] update: my_climate.precipitation[current_month];
	float curr_temp <- my_climate.temperature[current_month] update: my_climate.temperature[current_month];
	
	float growth_coeff_N;
	float growth_coeff_E; 
	
	int rotation_years <- 0; 	//only set once an investor decided to invest on a plot
	bool is_near_water <- false;
	bool is_nursery <- false;
	bool has_road <- false;
	bool is_invested <- false;
	bool is_candidate_nursery <- false; //true if there exist a mother tree in one of its trees;
	float projected_profit;
	float investment_cost;
	bool is_itp <- false;
	bool is_policed <- false;
	int nursery_type <- -1;
	bool is_investable <- false;

	list<labour> my_laborers <- [];
	int tree_count <- length(plot_trees) update: length(plot_trees);
	soil my_soil <- soil closest_to location;	
	
	bool is_ANR <- false;
	bool is_harvested <- false;
		
	//STATUS: CHECKED
	//per plot
	reflex native_determineNumberOfRecruits when: (fruiting_months_N contains current_month){
		//compute total number of recruits
		//divide total number of recruits by # of adult trees
		//turn the adult trees into mature trees and assign fruit in each
		//has_fruit_growing = 0 ensures that the tree hasn't just bore fruit, trees that bore fruit must wait at least 1 year before they can bear fruit again
		list<trees> adult_trees <- reverse((plot_trees select (each.state = ADULT and each.age >= 15 and each.type=NATIVE and each.counter_to_next_recruitment = 0)) sort_by (each.dbh));	//get all adult trees in the plot
		if(length(adult_trees) > 0){	//if count > 1, compute total number of recruits
			int length_adult_trees <- length(adult_trees);
			int total_no_of_native_recruits_in_plot <- int(4.202 + (0.017*native_count) + (-0.126*stand_basal_area));
			if(total_no_of_native_recruits_in_plot > 0){
				int recruits_per_adult_trees <- int(total_no_of_native_recruits_in_plot/length_adult_trees)+1;
				loop at over: adult_trees{
					if(total_no_of_native_recruits_in_plot < 1){	//no more recruits
						break;	
					}else if(recruits_per_adult_trees > total_no_of_native_recruits_in_plot){	//Case: when the remaining recruits is > total_no_of_native_recruits_in_plot
						at.number_of_recruits <- total_no_of_native_recruits_in_plot;
						at.is_mother_tree <- true;
						break;
					}else{
						at.number_of_recruits <- recruits_per_adult_trees;
						at.is_mother_tree <- true;
						total_no_of_native_recruits_in_plot <- total_no_of_native_recruits_in_plot - recruits_per_adult_trees;
					}
				}
			}
		}
	}
	
	aspect default{
		if(is_nursery){
			draw shape color: #green;
		}else if(is_ANR){
			draw shape color: #aquamarine;
		}else if(is_harvested){
			draw shape color: #violet;
		}else{
			draw shape color: rgb(153,136,0);
		}
	}
	
	//if there exist a mother tree in one of the trees inside the plot, it becomes a candidate nursery
	//put 
	reflex checkifCandidateNursery when: has_road{	// should be reflex
		int mother_count <- length(plot_trees where each.is_mother_tree);
		is_candidate_nursery <- (mother_count > 0)?true:false;
	}
	
	reflex checkIsDry{
		float precip_value <- closest_clim.precipitation[current_month];
		float etp_value <- closest_clim.etp[current_month];
			
		is_dry <- (precip_value <etp_value)?-1:1;
	}	
	
	
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
	
	float computeCoeff(float c_water, float p_precip, int type){
		float g_coeff <- 1.0;
		g_coeff <- g_coeff * reduceGrowth(curr_temp, min_temp[type], max_temp[type]);	//coefficient given temperature
		g_coeff <- g_coeff * reduceGrowth(my_pH, min_pH[NATIVE], max_pH[NATIVE]);			//coefficient given soil pH
		g_coeff <- g_coeff * reduceGrowth(c_water, min_water[NATIVE]*p_precip, max_water[NATIVE]*p_precip);//coefficient given water (considering only the percentage of precipitation given current month over the total annual precipitation)
		return g_coeff;
	}
	
	reflex growthCoeff{
		float curr_water <- water_content[location];
		float percent_precip <- curr_precip/my_climate.total_precipitation;
		
		growth_coeff_N <- computeCoeff(curr_water, percent_precip, NATIVE);
		growth_coeff_E <- computeCoeff(curr_water, percent_precip, EXOTIC);
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
//standard tree clearance width for the construction of a forest road is 15 metres. 
species road {
	aspect default {
		//draw display_shape color: #black depth: 3.0 at: {location.x,location.y,terrain[point(location.x, location.y)+250]};//250
		draw shape color: #black;// depth: 3.0 at: {location.x,location.y,location.z};//200
	}
	
	action removeRoadSection(plot plot_with_road){
		//remove all: (trees inside r.shape) from: plot_trees; 
		list<trees> trees_on_road <- plot_with_road.plot_trees inside shape;
		
		//remove trees on road
		ask trees_on_road{
			remove self from: plot_with_road.plot_trees;
			do die;
		}
		
		plot_with_road.shape <- plot_with_road.shape - shape;	//remove road section from plot
		
	}
}

species river{
	int node_id; 
	int drain_node;
	int strahler;
	int basin;
	
	aspect default {
		//draw display_shape color: #blue depth: 3 at: {location.x,location.y,terrain[point(location.x, location.y)]+250};//250
		draw shape color: #blue;// at: {location.x,location.y,location.z};//200
	}
}