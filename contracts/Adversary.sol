pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./DaiInterface.sol";
import "./oraclizeAPI_0.5.sol";

contract Adversary is DaiTransferrer, usingOraclize {

  using SafeMath for uint256;

  event NewOffer();
  event OfferDeleted();
  event NewEscrow();
  event TradeCompleted();
  event LogPriceUpdated(string price);
  event LogNewOraclizeQuery(string description);

  struct Offer {
    address maker;
    bool makerIsLong;
    string currency;
    uint dai;
    uint listIndex;
  }

  struct PendingTake {
    address taker;
    uint64 offerId;
  }

  struct PendingClaim {
    address claimer;
    uint64 escrowId;
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

  uint public margin = 2;
  uint public daiDecimals = 18;
  uint public minimumDai = 10 ** daiDecimals;
  uint public createEscrowGasLimit = 200000;  // TODO calculate in testing
  uint public claimEscrowGasLimit = 200000;  // TODO calculate in testing
  uint64[] public offerIds;
  uint64[] public escrowIds;
  uint64 public currentId = 1;

  mapping (uint64 => Offer) public offers;
  mapping (uint64 => Escrow) public escrows;
  mapping (bytes32 => PendingTake) public pendingTakes;
  mapping (bytes32 => PendingClaim) public pendingClaims;

  function setOracleResponseGasPrice(uint priceInWei) external onlyOwner {
    oraclize_setCustomGasPrice(priceInWei);
  }

  function createOffer(bool _long, string _currency, uint _dai) public {
    require(_dai >= minimumDai);
    transferDai(msg.sender, address(this), _dai);
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
    transferDai(address(this), msg.sender, offers[_offerId].dai);
    _deleteOffer(_offerId);
  }

  function createEscrow(uint64 _offerId) public {
    if (oraclize_getPrice("URL") > address(this).balance) {
        emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
        emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        bytes32 queryId = oraclize_query("URL", strConcat("json(https://www.bitstamp.net/api/v2/ticker/",
                                         offers[_offerId].currency, "ethusd/).last"), createEscrowGasLimit);
        pendingTakes[queryId] = PendingTake(msg.sender, _offerId);
    }
  }

  function claimEscrow(uint64 _offerId) public {
    if (oraclize_getPrice("URL") > address(this).balance) {
        emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
        emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        bytes32 queryId = oraclize_query("URL", strConcat("json(https://www.bitstamp.net/api/v2/ticker/",
                                         offers[_offerId].currency, "ethusd/).last"), createEscrowGasLimit);
        pendingClaims[queryId] = PendingClaim(msg.sender, _offerId);
    }
  }

  function __callback(bytes32 myid, string result) public {
    require(msg.sender == oraclize_cbAddress());
    if(pendingTakes[myid].offerId != 0) {
      completeEscrowCreation(pendingTakes[myid], result);
    }
    else {
      if(pendingClaims[myid].escrowId != 0) {
        completeEscrowClaim(pendingClaims[myid], result);
      }
    }
    revert();
  }

  function completeEscrowCreation(PendingTake _take, string priceResult) internal {  // TODO is result a string?
    Offer memory offer = offers[_take.offerId];
    require(offer.dai > 0);
    transferDai(_take.taker, address(this), offer.dai);
    escrows[currentId] = Escrow(offer.maker, _take.taker, offer.makerIsLong, offer.currency, offer.dai * 99 / 50,
                                escrowIds.push(currentId) - 1, parseInt(priceResult, 100));  // todo str to int
    currentId++;
    _deleteOffer(_take.offerId);
    emit NewEscrow();
  }

  function completeEscrowClaim(PendingClaim _pendingClaim, string priceResult) internal {
    Escrow memory escrow = escrows[_pendingClaim.escrowId];
    require(_pendingClaim.claimer == escrow.maker || _pendingClaim.claimer == escrow.taker);
    uint finalPriceCents = parseInt(priceResult, 100);  // TODO what happens with decimal
    uint payoutForLong = (escrow.dai * ((finalPriceCents - escrow.startPriceCents) * margin + escrow.startPriceCents)) /
                         (2 * escrow.startPriceCents);
    uint payoutForShort = escrow.dai - payoutForLong;
    if(escrow.makerIsLong) {
      transferDai(address(this), escrow.maker, payoutForLong);
      transferDai(address(this), escrow.taker, payoutForShort);
    }
    else {
      transferDai(address(this), escrow.maker, payoutForShort);
      transferDai(address(this), escrow.taker, payoutForLong);
    }
    /* TODO delete escrow item in map and array and make sure same for offers. */
    emit TradeCompleted();
  }
}
