/**
* Name: commmember
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model comm_member
import "university_si.gaml"

/* Insert your model definition here */
global{
	int member_count <- 15 update: member_count;
	int waiting_allowance <- 12 update: waiting_allowance;
	int MAX_WAITING_COMMITMENT <- 6;	//in months
	
	init{
		create comm_member number: member_count{
			create labour{
				self.com_identity <- myself;
				labor_type <- COMM_LABOUR;
				my_assigned_plot <- nil;
				myself.instance_labour <- self;
			}
		}
	}
}

species comm_member control: fsm{
	labour instance_labour; 
	float total_earning <- 0.0;		//total earning for the entire simulation
	float current_earning <- 0.0; //earning of the community at the current commitment
	
	//for independent community members
	int success <- 0;
	int caught <- 0; 
	bool is_caught <- false;
	
	float min_earning <- 0.0; 
	
	aspect default{
		if(state = "independent_harvesting"){
			draw squircle(5,5) color: #royalblue;	
		}else{
			draw teapot(5) color: #darkblue;
		}
		
	}
	
	reflex updateLocation {
		if(instance_labour.my_assigned_plot != nil){
			location <- any_location_in(instance_labour.my_assigned_plot);	
		}else{
			location <- point(0,0,0);
		}
	}
		
	//get the total number of comm_member with current earning greater than own current earning
	//if there exist even 1, return true (meaning, someone has better earning than self)
	bool hasCompetingEarner{
		list<comm_member> competitors <- comm_member where (each.state = "independent_harvesting");
		int number_of_better_earner <- length(competitors where (each.current_earning > self.current_earning));
		return (number_of_better_earner > (0.5*length(competitors)));	//return true if the # of better earning competitors is greater than half of the total number of competitors
	}
	
	//get a plot where to harvest that isn't occupied by laborers yet
	action findPlot{
		list<plot> harvested_plots <- (plot where (length(each.my_laborers) > 0)) + (comm_member collect each.instance_labour.my_assigned_plot);
		list<plot> open_plots <- plot-harvested_plots;
		
		if(length(open_plots) > 0){
			if(instance_labour.my_assigned_plot != nil){	//meaning, the laborer has harvested already; //get the closest plot
				instance_labour.my_assigned_plot <- open_plots closest_to(instance_labour.my_assigned_plot);
			}else{	//laborer's first time to harvest
				list<comm_member> not_cooperating_members <- (comm_member-self) where (each.state = "independent_harvesting" and each.instance_labour.my_assigned_plot != nil);
				
				if(length(not_cooperating_members) > 0){	//randomly choose from the harvested plots which among them to be close to
					instance_labour.my_assigned_plot <- open_plots closest_to(one_of(not_cooperating_members collect each.instance_labour.my_assigned_plot));		
				}else{	//get randomly from the fringe plots
					instance_labour.my_assigned_plot <- one_of(entrance_plots where (!(each in harvested_plots)));
				}
			}	
		}	
	}
	
	bool probaHarvest{
		if(success = caught){return flip(0.5);}
		if(success > caught){return flip(0.5+(0.5*caught/success));}	//more history of success, higher chance of harvesting
		if(success < caught){return flip(0.5-(0.5*success/caught));} 
	}
	
	//TODO: verify if this computes properly
	action computeEarning{
		current_earning <- estimateValue(instance_labour.marked_trees);	//compute earning of community member"
		success <- success + 1;
		total_earning <- total_earning + current_earning;
	}

	//uses the same metrics as with the university in terms of determining the cost per harvested tree
	float estimateValue(list<trees> harvested_trees){
		float temp_earning <- 0.0;
		float thv_n <- 0.0;
		float thv_e <- 0.0; 
		float profit <- 0.0;

		ask market{
			thv_n <- getTotalBDFT((myself.instance_labour.marked_trees where (each.type = NATIVE)));	
			thv_e <- getTotalBDFT((myself.instance_labour.marked_trees where (each.type = EXOTIC)));
			profit <- getProfit(NATIVE, thv_n) + getProfit(EXOTIC, thv_e);	
		}
		
	    return profit;
	}
	
	action markTrees{
		
		list<trees> chosen_trees <- instance_labour.my_assigned_plot.plot_trees where (each.dbh > 10);
		 
		if(length(chosen_trees) > 0){
			chosen_trees <- reverse(chosen_trees sort_by each.dbh);
			int capacity <- int(LABOUR_TCAPACITY/2); //reduce the capacity of individual harvester			
			add all: chosen_trees[0::((length(chosen_trees) < capacity)?length(chosen_trees):capacity)] to: instance_labour.marked_trees;
			ask instance_labour.marked_trees{
				location <- point(0,0,0);
				is_illegal <- true;
			}		
		}
	}	
	
	//waiting to be hired
	state potential_partner initial: true { 
		enter{
			int lapsed_time <- waiting_allowance;
			instance_labour.state <- "vacant";
		} 
	 	
	    transition to: independent_passive when: (lapsed_time = 0);
	    transition to: labour_partner when: (instance_labour.my_assigned_plot != nil){
	    	if(instance_labour.is_planting_labour){
				min_earning <- (LABOUR_COST*MD_ITP_PLANTING);
			}else if(instance_labour.is_nursery_labour){
				min_earning <- (LABOUR_COST*MD_NURSERY_MAINTENANCE);
			}else if(instance_labour.is_managing_labour){
				min_earning <- (LABOUR_COST*MD_INVESTED_MAINTENANCE);
			}else if(instance_labour.is_harvest_labour){
				float min_bdft;
				float temp_height; 
				
				ask university_si{
					temp_height <- calculateHeight(60.0, NATIVE);
				}
				ask market{
					min_bdft <- getBDFT(60.0, NATIVE, temp_height);	//mean harvestable dbh = 60
				}
				min_earning <- (HLABOUR_COST*min_bdft*(LABOUR_TCAPACITY/2));
			}
	    }
	 	
	 	lapsed_time <- lapsed_time - 1;
	} 
	
	//wage here
	//waits for 6 months before turning into independent harvester
	state labour_partner {
		enter{
			int month <- 0;
			float commitment_earning <- 0.0;	//laborer expects certain earning within commitment period, resets at the start of the commitment period
		}
		 
	    bool satisfied; 
	    commitment_earning <- commitment_earning + current_earning;
	    total_earning <- total_earning + current_earning;
	 	current_earning <- 0.0;
	 	
	 	if(month = MAX_WAITING_COMMITMENT){
	 		month <- 0;
	 		commitment_earning <- 0.0;
	 	}	
	    if(instance_labour.is_harvest_labour) {		
	    	//not satisfied when earning is less than max earn or when another independent_harvesting community member has better earning 
	    	satisfied <- (commitment_earning < min_earning or hasCompetingEarner())?false: true;
	    }else{ //satisifaction based on wage only
	    	satisfied <- (commitment_earning >= min_earning)?true: false;	
	    } 
	    
	    transition to: independent_passive when: (!satisfied and month = MAX_WAITING_COMMITMENT);
	    transition to: potential_partner when: (satisfied and month=MAX_WAITING_COMMITMENT);
	 
	 	month <- month + 1;
	 	
	    exit {
	    	instance_labour.total_earning <- 0.0;
	    } 
	}
	
	//observe independent_harvesting community members here
	//if their gain is more than 
	state independent_harvesting { 
		enter{
			instance_labour.state <- "independent";
		}

		current_earning <- 0.0;	
		loop i from: 0 to: 2{	//will look for plot three times then stop
			do findPlot();	//find the plot where to harvest
			if(instance_labour.my_assigned_plot != nil){
				do markTrees();
				break;
			}	
		}

 	 	//after harvesting, gets alerted of being caught 
 	 	transition to: independent_passive when: (is_caught) { 	//if caught 
	        success <- success - 1;
	        caught <- caught + 1; 
	        is_caught <- false;
	        
	        //when caught 
	        total_earning <- total_earning - current_earning;
	        current_earning <- 0.0; 
	    } 	
		
	    //before you even start to harvest, check if there are prospects of being hired
	    //if there's hiring prospective, choose to cooperate
	    transition to: potential_partner when: (length(instance_labour.marked_trees) = 0 or hiring_calls > 0){
	    	if(hiring_calls > 0) {hiring_calls <- hiring_calls - 1;}
	    }
	    
	    exit{
	    	if(instance_labour.my_assigned_plot != nil){
				remove instance_labour from: instance_labour.my_assigned_plot.my_laborers;	
				instance_labour.my_assigned_plot <- nil;			
			}
	    }

	}
	
	state independent_passive{
		enter{
			int month <- 0;
			instance_labour.state <- "independent";
		}
		
		transition to: potential_partner when: hiring_calls > 0{ 	//if there's hiring prospective, choose to cooperate
	    	hiring_calls <- hiring_calls - 1;
	    }
	    transition to: independent_harvesting when: (probaHarvest() and month > MAX_WAITING_COMMITMENT/3); 	//if there's no hiring prospective, hire on one's own
	    month <- month + 1;
	}	
}