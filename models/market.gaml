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
	float bprice_of_exotic <- 4000.0;	//php per cubic meter
	float bprice_of_native <- 8000.0; 	//php per dbh
	float native_sapling_price <- 100.0; //TODO: must set
	
	float getBuyingPrice(int t_type){
		return ((t_type = 1)?bprice_of_exotic:bprice_of_native);
	}
	
	float getTotalBDFT(list<trees> tth){
		float total_bdft <- 0.0;
		
		ask tth{
			ask university_si{
				total_bdft <- total_bdft + (calculateVolume(myself.dbh, myself.type)/12);	//TODO: get the source of bdft computation
			}
		}
		
		return total_bdft;
	}	
	
	float getProfit(int type, float th_bdft){
		return th_bdft * ((type = EXOTIC)?exotic_price_per_bdft:native_price_per_bdft);
	}
}

