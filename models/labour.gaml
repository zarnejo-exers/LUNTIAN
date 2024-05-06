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
	list<trees> marked_trees;	//filled 
	
	plot current_plot;
	list<trees> my_trees <- [];		//list of wildlings/seedlings that the laborer currently carries
	list<int> man_months <- [0,0,0];	//assigned, serviced, lapsed 
	int carrying_capacity <- LABOUR_TCAPACITY;	//total number of wildlings that a laborer can carry to the nursery and to the ITP
	list<geometry> planting_spaces <- [];	//exact spaces where to plant the saplings for ITP
	
	bool is_harvest_labour <- false;
	bool is_planting_labour <- false;
	bool is_nursery_labour <- false;
	int p_t_type;	//planting tree type
	int h_t_type;	//harvesting tree type
 	
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
	list<trees> plantInPlot(list<trees> trees_to_plant, plot pt_plant){
		list<trees> planted_trees <- [];
		list<geometry> available_square <- [];
		ask university_si{
			 available_square <- getSquareSpaces(pt_plant.shape, pt_plant.plot_trees, false, 1);	//1 is for recruitment since the plants are randomly positioned	
		}
		
		//no need to fix neighborhood since replanting and nursery mgmt doesn't concern adult trees
		loop tnp over: trees_to_plant{
			if(available_square != []){
				geometry sq <- available_square[0];
				remove tnp from: self.my_trees;	//remove plant from the "bag" of the laborer
				add tnp to: pt_plant.plot_trees;	//move to pt_plant
				tnp.my_plot <- pt_plant;	//put the tree in the plot
				tnp.location <- sq.location;
				remove sq from: available_square;
				add tnp to: planted_trees;	
			}else{
				write "NO SPACE LEFT!";
				break;		
			}				
		}
		
		return planted_trees;
	}

	action cutMarkedTrees{
		ask marked_trees{
			remove self from: my_plot.plot_trees;
			remove myself from: my_plot.my_laborers;
			do die;
		}
		remove all: marked_trees from: marked_trees;
	}	
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
	
	action gatherSaplings{
		list<trees> saplings_in_nurseries <- my_trees where (each.my_plot != nil);	//trees without plot are bought saplings
		
		ask saplings_in_nurseries{
			remove self from: my_plot.plot_trees;
			location <- point(0,0,0);
		}
	}
	
	action plantInSquare{
		list<trees> planted_trees <- [];
		loop tnp over: my_trees{
			if(planting_spaces != []){
				geometry sq <- planting_spaces[0];
				add tnp to: my_assigned_plot.plot_trees;	//move to pt_plant
				tnp.my_plot <- my_assigned_plot;	//put the tree in the plot
				tnp.location <- sq.location;
				remove sq from: planting_spaces;
				add tnp to: planted_trees;
			}else{
				write "NO SPACE LEFT!";
				break;		
			}				
		}
		
		remove all: planted_trees from: my_trees;
	}

	
	state vacant initial: true{	
		location <- point(0,0,0);
		transition to: manage_nursery when: is_nursery_labour;
		transition to: assigned_itp_harvester when: (is_harvest_labour and my_assigned_plot != nil);	//my_assigned_plot is an ITP plot
		transition to: assigned_planter when: is_planting_labour;
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
		ask university_si{
			do payLaborer(myself);
		}

		transition to: manage_nursery when: !((fruiting_months_N + fruiting_months_E) contains current_month)
		{	//!fruiting season, return to nursery
			
			//plant first before returning to nursery
			write "Laborer "+name+" is putting all gathered seedlings to plot.";
			if(length(all_seedlings_gathered) > 0){
				location <- my_assigned_plot.location;	//put laborer back to the nursery
				current_plot <- my_assigned_plot;
				list<trees> planted_trees <- plantInPlot(all_seedlings_gathered, my_assigned_plot);	//put to nursery all the gathered seedlings
				remove all: planted_trees from: all_seedlings_gathered;
				ask university_si{
					do payLaborer(myself);
				}
			}else{
				write "Laborers: "+name+" wasn't able to gather seeds";
			}
		}
	}
	
	//ITP planter
	state assigned_planter{
		//go to nurseries and get trees as much as it can carry => carrying_capacity
		write "Count of saplings to plant: "+length(my_trees);
		do gatherSaplings();
		do plantInSquare();
		ask university_si{
			do payLaborer(myself);
		}
		
		transition to: vacant{
			remove self from: my_assigned_plot.my_laborers;
			my_assigned_plot <- nil;
			current_plot <- nil;
			is_planting_labour <- false;	
		}
	}
	
	//stays in this state for 1 step only
	state assigned_itp_harvester{
		do cutMarkedTrees();
		
		//COST: 
		//3. pay hired harvesters 1month worth of wage
		ask university_si{
			do payLaborer(myself);
		}
		
		transition to: vacant{
			remove self from: my_assigned_plot.my_laborers;
			my_assigned_plot <- nil;
			current_plot <- nil;
			is_harvest_labour <- false;	
		}
	}
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