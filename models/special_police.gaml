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
	list<plot> observed_neighborhood <- nil;
	int total_comm_members_reprimanded <- 0; 	//remembers only the number, since they are not mandated to catch
	
	reflex updateArea when: (cycle mod 3 = 0) and is_servicing{
		if(assigned_area != nil){	//the police is going to change place, so the current place will no longer be policed
			assigned_area.is_policed <- false;
		}
		
		list<special_police> sp <- special_police where (each.is_servicing and assigned_area!=nil);
		list<plot> guarded_plots <- (sp collect each.assigned_area) + (sp collect each.observed_neighborhood);	//get all guarded places
		
		list<plot> open_plots <- plot - guarded_plots;
		
		assigned_area <- open_plots[rnd(length(open_plots))];
		assigned_area.is_policed <- true;
		location <- assigned_area.location;
		//get the neighbor of the plot
		ask assigned_area{
			myself.observed_neighborhood <- plot at_distance 8;
		}
		observed_neighborhood <- observed_neighborhood+assigned_area;
	} 
	
	reflex guardPlotNeighborhood when: is_servicing{
		loop on over: observed_neighborhood{
			if(on.my_laborers!=nil){
				loop ml over: on.my_laborers{
					if(ml.com_identity != nil and ml.com_identity.state="independent_harvesting"){
						ml.com_identity.is_caught <- true;
						total_comm_members_reprimanded <- total_comm_members_reprimanded + 1; 
					}
				}
			}
		}
	} 
	
}