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
	
	float getBuyingPrice(int t_type){
		return ((t_type = 1)?bprice_of_exotic:bprice_of_native);
	}
	
	float getTotalBDFT(list<trees> tth){
		float total_bdft <- 0.0;
		
		loop i over: tth{
			total_bdft <- total_bdft + (i.calculateVolume(i.dbh, i.type) / 12);	
		}
		return total_bdft;
	}	
	
	float getProfit(int type, float thv){
		return thv * ((type = EXOTIC)?exotic_price_per_volume:native_price_per_volume);
	}
}

