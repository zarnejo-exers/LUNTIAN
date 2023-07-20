/**
* Name: market
* Based on the internal empty template. 
* Author: admin
* Tags: 
*/


model market
import "university.gaml"

/* Insert your model definition here */

species market{
	float bprice_of_exotic <- 3.0;	//php per dbh
	float bprice_of_native <- 5.0; 	//php per dbh
	
	float getBuyingPrice(int t_type){
		return ((t_type = 1)?bprice_of_exotic:bprice_of_native);
	}
	
}