pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./SafeMath.sol";

contract DaiInterface {
  // function transferFrom(address src, address dst, uint wad) public stoppable returns (bool);  TODO is stopable required
  function transferFrom(address src, address dst, uint wad) public returns (bool);
}

contract DaiTransferrer is Ownable {

  DaiInterface daiContract;

  function transferDai(address _src, address _dst, uint _dai) internal {
    bool success = daiContract.transferFrom(_src, _dst, _dai);
  }

  function setDaiContractAddress(address _address) external onlyOwner {
    daiContract = DaiInterface(_address);
  }
}
