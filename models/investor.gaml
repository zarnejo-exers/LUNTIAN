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
	int investor_count <- 5 update: investor_count;
	map<string,float> risk_types <-["Averse"::0.25, "Loving"::0.95, "Neutral"::0.5];
	
	init{
		//assign risk type for each investor randomly
		create investor number: investor_count{
			rt <- 1; //rnd(2);	
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
	
	plot my_iplot <- nil; 
	int rt;	//risk type
	bool waiting <- false;
	
	int wins <- 0;
	int loss <- 0;
	
	float projected_profit;
	int total_tree_harvested <- 0;
	float investment_cost; 
	float total_investment <- 0.0;
	
	aspect default{
		draw pyramid(5) color: #gold; 
	}
	
	
	//investor is deciding whether to invest or not
	//computes for the rate of return on the invested plots
	//once investment has been successfully completed; university starts the planting and assigns rotation years per plot.
	// get firstbjarvestable plot
	action decideInvestment{	////reflex startInvesting when: ((length(plot where each.is_investable) > 0) and length(my_plots) = 0){
		
		plot investable_plot;

		ask university_si{
			investable_plot <- first(harvestable_plot);	//receives the first plot with the highest SBA
			remove investable_plot from: harvestable_plot;
		}
		
		if(investable_plot != nil){
			ask university_si{
				myself.projected_profit <- projectProfit(myself, investable_plot, investor_percent_earning_share);
				myself.investment_cost <- computeInvestmentCost(investable_plot);
			}
			bool decision <- decideOnRisk();
//			write "deciding on investment - projected_profit:"+projected_profit+" investment_cost:"+investment_cost;
//			write "	rt:"+rt+" decision: "+decision;
			if(decision){
				total_investments <- total_investments + 1;
				my_iplot <- investable_plot;
//				write "Commencing investment #"+total_investments+" by "+name+" on "+my_iplot.name;
				location <- any_location_in(my_iplot);
				investable_plot.is_invested <- true;
				monthly_ITP_earning <- monthly_ITP_earning + investment_cost;
				//assumes that the land has been prepared after commencing investment by incuring the cost
				monthly_management_cost <- monthly_management_cost + INIT_ESTABLISHMENT_INVESTOR; 	
				
				ask university_si{
					add myself.my_iplot to: invested_plots;
					do harvestITP(myself, myself.my_iplot, BOTH, 0.0);
//					write "harvested!";
				}
				total_investment <- total_investment + investment_cost;
			}else{
				projected_profit <- 0.0;
				investment_cost <- 0.0;
			}
		}
	}
	
	bool decideOnRisk{
		string risk <- risk_types.keys[rt];
		if(risk = "Neutral"){	//if risk tyep = neutral, flip what kind of risk it will be on this step
			risk <- risk_types.keys[flip(risk_types[risk])?0:1];
		}
		
		if(projected_profit>0 and ((investment_cost / projected_profit) < risk_types[risk])){
			return true;
		}
		return false; 
	}
	
	action updateRisk{
		if(recent_profit >= projected_profit){
			wins <- wins + 1;
			loss <- 0;
	     }else{
			loss <- loss + 1;
			wins <- 0;
		}
		string risk <- risk_types.keys[rt];
		
		if(loss = 3 or wins = 3){
			if(risk = "Neutral"){
				if(loss = 3){
					rt <- 0; //where 0 = averse		
				}else{
					rt <- 1; //where 1 = loving
				}	
			}else{	//otherwise, shift to Neutral
				rt <- 2;	//where 2 = neutral
			}
			loss <- 0;
			wins <- 0;
//			write risk+" shifting to: "+risk_types.keys[rt];
		}
	}
	
	state potential_active initial: true{ 
		if(investment_open){
			do decideInvestment;	
		}
	    transition to: investing when: (my_iplot != nil);
	} 
	
	state investing { 
		enter{
			int harvest_month_monitor <- 0;
		}
	 	
		//will only state transition after (investment_rotation_years*12) 
		//harvest_month_monitor monitors how long the investor has been investing 	
		transition to: end_investment when: (harvest_month_monitor = (investment_rotation_years*12));
//	    transition to: potential_active when: ((harvest_month_monitor = (investment_rotation_years*12)) and (recent_profit >= projected_profit));
//	    transition to: potential_passive when: ((harvest_month_monitor = (investment_rotation_years*12)) and (recent_profit < projected_profit));
	    
//	    write "before transitioning with recent_profit="+recent_profit+" promised_profit="+projected_profit+" total_profit="+total_profit;
	    harvest_month_monitor <- harvest_month_monitor + 1;
	    if(harvest_month_monitor = (investment_rotation_years*12)){
	 		ask university_si{
				do harvestITP(myself, myself.my_iplot, BOTH, investor_percent_earning_share);
//				write "last harvest!";
			}
//			write "after last harvest with recent_profit="+recent_profit+" promised_profit="+projected_profit+" total_profit="+total_profit;
			total_profit <- total_profit + recent_profit;	//note that, I didn't considered investment cost in predicting the promised profit
	 	}
	 	
	 	exit{
	 		total_profit <- total_profit + recent_profit;
//	 		write  "with recent_profit="+recent_profit+" promised_profit="+projected_profit+" total_profit="+total_profit;
	 		my_iplot.is_invested <- false;
	        my_iplot <- nil;
	        do updateRisk();
	        recent_profit <- 0.0;
	        investment_cost <- 0.0;
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
	
	state end_investment{
		write "!End investment for investor "+name;
	}
}