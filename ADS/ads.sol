pragma solidity^0.4.20;
/*
    Company: Atra Blockchain Services LLC
    Website: atra.io
    Author: Dillon Vincent
    Title: Address Delegate Service (ADS)
    Documentation: atra.readthedocs.io
    Date: 4/4/18
*/
interface IADS {
    function Create(string name, address currentAddress, string currentAbiLocation) public payable returns(uint newRouteId);
    
    function ScheduleUpdate(uint routeId, string routeName, uint updateRelease, address updateContractAddress, string updateAbiLocation) public returns(bool success);
    
    function Get(uint _id, string _name) public view returns(string name, address addr, string abiUrl, uint released, uint version, uint update, address updateAddr, string updateAbiUrl, uint active, address owner, uint created);
    function GetRouteIdsForOwner(address owner) public view returns(uint[] routeIds);
    
    function GetAddress(uint routeId, string routeName) public view returns(address validAddress);
    function GetAddressAndAbi(uint routeId, string routeName) public view returns(address validAddress, string abiLocation);

    function RoutesLength() public view returns(uint length);
    function NameTaken(string name) public view returns(bool);
    
    function TransferRouteOwnership(uint routeId, string routeName, address newOwner) public returns(bool success);
    function AcceptRouteOwnership(uint routeId, string routeName) public returns(bool success);
}
contract AtraOwners {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address from, address to);

    constructor() public {
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
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
}

