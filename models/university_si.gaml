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
	float EST_MANAGEMENT_COST_PYEAR <- 17449.14;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, considers the laborers already
	float NURSERY_ESTABLISHMENT_COST <- 238952.35;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf, considers the laborers already
	float ANR_COST <- 5893.59; 	//per hahttps://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf; considers the laborer already
	float HARVESTING_COST <- 137294.38; //https://www.mdpi.com/1999-4907/7/8/152
	
	float LABOUR_COST <- 406.21;	//https://forestry.denr.gov.ph/pdf/ref/dmc2000-19.pdf
	float HLABOUR_COST <- 16.21;	//https://www.mdpi.com/1999-4907/7/8/152

	float exotic_price_per_bdft <- 45.06 update: exotic_price_per_bdft;
	float native_price_per_bdft <- 49.35 update: native_price_per_bdft;
	
	int average_no_trees_in1ha <- 20;
	int police_count <- 2 update: police_count;
	int laborer_count <- 10 update: laborer_count;
	float planting_space <- 1.0 update: planting_space; 
	int nursery_count <- 2 update: nursery_count;
	float harvest_policy <- 0.5 update: harvest_policy; 
	bool is_hiring <- false;
	
	int investment_rotation_years <- 1 update: investment_rotation_years;	
	
	int ANR_instance <- 0; 
	int total_investments <- 0;
	float total_management_cost <- 0.0;
	float total_ITP_earning <- 0.0;
	int total_warned_CM <- sum(special_police collect each.total_comm_members_reprimanded) update: sum(special_police collect each.total_comm_members_reprimanded);
	
	bool investment_open;
	list<labour> uni_laborers;
	
	//per hectare, mandays
	float MD_NURSERY_MAINTENANCE <- 8.64;	//maintenance of seedlings: 8.64 mandays
	float MD_NURSERY_PLANTING <- 5.33;		//sowing of seed + potting of seedlings: 5.33 mandays
	float MD_NURSERY_PREPARATION <- 1.89;	//gathering and preparation of soil: 1.89 mandays
	float MD_ITP_PLANTING <- 12.16;			//assigned planter mandays: 12.16 mandays
	
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
			add self to: uni_laborers;
		}
		create university_si;
		create special_police number: police_count{
			location <- point(0,0,0);
		}
	}
}

