pragma solidity^0.4.20;

interface Logic {
	function Calc(uint num1, uint num2) external view returns(uint result);
}

contract AtraExmapleLogic is Logic{
	function Calc(uint num1, uint num2) external view returns(uint result) {
	    return num1 + num2;
	}
}