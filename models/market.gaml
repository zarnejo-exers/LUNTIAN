/**
* Name: market
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model market
import "university_si.gaml"

/* Insert your model definition here */

species market{
	float current_inflation <- 3.42; //https://forestry.denr.gov.ph/pdf/ds/prices-lumber.pdf
	
	
	float getMinBDFT(int type){
		float min_bdft;
		ask university_si{
			min_bdft <- (calculateVolume(60.0, type)/12);	//https://www.montana.edu/extension/forestry/projectlearningtree/activitybooklets/Estimating%20Individual%20Tree%20Volume.pdf
		}
		return min_bdft;
	}
	
	//cubic feet
	float getTotalBDFT(list<trees> tth){
		float total_bdft <- 0.0;
		
		ask tth{
			ask university_si{
				total_bdft <- total_bdft + (calculateVolume(myself.dbh, myself.type)/12);	//https://www.montana.edu/extension/forestry/projectlearningtree/activitybooklets/Estimating%20Individual%20Tree%20Volume.pdf
			}
		}
		
		return total_bdft;
	}	
	
	float getProfit(int type, float th_bdft){
		return th_bdft * ((type = EXOTIC)?exotic_price_per_bdft:native_price_per_bdft);
	}

//	add as a simulation scenario 	
//	reflex inflation when : current_month=11{
//		float random_fct <- rnd(-0.5, 0.5);
//		current_inflation <- current_inflation + (current_inflation * random_fct); 
//		
//		exotic_price_per_bdft <- (exotic_price_per_bdft)*((current_inflation*(10^-2))+1);
//		native_price_per_bdft <- (native_price_per_bdft)*((current_inflation*(10^-2))+1);
//	} 
}
