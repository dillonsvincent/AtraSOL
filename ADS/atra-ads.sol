pragma solidity^0.4.20;
/*
    Company: Atra Blockchain Services LLC
    Website: atra.io
    Author: Dillon Vincent
    Title: Address Delegate Service (ADS)
    Description: ADS provides the functionality to mange communication with contracts. 
    Rely on ADS for routing your product name to your products contract.
    Features:
    Create Route: Create a unique route name between 1-100 characters that you own along with the data
    Edit Route: Modify next route data
    Update Route: Updates the route to use the next route data as current
    Own Route: Senders own their routes and have the ability to transfer ownership 
    Loook Ups: Find all routes that a sender owns. Get route date by name.
    Date: 4/4/18
*/
interface IADS {
    function Create(string name, address currentAddress, string currentAbiLocation, address nextAddress, string nextAbiLocation, address newOwner, uint activateDate) public payable returns(uint newRouteId);
    
    function Edit(string name, uint activateNext, address nextContractAddress, string nextAbiLocation) public returns(bool success);
    
    function Update(string name) public returns(bool success);
    
    function Get(uint routeId, string routeName) public view returns(string name, address owner, uint currentExpiration, address currentContractAddress, string currentAbiLocation, address nextAddress, string nextAbiLocation, uint created);
    function GetRouteIdsForOwner(address owner) public view returns(uint[] routeIds);
    function GetAddress(string routeName) public view returns(address validAddress);
    function GetCurrentAddress(string routeName) public view returns(address currentContractAddress);
    function GetNextAddress(string routeName) public view returns(address nextContractAddress);
    
    function RoutesLength() public view returns(uint length);
    function NameTaken(string name) public view returns(bool);
    
