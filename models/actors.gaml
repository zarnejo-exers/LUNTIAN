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
	int investor_count <- 0 update: investor_count;
	int plot_size <- 1 update: plot_size;
	int required_wildlings <- 1 update: required_wildlings;
	int laborer_count <- 1 update: laborer_count;
	
	init{
		create university;
		create investor number: investor_count;
		create labour number: laborer_count;
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
	
	/*
	 * Determine amount of investment needed per hectare
		Given the current number of trees in the plot, 
        determine the cost needed to plant new trees (how many trees are to be planted)
	 */
	action determineReqInvestment{
		
	}
	
	//for each plot, determine if plot is investable or not
	//investable -> if (profit > cost & profit > threshold)
	//profit : current trees in n years, where n = rotation of newly planted trees
	//cost : number of wildlings that needs to be planted 
	//note: consider that the policy of the government will have an effect on the actual profit, where only x% can be harvested from a plot of y area
	action determineInvestablePlots{
		
	}
	
	//determine if a plot is to be a nursery or not
	//	where there is a mother tree, it becomes a nursery
	reflex assignNurseries when: (nursery_count > length(my_nurseries)){
		list<plot> candidate_plots <- plot where (length(each.plot_trees where (each.is_mother_tree=true))>0);
		if(length(candidate_plots) > nursery_count){
			candidate_plots <- candidate_plots[0::nursery_count];
		}
		ask candidate_plots{
			is_nursery <- true;
		}
	}
	
	//divide the total number of investable plots+nursery plots to available laborers 
	action assignLaborerToPlot{
		
	}	
	
}

species labour{
	plot my_plot;
	list<float> working_hours <- [0.0,0.0];	//assigned, serviced 
	int current_wildlings <- 0;
	
	
}

