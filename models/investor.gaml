/**
* Name: investor
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model investor
import "university_si.gaml"

/* Insert your model definition here */
global{
	float risk_averse <- 0.5; 	//type = 0
	float risk_loving <- 1.0;	//type = 1
	int investor_count <- 10 update: investor_count;
	map<string,float> risk_types <-["Averse"::0.25, "Loving"::0.75, "Neutral"::0.5];
	
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
	plot my_plot;
	int harvest_monitor;	//corresponds to the position of the plot, like a timer to signal if a year already passed
	float total_profit <- 0.0;
	float recent_profit;
	float total_investment <- 0.0;
	float investment <- 0.0;
	float promised_profit; 
	bool done_harvesting <- false;
	int tht <- 0;	//total harvested trees
	
	int rt;	//risk type
	bool waiting <- false;
	
	//investor is deciding whether to invest or not
	//computes for the rate of return on the invested plots
	//once investment has been successfully completed; university starts the planting and assigns rotation years per plot.
	action decideInvestment{	////reflex startInvesting when: ((length(plot where each.is_investable) > 0) and length(my_plots) = 0){
		
		ask university_si{
			do determineInvestablePlots;	
		}
		
		list<plot> investable_plots <- plot where (each.is_investable and !each.is_invested);	//gets investable plots
		
		//decide investment based on risk type
		plot chosen_plot <- getSuitablePlot(investable_plots, rt);
		if(chosen_plot != nil){
			bool investment_status <- false;
			
			ask university_si{
				investment_status <- investOnPlot(myself, chosen_plot);
				write "Investment status: "+investment_status;
			}			
			if(investment_status){	//investment successful, put investor on investor's list of plot
				harvest_monitor <- 0;
				chosen_plot.is_investable <- false;
				chosen_plot.is_invested <- true;
				investment <- chosen_plot.investment_cost;
				promised_profit <- chosen_plot.projected_profit;
				my_plot <- chosen_plot;
				write "Investment granted -- cost: "+investment+" promised profit: "+promised_profit;
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
		list<plot> candidate_plots <- [];
		if(risk = "Neutral"){
			risk <- risk_types.keys[flip(risk_types[risk])?0:1];
		}else if(risk = "Averse"){
			candidate_plots <- ip where ((1-(each.investment_cost / each.projected_profit)) < risk_types[risk]);
		}else{	//risk = "Loving"
			candidate_plots <- ip where ((1-(each.investment_cost / each.projected_profit)) >= risk_types[risk]);
		}
		
		if(length(candidate_plots) = 0){
			return nil;	
		}else{
			//get random plot from candidate plots
			int r_pos <- rnd(length(candidate_plots)-1);
//			write "Cost: "+candidate_plots[r_pos].investment_cost+" Profit: "+candidate_plots[r_pos].projected_profit;
//			write "Investment risk: "+(1-(candidate_plots[r_pos].investment_cost/candidate_plots[r_pos].projected_profit));
			return candidate_plots[r_pos];
		}
		
	}
	
	//to signal when to harvest and earn
	//harvest_monitor ticks to monitor the month, when harvest_monitor = 12, it means a year has passed
	//each plot have rotation_years, there is a set rotation year for each ITP, so you decrement the rotation_year whenever the harvest_monitor reaches 12
	action updateRotationYears{	// when: length(my_plots) > 0
		harvest_monitor <- 1 + harvest_monitor;
		if(harvest_monitor = 12){
			if(my_plot.rotation_years != 0){
				my_plot.rotation_years <- my_plot.rotation_years - 1;
			}
			harvest_monitor <- 0;
		}
	}
	
	state potential_active initial: true{ 
	 	if(assignedNurseries){
	 		write "Deciding investment... ";
	 		do decideInvestment;	
	 		write "Invested plot: "+my_plot;
	 	}else{
	 		write "Waiting for environment...";
	 	}
	 
	    transition to: investing when: (my_plot != nil);
	} 
	
	state investing { 
	 	do updateRotationYears;
	    
	    transition to: potential_active when: (done_harvesting and (recent_profit >= promised_profit));
	    transition to: potential_passive when: (done_harvesting and (recent_profit < promised_profit));
	 
	    exit {
	    	done_harvesting <- false;
	    	my_plot.is_invested <- false;
	        my_plot <- nil;
	    	total_profit <- total_profit + recent_profit;	//record final profit
	    	total_investment <- total_investment + investment;
	    	recent_profit <- 0.0;
	    	harvest_monitor <- 0;
	    	investment <- 0.0;
	    } 
	}
	
	state potential_passive { 
	    string risk <- risk_types.keys[rt];
		if(risk = "Neutral"){
			risk <- risk_types.keys[flip(risk_types[risk])?0:1];
		}
		write "Neutral becomes "+risk;
		bool to_transition <- flip(risk_types[risk]);
	    
	    transition to: potential_active when: (to_transition);
	}
}