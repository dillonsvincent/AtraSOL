pragma solidity ^0.4.19;

// Allow owner to create route for contract
// Ask contract if sender is owner
// Use interface of contract to get owner

// Update route if route owner sends request

// Get address for a routeid


interface IAtraAds {
	function CreateRoute(address route) public returns(uint routeId);
}