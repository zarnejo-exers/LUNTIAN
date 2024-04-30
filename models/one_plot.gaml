/**
* Name: oneplot
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model oneplot

/* Insert your model definition here */

global{
	int NB_TS <- 12; //monthly timestep, constant
	int NATIVE <- 0;
	int EXOTIC <- 1;
	int SEEDLING <- 0;
	int SAPLING <- 1;
	int POLE <- 2;
	int ADULT <- 3;
	
	//mean annual increments for diameter
	float growth_rate_exotic <- 1.25;//https://www.researchgate.net/publication/258164722_Growth_performance_of_sixty_tree_species_in_smallholder_reforestation_trials_on_Leyte_Philippines
	float growth_rate_native <- 0.72;	//https://www.researchgate.net/publication/258164722_Growth_performance_of_sixty_tree_species_in_smallholder_reforestation_trials_on_Leyte_Philippines
	
	file trees_shapefile <- shape_file("../includes/TREES_1PLOT_NATIVE.shp");	//mixed species
	file plot_shapefile <- shape_file("../includes/ITP_GRID_1PLOT_NATIVE.shp");
	file river_shapefile <- file("../includes/River_S5.shp");
	file Precip_TAverage <- file("../includes/CLIMATE_COMP.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm, total mm of ET0 per month
	map<point, climate> cell_climate;
	int current_month <- 0 update:(cycle mod NB_TS);
	
	float n_sapling_ave_DBH <- 7.5;
	float e_sapling_ave_DBH <- 2.5; 
	float n_adult_ave_DBH <- 60.0;
	float e_adult_ave_DBH <- 90.0;
	map<int, list<float>> max_dbh_per_class <- map<int,list>([NATIVE::[5.0,10.0,20.0,100.0],EXOTIC::[1.0,5.0,30.0,150.0]]);
	
	list<int> fruiting_months_N <- [4,5,6];	//seeds fall to the ground, ready to be harvested
	list<int> flowering_months_E <- [2,3,4,5];
	list<int> fruiting_months_E <- [11, 0, 1, 2];
	
	geometry shape <- envelope(Precip_TAverage);
	list<geometry> clean_lines;

	init{
		write "Begin initialization";
		create climate from: Precip_TAverage {
			temperature <- [float(get("1_TAvg")),float(get("2_TAvg")),float(get("3_TAvg")),float(get("4_TAvg")),float(get("5_TAvg")),float(get("6_TAvg")),float(get("7_TAvg")),float(get("8_TAvg")),float(get("9_TAvg")),float(get("10_TAvg")),float(get("11_TAvg")),float(get("12_TAvg"))];
			precipitation <- [float(get("1_Prec")),float(get("2_Prec")),float(get("3_Prec")),float(get("4_Prec")),float(get("5_Prec")),float(get("6_Prec")),float(get("7_Prec")),float(get("8_Prec")),float(get("9_Prec")),float(get("10_Prec")),float(get("11_Prec")),float(get("12_Prec"))];
			etp <- [float(get("1_ETP")),float(get("2_ETP")),float(get("3_ETP")),float(get("4_ETP")),float(get("5_ETP")),float(get("6_ETP")),float(get("7_ETP")),float(get("8_ETP")),float(get("9_ETP")),float(get("10_ETP")),float(get("11_ETP")),float(get("12_ETP"))];
		
			total_precipitation <- sum(precipitation);	
		}
		write "Done reading climate...";
		create trees from: trees_shapefile{
			dbh <- float(read("Book2_DBH"));
			mh <- float(read("Book2_MH"));		
			th <- float(read("Book2_TH"));		
			r <- float(read("Book2_R"));		
			type <- (string(read("Book2_Clas")) = "Native")? NATIVE:EXOTIC;	
			th <- calculateHeight(dbh, type);
			basal_area <- ((dbh/2.54)^2) * 0.005454;
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
		
		create plot from: plot_shapefile{
			plot_trees <- trees inside self;
			loop p over: plot_trees{
				p.my_plot <- self;
			}

			id <- int(read("id"));
			closest_clim <- climate closest_to self;
			stand_basal_area <- plot_trees sum_of (each.basal_area);
			
		}
		
		clean_lines <- clean_network(river_shapefile.contents,3.0,true,false);
		create river from: clean_lines {
			node_id <- int(read("NODE_A")); 
			drain_node <- int(read("NODE_B")); 
			strahler <- int(read("ORDER_CELL"));
			basin <- int(read("BASIN"));
		}
	}
	
	reflex replant{
		ask plot{
			geometry available_space <- myself.removeOccSpace(shape, plot_trees);
			list<geometry> available_square <- (to_squares(available_space, 3#m) where (each.area >= 9#m));

			if(available_square != []){
				geometry sq <- available_square[0];
				create trees number: 1 returns: new_trees{
					dbh <- n_sapling_ave_DBH;
					type <- NATIVE;
					age <-dbh/growth_rate_native; 
					location <- sq.location;
					th <- calculateHeight(dbh, type);
					my_plot <- myself;	//assigns the plot where the tree is located
				}
				plot_trees <- plot_trees + new_trees;
//				write "Created "+length(new_trees)+" trees. Area: "+sq.area;	
			}else{
				write "NO SPACE LEFT!";
			}
		}
	}
	
	geometry removeOccSpace(geometry main_space, list<trees> to_remove_space){
		geometry t_shape <- nil; 
			
		ask to_remove_space{
			//the centre of the square is by default the location of the current agent in which has been called this operator.
			t_shape <- t_shape + square(5#m);
		}
			
		return main_space - t_shape;	//remove all occupied space;		
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
	
	aspect default{
		draw shape color: rgb(153,136,0);
	}
	
	reflex checkIsDry{
		float precip_value <- closest_clim.precipitation[current_month];
		float etp_value <- closest_clim.etp[current_month];
			
		is_dry <- (precip_value <etp_value)?-1:1;
	}
	
	//STATUS: CHECKED
	//per plot
	reflex native_determineNumberOfRecruits when: (fruiting_months_N contains current_month){
		//compute total number of recruits
		//divide total number of recruits by # of adult trees
		//turn the adult trees into mature trees and assign fruit in each
		//has_fruit_growing = 0 ensures that the tree hasn't just bore fruit, trees that bore fruit must wait at least 1 year before they can bear fruit again
		list<trees> adult_trees <- reverse((plot_trees select (each.state = ADULT and each.age >= 15 and each.type=NATIVE and each.has_fruit_growing = 0)) sort_by (each.dbh));	//get all adult trees in the plot
		if(length(adult_trees) > 0){	//if count > 1, compute total number of recruits
			int length_adult_trees <- length(adult_trees);
			int total_no_of_native_recruits_in_plot <- int(4.202 + (0.017*native_count) + (-0.126*stand_basal_area));
			if(total_no_of_native_recruits_in_plot > 0){
				write "Native: number of recruits: "+total_no_of_native_recruits_in_plot+" for "+length_adult_trees;
				int recruits_per_adult_trees <- int(total_no_of_native_recruits_in_plot/length_adult_trees)+1;
				loop at over: adult_trees{
					if(total_no_of_native_recruits_in_plot < 1){	//no more recruits
						break;	
					}else if(recruits_per_adult_trees > total_no_of_native_recruits_in_plot){	//Case: when the remaining recruits is > total_no_of_native_recruits_in_plot
						at.number_of_recruits <- total_no_of_native_recruits_in_plot;
						at.is_mother_tree <- true;
						write "Tree: "+at.name+" with "+at.number_of_recruits+" fruits";
						break;
					}else{
						at.number_of_recruits <- recruits_per_adult_trees;
						at.is_mother_tree <- true;
						total_no_of_native_recruits_in_plot <- total_no_of_native_recruits_in_plot - recruits_per_adult_trees;
						write "Tree: "+at.name+" with "+at.number_of_recruits+" fruits";
					}
				}
			}else{
				write "NO native Recruits";
			}
		}else{
			write "No native adult fruiting tree";
		}
	}
}

species river{
	geometry display_shape <- shape + 5.0;
	int node_id; 
	int drain_node;
	int strahler;
	int basin;
	
	aspect default {
		//draw display_shape color: #blue depth: 3 at: {location.x,location.y,terrain[point(location.x, location.y)]+250};//250
		draw display_shape color: #blue;// at: {location.x,location.y,location.z};//200
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
	float basal_area <- #pi * dbh/40000 update: #pi * dbh/40000;	//http://ifmlab.for.unb.ca/People/Kershaw/Courses/For1001/Erdle_Version/TAE-BasalArea&Volume.pdf in m2
	
	int counter_to_next_recruitment <- 0;	//ensures that tree only recruits once a year
	int number_of_recruits <- 0;
	bool is_mother_tree <- false;
	
	int number_of_fruits <- 0;
	int has_fruit_growing <- 0;	//timer once there are fruits, from 12 - 0, where fruits now has grown into 1-year old seedlings
	bool has_flower <- false;
	bool is_new_tree <- false;
	
	//STATUS: CHECKED
	aspect geom3D{
		if(crown_diameter != 0){
			//this is the crown
			// /2 since parameter asks for radius
			if(type = NATIVE){
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
		trees closest_tree <-(my_plot.plot_trees closest_to self); 
		float prev_dbh <- dbh;
		float prev_th <- th;
		
		diameter_increment <- computeDiameterIncrement();//*neighborh_effect;
		dbh <- dbh + diameter_increment;	 
		do setState();
		th <- calculateHeight(dbh, type);
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
	
	bool isFlowering{
		float x0 <- 9.624+(3.201*diameter_increment);
		float x1 <- -1.265*(diameter_increment^2);
		float x2 <- 0.21*dbh;
		float x3 <- -0.182*(max(0, (dbh-40)));
		float e <- exp(x0+x1+x2+x3);
		float p_producing <- e/(1+e);
		
		return flip(p_producing);
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
	
	//put the recruit on the same plot as with the mother tree
	action recruitTree(int total_recruits, geometry t_space){
		//create new trees	
		write "recruiting "+total_recruits;
		loop i from: 0 to: total_recruits {
			//setting location of the new tree 
			//make sure that there is sufficient space before putting the tree in the new location
			point new_location <- any_location_in(t_space);
			if(new_location = nil){break;}	//don't add seeds if there are no space

			create trees number: 1 returns: n_tree{
				dbh <- (myself.type=NATIVE)?growth_rate_native:growth_rate_exotic;
				type <- myself.type;
				age <-1.0; 
				location <- new_location;
				th <- calculateHeight(dbh, type);
				my_plot <- myself.my_plot;	//assigns the plot where the tree is located
				shade_tolerant <- myself.shade_tolerant;
				is_new_tree <- true;
				state <- SEEDLING;
			}//add treeInstance all: true to: chosenParcel.parcelTrees;	add new tree to parcel's list of trees
			add n_tree[0] to: my_plot.plot_trees;
			write "added 1 tree";
		}
	}
	
	//return unoccupied places within 20m from the mother tree
	geometry getTreeSpaceForRecruitment{
		geometry recruitment_space <- circle((dbh/2)#cm + 20#m);	//recruitment space
		
		
		list<trees> trees_inside <- trees inside recruitment_space;
		ask trees_inside{
			recruitment_space <- recruitment_space - circle((dbh/2)#cm);	//remove the space occupied by tree
		} 
		return recruitment_space inter my_plot.shape;
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
//			match EXOTIC{
//				if(number_of_fruits >0 and has_fruit_growing=0){	//fruits have matured
//					int total_no_1yearold <- int(number_of_fruits *42.4 *0.085);//42.4->mean # of viable seeds per fruit, 0.085-> seeds that germinate and became 1-year old 
//					do recruitTree(total_no_1yearold, getTreeSpaceForRecruitment());	
//					has_fruit_growing <- 0;
//					number_of_fruits <- 0;
//					is_mother_tree <- false;
//				}else if(has_fruit_growing > 0){	//flower is growing
//					has_fruit_growing <- has_fruit_growing-1;
//				}else if(has_flower and fruiting_months_E contains current_month){	//flower has bud, # of flowers is determined
//					number_of_fruits <- getNumberOfFruitsE();
//					has_fruit_growing <- 11;
//					has_flower <- false;	
//				}else if((age>=12 and state=ADULT) and !has_flower and (flowering_months_E contains current_month)){	//adult tree, no flower, but flowering season
//					has_flower <- isFlowering();	//compute the probability of flowering
//					is_mother_tree <- (has_flower)?true:false;	//turn the tree into a mother tree
//				}
//			}
		}
	}
	
	//based on Vanclay(1994) schematic representation of growth model
	reflex growthModel{
		if(checkMortality()){
			remove self from: my_plot.plot_trees;
			do die;	
		}
		else{	//tree recruits, tree grows, tree ages
			do treeRecruitment();
			do treeGrowthIncrement();
			do stepAge();
		}

	}
	
	action setState{
		if(dbh < max_dbh_per_class[type][0]){
			state <- SEEDLING;
		}else if(dbh<max_dbh_per_class[type][1]){
			state <- SAPLING;
		}else if(dbh<max_dbh_per_class[type][2]){
			state <- POLE;
		}else{
			state <- ADULT;
		}
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

experiment oneplot type: gui{
	output{
		display op type: opengl camera:#isometric{
			species climate;
			species plot; 
			species trees aspect: geom3D;
			species river;
		}
	}
}