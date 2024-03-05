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
	plot plot_to_harvest;	//for ITP harvesting laborer
	plot plot_to_plant; 	//for ITP planting laborer
	list<trees> harvested_trees;
	
	plot current_plot;
	list<trees> my_trees <- [];		//list of wildlings that the laborer currently carries
	list<int> man_months <- [0,0,0];	//assigned, serviced, lapsed 
	int carrying_capacity <- LABOUR_PCAPACITY;	//total number of wildlings that a laborer can carry to the nursery and to the ITP
	
	bool is_harvest_labour <- false;
	bool is_planting_labour <- false;
	bool is_nursery_labour <- false;
	int p_t_type;	//planting tree type
	int h_t_type;	//harvesting tree type
	
	int nursery_labour_type <- -1;	//-1 if not labour type, either NATIVE or EXOTIC
	
	int count_bought_nsaplings; 
	
	comm_member com_identity <- nil;
	list<trees> all_seedlings_gathered <- [];  
	list<plot> visited_plot <- [];
	
	float total_earning <- 0.0;		//total earning for the entire simulation
	
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
			list<trees> seedlings <- plot_trees where (each.state = SEEDLING);
			if(length(seedlings) > 0){
				return self;
			}
		}		
		
		current_plot <- neighborhood farthest_to self;
		location <- current_plot.location;
		
		return nil;	 
	}
	
	//gather all seedlings from the current plot
	list<trees> gatherSeedlings(plot curr_plot){
		list<trees> c_trees <- curr_plot.plot_trees where !dead(each);
		list<trees> all_seedlings <- c_trees where (each.state = SEEDLING);
		list<plot> coverage <- closest_to(plot, curr_plot, 8);	//a single nursery laborer can scan 9 neighborhoods in 1 month
		
		loop c_plot over: coverage{
			c_trees <- c_plot.plot_trees where !dead(each);
			if(length(all_seedlings) > carrying_capacity){
				all_seedlings <- all_seedlings[0::carrying_capacity];
				break;
			}else{
				all_seedlings <- all_seedlings + (c_trees where (each.state = SEEDLING));
			}
		}
		
		//remove the seedlings from the plot
		ask all_seedlings{
			remove self from: self.my_plot.plot_trees;
			add self to: myself.my_trees;	//my_trees is the bag of the laborer to hold the trees it had gathered
			location <- nil;
		}
		
		return all_seedlings;
	}
	
	list<trees> plantInPlot(list<trees> trees_to_plant, plot pt_plant, plot source_plot){
		pt_plant.plot_trees <- pt_plant.plot_trees where !dead(each);
		list<trees> ttp <- trees_to_plant where !dead(each);
		self.current_plot <- pt_plant;
		int i <- 0;
		geometry remaining_space <- pt_plant.removeTreeOccupiedSpace(pt_plant.shape, pt_plant.plot_trees);
		loop while: (remaining_space != nil and (remaining_space.area > 0 and length(ttp) > 0)){
			trees to_plant <- first(ttp);
			if(to_plant != nil){
				to_plant.location <- any_location_in(remaining_space);	//put the seedling in one of the available location in the nursery
				geometry to_plant_area <- circle(to_plant.dbh+5) translated_to to_plant.location;	//+5 allows for spacing between plants
				trees closest_tree <-pt_plant.plot_trees closest_to to_plant;
					
				//make sure it is safe to replant, meaning, it doesn't overlap a nearby tree
				if(closest_tree = nil or (closest_tree != nil and !(circle(closest_tree.dbh+5, closest_tree.location) overlaps to_plant_area))){	//if the closest tree overlaps with the tree that will be planted, do not continue planting the tree		
					//plant the tree
					to_plant.my_plot <- pt_plant;
					add to_plant to: pt_plant.plot_trees;
					ask university_si{
						total_seedlings_replanted <- total_seedlings_replanted + 1;
					}
					remove to_plant from: my_trees;
					if(source_plot != nil){
						remove to_plant from: source_plot.plot_trees;
					}
					i <- i+1;
					write "Replanting tree: "+to_plant.name;
					remove to_plant from: ttp;
					write "TTP: "+ttp;
				}	
				remaining_space <- remaining_space - to_plant_area;	//remove the area from remaining space
			}
		}
		write "Total planted trees: "+i+" in plot: "+pt_plant.name;
		return ttp;
	}

	action cutTrees(list<trees> t){
		ask t{
			remove self from: myself.harvested_trees;
			remove self from: my_plot.plot_trees;
			remove myself from: my_plot.my_laborers;
			do die;
		}
		plot_to_harvest <- nil;
	}
	
	//find a nursery with seedling and return the plot
	plot goToNursery{
		list<plot> nurseries <- plot where (each.is_nursery);
		ask nurseries{
			if(length(plot_trees where (each.state = SAPLING)) > 0){	//the plot has seedlings
				return self;
			}
		}
		return nil;
	}
	
	//harvests upto capacity
	action selectiveHarvestITP{
		list<trees> trees_of_species <- plot_to_harvest.plot_trees where (each.type = h_t_type);
		list<trees> trees_to_harvest <- [];
		
		list<trees> tree60to70 <- trees_of_species where (each.dbh >= 60 and each.dbh < 70);
		tree60to70 <- (tree60to70[0::int(length(tree60to70)*0.25)]);
		if(length(tree60to70) >= carrying_capacity){//get only upto capacity
			trees_to_harvest <- tree60to70[0::carrying_capacity];
		}else{
			trees_to_harvest <- tree60to70;
			list<trees> tree70to80 <- trees_of_species where (each.dbh >= 70 and each.dbh < 80);
			tree70to80 <- (tree70to80[0::int(length(tree70to80)*0.75)]);
			if(length(tree70to80) >= (carrying_capacity - length(trees_to_harvest))){
				trees_to_harvest <<+ tree70to80[0::(carrying_capacity - length(trees_to_harvest))];
			}else{
				list<trees> tree80up <- trees_of_species where (each.dbh >= 80);
				if(length(tree80up) >= (carrying_capacity - length(trees_to_harvest))){
					trees_to_harvest <<+ tree70to80[0::(carrying_capacity - length(trees_to_harvest))];
				}else{
					trees_to_harvest <<+ tree80up;
				}
			}
			
		}

		plot_to_harvest.plot_trees <- (plot_to_harvest.plot_trees - trees_to_harvest);

		man_months[1] <- man_months[1]+1;
		current_plot <- plot_to_harvest; 
		
		harvested_trees <- trees_to_harvest;
	}
	
	action setPlotToHarvest(plot pth){
		plot_to_harvest <- pth;
	}
	
	//harvests upto capacity
	//gets the biggest trees
	action harvestPlot{
		list<trees> trees_to_harvest <- [];
		
		if(state = "independent"){
			carrying_capacity <- int(carrying_capacity/2);
		}
		
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
	
	action getFromNursery{
		list<plot> nurseries <- plot where (each.is_nursery);
		
		int my_capacity <- carrying_capacity;
		write "Inside assigned planter getting saplings from nurseries";
		loop i over: nurseries{
			if(my_capacity<1){break;}
			list<trees> saplings <- i.plot_trees where (!dead(each) and each.state = SAPLING);	//get all the saplings from the nursery
			if(length(saplings) = 0){continue;}
			if(length(saplings) > my_capacity){	//laborers' capacity is less than available saplings
				//get only what can be carried by the laborer
				do plantInPlot(saplings[0::my_capacity], plot_to_plant, i);	//go to plot where to plant and replant the trees
				break;
			}else{		//laborer can carry all the saplings
				my_capacity <- my_capacity - length(saplings);
				do plantInPlot(saplings, plot_to_plant, i);	//go to plot where to plant and replant the trees
			}
		}		
	}
	
	//	create #native_count new saplings
	//	plant this new saplings on the_plot
	action plantBoughtSaplings{
		write "Count of bought saplings: "+count_bought_nsaplings;
		create trees number: count_bought_nsaplings returns: bought_saplings{
			dbh <- n_sapling_ave_DBH;
			type <- NATIVE;
			age <- dbh/growth_rate_exotic; 
		}
		
		write "BoughtSaplings: "+bought_saplings+" - Count of trees before: "+length(plot_to_plant);
		bought_saplings <- plantInPlot(bought_saplings, plot_to_plant, nil);
		write "BoughtSaplings: "+bought_saplings+" - Count of trees after: "+length(plot_to_plant);
	}
	
	state vacant initial: true{	
		transition to: assigned_nursery when: nursery_labour_type != -1;
		transition to: manage_nursery when: (is_nursery_labour and nursery_labour_type = -1);
		transition to: assigned_itp_harvester when: (is_harvest_labour and plot_to_harvest != nil);
		transition to: assigned_planter when: is_planting_labour;
	}
	
	state manage_nursery{
		
		ask university_si{
			do payLaborer(myself);
		}
		
		transition to: vacant when: (fruiting_months_N + fruiting_months_E) contains current_month{
			is_nursery_labour <- false;
		}
	}
	
	state assigned_nursery {
		list<trees> seedlings_in_plot <- gatherSeedlings(current_plot); 
		ask seedlings_in_plot{
			add self to: myself.all_seedlings_gathered;
		} 
		add current_plot to: visited_plot;
		current_plot <- (plot-visited_plot) closest_to current_plot;
		//get another location
			 		
		transition to: vacant when: !((fruiting_months_N + fruiting_months_E) contains current_month){	//stop gathering of seedlings once fruiting month has ended
			write "---Putting all gathered seedlings to plot---";
			if(length(all_seedlings_gathered) > 0){
				plot n_plot <- nil;
				ask university_si{
					n_plot <- one_of(my_nurseries where (each.nursery_type = myself.nursery_labour_type));	
				}
				if(n_plot != nil){	//if n_plot = nil, the nursery laborer just manages the nursery and doesn't have anything to replant
					do plantInPlot(all_seedlings_gathered, n_plot, nil);	//put to nursery all the gathered seedlings
					all_seedlings_gathered <- [];
					visited_plot <- [];
					nursery_labour_type <- -1;	
				}
				
			}else{
				write "Nursery laborers wasn't able to gather seeds";
			}
			is_nursery_labour <- false;
		}
	}
	
	//hired only once
	state assigned_planter{
		//go to nurseries and get trees as much as it can carry => carrying_capacity
		write "Count of bought saplings: "+count_bought_nsaplings;
		if(count_bought_nsaplings > 0){	//count_bought_nsaplings is the number of saplings bought by the university that is allotted to the planter for replanting
			do plantBoughtSaplings();
		}else{	//if there's no allotted saplings, get from the nursery # of saplings = laborer capacity
			do getFromNursery();
		}
		
		transition to: vacant when: !is_planting_labour{
			count_bought_nsaplings <- 0;
			plot_to_plant <- nil; 
		}
	    
	    exit{
	    	p_t_type <- -1;
	    }
	}
	
	state assigned_itp_harvester{
		do cutTrees(harvested_trees);
		
		transition to: vacant when: plot_to_harvest = nil;
	    
	    exit{
	    	h_t_type <- -1;
	    }
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
		transition to: assigned_planter when: is_planting_labour;
	}
}