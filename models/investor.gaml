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
	int tht <- 0;	//total harvested trees
	int investment_count <- 0;
	list<int> investment_rotation_years <- [];
	int rt;	//risk type
	bool waiting <- false;
	
	//investor is deciding whether to invest or not
	//computes for the rate of return on the invested plots
	//once investment has been successfully completed; university starts the planting and assigns rotation years per plot.
	// get firstbjarvestable plot
	action decideInvestment{	////reflex startInvesting when: ((length(plot where each.is_investable) > 0) and length(my_plots) = 0){
		plot investable_plot; 
		int s_type;	//supported ITP type
		ask university_si{
			investable_plot <- getInvestablePlot();		//get the first plot with highest SBA;
			write "Getting Details of Investment";
			do getInvestmentDetailsOfPlot(investable_plot);
		}
		write "Investor: "+name+" is investing on plot: "+investable_plot.name+" with sba: "+investable_plot.stand_basal_area;
		if(investable_plot != nil){
			//decide investment based on risk type
			bool decision <- decideOnRisk(investable_plot, rt);
			if(decision){
				ask university_si{
					do investOnPlot(myself, investable_plot, itp_type);
				}			
				harvest_monitor <- 0;
				investable_plot.is_investable <- false;
				investable_plot.is_invested <- true;
				investment <- investable_plot.investment_cost;
				promised_profit <- investable_plot.projected_profit;
				my_plot <- investable_plot;
				write "Investment granted -- cost: "+investment+" promised profit: "+promised_profit;
				investment_count <- investment_count + 1;
			}else{
				write "Risk not satisfied!";
			}	
		}else{
			write "No ready plot";
		}
	}
	
	bool decideOnRisk(plot i_plot, int risk_type){
		string risk <- risk_types.keys[risk_type];
		if(risk = "Neutral"){	//if risk tyep = neutral, flip what kind of risk it will be on this step
			risk <- risk_types.keys[flip(risk_types[risk])?0:1];
		}
		
		switch risk{
			match "Averse" {
				if(i_plot.projected_profit>0 and (1-(i_plot.investment_cost / i_plot.projected_profit) < risk_types[risk])){
					return true;
				}	
			}
			match "Loving" {
				if(i_plot.projected_profit > 0 and (1-(i_plot.investment_cost / i_plot.projected_profit)) >= risk_types[risk]){
					return true;
				}
			}
		}
		return false; 
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
	 	}
	 
	    transition to: investing when: (my_plot != nil);
	} 
	
	state investing { 
	 	do updateRotationYears;
	 	
	    transition to: potential_active when: (!waiting and (recent_profit >= promised_profit));
	    transition to: potential_passive when: (!waiting and (recent_profit < promised_profit));
	 
	    exit {
	    	my_plot.is_invested <- false;
	        my_plot <- nil;
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
		bool to_transition <- flip(risk_types[risk]);
	    
	    transition to: potential_active when: (to_transition);
	}
}