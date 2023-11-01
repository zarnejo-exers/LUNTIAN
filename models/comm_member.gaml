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
	    
	    transition to: cooperating_available when: (cycle > 2) { 
	        write "transition: competing -> cooperating_available"; 
	    }  
	 
	    exit {write 'EXIT from '+state;} 
	}	
}
