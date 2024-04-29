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
	
	float growth_rate_exotic <- 0.10417;
	float growth_rate_native <- 0.09917;	
	
	file trees_shapefile <- shape_file("../includes/TREES_1PLOT.shp");	//mixed species
	file plot_shapefile <- shape_file("../includes/ITP_GRID_1PLOT.shp");
	file river_shapefile <- file("../includes/River_S5.shp");
	file Precip_TAverage <- file("../includes/CLIMATE_COMP.shp"); // Monthly_Prec_TAvg, Temperature in Celsius, Precipitation in mm, total mm of ET0 per month
	
	float n_sapling_ave_DBH <- 7.5;
	float e_sapling_ave_DBH <- 2.5; 
	float n_adult_ave_DBH <- 60.0;
	float e_adult_ave_DBH <- 90.0;
	map<int, list<float>> max_dbh_per_class <- map<int,list>([NATIVE::[5.0,10.0,20.0,100.0],EXOTIC::[1.0,5.0,30.0,150.0]]);
	
	map<point, climate> cell_climate;
	int current_month <- 0 update:(cycle mod NB_TS);
	
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
			available_space <- myself.removeOccSpace(available_space, plot_trees);
			list<geometry> available_square <- (to_squares(available_space, 3#m) where (each.area >= 9#m));

			if(available_square != []){
				geometry sq <- available_square[0];
				create trees number: 1 returns: new_trees{
					dbh <- n_sapling_ave_DBH;
					type <- NATIVE;
					age <- dbh/growth_rate_exotic; 
					location <- sq.location;
					th <- calculateHeight(dbh, type);
					my_plot <- myself;	//assigns the plot where the tree is located
				}
				plot_trees <- plot_trees + new_trees;
				write "Created "+length(new_trees)+" trees. Area: "+sq.area;	
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
	geometry available_space <- shape;
	climate closest_clim;
	
	aspect default{
		draw shape color: rgb(153,136,0);
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
	
	float cr <- (type=0)?(1/4):(1/3);	//by default 
	float crown_diameter <- (cr*dbh) update: (cr*dbh);	//crown diameter
	float basal_area <- 0.0 update: ((dbh/2.54)^2) * 0.005454;	//calculate basal area before calculating dbh increment; in m2
	
	aspect geom3D{
		if(crown_diameter != 0){
			//this is the crown
			if(type = 0){
				draw sphere(self.crown_diameter#ft) color: #darkgreen at: {location.x,location.y,th#ft};
			}else{
				draw sphere(self.crown_diameter#ft) color: #lightgreen at: {location.x,location.y,th#ft};
			}
			//this is the stem
			
			switch state{
				match SEEDLING{
					draw circle(dbh#cm) at: {location.x,location.y} color: #yellow depth: th#ft;		
				}
				match SAPLING{
					draw circle(dbh#cm) at: {location.x,location.y} color: #green depth: th#ft;
				}
				match POLE{
					draw circle(dbh#cm) at: {location.x,location.y} color: #blue depth: th#ft;
				}
				match ADULT{
					draw circle(dbh#cm) at: {location.x,location.y} color: #red depth: th#ft;
				}
			}
			
		}	
	}
	
	float calculateHeight(float temp_dbh, int t_type){
		float predicted_height; 
		switch t_type{
			match EXOTIC {
				//in meters
				predicted_height <- (1.3 + (12.3999 * (1 - exp(-0.105*temp_dbh)))^1.79);	///Downloads/BKrisnawati1110.pdf 
			}
			match NATIVE {
				predicted_height <- (1.3 + (temp_dbh / (1.7116 + (0.3415 * temp_dbh)))^3);	//https://d-nb.info/1002231884/34		
			}
		}
		
		return predicted_height *3.28084;	//convert to feet	
	}

	//growth of tree
	//assume: growth coefficient doesn't apply on plots for ITP 
	//note: monthly increment 
	//returns diameter_increment
	float computeDiameterIncrement(float neighbor_impact){
		if(type = EXOTIC){ //mahogany 
			write "closest clim is: "+my_plot.closest_clim+" to: "+self.name;
			float precip_value <- my_plot.closest_clim.precipitation[current_month];
			float etp_value <- my_plot.closest_clim.etp[current_month];
			
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
	
		//doesn't yet inhibit growth of tree
	action treeGrowthIncrement{
		trees closest_tree <-(my_plot.plot_trees closest_to self); 
		float prev_dbh <- dbh;
		float prev_th <- th;
		
		diameter_increment <- computeDiameterIncrement(neighborh_effect);
		dbh <- dbh + diameter_increment;	 
		th <- calculateHeight(dbh, type);
	}
	
	//tree age
	//once the tree reaches 5 years old, it cannot be moved to a nursery anymore
	action stepAge {
		age <- age + (1/12);
	}
	
	//based on Vanclay(1994) schematic representation of growth model
	reflex growthModel{
		bool is_dead <- false;
//		if((my_plot.is_nursery and age>3) or (!my_plot.is_nursery)){	//determine mortality
//			if(checkMortality()){
//				remove self from: my_plot.plot_trees;
//				is_dead <- true;
//				do die;	
//			}
//		}
		if(!is_dead){	//tree recruits, tree grows, tree ages
			//do treeRecruitment();
			do treeGrowthIncrement();
			do stepAge();
		}
	}
	
	reflex updateTreeClass{
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