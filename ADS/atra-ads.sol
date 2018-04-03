pragma solidity^0.4.20;

contract ADS {

    struct RouteData {
        string abiLocation; // url pointing to the abi json
        address contractAddress; // address pointing to an ethereum contract
    }

    struct Route {
        string name; //this will never change, used as a key
        uint currentExpiration; // the epoch time when the current contract expires, 0=never
        address owner; // address that owns/created and can modify route
        address newOwner; // used to transfer ownership
        RouteData current; // current contract data
        RouteData upcoming; // upcomin contract data
    }
    
    // Declare Storage 
    Route[] public Routes;
    mapping(bytes32 => uint) public ContractNamesToRoutes; // keccak256([name])
    mapping(address => uint[]) public OwnersToRoutes; 

    //Constructor
    function ADS() public {
        // Create padding in Routes array to be able to check for unique name in list by returning 0 for no match
        ContractNamesToRoutes[keccak256('')] = Routes.push(Route('', 0, this, this, RouteData('NULL',this), RouteData('NULL',this))) -1;
        // Register ADS to position 1 
        ContractNamesToRoutes[keccak256('ADS')] = Routes.push(Route('ADS', 0, msg.sender, msg.sender, RouteData('atra.io/abi/ads',this), RouteData('atra.io/abi/ads',this))) -1;
    }

    function Get(string routeName) public view returns(string name, address owner, uint currentExpiration, address currentContractAddress, string currentAbiLocation, address upcomingAddress, string upcomingAbiLocation) {
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        return (route.name, route.owner, route.currentExpiration, route.current.contractAddress, route.current.abiLocation, route.upcoming.contractAddress, route.upcoming.abiLocation);
    }
    
    //returns the valid contract address
    function GetAddress(string routeName) public view returns(address validAddress){
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        if(route.currentExpiration < now){ // the current contract has expired use upcoming
            return route.upcoming.contractAddress;
        }else{
            return route.current.contractAddress;  
        }
    }
    
    function GetCurrentAddress(string routeName) public view returns(address currentContractAddress) {
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        return route.current.contractAddress;
    }
    function GetUpcomingAddress(string routeName) public view returns(address upcomingContractAddress) {
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        return route.upcoming.contractAddress;
    }
    

    // creating a route is free
    // you can create a route with the intent to update it in the near future, by batching this logic it saves tx fees
    function Create(string name, address currentAddress, string currentAbiLocation, address upcomingAddress, string upcomingAbiLocation, address newOwner, uint currentExpiration) public returns(uint newRouteId) {
        require(bytes(name).length > 0);
        require(ContractNamesToRoutes[keccak256(name)] == 0);
        // "x","0xd26114cd6EE289AccF82350c8d8487fedB8A0C07", "github.com/omg/abi", "0xd26114cd6EE289AccF82350c8d8487fedB8A0C07", "github.com/omg/abi", "0x0", 0
        RouteData memory current = RouteData(currentAbiLocation, currentAddress);
        RouteData memory upcoming = RouteData(upcomingAbiLocation, upcomingAddress);
        return ContractNamesToRoutes[keccak256(name)] = Routes.push(Route(name, now + currentExpiration, msg.sender, newOwner, current, upcoming)) -1;
    }

    function Update(string name, uint currentExpiration, address newContractAddress, string newAbiLocation) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)];
        require(Routes[routeId].owner == msg.sender); //require sender to be owner to update
        Routes[routeId].currentExpiration = currentExpiration == 0 ? 0 : now + currentExpiration; // update when the current contract expires to epoch
        Routes[routeId].upcoming.contractAddress = newContractAddress; // update upcoming address
        Routes[routeId].upcoming.abiLocation = newAbiLocation; // update upcoming abi location
        return true; // return success
    }
    
    //This function will switch over the upcoming route to the current route data if the current route has expired, and set expiration
    function Live(string name) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)]; // get route Id by route name
        require(Routes[routeId].owner == msg.sender); //require sender to be owner to update
        //require there to be an expiration time for the current contract and it be expired
        require(Routes[routeId].currentExpiration != 0 && Routes[routeId].currentExpiration < now);
        Routes[routeId].current = Routes[routeId].upcoming; // update current with contents of upcoming
        Routes[routeId].currentExpiration = 0; // set the current contract to never expire
        return true; // return success
    }
    
    function WhatsNow() public view returns(uint time){
        return now;
    }
    
    function NameTaken(string name) public view returns(bool) {
        require(bytes(name).length > 0);
        if(ContractNamesToRoutes[keccak256(name)] == 0){
            return false;//name is not taken
        }else{
            return true;
        }
    }

    function TransferRouteOwnership(string name, address newOwner) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)]; // get route Id by route name
        require(Routes[routeId].owner == msg.sender); //require sender to be owner to transfer ownership
        Routes[routeId].newOwner = newOwner; // set new owner
        return true; // return success
    }

    function AcceptRouteOwnership(string name) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)]; // get routeId by route name
        require(Routes[routeId].newOwner == msg.sender); //require sender to be newOwner to accecpt ownership
        Routes[routeId].owner = Routes[routeId].newOwner; // transfer ownership
        return true; // return success
    }
}