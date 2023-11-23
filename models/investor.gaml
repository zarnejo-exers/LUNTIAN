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
	int i_t_type;	//investor, tree type
	
	//investor is deciding whether to invest or not
	//computes for the rate of return on the invested plots
	//once investment has been successfully completed; university starts the planting and assigns rotation years per plot.
	action decideInvestment{	////reflex startInvesting when: ((length(plot where each.is_investable) > 0) and length(my_plots) = 0){
		
		map<int, list<plot>> investable_plots; 
		int s_type;	//supported ITP type
		ask university_si{
			s_type <- itp_type;
			investable_plots <- determineInvestablePlots();	
			investment_request_count <- investment_request_count + 1;
		}
		
		//decide investment based on risk type
		map<plot, int> chosen_plot <- getSuitablePlot(investable_plots, rt, s_type);
		plot c_plot <- first(chosen_plot.keys);
		if(c_plot != nil){
			bool investment_status <- false;
			
			ask university_si{
				investment_status <- investOnPlot(myself, c_plot, chosen_plot[c_plot]);
				write "Investment status: "+investment_status;
			}			
			if(investment_status){	//investment successful, put investor on investor's list of plot
				harvest_monitor <- 0;
				c_plot.is_investable <- false;
				c_plot.is_invested <- true;
				investment <- c_plot.investment_cost;
				promised_profit <- c_plot.projected_profit;
				my_plot <- c_plot;
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
	map<plot, int> getSuitablePlot(map<int, list<plot>> ip, int risk_type, int s_type){
		string risk <- risk_types.keys[risk_type];
		map<int, list<plot>> all <- [];
		map<plot,int> chosen <- nil;
		
		if(risk = "Neutral"){	//if risk tyep = neutral, flip what kind of risk it will be on this step
			risk <- risk_types.keys[flip(risk_types[risk])?0:1];
		}
		
		if(risk = "Averse"){
			if(s_type = 2){
				add 0::(ip[0] where ((1-(each.investment_cost / each.projected_profit)) < risk_types[risk])) to: all;	//get all the plots that are suitable
				add 1::(ip[1] where ((1-(each.investment_cost / each.projected_profit)) < risk_types[risk])) to: all;	//get all the plots that are suitable	
			}else{
				add s_type::(ip[s_type] where ((1-(each.investment_cost / each.projected_profit)) < risk_types[risk])) to: all;	//get all the plots that are suitable
			}
			
			chosen <- getBetterPlot(all, s_type);
		}else{	//risk = "Loving"
			if(s_type = 2){
				add 0::(ip[0] where ((1-(each.investment_cost / each.projected_profit)) >= risk_types[risk])) to: all;	//get all the plots that are suitable
				add 1::(ip[1] where ((1-(each.investment_cost / each.projected_profit)) >= risk_types[risk])) to: all;	//get all the plots that are suitable
			}else{
				add s_type::(ip[s_type] where ((1-(each.investment_cost / each.projected_profit)) >= risk_types[risk])) to: all;	//get all the plots that are suitable				
			}
			chosen <- getBetterPlot(all, s_type);
		}
		
		if(chosen != nil){
			return nil;	
		}else{
			return chosen;
		}
	}
	
	map<plot, int> getBetterPlot(map<int, list<plot>> ip, int s_type){
		if(s_type = 2){
			plot b1 <- ip[0] with_max_of (1-(each.investment_cost / each.projected_profit));
			plot b2 <- ip[1] with_max_of (1-(each.investment_cost / each.projected_profit));
			
			if(b1=nil and b2!=nil){
				return [b2::1];
			}else if(b1!=nil and b2=nil){
				return [b1::0];
			}else if(b1!=nil and b2!=nil){
				float b1_profit <- (1-(b1.investment_cost / b1.projected_profit));
				float b2_profit <- (1-(b2.investment_cost / b2.projected_profit));
				if(b1_profit > b2_profit){
					return [b1::0];	
				}
				return [b2::1];	
			}
		}
		return [(ip[s_type] with_max_of (1-(each.investment_cost / each.projected_profit)))::s_type];
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