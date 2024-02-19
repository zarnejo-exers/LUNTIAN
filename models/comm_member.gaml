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
	int member_count <- 8 update: member_count;
	int waiting_allowance <- 12 update: waiting_allowance;
	float max_harvest_pay <- HARVEST_LABOUR * HARVESTING_LCOST;
	float max_planting_pay <- PLANTING_LABOUR * PLANTING_LCOST;
	float max_nursery_pay <- NURSERY_LABOUR * NURSERY_LCOST;
	
	map<comm_member,int> h_monitor; 
	
	init{
		create comm_member number: member_count;
		ask comm_member{
			add self::0 to: h_monitor;
		} 
	}
}

species comm_member control: fsm{
	int lapsed_time <- waiting_allowance;
	labour instance_labour; 
	float total_earning <- 0.0;		//total earning for the entire simulation
	float current_earning <- 0.0; //earning of the community at the current commitment
	
	//for independent community members
	int success <- 0;
	int caught <- 0; 
	bool is_caught <- false;
	
	int total_harvested_trees <- 0; //for independent harvesting
	
	reflex tickService when: instance_labour != nil{	//monitor lapsed time
		instance_labour.man_months[2] <- instance_labour.man_months[2]+1;
	}
	
	//get the total number of comm_member with current earning greater than own current earning
	//if there exist even 1, return true (meaning, someone has better earning than self)
	bool hasCompetingEarner{
		list<comm_member> competitors <- comm_member where (each.state = "independent_harvesting");
		int number_of_better_earner <- length(competitors where (each.current_earning > self.current_earning));
		return (number_of_better_earner > (0.5*length(competitors)));	//return true if the # of better earning competitors is greater than half of the total number of competitors
	}
	
	//return random location that is at the fringe
	plot getFringePlot{
		plot chosen_plot;
		
		list<plot> plot_with_trees <- entrance_plot where (length(each.plot_trees) > 0);
		int plot_pos <- rnd(length(plot_with_trees));
		chosen_plot <- entrance_plot[plot_pos];
		
		return chosen_plot;
	}
	
	//get a plot where to harvest
	action findPlot{
		list<comm_member> not_cooperating_members <- [];
		if(instance_labour.plot_to_harvest != nil){	//laborer has been harvesting 
			//get an adjacent plot
			list<plot> closest_plot <-  plot closest_to(instance_labour.plot_to_harvest, 10);	//get the 10 closest plot to current plot
			instance_labour.plot_to_harvest <- first(sort_by(closest_plot, length(each.plot_trees)));						//return the plot with the most number of trees
		}else{
			not_cooperating_members <- comm_member where (each.state = "independent_harvesting" and each.instance_labour != nil and (each.instance_labour.plot_to_harvest != nil));
			ask instance_labour{
				if(length(not_cooperating_members) > 0){	//there's another independent_harvesting community member
					do setPlotToHarvest(one_of(not_cooperating_members).instance_labour.plot_to_harvest);	//choose who to follow randomly and return one of the plots where it is harvesting
				}else{	//this is the first independent_harvesting community member
					do setPlotToHarvest(myself.getFringePlot());
				}	
			}
		}
	}
	
	//uses the same metrics as with the university in terms of determining the cost per harvested tree
	float computeEarning(list<trees> harvested_trees){
		float temp_earning <- 0.0;
		float thv_n;
		float thv_e; 
		list<trees> native <- harvested_trees where (each.type = NATIVE);
		list<trees> exotic <- harvested_trees where (each.type = EXOTIC);
		ask market{
			thv_n <- getTotalBDFT(native);
			thv_e <- getTotalBDFT(exotic);
		}
		
	    ask market{
	    	return getProfit(NATIVE, thv_n) + getProfit(EXOTIC, thv_e);
	    }
	}
	
	//determines hiring prospecti
	//if returned true, transition to labour_partner; else, remain as competitor
	bool checkHiringProspective{
		ask university_si{
			if(!hiring_prospect){
				return false;		//if there's no hiring prospect, return false right away	
			}
		}
		write "THERE'S HIRING PROSPECT!";
		//if there is a hiring prospect, check the state of all competitors
		//shift meaning, become labour_partner
		int competition_count <- comm_member count (each.state = "independent_harvesting" or each.state = "independent_passive");
		if(competition_count = 0){
			return true;
		} 
		return flip(1/competition_count);	//shift chance is a fraction dependent on total number of competition
	}
	
	bool probaHarvest{
		if(success = caught){return flip(0.5);}
		if(success > caught){return flip(0.5+(0.5*caught/success));}	//more history of success, higher chance of harvesting
		if(success < caught){return flip(0.5-(0.5*success/caught));} 
	}
	
	action completeHarvest(list<trees> harvested_trees){
		current_earning <- computeEarning(harvested_trees);	//compute earning of community member
		total_earning <- total_earning + current_earning;
		success <- success + 1;
		total_harvested_trees <- total_harvested_trees + 1;
		h_monitor[self] <- total_harvested_trees;
		current_earning <- 0.0;
	}
	
	//waiting to be hired
	state potential_partner initial: true { 
	 	lapsed_time <- lapsed_time - 1; 
	 	
	    transition to: independent_passive when: (lapsed_time = 0);
	    transition to: labour_partner when: (instance_labour != nil);
	 
	    exit { 
	    	lapsed_time <- waiting_allowance;
	    } 
	} 
	
	//wage here
	//kill instance_labour after
	state labour_partner { 
	    bool satisfied; 
	    	
	    if(instance_labour.is_harvest_labour) {		
	    	//not satisfied when earning is less than max earn or when another independent_harvesting community member has better earning 
	    	satisfied <- (current_earning < max_harvest_pay or hasCompetingEarner())?false: true;
	    }else{ //satisifaction based on wage only
	    	if(instance_labour.is_planting_labour) {
	    		satisfied <- (current_earning >= (0.3*max_planting_pay))?true: false;
	    	}else{
	    		satisfied <- (current_earning >= (0.3*max_nursery_pay))?true: false;
	    	}	
	    } 
	    
	   // write "assigned: "+instance_labour.man_months[0]+" lapsed: "+instance_labour.man_months[0];
	    transition to: independent_harvesting when: (instance_labour.man_months[2] >= instance_labour.man_months[0] and !satisfied);
	    transition to: potential_partner when: (instance_labour.man_months[2] >= instance_labour.man_months[0]);
	 
	    exit {
	    	total_earning <- total_earning + current_earning;
	    	current_earning <- 0.0;
	    	
	    	loop mp over: instance_labour.my_plots{
	    		remove instance_labour from: mp.my_laborers;	
	    	}
	    	ask instance_labour{
	    		do die;
	    	}
	    	instance_labour <- nil;
	    } 
	}
	
	//observe independent_harvesting community members here
	//if their gain is more than 
	state independent_harvesting { 
	    enter {//create an instance of a labour for the harvester
		    create labour{
				com_identity <- myself;
				myself.instance_labour <- self;
				nursery_labour_type <- -1;
				is_harvest_labour <- nil;
				is_planting_labour <- nil;
				my_plots <- nil;
				state <- "independent";
			}
		} 
	 
	    
	    //before you even start to harvest, check if there are prospects of being hired
	    transition to: potential_partner when: (checkHiringProspective()) { 	//if there's hiring prospective, choose to cooperate
	        success <- 0;
	        caught <- 0;
	    } 
	    
	    loop i from: 0 to: 2{	//will look for plot three times then stop
			do findPlot();	//find the plot where to harvest
			if(instance_labour.plot_to_harvest != nil){
				break;
			}	
		}

 	 	//after harvesting, gets alerted of being caught 
 	 	transition to: independent_passive when: (is_caught) { 	//if caught 
	        success <- success - 1;
	        caught <- caught + 1; 
	        is_caught <- false;
	        
	        //when caught 
	        write "CAUGHT! curreng_earning: "+current_earning;
	        total_earning <- total_earning - current_earning;
	        current_earning <- 0.0; 
	    } 
	    
	    exit {
	    	if(instance_labour != nil){
	    		loop mp over: instance_labour.my_plots{
	    			remove instance_labour from: mp.my_laborers;	
	    		}
	    		remove instance_labour from: instance_labour.plot_to_harvest.my_laborers;
	    		ask instance_labour{ do die; }
	    		instance_labour <- nil;
	    	}
	    	lapsed_time <- waiting_allowance;
	    } 
	}
	
	state independent_passive{
		transition to: potential_partner when: (checkHiringProspective()) { 	//if there's hiring prospective, choose to cooperate
	        success <- 0;
	        caught <- 0;
	        lapsed_time <- waiting_allowance;
	    }
	    transition to: independent_harvesting when: (probaHarvest()); 	//if there's no hiring prospective, hire on one's own
	}	
}