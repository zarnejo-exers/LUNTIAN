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
	int lapsed_time <- waiting_allowance;
	
	state cooperating_available initial: true { 
	    enter {  
	        write "Enter in: " + state; 
	    } 
	 
	 	lapsed_time <- lapsed_time - 1;
	    write "Current state: "+state+" Remaining time: "+lapsed_time; 
	 	
	    transition to: competing when: (lapsed_time = 0) { 
	        write "transition: cooperating_available -> competing"; 
	    } 
	    
	 
	    exit { 
	    	lapsed_time <- waiting_allowance;
	        write "EXIT from "+state; 
	    } 
	} 
	
	state cooperating { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    transition to: competing when: (cycle > 2) { 
	        write "transition: cooperating -> competing"; 
	    }  
	 
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
