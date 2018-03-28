pragma solidity ^0.4.19;

// What do we want out of the owner contract?
// set ourself of the owner of a contract
// transfer ownership of contract

interface IAtraCos {
	function SetOwnerOfContract() public returns(bool);
}