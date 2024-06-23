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
	bool is_managing_labour <- false;
 	
	comm_member com_identity <- nil;
	list<trees> all_seedlings_gathered <- [];  
	list<plot> to_visit_plot <- [];
	
	float total_earning <- 0.0;		//total earning for the entire simulation
	int count_of_colaborers <- 1 update: (my_assigned_plot != nil)?length(my_assigned_plot.my_laborers):1;
	
	aspect default{
		if(labor_type = OWN_LABOUR){
			draw teapot(5) color: #orange rotate: 90.0;	
		}
	}

	//if source_plot = nil, then it is not a nursery plot
	list<trees> plantInPlot(list<trees> trees_to_plant, plot pt_plant){
		list<trees> planted_trees <- [];
		list<geometry> available_square <- [];
		ask university_si{
			 available_square <- getSquareSpaces(pt_plant.shape, pt_plant.plot_trees, false);	
		}
		//no need to fix neighborhood since replanting and nursery mgmt doesn't concern adult trees
		loop tnp over: trees_to_plant{
			if(available_square != []){
				geometry sq <- available_square[0];
				remove tnp from: self.my_trees;	//remove plant from the "bag" of the laborer
				add tnp to: pt_plant.plot_trees;	//move to pt_plant
				tnp.my_plot <- pt_plant;	//put the tree in the plot
				tnp.location <- any_location_in(sq.location);
				remove sq from: available_square;
				add tnp to: planted_trees;	
			}else{
//				write "NO SPACE LEFT in plot: "+pt_plant.name;
				break;		
			}				
		}
		
		return planted_trees;
	}

	action cutMarkedTrees{
		ask marked_trees{
			remove self from: my_plot.plot_trees;
			if(myself in my_plot.my_laborers){
				remove myself from: my_plot.my_laborers;	
			}
			do die;
		}
		remove all: marked_trees from: marked_trees;
	}	
	//gather all seedlings from the current plot
	//randomly choose from its neighbor where it will gather seedlings 
	list<trees> gatherSeedlings(plot c_plot, int current_seedlings_count){
		int space_for_new_seedlings <- (carrying_capacity > current_seedlings_count)?(carrying_capacity-current_seedlings_count): 0;
		if(space_for_new_seedlings > 0){
			location <- any_location_in(c_plot.location);
			
			list<trees> all_seedlings <- c_plot.plot_trees where (each.state = SEEDLING);
			//get only what it can carry
			if(length(all_seedlings) > space_for_new_seedlings){
				all_seedlings <- all_seedlings[0::space_for_new_seedlings];
			}
			
			//remove the seedlings from the plot
			ask all_seedlings{
				remove self from: c_plot.plot_trees;	//remove it from where it is currently planted
				add self to: myself.my_trees;	//my_trees is the bag of the laborer to hold the trees it had gathered
				location <- point(0,0,0);	//no location, meaning the tree is currenltly held by laborer
				my_plot <- nil;
			}
			
			return all_seedlings;	
		}
		return nil;
	}
	
	action plantInSquare{
		list<trees> planted_trees <- [];
		loop tnp over: my_trees{
			if(planting_spaces != []){
				geometry sq <- planting_spaces[0];
				if(tnp.my_plot != nil){
					remove tnp from: tnp.my_plot.plot_trees;	
				}
				add tnp to: my_assigned_plot.plot_trees;	//move to pt_plant
				tnp.my_plot <- my_assigned_plot;	//put the tree in the plot
				tnp.location <- any_location_in(sq.location);
				remove sq from: planting_spaces;
				add tnp to: planted_trees;
			}else{
//				write "NO SPACE LEFT!";
				break;		
			}				
		}
		
		remove all: planted_trees from: my_trees;
	}

	
	state vacant initial: true{	
		location <- point(0,0,0);
		transition to: manage_nursery when: is_nursery_labour;
		transition to: management_invested_plot when: (is_managing_labour and my_assigned_plot!=nil);
		transition to: assigned_itp_harvester when: (is_harvest_labour and my_assigned_plot != nil);	//my_assigned_plot is an ITP plot
		transition to: assigned_planter when: is_planting_labour;
	}
	
	state manage_nursery{
		ask university_si{
			if(myself.count_of_colaborers > 0){
				do payLaborer(myself, MD_NURSERY_MAINTENANCE/myself.count_of_colaborers);	//maintenance of seedlings: 8.64 mandays	
			}
		}
		
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
			location <- any_location_in(current_plot.location);
			list<trees> seedlings_in_plot <- gatherSeedlings(current_plot, length(all_seedlings_gathered));
			all_seedlings_gathered <<+ seedlings_in_plot;
			remove current_plot from: to_visit_plot;	
		}
		ask university_si{
			if(myself.count_of_colaborers > 0){
				do payLaborer(myself, MD_NURSERY_PREPARATION/myself.count_of_colaborers);	//gathering and preparation of soil
			}
		}

		transition to: manage_nursery when: !((fruiting_months_N + fruiting_months_E) contains current_month)
		{	//!fruiting season, return to nursery
			
			//plant first before returning to nursery
			if(length(all_seedlings_gathered) > 0){
				location <- any_location_in(my_assigned_plot.location);	//put laborer back to the nursery
				current_plot <- my_assigned_plot;
				list<trees> planted_trees <- plantInPlot(all_seedlings_gathered, my_assigned_plot);	//put to nursery all the gathered seedlings
				remove all: planted_trees from: all_seedlings_gathered;
				ask university_si{
					if(myself.count_of_colaborers > 0){
						do payLaborer(myself, MD_NURSERY_PLANTING/myself.count_of_colaborers);	//sowing of seed + potting of seedlings
					}
				}
			}
		}
	}
	
	//ITP planter
	state assigned_planter{
		do plantInSquare();
		ask university_si{
			if(myself.count_of_colaborers > 0){
				do payLaborer(myself, MD_ITP_PLANTING/myself.count_of_colaborers);	//assigned planter mandays
			}
		}
		transition to: vacant{
			if(my_assigned_plot.is_ANR){
				my_assigned_plot.is_ANR <- false;
			}
			remove self from: my_assigned_plot.my_laborers;
			my_assigned_plot <- nil;
			current_plot <- nil;
			is_planting_labour <- false;	
			location <- point(0,0,0);
		}
	}
	
	//stays in this state for 1 step only
	state assigned_itp_harvester{
		float harvested_bdft <- 0.0;
		//COST: 
		//3. pay hired harvesters 1month worth of wage
		ask market {
			harvested_bdft <- getTotalBDFT(myself.marked_trees);
		}
		ask university_si{
			do payLaborer(myself, harvested_bdft);
		}
		
		do cutMarkedTrees();
		
		transition to: vacant{
			if(my_assigned_plot.is_harvested){
				my_assigned_plot.is_harvested <- false;
			}
			remove self from: my_assigned_plot.my_laborers;
			my_assigned_plot <- nil;
			current_plot <- nil;
			is_harvest_labour <- false;	
		}
	}
	
	//commitment granted is only 6 months, transitions to vacant after 6 months 
	state management_invested_plot{
		enter{
			int month <- 0;
		}
		
		ask university_si{
			if(myself.count_of_colaborers > 0){
				do payLaborer(myself, MD_INVESTED_MAINTENANCE/myself.count_of_colaborers);	
			}
		}
		
		transition to: vacant when: month = 5;	//commitment is only 6 months
		month <- month + 1;
		
		exit{
			is_managing_labour <- false;
			remove self from: my_assigned_plot.my_laborers;
			my_assigned_plot <- nil;
		}
	}
	
	state independent{	//if instance of independent community member 
		enter{
			int month <- 0;
		}
		if(my_assigned_plot != nil and length(marked_trees) > 0 and month = 1){
			location <- any_location_in(my_assigned_plot.location);
			ask com_identity{
				do computeEarning();
			}
			do cutMarkedTrees();
		}else{
			month <- 1;
		}
	}
}