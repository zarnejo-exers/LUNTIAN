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
	int required_wildlings <- 1 update: required_wildlings;
	int laborer_count <- 5 update: laborer_count;
	int nlaborer_count<- 2 update: nlaborer_count;
	float planting_space <- 1.0 update: planting_space; 
	int planting_age <- 1 update: planting_age;
	int harvesting_age_exotic <- 50 update: harvesting_age_exotic;
	int harvesting_age_native <- 70 update: harvesting_age_native;
	int nursery_count <- 2 update: nursery_count;
	float harvest_policy <- 0.5 update: harvest_policy;
	
	init{
		create market;
		create university;
		create investor number: investor_count;
		create labour number: laborer_count;
	}
	
	reflex checkNurseries{
		ask university{
			do assignNurseries;
			if(length(my_nurseries) >= nursery_count){	//start ITP if there's enough nurseries
				write "Starting ITP";
				do assignLaborerToPlot(my_nurseries);
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
		list<plot> candidate_plots <- plot where (length(each.plot_trees where (each.is_mother_tree=true))>0);
		if(candidate_plots != nil and length(candidate_plots) > nursery_count){
			candidate_plots <- candidate_plots[0::nursery_count];
			ask candidate_plots{
				is_nursery <- true;	
			}	
		}
	}
	
	//divide the total number of investable plots+nursery plots to available laborers 
	action assignLaborerToPlot(list<plot> to_assign_nurseries){
		//do determineInvestablePlots(1);	//plant exotic
		//get all unassigned laborers
		list<labour> free_laborers <- labour where !each.is_nursery_labour;
		loop an over: to_assign_nurseries{
			if(length(free_laborers) >= nlaborer_count){	//there are sufficient number of laborers
				list<labour> laborers <- free_laborers[0::nlaborer_count]-1;	//get the nlaborers from the free_laborers
				an.my_laborers <<+ laborers;	//add laborers to the plot's laborers
				free_laborers >>- laborers;	//remove assigned laborers
				
				//update the status of the laborer	
				ask laborers{
					add an to: self.my_plots;
					self.man_months <- [NURSERY_LABOUR, 0];
					self.is_nursery_labour <- true;
					do assignLocation;
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
	list<trees> my_trees <- [];
	list<int> man_months <- [0,0];	//assigned, serviced 
	int current_wildlings <- 0;
	bool is_nursery_labour <- false;
	
	aspect default{
		draw triangle(length(my_trees)+50) color: #orange rotate: 90.0;
	}
	
	//put the laborer at the the center of one of its assigned plots
	action assignLocation{
		if(length(my_plots) = 1){	//if there's only one plot, put the laborer on the location of the plot
			self.location <- my_plots[0].location;
		}else if(length(my_plots where each.has_road) > 0){	//one of the plot has a road, put the laborer on one of the plots with a road
			self.location <- one_of(my_plots where each.has_road).location;
		}else{	//if there are multiple plots, just put the laborer randomly
			self.location <- one_of(my_plots).location;
		}
	}
}

