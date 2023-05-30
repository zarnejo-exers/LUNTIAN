/**
* Name: investor
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/

model actors
import "llg.gaml"

/* Insert your model definition here */
global{
	int NURSERY_LABOUR <- 12; //labor required per nursery, constant
	
	int investor_count <- 0 update: investor_count;
	int plot_size <- 1 update: plot_size;
	int laborer_count <- 5 update: laborer_count;
	int nlaborer_count<- 1 update: nlaborer_count;
	float planting_space <- 1.0 update: planting_space; 
	int planting_age <- 1 update: planting_age;
	int harvesting_age_exotic <- 50 update: harvesting_age_exotic;
	int harvesting_age_native <- 70 update: harvesting_age_native;
	int nursery_count <- 2 update: nursery_count;
	float harvest_policy <- 0.5 update: harvest_policy;
	
	bool assignedNurseries <- false;
	init{
		create market;
		create university;
		create investor number: investor_count;
		create labour number: laborer_count;
	}
	
	//automatically execute when there are no laborers assigned to nurseries
	reflex assignLaborersToNurseries when: !assignedNurseries{
		ask university{
			do assignNurseries;
			if(length(my_nurseries) >= nursery_count){	//start ITP if there's enough nurseries
				write "Starting ITP: "+length(my_nurseries)+" with: "+nursery_count;
				do assignLaborerToPlot(my_nurseries);
				assignedNurseries <- true;
			}else{
				write "Let environment grow";
			}	
		}
	}
}

species investor{
	list<plot> my_plots;
	float expected_ror;
	float profit; 
	float investment;
	
	//computes for the rate of return on the invested plots
	action computeRoR{
		
	}
}

