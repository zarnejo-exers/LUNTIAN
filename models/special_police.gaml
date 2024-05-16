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
	int total_years_served <- 0;	//number of years the police was hired
	plot assigned_area <- nil;		//position of the sp in the environment
	list<plot> observed_neighborhood <- [];
	int total_comm_members_reprimanded <- 0; 	//remembers only the number, since they are not mandated to catch
	float total_wage <- 0.0;
	
	aspect default{
		draw hexagon(5) color: #yellowgreen;
		
		ask observed_neighborhood - assigned_area{
			draw hexagon(5) color: #yellowgreen at: any_location_in(self);
		}
	}
	
	reflex updateArea when: (current_month mod 3 = 0){
		//the police is going to change place, so the current place will no longer be policed
		if(length(observed_neighborhood) > 0){	
			ask observed_neighborhood{
				is_policed <- false;
				remove self from: myself.observed_neighborhood;
			}
		}
		
		//getting new location
		list<plot> open_plots <- getOpenPlots();
		assigned_area <- one_of(open_plots);	//get randomly from the open plots
		location <- point(0,0,0);
		if(assigned_area != nil){
			location <- any_location_in(assigned_area.location);
			assigned_area.is_policed <- true;
			add all: (plot where (!each.is_policed and !each.is_nursery)) closest_to (self, 8) to: observed_neighborhood;
			add assigned_area to: observed_neighborhood;
			ask observed_neighborhood{
				is_policed <- true;
			}			
		}
	} 
	
	list<plot> getOpenPlots{
		list<special_police> sp <- special_police where (assigned_area!=nil);
		list<plot> guarded_plots <- (sp collect each.assigned_area) + (sp collect each.observed_neighborhood);	//get all guarded places
		return (plot where ((!each.is_policed) and !each.is_nursery)) - guarded_plots;
	} 
	
	reflex guardPlotNeighborhood{
		list<labour> observed_labour <- ((comm_member where (each.state = "independent_harvesting")) collect each.instance_labour)-uni_laborers;
		
		loop on over: observed_neighborhood{
			ask (observed_labour inside on){
//				write "Special police "+name+" caught member "+com_identity.name;
				com_identity.is_caught <- true;
				myself.total_comm_members_reprimanded <- myself.total_comm_members_reprimanded + 1; 
			}
		}
		ask university_si{
			do payPatrol(myself, 1.33*length(myself.observed_neighborhood));
		}
	} 
	
}