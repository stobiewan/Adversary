pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./DaiInterface.sol";

contract Adversary is DaiInterface {

  using SafeMath for uint256;

  event NewOffer();
  event OfferDeleted();
  event NewEscrow();
  event TradeCompleted();

  struct Offer {
    address maker;
    bool makerIsLong;
    string currency;
    uint dai;
    uint listIndex;
  }

  struct Escrow {
    address maker;
    address taker;
    bool makerIsLong;
    string currency;
    uint dai;
    uint listIndex;
    uint startPriceCents;
  }

  uint margin = 2;
  uint64[] public offerIds;
  uint64[] public escrowIds;
  uint64 public currentId = 1;
  uint64 public minimumDai = 10;  // todo what are dai units? 10^18 == 1?

  mapping (uint64 => Offer) public offers;
  mapping (uint64 => Escrow) public escrows;


  function createOffer(bool _long, string _currency, uint _dai) public {
    require(_dai >= minimumDai);
    // todo dai.transferFrom(msg.sender, self, _dai);
    offers[currentId] = Offer(msg.sender, _long, _currency, _dai, offerIds.push(currentId) - 1);
    currentId++;
    emit NewOffer();
  }

  function _deleteOffer(uint64 _offerId) internal {
    uint listIndex = offers[_offerId].listIndex;
    offerIds[listIndex] = offerIds[offerIds.length - 1];
    offerIds.length --;
    delete offers[_offerId];
    offers[offerIds[listIndex]].listIndex = listIndex;
    emit OfferDeleted();
  }

  function deleteOffer(uint64 _offerId) external {
    require(msg.sender == offers[_offerId].maker);
    _deleteOffer(_offerId);
    // todo return dai to user
  }

  function createEscrow(uint64 _offerId) public {
    Offer memory offer = offers[_offerId];
    require(offer.dai >= minimumDai);
    // todo dai.transferFrom(msg.sender, self, offer.dai);
    uint startPriceCents = 10000;
    escrows[currentId] = Escrow(offer.maker, msg.sender, offer.makerIsLong, offer.currency, offer.dai * 199 / 100,
                                escrowIds.push(currentId) - 1, startPriceCents);
    currentId++;
    _deleteOffer(_offerId);
    emit NewEscrow();
  }

  function claimEscrow(uint64 _escrowId) public {
    Escrow memory escrow = escrows[_escrowId];
    require(msg.sender == escrow.maker || msg.sender == escrow.taker);
    uint finalPriceCents = 12500;
    uint payoutForLong = (escrow.dai * ((finalPriceCents - escrow.startPriceCents) * margin + escrow.startPriceCents)) /
                         (2 * escrow.startPriceCents);
    uint payoutForShort = escrow.dai - payoutForLong;
    if(escrow.makerIsLong) {
      payDai(escrow.maker, payoutForLong);
      payDai(escrow.taker, payoutForShort);
    }
    else {
      payDai(escrow.taker, payoutForLong);
      payDai(escrow.maker, payoutForShort);
    }
    emit TradeCompleted();
  }
}
