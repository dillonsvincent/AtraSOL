pragma solidity^0.4.20;

contract ADS {

    struct RouteData {
        string abiLocation;
        address contractAddress;
    }

    struct Route {
        string name; //this will never change, used as a key
        uint goingLive; // epoch timestamp that warns clients when the upcoming switch will happen
        address owner;
        address newOwner;
        RouteData current;
        RouteData upcoming;
    }
    
    // Declare Storage 
    Route[] public Routes;
    mapping(bytes32 => uint) public ContractNamesToRoutes; // keccak256([name])

    //Constructor
    function ADS() public {
        // Create padding in Routes array to be able to check for unique name in list by returning 0 for no match
        ContractNamesToRoutes[keccak256('')] = Routes.push(Route('', 0, this, this, RouteData('NULL',this), RouteData('NULL',this))) -1;
        // Register ADS to position 1 
        ContractNamesToRoutes[keccak256('ADS')] = Routes.push(Route('ADS', 0, msg.sender, msg.sender, RouteData('atra.io/abi/ads',this), RouteData('atra.io/abi/ads',this))) -1;
    }

    function Get(string routeName) public view returns(string name, address owner, uint goingLive, address currentContractAddress, string currentAbiLocation, address upcomingAddress, string upcomingAbiLocation) {
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        return (route.name, route.owner, route.goingLive, route.current.contractAddress, route.current.abiLocation, route.upcoming.contractAddress, route.upcoming.abiLocation);
    }

    // creating a route is free
    // you can create a route with the intent to update it in the near future, by batching this logic it saves tx fees
    function Create(string name, address currentAddress, string currentAbiLocation, address upcomingAddress, string upcomingAbiLocation, address newOwner, uint goingLive) public returns(uint newRouteId) {
        require(bytes(name).length > 0);
        require(ContractNamesToRoutes[keccak256(name)] == 0);
        // "x","0xd26114cd6EE289AccF82350c8d8487fedB8A0C07", "github.com/omg/abi", "", "0x0", 0
        RouteData memory current = RouteData(currentAbiLocation, currentAddress);
        RouteData memory upcoming = RouteData(upcomingAbiLocation, upcomingAddress);
        return ContractNamesToRoutes[keccak256(name)] = Routes.push(Route(name, goingLive, msg.sender, newOwner, current, upcoming)) -1;
    }

    // Used to update the upcoming contract data, you can not change the current data with an update you must use GoLive
    function Update(string name, uint goingLive, address newContractAddress, string newAbiLocation) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)];
        require(Routes[routeId].owner == msg.sender); //require sender to be owner to update
        Routes[routeId].goingLive = goingLive; // update going live to new unix time uint
        Routes[routeId].upcoming.contractAddress = newContractAddress; // update upcoming address
        Routes[routeId].upcoming.abiLocation = newAbiLocation; // update upcoming abi location
        return true; // return success
    }

    //This function will switch over the upcoming route to the current route data if the goingLive has lapsed
    function GoLive(string name) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)]; // get route Id by route name
        require(Routes[routeId].owner == msg.sender); //require sender to be owner to update
        Routes[routeId].current = Routes[routeId].upcoming; // update current with contents of upcoming
        Routes[routeId].goingLive = now; // set going live to the current time in UTC
        return true; // return success
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