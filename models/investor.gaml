/**
* Name: investor
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model investor
import "university_si.gaml"

//NOTE:open plots to investor when there's sufficient saplings in the nurseries 

/* Insert your model definition here */
global{
	float risk_averse <- 0.5; 	//type = 0
	float risk_loving <- 1.0;	//type = 1
	int investor_count <- 10 update: investor_count;
	map<string,float> risk_types <-["Averse"::0.25, "Loving"::0.75, "Neutral"::0.5];
	int total_investment_count <- 0 update: total_investment_count;
	
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
	float total_profit <- 0.0;
	float recent_profit <- 0.0;
	float total_investment <- 0.0;
	int tht <- 0;	//total harvested trees
	
	plot my_plot <- nil;
	float promised_profit; 
	int investment_count <- 0;
	int rt;	//risk type
	bool waiting <- false;
	
	
	//investor is deciding whether to invest or not
	//computes for the rate of return on the invested plots
	//once investment has been successfully completed; university starts the planting and assigns rotation years per plot.
	// get firstbjarvestable plot
	action decideInvestment{	////reflex startInvesting when: ((length(plot where each.is_investable) > 0) and length(my_plots) = 0){
		
		plot investable_plot;
		float projected_profit;
		float investment_cost; 
		
		ask university_si{
			investable_plot <- getInvestablePlot();	//receives the first plot with the highest SBA
		}
		
		if(investable_plot != nil){
			ask university_si{
				int cplaces_to_fill <- length(getSquareSpaces(investable_plot.shape, investable_plot.plot_trees, true, 3));	//to support investment
				projected_profit <- projectProfit(myself, investable_plot, cplaces_to_fill);
				investment_cost <- computeInvestmentCost(investable_plot, cplaces_to_fill);
			}
			bool decision <- decideOnRisk(projected_profit, investment_cost, rt);
			if(decision){
				write "Commencing investment";
				my_plot <- investable_plot;
				investable_plot.is_invested <- true;
				total_investment <- total_investment + investment_cost;
				total_ITP_earning <- total_ITP_earning + investment_cost;
				ask university_si{
					do harvestITP(myself, myself.my_plot);	
				} 
			}
		}else{
			write "No available plot for investment";
		}
	}
	
	bool decideOnRisk(float projected_profit, float investment_cost, int risk_type){
		string risk <- risk_types.keys[risk_type];
		if(risk = "Neutral"){	//if risk tyep = neutral, flip what kind of risk it will be on this step
			risk <- risk_types.keys[flip(risk_types[risk])?0:1];
		}
		
		if(projected_profit>0 and ((investment_cost / projected_profit) < risk_types[risk])){
			return true;
		}
		return false; 
	}
	
	state potential_active initial: true{ 
		if(investment_open){
			do decideInvestment;	
		}
	    transition to: investing when: (my_plot != nil);
	} 
	
	state investing { 
		enter{
			int harvest_month_monitor <- 0;
		}
				
	    transition to: potential_active when: ((harvest_month_monitor = (investment_rotation_years*12)) and (recent_profit >= promised_profit));
	    transition to: potential_passive when: ((harvest_month_monitor = (investment_rotation_years*12)) and (recent_profit < promised_profit));
	 
	 	if(harvest_month_monitor = investment_rotation_years){
	 		ask university_si{
				do harvestITP(myself, myself.my_plot);	
			}
	 	}else{
	 		harvest_month_monitor <- harvest_month_monitor + 1;	
	 	}
	 	
	    exit {
	    	my_plot.is_invested <- false;
	        my_plot <- nil;
	        total_profit <- total_profit + recent_profit;
	    	recent_profit <- 0.0;
	    } 
	}
	
	state potential_passive { 
	    string risk <- risk_types.keys[rt];
		if(risk = "Neutral"){
			risk <- risk_types.keys[flip(risk_types[risk])?0:1];
		}
		bool to_transition <- flip(risk_types[risk]);
	    
	    transition to: potential_active when: (to_transition);
	}
}