/**
* Name: specialpolice
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model special_police
import "university_si.gaml"

/* Insert your model definition here */
//one instance of special_police = 1 group of police
species special_police{
	bool is_servicing <- false; 	//is the special police currently hired
	int total_years_served <- 0;	//number of years the police was hired
	plot assigned_area <- nil;		//position of the sp in the environment
	list<plot> observed_neighborhood <- [];
	int total_comm_members_reprimanded <- 0; 	//remembers only the number, since they are not mandated to catch
	rgb color_neighbor <- rnd_color(0, 255);
	
	aspect si{
		loop p over: observed_neighborhood{
			draw p.shape color: color_neighbor;
		}
	}
	
	reflex updateArea when: (cycle mod 3 = 0) and is_servicing{
		//the police is going to change place, so the current place will no longer be policed
		if(length(observed_neighborhood) > 0){	
			ask observed_neighborhood{
				is_policed <- false;
				remove self from: myself.observed_neighborhood;
			}
		}
		
		//getting new location
		list<plot> open_plots <- getOpenPlots();
		
		assigned_area <- open_plots[rnd(length(open_plots)-1)];
		assigned_area.is_policed <- true;
		location <- assigned_area.location;
		//get the neighbor of the plot
		ask assigned_area{
			myself.observed_neighborhood <- (plot at_distance 50) where (!each.is_policed);
		}
		observed_neighborhood <- observed_neighborhood+assigned_area;
	} 
	
	list<plot> getOpenPlots{
		list<special_police> sp <- special_police where (each.is_servicing and assigned_area!=nil);
		list<plot> guarded_plots <- (sp collect each.assigned_area) + (sp collect each.observed_neighborhood);	//get all guarded places
		return plot - guarded_plots;
	} 
	
	reflex guardPlotNeighborhood when: is_servicing{
		loop on over: observed_neighborhood{
			on.is_policed <- true;
			ask on.my_laborers where (each.labor_type = each.COMM_LABOUR and each.com_identity != nil){	
				if(com_identity.state="independent_harvesting" and !com_identity.is_caught){
					write "Special police "+name+" caught member "+com_identity.name;
					com_identity.is_caught <- true;
					myself.total_comm_members_reprimanded <- myself.total_comm_members_reprimanded + 1; 
				}
			}
		}
	} 
	
}