species university{
	list<plot> my_invested_plots;		//list of plots invested by the university
	list<plot> my_nurseries <- (plot where each.is_nursery) update: (plot where each.is_nursery);	//list of nurseries managed by university
	list<plot> investable_plots;
	
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
	action determineReqInvestment{
		
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
		
		list<plot> not_investable_plots <- plot where (each.is_near_water or each.is_nursery);
		ask not_investable_plots{
			is_investable <- false;
		}
		
		ask plot - not_investable_plots{
			int spaces_for_planting <- getAvailableSpaces(t_type);	//get total number of wildlings that the plot can accommodate
			
			float total_cost <- (((planting_cost+myself.getManagementCost(t_type)) * spaces_for_planting)*myself.labor_price) ;	//compute total cost in man hours
			int rotation_years <- harvest_age - planting_age;
			
			int tree_to_harvest <- int((length(plot_trees)+spaces_for_planting)*harvest_policy);
			float projected_profit <- 0.0;
			int t_count <- 0;
			loop pt over: plot_trees{
				if(t_count=tree_to_harvest){break;}
				int future_age <- pt.age + rotation_years;
				float future_dbh <- myself.managementDBHEstimate(pt.type, future_age);
				projected_profit <- projected_profit + (future_dbh*buying_price);
				t_count <- t_count + 1;
			}
			
			float new_tree_dbh <- myself.managementDBHEstimate(t_type, harvest_age);
			projected_profit <- projected_profit + (new_tree_dbh*buying_price*(tree_to_harvest - t_count));
			is_investable <- (projected_profit > total_cost)?true:false;
			if(is_investable){
				add self to: myself.investable_plots;
			}
		}
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
	action assignLaborerToPlot(list<plot> to_assign_nurseries){
		//do determineInvestablePlots(1);	//plant exotic
		//get all unassigned laborers
		list<labour> free_laborers <- labour where !each.is_nursery_labour;
		
		if(length(to_assign_nurseries) <= length(free_laborers)){	//there are sufficient laborers for the nurseries
			write "Total Nurseries: "+length(to_assign_nurseries)+" of max capacity: "+nlaborer_count+" given Total Labor: "+length(free_laborers);
		
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
				write "Nurseries are given multiple laborers -- max: "+nlaborer_count+" for: "+length(remaining_laborers);

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
			write "Laborers are assigned to multiple nurseries... To do";
			float nurseries_per_laborer <- length(to_assign_nurseries)/length(free_laborers);	//get how many nurseries will be assigned to one laborer
			
			ask free_laborers{
				int no_nurseries; 
				if(length(to_assign_nurseries) > 0){
					write "nurseries left: "+length(to_assign_nurseries); 
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
		write "Plot: "+source_plot.name+" Trees: "+length(new_trees);
		
		//get any laborer that is on the same plot (current_plot = source_plot) and is still able to get more trees
		loop while: length(new_trees) > 0{
			labour closest_laborer <- labour where (each.carrying_capacity != length(each.my_trees)) closest_to source_plot;
			if(closest_laborer.current_plot = source_plot){	//laborer is on the same plot, get the new trees
				new_trees <- closest_laborer.getTrees(new_trees);
			}else{ break; }	
		}
		
		//there are more trees to be allocated
		// and there is there is no/ no more laborer in the plot, get available laborers that is currently in one of its nursery plot
		if(length(new_trees) > 0){
			plot closest_nursery <- (plot where each.is_nursery) closest_to source_plot;	//get closest nursery to plot with new tree	
			list<labour> available_laborers <- closest_nursery.my_laborers where (each.current_plot = closest_nursery);
			if(length(available_laborers) = 0){		//let the closest laborer go back to the nursery and plant all the widlings that it had gathered
				labour closest_labor <- closest_nursery.my_laborers closest_to source_plot;
				ask closest_labor{
					location <- closest_nursery.location;	//return to closest_nursery;
					current_plot <- closest_nursery;
					write "In university, planting at: "+closest_nursery.name;
					do replantAlert(closest_nursery);
				}		
			}else{	//choose one laborer and move the laborer to source_plot
				loop al over: available_laborers{
					if(length(new_trees) = 0) {break;}	//if there are no more trees, break
					al.current_plot <- source_plot;							//go to the source plot
					al.location <- source_plot.location;					
					new_trees <- al.getTrees(new_trees);
				}
			}	
		}
	}	
}

species market{
	float bprice_of_exotic <- 3.0;	//php per dbh
	float bprice_of_native <- 5.0; 	//php per dbh
	
	float getBuyingPrice(int t_type){
		return ((t_type = 1)?bprice_of_exotic:bprice_of_native);
	}
	
}

species labour{
	list<plot> my_plots <- [];
	plot current_plot;
	list<trees> my_trees <- [];		//list of wildlings that the laborer currently carries
	list<int> man_months <- [0,0];	//assigned, serviced 
	int carrying_capacity <- 10;	//total number of wildlings that a laborer can carry 
	bool is_nursery_labour <- false;
	
	aspect default{
		draw triangle(length(my_trees)+50) color: #orange rotate: 90.0;
	}
	
	reflex removeDeadTrees{
		my_trees <- my_trees where !dead(each);
	}
	
	//put the laborer at the the center of one of its assigned plots
	action assignLocation{
		if(length(my_plots) = 0){
			return;
		}
		
		if(length(my_plots where each.has_road) > 0){	//one of the plot has a road, put the laborer on one of the plots with a road
			current_plot <- one_of(my_plots where each.has_road);
			write self.name+" at current_plot "+current_plot.name;
		}else{	//put the laborer randomly
			current_plot <- one_of(my_plots);
			write self.name+" at current_plot "+current_plot.name;
		}
		self.location <- current_plot.location;
	}
	
	reflex checkIfMustReplant when: carrying_capacity = length(my_trees){
		list<plot> available_plots <- my_plots where (each.getRemainingSpace() != nil);	//all plots with remaining space
		if(length(available_plots) > 0){
			plot nursery <- available_plots closest_to current_plot;
			location <- nursery.location;		//go back to the nursery and plant the trees
			current_plot <- nursery;
			write "Planting at: "+nursery.name;
			do replantAlert(nursery);	
		}//else, do nothing; meaning, just wait until there are available plots
		
	}
	
	//The capacity of the laborer is reached, plant the trees to the nursery
	action replantAlert(plot nursery){		
		geometry remaining_space <- nursery.getRemainingSpace();
		loop while: remaining_space != nil and length(my_trees) > 0{	//use the same plot while there are spaces; plant while there are trees to plant
			trees to_plant <- one_of(my_trees);	//get one of the trees
			to_plant.is_new_tree <- false;
			to_plant.my_plot <- nursery;	//update plot of tree
			nursery.plot_trees << to_plant;	//put tree to the tree list of the nursery
			to_plant.location <- any_location_in(remaining_space);	//plant anywhere inside the remaining_space;
			remove to_plant from: my_trees;
			geometry new_occupied_space <- circle(to_plant.dbh) translated_to to_plant.location;
			remaining_space <- remaining_space - new_occupied_space;
		}	
	}
	
	//laborer gets as much tree as it can get 
	list<trees> getTrees(list<trees> treeToBeAlloc){
		if(length(treeToBeAlloc) >= self.carrying_capacity){			//there are more trees than the laborer can hold
			self.my_trees <<+ treeToBeAlloc[0::self.carrying_capacity];
			treeToBeAlloc >>- treeToBeAlloc[0::self.carrying_capacity];			
		}else{	//the number of trees isn't enough to make the laborer go back to the nursery to plant
			self.my_trees <<+ treeToBeAlloc;	//get all the trees
			treeToBeAlloc <- [];		//set the new unassigned trees to empty
		}
		
		ask self.my_trees where each.is_new_tree{	//all allocated trees are no longer new trees
			is_new_tree <- false;
		}
		
		return treeToBeAlloc;
	}
}

