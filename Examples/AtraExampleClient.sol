pragma solidity^0.4.20;

interface Logic {
	function Calc(uint num1, uint num2) external view returns(uint result);
}

interface ADS {
	function GetCurrentAddress(string name) external view returns(address currentAddress);
}


contract Client1 {
	//Client contract will request info from logic contracts to silumlate a network of contracts
	address AdsAddress;
	uint num1 = 500;
	uint num2 = 300;
	function Client1(address adsAddress) public {
		AdsAddress = adsAddress;
	}
	//Contract will use the ads address instead of contacting logic contracts directly
	function Calculate() public view returns(uint result) {
		ADS ads = ADS(AdsAddress);
		Logic logic = Logic(ads.GetCurrentAddress('logic'));
	    return logic.Calc(num1, num2);
	}
	
	function GetAdsRouteAddress(string name) public view returns(address) {
		ADS ads = ADS(AdsAddress);
		return ads.GetCurrentAddress(name);
	}
}