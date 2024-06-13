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
	
	//https://erc.cals.wisc.edu/woodlandinfo/files/2017/09/G3332.pdf
	/* The rule of thumb is about 5 bdft per cubic foot of roundwood when DBH is 7 inches;
	 * about 6.5boardfeet per cubic foot when the DBH is about 26 inches. 
	 * However, when the tree is so small products cannot be manufactured.
	 * */
	float getMultiplier(float dbh){
		float multiplier <- 0.0;
		dbh <- dbh/2.54;	//2.54 is to convert cm to inch
		if(dbh > 26){	
			multiplier <- 6.5;						
		}else if(dbh >= 7 and dbh < 26){
			multiplier <- 5.0;
		}
		return multiplier;
	}
	
	float getBDFT(float dbh, int type, float th){
		float bdft;
		float multiplier <- getMultiplier(dbh);
		ask university_si{
//			write " >> round wood volume: "+getRoundwoodVolume(dbh, type);
			bdft <- getRoundwoodVolume(dbh, type, th)*multiplier;	//https://www.montana.edu/extension/forestry/projectlearningtree/activitybooklets/Estimating%20Individual%20Tree%20Volume.pdf
//			write " >> with multiplier: "+multiplier;
		}
		
		//write "current: "+bdft;
		return bdft;
	}

	//cubic feet
	float getTotalBDFT(list<trees> tth){
		float total_bdft <- 0.0;
		
		loop t over: tth{
			total_bdft <- total_bdft + getBDFT(t.dbh, t.type, t.th);	
		}
		
//		write "total_bdft: "+total_bdft;
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
