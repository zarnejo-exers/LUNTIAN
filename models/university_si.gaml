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
	int LABOUR_TCAPACITY <- 15;	//number of trees that the laborer can plant/manage
	
	//fixed rate
	float INIT_COST <- 45519.51; //INFRASTRUCTURE COST
	float YEARLY_PROJ_MGMT_COST <- 2731.17;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, based on year 1 only
	float INIT_ESTABLISHMENT_INVESTOR <- 7227.06;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, considers the laborers already
	float MAINTENANCE_COST_PER_HA <- 9457.97; //https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, considers the laborers already
	float MAINTENANCE_MATCOST_PER_HA <- 1210.62; 	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, considers the laborers already
	float SAPLINGS_UNIT_COST <-  1.194;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, GENERIC
	float NURSERY_ESTABLISHMENT_COST <- 238952.35;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, considers the laborers already
	float ANR_COST <- 5893.59; 	//per ha https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf; considers the laborer already
	float YEARLY_HARVESTING_COST <- 137294.38; //https://www.mdpi.com/1999-4907/7/8/152
	
	float LABOUR_COST <- 406.21;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf
	float HLABOUR_COST <- 16.21;	//https://www.mdpi.com/1999-4907/7/8/152
	
	int average_no_trees_in1ha <- 20;
	int police_count <- 3 update: police_count;
	int police_neighborhood <- 16 update: police_neighborhood;
	int laborer_count <- 20 update: laborer_count; 
	int nursery_count <- 2 update: nursery_count; 
	int hiring_calls <- 0;
	
	int investment_rotation_years <- 15 update: investment_rotation_years;	
	
	int ANR_instance <- 0; 
	int total_investments <- 0;
	int total_warned_CM <- sum(special_police collect each.total_comm_members_reprimanded) update: sum(special_police collect each.total_comm_members_reprimanded);
	
	bool investment_open;
	list<labour> uni_laborers;
	
	float monthly_management_cost <- 0.0;
	float monthly_ITP_earning <- 0.0;
	float monthly_labor_cost <- 0.0;
	float management_running_cost <- 0.0; 
	float ITP_running_earning <- 0.0;
	float net_running_earning <- 0.0;
	 
	//per hectare, mandays
	float MD_NURSERY_MAINTENANCE <- 8.64;	//maintenance of seedlings: 8.64 mandays
	float MD_NURSERY_PLANTING <- 5.33;		//sowing of seed + potting of seedlings: 5.33 mandays
	float MD_NURSERY_PREPARATION <- 1.89;	//gathering and preparation of soil: 1.89 mandays
	float MD_ITP_PLANTING <- 12.16;			//assigned planter mandays: 12.16 mandays
	float MD_INVESTED_MAINTENANCE <- 20.647; 	//per ha required mandays 
	
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
	 
	float partners_earning <- 0.0;
	float independent_earning <- 0.0;
	float investor_total_profit <- 0.0;
	float total_investment_cost <- 0.0;
	float total_partners_earning <- 0.0;
	float total_independent_earning <- 0.0;
	
	float investor_percent_share <- 0.75 update: investor_percent_share;
	float exotic_price_per_bdft <- 135.18 update: exotic_price_per_bdft;	//https://forestry.denr.gov.ph/pdf/ds/prices-lumber.pdf 45.06
	float native_price_per_bdft <- 49.35 update: native_price_per_bdft;	//https://forestry.denr.gov.ph/pdf/ds/prices-lumber.pdf 49.35 
	
	init{
		create market;
		create labour number: laborer_count{
			labor_type <- OWN_LABOUR; 
			add self to: uni_laborers;
		}
		create university_si;
		create special_police number: police_count{
			location <- point(0,0,0);
		}
		
		management_running_cost <- INIT_COST;	//infrastructure cost at the beginning
	}
	
	reflex updateCashflow{
    	partners_earning <- sum((comm_member where (each.state = "labour_partner")) collect each.current_earning);
    	independent_earning <- sum((comm_member where (each.state = "independent_harvesting")) collect each.current_earning);
    	investor_total_profit <- sum(investor collect each.total_profit); 
    	total_investment_cost <- sum( investor collect each.total_investment);
    	total_partners_earning <- total_partners_earning + partners_earning;
    	total_independent_earning <- total_independent_earning + independent_earning;
	}
	
