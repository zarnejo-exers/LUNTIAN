/**
* Name: oneplot
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model oneplot

/* Insert your model definition here */

global{
	int NATIVE <- 0;
	int EXOTIC <- 1;
	float growth_rate_exotic <- 0.10417;
	float growth_rate_native <- 0.09917;	
	
	file trees_shapefile <- shape_file("../includes/TREES_INIT_1PLOT.shp");	//randomly positioned, actual
	file plot_shapefile <- shape_file("../includes/ITP_1_PLOT.shp");
	file river_shapefile <- file("../includes/River_S5.shp");
	
	float n_sapling_ave_DBH <- 7.5;
	float e_sapling_ave_DBH <- 2.5; 
	float n_adult_ave_DBH <- 60.0;
	float e_adult_ave_DBH <- 90.0;
	
	geometry shape <- envelope(plot_shapefile);
	list<geometry> clean_lines;

	init{
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
			geometry remaining_space <- myself.removeOccSpace(shape, plot_trees);
			shape <- remaining_space;
			
			list<geometry> available_spaces <- (to_squares(remaining_space, 3#m) where (each.area >= 9#m));

			if(available_spaces != []){
				geometry sq <- available_spaces[0];
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
	float cr <- (type=0)?(1/4):(1/3);	//by default 
	float crown_diameter <- (cr*dbh) update: (cr*dbh);	//crown diameter
	float age;
	bool shade_tolerant;
	plot my_plot;
	
	aspect geom3D{
		if(crown_diameter != 0){
			//this is the crown
			if(type = 0){
				draw sphere(self.crown_diameter#ft) color: #darkgreen at: {location.x,location.y,th#ft};
			}else{
				draw sphere(self.crown_diameter#ft) color: #lightgreen at: {location.x,location.y,th#ft};
			}
			//this is the stem
			draw circle(dbh#cm) at: {location.x,location.y} color: #brown depth: th#ft;
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
}

experiment oneplot type: gui{
	output{
		display op type: opengl camera:#isometric{
			species plot; 
			//species trees aspect: geom3D;
			species river;
		}
	}
}