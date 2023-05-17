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
	
	init{
		create investor number: investor_count;
		create university;
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
	list<plot> my_nurseries;	//list of nurseries managed by university
	list<plot> investable_plots;
	
	/*
	 * Determine amount of investment needed per hectare
		Given the current number of trees in the plot, 
        determine the cost needed to plant new trees (how many trees are to be planted)
	 */
	action determineReqInvestment{
		
	}
	
	//for each plot, determine if plot is investable or not
	action determineInvestablePlots{
		
	}
	
	//determine if a plot is to be a nursery or not
	//	where there is a mother tree, it becomes a nursery
	reflex assignNurseries when: (nursery_count > length(plot where each.is_nursery)){
		list<plot> candidate_plots <- plot where (length(each.plot_trees where (each.is_mother_tree=true))>0);
		if(length(candidate_plots) > nursery_count){
			candidate_plots <- candidate_plots[0::nursery_count];
		}
		ask candidate_plots{
			is_nursery <- true;
		}
	}	
	
}

species labor{
	plot my_plot;
	float number_of_wh;
	
	
}

