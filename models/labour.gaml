/**
* Name: labour
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model labour
import "university_si.gaml"

/* Insert your model definition here */

species labour control: fsm{
	int OWN_LABOUR <- 0; 
	int COMM_LABOUR <- 1;
	int labor_type; 	//important when hiring community labor 
	
	list<plot> my_plots <- [];
	plot plot_to_harvest;	//for harvesting laborer
	list<trees> harvested_trees;
	
	plot current_plot;
	list<trees> my_trees <- [];		//list of wildlings that the laborer currently carries
	list<int> man_months <- [0,0,0];	//assigned, serviced, lapsed 
	int carrying_capacity <- LABOUR_PCAPACITY;	//total number of wildlings that a laborer can carry to the nursery and to the ITP
	bool is_nursery_labour <- false;
	bool is_harvest_labour <- false;
	bool is_planting_labour <- false;
	 
	comm_member com_identity <- nil;
	
	aspect default{
		if(is_nursery_labour){
			draw triangle(length(my_trees)+50) color: #orange rotate: 90.0;	
		}else if(is_harvest_labour or is_planting_labour){
			draw triangle(length(my_trees)+50) color: #violet rotate: 90.0;
		}
		
	}
	
	aspect si{
		if(labor_type = OWN_LABOUR){
			draw circle(20, location) color: #red;	//if own labor, red; else, pink	
		}else if(labor_type = COMM_LABOUR){
			draw circle(20, location) color: #violet;	//if own labor, red; else, pink
		}
	}

	//when tree dies, it is removed from the plot but the laborer isn't aware yet that it has died	
	reflex removeDeadTrees{
		my_trees <- my_trees where !dead(each);
	}
	
	//put the laborer at the the center of one of its assigned plots
	action assignLocation{
		if(length(my_plots) = 0){
			return;
		}
		
		if(length(my_plots where each.has_road) > 0){	//one of the plot has a road, put the laborer on one of the plots with a road
			current_plot <- one_of(my_plots where each.has_road);
		}else{	//put the laborer randomly
			current_plot <- one_of(my_plots);
		}
		self.location <- current_plot.location;
	}
	
	//laborer gets as much tree as it can get 
	//returns remaining unallocated trees
	list<trees> getTrees(list<trees> treeToBeAlloc){
		if(length(treeToBeAlloc) >= self.carrying_capacity){			//there are more trees than the laborer can hold
			self.my_trees <<+ treeToBeAlloc[0::self.carrying_capacity];
			treeToBeAlloc >>- treeToBeAlloc[0::self.carrying_capacity];		
		}else{	//the number of trees isn't enough to make the laborer go back to the nursery to plant
			self.my_trees <<+ treeToBeAlloc;	//get all the trees
			treeToBeAlloc <- [];		//set the new unassigned trees to empty
		}
		
		ask self.my_trees where each.is_new_tree{	//all allocated trees are no longer new trees
			is_new_tree <- false;
		}
		return treeToBeAlloc;
	}
	
	//First, look at the neighborhood of the nursery for any plot with seedlings, if there is proceed with gathering
	//If there is none, put the laborer at the farthest position in the neighborhood so that the next time he will search on that new neighborhood
	plot findPlotWithSeedlings{
		list<plot> neighborhood <- plot at_distance 150;
		ask neighborhood{
			list<trees> seedlings <- plot_trees where (each.state = "seedling");
			if(length(seedlings) > 0){
				return self;
			}
		}		
		
		self.current_plot <- neighborhood farthest_to self;
		location <- current_plot.location;
		
		return nil;	 
	}
	
	list<trees> gatherSeedlings(plot found_plot){
		list<trees> all_seedlings <- found_plot.plot_trees where (each.state = "seedling");
		if(length(all_seedlings) > carrying_capacity){
			all_seedlings <- all_seedlings[0::carrying_capacity];
		}
		//remove the seedlings from the plot
		ask all_seedlings{
			remove self from: found_plot.plot_trees;
			add self to: myself.my_trees;	//my_trees is the bag of the laborer to hold the trees it had gathered
		}
		
		return all_seedlings;
	}
	
	action replant(list<trees> t){
		
		list<plot> to_plant_plot <- []; 
		ask university_si{
			ask myself.my_plots{
				if(length(myself.getAvailableSpaces(self, 0)) > 0){
					add self to: to_plant_plot;
				}
			}
		}
		if(length(to_plant_plot)>0){
			plot p <- one_of(to_plant_plot);
			self.current_plot <- p;
			location <- current_plot.location;
			geometry remaining_space <- p.removeOccupiedSpace(p.shape, p.plot_trees);
			loop while: (remaining_space.area > 0 and length(t) > 0){
				trees to_plant <- one_of(t);
				point prev_location <- to_plant.location;	//get location of the seedling
				to_plant.location <- any_location_in(remaining_space);	//put the seedling in one of the available location in the nursery
				//make sure it is safe to replant, meaning, it doesn't overlap a nearby tree
				trees closest_tree <-p.plot_trees closest_to to_plant;
				if(closest_tree = nil or !(circle(closest_tree.dbh+5, closest_tree.location) overlaps circle(to_plant.dbh+5, to_plant.location))){	//if the closest tree overlaps with the tree that will be planted, do not continue planting the tree
					//plant the tree
					to_plant.my_plot <- p;
					add to_plant to: to_plant.my_plot.plot_trees;
					remove to_plant from: my_trees;
					geometry new_occupied_space <- circle(to_plant.dbh+5) translated_to to_plant.location;	//+5 allows for spacing between plants
					remaining_space <- remaining_space - new_occupied_space;
					remove to_plant from: t;
				}else{
					to_plant.location <- nil;	//the tree isn't give permanent nursery location yet 
				}
			}
		}
		if(labor_type = COMM_LABOUR){
			man_months[1] <- man_months[1] + 1;
		}
	}
	
	//find a nursery with seedling and return the plot
	plot goToNursery{
		list<plot> nurseries <- plot where (each.is_nursery);
		ask nurseries{
			if(length(plot_trees where (each.state ="sapling")) > 0){	//the plot has seedlings
				return self;
			}
		}
		return nil;
	}
	
	//harvests upto capacity
	action selectiveHarvestITP{
		list<trees> trees_to_harvest <- [];
		
		list<trees> tree60to70 <- plot_to_harvest.plot_trees where (each.dbh >= 30 and each.dbh < 40); //(each.dbh >= 60 and each.dbh < 70);
		tree60to70 <- (tree60to70[0::int(length(tree60to70)*0.25)]);
		if(length(tree60to70) >= carrying_capacity){//get only upto capacity
			trees_to_harvest <- tree60to70[0::carrying_capacity];
		}else{
			trees_to_harvest <- tree60to70;
			list<trees> tree70to80 <- plot_to_harvest.plot_trees where (each.dbh >= 40 and each.dbh < 50);//(each.dbh >= 70 and each.dbh < 80);
			tree70to80 <- (tree70to80[0::int(length(tree70to80)*0.75)]);
			if(length(tree70to80) >= (carrying_capacity - length(trees_to_harvest))){
				trees_to_harvest <<+ tree70to80[0::(carrying_capacity - length(trees_to_harvest))];
			}else{
				list<trees> tree80up <- plot_to_harvest.plot_trees where (each.dbh >= 50);// (each.dbh >= 80);
				if(length(tree80up) >= (carrying_capacity - length(trees_to_harvest))){
					trees_to_harvest <<+ tree70to80[0::(carrying_capacity - length(trees_to_harvest))];
				}else{
					trees_to_harvest <<+ tree80up;
				}
			}
			
		}

		plot_to_harvest.plot_trees <- (plot_to_harvest.plot_trees - trees_to_harvest);
		ask plot_to_harvest.plot_trees{
			age <- age + 5; 	//to correspond to TSI
		}
		if(labor_type = COMM_LABOUR){
			man_months[1] <- man_months[1]+1;
			current_plot <- plot_to_harvest;
		} 
		
		harvested_trees <- trees_to_harvest;
	}
	
	list<trees> gatherSaplings(plot nursery){
		return (nursery.plot_trees where (each.state = "sapling"));
	}
	
	action setPlotToHarvest(plot pth){
		plot_to_harvest <- pth;
	}
	
	action cutTrees(list<trees> t){
		ask t{
			remove self from: myself.harvested_trees;
			remove self from: my_plot.plot_trees;
			do die;
		}
	}
	
	//harvests upto capacity
	//gets the biggest trees
	action harvestPlot{
		list<trees> trees_to_harvest <- [];
		
		if(!(plot_to_harvest.my_laborers contains self)){
			add self to: plot_to_harvest.my_laborers;	
		}
		trees_to_harvest <- reverse(sort_by(plot_to_harvest.plot_trees, each.dbh));
		
		if(trees_to_harvest != nil){	//nothing to harvest on the plot, move to another plot
			if(length(trees_to_harvest) > carrying_capacity){
				trees_to_harvest <- first(carrying_capacity, sort_by(plot_to_harvest.plot_trees, each.dbh));	//get only according to capacity
			}
					
			plot_to_harvest.plot_trees <- (plot_to_harvest.plot_trees - trees_to_harvest);
			ask plot_to_harvest.plot_trees{
				age <- age + 5; 	//to correspond to TSI
			}
		}
		harvested_trees <- trees_to_harvest;
	}
	
	state vacant initial: true{	
		transition to: assigned_nursery when: is_nursery_labour;
		transition to: assigned_itp_harvester when: (is_harvest_labour and plot_to_harvest != nil);
		transition to: assigned_itp_planter when: is_planting_labour;
	}
	
	state assigned_nursery {
		plot found_plot <- findPlotWithSeedlings();
		if(found_plot!=nil){
			list<trees> seedlings_gathered <- gatherSeedlings(found_plot);
			do replant(seedlings_gathered);
		} 
	}
	
	state assigned_itp_planter{
		plot nursery <- goToNursery();
		if(nursery != nil){
			list<trees> saplings_gathered <- gatherSaplings(nursery); 
			do replant(saplings_gathered);
		}
		if(com_identity != nil){	//meaning, laborer is an instance of community
			ask university_si{
				write "Paying laborer: current earning (before) - "+myself.com_identity.current_earning;
				do payLaborer(myself);
				write "Paying laborer: current earning (after) - "+myself.com_identity.current_earning;
			}
		}
		transition to: vacant when: !is_planting_labour;
	}
	
	state assigned_itp_harvester{
		do selectiveHarvestITP;
	    ask university_si{
	    	do completeITPHarvest(myself.harvested_trees, myself);
	    }
	    do cutTrees(harvested_trees);
		transition to: vacant when: !is_harvest_labour;
	}
	
	state independent{	//if instance of independent community member 
		if(plot_to_harvest != nil){
			do harvestPlot;
			ask com_identity{
				do completeHarvest(myself.harvested_trees);
			}
			do cutTrees(harvested_trees);
		}
		
		transition to: assigned_itp_harvester when: is_harvest_labour;
		transition to: assigned_itp_planter when: is_planting_labour;
	}
}