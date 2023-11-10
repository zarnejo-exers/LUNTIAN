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
	
	//for independent community members
	int success <- 0;
	int caught <- 0; 
	bool is_caught <- false;
	
	reflex tickService when: instance_labour != nil{	//monitor lapsed time
		instance_labour.man_months[2] <- instance_labour.man_months[2]+1;
	}
	
	//get the total number of comm_member with current earning greater than own current earning
	//if there exist even 1, return true (meaning, someone has better earning than self)
	bool hasCompetingEarner{
		list<comm_member> competitors <- comm_member where (each.state = "independent_harvesting");
		write "HERE ! Current earning: "+self.current_earning;
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
		if(instance_labour.my_plots != nil and length(instance_labour.my_plots) > 0){	//if there's already a plot, it means there's nothing to harvest on that plot 
			//get an adjacent plot
			list<plot> closest_plot <-  plot closest_to(first(instance_labour.my_plots), 10);	//get the 10 closest plot to current plot
			instance_labour.my_plots <- [];	//remove the contents of the laborer's plots
			add first(sort_by(closest_plot, length(each.plot_trees))) to: instance_labour.my_plots;						//return the plot with the most number of trees
		}else{
			not_cooperating_members <- comm_member where (each.state = "independent_harvesting" and each.instance_labour != nil and length(each.instance_labour.my_plots) > 0);
			if(length(not_cooperating_members) > 0){	//there's another independent_harvesting community member
				add first(first(shuffle(not_cooperating_members)).instance_labour.my_plots ) to: instance_labour.my_plots;	//choose who to follow randomly and return one of the plots where it is harvesting
			}else{	//this is the first independent_harvesting community member
				add getFringePlot() to: instance_labour.my_plots;
			}
		}
	}
	
	//harvests upto capacity
	//gets the biggest trees
	list<trees> harvestPlot(labour cl, plot plot_to_harvest){
		add cl to: plot_to_harvest.my_laborers;
		list<trees> trees_to_harvest <- reverse(sort_by(plot_to_harvest.plot_trees, each.dbh));
		
		if(trees_to_harvest = nil){	//nothing to harvest on the plot, move to another plot
			return nil;
		}else{
			if(length(trees_to_harvest) > cl.carrying_capacity){
				trees_to_harvest <- first(cl.carrying_capacity, sort_by(plot_to_harvest.plot_trees, each.dbh));	//get only according to capacity
			}
					
			plot_to_harvest.plot_trees <- (plot_to_harvest.plot_trees - trees_to_harvest);
			ask plot_to_harvest.plot_trees{
				age <- age + 5; 	//to correspond to TSI
			}
			return trees_to_harvest;	
		}
	}
	
	//uses the same metrics as with the university in terms of determining the cost per harvested tree
	float computeEarning(list<trees> harvested_trees){
		float temp_earning <- 0.0;
		
	    loop s over: harvested_trees{
	    	//use specific price per type
	    	temp_earning <- temp_earning + (((s.type = 1)?exotic_price_per_volume:native_price_per_volume) * (#pi * (s.dbh/2)^2 * s.th) ); 
	    }
		
		return temp_earning;
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
		float shift_chance <- 1/((comm_member count (each.state = "independent_harvesting")));	//shift chance is a fraction dependent on total number of competition
		return flip(shift_chance);	
	}
	
	bool probaHarvest{
		if(success = caught){return flip(0.5);}
		if(success > caught){return flip(0.5+(0.5-caught/success));}	//more history of success, higher chance of harvesting
		if(success < caught){return flip(0.5-(0.5-success/caught));} 
	}
	
	//waiting to be hired
	state potential_partner initial: true { 
	    enter {  
	        write "Enter in: " + state; 
	    } 
	 
	 	lapsed_time <- lapsed_time - 1;
	    write "Current state: "+state+" Remaining time: "+lapsed_time; 
	 	
	    transition to: independent_passive when: (lapsed_time = 0) { 
	        write "transition: potential_partner -> independent_harvesting"; 
	    } 
	    transition to: labour_partner when: (instance_labour != nil){
	    	write "transition: cooperating_variable -> labour_partner";
	    }
	 
	    exit { 
	    	lapsed_time <- waiting_allowance;
	        write "EXIT from "+state; 
	    } 
	} 
	
	//wage here
	//kill instance_labour after
	state labour_partner { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    bool satisfied; 
	    	
	    if(instance_labour.is_harvest_labour) {		
	    	//not satisfied when earning is less than max earn or when another independent_harvesting community member has better earning 
	    	satisfied <- (current_earning < max_harvest_pay or hasCompetingEarner())?false: true;
	    }else{ //satisifaction based on wage only
	    	if(instance_labour.is_planting_labour) {
	    		write "Planting labour: current earning "+current_earning+" max planting pay: "+max_planting_pay;
	    		satisfied <- (current_earning >= (0.3*max_planting_pay))?true: false;
	    	}else{
	    		write "Nursery labour";
	    		satisfied <- (current_earning >= (0.3*max_nursery_pay))?true: false;
	    	}	
	    } 
	    
	    
	    
	    transition to: independent_harvesting when: (instance_labour.man_months[2] >= instance_labour.man_months[0] and !satisfied) { 
	        write "Service Ended... Transition: labour_partner -> independent_harvesting"; 
	    }
	    
	    transition to: potential_partner when: (instance_labour.man_months[2] >= instance_labour.man_months[0]) { 
	        write "Service Ended... Transition: labour_partner -> potential_partner"; 
	    }  
	 
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
	    	write 'EXIT from '+state;
	    } 
	}
	
	//observe independent_harvesting community members here
	//if their gain is more than 
	state independent_harvesting { 
		
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    //before you even start to harvest, check if there are prospects of being hired
	    transition to: potential_partner when: (checkHiringProspective()) { 	//if there's hiring prospective, choose to cooperate
	        success <- 0;
	        caught <- 0;
	        write "transition: independent_harvesting -> potential_partner"; 
	    } 
	    
	    if(instance_labour = nil){	//create laborer
	    	//become a independent_harvesting labour a independent_harvesting labour
		    create labour{
				com_identity <- myself;
				myself.instance_labour <- self;
				is_nursery_labour <- nil;
				is_harvest_labour <- nil;
				is_planting_labour <- nil;
				my_plots <- nil;
			}	
	    }
		
		labour not_cooperating_labour <- self.instance_labour;
		list<trees> harvested_trees;
		
		loop i from: 0 to: 2{	//will look for plot three times then stop
			do findPlot();	//find the plot where to harvest
			not_cooperating_labour.current_plot <- first(not_cooperating_labour.my_plots); 	//put laborer on the plot, currently plot is a list but in essence it contains only 1, just as preparation
			harvested_trees <- harvestPlot(not_cooperating_labour, not_cooperating_labour.current_plot);
			if(harvested_trees != nil and length(harvested_trees) > 0){
				break;
			}	
		}
		current_earning <- computeEarning(harvested_trees);	//compute earning of community member
		total_earning <- total_earning + current_earning;
		success <- success + 1;
 	 
 	 	//after harvesting, gets alerted of being caught 
 	 	transition to: independent_passive when: (is_caught) { 	//if caught 
	        write "transition: independent_harvesting -> independent_passive";
	        success <- success - 1;
	        caught <- caught + 1; 
	        is_caught <- false;
	        
	        //when caught 
	        total_earning <- total_earning - current_earning;
	        current_earning <- 0.0; 
	    } 
	    
	    exit {
	    	if(instance_labour != nil){
	    		loop mp over: instance_labour.my_plots{
	    			remove instance_labour from: mp.my_laborers;	
	    		}
	    		ask instance_labour{ do die; }
	    		instance_labour <- nil;
	    	}
	    	lapsed_time <- waiting_allowance;
	    	write 'EXIT from '+state;
	    } 
	}
	
	state independent_passive{
		enter {write 'Enter in: '+state;}
		
		write "indepdent passive... has other work/do nothing";	
		transition to: potential_partner when: (checkHiringProspective()) { 	//if there's hiring prospective, choose to cooperate
	        success <- 0;
	        caught <- 0;
	        write "transition: independent_harvesting -> potential_partner"; 
	    }
	    transition to: independent_harvesting when: (probaHarvest()) { 	//if there's hiring prospective, choose to cooperate
	        write "transition: independent_harvesting -> independent_harvesting"; 
	    }
	    
	    exit {
	    	write 'EXIT from '+state;
	    } 	
	}	
}