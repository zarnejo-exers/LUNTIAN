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
	
	/** Insert the global definitions, variables and actions here */
	file elev_file <- file("../images/ITP_Reprojected_Filled.tif"); //resolution 30m-by-30m
	file dem_file <- file("../images/ITP_colored_100.tif");		//resolution 100m-by-100m
	file road_shapefile <- file("../includes/ITP_Road.shp");	
	file river_shapefile <- file("../includes/River_S5.shp");
	file Precip_TAverage <- file("../includes/Monthly_Climate.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm, total mm of ET0 per month
	file Soil_Group <- file("../includes/soil_group_pH.shp");
//	file trees_shapefile <- shape_file("../includes/Initial_Distribution_Trees.shp");	//randomly positioned, actual
	file trees_shapefile <- shape_file("../includes/TREES_INIT.shp");	//randomly positioned, dummy equal distribution
	file Plot_shapefile <- shape_file("../includes/ITP_GRID_NORIVER.shp");
//	file Plot_shapefile <- shape_file("../includes/parcel-polygon-100mx100m.shp");
	
	graph road_network;
	graph river_network;
	
	field elev <- field(elev_file);
	//field water_content <- field(dem_file)+400;
	//field water_before_runoff <- field(water_content.columns, water_content.rows, 0.0);	// Ia
	field remaining_precip <- field(water_content.columns, water_content.rows, 0.0);	// RP in mm
	field inflow <- field(water_content.columns, water_content.rows, 0.0);	// RP
	
	file water_file <- file("../images/water_level.tif");
	field water_content <- field(water_file);
	
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
	float growth_rate_exotic <- 0.10417 update: growth_rate_exotic;	//average monthly Schneider, T., Ashton, M. S., Montagnini, F., & Milan, P. P. (2014). Growth performance of sixty tree species in smallholder reforestation trials on Leyte, Philippines. New Forests, 45(1), 83–96. https://doi.org/10.1007/s11056-013-9393-5
	float max_dbh_exotic <- 110.8 update: max_dbh_exotic;
	float min_dbh_exotic <- 1.0 update: min_dbh_exotic;
	//int ave_fruits_exotic <- 700 update: ave_fruits_exotic;
	float exotic_price_per_volume <- 70.0 update: exotic_price_per_volume;
	
	float growth_rate_native <- 0.09917 update: growth_rate_native;	//average monthly (Shorea guiso Blaco Blume) Schneider, T., Ashton, M. S., Montagnini, F., & Milan, P. P. (2014). Growth performance of sixty tree species in smallholder reforestation trials on Leyte, Philippines. New Forests, 45(1), 83–96. https://doi.org/10.1007/s11056-013-9393-5
	float max_dbh_native <- 130.0 update: max_dbh_native;
	float min_dbh_native <- 1.0 update: min_dbh_native;
	//int ave_fruits_native <- 100 update: ave_fruits_native;
	float native_price_per_volume <- 70.0 update: native_price_per_volume;
	
	//Note: 0->January; 11-> December
	list<int> fruiting_months_N <- [4,5,6];	//seeds fall to the ground, ready to be harvested
	list<int> flowering_months_E <- [2,3,4,5];
	list<int> fruiting_months_E <- [11, 0, 1, 2];
	
	//native, exotic
	list<float> min_water <- [1500.0, 1400.0];						//best grow, annual, monthly will be taken in consideration during the growth effect
	list<float> max_water <- [3500.0, 6000.0];						//best grow, annual
	list<float> min_pH <- [5.0, 6.0];								//temp value - best grow
	list<float> max_pH <- [6.7, 8.5];								//temp value - best grow
	list<float> min_temp <- [20.0, 11.0];							//temp value - best grow
	list<float> max_temp <- [34.0, 39.0];							//true value - best grow	

	//computed K based on Von Bertalanffy Growth Function 
	//float mahogany_von_gr;
	//float mayapis_von_gr; 
	
	list<plot> entrance_plot;
	
	init {
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
		write "Done reading soil...";
//		Useful when there is no water_level yet
//		Determine initial amount of water
//		loop pp over: points where (water_content[each] > 400){
//			soil closest_soil <- soil closest_to pp;	//closest soil descriptor to the point
//			//water_content[pp] <- water_content[pp] + (0.2 * closest_soil.S);
//			//water_before_runoff[pp] <- water_content[pp];	//Ia
//		}
		
		create trees from: trees_shapefile{
			dbh <- float(read("Book2_DBH"));
			mh <- float(read("Book2_MH"));		
			th <- float(read("Book2_TH"));		
			r <- float(read("Book2_R"));		
			type <- (string(read("Book2_Clas")) = "Native")? NATIVE:EXOTIC;	
			
			//Dummy
//			dbh <- float(read("Dummy_Data"));	//Dummy_Data
//			mh <- float(read("Dummy_Da_1"));		//Dummy_Da_1
//			th <- float(read("Dummy_Da_2"));		//Dummy_Da_1
//			r <- float(read("Dummy_Da_5"));		//Dummy_Da_5
//			type <- ((read("Dummy_Da_3")) = "Native")? NATIVE:EXOTIC;	//Dummy_Da_3
			
			if(mh > th){
				float temp_ <- mh;
				mh <- th;
				th <- temp_;
			}
			cr <- 1 - (mh / th);
			crown_diameter <- cr*(dbh) + dbh; 
			
			if(type = EXOTIC){ //exotic trees, mahogany
				age <- self.dbh/growth_rate_exotic;
				shade_tolerant <- false;
			}else{	//native trees are shade tolerant
				age <- self.dbh/growth_rate_native;
				shade_tolerant <- true;
			}
		}
		write "Done reading trees...";
		
		//do computeGrowthRate;
		
		create plot from: Plot_shapefile{
			if((water_content[self.location] <= 400)){	//if the plot is actually a river, do not include it
				do die;
			}else{
				plot_trees <- trees inside self;
				loop p over: plot_trees{
					p.my_plot <- self;
				}
				 
				if(length(road crossing self)>0){
					has_road <- true;
				}	
			}
			id <- int(read("id"));
		}
		write "Done reading plot...";
		entrance_plot <- getEntrancePlot();	//determine the entrance plots for competing community
		
		ask plot{
			do compute_neighbors;
			ask plot_trees{
				float prev_dbh <- dbh;
				nieghborh_effect <- 1.0;
				if(state = ADULT){
					nieghborh_effect <- neighborhoodInteraction();
					if(nieghborh_effect > 0){
						nieghborh_effect <- 1-exp(log(neighborhoodInteraction()) * log(prev_dbh));	
					}	
				}				
				dbh <- computeDiameterIncrement(nieghborh_effect, self.location) + prev_dbh;
				th <- calculateHeight(dbh, type);	
			}
			write "Assigning plot: "+id;
		}
		
		write "Done associating trees to plot";
		
		//clean data, with the given options
		clean_lines <- clean_network(river_shapefile.contents,3.0,true,false);
		//create river from the clean lines
		create river from: clean_lines {
			node_id <- int(read("NODE_A")); 
			drain_node <- int(read("NODE_B")); 
			strahler <- int(read("ORDER_CELL"));
			basin <- int(read("BASIN"));
		}
		river_network <- as_edge_graph(river);
		
		//computed the connected components of the graph (for visualization purpose)
		connected_components <- list<list<point>>(connected_components_of(river_network));
		loop times: length(connected_components) {colors << rnd_color(255);}
		write "End initialization";
	}
	
	//returns the entrance plots
	list<plot> getEntrancePlot{
		return reverse(sort_by(plot where (!each.has_road and each.plot_trees != nil), each.location.y))[0::200];	//entrance_plot is the first 100 lowest point
	}
	
//	action computeGrowthRate{
//		 mahogany_von_gr <- growth_rate_exotic / (max_dbh_exotic - min_dbh_exotic);
//		 mayapis_von_gr <- growth_rate_native / (max_dbh_native - min_dbh_native);
//		 
//		 write "growth rate mahogany: "+mahogany_von_gr;
//		 write "growth_rate_mayapis: "+mayapis_von_gr;
//	}
	
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

//	useful at the beginning when "water_level" is not yet present 	
//	reflex waterViz{
//		loop pp over: points where (water_content[each] > 0){
//			water_content[pp] <- water_before_runoff[pp] + 400;
//		}
//	}

	reflex drainCells{
		loop pp over: drain_cells{
			water_content[pp] <- 0;
		}
	}

//	useful at the beginning when "water_level" is not yet present
//	reflex saveField when: cycle = 75{
//    	save water_content to: "../images/water_level.tif" format: "geotiff" crs: "EPSG:25393";
//    }

	reflex count_plots{
		write "length: "+length(plot);
	}
}

