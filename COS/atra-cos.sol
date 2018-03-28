pragma solidity ^0.4.19;


interface IOwnable {
	function Owner() public view returns(address owner);
}

contract AtraCos {

	mapping(address => address) public _ContractToOwner;
	address private _Owner;
	
	function AtraCos() public {
	    _Owner = msg.sender;
	    _ContractToOwner[this] = msg.sender;
	}
	
	function Owner() public view returns(address owner){
	    return _Owner;
	}

	function ClaimOwnership(address _contract) public returns(bool success){
		//load contract and access owner
		IOwnable ownership = IOwnable(_contract);
		address owner = ownership.Owner();
		require(owner == msg.sender);
		_ContractToOwner[_contract] = msg.sender;
		return true;
	}
}
