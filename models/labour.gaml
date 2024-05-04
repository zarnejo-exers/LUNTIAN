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
	
	plot my_assigned_plot;
	plot plot_to_harvest;	//for ITP harvesting laborer
	plot plot_to_plant; 	//for ITP planting laborer
	list<trees> harvested_trees;
	
	plot current_plot;
	list<trees> my_trees <- [];		//list of wildlings/seedlings that the laborer currently carries
	list<int> man_months <- [0,0,0];	//assigned, serviced, lapsed 
	int carrying_capacity <- LABOUR_PCAPACITY;	//total number of wildlings that a laborer can carry to the nursery and to the ITP
	
	bool is_harvest_labour <- false;
	bool is_planting_labour <- false;
	bool is_nursery_labour <- false;
	int p_t_type;	//planting tree type
	int h_t_type;	//harvesting tree type
	
	//int nursery_labour_type <- -1;	//-1 if not labour type, either NATIVE or EXOTIC
	
	int count_bought_nsaplings; 
	
//	comm_member com_identity <- nil;
	list<trees> all_seedlings_gathered <- [];  
	list<plot> to_visit_plot <- [];
	
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

	//if source_plot = nil, then it is not a nursery plot
	list<trees> plantInPlot(list<trees> trees_to_plant, plot pt_plant, plot source_plot){
		list<trees> planted_trees <- [];
		int needed_space <- (source_plot!=nil)?1:3; 
		
		geometry available_space <- removeOccSpace(pt_plant.shape, pt_plant.plot_trees, (source_plot!=nil)?true:false);
		list<geometry> available_square <- (to_squares(available_space, needed_space#m) where (each.area >= (needed_space^2)#m));
			
		//no need to fix neighborhood since replanting and nursery mgmt doesn't concern adult trees
		write "[before] count of trees in plot: "+length(pt_plant.plot_trees);
		loop tnp over: trees_to_plant{
			if(available_square != []){
				geometry sq <- available_square[0];
				if(source_plot != nil){
					remove tnp from: source_plot.plot_trees;	//remove from source_plot	
				}
				remove tnp from: self.my_trees;	//remove plant from the "bag" of the laborer
				add tnp to: pt_plant.plot_trees;	//move to pt_plant
				tnp.my_plot <- pt_plant;	//put the tree in the plot
				location <- sq.location;
				remove sq from: available_square;
				add tnp to: planted_trees;	
			}else{
				write "NO SPACE LEFT!";
				break;		
			}				
		}
		write "planted trees: "+length(planted_trees);
		write "[before] count of trees in plot: "+length(pt_plant.plot_trees);
		
		return planted_trees;
	}
	
	//the centre of the square is by default the location of the current agent in which has been called this operator.
	geometry removeOccSpace(geometry main_space, list<trees> to_remove_space, bool is_nursery){
		geometry t_shape <- nil; 
		int needed_space <- (is_nursery)?1:5;
			
		ask to_remove_space{
			t_shape <- t_shape + square(needed_space#m);
		}
			
		return main_space - t_shape;	//remove all occupied space;		
	}

//	action cutTrees(list<trees> t){
//		ask t{
//			remove self from: myself.harvested_trees;
//			remove self from: my_plot.plot_trees;
//			remove myself from: my_plot.my_laborers;
//			do die;
//		}
//		plot_to_harvest <- nil;
//	}
	
//	//find a nursery with seedling and return the plot
//	plot goToNursery{
//		list<plot> nurseries <- plot where (each.is_nursery);
//		ask nurseries{
//			if(length(plot_trees where (each.state = SAPLING)) > 0){	//the plot has seedlings
//				return self;
//			}
//		}
//		return nil;
//	}
//	
//	//harvests upto capacity
//	action selectiveHarvestITP{
//		list<trees> trees_of_species <- plot_to_harvest.plot_trees where (each.type = h_t_type);
//		list<trees> trees_to_harvest <- [];
//		
//		list<trees> tree60to70 <- trees_of_species where (each.dbh >= 60 and each.dbh < 70);
//		tree60to70 <- (tree60to70[0::int(length(tree60to70)*0.25)]);
//		if(length(tree60to70) >= carrying_capacity){//get only upto capacity
//			trees_to_harvest <- tree60to70[0::carrying_capacity];
//		}else{
//			trees_to_harvest <- tree60to70;
//			list<trees> tree70to80 <- trees_of_species where (each.dbh >= 70 and each.dbh < 80);
//			tree70to80 <- (tree70to80[0::int(length(tree70to80)*0.75)]);
//			if(length(tree70to80) >= (carrying_capacity - length(trees_to_harvest))){
//				trees_to_harvest <<+ tree70to80[0::(carrying_capacity - length(trees_to_harvest))];
//			}else{
//				list<trees> tree80up <- trees_of_species where (each.dbh >= 80);
//				if(length(tree80up) >= (carrying_capacity - length(trees_to_harvest))){
//					trees_to_harvest <<+ tree70to80[0::(carrying_capacity - length(trees_to_harvest))];
//				}else{
//					trees_to_harvest <<+ tree80up;
//				}
//			}
//			
//		}
//
//		plot_to_harvest.plot_trees <- (plot_to_harvest.plot_trees - trees_to_harvest);
//
//		man_months[1] <- man_months[1]+1;
//		current_plot <- plot_to_harvest; 
//		
//		harvested_trees <- trees_to_harvest;
//	}
	
//	action setPlotToHarvest(plot pth){
//		plot_to_harvest <- pth;
//	}
//	
//	//harvests upto capacity
//	//gets the biggest trees
//	action harvestPlot{
//		list<trees> trees_to_harvest <- [];
//		
//		if(state = "independent"){
//			carrying_capacity <- int(carrying_capacity/2);
//		}
//		
//		if(!(plot_to_harvest.my_laborers contains self)){
//			add self to: plot_to_harvest.my_laborers;	
//		}
//		trees_to_harvest <- reverse(sort_by(plot_to_harvest.plot_trees, each.dbh));
//		
//		if(trees_to_harvest != nil){	//nothing to harvest on the plot, move to another plot
//			if(length(trees_to_harvest) > carrying_capacity){
//				trees_to_harvest <- first(carrying_capacity, sort_by(plot_to_harvest.plot_trees, each.dbh));	//get only according to capacity
//			}
//					
//			plot_to_harvest.plot_trees <- (plot_to_harvest.plot_trees - trees_to_harvest);
//			ask plot_to_harvest.plot_trees{
//				age <- age + 5; 	//to correspond to TSI
//			}
//		}
//		harvested_trees <- trees_to_harvest;
//	}
	
//	action getFromNursery{
//		list<plot> nurseries <- plot where (each.is_nursery);
//		
//		int my_capacity <- carrying_capacity;
//		write "Inside assigned planter getting saplings from nurseries";
//		loop i over: nurseries{
//			if(my_capacity<1){break;}
//			list<trees> saplings <- i.plot_trees where (!dead(each) and each.state = SAPLING);	//get all the saplings from the nursery
//			if(length(saplings) = 0){continue;}
//			if(length(saplings) > my_capacity){	//laborers' capacity is less than available saplings
//				//get only what can be carried by the laborer
//				do plantInPlot(saplings[0::my_capacity], plot_to_plant, i);	//go to plot where to plant and replant the trees
//				break;
//			}else{		//laborer can carry all the saplings
//				my_capacity <- my_capacity - length(saplings);
//				do plantInPlot(saplings, plot_to_plant, i);	//go to plot where to plant and replant the trees
//			}
//		}		
//	}
//	
//	//	create #native_count new saplings
//	//	plant this new saplings on the_plot
//	action plantBoughtSaplings{
//		write "Count of bought saplings: "+count_bought_nsaplings;
//		create trees number: count_bought_nsaplings returns: bought_saplings{
//			dbh <- n_sapling_ave_DBH;
//			type <- NATIVE;
//			age <- dbh/growth_rate_exotic; 
//		}
//		
//		write "BoughtSaplings: "+bought_saplings+" - Count of trees before: "+length(plot_to_plant);
//		do plantInPlot(bought_saplings, plot_to_plant, nil);
//		write "BoughtSaplings: "+bought_saplings+" - Count of trees after: "+length(plot_to_plant);
//	}
//	
	
	//gather all seedlings from the current plot
	//randomly choose from its neighbor where it will gather seedlings 
	list<trees> gatherSeedlings(plot c_plot){
		location <- c_plot.location;
		
		list<trees> all_seedlings <- c_plot.plot_trees where (each.state = SEEDLING);
		//get only what it can carry
		if(length(all_seedlings) > carrying_capacity){
			all_seedlings <- all_seedlings[0::carrying_capacity];
		}
		
		//remove the seedlings from the plot
		ask all_seedlings{
			remove self from: my_plot.plot_trees;	//remove it from where it is currently planted
			add self to: myself.my_trees;	//my_trees is the bag of the laborer to hold the trees it had gathered
			location <- point(0,0,0);	//no location, meaning the tree is currenltly held by laborer
		}
		
		return all_seedlings;
	}

	
	state vacant initial: true{	
		transition to: manage_nursery when: is_nursery_labour;
//		transition to: assigned_itp_harvester when: (is_harvest_labour and plot_to_harvest != nil);
//		transition to: assigned_planter when: is_planting_labour;
	}
	
	state manage_nursery{
		
		ask university_si{
			do payLaborer(myself);
		}
		write "managing nursery";
		
		transition to: assigned_nursery when: ((fruiting_months_N + fruiting_months_E) contains current_month){//fruiting season, go out to gather
			add all: (plot where !each.is_nursery) to: to_visit_plot;	
		}
	}
	
	//gathers seedlings for nursery
	state assigned_nursery {
		//get another location
		list<plot> coverage <- closest_to(to_visit_plot, current_plot, 8);	//get the neighboring plots
		
		if(coverage != []){
			current_plot <- one_of(coverage);	//get a random location
			list<trees> seedlings_in_plot <- gatherSeedlings(current_plot);
			all_seedlings_gathered <<+ seedlings_in_plot;
			
			remove current_plot from: to_visit_plot;	
		}else{
			write "have harvested all possible places. nowhere to harvest";
		}

		transition to: manage_nursery when: !((fruiting_months_N + fruiting_months_E) contains current_month)
		{	//!fruiting season, return to nursery
			
			//plant first before returning to nursery
			write "Laborer "+name+" is putting all gathered seedlings to plot.";
			if(length(all_seedlings_gathered) > 0){
				location <- my_assigned_plot.location;	//put laborer back to the nursery
				current_plot <- my_assigned_plot;
				write "(before)Laborer: "+name+" my trees: "+length(my_trees);
				list<trees> planted_trees <- plantInPlot(all_seedlings_gathered, my_assigned_plot, nil);	//put to nursery all the gathered seedlings
				write "(after)Laborer: "+name+" my trees: "+length(my_trees);
				remove all: planted_trees from: all_seedlings_gathered;
			}else{
				write "Laborers: "+name+" wasn't able to gather seeds";
			}
		}
	}
	
//	//hired only once
//	state assigned_planter{
//		//go to nurseries and get trees as much as it can carry => carrying_capacity
//		write "Count of bought saplings: "+count_bought_nsaplings;
//		if(count_bought_nsaplings > 0){	//count_bought_nsaplings is the number of saplings bought by the university that is allotted to the planter for replanting
//			do plantBoughtSaplings();
//		}else{	//if there's no allotted saplings, get from the nursery # of saplings = laborer capacity
//			do getFromNursery();
//		}
//		
//		transition to: vacant when: !is_planting_labour{
//			count_bought_nsaplings <- 0;
//			plot_to_plant <- nil; 
//		}
//	    
//	    exit{
//	    	p_t_type <- -1;
//	    }
//	}
//	
//	state assigned_itp_harvester{
//		do cutTrees(harvested_trees);
//		
//		transition to: vacant when: plot_to_harvest = nil;
//	    
//	    exit{
//	    	h_t_type <- -1;
//	    }
//	}
//	
//	state independent{	//if instance of independent community member 
//		if(plot_to_harvest != nil){
//			do harvestPlot;
//			ask com_identity{
//				do completeHarvest(myself.harvested_trees);
//			}
//			do cutTrees(harvested_trees);
//		}
//		
//		transition to: assigned_itp_harvester when: is_harvest_labour;
//		transition to: assigned_planter when: is_planting_labour;
//	}
}