species trees{
	float dbh; //diameter at breast height
	float th; //total height
	float mh;	//merchantable height
	float r; //distance from tree to a point 
	int type;  //0-palosapis; 1-mahogany
	float cr; 	//crown ratio, set at the reading of the data
	float crown_diameter;	//crown diameter
	
	float basal_area <- 0.0 update: ((dbh/2.54)^2) * 0.005454;	//calculate basal area before calculating dbh increment; in m2
	float dipy;
	
	float total_biomass <- 0.0;	//in kg
	float age;
	bool shade_tolerant;
	
	plot my_plot;
	bool is_mother_tree <- false;
	bool is_new_tree <- false;
	
	int count_fruits; 
	int temp;
	
	list<trees> my_neighbors <- [];  
	float nieghborh_effect <- 0.0; 
	int state;
	
	float diameter_increment <- 0.0; 
	map<int, list<float>> max_dbh_per_class <- map<int,list>([NATIVE::[5.0,10.0,20.0,100.0],EXOTIC::[1.0,5.0,30.0,150.0]]);
	
	bool has_flower <- false;
	int has_fruit_growing <- 0;	//timer once there are fruits, from 12 - 0, where fruits now has grown into 1-year old seedlings
	int number_of_fruits <- 0;
	
	//kill tree that are inside a water basin
	reflex killTree{
		point tree_loc <- shape.location;
		if(my_plot = nil) {do die; }
		else{
			if(water_content[tree_loc]-275 > elev[tree_loc]){
				remove self from: my_plot.plot_trees;
				my_plot.is_near_water <- true;
				do die;
			}
		} 
	}
	
	
	aspect default{
		draw circle(self.crown_diameter/2, self.location) color: (type = NATIVE)?#forestgreen:#midnightblue border: #black at: {location.x,location.y,elev[point(location.x, location.y)]+450};
	}
	
	aspect geom3D{
		if(crown_diameter != 0){
			//this is the crown
			if(temp = 3){
				draw sphere(self.crown_diameter/2) color: #turquoise at: {location.x,location.y,elev[point(location.x, location.y)]+400+mh};
			}
			else if(is_new_tree){	//new tree
				draw sphere(self.crown_diameter/2) color: #yellow at: {location.x,location.y,elev[point(location.x, location.y)]+400+mh};
			}else{
				draw sphere(self.crown_diameter/2) color: (type = NATIVE) ? #forestgreen :  #midnightblue at: {location.x,location.y,elev[point(location.x, location.y)]+400+mh};	
			}
			
			//this is the stem
			draw circle(dbh/2) at: {location.x,location.y,elev[point(location.x, location.y)]+400} color: #brown depth: mh;
		}	
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
	
	//put the recruit on the same plot as with the mother tree
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
				add self to: my_plot.plot_trees;	//similar scenario different approach for adding specie to a list attribute of another specie
				is_new_tree <- true;
				instance <- self;
				state <- SEEDLING;
			}//add treeInstance all: true to: chosenParcel.parcelTrees;	add new tree to parcel's list of trees
			
			trees closest_tree <- instance.my_plot.plot_trees closest_to instance;
			if(closest_tree != nil and circle(closest_tree.dbh+5, closest_tree.location) overlaps circle(instance.dbh+5, instance.location)){	//check if the instance overlaps another tree
				ask instance{
					remove self from: my_plot.plot_trees;
					do die;
				}
			}else{
				add instance to: new_trees;		//add new tree to list of new trees
				t_space <- t_space - circle(instance.dbh, new_location); 	//remove the tree's occupied space from the available space 
			}
		}
		count_fruits <- length(new_trees);
	}

	//growth of tree
	//assume: growth coefficient doesn't apply on plots for ITP 
	//note: monthly increment 
	//returns diameter_increment
	float computeDiameterIncrement(float neighbor_impact, point loc){
		if(type = EXOTIC){ //mahogany 
			climate closest_clim <- climate closest_to loc;	//closest climate descriptor to the point
			float precip_value <- closest_clim.precipitation[current_month];
			float etp_value <- closest_clim.etp[current_month];
			
			int is_dry_season <- (precip_value <etp_value)?-1:1;
				
			switch(dbh){
				match_between [0, 19.99] {
					return (((1.01+(0.10*is_dry_season))/12) *neighbor_impact);
				}
				match_between [20, 29.99] {return (((0.86+(0.17*is_dry_season))/12) *neighbor_impact);}
				match_between [30, 39.99] {return (((0.90+(0.10*is_dry_season))/12) *neighbor_impact);}
				match_between [40, 49.99] {return (((0.75+(0.14*is_dry_season))/12) *neighbor_impact);}
				match_between [50, 59.99] {return (((1.0+(0.06*is_dry_season))/12) *neighbor_impact);}
				match_between [60, 69.99] {return (((1.16+(0.06*is_dry_season))/12) *neighbor_impact);}
				default {return (((1.38+(0.26*is_dry_season))/12) *neighbor_impact);}	//>70
			}
		}else if(type = NATIVE){	//palosapis
			float increment <- (((0.1726*(dbh^0.5587)) + (-0.0215*dbh) + (-0.0020*basal_area))/12); 
			return ((((0.1726*(dbh^0.5587)) + (-0.0215*dbh) + (-0.0020*basal_area))/12)*neighbor_impact); 
		}
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
	
	float neighborhoodInteraction{
		list<trees> t <- my_plot.plot_trees where !dead(each);
		my_neighbors <- (t select ((each.state = ADULT) and (each distance_to self) < 20#m));
		float ni <- 0.0;
		
		loop n over: (my_neighbors-self){
			float dis <- n distance_to self;
			if(dis > 0){
				ni <- ni + ((n.basal_area * ((self.type = n.type)?1:0.5))/(n distance_to self));	
			}
		}
		
		if(ni < 0.000001){
			ni <- 0.0;
		}
		
		return ni;
	}	
	
	//used by checkMortality for Exotic/Mahogany
	float exotic_GetShadeTolerance{
		switch state{
			match SEEDLING{
				return 0.0;
			} 
			match SAPLING {
				return 0.33;
			}
			match POLE{
				return 0.66;
			}
			match ADULT{
				return 1.0;
			}
		}
	}
	
	//Returns middleDBH, used by checkMortality() for Native/Dipterocarps
	float getMiddleDBH{
		switch state{
			match SEEDLING{
				return (max_dbh_per_class[type][SEEDLING]/2);
			}
			default{	//the middle dbh between current and the former state max_dbh
				return ((max_dbh_per_class[type][state]+max_dbh_per_class[type][state-1])/2);
			}
		}
	}
	
	//tree mortality
	//true = dead
	bool checkMortality{
		float p_dead <- 0.0;
		switch type{
			match EXOTIC {
				float e <- exp(-2.917 - 1.897 * self.exotic_GetShadeTolerance() - 0.079 * dbh);
				p_dead <- (e/(e+1));
			}
			match NATIVE{
				float d <- self.getMiddleDBH();
				float x_0 <- -4.0527+(1/d);
				float x_1 <- -0.1582*d;
				float x_2 <- 0.0011*(d^2);
				float x_3 <- 0.0951*self.my_plot.stand_basal_area;
				float e <- -(x_0 + x_1 + x_2 + x_3);
				p_dead <- ((1+exp(e))^-1);
			}
		}
		
		bool is_dead <- flip(p_dead);
		
		//add additional 50% of survival if inside nursery
		if(is_dead and my_plot.is_nursery){
			return flip(0.5);
		}
		
		return is_dead;
	}
	
	//doesn't yet inhibit growth of tree
	action treeGrowthIncrement{
		trees closest_tree <-(my_plot.plot_trees closest_to self); 
		float prev_dbh <- dbh;
		float prev_th <- th;
		
		nieghborh_effect <- 1.0;
		if(state = ADULT){
			nieghborh_effect <- neighborhoodInteraction();
			if(nieghborh_effect > 0){
				nieghborh_effect <- 1-exp(log(neighborhoodInteraction()) * log(prev_dbh));	
			}	
		}
		
		diameter_increment <- computeDiameterIncrement(nieghborh_effect, self.location);
		dbh <- dbh + diameter_increment;	 
		crown_diameter <- cr*(dbh) + dbh;
		th <- calculateHeight(dbh, type);
		if(!my_plot.is_itp and closest_tree != nil and (circle(self.crown_diameter/2, self.location) overlaps circle(closest_tree.crown_diameter/2, closest_tree.location))){	//inhibit growth if will overlap
			dbh <- prev_dbh;
			th <- prev_th;	
		}
		
		mh <- th - (cr * th);	//update merchantable height
	}
	
	//tree age
	//once the tree reaches 5 years old, it cannot be moved to a nursery anymore
	action stepAge {
		age <- age + (1/12);
	}
	
	geometry getTreeSpaceForRecruitment{
		point mother_location <- point(self.location.x, self.location.y);
		geometry t_space <- my_plot.neighborhood_shape inter (circle(self.dbh+20, mother_location) - circle(self.dbh, mother_location));
		return my_plot.removeTreeOccupiedSpace(t_space, trees inside t_space);
	}
	
	action treeRecruitment{
		switch type{
			match NATIVE {
				if(number_of_fruits > 0 and is_mother_tree and fruiting_months_N contains current_month){	//fruit ready to be picked during the fruiting_months_N		
					do recruitTree(number_of_fruits, getTreeSpaceForRecruitment());	
					is_mother_tree <- false;
					number_of_fruits <- 0;
					has_fruit_growing <- 12;
				}else if(has_fruit_growing > 0){
					has_fruit_growing <- has_fruit_growing - 1;
					is_mother_tree <- true;
				}
			}
			match EXOTIC{
				if(number_of_fruits >0 and has_fruit_growing=0){	//fruits have matured
					int total_no_1yearold <- int(number_of_fruits *42.4 *0.085);//42.4->mean # of viable seeds per fruit, 0.085-> seeds that germinate and became 1-year old 
					do recruitTree(total_no_1yearold, getTreeSpaceForRecruitment());	
					has_fruit_growing <- 0;
					number_of_fruits <- 0;
					is_mother_tree <- false;
				}else if(has_fruit_growing > 0){	//flower is growing
					has_fruit_growing <- has_fruit_growing-1;
				}else if(has_flower and fruiting_months_E contains current_month){	//flower has bud, # of flowers is determined
					number_of_fruits <- getNumberOfFruitsE();
					has_fruit_growing <- 11;
					has_flower <- false;	
				}else if((age>=12 and state=ADULT) and !has_flower and (flowering_months_E contains current_month)){	//adult tree, no flower, but flowering season
					has_flower <- isFlowering();	//compute the probability of flowering
					is_mother_tree <- (has_flower)?true:false;	//turn the tree into a mother tree
				}
			}
		}
	}
	
	//in meters
	float calculateHeight(float temp_dbh, int t_type){
		switch t_type{
			match EXOTIC {
				return (1.3 + (12.3999 * (1 - exp(-0.105*temp_dbh)))^1.79);	///Downloads/BKrisnawati1110.pdf
			}
			match NATIVE {
				return (1.3 + (temp_dbh / (1.7116 + (0.3415 * temp_dbh)))^3);	//https://d-nb.info/1002231884/34		
			}
		}
	}
	
	//in cubic meters
	float calculateVolume(float temp_dbh, int t_type){
		return -0.08069 + 0.31144 * ((temp_dbh*0.01)^2) * calculateHeight(temp_dbh, t_type);	//Nguyen, T. T. (2009). Modelling Growth and Yield of Dipterocarp Forests in Central Highlands of Vietnam [Ph.D. Dissertation]. Technische Universität München.	
	}
	
	//based on Vanclay(1994) schematic representation of growth model
	reflex growthModel{
		bool is_dead <- false;
		if((my_plot.is_nursery and age>3) or (!my_plot.is_nursery)){	//determine mortality
			if(checkMortality()){
				remove self from: my_plot.plot_trees;
				is_dead <- true;
				do die;	
			}
		}
		if(!is_dead){	//tree recruits, tree grows, tree ages
			do treeRecruitment();
			do treeGrowthIncrement();
			do stepAge();
		}
	}

	/*Dipterocarp: max_dbh = [80,120]cm
	 *Mahogany: max_dbh = 150cm
	 *				Exotic			Native
	 * seedling		[0,1)			[0,5)
	 * sapling		[1,5)			[5,10)
	 * pole			[5,30)			[10,20)
	 * adult 		[30,150)		[20,100)
	*/
	reflex updateTreeClass{
		if(dbh < max_dbh_per_class[type][0]){
			state <- SEEDLING;
		}else if(dbh<max_dbh_per_class[type][1]){
			is_new_tree <- false;
			state <- SAPLING;
		}else if(dbh<max_dbh_per_class[type][2]){
			state <- POLE;
		}else{
			state <- ADULT;
		}
	}
}

species plot{
	list<labour> my_laborers <- [];
	geometry neighborhood_shape <- nil;
	bool is_policed <- false;
	list<trees> plot_trees<- [] update: plot_trees where !dead(each);
	int tree_count <- 0 update: length(plot_trees);
	soil my_soil <- soil closest_to location;
	climate my_climate <- climate closest_to location;
	bool is_nursery <- false;
	int nursery_type <- -1; //
	bool is_itp <- false;
	bool is_investable <- false;
	bool is_near_water <- false;
	bool has_road <- false;
	bool is_candidate_nursery <- false; //true if there exist a mother tree in one of its trees;
	int rotation_years <- 0; 	//only set once an investor decided to invest on a plot
	bool is_invested <- false;
	float stand_basal_area;
	int id; 
	
	float projected_profit;
	float investment_cost;
	
	int getSaplingsCountS(int t_type){
		list<trees> pt <- plot_trees where !dead(each);
		return length(pt where (each.type = t_type and each.state = SAPLING));
	}
	
	action compute_neighbors {
		list<plot> my_neighborhood <- (plot select ((each distance_to self) < 5));
		
		loop mn over: my_neighborhood{
			neighborhood_shape <- neighborhood_shape + mn.shape;
		}
		
		//write "My area: "+self.shape.area+" Neighbors area: "+neighborhood_shape.area;
	}
	
	reflex native_determineNumberOfRecruits when: (fruiting_months_N contains current_month){
		//compute total number of recruits
		//divide total number of recruits by # of adult trees
		//turn the adult trees into mature trees and assign fruit in each
		//has_fruit_growing = 0 ensures that the tree hasn't just bore fruit, trees that bore fruit must wait at least 1 year before they can bear fruit again
		list<trees> adult_trees <- reverse((trees select (each.age >= 15 and each.type=NATIVE and each.has_fruit_growing = 0)) sort_by (each.dbh));	//get all adult trees with age>= 15
		if(length(adult_trees) > 1){	//if count > 1, compute total number of recruits
			int count_of_native <- trees count (each.type = NATIVE);
			float number_of_recruits <- 4.202 + (0.017*count_of_native) + (-0.126*stand_basal_area);
			int recruits_per_adult_trees <- 1;
			//write "Native: number of recuits: "+number_of_recruits+" for "+length(adult_trees);
			
			if(number_of_recruits > length(adult_trees)){
				recruits_per_adult_trees <- int(number_of_recruits/length(adult_trees));	
			}else{
				adult_trees <- copy_between(adult_trees, 1, length(adult_trees));
			}
			
			ask adult_trees{
				number_of_fruits <- recruits_per_adult_trees;
				is_mother_tree <- true;
			}
			
		}
	}
	
	//sum of all the basal areas of the tree inside the plot, in m2
	reflex getStandBasalArea{
		float sba <- 0.0;
		
		ask plot_trees{
			sba <- sba + basal_area;
		}
	
		stand_basal_area <- sba;
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
	
	aspect si{
		if(is_nursery){
			draw self.shape color: #yellow;
		}else if(is_investable){
			draw self.shape color: #lightgreen;
		}else if(is_invested){
			draw self.shape color: #lightblue;
		}else{
			if(length(plot_trees) > 0){
				draw self.shape color: #darkgreen;
			}else{
				draw self.shape color: #gray;
			}
		}
	}
	
	aspect entrance{
		if(self in entrance_plot){
			draw self.shape color: #green;
		}else{
			draw self.shape color: #black;
		}
	}
	
	//if there exist a mother tree in one of the trees inside the plot, it becomes a candidate nursery
	reflex checkifCandidateNursery{	// should be reflex
		int mother_count <- length(plot_trees where each.is_mother_tree);
		is_candidate_nursery <- (mother_count > 0)?true:false;
	}
	
	//removes spaces occupied by trees
	//temp_shape can be the shape of a parcel
	//trees_inside can be the parcel_trees
	geometry removeTreeOccupiedSpace(geometry temp_shape, list<trees> trees_inside){
		//remove from occupied spaces
		loop pt over: trees_inside{
			if(dead(pt)){ continue; }
			//geometry occupied_space <- circle(pt.dbh, pt.location);
			temp_shape <- temp_shape - circle(pt.dbh, pt.location);//occupied_space; dbh+ room for growth
		}
		
		return temp_shape;
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
	int basin;
	
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
		ask plot at_distance(5){
			is_near_water <- true;
		}
	}
}
