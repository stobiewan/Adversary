pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./SafeMath.sol";

contract DaiContractInterface {
  // function transferFrom(address src, address dst, uint wad) public stoppable returns (bool);  TODO is stopable required
  function transferFrom(address src, address dst, uint wad) public returns (bool);
}

contract DaiInterface is Ownable {

  DaiContractInterface contractInterface;

  // modifier onlyOwnerOf(uint _zombieId) {
  //   require(msg.sender == zombieToOwner[_zombieId]);
  //   _;
  // }

  // function setKittyContractAddress(address _address) external onlyOwner {
  //   kittyContract = KittyInterface(_address);
  // }

  // function _triggerCooldown(Zombie storage _zombie) internal {
  //   _zombie.readyTime = uint32(now + cooldownTime);
  // }

  // function _isReady(Zombie storage _zombie) internal view returns (bool) {
  //     return (_zombie.readyTime <= now);
  // }

  // function feedAndMultiply(uint _zombieId, uint _targetDna, string _species) internal onlyOwnerOf(_zombieId) {
  //   Zombie storage myZombie = zombies[_zombieId];
  //   require(_isReady(myZombie));
  //   _targetDna = _targetDna % dnaModulus;
  //   uint newDna = (myZombie.dna + _targetDna) / 2;
  //   if (keccak256(_species) == keccak256("kitty")) {
  //     newDna = newDna - newDna % 100 + 99;
  //   }
  //   _createZombie("NoName", newDna);
  //   _triggerCooldown(myZombie);
  // }

  // function feedOnKitty(uint _zombieId, uint _kittyId) public {
  //   uint kittyDna;
  //   (,,,,,,,,,kittyDna) = kittyContract.getKitty(_kittyId);
  //   feedAndMultiply(_zombieId, kittyDna, "kitty");
  // }
}