    function TransferRouteOwnership(string name, address newOwner) public returns(bool success);
    function AcceptRouteOwnership(string name) public returns(bool success);
}
contract AtraOwners {
    address public owner;
    address private newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    function AtraOwners() public {
        owner = msg.sender;
    }

    modifier isOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public isOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract ADS is IADS, AtraOwners {

    struct RouteData {
        string abiLocation; // url pointing to the abi json
        address contractAddress; // address pointing to an ethereum contract
    }

    struct Route {
        string name; //this will never change, used as a key
        uint activateNext; // the epoch time when the next contract activates, 0 = never
        address owner; // address that owns/created and can modify route
        address newOwner; // used to transfer ownership
        RouteData current; // current contract data
        RouteData next; // next contract data
        uint created; //time created
    }
    
    // Declare Storage 
    uint RoutePrice = 10000000000000000;
    Route[] public Routes;
    mapping(bytes32 => uint) public ContractNamesToRoutes; // keccak256([name])
    mapping(address => uint[]) public OwnersToRoutes;
    
    //Events
    event RouteCreated(string name, address owner);
    event RouteEdited(string name, address owner);
    event RouteUpdated(string name, address owner);
    event TransferOwnership(string name, address owner, address newOwner);
    event AcceptOwnership(string name, address newOwner);

    //Constructor
    function ADS() public {
        // Create padding in Routes array to be able to check for unique name in list by returning 0 for no match
        ContractNamesToRoutes[keccak256('')] = Routes.push(Route('', 0, this, this, RouteData('NULL',this), RouteData('NULL',this), now)) -1;
        // Register ADS to position 1 
        ContractNamesToRoutes[keccak256('ADS')] = Routes.push(Route('ADS', 0, msg.sender, msg.sender, RouteData('atra.io/abi/ads',this), RouteData('atra.io/abi/ads',this), now)) -1;
        OwnersToRoutes[msg.sender].push(1);
    }

    function Get(uint routeId, string routeName) public view returns(string name, address owner, uint currentExpiration, address currentContractAddress, string currentAbiLocation, address nextAddress, string nextAbiLocation, uint created) {
        Route memory route;
        if(bytes(routeName).length > 0){
            route = Routes[ContractNamesToRoutes[keccak256(routeName)]];  
        }else{
            route = Routes[routeId];  
        }
        return (route.name, route.owner, route.activateNext, route.current.contractAddress, route.current.abiLocation, route.next.contractAddress, route.next.abiLocation, route.created);
    }
    
    function GetRouteIdsForOwner(address owner) public view returns(uint[] routeIds) {
        return OwnersToRoutes[owner];
    }
    
    //returns the valid contract address
    function GetAddress(string routeName) public view returns(address validAddress) {
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        if(route.activateNext < now){
            return route.next.contractAddress;
        }else{
            return route.current.contractAddress;  
        }
    }
    
    function GetCurrentAddress(string routeName) public view returns(address currentContractAddress) {
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        return route.current.contractAddress;
    }
    
    function GetNextAddress(string routeName) public view returns(address nextContractAddress) {
        Route memory route = Routes[ContractNamesToRoutes[keccak256(routeName)]];
        return route.next.contractAddress;
    }
    
    function RoutesLength() public view returns(uint length){
        return Routes.length;
    }
    
    function NameTaken(string name) public view returns(bool) {
        require(bytes(name).length > 0 && bytes(name).length <= 100);
        if(ContractNamesToRoutes[keccak256(name)] == 0){
            return false;//name is not taken
        }else{
            return true;
        }
    }
    
    function Create(string name, address currentAddress, string currentAbiLocation, address nextAddress, string nextAbiLocation, address newOwner, uint activateDate) public payable returns(uint newRouteId) {
         require(msg.value == RoutePrice);
        // validate inputs
        require(bytes(name).length > 0 && bytes(name).length <= 100 && bytes(currentAbiLocation).length <= 256 && bytes(nextAbiLocation).length <= 256);
        require(ContractNamesToRoutes[keccak256(name)] == 0);
        uint routeId = Routes.push(Route(name, activateDate == 0 ? 0 : now + activateDate, msg.sender, newOwner, RouteData(currentAbiLocation, currentAddress), RouteData(nextAbiLocation, nextAddress),now)) -1;
        OwnersToRoutes[msg.sender].push(routeId);
        emit RouteCreated(name, msg.sender);
        return ContractNamesToRoutes[keccak256(name)] = routeId;
    }

    function Edit(string name, uint activateNext, address nextContractAddress, string nextAbiLocation) public returns(bool success) {
        //dont require name validation since we aren't storing it
        require(bytes(nextAbiLocation).length <= 256);
       
        uint routeId = ContractNamesToRoutes[keccak256(name)];
        require(Routes[routeId].owner == msg.sender); //require sender to be owner to update
        Routes[routeId].activateNext = activateNext == 0 ? 0 : now + activateNext; // update when the next contract is active to epoch
        Routes[routeId].next.contractAddress = nextContractAddress; // update next address
        Routes[routeId].next.abiLocation = nextAbiLocation; // update next abi location
        emit RouteEdited(name, msg.sender);
        return true; // return success
    }
    
    //This function will switch over the next route to the current route data if the next route is active
    function Update(string name) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)]; // get route Id by route name
        require(Routes[routeId].activateNext != 0 && Routes[routeId].activateNext < now);
        Routes[routeId].current = Routes[routeId].next; // update current with contents of next
        Routes[routeId].activateNext = 0; // set the activateNext contract to never activate
        emit RouteUpdated(name, msg.sender);
        return true; // return success
    }
    

    function TransferRouteOwnership(string name, address newOwner) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)]; // get route Id by route name
        require(Routes[routeId].owner == msg.sender); //require sender to be owner to transfer ownership
        Routes[routeId].newOwner = newOwner; // set new owner
        emit TransferOwnership(name, msg.sender, newOwner);
        return true; // return success
    }

    function AcceptRouteOwnership(string name) public returns(bool success) {
        uint routeId = ContractNamesToRoutes[keccak256(name)]; // get routeId by route name
        require(Routes[routeId].newOwner == msg.sender); //require sender to be newOwner to accecpt ownership
        
        //delete route lookup for pervious owner
        //get last routeid in array
        uint keepRouteId = OwnersToRoutes[Routes[routeId].owner][OwnersToRoutes[Routes[routeId].owner].length - 1];
        //replace routeId marked for delete
        for(uint x = 0; x < OwnersToRoutes[Routes[routeId].owner].length; x++){
            if(OwnersToRoutes[Routes[routeId].owner][x] == routeId){
                OwnersToRoutes[Routes[routeId].owner][x] = keepRouteId;
            }
        }
        //delete last position
        delete OwnersToRoutes[Routes[routeId].owner][OwnersToRoutes[Routes[routeId].owner].length - 1];
        //adjust array length
        OwnersToRoutes[Routes[routeId].owner].length--;
        
        // Add route to new owner
        Routes[routeId].owner = Routes[routeId].newOwner; // transfer ownership
        OwnersToRoutes[Routes[routeId].owner].push(routeId); // add lookup
        
        emit AcceptOwnership(name, Routes[routeId].owner);
        return true; // return success
    }
    function Price() public view returns(uint price) {
        return RoutePrice;
    } 
    
    function SetPrice(uint amount) public isOwner returns(bool) {
        RoutePrice = amount;
        return true;
    }

    function Widthdraw(uint amount) public isOwner returns(bool) {
        // if amount is zero take the whole balance else use amount
        owner.transfer(amount == 0 ? address(this).balance : amount);
        return true;
    }

    function Balance() public view isOwner returns(uint) {
        return address(this).balance;
    }
}