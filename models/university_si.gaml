/**
* Name: investor
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/

model university_si
import "llg.gaml"
import "market.gaml"
import "investor.gaml"
import "labour.gaml"
//import "comm_member.gaml"
import "special_police.gaml"

/* Insert your model definition here */
global{
	int NURSERY_LABOUR <- 12; //labor required per nursery, constant
	int HARVEST_LABOUR <- 1;
	int PLANTING_LABOUR <- 6;
	int LABOUR_TCAPACITY <- 15;	//number of trees that the laborer can plant/manage
	
	//fixed rate
	float NURSERY_LCOST <- 12810.0;	//labor per month https://velocityglobal.com/resources/blog/minimum-wage-by-country
	float HARVESTING_LCOST <- 13834.51;	//one month labor
	float PLANTING_LCOST <- 25.0;	//
	
	float POLICE_COST <- 18150.0; //average wage per month https://www.salaryexpert.com/salary/job/forest-officer/philippines
	
	float HARVESTING_COST <- 17.04; //cost = (0.28+0.33)/2 usd per bdft, 17.04php
	float NATIVE_price_per_SAPLING <- 100.0; //Temporary variable, plants native on every ANR
	
	int average_no_trees_in1ha <- 20;
	int police_count <- 2 update: police_count;
	int plot_size <- 1 update: plot_size;
	int laborer_count <- 10 update: laborer_count;
	int nlaborer_count<- 5 update: nlaborer_count;
	float planting_space <- 1.0 update: planting_space; 
	int nursery_count <- 2 update: nursery_count;
	float harvest_policy <- 0.5 update: harvest_policy;
	float dbh_policy <- 50.0 update: dbh_policy; 
	bool hiring_prospect <- false;
	
	int harvesting_age_exotic <- 15 update: harvesting_age_exotic;	//temp
	int harvesting_age_native <- 20 update: harvesting_age_native;	//actual 40
	bool start_harvest <- false;
	
	int tht <- 0;
	
	float total_management_cost <- 0.0;
	float total_ITP_earning <- 0.0;
	int total_ANR_instance <- 0;
	int total_warned_CM <- 0;
	
	int total_seedlings_replanted <- 0;	//per year
	
	/*Dipterocarp: max_dbh = [80,120]cm
	 *Mahogany: max_dbh = 150cm
	 *				Exotic			Native
	 * seedling		[0,1)			[0,5)
	 * sapling		[1,5)			[5,10)
	 * pole			[5,30)			[10,20)
	 * adult 		[30,150)		[20,100)
	*/
	 float n_sapling_ave_DBH <- 7.5;
	 float e_sapling_ave_DBH <- 2.5; 
	 float n_adult_ave_DBH <- 60.0;
	 float e_adult_ave_DBH <- 90.0;
	
	init{
		create market;
		create labour number: laborer_count{
			labor_type <- OWN_LABOUR; 
		}
		create university_si;
		create special_police number: police_count{
			is_servicing <- true;
		}
	}
	
	reflex updateTHT{
		tht <- 0;
		loop i over: investor{
			tht <- tht + i.tht; 
		}
	}
	
	//stop simulation at year 50
//	reflex stopAtYear100 when: cycle=1200{
//		do pause;
//	}
	
	//start checking once all investor already have investments
	//stop simulation when the rotation years of all investor is finished
	reflex waitForHarvest when: length(investor)>0{	//and (length(investor where !empty(each.my_plots)) = length(investor)) 
    	loop i over: investor where (each.my_plot != nil){
    		if(i.my_plot.rotation_years =0 and i.waiting){
//    			ask university_si{
//    				list<trees> trees_to_harvest_n <- (getTreesToHarvestSH(i.my_plot)) where (each.type = NATIVE);
//    				do harvestEarning(i, timberHarvesting(false, i.my_plot, trees_to_harvest_n), NATIVE, false);
//    				list<trees> trees_to_harvest_e <- (getTreesToHarvestSH(i.my_plot)) where (each.type = EXOTIC);
//					do harvestEarning(i, timberHarvesting(false, i.my_plot, trees_to_harvest_e), EXOTIC, false);
//					do hirePlanter(i.my_plot, 0);
//    			}
    			i.waiting <- false;	
    		}else{
    			write "Rotation year remaining: "+i.my_plot.rotation_years;	
    		}
    	}
    }
    
    reflex warnedCMReportFromSP{
    	int temp_count <- 0;
		ask special_police{
			temp_count <- temp_count + self.total_comm_members_reprimanded; 
		}
		total_warned_CM <- temp_count;
    }
}

