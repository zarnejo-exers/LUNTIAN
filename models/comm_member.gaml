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
	int member_count <- 1 update: member_count;
	int waiting_allowance <- 12 update: waiting_allowance;
	float max_harvest_pay <- HARVEST_LABOUR * HARVEST_LCOST;
	float max_planting_pay <- PLANTING_LABOUR * PLANTING_LCOST;
	float max_nursery_pay <- NURSERY_LABOUR * NURSERY_LCOST;
	
	init{
		create comm_member number: member_count; 
	}
}

species comm_member control: fsm{
	int lapsed_time <- waiting_allowance;
	labour instance_labour; 
	float total_earning <- 0.0;		//total earning for the entire simulation
	float current_earning <- 0.0; //earning of the community at the current commitment
	
	reflex tickService when: instance_labour != nil{	//monitor lapsed time
		instance_labour.man_months[2] <- instance_labour.man_months[2]+1;
	}
	
	//get the total number of comm_member with current earning greater than own current earning
	//if there exist even 1, return true (meaning, someone has better earning than self)
	bool hasCompetingEarner{
		int number_of_better_earner <- length(comm_member where (each.state = "competing" and each.current_earning > self.current_earning));
		
		return (number_of_better_earner > 0);
	}
	
	//return random location that is at the fringe
	plot getFringePlot{
		return nil;
	}
	
	//get a plot where to harvest
	plot findPlot{
		if(instance_labour.my_plots != nil and length(instance_labour.my_plots) > 0){	//if there's already a plot, it means there's nothing to harvest on that plot 
			//get an adjacent plot
			list<plot> closest_plot <-  plot closest_to(first(instance_labour.my_plots), 10);	//get the 10 closest plot to current plot
			return first(sort_by(closest_plot, length(each.plot_trees)));						//return the plot with the most number of trees
		}else{
			list<comm_member> competing_members <- comm_member where (each.state = "competing");
			if(competing_members != nil){	//there's another competing community member
				return first(first(shuffle(competing_members)).instance_labour.my_plots );	//choose who to follow randomly and return one of the plots where it is harvesting
			}else{	//this is the first competing community member
				return getFringePlot();
			}
		}
	}
	
	//harvests upto capacity
	//gets the biggest trees
	list<trees> harvestPlot(labour cl, plot plot_to_harvest){
		list<trees> trees_to_harvest <- reverse(sort_by(plot_to_harvest.plot_trees, each.dbh));
		if(length(trees_to_harvest) > cl.carrying_capacity){
			trees_to_harvest <- first(cl.carrying_capacity, sort_by(plot_to_harvest.plot_trees, each.dbh));	//get only according to capacity
		}
				
		plot_to_harvest.plot_trees <- (plot_to_harvest.plot_trees - trees_to_harvest);
		ask plot_to_harvest.plot_trees{
			age <- age + 5; 	//to correspond to TSI
		}
		return trees_to_harvest;
	}
	
	//to fill out
	float computeEarning(list<trees> harvested_trees){
		return 0.0;
	}
	//to fillout
	bool checkHiringProspective{
		return false;
	}
	
	//waiting to be hired
	state cooperating_available initial: true { 
	    enter {  
	        write "Enter in: " + state; 
	    } 
	 
	 	lapsed_time <- lapsed_time - 1;
	    write "Current state: "+state+" Remaining time: "+lapsed_time; 
	 	
	    transition to: competing when: (lapsed_time = 0) { 
	        write "transition: cooperating_available -> competing"; 
	    } 
	    transition to: cooperating when: (instance_labour != nil){
	    	write "transition: cooperating_variable -> cooperating";
	    }
	 
	    exit { 
	    	lapsed_time <- waiting_allowance;
	        write "EXIT from "+state; 
	    } 
	} 
	
	//wage here
	//kill instance_labour after
	state cooperating { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    bool satisfied; 
	    	
	    if(instance_labour.is_harvest_labour) {		
	    	//not satisfied when earning is less than max earn or when another competing community member has better earning 
	    	satisfied <- (current_earning < max_harvest_pay or hasCompetingEarner())?false: true;
	    }else{ //satisifaction based on wage only
	    	if(instance_labour.is_planting_labour) {
	    		satisfied <- (current_earning >= (0.8*max_planting_pay))?true: false;
	    	}else{
	    		satisfied <- (current_earning >= (0.8*max_nursery_pay))?true: false;
	    	}	
	    } 
	    
	    transition to: competing when: (instance_labour.man_months[2] >= instance_labour.man_months[0] and !satisfied) { 
	        write "Service Ended... Transition: cooperating -> competing"; 
	    }
	    
	    transition to: cooperating_available when: (instance_labour.man_months[2] >= instance_labour.man_months[0] and satisfied) { 
	        write "Service Ended... Transition: cooperating -> cooperating_available"; 
	    }  
	 
	    exit {
	    	total_earning <- total_earning + current_earning;
	    	current_earning <- 0.0;
	    	ask instance_labour{
	    		do die;
	    	}
	    	instance_labour <- nil;
	    	write 'EXIT from '+state;
	    } 
	}
	
	//observe competing community members here
	//if their gain is more than 
	state competing { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    transition to: cooperating_available when: (checkHiringProspective()) { 	//if there's hiring prospective, choose to cooperate
	        write "transition: competing -> cooperating_available"; 
	    } 
	    
	    //become a competing labour a competing labour
	    create labour{
			com_identity <- myself;
			myself.instance_labour <- self;
			is_nursery_labour <- nil;
			is_harvest_labour <- nil;
			is_planting_labour <- nil;
		}
		
		labour competing_labour <- self.instance_labour;
		list<trees> harvested_trees;
		
		loop i from: 0 to: 3{
			add findPlot() to: competing_labour.my_plots;	//find the plot where to harvest
			competing_labour.current_plot <- first(competing_labour.my_plots); 	//put laborer on the plot, currently plot is a list but in essence it contains only 1, just as preparation
			harvested_trees <- harvestPlot(competing_labour, competing_labour.current_plot);
			if(harvested_trees != nil and length(harvested_trees) > 0){
				break;
			}	
		}
		current_earning <- computeEarning(harvested_trees);	//compute earning of community member
 	 
	    exit {
	    	total_earning <- total_earning + current_earning;
	    	if(instance_labour != nil){
	    		ask instance_labour{ do die; }
	    		instance_labour <- nil;
	    	}
	    	write 'EXIT from '+state;
	    } 
	}
	
}
