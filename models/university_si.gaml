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
import "comm_member.gaml"
import "special_police.gaml"

/* Insert your model definition here */
global{
	int NURSERY_LABOUR <- 12; //labor required per nursery, constant
	int HARVEST_LABOUR <- 1;
	int PLANTING_LABOUR <- 6;
	int LABOUR_PCAPACITY <- 15;	//number of trees that the laborer can plant/manage
	
	//fixed rate
	float NATIVE_price_per_SAPLING <- 100.0; //TODO: must set
	float NURSERY_LCOST <- 12810.0;	//labor per month https://velocityglobal.com/resources/blog/minimum-wage-by-country
	float HARVESTING_LCOST <- 13834.51;	//one month labor
	float PLANTING_LCOST <- 25.0;
	float POLICE_COST <- 18150.0; //average wage per month https://www.salaryexpert.com/salary/job/forest-officer/philippines
	
	float HARVESTING_COST <- 17.04; //cost = (0.28+0.33)/2 usd per bdft, 17.04php
	
	int average_no_trees_in1ha <- 20;
	int police_count <- 2 update: police_count;
	int plot_size <- 1 update: plot_size;
	int laborer_count <- 10 update: laborer_count;
	int nlaborer_count<- 5 update: nlaborer_count;
	float planting_space <- 1.0 update: planting_space; 
	int planting_age <- 1 update: planting_age;
	int nursery_count <- 5 update: nursery_count;
	float harvest_policy <- 0.5 update: harvest_policy;
	float dbh_policy <- 50.0 update: dbh_policy; 
	bool plant_native <- true update: plant_native;
	bool plant_exotic <- false update: plant_exotic;
	int itp_type; //0 ->plant native, 1->plant exotic, 2->plant mix 
	bool hiring_prospect <- false;
	
	int harvesting_age_exotic <- 25 update: harvesting_age_exotic;	//temp
	int harvesting_age_native <- 25 update: harvesting_age_native;	//actual 40
	
	bool assignedNurseries <- false;
	bool start_harvest <- false;
	
	int tht <- 0;
	
	float total_management_cost <- 0.0;
	float total_ITP_earning <- 0.0;
	int total_ANR_instance <- 0;
	int total_warned_CM <- 0;
	
	int total_seedlings_replanted <- 0;	//per year
	
	init{
		create market;
		create labour number: laborer_count{
			labor_type <- OWN_LABOUR; 
		}
		create university_si;
		create special_police number: police_count{
			is_servicing <- true;
		}
		
		itp_type <- (plant_native and plant_exotic)?2:(plant_native?0:1);
		
		//always set plot 263 as a nursery
		ask university_si{
			do setNursery(first(plot where (each.name = "plot263")), true);	
		}
	}
	
	reflex updateTHT{
		tht <- 0;
		loop i over: investor{
			tht <- tht + i.tht; 
		}
	}
	
	//automatically execute when there are no laborers assigned to nurseries
	reflex assignLaborersToNurseries when: (!assignedNurseries){
		ask university_si{
			do assignNurseries;
			if(length(my_nurseries) >= nursery_count){	//start ITP if there's enough nurseries
				do updateInvestors;	 
				assignedNurseries <- true;
			}else{
				write "Not ready for investment";
			}		
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
    			ask university_si{
    				list<trees> trees_to_harvest_n <- (getTreesToHarvestSH(i.my_plot)) where (each.type = NATIVE);
    				do harvestEarning(i, timberHarvesting(false, i.my_plot, trees_to_harvest_n), NATIVE, false);
    				list<trees> trees_to_harvest_e <- (getTreesToHarvestSH(i.my_plot)) where (each.type = EXOTIC);
					do harvestEarning(i, timberHarvesting(false, i.my_plot, trees_to_harvest_e), EXOTIC, false);
					do hirePlanter(i.my_plot);
    			}
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
	list<plot> my_nurseries;	//list of nurseries managed by university
	list<investor> current_investors <- [];
	
	float mcost_of_native <- 5.0; //management cost in man hours of labor
	float mcost_of_exotic <- 4.0; //management cost in man hours of labor
	float pcost_of_native <- 1.0;	//planting cost in man hours of labor
	float pcost_of_exotic <- 1.0;	//planting cost in man hours of labor
	
	float labor_price <- 3.0; //per months
	
	int ANR_instance <- 0; 
	float current_labor_cost <- 0.0;
	float current_harvest_cost <- 0.0;
	
	int has_hired <- -1;
	
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
		}else if(cl.is_planting_labour){
			cost <- PLANTING_LCOST;	
		}else{
			cost <- NURSERY_LCOST;
		}
		
		if(cl.com_identity != nil){
			cl.com_identity.current_earning <- cl.com_identity.current_earning + cost;
		}else{
			cl.total_earning <- cl.total_earning + cost;
		}
		current_labor_cost <- current_labor_cost + cost;
			
	}
	

	action updateInvestors{
		current_investors <- investor where (each.my_plot != nil);
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
	action investOnPlot(investor investing_investor, plot chosen_plot, int t_type){
		//confirm investment 
		chosen_plot.is_nursery <- false;
		investing_investor.my_plot <- chosen_plot;
		investing_investor.investment <- chosen_plot.investment_cost;
		
		//assign laborer and get available seeds from the nursery 		 
		do setRotationYears(chosen_plot, t_type);		//set rotation years to plot
		add chosen_plot.rotation_years to: investing_investor.investment_rotation_years;
		chosen_plot.is_itp <- true;
		
		//1. get all the trees that will be harvested via selective harvesting
		list<trees> trees_to_harvest_n <- (getTreesToHarvestSH(chosen_plot)) where (each.type = NATIVE);
		do harvestEarning(investing_investor, timberHarvesting(true, chosen_plot, trees_to_harvest_n), NATIVE, false);
		list<trees> trees_to_harvest_e <- (getTreesToHarvestSH(chosen_plot)) where (each.type = EXOTIC);
		do harvestEarning(investing_investor, timberHarvesting(true, chosen_plot, trees_to_harvest_e), EXOTIC, false);
		do hirePlanter(chosen_plot);
		investing_investor.waiting <- true;
		write("!!!Investment commenced!!!");
	}
	
	//called at the beginnning of the investment 
	//sets projected_profit (c_plot.projected_profit) = future_profit of all trees in the plot assuming 0% mortality
	//sets investment_cost (c_plot.investment_cost) = labor_harvester(start, end) + labor_planter(start) 
	action getInvestmentDetailsOfPlot(plot c_plot){
		//get the # of saplings in the nursery
		int count_native <- length(getAllSaplingsInNurseries(NATIVE));	//get the count of native trees in the c_plot (after filling up the plot) 
		int count_exotic <- length(getAllSaplingsInNurseries(EXOTIC));	//get the count of exotic trees in the c_plot (after filling up the plot)
		
		int needed_native <- (average_no_trees_in1ha < (count_native + count_exotic))?(average_no_trees_in1ha - (count_native + count_exotic)):0;	//given the existing count, determine how much more is needed to fill the plot
		float needed_cost <- needed_native * (NATIVE_price_per_SAPLING);	////buying_sapling_cost = determine the cost of the needed saplings
		
		int trees_tobe_harvested <- 0; //given selective harvesting rule, count the trees that will be removed
		int total_trees_tobeplanted <- count_native + count_exotic + needed_native - (length(c_plot.plot_trees)-trees_tobe_harvested);
		int labor_needed <- int(total_trees_tobeplanted/LABOUR_PCAPACITY)+1;
		float labor_cost <- labor_needed * PLANTING_LCOST;//labor_cost = compute the planting cost given all the needed saplings
		//get the average harvesting cost for a filled up hectare (noting the rule on selective harvesting)
		float init_harvest_cost <- (int(total_trees_tobeplanted/LABOUR_PCAPACITY)+1) * HARVESTING_LCOST;
		c_plot.projected_profit <- projectProfit(count_native+needed_native, count_exotic);
	}
	//end get InvestmentDeatilsOfPlot
	//	the investor decides given projected profit and investment_cost and risk profile
	//	once the investor enters the deal, the university fills up the plot with all the needed saplings
	//	earning happens twice, at the beginning and in the end of the investment 
	//	the investor decides whether to be active or passive depending on the actual gain after the investment 
	
	//projected profit: 
	//	project the dbh of the tree after the rotation year (c_plot.rotation_years)
	//  set dbh 
	float projectProfit(int ct_native, int ct_exotic){
		return 0.0;
	}
	
	//pays the hired harvester and gives the earning to laborer
	//compute cost
	action harvestEarning(investor i, float thv, int type, bool is_final_harvesting){
		//give payment to investor
	    float c_profit <- 0.0;
	    c_profit <- thv * ((type = EXOTIC)?exotic_price_per_volume:native_price_per_volume);
	    
	    if(i != nil){
	    	i.tht <- i.tht + 1;
	    	i.recent_profit <- i.recent_profit + (c_profit*0.75);		//actual profit of investor is 75% of total profit
		    i.total_profit <- i.total_profit + (c_profit*0.75);
		    i.waiting <- is_final_harvesting;
		    
		    write "CProfit: "+c_profit+" thv: "+thv;
		    write "Investor earning... "+i.recent_profit;	
	    }
	    
	    total_ITP_earning <- total_ITP_earning + (c_profit * ((i!=nil)?0.25:1.0));
	    write "University earning... "+total_ITP_earning;
	}

	float timberHarvesting(bool is_first_harvest, plot chosen_plot, list<trees> tth){
		//2. hire harvesters: 2x the number of trees that will be harvested
		//-- harvest process, harvest each of the trees in n parallel steps, where n = # of harvesters hired --
		
		list<labour> hired_harvesters <- getLaborers(length(tth)*2);
		float harvested_bdft <- sendHarvesters(hired_harvesters, chosen_plot, tth);
		
		//COST: 
		//3. pay hired harvesters 1month worth of wage
		loop laborers over: hired_harvesters{
			do payLaborer(laborers);
			laborers.is_harvest_labour <- false;
		}
		//4. compute total bdft harvested BF of 1 tree = volume/12, total bdft = sumofall bf
		float i_harvesting_cost <- harvested_bdft * HARVESTING_COST;
		current_harvest_cost <- current_harvest_cost + i_harvesting_cost;
		//5. add forest tax per tree harvested
		
		return harvested_bdft;
	}

	//harvests upto capacity
	//only returns what can be harvested in the plot
	list<trees> getTreesToHarvestSH(plot pth){
		list<trees> p <- pth.plot_trees where !dead(each);
		
		list<trees> tree60to70 <- p where (each.dbh >= 60 and each.dbh < 70);
		tree60to70 <- (tree60to70[0::int(length(tree60to70)*0.25)]);
		list<trees> tree70to80 <- p where (each.dbh >= 70 and each.dbh < 80);
		tree70to80 <- (tree70to80[0::int(length(tree70to80)*0.75)]);
		list<trees> tree80up <- p where (each.dbh >= 80);

		return tree60to70 + tree70to80 + tree80up;
	}
	
	list<labour> getLaborers(int needed_laborers){
		list<labour> available_laborers <- labour where (each.labor_type = each.OWN_LABOUR and each.state="vacant");	//get own laborers that are not nursery|planting labours
		int still_needed_harvesters <- needed_laborers - length(available_laborers);
		if(still_needed_harvesters > 0){	//hires from the community if there lacks need
			list<comm_member> avail_member <- comm_member where (each.state = "potential_partner" and each.instance_labour = nil);
			int total_to_hire <- (length(avail_member) > still_needed_harvesters)?still_needed_harvesters:length(avail_member);
			
			if(total_to_hire = 0) { total_to_hire <- 1;}
			
			loop i from: 0 to: total_to_hire-1{
				comm_member cm <- first(avail_member);	//use the first member;
				if(cm != nil){
					create labour returns: new_labour {
						labor_type <- COMM_LABOUR; 
						com_identity <- cm;
					}	
					add first(new_labour) to: available_laborers;
					cm.instance_labour <- first(new_labour);
					remove cm from: avail_member;	
				}
			}
		}
		
		hiring_prospect <- (length(available_laborers) < needed_laborers)?true:false;	//if the total labour isn't supplied, create a call for hiring prospect
		return available_laborers;
	}
	
	//returns the hired harvesters that completed the harvesting
	float sendHarvesters(list<labour> hh, plot pth, list<trees> trees_to_harvest){
		list<trees> tth <- trees_to_harvest where !dead(each);
		float total_bdft <- getTotalBDFT(tth, pth);
		
		loop while:(length(tth) > 0 and length(hh) > 0){
			labour instance <- first(hh);
			trees to_harvest <- first(trees_to_harvest);
			ask instance{
				man_months <- [HARVEST_LABOUR, 1, 0];
				is_harvest_labour <- true;
				current_plot <- pth;
				plot_to_harvest <- pth;
				add to_harvest to: harvested_trees;
				state <- "assigned_itp_harvester";	
			}
			remove instance from: hh;
			remove to_harvest from: tth;
		}
		
		return total_bdft;
	}
	
	float getTotalBDFT(list<trees> tth, plot pth){
		float total_bdft <- 0.0;
		
		loop i over: tth{
			total_bdft <- total_bdft + (i.calculateVolume() / 12);	
		}
		pth.plot_trees <- (pth.plot_trees - tth);
		return total_bdft;
	}
	
	//type 0: automatically base on harvesting age of native
	//type 1: automatically base on harvesting age of exotic
	action setRotationYears(plot the_plot, int t_type){
		float mean_age_tree <- mean((the_plot.plot_trees where (each.type = itp_type)) accumulate each.age); //get the minimum age of the tree in the plot
		
		if(t_type = NATIVE){	
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
	
	//compute the number of new tree that the plot can accommodate
	//given type of tree, returns the number of spaces that can be accommodate wildlings
	int getAvailableSpaces(plot p, int type){
		//remove from occupied spaces
		geometry temp_shape <- p.removeTreeOccupiedSpace(p.shape, p.plot_trees);
		float temp_dbh <- determineDBHGrowth(type, planting_age);
		
		geometry tree_shape <- circle(temp_dbh);
		
		if(temp_shape = nil){return 0;}
		else{
			return int(temp_shape.area/tree_shape.area);	//rough estimate of the number of available spaces for occupation
		}	
	}
	
	//Prioritize replanting native trees
	bool hirePlanter(plot the_plot){
		//get the number of trees that can be accommodated in the plot
		int space_available <- getAvailableSpaces(the_plot, NATIVE)+getAvailableSpaces(the_plot, EXOTIC);
		
		//get the number of trees in the nurseries
		list<plot> nurseries <- plot where each.is_nursery;
		int tree_count <- 0;
		ask nurseries{
			tree_count <- tree_count + getSaplingsCountS(NATIVE) + getSaplingsCountS(EXOTIC);
		}
		
		int planting_capacity <- (space_available > tree_count)?tree_count:space_available;
		int needed_planters <- int(planting_capacity / LABOUR_PCAPACITY)+1;	//each laborer have planting capacity
		
		list<labour> avail_planters <- getLaborers(needed_planters);	//get laborers
		
		if(length(avail_planters) = 0){
			write "No available planters!";
			return false;
		}
		
		ask avail_planters{
			man_months <- [PLANTING_LABOUR, 1, 0];
			is_planting_labour <- true;
			plot_to_plant <- the_plot;
			state <- "assigned_planter";
		}
		write "Total hired planters: "+length(avail_planters)+" for plot: "+the_plot.name;
		
		//COST: 
		//3. pay hired harvesters 1month worth of wage
		loop laborers over: avail_planters{
			do payLaborer(laborers);
			laborers.is_planting_labour <- false;
		}
		
		return true;
	}
	
	float determineDBHGrowth(int t_type, int age){
		if(t_type=1){	//to plant exotic
			return max_dbh_exotic * (1-exp(-mahogany_von_gr * (current_month+age)));
		}else{		//to plant native
			return max_dbh_native * (1-exp(-mayapis_von_gr * (current_month+age)));
		}
	}	
	//determine if a plot is to be a nursery or not
	//	where there is a mother tree, it becomes a nursery
	action assignNurseries{
		list<plot> candidate_plots <- [];
		ask plot where (each.nursery_type = -1){
			if(length(plot_trees where each.is_mother_tree) > 0){
				add self to: candidate_plots;
			}
		}
		if(candidate_plots != nil and length(candidate_plots) > (nursery_count-1)){
			candidate_plots <- candidate_plots[0::(nursery_count-1)];
			bool is_native <- true;
			loop cp over: candidate_plots{
				is_native <- setNursery(cp, is_native);
			}
			add all: candidate_plots to: my_nurseries;	
		}
	}
	
	bool setNursery(plot n_plot, bool is_native){
		n_plot.is_nursery <- true;
		n_plot.nursery_type <- (is_native)?NATIVE:EXOTIC;
		return !is_native;	//next type
	}
	
	//hire 5 laborers 
	reflex hireNurseryLaborers{
		
		if((fruiting_months_N + fruiting_months_E) contains current_month){
			if(has_hired = -1){
				bool is_with_mother_trees; 
			
				ask university_si{
					is_with_mother_trees <- length(my_nurseries)>0; 
				}
				
				if(is_with_mother_trees){
					list<labour> nursery_laborers <- (sort_by(labour where (each.state = "vacant"), each.total_earning))[0::5];	//if there are laborers that the university manages
					
					//depending on the fruiting month, set the laborer to gather only that kind of fruit
					ask nursery_laborers{
						if(fruiting_months_N contains current_month){	//hire native tree fruit gatherer
							nursery_labour_type <- NATIVE;
							myself.has_hired <- NATIVE; 
						}else{	//hire exotic tree fruit gatherer
							nursery_labour_type <- EXOTIC;
							myself.has_hired <- EXOTIC;
						}	
						is_nursery_labour <- true;			
						current_plot <- one_of(plot);	//put laborer on a random location
						state <- "assigned_nursery";
					}
				}		
			}else{
				list<labour> hired_nursery_laborers <- labour where (each.nursery_labour_type = NATIVE or each.nursery_labour_type = EXOTIC);
				loop n_laborers over: hired_nursery_laborers{
					do payLaborer(n_laborers);
				}
				
			}
			
		}else if(has_hired != -1){ //not anymore fruiting season, and has hired someone from the previous fruiting season
			has_hired <- -1;
			
			list<plot> nurseries <- plot where each.is_nursery;
			list<labour> free_laborers <- (sort_by((labour where (each.state = "vacant")), each.total_earning))[0::length(nurseries)];
			
			ask free_laborers{
				is_nursery_labour <- true;
				nursery_labour_type <- -1;
				current_plot <- one_of(nurseries);
				remove current_plot from: nurseries;
				state <- "assigned_nursery";
			}
			
		}
	}
	
	reflex monitorSBAforANR{
		//get plots less than SBA = 35
		list<plot> plot_for_ANR <- sort_by((plot where (each.stand_basal_area < 35)), each.stand_basal_area);	//35 = threshold for sustainable stand basal area
		
		write "Performing ANR on plots";
		loop pfa over: plot_for_ANR{
			if(!hirePlanter(pfa)){
				break;
			}
			ANR_instance <- ANR_instance + 1;
		}
		write "end of ANR";
	}
	
	reflex checkForITPHarvesting{
		list<plot> pt <- plot where (each.stand_basal_area > 80);
		write "University harvesting";
		write "total_ITP_earning before: "+total_ITP_earning;
		loop p over: pt{
			write "Harvesting in plot: "+p.name+" sba: "+p.stand_basal_area;
			ask university_si{
    			list<trees> trees_to_harvest_n <- (getTreesToHarvestSH(p)) where (each.type = NATIVE);
    			do harvestEarning(nil, timberHarvesting(false, p, trees_to_harvest_n), NATIVE, false);
    			list<trees> trees_to_harvest_e <- (getTreesToHarvestSH(p)) where (each.type = EXOTIC);
				do harvestEarning(nil, timberHarvesting(false, p, trees_to_harvest_e), EXOTIC, false);
				do hirePlanter(p);
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