contract ADS is IADS, AtraOwners {
    using SafeMath for uint;
    
    struct RouteData {
        string abiLocation; // url pointing to the abi json
        address contractAddress; // address pointing to an ethereum contract
    }

    struct Route {
        string name; //this will never change, used as a key
        uint updateRelease; // the epoch time when the updated contract data is released
        address owner; // address that owns/created and can modify route
        address newOwner; // used to transfer ownership
        RouteData current; // current contract data
        RouteData update; // scheduled update contract data
        uint created; //time created
        uint version; // auto increment 
        uint released; //when the last release was
    }
    
    // Declare Storage 
    uint RoutePrice = 0;
    Route[] public Routes;
    mapping(bytes32 => uint) public ContractNamesToRoutes; // (keccak256('Route Name') => routeId)
    mapping(address => uint[]) public OwnersToRoutes;
    
    //Events
    event RouteCreated(string name, address owner);
    event UpdateScheduled(string name, address owner);
    event TransferOwnership(string name, address owner, address newOwner);
    event AcceptOwnership(string name, address newOwner);

    //Constructor
    constructor() public {
        // Create padding in Routes array to be able to check for unique name in list by returning 0 for no match
        ContractNamesToRoutes[keccak256('')] = Routes.push(Route('', now, this, this, RouteData('',this), RouteData('',this), now, 0, now)) -1;
        // Register ADS to position 1 
        ContractNamesToRoutes[keccak256('ADS')] = Routes.push(Route('ADS', now, msg.sender, msg.sender, RouteData('',this), RouteData('',this), now, 0, now)) -1;
        OwnersToRoutes[msg.sender].push(1);
    }

    function Get(uint _id, string _name) public view returns(
            string name, 
            address addr, 
            string abiUrl, 
            uint released, 
            uint version, 
            uint update,  
            address updateAddr, 
            string updateAbiUrl, 
            uint active, 
            address owner, 
            uint created
        ) {
        Route memory route;
        if(bytes(_name).length > 0){
            route = Routes[ContractNamesToRoutes[keccak256(_name)]];  
        }else{
            route = Routes[_id];  
        }
        return (
            route.name, //name
            route.current.contractAddress, //addr
            route.current.abiLocation, //abi
            // if update is active the released date is when it went live, else it's the release date
            route.updateRelease < now ? route.updateRelease : route.released, //released
            //check is next contract is active, if so it's a different version add 1, else return normal version
            route.updateRelease < now ? route.version.add(1) : route.version, //version            
            // active position  will be used to determine what address to use by the client 0=current 1=next
            route.updateRelease, //update
            route.update.contractAddress, //updateAddr
            route.update.abiLocation, //updateAbi
            route.updateRelease < now ? 1 : 0, //active
            route.owner, //owner
            route.created //created 
            );
    }
    
    function GetRouteIdsForOwner(address owner) public view returns(uint[] routeIds) {
        return OwnersToRoutes[owner];
    }

    function GetAddress(uint routeId, string routeName) public view returns(address validAddress) {
        Route memory route;
        if(bytes(routeName).length > 0){
            route = Routes[ContractNamesToRoutes[keccak256(routeName)]];  
        }else{
            route = Routes[routeId];  
        }
        return route.updateRelease < now ? route.update.contractAddress : route.current.contractAddress;
    }
    
    function GetAddressAndAbi(uint routeId, string routeName) public view returns(address validAddress, string abiLocation) {
        Route memory route;
        if(bytes(routeName).length > 0){
            route = Routes[ContractNamesToRoutes[keccak256(routeName)]];  
        }else{
            route = Routes[routeId];  
        }
        return route.updateRelease < now ? (route.update.contractAddress, route.update.abiLocation) : (route.current.contractAddress, route.current.abiLocation);
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
    
    function Create(string name, address currentAddress, string currentAbiLocation) public payable returns(uint newRouteId) {
        require(msg.value == RoutePrice);
        // validate inputs
        require(bytes(name).length > 0 && bytes(name).length <= 100 && bytes(currentAbiLocation).length <= 256);
        require(ContractNamesToRoutes[keccak256(name)] == 0);
        uint routeId = Routes.push(Route(name, now, msg.sender, msg.sender, RouteData(currentAbiLocation, currentAddress), RouteData(currentAbiLocation, currentAddress),now, 0, now)) -1;
        OwnersToRoutes[msg.sender].push(routeId);
        emit RouteCreated(name, msg.sender);
        return ContractNamesToRoutes[keccak256(name)] = routeId;
    }

    function ScheduleUpdate(uint routeId, string routeName, uint updateRelease, address nextContractAddress, string nextAbiLocation) public returns(bool success) {
        //dont require name validation since we aren't storing it
        require(bytes(nextAbiLocation).length <= 256);
        Route storage route;
        if(bytes(routeName).length > 0){
            route = Routes[ContractNamesToRoutes[keccak256(routeName)]];  
        }else{
            route = Routes[routeId];  
        }
        require(route.owner == msg.sender); //require sender to be owner to update
        
        //if Next Contract Data is active do not overwrite Next data, move it to Current and increment the version
        if(route.updateRelease < now){
            route.current = route.update;
            route.released = route.updateRelease;
            route.version = route.version.add(1);
        }
        
        route.updateRelease = now.add(updateRelease);// if updateRelease is zero update will be live now
        route.update.contractAddress = nextContractAddress; // update next address
        route.update.abiLocation = nextAbiLocation; // update next abi location
        emit UpdateScheduled(route.name, msg.sender);
        return true; // return success
    }

    function TransferRouteOwnership(uint routeId, string routeName, address newOwner) public returns(bool success) {
        Route storage route;
        if(bytes(routeName).length > 0){
            route = Routes[ContractNamesToRoutes[keccak256(routeName)]];  
        }else{
            route = Routes[routeId];  
        }
        require(route.owner == msg.sender); //require sender to be owner to transfer ownership
        route.newOwner = newOwner; // set new owner
        emit TransferOwnership(route.name, msg.sender, newOwner);
        return true; // return success
    }

    function AcceptRouteOwnership(uint routeId, string routeName) public returns(bool success) {
        Route storage route;
        if(bytes(routeName).length > 0){
            routeId = ContractNamesToRoutes[keccak256(routeName)];
            route = Routes[ContractNamesToRoutes[keccak256(routeName)]];  
        }else{
            route = Routes[routeId];  
        }
        require(route.newOwner == msg.sender); //require sender to be newOwner to accecpt ownership
        
        //delete route lookup for pervious owner
        //get last routeid in array
        uint keepRouteId = OwnersToRoutes[route.owner][OwnersToRoutes[route.owner].length - 1];
        //replace routeId marked for delete
        for(uint x = 0; x < OwnersToRoutes[route.owner].length; x++){
            if(OwnersToRoutes[route.owner][x] == routeId){
                OwnersToRoutes[route.owner][x] = keepRouteId;
            }
        }
        //delete last position
        delete OwnersToRoutes[route.owner][OwnersToRoutes[route.owner].length - 1];
        //adjust array length
        OwnersToRoutes[route.owner].length--;
        
        // Add route to new owner
        route.owner = route.newOwner; // transfer ownership
        OwnersToRoutes[route.owner].push(routeId); // add lookup
        
        emit AcceptOwnership(routeName, route.owner);
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
