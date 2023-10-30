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
	
	init{
		create comm_member number: member_count; 
	}
}

species comm_member control: fsm{
	labour instance_labour;
	int lapsed_time <- waiting_allowance;
	
	state cooperating_available initial: true { 
	    enter {  
	        write "Enter in: " + state; 
	    } 
	 
	    transition to: cooperating when: (instance_labour != nil) { 
	        write "transition: cooperating_available -> cooperating"; 
	    } 
	    transition to: competing when: (lapsed_time = 0){
	    	write "transition: cooperating_available -> competing";
	    }
	    write "Current state: "+state; 
	    lapsed_time <- lapsed_time - 1;
	 
	    exit { 
	    	lapsed_time <- waiting_allowance;
	        write "EXIT from "+state; 
	    } 
	} 
	
	state cooperating { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	 	//when instance_labour.man_months[0] >= instance_labour.man_months[2]
	 	//calculate wage
	 	//if satisfactory, go to cooperating_available, if not go to competing
	 	
	    transition to: cooperating_available when: (instance_labour.man_months[0] >= instance_labour.man_months[2] ) { 
	        write "transition: cooperating -> cooperating_available"; 
	    }  
	    //not satisfactory wage
	    transition to: competing when: (cycle=1){
	    	write "transition: cooperating -> competing";
	    }
	    
		
		write "Current state: "+state + "length: "+length(instance_labour.man_months)+" here: "+instance_labour.man_months;	 
	 	instance_labour.man_months[2] <- instance_labour.man_months[2] + 1;	//lapsed time
	    exit {write 'EXIT from '+state;} 
	}
	
	state competing { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    transition to: cooperating_available when: (cycle > 2) { 
	        write "transition: competing -> cooperating_available"; 
	    }  
	 	
	    exit {write 'EXIT from '+state;} 
	}	
}
