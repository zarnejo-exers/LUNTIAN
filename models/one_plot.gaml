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
	
	file trees_shapefile <- shape_file("../includes/TREES_INIT.shp");	//randomly positioned, actual
	file plot_shapefile <- shape_file("../includes/ITP_GRID_NORIVER.shp");
	file river_shapefile <- file("../includes/River_S5.shp");
	
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
			cr <- mh;
			crown_diameter <- cr; 
			
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
	float cr; 	//crown ratio, set at the reading of the data
	float crown_diameter;	//crown diameter
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
}

experiment oneplot type: gui{
	output{
		display op type: opengl camera:#isometric{
			species plot; 
			species trees aspect: geom3D;
			species river;
		}
	}
}