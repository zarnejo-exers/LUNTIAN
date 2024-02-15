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
	int LABOUR_PCAPACITY <- 25;	//number of trees that the laborer can plant/manage
	
	//fixed rate
	float NURSERY_LCOST <- 12810.0;	//labor per month https://velocityglobal.com/resources/blog/minimum-wage-by-country
	float HARVEST_LCOST <- 13834.51;	//one month labor
	float PLANTING_LCOST <- 25.0;
	float POLICE_COST <- 18150.0; //average wage per month https://www.salaryexpert.com/salary/job/forest-officer/philippines
	
	float HARVESTING_COST <- 17.04; //cost = (0.28+0.33)/2 usd per bdft, 17.04php
	
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
	
	int harvesting_age_exotic <- 4 update: harvesting_age_exotic;	//temp
	int harvesting_age_native <- 4 update: harvesting_age_native;	//actual 40
	
	bool assignedNurseries <- false;
	bool start_harvest <- false;
	
	int tht <- 0;
	
	float total_management_cost <- 0.0;
	float total_ITP_earning <- 0.0;
	int total_ANR_instance <- 0;
	int total_investment_request <- 0;
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
				write "Open for investment";
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
//	reflex waitForHarvest when: length(investor)>0{	//and (length(investor where !empty(each.my_plots)) = length(investor)) 
//    	loop i over: investor where (each.my_plot != nil){
//    		if(i.my_plot.rotation_years <=0){
//    			if(!i.waiting){
//    				ask university_si{
//    					write("Investor "+i.name+" last harvesting");
//    					i.waiting <- hireHarvester(i, false);	
//    				}	
//    			}else{
//    				write "Waiting for laborer...";	
//    			}
//    	}
//    }
    
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
	int investment_request_count <- 0;
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
	action ANRAlert{
		ANR_instance <- ANR_instance + 1;
	}
	
	action payLaborer(labour cl){
		float cost <- 0.0; 
		//serviced * labor_cost
		if(cl.is_harvest_labour){
			cost <- HARVEST_LCOST;	
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
	list<plot> getInvestableGivenSpecies(int t_type){
		list<plot> investable_plots <- [];
		float buying_price;
		float planting_cost <- getPlantingCost(t_type);
		int harvest_age <- (t_type=1 ? harvesting_age_exotic: harvesting_age_native);
		//get the planting cost from the market
		ask market{
			buying_price <- getBuyingPrice(t_type);
		}
		
		list<plot> not_investable_plots <- plot where (each.is_near_water or each.is_nursery or each.is_invested);
		ask not_investable_plots{
			is_investable <- false;
		}
		
		ask plot - not_investable_plots{
			int spaces_for_planting <- myself.getAvailableSpaces(self, t_type);	//get total number of wildlings that the plot can accommodate
			
			//given spaces to be filled by plants + planting cost + management cost
			investment_cost <- (((planting_cost+myself.getManagementCost(t_type)) * spaces_for_planting)*myself.labor_price) ;	//compute total cost in man months
			int projected_rotation_years <- harvest_age - planting_age;	//harvest age is the set age when a species becomes harvestable; planting age is the age when the given species is moved from nursery to plantation
			
			int tree_to_harvest <- int((length(plot_trees)+spaces_for_planting)*harvest_policy);	//harvest policy: % count of trees allowed to be harvested
			projected_profit <- 0.0;
			int t_count <- 0;
			loop pt over: plot_trees{
				if(t_count=tree_to_harvest){break;}
				int future_age <- int(pt.age + projected_rotation_years);
				float future_dbh <- myself.determineDBHGrowth(pt.type, future_age);
				if(future_dbh > dbh_policy){	//harvest only trees of specific dbh; restriction by the government
					projected_profit <- projected_profit + (future_dbh*buying_price);
					t_count <- t_count + 1;	
				}
			}
			
			float new_tree_dbh <- myself.determineDBHGrowth(t_type, harvest_age);
			projected_profit <- projected_profit + (new_tree_dbh*buying_price*(tree_to_harvest - t_count));
			if(projected_profit > 0){
				is_investable <- (projected_profit > investment_cost)?true:false;
				if(is_investable){
					add self to: investable_plots;
				}	
			}
		}
		return investable_plots;
	}
	
	//get all investable plots per tree species
	//depending on the supported ITP type, determine investable plots
	map<int, list<plot>> determineInvestablePlots{
		map<int, list<plot>> i_plots_t;
		
		if(itp_type = 0){
			add 0::getInvestableGivenSpecies(0) to: i_plots_t;	//Native
		}else if(itp_type = 1){
			add 1::getInvestableGivenSpecies(1) to: i_plots_t;	//Exotic
		}else{
			write "INSIDE ITP = 2";
			add 1::getInvestableGivenSpecies(1) to: i_plots_t;	//Exotic
			add 0::getInvestableGivenSpecies(0) to: i_plots_t;	//Native
		}
		
		return i_plots_t;
	}

	//returns true if successful, else false
	//idea: investor decides given the following information, # of species per each plot, future value, investment value, investment payout
	bool investOnPlot(investor investing_investor, plot chosen_plot, int t_type){
//		list<trees> available_seeds <- (my_nurseries accumulate each.plot_trees) where (each.state = SAPLING and each.type = t_type);	//transplant saplings 
//		if(length(available_seeds) = 0){
//			write "NO SEEDS of type: "+t_type+" at plot: "+chosen_plot.name;
//			return false;
//		}
//		//check available seeds in nursery
//		int no_trees_for_planting <- getAvailableSpaces(chosen_plot, t_type);
//		if(length(available_seeds)< no_trees_for_planting){	//check if the available seeds is sufficient to start investment on plot, if no, deny investment
//			return false;
//		}

		//confirm investment 
		chosen_plot.is_nursery <- false;
		investing_investor.my_plot <- chosen_plot;
		investing_investor.investment <- chosen_plot.investment_cost;
		investing_investor.i_t_type <- t_type;
		//assign laborer and get available seeds from the nursery 		
		do assignLaborerToPlot(chosen_plot, t_type);	//planters stays on the plot until the end of teh 
		//set rotation years to plot
		do setRotationYears(chosen_plot, t_type);
		chosen_plot.is_itp <- true;
		
		//bool hire_status <- hireHarvester(investing_investor, true);	//harvester stays on the plot for one step only
		
		//1. get all the trees that will be harvested via selective harvesting
		list<trees> trees_to_harvest_n <- (getTreesToHarvestSH(chosen_plot)) where (each.type = NATIVE);
		float thv <- timberHarvesting(true, chosen_plot, trees_to_harvest_n);
		do harvestEarning(investing_investor, thv, NATIVE, false);
		list<trees> trees_to_harvest_e <- (getTreesToHarvestSH(chosen_plot)) where (each.type = EXOTIC);
		do timberHarvesting(true, chosen_plot, trees_to_harvest_e);
		do harvestEarning(investing_investor, thv, EXOTIC, false);
		write("!!!Investment commenced!!!");
		return true;
	}
	
	//pays the hired harvester and gives the earning to laborer
	//compute cost
	action harvestEarning(investor i, float thv, int type, bool is_final_harvesting){
		//give payment to investor
	    float c_profit <- 0.0;
	    c_profit <- thv * ((type = 1)?exotic_price_per_volume:native_price_per_volume);
	    i.tht <- i.tht + 1;
	    
	    total_ITP_earning <- total_ITP_earning + (c_profit * 0.25);
	    i.recent_profit <- i.recent_profit + (c_profit*0.75);		//actual profit of investor is 75% of total profit
	    i.total_profit <- i.total_profit + (c_profit*0.75);
	    i.done_harvesting <- is_final_harvesting;
	    i.waiting <- false;
	    
	    write "Investor earning... "+i.recent_profit;
	}

	float timberHarvesting(bool is_first_harvest, plot chosen_plot, list<trees> tth){
		//2. hire harvesters: 2x the number of trees that will be harvested
		//-- harvest process, harvest each of the trees in n parallel steps, where n = # of harvesters hired --
		list<labour> hired_harvesters <- getHarvesters(length(tth)*2);
		float harvested_bdft <- sendHarvesters(hired_harvesters, chosen_plot, tth);
		
		write "Total harvesters: "+length(hired_harvesters)+" Harvested volume: "+harvested_bdft;
		
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
		
		list<trees> tree60to70 <- pth.plot_trees where (each.dbh >= 60 and each.dbh < 70);
		tree60to70 <- (tree60to70[0::int(length(tree60to70)*0.25)]);
		list<trees> tree70to80 <- pth.plot_trees where (each.dbh >= 70 and each.dbh < 80);
		tree70to80 <- (tree70to80[0::int(length(tree70to80)*0.75)]);
		list<trees> tree80up <- pth.plot_trees where (each.dbh >= 80);

		return tree60to70 + tree70to80 + tree80up;
	}
	
	list<labour> getHarvesters(int needed_harvesters){
		list<labour> available_harvesters <- labour where (each.labor_type = each.OWN_LABOUR and each.state="vacant");	//get own laborers that are not nursery|planting labours
		int still_needed_harvesters <- needed_harvesters - length(available_harvesters);
		if(still_needed_harvesters > 0){	//hires from the community if there lacks need
			list<comm_member> avail_member <- comm_member where (each.state = "potential_partner" and each.instance_labour = nil);
			int total_to_hire <- (length(avail_member) > still_needed_harvesters)?still_needed_harvesters:length(avail_member);
			
			write "Total_to_hire: "+total_to_hire+" length of comm_member: "+length(avail_member);
			loop i from: 0 to: total_to_hire-1{
				comm_member cm <- one_of(avail_member);	//use the first member
				write "Community member: "+cm.name+" is chosen! i: "+i; 
				create labour{
					labor_type <- COMM_LABOUR; 
					com_identity <- cm;
					cm.instance_labour <- self;
				}	
				add cm.instance_labour to: available_harvesters;
				remove cm from: avail_member;
			}
		}
		
		hiring_prospect <- (length(available_harvesters) < needed_harvesters)?true:false;	//if the total labour isn't supplied, create a call for hiring prospect
		return available_harvesters;
	}
	
	//returns the hired harvesters that completed the harvesting
	float sendHarvesters(list<labour> hh, plot pth, list<trees> trees_to_harvest){
		float total_bdft <- getTotalBDFT(trees_to_harvest, pth);
		
		ask hh{
			man_months <- [HARVEST_LABOUR, 1, 0];
			is_harvest_labour <- true;
			state <- "assigned_itp_harvester";
			current_plot <- pth;
			plot_to_harvest <- pth;
			harvested_trees <- trees_to_harvest[0::1];
			remove harvested_trees from: trees_to_harvest;
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
		
		if(t_type = 0){	
			the_plot.rotation_years <- (harvesting_age_native < mean_age_tree)?harvesting_age_native:int(harvesting_age_native - mean_age_tree);
		}else{
			the_plot.rotation_years <- (harvesting_age_exotic < mean_age_tree)?harvesting_age_exotic:int(harvesting_age_exotic - mean_age_tree);
		}		
	}
	
	list<trees> getAllSaplingsInNurseries{
		list<plot> nurseries <- plot where (each.is_nursery);
		list<trees> saplings <- [];
		
		ask nurseries{
			list<trees> s <- (plot_trees where (each.state = SAPLING));
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

	/* ITP_Planter
	 * the_plot: needs trees_to_be_planted in order to convert the plot into an ITP implementing selective logging
	 * Assign laborer to ITP plot: 
	 * 	Case 1: There's unassigned laborer
	 *  Case 2: There's available nursery laborer (in waiting phase)
	 * 	Case 3: Need to hire new laborer
	 * Depending on the capacity of the laborer, get n trees from the nurseries
	 * Add more laborers if the plot isn't filled yet
	 * All this happens in one step: in one month
	 */	
	action assignLaborerToPlot(plot the_plot, int t_type){
		//check if there are vacant, non-nursery laborers
		list<trees> available_seeds <- getAllSaplingsInNurseries();	//total number of sapligns in the nurseries
		list<labour> itp_laborers <- labour where (each.state = "vacant");	//get those currently aren't nursery labor and without assigned plots
		
		int demand_for_labor <- length(available_seeds);
		if(length(itp_laborers) > 0 and demand_for_labor > 0){	//there are vacant laborers
			write "Using own laborers";
			ask itp_laborers{
				if(carrying_capacity < demand_for_labor){
					add the_plot to: self.my_plots;
					add self to: the_plot.my_laborers;
					p_t_type <- t_type;
					state <- "assigned_itp_planter";
					demand_for_labor <- demand_for_labor - carrying_capacity;
				}
				if(demand_for_labor <= 0){break;}
			}
		}
		
		if(demand_for_labor > 0){
			write "Hire new laborer";	
			list<comm_member> avail_labor <- shuffle(comm_member where (each.state = "potential_partner" and each.instance_labour = nil));
				
			int new_laborer_needed <- int(demand_for_labor/LABOUR_PCAPACITY);
			if(length(avail_labor) < new_laborer_needed){	//depending on remaining available_seeds, create n new laborer upto # of available community laborer
				new_laborer_needed <- length(avail_labor);
				hiring_prospect <- true;	//the number of available laborers is less than the need
			}else if(length(avail_labor) >= new_laborer_needed){	//there are mo laborer needed that available
				hiring_prospect <- false;
			}
			
			itp_laborers <- [];
			if(new_laborer_needed > 0){
				loop i from: 0 to: new_laborer_needed-1{
					create labour{
						man_months <- [PLANTING_LABOUR, 0, 0];
						labor_type <- COMM_LABOUR;
						com_identity <- avail_labor[i];
						avail_labor[i].instance_labour <- self;
						is_planting_labour <- true;
						state <- "assigned_itp_planter";
						p_t_type <- t_type;
					}
					add avail_labor[i].instance_labour to: itp_laborers;
				}
			}			
		}
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
		write "CANDIDATE PLOTS: "+length(candidate_plots);
		list<plot> nursery_plot;
		if(candidate_plots != nil and length(candidate_plots) > nursery_count){
			candidate_plots <- candidate_plots[0::nursery_count];
			ask candidate_plots{
				add self to: nursery_plot;
				is_nursery <- true;
				ask university_si{
					add myself to: my_nurseries;
					write "Plot added to my_nurseries";
				}	
			}	
		}
		
		ask university_si
		{
			write "Total nursery count: "+length(my_nurseries);
		}		
		ask nursery_plot[0::int(nursery_count/2)]{
			nursery_type <- NATIVE;
		}
		ask nursery_plot[int(nursery_count/2)+1::nursery_count]{
			nursery_type <- EXOTIC;
		}
		
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
					write "Current month: "+current_month+" university hiring nursery laborers";
					
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
					}
					
					write "Has hired: "+has_hired;	
				}		
			}else{
				list<labour> hired_nursery_laborers <- labour where (each.nursery_labour_type = NATIVE or each.nursery_labour_type = EXOTIC);
				loop n_laborers over: hired_nursery_laborers{
					do payLaborer(n_laborers);
				}
				
			}
			
		}else if(has_hired != -1){ //not anymore fruiting season, and has hired someone from the previous fruiting season
			write "Current month: "+current_month;
			write "Fruisting seasons: "+(fruiting_months_N + fruiting_months_E);
			has_hired <- -1;
			write "Hiring for nursery management while not yet fruiting season";
			
			list<plot> nurseries <- plot where each.is_nursery;
			list<labour> free_laborers <- (sort_by((labour where (each.state = "vacant")), each.total_earning))[0::length(nurseries)];
			
			ask free_laborers{
				is_nursery_labour <- true;
				nursery_labour_type <- -1;
				current_plot <- one_of(nurseries);
				remove current_plot from: nurseries;
			}
			
		}
	}
	
	//at every step, determine to overall cost of running a managed forest (in the light of ITP)
	reflex computeTotalCost{
		
		float nursery_other_cost <- 0.0;
		if(current_month = 0){	//start of the new year
			nursery_other_cost <- total_seedlings_replanted * 2.40;	//additional management cost per seedlings replanted is 2.40 each
			total_seedlings_replanted <- 0;
		}
		
		float police_cost <- 1000.0;
		float ANR_cost <- 250.0;
		float investment_survey_cost <- 150.0;
		 
		int working_sp <- length(special_police where (each.is_servicing));
		
		total_management_cost <- total_management_cost + nursery_other_cost + current_labor_cost + current_harvest_cost;	//currently working nursery labor and cost
		//total_management_cost <- total_management_cost + nursery_other_cost + (working_sp*POLICE_COST) + (ANR_instance*ANR_cost) + current_labor_cost + (investment_request_count * investment_survey_cost);
		total_ANR_instance <- total_ANR_instance + ANR_instance;
		total_investment_request <- total_investment_request + investment_request_count;
		
		ANR_instance <- 0; 
		current_labor_cost <- 0.0;
		investment_request_count <- 0;
		current_harvest_cost <- 0.0;
		
	}	
}



