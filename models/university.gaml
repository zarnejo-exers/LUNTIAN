/**
* Name: investor
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/

model university
import "llg.gaml"
import "market.gaml"
import "investor.gaml"
import "labour.gaml"
import "comm_member.gaml"

/* Insert your model definition here */
global{
	int NURSERY_LABOUR <- 12; //labor required per nursery, constant
	int LABOUR_PCAPACITY <- 5;	//number of trees that the laborer can plant/manage
	
	int plot_size <- 1 update: plot_size;
	int laborer_count <- 5 update: laborer_count;
	int nlaborer_count<- 1 update: nlaborer_count;
	float planting_space <- 1.0 update: planting_space; 
	int planting_age <- 1 update: planting_age;
	int harvesting_age_exotic <- 60 update: harvesting_age_exotic;	//temp
	int harvesting_age_native <- 60 update: harvesting_age_native;	//actual 40
	int nursery_count <- 2 update: nursery_count;
	float harvest_policy <- 0.5 update: harvest_policy;
	float dbh_policy <- 50.0 update: dbh_policy; 
	bool plant_native <- true update: plant_native;
	bool plant_exotic <- false update: plant_exotic;
	int itp_type; //0 ->plant native, 1->plant exotic, 2->plant mix
	
	bool assignedNurseries <- false;
	bool start_harvest <- false;
	init{
		create market;
		create labour number: laborer_count;
		create university;
		
		itp_type <- (plant_native and plant_exotic)?2:(plant_native?0:1);
	}
	
	//automatically execute when there are no laborers assigned to nurseries
	reflex assignLaborersToNurseries when: (!assignedNurseries and (nursery_count > 0)){
		ask university{
			do assignNurseries;
			if(length(my_nurseries) >= nursery_count){	//start ITP if there's enough nurseries
				write "Starting ITP: "+length(my_nurseries)+" with: "+nursery_count;
				do assignLaborerToNursery(my_nurseries);
				do determineInvestablePlots(itp_type);
				do updateInvestors;	 
				assignedNurseries <- true;
			}else{
				write "Let environment grow";
			}	
		}
	}
	
	//stop simulation at year 50
//	reflex stopAtYear100 when: cycle=1200{
//		do pause;
//	}
	
	//start checking once all investor already have investments
	//stop simulation when the rotation years of all investor is finished
	reflex stopSimulation when: length(investor)>0 and (length(investor where !empty(each.my_plots)) = length(investor)) {
    	int is_finished <- length(investor);
    	bool to_pause <- true;
    	loop i over: investor{
    		loop mp over: i.my_plots{
    			if(mp.rotation_years > 0){
    				to_pause <- false;
    				break;
    			}
    		}
    	}
    	if(to_pause){	//harvest the plots
    		list<labour> available_labors <- labour where each.is_itp_labour;	//get all itp labours
    		loop i over: investor{
    			write "Investor: "+i.name;
    			loop mp over: i.my_plots{
    				write "Trees in ITP plot: "+(mp.plot_trees accumulate each.dbh);
    				labour chosen_labour <- one_of(available_labors closest_to mp);
    				list<trees> selected_trees <- chosen_labour.selectiveHarvestITP(mp, i);
    				ask university{
    					write "Selected DBH: "+(selected_trees accumulate each.dbh);
    					put selected_trees at: i in: harvested_trees_per_investor;
    					write "In htpi: "+harvested_trees_per_investor[i];
    					i.harvested_trees <- length(harvested_trees_per_investor[i]);
    				}
    			}
    		}
    		do pause ;	
    	}
    } 
}