species university_si{
	list<plot> my_invested_plots;		//list of plots invested by the university
	list<investor> current_investors <- investor where (each.my_plot != nil) update: investor where (each.my_plot != nil);
	
	float mcost_of_native <- 5.0; //management cost in man hours of labor
	float mcost_of_exotic <- 4.0; //management cost in man hours of labor
	float pcost_of_native <- 1.0;	//planting cost in man hours of labor
	float pcost_of_exotic <- 1.0;	//planting cost in man hours of labor
	
	float labor_price <- 3.0; //per months
	
	int ANR_instance <- 0; 
	float current_labor_cost <- 0.0;
	float current_harvest_cost <- 0.0;
	
	bool investment_open <- length(my_nurseries) >= nursery_count/2 update: length(my_nurseries) >= nursery_count/2;
	list<plot> my_nurseries;	//list of nurseries managed by university
	list<trees> my_saplings <- [] update: (my_saplings where !dead(each)); //contains all saplings in the nusery, remove all the dead saplings
	list<labour> n_laborers <- [];
	list<plot> harvestable_plot <- plot where (each.stand_basal_area > 12 and !each.is_nursery) update: plot where (each.stand_basal_area > 12);
	
	//candidate nursery are those plots with road 
	//nursery plots are chosen based on the distance from river
	reflex updateNurseryPlots when: length(my_nurseries)<nursery_count{
		list<plot> candidate_plots <- (plot where (each.is_candidate_nursery)) sort_by each.distance_to_river;
		int needed_nurseries <- nursery_count-length(my_nurseries);
		int actual_count <- (length(candidate_plots) <= needed_nurseries)?length(candidate_plots):needed_nurseries;
		
		if(actual_count > 0){
			list<plot> nurseries <- candidate_plots[0::actual_count];
	//		write "needed_nurseries: "+needed_nurseries+" actual_count: "+actual_count;
			
			loop n over: nurseries{
				n.is_nursery <- true;
				n.is_candidate_nursery <- false;
				n.nursery_type <- NATIVE;
				add n to: my_nurseries;
				do hireNurseryLaborer(n);
	//			write "Saplings in nursery: "+length(n.plot_trees where (each.state = SAPLING));
				add all: (n.plot_trees where (each.state = SAPLING)) to: my_saplings;
				write "I AM nursery: "+n.name;
			}			
		}else{
			write "No candidate nursery plots found";
		}
	}
	
	//once hired, nursery laborer either attends to the plot (manage_nursery) or goes out to gather seedlings (assigned_nursery)
	action hireNurseryLaborer(plot n_plot){
		list<labour> free_laborer <- (sort_by((labour where (each.state = "vacant")), each.total_earning));
			
		if(length(free_laborer) > 0){
			ask first(free_laborer){
				is_nursery_labour <- true;
				current_plot <- n_plot;
				my_assigned_plot <- n_plot;	//assigned plot
				location <- n_plot.location;
				add self to: n_plot.my_laborers;
				add self to: myself.n_laborers;
			}	
		}
	}
		
	/*
	 * Determine amount of investment needed per hectare
		Given the current number of trees in the plot, 
        determine the cost needed to plant new trees (how many trees are to be planted)
	 */
	 
	//everytime a community laborer completes a task, the university pays them
	/*	float total_earning <- 0.0;		//total earning for the entire simulation
	 *  float current_earning <- 0.0; //earning of the community at the current commitment
	 */ 
	
	action payLaborer(labour cl){
		
		float cost <- 0.0; 
		//serviced * labor_cost
		if(cl.is_harvest_labour){
			cost <- HARVESTING_LCOST;
		}
		else if(cl.is_planting_labour){
			cost <- PLANTING_LCOST;
		}else if(cl.is_nursery_labour){
			cost <- NURSERY_LCOST;
		}
		
//		if(cl.com_identity != nil){
//			cl.com_identity.current_earning <- cl.com_identity.current_earning + cost;
//		}else{
//			cl.total_earning <- cl.total_earning + cost;
//		}
	
//		write "Before payLaborer: "+cl.total_earning;
		cl.total_earning <- cl.total_earning + cost;
//		write "After payLaborer: "+cl.total_earning;
		current_labor_cost <- current_labor_cost + cost;
	}
	
	float getPlantingCost(int t_type){
		return ((t_type = 1)?pcost_of_exotic:pcost_of_native);
	}
	
	float getManagementCost(int t_type){
		return ((t_type = 1)?mcost_of_exotic:mcost_of_native);
	}
	
	//for each plot, determine if plot is investable or not
	//investable -> if (profit > cost & profit > threshold)
	//profit : current trees in n years, where n = rotation of newly planted trees
	//cost : number of wildlings that needs to be planted + maintenance cost per wildling
	//note: consider that the policy of the government will have an effect on the actual profit, where only x% can be harvested from a plot of y area
	plot getInvestablePlot{
		list<plot> investable_plots <- reverse(sort_by(plot where (!each.is_near_water and !each.is_nursery and !each.is_invested), each.stand_basal_area)); 

		return first(investable_plots);
	}

	//returns true if successful, else false
	//idea: investor decides given the following information, # of species per each plot, future value, investment value, investment payout
//	action investOnPlot(investor investing_investor, plot chosen_plot){
//		//confirm investment 
//		chosen_plot.is_nursery <- false;
//		investing_investor.my_plot <- chosen_plot;
//		investing_investor.investment <- chosen_plot.investment_cost;
//		
//		//assign laborer and get available seeds from the nursery 		 
//		do setRotationYears(chosen_plot);		//set rotation years to plot
//		add chosen_plot.rotation_years to: investing_investor.investment_rotation_years;
//		chosen_plot.is_itp <- true;
//		
//		//1. get all the trees that will be harvested via selective harvesting
////		list<trees> trees_to_harvest_n <- (getTreesToHarvestSH(chosen_plot)) where (each.type = NATIVE);
////		do harvestEarning(investing_investor, timberHarvesting(true, chosen_plot, trees_to_harvest_n), NATIVE, false);
////		list<trees> trees_to_harvest_e <- (getTreesToHarvestSH(chosen_plot)) where (each.type = EXOTIC);
////		do harvestEarning(investing_investor, timberHarvesting(true, chosen_plot, trees_to_harvest_e), EXOTIC, false);
////		do hirePlanter(chosen_plot, 0);	
//		investing_investor.waiting <- true;
//		write("!!!Investment commenced!!!");
//	}
	
	//called at the beginnning of the investment 
	//sets projected_profit (c_plot.projected_profit) = future_profit of all trees in the plot assuming 0% mortality
	//sets investment_cost (c_plot.investment_cost) = labor_harvester(start, end) + labor_planter(start) 
	int getInvestmentDetailsOfPlot(plot c_plot){
		//get the # of saplings in the nursery
		int count_native <- length(getAllSaplingsInNurseries(NATIVE));	//get the count of native trees in the c_plot (after filling up the plot) 
		int count_exotic <- length(getAllSaplingsInNurseries(EXOTIC));	//get the count of exotic trees in the c_plot (after filling up the plot)
		
		int needed_native <- (average_no_trees_in1ha > (count_native + count_exotic))?(average_no_trees_in1ha - (count_native + count_exotic)):0;	//given the existing count, determine how much more is needed to fill the plot
		
//		write "NATIVE: "+count_native+" EXOTIC: "+count_exotic+" NEEDED: "+needed_native;
//		
//		float needed_cost <- needed_native * (NATIVE_price_per_SAPLING);	////buying_sapling_cost = determine the cost of the needed saplings
//		
//		list<trees> trees_tobe_harvested <- getTreesToHarvestSH(c_plot); //given selective harvesting rule, count the trees that will be removed
//		int total_trees_tobeplanted <- count_native + count_exotic + needed_native - (length(c_plot.plot_trees)-length(trees_tobe_harvested));
//		int labor_needed <- int(total_trees_tobeplanted/LABOUR_PCAPACITY)+1;
//		float labor_cost <- labor_needed * PLANTING_LCOST;//labor_cost = compute the planting cost given all the needed saplings
//		
//		write "Projected labor cost: "+labor_cost;
//		//get the average harvesting cost for a filled up hectare (noting the rule on selective harvesting)
//		c_plot.investment_cost <- (int(total_trees_tobeplanted/LABOUR_PCAPACITY)+1) * HARVESTING_LCOST;
//	
//		count_native <- count_native + length(trees_tobe_harvested where (each.type=NATIVE));
//		count_exotic <- count_exotic + length(trees_tobe_harvested where (each.type=EXOTIC));
//		write "Native: "+(count_native+needed_native)+" Exotic: "+count_exotic;
//		c_plot.projected_profit <- projectProfit(count_native+needed_native, count_exotic);
		return needed_native; //return the needed_native in case the investor agrees with the deal
	}
	//end get InvestmentDeatilsOfPlot
	//	the investor decides given projected profit and investment_cost and risk profile
	//	once the investor enters the deal, the university fills up the plot with all the needed saplings
	//	earning happens twice, at the beginning and in the end of the investment 
	//	the investor decides whether to be active or passive depending on the actual gain after the investment 
	
	//projected profit: 
	//	given all the trees in the stand, assume that they will all be adult at the end of the rotation 
//	float projectProfit(int ct_native, int ct_exotic){
//		float total_bdft_n <- 0.0;
//		float total_bdft_e <- 0.0;
//		
//		if(ct_native > 0){
//			create trees number: ct_native returns: n_trees{
//				dbh <- n_adult_ave_DBH;
//				type <- NATIVE;
//			}
//			ask market{
//				total_bdft_n <- getTotalBDFT(n_trees);	
//			}
//			ask n_trees{
//				do die;
//			}
//		}
//		if(ct_exotic > 0){
//			create trees number: ct_exotic returns: e_trees{
//				dbh <- e_adult_ave_DBH;
//				type <- EXOTIC;
//			}	
//			ask market{
//				total_bdft_e <- getTotalBDFT(e_trees);
//			}
//			ask e_trees{
//				do die;
//			}
//		}
//		
//		float total_profit; 
//		ask market {
//			total_profit <- (getProfit(NATIVE, total_bdft_n) + getProfit(EXOTIC, total_bdft_e))*0.75;
//		}
//
//		return total_profit;
//	}
	
	//pays the hired harvester and gives the earning to laborer
	//compute cost
	action harvestEarning(investor i, float thv, int type, bool is_final_harvesting){
		//give payment to investor
	    float c_profit;
	    ask market{
	    	c_profit <- getProfit(type, thv);
	    }
	    
	    if(i != nil){
	    	i.tht <- i.tht + 1;
	    	i.recent_profit <- i.recent_profit + (c_profit*0.75);		//actual profit of investor is 75% of total profit
		    i.total_profit <- i.total_profit + (c_profit*0.75);
		    i.waiting <- is_final_harvesting;
		    
//		    write "CProfit: "+c_profit+" thv: "+thv;
//		    write "Investor earning... "+i.recent_profit;	
	    }
	    
	    total_ITP_earning <- total_ITP_earning + (c_profit * ((i!=nil)?0.25:1.0));
	    write "University earning... "+total_ITP_earning;
	}

	float timberHarvesting(plot chosen_plot, list<trees> tth){
//		//2. hire harvesters: 2x the number of trees that will be harvested
//		//-- harvest process, harvest each of the trees in n parallel steps, where n = # of harvesters hired --
		//needed laborers is based on trees_length/capacity
		list<labour> hired_harvesters <- getLaborers(int(length(tth)/LABOUR_TCAPACITY)+1);	//if there's no laborer avail, get all assigned_planter
		 
		float harvested_bdft <- sendHarvesters(hired_harvesters, chosen_plot, tth);	
		
		//4. compute total bdft harvested BF of 1 tree = volume/12, total bdft = sumofall bf
		float i_harvesting_cost <- harvested_bdft * HARVESTING_COST;
		current_harvest_cost <- current_harvest_cost + i_harvesting_cost;
		
		//TODO: 5. add forest tax per tree harvested
		
		return harvested_bdft;
	}	

	//harvests upto capacity
	//only returns what can be harvested in the plot
	list<trees> getTreesToHarvestSH(plot pth){
		list<trees> trees_above_th <- pth.plot_trees where (each.dbh >= 60);
		
		list<trees> tree60to70 <- trees_above_th where (each.dbh >= 60 and each.dbh < 70);	//25% of trees with dbh[60,70)
		trees_above_th <- trees_above_th - tree60to70;
		tree60to70 <- (tree60to70[0::int(length(tree60to70)*0.25)]);
		
		list<trees> tree70to80 <- trees_above_th where (each.dbh >= 70 and each.dbh < 80);	//75% of trees with dbh[70, 80)
		trees_above_th <- trees_above_th - tree70to80;
		tree70to80 <- (tree70to80[0::int(length(tree70to80)*0.75)]);
		
		return tree60to70 + tree70to80 + trees_above_th;
	}
	
	list<labour> getLaborers(int needed_laborers){ 
		list<labour> available_laborers <- labour where ((each.labor_type = each.OWN_LABOUR and each.state="vacant" and !each.is_planting_labour and !each.is_harvest_labour));	//get own laborers that are not nursery|planting labours
		int still_needed_harvesters <- needed_laborers - length(available_laborers);
		
		write "Available laborers: "+length(available_laborers)+" still needed: "+still_needed_harvesters;
	
		list<labour> hired_laborers <- available_laborers sort_by each.total_earning;
		
		if(still_needed_harvesters < 0){
			//get only the first LABOUR_TCAPACITY laborers
			hired_laborers <- hired_laborers[0::needed_laborers];
		}else{
			//hire from available community
//			list<comm_member> avail_member <- comm_member where (each.state = "potential_partner" and each.instance_labour = nil);
//			int total_to_hire <- (length(avail_member) > still_needed_harvesters)?still_needed_harvesters:length(avail_member);
//			if(total_to_hire = 0) { total_to_hire <- 1;}
//			
//			loop i from: 0 to: total_to_hire-1{
//				comm_member cm <- first(avail_member);	//use the first member;
//				if(cm != nil){
//					create labour returns: new_labour {
//						labor_type <- COMM_LABOUR; 
//						com_identity <- cm;
//					}	
//					add first(new_labour) to: available_laborers;
//					cm.instance_labour <- first(new_labour);
//					remove cm from: avail_member;	
//				}
//			}
		}
//		
//		hiring_prospect <- (length(available_laborers) < needed_laborers or is_also_planters)?true:false;	//if the total labour isn't supplied, create a call for hiring prospect

		return hired_laborers;
	}
	
	//type 0: automatically base on harvesting age of native
	//type 1: automatically base on harvesting age of exotic
	action setRotationYears(plot the_plot){
		float mean_age_tree <- mean(the_plot.plot_trees accumulate each.age); //get the minimum age of the tree in the plot
		
		int n_count <- length(the_plot.plot_trees where (each.type = NATIVE));
		int e_count <- length(the_plot.plot_trees where (each.type = EXOTIC));
		
		
		if(n_count > e_count){	
			the_plot.rotation_years <- (harvesting_age_native < mean_age_tree)?harvesting_age_native:int(harvesting_age_native - mean_age_tree);
		}else{
			the_plot.rotation_years <- (harvesting_age_exotic < mean_age_tree)?harvesting_age_exotic:int(harvesting_age_exotic - mean_age_tree);
		}		
	}
	
	list<trees> getAllSaplingsInNurseries(int t_type){
		list<plot> nurseries <- plot where (each.is_nursery);
		list<trees> saplings <- [];
		
		ask nurseries{
			list<trees> s <- (plot_trees where (each.state = SAPLING and each.type = t_type));
			saplings <<+ s;
		}
		
		return saplings;
	}

	//the centre of the square is by default the location of the current agent in which has been called this operator.
	list<geometry> getSquareSpaces(geometry main_space, list<trees> to_remove_space, bool is_itp, int n_space){
		geometry t_shape <- nil; 
		int needed_space <- (is_itp)?5:1;
			
		ask to_remove_space{
			t_shape <- t_shape + square(needed_space#m);
		}
			
		geometry remaining_space <- main_space - t_shape;	//remove all occupied space;
		return (to_squares(remaining_space, n_space#m) where (each.area >= (n_space^2)#m));	//n_space, assumed space needed by the trees that will be planted		
	}	
	
	//buys native saplings
	list<trees> buySaplings(int saplings_to_be_bought){
		//no location, my_plot yet
		create trees number: saplings_to_be_bought returns: bought_saplings{
			dbh <- n_sapling_ave_DBH;
			type <- NATIVE;
			age <- dbh/growth_rate_native;
			is_new_tree <- true; 
			shade_tolerant <- true;
			state <- SAPLING;
			th <- calculateHeight(dbh, type);
			basal_area <- #pi * (dbh^2)/40000;
			my_plot <- nil;
			location <- point(0,0,0);
		}
		return bought_saplings;
	}
	
	//Prioritize replanting native trees
	//native count is the number of native saplings bought by the university to fill the plot with trees
	//native_count > 0
	// after investment, must fill up the plot to capacity given the saplings in the nursery and buying #native_count of saplings if there are more spaces
	// TODO: incur additional cost 
	bool replantPlot(plot the_plot){
		//Step 1: Given the total saplings contained in the nursery -> my_saplings
		//Step 2: Get the capacity of the plot (for replanting)
		list<geometry> available_spaces <- getSquareSpaces(the_plot.shape, the_plot.plot_trees, true, 3);
		int plot_capacity <- length(available_spaces); 	
//		write "Available spaces: "+plot_capacity;
		
		//Step 3: hire planters based on planting_capacity/LABOUR_TCAPACITY
		int needed_planters <- int(ceil(plot_capacity/LABOUR_TCAPACITY));
//		write "Needed planters: "+needed_planters;
		list<labour> available_planters <- getLaborers(needed_planters);
//		write "Total hired planters: "+length(available_planters);
		
		if(length(available_planters)>0){
			int available_saplings <- length(my_saplings);
			
			//get how many saplings should be bought given available laborers and available space
			list<trees> saplings_to_be_planted <- [];
			int saplings_to_be_bought <- 0;
			int planting_capacity <- length(available_planters)*LABOUR_TCAPACITY;
			if(planting_capacity > available_saplings){
				saplings_to_be_bought <- (length(available_planters)*LABOUR_TCAPACITY) - available_saplings;
				remove all: my_saplings from: my_saplings;
			}else{
				add all: my_saplings[0::planting_capacity] to: saplings_to_be_planted;
				remove all: my_saplings[0::planting_capacity] from: my_saplings; 
			}
			
			list<trees> bought_saplings <- buySaplings(saplings_to_be_bought);
		
			do sendPlanters(available_planters, the_plot, saplings_to_be_planted + bought_saplings, available_spaces);
			return true;			
		}
		return false;
	}
	
	action sendPlanters(list<labour> planters, plot ptp, list<trees> trees_to_be_planted, list<geometry> available_spaces){
		int count_of_trees <- length(trees_to_be_planted);
		//assign plant to planter		
		loop p over: planters{
			p.is_planting_labour <- true;
			p.my_assigned_plot <- ptp;
			p.current_plot <- ptp;
			add p to: ptp.my_laborers;
			
			list<trees> assigned_trees <- trees_to_be_planted[0::((count_of_trees<LABOUR_TCAPACITY)?count_of_trees:LABOUR_TCAPACITY)];
			
			add all: available_spaces[0::length(assigned_trees)] to: p.planting_spaces;
			remove all: p.planting_spaces from: available_spaces; 
			
			add all: assigned_trees to: p.my_trees;
			remove all: assigned_trees from: trees_to_be_planted;
			
			count_of_trees <- length(trees_to_be_planted);
		}
	}

	//returns the hired harvesters that completed the harvesting
	//marked the trees and harvests
	float sendHarvesters(list<labour> hh, plot pth, list<trees> trees_to_harvest){
		float total_bdft;
		ask market{
			total_bdft <- getTotalBDFT(trees_to_harvest);	
		}
		
		remove trees_to_harvest from: pth.plot_trees;
		
		pth.is_harvested <- true;
		
		//the laborer marks the tree
		loop while:(length(trees_to_harvest) > 0 and length(hh) > 0){
			labour labour_instance <- first(hh);
			list<trees> to_harvest <- trees_to_harvest[0::((length(trees_to_harvest)>=LABOUR_TCAPACITY)?LABOUR_TCAPACITY:length(trees_to_harvest))];
			ask to_harvest{
				is_marked <- true;
			}
			//put the labour_instance on the plot where the trees to be harvested are
			ask labour_instance{
				is_harvest_labour <- true;
				current_plot <- pth;
				my_assigned_plot <- pth;
				add self to: my_assigned_plot.my_laborers;
				add all: to_harvest to: marked_trees;
				state <- "assigned_itp_harvester";	
			}
			remove labour_instance from: hh;
			remove all: to_harvest from: trees_to_harvest;
		}
		
		return total_bdft;
	}
		
	//for ANR when: there's at least 1 vacant laborers, sba < 5, and plot_trees < 200
	//1 available vacant laborer = 1 plot 
	reflex monitorSBAforANR when: ((labour count (each.state = "vacant"))>0){
		write "Performing ANR on plots";
		list<plot> plot_for_ANR <- sort_by((plot where (!each.is_ANR and !each.is_nursery and each.stand_basal_area < 5.0 and (length(each.plot_trees) < 200))), each.stand_basal_area);	
		
		loop pfa over: plot_for_ANR{
			if(!replantPlot(pfa)){
				break;	//once it breaks it means that there are no more laborers avaialble to conduct ANR
			}
			ANR_instance <- ANR_instance + 1;
			pfa.is_ANR <- true;
			write "ANR instance: "+ANR_instance+" plot: "+pfa.name;
		}
		write "end of ANR";
	}
	
	reflex checkForITPHarvesting when: length(my_nurseries) > (nursery_count/2){	//will harvest only when I already have at least half of wanted nursery
		write "University harvesting";
		write "total_ITP_earning before: "+total_ITP_earning;
		loop h_plot over: harvestable_plot{
//			write "Harvesting in plot: "+h_plot.name+" sba: "+h_plot.stand_basal_area;
    		list<trees> trees_to_harvest <- getTreesToHarvestSH(h_plot);
    		list<trees> native_trees <- (trees_to_harvest where (each.type = NATIVE));
    		list<trees> exotic_trees <- trees_to_harvest - native_trees;
    		
    		if(native_trees != []){
//    			write "Harvesting "+length(native_trees)+" native trees";
    			do harvestEarning(nil, timberHarvesting(h_plot, native_trees), NATIVE, false);	
    		}
    		if(exotic_trees != []){
//    			write "Harvesting "+length(exotic_trees)+" exotic trees";
    			do harvestEarning(nil, timberHarvesting(h_plot, exotic_trees), EXOTIC, false);	
    		}	
			if(!replantPlot(h_plot)){
				break;
			}
		}
		write "total_ITP_earning after: "+total_ITP_earning;
	}
	
	//at every step, determine to overall cost of running a managed forest (in the light of ITP)
	reflex computeTotalCost {
		float police_cost <- 1000.0;
		float ANR_cost <- 10725.0;
		
		float nursery_other_cost <- 0.0;
		float total_ANR_cost <- 0.0;
		
		//added only at the start of the start of the new year, computing all the cost from the previous year
		if(current_month = 0){	//start of the new year
			nursery_other_cost <- total_seedlings_replanted * 2.40;	//additional management cost per seedlings replanted is 2.40 each
			total_seedlings_replanted <- 0;
			total_ANR_cost <- ANR_instance * ANR_cost;
		}
		 
		int working_sp <- length(special_police where (each.is_servicing));
		
		total_management_cost <- total_ANR_cost + total_management_cost + nursery_other_cost + current_labor_cost + current_harvest_cost;	//currently working nursery labor and cost
		total_ANR_instance <- total_ANR_instance + ANR_instance;
		
		ANR_instance <- 0; 
		current_labor_cost <- 0.0;
		current_harvest_cost <- 0.0;
		
	}	
}


