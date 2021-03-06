pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract Welandam is Ownable {

  event OrderRecorded(bytes16 indexed id, bytes32 indexed itemId, uint64 amount);
  event OrderConfirmed(bytes16 indexed id, bytes32 indexed itemId, address by);
  event OrderExpired(bytes16 indexed id, bytes32 indexed itemId);

  mapping(bytes16 => Order) public orders;

  constructor() public {
    owner = msg.sender;
  }

  struct Order {
    bytes16 id;
    bytes32 itemId;
    // original amount in USD
		uint64 amount;
    // amount payable in ether
		uint256 amountEther;
    // TODO decide on exactly how we can handle any number of relayers while also encouraging
    // all the network participants to relay everyone elses orders
    // TODO This is a key problem that differentiates welandam from 0x since in 0x, in order to share liquidity for exchange orders there is a natural incentive for relayers to share maker orders
    address[] relayers;
    address shipper;
    address merchant;
    address customer;
    uint256 expirationBlock;
    uint8 status; // 1:Requested, 2:Delivered, 3: Expired
  }

  modifier allowedToConfirm(bytes16 _id) {
    require(orders[_id].id != 0x0);
    require(orders[_id].shipper == msg.sender);
    _;
  }

  modifier allowedToUnlock(bytes16 _id) {
    require(orders[_id].id != 0x0);
    bool foundRelayer = false;
    for (uint i = 0; i < orders[_id].relayers.length; i++) {
      if (orders[_id].relayers[i] == msg.sender) {
        foundRelayer = true;
      }
    }
    require(foundRelayer || orders[_id].shipper == msg.sender);
    _;
  }

  function getRelayersPerOrderId(bytes16 _id) public view returns (address[]) {
    return orders[_id].relayers;
  }

  function recordOrder(
		bytes16 _id,
		bytes32 _itemId,
		uint64 _amount,
		uint256 _amountEther,
		address[] _relayers,
		address _shipper,
		address _merchant,
		address _customer,
		uint256 _maxBlocks
	) public payable {
    require(orders[_id].id == 0x0);
    require(_amountEther == msg.value);
    orders[_id] = Order(_id, _itemId, _amount, _amountEther, _relayers, _shipper, _merchant, _customer, block.number + _maxBlocks, 1);
		emit OrderRecorded(_id, _itemId, _amount);
  }

  function confirmOrder(bytes16 _id) public allowedToConfirm(_id) {
    unlockFundsForOrder(_id);
  }

  function unlockFundsForOrder(bytes16 _id) public allowedToUnlock(_id) {
    require(orders[_id].status == 1);
    if (orders[_id].expirationBlock < block.number) {
      orders[_id].status = 3;
      orders[_id].customer.transfer(orders[_id].amountEther);
			emit OrderExpired(_id, orders[_id].itemId);
    } else if (msg.sender == orders[_id].shipper) {
      orders[_id].merchant.transfer(orders[_id].amountEther);
      orders[_id].status = 2;
			emit OrderConfirmed(_id, orders[_id].itemId, orders[_id].shipper);
    }
  }

  function checkLockedOrder(bytes16 _id) public allowedToUnlock(_id) {
    if (orders[_id].expirationBlock < block.number) {
      orders[_id].status = 3;
      orders[_id].customer.transfer(orders[_id].amountEther);
			emit OrderExpired(_id, orders[_id].itemId);
    }
  }


}