species university{
	list<plot> my_invested_plots;		//list of plots invested by the university
	list<plot> my_nurseries <- (plot where each.is_nursery) update: (plot where each.is_nursery);	//list of nurseries managed by university
	list<plot> investable_plots;
	list<investor> current_investors <- [];
	
	map<investor, list<trees>> harvested_trees_per_investor <- investor as_map (each::[]);
	
	list<trees> available_seeds<- [];
	
	float mcost_of_native <- 5.0; //management cost in man hours of labor
	float mcost_of_exotic <- 4.0; //management cost in man hours of labor
	float pcost_of_native <- 1.0;	//planting cost in man hours of labor
	float pcost_of_exotic <- 1.0;	//planting cost in man hours of labor
	
	float labor_price <- 3.0; //per hour
	
	/*
	 * Determine amount of investment needed per hectare
		Given the current number of trees in the plot, 
        determine the cost needed to plant new trees (how many trees are to be planted)
	 */
	 
	 

	action updateInvestors{
		current_investors <- investor where !empty(each.my_plots);
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
	action determineInvestablePlots(int t_type){
		float planting_cost <- getPlantingCost(t_type);
		float buying_price;
		int harvest_age <- (t_type=1 ? harvesting_age_exotic: harvesting_age_native);
		//get the planting cost from the market
		ask market{
			buying_price <- getBuyingPrice(t_type);
		}
		
		list<plot> not_investable_plots <- plot where (each.is_near_water or each.is_nursery or !empty(each.my_investors));
		ask not_investable_plots{
			is_investable <- false;
		}
		
		ask plot - not_investable_plots{
			int spaces_for_planting <- getAvailableSpaces(t_type);	//get total number of wildlings that the plot can accommodate
			
			//given spaces to be filled by plants + planting cost + management cost
			investment_cost <- (((planting_cost+myself.getManagementCost(t_type)) * spaces_for_planting)*myself.labor_price) ;	//compute total cost in man hours
			int projected_rotation_years <- harvest_age - planting_age;	//harvest age is the set age when a species becomes harvestable; planting age is the age when the given species is moved from nursery to plantation
			
			int tree_to_harvest <- int((length(plot_trees)+spaces_for_planting)*harvest_policy);	//harvest policy: % count of trees allowed to be harvested
			projected_profit <- 0.0;
			int t_count <- 0;
			loop pt over: plot_trees{
				if(t_count=tree_to_harvest){break;}
				int future_age <- int(pt.age + projected_rotation_years);
				float future_dbh <- myself.managementDBHEstimate(pt.type, future_age);
				if(future_dbh > dbh_policy){	//harvest only trees of specific dbh; restriction by the government
					projected_profit <- projected_profit + (future_dbh*buying_price);
					t_count <- t_count + 1;	
				}
			}
			
			float new_tree_dbh <- myself.managementDBHEstimate(t_type, harvest_age);
			projected_profit <- projected_profit + (new_tree_dbh*buying_price*(tree_to_harvest - t_count));
			is_investable <- (projected_profit > investment_cost)?true:false;
			if(is_investable){
				add self to: myself.investable_plots;
			}
		}
	}

	//returns true if successful, else false
	bool investOnPlot(investor investing_investor, plot chosen_plot){
		ask my_nurseries{
			do updateTrees;
		}
		available_seeds <- (my_nurseries accumulate each.plot_trees) where (each.age < 4);	//can transplant seed from nursery to ITP until before age 4
		if(length(available_seeds) = 0){
			write "No available seeds";
			return false;
		}
		//check available seeds in nursery
		int no_trees_for_planting <- chosen_plot.getAvailableSpaces((plant_native)?0:1);
		
		//write "Available seeds: "+length(available_seeds)+" Needed seeds: "+no_trees_for_planting;
		if(length(available_seeds)< no_trees_for_planting){	//check if the available seeds is sufficient to start investment on plot, if no, deny investment
			return false;
		}else{
			available_seeds <- (length(available_seeds)>no_trees_for_planting ? available_seeds[0::no_trees_for_planting]:available_seeds);
		}

		//confirm investment 
		chosen_plot.is_nursery <- false;
		add chosen_plot to: investing_investor.my_plots;
		investing_investor.investment <- chosen_plot.investment_cost;
		//assign laborer and get available seeds from the nursery 		
		list<labour> assigned_laborers <- assignLaborerToPlot(chosen_plot);
		 
		if(length(assigned_laborers) = 0){
			write "No available laborers";
			return false;
		}
		//laborer has the seeds: transplant in the chosen plot, action replantAlert(plot new_plot)
		
		ask assigned_laborers{
			current_plot <- chosen_plot;
			self.is_itp_labour <- true;
			self.location <- chosen_plot.location;
			do replantAlert(chosen_plot);
		}
		//set rotation years to plot
		do setRotationYears(chosen_plot);
		chosen_plot.is_itp <- true;
		return true;
	}

	//type 0: automatically base on harvesting age of native
	//type 1: automatically base on harvesting age of exotic
	action setRotationYears(plot the_plot){
		float mean_age_tree <- mean((the_plot.plot_trees where (each.type = itp_type)) accumulate each.age); //get the minimum age of the tree in the plot
		
		if(itp_type = 0){	//if itp type is native, or it is a mix itp and the youngest is native
			the_plot.rotation_years <- (harvesting_age_native < mean_age_tree)?harvesting_age_native:int(harvesting_age_native - mean_age_tree);
		}else if(itp_type = 1){
			the_plot.rotation_years <- (harvesting_age_exotic < mean_age_tree)?harvesting_age_exotic:int(harvesting_age_exotic - mean_age_tree);
		}		
	}

	/*
	 * the_plot: needs trees_to_be_planted in order to convert the plot into an ITP implementing selective logging
	 * Assign laborer to ITP plot: 
	 * 	Case 1: There's unassigned laborer
	 *  Case 2: There's available nursery laborer (in waiting phase)
	 * 	Case 3: Need to hire new laborer
	 * Depending on the capacity of the laborer, get n trees from the nurseries
	 * Add more laborers if the plot isn't filled yet
	 * All this happens in one step: in one month
	 */	
	list<labour> assignLaborerToPlot(plot the_plot){
		//check if there are vacant, non-nursery laborers
		
		list<labour> itp_laborers <- labour where (!each.is_nursery_labour and empty(each.my_plots));
		list<labour> assigned_laborers <- [];
		
		if(!empty(itp_laborers)){	//there's vacant laborer
			write "There's vacant laborer: "+itp_laborers;
			assigned_laborers <<+ updateAssignment(the_plot, itp_laborers);
		}
		
		if(!empty(available_seeds)){	//there's more tree to be planted, more laborer is needed
			itp_laborers <- [];
			ask my_nurseries where (length(each.my_laborers) >1){	//get laborers from nursery with more than one laborer
				itp_laborers <<+ (my_laborers where (each.current_plot = self));
			}
			
			if(!empty(itp_laborers)){
				write "Getting vacant laborer from nurseries";
				assigned_laborers <<+updateAssignment(the_plot, itp_laborers);
				ask assigned_laborers{
					is_nursery_labour <- false;
				}
				
			}
			
			if(!empty(available_seeds)){
				write "Hire new laborer";
				//depending on remaining available_seeds, create n new laborer
				int new_laborer_needed <- int(length(available_seeds)/LABOUR_PCAPACITY);
				create labour number: new_laborer_needed;
				itp_laborers <- labour where empty(each.my_plots);
				assigned_laborers <<+ updateAssignment(the_plot, itp_laborers);
			}
		}
		return assigned_laborers;
	}
	
	//as much as each one can, replant the ITP
	//update total_laborer_capacity
	list<labour> updateAssignment(plot the_plot, list<labour> itp_laborers){
		list<labour> assigned_laborers <- [];
		
		loop itp_l over: itp_laborers{
			if(empty(available_seeds)){break;}	//there's no more seeds to be planted 
			add the_plot to: itp_l.my_plots;	//add the itp plot to the list of laborer's my_plots
			add itp_l to: the_plot.my_laborers;	//put the laborer to the list of plot's laborers
			
			available_seeds <- itp_l.getTrees(available_seeds where (each.type = itp_type)); //get only trees that is relevant to ITP
				
			add itp_l to: assigned_laborers;				 	
		}
		
		return assigned_laborers;
	}
	float managementDBHEstimate(int t_type, int age){
		if(t_type=1){	//to plant exotic
			return max_dbh_exotic * (1-exp(-mahogany_von_gr * (current_month+age)));
		}else{		//to plant native
			return max_dbh_native * (1-exp(-mayapis_von_gr * (current_month+age)));
		}
	}	
	//determine if a plot is to be a nursery or not
	//	where there is a mother tree, it becomes a nursery
	action assignNurseries{
		ask plot{do updateTrees;}
		
		list<plot> candidate_plots <- plot where (length(each.plot_trees where each.is_mother_tree)>0);
		if(candidate_plots != nil and length(candidate_plots) > nursery_count){
			candidate_plots <- candidate_plots[0::nursery_count];
			ask candidate_plots{
				is_nursery <- true;	
			}	
		}
	}
	
	//divide the total number of investable plots+nursery plots to available laborers
	//NOTE: 
	// 1 laborer can manage 0..* nurseries -> meaning, they may have none or multiple nurseries
	// 1 nursery can have 1..* laborers -> meaning, a nursery must be managed by at least 1 laborer
	action assignLaborerToNursery(list<plot> to_assign_nurseries){
		//do determineInvestablePlots(1);	//plant exotic
		//get all unassigned laborers
		if(nlaborer_count = 0) { write "Nursery not accepting laborers."; return; }
		
		list<labour> free_laborers <- labour where !each.is_nursery_labour;
		
		if(length(to_assign_nurseries) <= length(free_laborers)){	//there are sufficient laborers for the nurseries
			//write "Total Nurseries: "+length(to_assign_nurseries)+" of max capacity: "+nlaborer_count+" given Total Labor: "+length(free_laborers);
		
			loop an from: 0 to: length(to_assign_nurseries)-1{
				//update the status of the laborer
				ask free_laborers[an]{
					add to_assign_nurseries[an] to: self.my_plots;
					self.man_months <- [NURSERY_LABOUR, 0];
					self.is_nursery_labour <- true;
				}
				add free_laborers[an] to: to_assign_nurseries[an].my_laborers; 
			}//assign one laborer per nursery
			
			list<labour> remaining_laborers <- free_laborers where !each.is_nursery_labour;
			
			//if nurseries can have more than one laborer and if there are unassigned laborers, assign the remaining laborers to the nurseries (provided the restriction on teh allowed number of laborers per nursery) 
			if(nlaborer_count > 1 and length(remaining_laborers) > 0){	//nurseries can have more than 1 laborer
				//write "Nurseries are given multiple laborers -- max: "+nlaborer_count+" for: "+length(remaining_laborers);

				loop an over: to_assign_nurseries{
					list<labour> laborers;
					if(length(remaining_laborers) >= nlaborer_count-1){	//there are sufficient number of laborers; nlaborer_count-1 because it is sure that one of laborers has been assigned on the nursery already
						laborers <- remaining_laborers[0::nlaborer_count-1];	//get the nlaborers from the free_laborers
					}else if(length(remaining_laborers) > 0){	//put the remaining laborers to the nursery
						laborers <- remaining_laborers;
					}else{	//there are no more laborers to be placed in nurseries
						break;
					}
					
					an.my_laborers <<+ laborers;	//add laborers to the plot's laborers
					
					//update the status of the laborer	
					ask laborers{
						add an to: self.my_plots;
						self.man_months <- [NURSERY_LABOUR, 0];
						self.is_nursery_labour <- true;
					}
					remaining_laborers >>- laborers;	//remove assigned laborers					
				}
			}else{
				write "Nurseries are given exactly one laborer";
			}
		}else{	//there are more nurseries than the laborers
//			int nurseries_per_laborer <- int(length(to_assign_nurseries)/length(free_laborers));
// 			5 nurseries, 2 laborers: laborer_1=2, laborer_2=3
			//write "Laborers are assigned to multiple nurseries... To do";
			float nurseries_per_laborer <- length(to_assign_nurseries)/length(free_laborers);	//get how many nurseries will be assigned to one laborer
			
			ask free_laborers{
				int no_nurseries; 
				if(length(to_assign_nurseries) > 0){
					//write "nurseries left: "+length(to_assign_nurseries); 
					if(length(to_assign_nurseries)>int(nurseries_per_laborer)+1){
						no_nurseries <- int(nurseries_per_laborer);
					}else{
						no_nurseries <- int(nurseries_per_laborer)+1;
					}	
				}
				else{
					break;
				}
				self.my_plots <<+ to_assign_nurseries[0::no_nurseries];
				self.man_months <- [NURSERY_LABOUR, 0];
				self.is_nursery_labour <- true;
				to_assign_nurseries >>- to_assign_nurseries[0::no_nurseries];
			}
			
			if(length(to_assign_nurseries) > 0){	//put the remaining nursery on random laborer
				labour chosen_laborer <- one_of(free_laborers);
				ask chosen_laborer{
					self.my_plots <<+ to_assign_nurseries;
					self.man_months <- [NURSERY_LABOUR, 0];
					self.is_nursery_labour <- true;
				}
			}
			
		}
		
		ask free_laborers{
			do assignLocation;
		}
	}
	
	//as manager, university gets "alerted" whenever there are new trees in the area
	//move the nursery laborer to the plot where there are new trees
	//let the laborer get as much new trees as it can carry (meaning, some new trees will not be transplanted to the nursery)
	action newTreeAlert(plot source_plot, list<trees> new_trees){
		
		new_trees <- new_trees select (each.type = itp_type);	//get only trees that is relevant to ITP
		
		list<plot> nurseries_with_space <- [];	//get the nurseries with space
		loop p over: self.my_nurseries{
			if(p.getAvailableSpaces(itp_type) > 0){
				add p to: nurseries_with_space;
			}
		}
		
		if(length(nurseries_with_space) = 0){
			//write "No more space in nursery";
			return;
		}
		
		//get the nursery laborer that is on the same plot and get more trees as long as carrying capacity permits
		list<labour> closest_laborers <- labour where (each.current_plot = source_plot and each.is_nursery_labour and each.carrying_capacity > length(each.my_trees)); 
		loop while: length(new_trees) > 0{
			if(!empty(closest_laborers)){	//laborer is on the same plot, get the new trees
				labour cl <- one_of(closest_laborers);
				new_trees <- cl.getTrees(new_trees);
				remove cl from: closest_laborers;
			}else{ break; }	
		}

		if(length(new_trees) > 0){
			plot closest_nursery <- nurseries_with_space closest_to source_plot;	//get closest nursery to plot with new tree
			list<labour> available_nlaborers <- closest_nursery.my_laborers where (each.current_plot = closest_nursery);
			if(!empty(available_nlaborers)){	//if there are more trees to be allocated, check if there are nursery laborers that is in the nursery and move that laborer to the plot where the new tree is spotted
				loop an over: available_nlaborers{
					an.current_plot <- source_plot;							//go to the source plot
					an.location <- source_plot.location;					
					new_trees <- an.getTrees(new_trees);
					if(length(new_trees) = 0) {break;}	//if there are no more trees, break
				}
			}else{//if there are still more, let the one of the laborers of the closest nursery go back to the nursery and plant all the wildlings even if it hasn't exhausted its carrying capacity yet
				labour closest_labor <- (closest_nursery.my_laborers - available_nlaborers) closest_to source_plot;
				if(closest_labor != nil){
					ask closest_labor{
						location <- closest_nursery.location;	//return to closest_nursery;
						current_plot <- closest_nursery;
						//write "In university, planting at: "+closest_nursery.name;
						do replantAlert(closest_nursery);
					}
				}
			}
		}
	}	
}



