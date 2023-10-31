/**
* Name: labour
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model labour
import "university_si.gaml"

/* Insert your model definition here */

species labour{
	int OWN_LABOUR <- 0; 
	int COMM_LABOUR <- 1;
	int labor_type; 	//important when hiring community labor 
	
	list<plot> my_plots <- [];
	plot current_plot;
	list<trees> my_trees <- [];		//list of wildlings that the laborer currently carries
	list<int> man_months <- [0,0,0];	//assigned, serviced, lapsed 
	int carrying_capacity <- LABOUR_PCAPACITY;	//total number of wildlings that a laborer can carry to the nursery and to the ITP
	bool is_nursery_labour <- false;
	bool is_harvest_labour <- false;
	bool is_planting_labour <- false;
	
	aspect default{
		if(is_nursery_labour){
			draw triangle(length(my_trees)+50) color: #orange rotate: 90.0;	
		}else if(is_harvest_labour or is_planting_labour){
			draw triangle(length(my_trees)+50) color: #violet rotate: 90.0;
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
	
	reflex checkIfMustReplant when: carrying_capacity = length(my_trees){
		ask university_si{
			loop mp over: myself.my_plots{
				ask mp{
					do updateTrees;
				}
				geometry space <- mp.removeOccupiedSpace(mp.shape, mp.plot_trees);
			}
		}
		
		list<plot> available_plots <- my_plots where (each.removeOccupiedSpace(each.shape, each.plot_trees) != nil);	//all plots with remaining space
		if(length(available_plots) > 0){
			plot nursery <- available_plots closest_to current_plot;
			if(nursery != nil){
				location <- nursery.location;		//go back to the nursery and plant the trees
				current_plot <- nursery;
				do replantAlert(nursery);	
			}
		}//else, do nothing; meaning, just wait until there are available plots
	}
	
	//Invoked by labour reflex when the capacity of the laborer is reached, plant the trees to the nursery
	//Invoked by university to command labour to return and plant all that is in its hands
	//For replanting to nursery, and to the new plot (for ITP)
	action replantAlert(plot new_plot){	
		int my_trees_length <- length(my_trees);	
		geometry remaining_space <- new_plot.removeOccupiedSpace(new_plot.shape, new_plot.plot_trees);
		
		loop while: (remaining_space.area > 0 and my_trees_length > 0){	//use the same plot while there are spaces; plant while there are trees to plant
			trees to_plant <- one_of(my_trees);	//get one of the trees
			point prev_location <- to_plant.location;
			to_plant.location <- any_location_in(remaining_space);	//put plant on the location
			trees closest_tree <- new_plot.plot_trees closest_to to_plant;	//get the closest tree to the newly planted plant
			if(closest_tree != nil and (circle(closest_tree.dbh+5, closest_tree.location) overlaps circle(to_plant.dbh+5, to_plant.location))){	//if the closest tree overlaps with the tree that will be planted, do not continue planting the tree 
				ask to_plant{
					remove self from: myself.my_trees;	//remove the plant from the 
					self.location <- prev_location; 	//return the plant from where it's from
				}
			}else{	//plant the tree
				write "Type: "+to_plant.type;
				to_plant.is_new_tree <- false;
				remove to_plant from: to_plant.my_plot.plot_trees;
				to_plant.my_plot <- new_plot;	//update plot of tree
				to_plant.my_plot.plot_trees << to_plant;	//put tree to the tree list of the new_plot
				remove to_plant from: my_trees;
				geometry new_occupied_space <- circle(to_plant.dbh+5) translated_to to_plant.location;	//+5 allows for spacing between plants
				remaining_space <- remaining_space - new_occupied_space; 
			}
			my_trees_length <- my_trees_length - 1;
		}
		man_months[1] <- man_months[1]+1;
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
}