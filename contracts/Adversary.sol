pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./DaiInterface.sol";

contract Adversary is DaiInterface {

  using SafeMath for uint256;

  event NewOffer();
  event RemovedOffer();
  event ClaimedOffer();
  event FinalisedOffer();

  struct Offer {
    address maker;
    string currency;
    uint dai;
    uint listIndex;
  }

  struct Escrow {
    address maker;
    address taker;
    uint dai;
    uint earliestTermination;
    uint id;
    uint32 startPriceCents;
    uint32 milliMarginRatio;
    uint32 kiloMinimumPriceDeltaRatio;
  }

  uint64[] public offerIds;
  uint64[] public escrowIds;
  uint64 public currentId = 0;

  mapping (uint64 => Offer) public offers;
  mapping (uint64 => Escrow) public escrows;


  function createOffer(string _currency, uint _dai) public {
    // todo dai.transferFrom(msg.sender, self, _dai);
    offers[currentId] = Offer(msg.sender, _currency, _dai, offerIds.push(currentId) - 1);
    NewOffer();
  }

  function _deleteOffer(uint64 _offerId) internal {
    uint listIndex = offers[_offerId].listIndex;
    offerIds[listIndex] = offerIds[offerIds.length - 1];
    offerIds.length --;
    delete offers[_offerId];
    offers[offerIds[listIndex]].listIndex = listIndex;
  }

  function deleteOffer(uint64 _offerId) external {
    require(msg.sender == offers[_offerId].maker);
    _deleteOffer(_offerId);
    // todo return dai to user
    RemovedOffer();
  }
}
