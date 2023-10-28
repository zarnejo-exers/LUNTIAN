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
	plot my_plots;
	int harvest_monitor;	//corresponds to the position of the plot, like a timer to signal if a year already passed
	float total_profit <- 0.0;
	float investment <- 0.0;
	int harvested_trees<-0; 
	bool done_harvesting;
	
	int rt;	//risk type
	
	//investor is deciding whether to invest or not
	//computes for the rate of return on the invested plots
	//once investment has been successfully completed; university starts the planting and assigns rotation years per plot.
	action decideInvestment{	////reflex startInvesting when: ((length(plot where each.is_investable) > 0) and length(my_plots) = 0){
		
		list<plot> investable_plots <- plot where (each.is_investable);	//gets investable plots
		
		//decide investment based on risk type
		plot chosen_plot <- getSuitablePlot(investable_plots, rt);
		if(chosen_plot != nil){
			bool investment_status <- false;
			
			ask university{
				investment_status <- investOnPlot(myself, chosen_plot);
				write "Investment status: "+investment_status;
			}			
			if(investment_status){	//investment successful, put investor on investor's list of plot 
				add self to: chosen_plot.my_investors;
				harvest_monitor <- 0;
				chosen_plot.is_investable <- false;
			}else{
				write "Investment denied";	
			}
		}else{
			write "Risk not satisfied!";
		}	
		
	}
	
	/* list<plot> plot_wroad <- investable_plots where each.has_road;	//get plots with road
		plot chosen_plot <- ((length(plot_wroad)>0)? plot_wroad:investable_plots) with_max_of each.projected_profit;	//get the chosen plot from those with road, or if there's no plot with road, just get the plot with max profit
	 */
	plot getSuitablePlot(list<plot> ip, int risk_type){
		string risk <- risk_types.keys[risk_type];
		if(risk = "Neutral"){
			risk_type <- flip(risk_types[risk])?0:1;
			risk <- risk_types.keys[risk_type];
			write "entering neutral then "+risk; 
		}
		
		list<plot> candidate_plots <- [];
		if(risk = "Averse"){
			write "entering averse... ";
			candidate_plots <- ip where ((1-(each.investment_cost / each.projected_profit)) < risk_types[risk]);
		}else{	//risk = "Loving"
			write "entering loving...";
			candidate_plots <- ip where ((1-(each.investment_cost / each.projected_profit)) >= risk_types[risk]);
		}
		if(length(candidate_plots) = 0){
			return nil;	
		}else{
			//get random plot from candidate plots
			int r_pos <- rnd(length(candidate_plots)-1);
			write "Cost: "+candidate_plots[r_pos].investment_cost+" Profit: "+candidate_plots[r_pos].projected_profit;
			write "Investment risk: "+(1-(candidate_plots[r_pos].investment_cost/candidate_plots[r_pos].projected_profit));
			return candidate_plots[r_pos];
		}
		
	}
	
	//to signal when to harvest and earn
	//harvest_monitor ticks to monitor the month, when harvest_monitor = 12, it means a year has passed
	//each plot have rotation_years, there is a set rotation year for each ITP, so you decrement the rotation_year whenever the harvest_monitor reaches 12
	action updateRotationYears{	// when: length(my_plots) > 0
		harvest_monitor <- 1 + harvest_monitor;
		if(harvest_monitor = 12){
			if(my_plots.rotation_years != 0){
				my_plots.rotation_years <- my_plots.rotation_years - 1;
				harvest_monitor <- 0;
			}
		}
	}
	
	state interested_passive initial: true { 
	    enter {  
	        write " "+risk_types.keys[rt]+" Enter in: " + state; 
	    } 
	 
	 	do decideInvestment;
	    write "Current state: "+state ; 
	 
	    transition to: active when: (my_plots != nil) { 
	        write "Plot count: "+length(my_plots);
	        write "transition: interested_passive -> active"; 
	    } 
	 
	    exit { 
	        write "EXIT from "+state; 
	    } 
	} 
	
	state active { 
	 
	    enter {write 'Enter in: '+state;} 
	 
	 	do updateRotationYears;
	    write "Current state: "+state+" remaining rotation years: "+my_plots.rotation_years;
	    
	    transition to: interested_passive when: (done_harvesting) { 
	        write "transition: active -> interested_passive"; 
	        done_harvesting <- false;
	        my_plots <- nil;
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