species university_si{
	list<plot> my_invested_plots;		//list of plots invested by the university
	
	float labor_price <- 3.0; //per months
	
	float current_harvest_cost <- 0.0;
	float current_ANR_cost <- 0.0;
	
	list<plot> my_nurseries;	//list of nurseries managed by university
	list<trees> my_saplings <- [] update: (my_saplings where !dead(each)); //contains all saplings in the nusery, remove all the dead saplings
	list<plot> harvestable_plot <- plot where (each.stand_basal_area > 12 and !each.is_nursery and !each.is_invested) update: plot where (each.stand_basal_area > 12  and !each.is_nursery and !each.is_invested);
	
	reflex alertInvestment{
		investment_open <- length(my_nurseries) >= nursery_count/2;
	}
	
	//candidate nursery are those plots with road 
	//nursery plots are chosen based on the distance from river
	reflex updateNurseryPlots when: length(my_nurseries)<nursery_count{
		list<plot> candidate_plots <- (plot where (each.is_candidate_nursery)) sort_by each.distance_to_river;
		int needed_nurseries <- nursery_count-length(my_nurseries);
		int actual_count <- (length(candidate_plots) <= needed_nurseries)?length(candidate_plots):needed_nurseries;
		
		if(actual_count > 0){
			list<plot> nurseries <- candidate_plots[0::actual_count];
			
			loop n over: nurseries{
				n.is_nursery <- true;
				n.is_candidate_nursery <- false;
				add n to: my_nurseries;
				add all: (n.plot_trees where (each.state = SAPLING)) to: my_saplings;
				write "I AM nursery: "+n.name;
				total_management_cost <- total_management_cost + NURSERY_ESTABLISHMENT_COST;
			}			
		}
	}
	
	//once hired, nursery laborer either attends to the plot (manage_nursery) or goes out to gather seedlings (assigned_nursery)
	reflex hireNurseryLaborer when: ((my_nurseries count ((length(each.my_laborers)) = 0)) > 0){
		list<plot> nursery_wo_laborer <- my_nurseries where ((length(each.my_laborers)) = 0);
		list<labour> free_laborer <- (sort_by((labour where (each.labor_type = each.OWN_LABOUR and each.state = "vacant" and each.my_assigned_plot = nil)), each.total_earning));
			
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
		
	/*
	 * Determine amount of investment needed per hectare
		Given the current number of trees in the plot, 
        determine the cost needed to plant new trees (how many trees are to be planted)
	 */
	 float computeInvestmentCost(plot investable_plot, int sapling_places){
	 	float investment_cost <- 0.0;
	 	
	 	int needed_plaborer <- int(sapling_places/LABOUR_TCAPACITY);
	 	float cost_to_support_investment <- 0.0; 
	 	
	 	ask market{	//cost of saplings to plant after harvesting
	 		cost_to_support_investment <- sapling_places * native_sapling_price;	
	 	}
	 	
	 	cost_to_support_investment <- cost_to_support_investment + (needed_plaborer*LABOUR_COST);	//cost of planters that will be hired
	 	cost_to_support_investment <- cost_to_support_investment + (LABOUR_COST * 2);	//cost of harvesters that will be hired 
	 	
	 	//add management cost 
	 	cost_to_support_investment <- cost_to_support_investment + (EST_MANAGEMENT_COST_PYEAR*investment_rotation_years);
	 	
	 	return cost_to_support_investment;
	 }
			
	float projectProfit(investor inv, plot investable_plot, int sapling_places){
		float projected_profit <- 0.0;
		
		//current harvestable
		list<trees> current_harvestables <- getTreesToHarvestSH(investable_plot);
		ask market {
			float total_bdft_n <- getTotalBDFT(current_harvestables where (each.type = NATIVE));
			float total_bdft_e <- getTotalBDFT(current_harvestables where (each.type = EXOTIC));
			projected_profit <- (getProfit(NATIVE, total_bdft_n) + getProfit(EXOTIC, total_bdft_e))*0.75;
		}	
		
		//future harvestable
		trees sample_sapling <- first(buySaplings(1));
		float pfuture_dbh <- (sample_sapling.age + investment_rotation_years)*growth_rate_native;
		float pfuture_bdft <- calculateVolume(pfuture_dbh, NATIVE)/12;
		
		ask market{
			projected_profit <- projected_profit + (getProfit(NATIVE, pfuture_bdft*sapling_places)*0.75);	
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
		write "-- current payable: "+current_payable+" for "+effort+" effort";
		cl.total_earning <- cl.total_earning + current_payable;
	}	
	
	action payPatrol(special_police sp, float effort){
		sp.total_wage <- sp.total_wage + (effort * LABOUR_COST);
	}
	
	plot getInvestablePlot{
		list<plot> investable_plots <- reverse(sort_by(plot where (!each.is_nursery and !each.is_invested), each.stand_basal_area)); 

		return first(investable_plots);
	}
	
	//pays the hired harvester and gives the earning to laborer
	//compute cost
	action harvestEarning(investor i, float thv, int type){
		//give payment to investor
	    float c_profit;
	    ask market{
	    	c_profit <- getProfit(type, thv);
	    }
	    
	    if(i != nil){
	    	i.tht <- i.tht + 1;
	    	i.recent_profit <- i.recent_profit + (c_profit*0.75);		//actual profit of investor is 75% of total profit
	    }
	    
	    total_ITP_earning <- total_ITP_earning + (c_profit * ((i!=nil)?0.25:1.0));
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
				
		is_hiring <- (still_needed_laborers > 0)?true:false;	//if the total labour isn't supplied, create a call for hiring prospect

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
	 */ 
	bool replantPlot(plot the_plot){
		list<geometry> available_spaces <- getSquareSpaces(the_plot.shape, the_plot.plot_trees, true, 3);
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
		
	//for ANR when: there's at least 1 vacant laborers, sba < 5, and plot_trees < 200
	//1 available vacant laborer = 1 plot 
	reflex monitorSBAforANR when: ((labour count (each.state = "vacant"))>0){
		list<plot> plot_for_ANR <- sort_by((plot where (!each.is_ANR and !each.is_nursery and each.stand_basal_area < 5.0 and (length(each.plot_trees) < 200))), each.stand_basal_area);	
		
		loop pfa over: plot_for_ANR{
			if(!replantPlot(pfa)){
				break;	//once it breaks it means that there are no more laborers avaialble to conduct ANR
			}
			current_ANR_cost <- current_ANR_cost + ANR_COST;
			ANR_instance <- ANR_instance + 1;
			pfa.is_ANR <- true;
		}
	}
	
	reflex startITPHarvesting when: length(my_nurseries) > (nursery_count/2){
		loop h_plot over: harvestable_plot{
			if(!harvestITP(nil, h_plot)){
				break;
			}
		}
	}
	
	//returns true when it can support more harvesting, else false
	bool harvestITP(investor inv, plot plot_to_harvest){	//will harvest only when I already have at least half of wanted nursery
		list<trees> trees_to_harvest <- getTreesToHarvestSH(plot_to_harvest);
    	
    	if(length(trees_to_harvest) > 0){
    		list<trees> native_trees <- (trees_to_harvest where (each.type = NATIVE));
	    	list<trees> exotic_trees <- trees_to_harvest - native_trees;
	    		
	    	if(native_trees != []){
	    		do harvestEarning(inv, timberHarvesting(plot_to_harvest, native_trees), NATIVE);	
	    	}
	    	if(exotic_trees != []){
	    		do harvestEarning(inv, timberHarvesting(plot_to_harvest, exotic_trees), EXOTIC);	
	    	}
			current_harvest_cost <- current_harvest_cost + HARVESTING_COST;
			write "HARVESTED";
    	}else{
    		write "NOTHING to harvest";
    	}
    	
    	
		return replantPlot(plot_to_harvest);
	}
	
	//at every step, determine to overall cost of running a managed forest (in the light of ITP)
	reflex computeTotalCost {
		total_management_cost <- total_management_cost + current_ANR_cost + current_harvest_cost;	//currently working nursery labor and cost
		
		current_harvest_cost <- 0.0;
		current_ANR_cost <- 0.0;
	}	
}


