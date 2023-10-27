/**
* Name: investor
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model investor
import "university.gaml"

/* Insert your model definition here */
global{
	float risk_averse <- 0.5; 	//type = 0
	float risk_loving <- 1.0;	//type = 1
	int investor_count <- 1 update: investor_count;
	map<string,float> risk_types <-["Averse"::0.5, "Loving"::1.0, "Neutral"::0.5];
	
	init{
		//assign risk type for each investor randomly
		create investor number: investor_count{
			rt <- rnd(2);	
		}
	}
	
}

//previous
//behavior of investor detemines the profit threshold that it will tolerate
//profit threshold will dictate whether the investor will continue on investing on a plot or not
//plot's projected profit is determined by the university
species investor control: fsm{
	list<plot> my_plots <- [];
	list<int> harvest_monitor <- [];	//corresponds to the position of the plot, like a timer to signal if a year already passed
	float total_profit <- 0.0;
	float investment <- 0.0;
	int harvested_trees<-0; 
	
	int rt;	//risk type
	
	//computes for the rate of return on the invested plots
	//once investment has been successfully completed; university starts the planting and assigns rotation years per plot.
	reflex startInvesting when: ((length(plot where each.is_investable) > 0) and length(my_plots) = 0){
		list<plot> investable_plots <- plot where each.is_investable;	//gets investable plots
		//decide investment
		//if investment is 0, no previous investment, invests on the plot that have road, with highest profit
		if(investment = 0){
			list<plot> plot_wroad <- investable_plots where each.has_road;	//get plots with road
			plot chosen_plot <- ((length(plot_wroad)>0)? plot_wroad:investable_plots) with_max_of each.projected_profit;	//get the chosen plot from those with road, or if there's no plot with road, just get the plot with max profit
			bool investment_status <- false;
			ask university{
				investment_status <- investOnPlot(myself, chosen_plot);
			}			
			if(investment_status){	//investment successful, put investor on investor's list of plot 
				add self to: chosen_plot.my_investors;
				add 0 to: harvest_monitor;
				chosen_plot.is_investable <- false;
			}else{
				//write "Investment denied";	
			} 
		}else{
			write "??";
			//investor decides based on the result of the prior investment
			//profit >= expected; stay on the same plot
			//profit < expected and profit > 70% of expected; invest on different plot
			//profit < 70% of expected; investor stop investing 
			
			//if all investor gained on the prior investment round, additional investor are added in the system
		}
		
		//set plots rotation years
		
	}
	
	//to signal when to harvest and earn
	reflex updateRotationYears when: length(my_plots) > 0{
		loop plot_length from: 0 to: length(my_plots)-1{	//number of plots where investor have put his/her investment
			harvest_monitor[plot_length] <- 1+harvest_monitor[plot_length];
			if(harvest_monitor[plot_length] = 12){
				if(my_plots[plot_length].rotation_years != 0){
					my_plots[plot_length].rotation_years <- my_plots[plot_length].rotation_years - 1;
					harvest_monitor[plot_length] <- 0;	
				}
			} 
		}
	}
	
	state interested_passive initial: true { 
	    enter {  
	        write " "+risk_types.keys[rt]+" Enter in: " + state; 
	    } 
	 
	    write "Current state: "+state ; 
	 
	    transition to: active when: (length(my_plots)>0) { 
	        write "Plot count: "+length(my_plots);
	        write "transition: interested_passive -> active"; 
	    } 
	    
	 
	    exit { 
	        write "EXIT from "+state; 
	    } 
	} 
	
	state active { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    transition to: not_interested_passive when: (cycle > 2) { 
	        write "transition: active -> not_interested_passive"; 
	    }  
	 
	    exit {write 'EXIT from '+state;} 
	}
	
	state not_interested_passive { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	    write "Current state: "+state;
	    
	    transition to: interested_passive when: (cycle > 2) { 
	        write "transition: not_interested_passive -> interested_passive"; 
	    }  
	 
	    exit {write 'EXIT from '+state;} 
	}
}