//	reflex save_results_explo{   	
//    	save [cycle, investor_percent_share, exotic_price_per_bdft, native_price_per_bdft, 
//	    	length(trees where (each.type = NATIVE and each.state = SEEDLING)),length(trees where (each.type = NATIVE and each.state = SAPLING)),length(trees where (each.type = NATIVE and each.state = POLE)),length(trees where (each.type = NATIVE and each.state = ADULT)), 
//			length(trees where (each.type = EXOTIC and each.state = SEEDLING)),length(trees where (each.type = EXOTIC and each.state = SAPLING)),length(trees where (each.type = EXOTIC and each.state = POLE)),length(trees where (each.type = EXOTIC and each.state = ADULT)),
//			management_running_cost,ITP_running_earning,net_running_earning,
//			partners_earning, independent_earning,
//			investor_total_profit, total_investment_cost, total_investments] rewrite: false to: "../results/experiment.csv" format:"csv" header: true;		
//	}
}

species university_si{
	list<plot> invested_plots <- [];
	
	float labor_price <- 3.0; //per months
	
	bool has_harvested <- false;
	float monthly_ANR_cost <- 0.0;
	
	list<plot> my_nurseries;	//list of nurseries managed by university
	list<trees> my_saplings <- [] update: (my_saplings where !dead(each)); //contains all saplings in the nusery, remove all the dead saplings
	list<plot> harvestable_plot <- plot where (each.stand_basal_area > 10 and !each.is_nursery and !each.is_invested) update: plot where (each.stand_basal_area > 10  and !each.is_nursery and !each.is_invested);
	
	float count_available_saplings_harvesting <- 0.0; 
	
	reflex alertInvestment{
		investment_open <- length(my_nurseries) >= nursery_count/2;
	}
	
	//candidate nursery are those plots with road 
	//nursery plots are chosen based on the distance from river
	reflex updateNurseryPlots when: length(my_nurseries)<nursery_count{
		list<plot> candidate_plots <- reverse((plot where (each.is_candidate_nursery)) sort_by (each.distance_to_river)) sort_by each.exotic_trees;
		int needed_nurseries <- nursery_count-length(my_nurseries);
		int actual_count <- (length(candidate_plots) <= needed_nurseries)?length(candidate_plots):needed_nurseries;
		
		if(actual_count > 0){
			list<plot> nurseries <- candidate_plots[0::actual_count];
			
			loop n over: nurseries{
				n.is_nursery <- true;
				n.is_candidate_nursery <- false;
				add n to: my_nurseries;
				add all: (n.plot_trees where (each.state = SAPLING)) to: my_saplings;
				monthly_management_cost <- monthly_management_cost + NURSERY_ESTABLISHMENT_COST;
				//harvest all the exotic
				//I'm thinking if I should remove all exotic in the plot
				write "I AM a nursery: "+n.name;  
				do harvestITP(nil, n, EXOTIC);
			}			
		}
	}
	
	//once hired, nursery laborer either attends to the plot (manage_nursery) or goes out to gather seedlings (assigned_nursery)
	reflex hireNurseryLaborer when: ((my_nurseries count ((length(each.my_laborers)) = 0)) > 0){
		list<plot> nursery_wo_laborer <- my_nurseries where ((length(each.my_laborers)) = 0);
		list<labour> free_laborer <- (sort_by((labour where (each.state = "vacant" and each.my_assigned_plot = nil)), each.total_earning));
			
		if(length(free_laborer) > 0){
			loop i from: 0 to: length(free_laborer)-1{
				if(i < length(nursery_wo_laborer)){
					plot n_plot <- nursery_wo_laborer[i];
					
					free_laborer[i].is_nursery_labour <- true;
					free_laborer[i].current_plot <- n_plot;
					free_laborer[i].my_assigned_plot <- n_plot;	//assigned plot
					free_laborer[i].location <- n_plot.location;
					add free_laborer[i] to: n_plot.my_laborers;	
				}else{	//break if there are no more nursery_wo_laborer
					break;
				}
			}
		}
	}		
		
	reflex startITPHarvesting when: length(my_nurseries) > (nursery_count/2){
		loop h_plot over: reverse(harvestable_plot sort_by each.stand_basal_area){
			int hs_count <- harvestITP(nil, h_plot, BOTH);    
			if(hs_count = -1){
				break;
			}
			//write "University harvesting...";
			count_available_saplings_harvesting <- count_available_saplings_harvesting + hs_count;
		}
	}
		
	//hire 4 different laborers every six months
	//six months is ensured in the laborer state 
	//for maintaining invested plots
	reflex hireManagersForInvestedPlots when: ((invested_plots count ((length(each.my_laborers)) = 0)) > 0){
		list<plot> for_management_plots <- invested_plots where (length(each.my_laborers) = 0);
		list<labour> free_laborers <- sort_by(labour where (each.state = "vacant" and each.my_assigned_plot = nil), each.total_earning);
		int laborer_per_plot <- 2;
		
		ask for_management_plots{
			if(length(free_laborers) < 1){	//assign while there are neighbors 
				hiring_calls <- hiring_calls + 1;
				break;
			}
			
			if(length(free_laborers) > laborer_per_plot){
				add all: free_laborers[0::laborer_per_plot] to: my_laborers;
			}else{	//assign all remaining
				add all: free_laborers to: my_laborers;
			}
			remove all: my_laborers from: free_laborers;
			
			ask my_laborers{
				my_assigned_plot <- myself;
				is_managing_labour <- true;
			}
		}
	}
		
	//for ANR when: there's at least 1 vacant laborers, sba < 5, and plot_trees < 200
	//1 available vacant laborer = 1 plot 
	reflex monitorSBAforANR when: ((labour count (each.state = "vacant"))>0){
		list<plot> plot_for_ANR <- sort_by((plot where (!each.is_ANR and !each.is_nursery and each.stand_basal_area < 5.0 and (length(each.plot_trees) < 200))), each.stand_basal_area);	 
		loop pfa over: plot_for_ANR{
			int count_available_saplings <- replantPlot(pfa); 
			if(count_available_saplings = -1){
				break;	//once it breaks it means that there are no more laborers avaialble to conduct ANR
			}
			
			monthly_ANR_cost <- monthly_ANR_cost + (ANR_COST - (SAPLINGS_UNIT_COST * count_available_saplings));
			ANR_instance <- ANR_instance + 1;
			pfa.is_ANR <- true;
		}
	}	
	
	/*float current_management_cost <- 0.0;
	float current_ITP_earning <- 0.0;
	float annual_net_earning;
	float total_management_cost <- 0.0; 
	float total_ITP_earning <- 0.0;
	 */
	
	//at every step, determine to overall cost of running a managed forest (in the light of ITP)
	reflex computeTotalCost {
		int c_invested_plots <- length(plot where (each.is_invested));
		
		//yearly payables: harvesting and project management 
		if(current_month = 0){
			if(has_harvested){
				float yearly_harvesting_cost <- (YEARLY_HARVESTING_COST - (SAPLINGS_UNIT_COST * count_available_saplings_harvesting));
				monthly_management_cost <- monthly_management_cost+yearly_harvesting_cost;
			}
			monthly_management_cost <- monthly_management_cost + YEARLY_PROJ_MGMT_COST;
		}
		
		//monthly payables: ANR, labour, maintenance
		float monthly_maintenance_cost <- (MAINTENANCE_MATCOST_PER_HA * c_invested_plots);
		monthly_management_cost <- monthly_management_cost + monthly_ANR_cost + monthly_labor_cost+monthly_maintenance_cost;
		
		//update running values
		management_running_cost <- management_running_cost + monthly_management_cost;
		ITP_running_earning <- ITP_running_earning + monthly_ITP_earning;
		net_running_earning <- ITP_running_earning - management_running_cost;
		
		//reset montly values
		monthly_management_cost <- 0.0;
		monthly_ITP_earning <- 0.0;
		has_harvested <- false;
		monthly_ANR_cost <- 0.0;
		monthly_labor_cost <- 0.0;
		count_available_saplings_harvesting <- 0.0;
	}
			
	/*
	 * Determine amount of investment needed per hectare
		Given the current number of trees in the plot, 
        determine the cost needed to plant new trees (how many trees are to be planted)
	 */
	 float computeInvestmentCost(plot investable_plot){
	 	
	 	//establishment + management cost => considers laborers already  
	 	float cost_to_support_investment <- (MAINTENANCE_COST_PER_HA*(investment_rotation_years*investor_percent_share))+INIT_ESTABLISHMENT_INVESTOR;
	 	
	 	return cost_to_support_investment;
	 }
			
	float projectProfit(investor inv, plot investable_plot){
		float projected_profit <- 0.0;
		
		//current harvestable
		list<trees> current_harvestables <- getTreesToHarvestSH(investable_plot);
		ask market {
			float total_bdft_n <- getTotalBDFT(current_harvestables where (each.type = NATIVE));
			float total_bdft_e <- getTotalBDFT(current_harvestables where (each.type = EXOTIC));
			projected_profit <- (getProfit(NATIVE, total_bdft_n) + getProfit(EXOTIC, total_bdft_e))*0.70;
		}

		//future harvestable
		list<trees> future_harvestables <- investable_plot.plot_trees - current_harvestables;
		
		ask future_harvestables{
			temp_dbh <- dbh;
			dbh <- (age + investment_rotation_years)*((type=NATIVE)?growth_rate_native:growth_rate_exotic);
		}
		
		ask market {
			float total_bdft_n <- getTotalBDFT(future_harvestables where (each.type = NATIVE));
			float total_bdft_e <- getTotalBDFT(future_harvestables where (each.type = EXOTIC));
			projected_profit <- projected_profit + (getProfit(NATIVE, total_bdft_n) + getProfit(EXOTIC, total_bdft_e))*0.70;
		}
		
		ask future_harvestables{
			dbh <- temp_dbh;
		}
		
		return projected_profit; 
	}	
	
	//individual tree volume for all species
	//https://www.doc-developpement-durable.org/file/Culture/Arbres-Bois-de-Rapport-Reforestation/FICHES_ARBRES/Swietenia%20microphylla/Conversion%20Table%20for%20Sawn%20Mahogany.pdf
	//cubic feet
	float calculateVolume(float temp_dbh, int t_type){
		float th <- calculateHeight(temp_dbh, t_type) * 3.281;	// with *3.281 -> meters feet
		float tdbh <- temp_dbh / 30.48;	//with /30.48 -> cm - feet
		return  (th/4)*(#pi * ((tdbh/2)^2));	
	}
	
	//STATUS: CHECKED
	float calculateHeight(float temp_dbh, int t_type){
		float height; 
		switch t_type{
			match EXOTIC {
				height <- (1.3 + (12.39916 * (1 - exp(-0.105*temp_dbh)))^1.79);	//https://www.cifor-icraf.org/publications/pdf_files/Books/BKrisnawati1110.pdf 
			}
			match NATIVE {
				height <- 1.3+(temp_dbh/(1.5629+0.3461*temp_dbh))^3;	//https://d-nb.info/1002231884/34		
			}
		}
		
		return height;	//in meters	
	}	 	
	 
	//everytime a community laborer completes a task, the university pays them
	/*	float total_earning <- 0.0;		//total earning for the entire simulation
	 *  float current_earning <- 0.0; //earning of the community at the current commitment
	 * nursery and planter => effort in terms of mandays
	 * harvester => effort in terms of bdft
	 */ 
	action payLaborer(labour cl, float effort){
		float current_payable <- effort*((cl.is_harvest_labour)?HLABOUR_COST:LABOUR_COST);
		if(cl.com_identity != nil){
			cl.com_identity.current_earning <- cl.com_identity.current_earning + current_payable;
		}
		cl.total_earning <- cl.total_earning + current_payable;
		monthly_labor_cost <- monthly_labor_cost + current_payable;
	}	
	
	action payPatrol(special_police sp, float effort){
		sp.total_wage <- sp.total_wage + (effort * LABOUR_COST);
	}
	
	//pays the hired harvester and gives the earning to laborer
	//compute cost
	action harvestEarning(investor i, float thv, int type){
		//give payment to investor
	    float c_profit <- 0.0;
	    ask market{
	    	c_profit <- getProfit(type, thv);
	    }
	    
	    if(i != nil){
	    	i.recent_profit <- i.recent_profit + (c_profit*0.60);		//actual profit of investor is 75% of total profit
	    }
	    c_profit <- (c_profit * ((i!=nil)?0.40:1.0));
	    monthly_ITP_earning <- monthly_ITP_earning + c_profit;
	}

	float timberHarvesting(plot chosen_plot, list<trees> tth){
//		//2. hire harvesters: 2x the number of trees that will be harvested
//		//-- harvest process, harvest each of the trees in n parallel steps, where n = # of harvesters hired --
		//needed laborers is based on trees_length/capacity
		list<labour> hired_harvesters <- getLaborers(int(length(tth)/LABOUR_TCAPACITY)+1);	//if there's no laborer avail, get all assigned_planter
		 
		float harvested_bdft <- sendHarvesters(hired_harvesters, chosen_plot, tth);	
		
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
		list<labour> available_laborers <- (labour where ((each.labor_type = each.OWN_LABOUR and each.my_assigned_plot=nil))) sort_by each.total_earning;	//get own laborers that are not nursery|planting labours
		int still_needed_laborers <- needed_laborers - length(available_laborers);
	
		list<labour> hired_laborers <- available_laborers sort_by each.total_earning;
		
		if(still_needed_laborers < 0){
			//get only the first LABOUR_TCAPACITY laborers
			hired_laborers <- hired_laborers[0::needed_laborers];
		}else{
			//hire the community members that are labor partners already
			list<labour> comm_laborers <- ((comm_member where (each.state = "labour_partner" and each.instance_labour.my_assigned_plot = nil)) sort_by (each.current_earning)) collect each.instance_labour;
			add all: (((comm_member where (each.state = "potential_partner" and each.instance_labour.my_assigned_plot = nil)) sort_by (each.total_earning)) collect each.instance_labour) to: comm_laborers;
			
			if(still_needed_laborers > length(comm_laborers)){
				still_needed_laborers <- still_needed_laborers - length(comm_laborers);
				add all: comm_laborers to: hired_laborers;	
			}else{
				add all: comm_laborers[0::still_needed_laborers] to: hired_laborers; 
				still_needed_laborers <- 0;
			}
		}
				
		//if the total labour isn't supplied, create a call for hiring prospect				
		if(still_needed_laborers > 0){
			hiring_calls <- hiring_calls + 1;
		}
		
		return hired_laborers;
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
	list<geometry> getSquareSpaces(geometry main_space, list<trees> to_remove_space, bool is_itp){
		geometry t_shape <- nil; 
		int tree_space <- 5;
			
		ask to_remove_space{
			t_shape <- t_shape + square(tree_space#m);
		}
			
		geometry remaining_space <- main_space - t_shape;	//remove all occupied space;
		return (to_squares(remaining_space, tree_space#m) where (each.area >= (tree_space^2)#m));	//n_space, assumed space needed by the trees that will be planted		
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
			ask university_si{
				myself.th <- calculateHeight(myself.dbh, myself.type);	
			}
			basal_area <- #pi * (dbh^2)/40000;
			my_plot <- nil;
			location <- point(0,0,0);
		}
		return bought_saplings;
	}
	
	/* TWO types: 
	 *  (i) encrichment planting as ANR approach
	 *  (ii)planting for ITP
	 * 
	 * This function also "hires" planters
	 * 
	 * 
	 * returns -1 if didn't get to plant
	 * else, return the number of planted saplings
	 */
	int replantPlot(plot the_plot){
		list<geometry> available_spaces <- getSquareSpaces(the_plot.shape, the_plot.plot_trees, true);
		int plot_capacity <- length(available_spaces); 	

		int needed_planters <- int(ceil(plot_capacity/LABOUR_TCAPACITY));
		list<labour> available_planters <- getLaborers(needed_planters);
		
		if(length(available_planters)>0){
			int available_saplings <- length(my_saplings);
			
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
			return length(saplings_to_be_planted);			
		}
		return -1;
	}
	
	action sendPlanters(list<labour> planters, plot ptp, list<trees> trees_to_be_planted, list<geometry> available_spaces){
		int count_of_trees <- length(trees_to_be_planted);
		//assign plant to planter		
		loop p over: planters{
			p.is_planting_labour <- true;
			p.my_assigned_plot <- ptp;
			p.current_plot <- ptp;
			p.location <- p.current_plot.location;
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
				location <- current_plot.location;
			}
			remove labour_instance from: hh;
			remove all: to_harvest from: trees_to_harvest;
		}
		
		return total_bdft;
	}
	
	//returns true when it can support more harvesting, else false
	int harvestITP(investor inv, plot plot_to_harvest, int type_to_harvest){	//will harvest only when I already have at least half of wanted nursery
		list<trees> trees_to_harvest <- [];
		
		trees_to_harvest <- (type_to_harvest = BOTH)?getTreesToHarvestSH(plot_to_harvest):plot_to_harvest.plot_trees;
    	
    	if(length(trees_to_harvest) > 0){
	    	list<trees> exotic_trees <- (trees_to_harvest where (each.type = EXOTIC));
	    	if(exotic_trees != []){
	    		do harvestEarning(inv, timberHarvesting(plot_to_harvest, exotic_trees), EXOTIC);	
	    	}
	    	if(type_to_harvest = BOTH){
	    		list<trees> native_trees <- (trees_to_harvest where (each.type = NATIVE));
		    	if(native_trees != []){
		    		do harvestEarning(inv, timberHarvesting(plot_to_harvest, native_trees), NATIVE);	
		    	}	
	    	}
			has_harvested <- true;
    	}
    	
    	if(type_to_harvest = BOTH){
    		return replantPlot(plot_to_harvest);	
    	}else{
    		return 1;
    	}
    	
	}	
}


