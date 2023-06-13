// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



contract BinBins is ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _counter;


  address private owner;
  uint256 private totalPayments;

  struct User {
    address walletAddress;
    string name;
    string lastname;
    uint rentedBinBinId;
    uint balance;
    uint debt;
    uint start;

  }

  struct BinBin {
    uint id;
    string name;
    string imgUrl;
    Status status;
    uint rentFee;
    uint saleFee;

  }

  enum Status {
    Retired,
    InUse,
    Available
  }

  event BinBinAdded(uint indexed id, string name, string imgUrl, uint rentFee, uint saleFee);
  event BinBinMetadataEdited(uint indexed id, string name, string imgUrl, uint rentFee, uint saleFee); 
  event BinBinStatusEdited(uint indexed id, Status status);
  event UserAdded(address indexed walletAddress, string name, string lastname);
  event Deposit (address indexed walletAddress, uint amount);
  event Checkout (address indexed walletAddress, uint indexed BinBinId);
  event CheckInEvent (address indexed walletAddress, uint indexed BinBinId);
  event PaymentMade (address indexed walletAddress, uint amount);
  event Balance (address indexed walletAddress, uint amount);

  mapping (address => User) private users;
  mapping (uint => BinBin) private binbins;

  constructor() {
    owner = msg.sender;
    totalPayments = 0;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "You're not the owner");
    _;
  }

  function setOwner (address _newOwner) external onlyOwner {
    owner = _newOwner;
  }

  function addUser (string calldata name, string calldata _lastName ) external {
    require(!isUser(msg.sender) , "User already exists");
    users[msg.sender] = User(msg.sender, name, _lastName, 0, 0, 0, 0);
    emit UserAdded(msg.sender, name, _lastName);
  }

  function addBinBin ( string calldata name, string calldata url, uint rent, uint sale) external onlyOwner {
    _counter.increment();
    uint counter = _counter.current();
    binbins[counter] = BinBin(counter, name, url, Status.Available, rent, sale);

    emit BinBinAdded(counter, binbins[counter].name, binbins[counter].imgUrl, rent, sale);
  }

  function editBinBinMetadata (uint id , string calldata name, string calldata imgUrl, uint rentFee, uint saleFee) external onlyOwner {
    require(binbins[id].id != 0, "BinBin doesn't exist");
    BinBin storage binbin = binbins[id];
    if(bytes(name).length != 0) {
      binbin.name = name;
    }
    if(bytes(imgUrl).length != 0) {
      binbin.imgUrl = imgUrl;
    }
    if(rentFee != 0) {
      binbin.rentFee = rentFee;
    }
    if(saleFee != 0) {
      binbin.saleFee = saleFee;
    }

    emit BinBinMetadataEdited(id, binbin.name, binbin.imgUrl, binbin.rentFee, binbin.saleFee);
  }

  function editBinBinStatus(uint id , Status status ) external onlyOwner {
    require(binbins[id].id != 0, "BinBin doesn't exist");
    binbins[id].status = status;
    emit BinBinStatusEdited(id, status);
  }

  function checkOut(uint id) external {
    require(isUser(msg.sender), "User doesn't exist");
    require(binbins[id].status == Status.Available, "BinBin is not available");
    require(users[msg.sender].rentedBinBinId == 0, "User already has a binbin rented");
    require(users[msg.sender].debt == 0, "User has debt");

    users[msg.sender].start = block.timestamp;
    users[msg.sender].rentedBinBinId = id;
    binbins[id].status = Status.InUse;

    emit Checkout(msg.sender, id);
  }

  function CheckIn() external {
    require(isUser(msg.sender), "User doesn't exist");
    uint rentedBinBinId = users[msg.sender].rentedBinBinId;
    require(rentedBinBinId != 0, "User doesn't have a binbin rented");

    uint timeElapsed = block.timestamp - users[msg.sender].start;
    uint rentFee = binbins[rentedBinBinId].rentFee;
    users[msg.sender].debt += calculateDebt(timeElapsed, rentFee);
    users[msg.sender].rentedBinBinId = 0;
    users[msg.sender].start = 0;
    binbins[rentedBinBinId].status = Status.Available;

    emit CheckInEvent(msg.sender, rentedBinBinId);
  }

  function deposit () external payable {
    require(isUser(msg.sender), "User doesn't exist");
    require(msg.value > 0, "You must send greater than 0");
    users[msg.sender].balance += msg.value;
    emit Deposit(msg.sender, msg.value);
  }

  function makePayment () external payable {
    require(isUser(msg.sender), "User doesn't exist");
    uint debt = users[msg.sender].debt;
    uint balance = users[msg.sender].balance;
    require (debt > 0, "User doesn't have debt");
    require (balance >= debt, "User doesn't have enough balance");

    unchecked {
      users[msg.sender].debt -= msg.value;
    }

    totalPayments += msg.value;
    users[msg.sender].debt = 0;

    emit PaymentMade(msg.sender, debt);
  }

  function withdrawBalance (uint amount) external nonReentrant {
    require(isUser(msg.sender), "User doesn't exist");
    uint balance = users[msg.sender].balance;
    require(balance > amount, "You don't have enough balance");

    unchecked {
      users[msg.sender].balance -= amount;
    }

    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed.");

    emit Balance(msg.sender, balance);
  }

  function withdrawOwnerBalance (uint amount) external onlyOwner nonReentrant {
    require(totalPayments > amount, "You don't have enough balance");
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed.");
    
    unchecked {
      totalPayments -= amount;
    }
  
  }

  function getOwner () external view returns (address) {
    return owner;
  }

  function isUser(address walletAddress) private view returns (bool) {
    return users[walletAddress].walletAddress != address(0);
  }

  function getUser(address walletAddress) external view returns (User memory) {

    return users[walletAddress];
  }

  function getBinBin(uint id) external view returns (BinBin memory) {
    require(binbins[id].id != 0, "BinBindoesn't exist");
    return binbins[id];
  }

  function getBinBinByStatus(Status _status) external view returns(BinBin[] memory) {
    uint count = 0;
    uint lenght = _counter.current();
    for(uint i = 1; i <= lenght; i++) {
      if(binbins[i].status == _status) {
        count++;
      }
    }

   BinBin[] memory result = new BinBin[](count);
    count = 0;
    for(uint i = 1; i <= lenght; i++) {
      if(binbins[i].status == _status) {
        result[count] = binbins[i];
        count++;
      }
    }
    return result;
  }

  function calculateDebt(uint usedSecond, uint rentFee) private pure returns (uint) {
    uint usedMinutes = usedSecond / 60;
    return usedMinutes * rentFee;
  }

  function getCurrentCount() external view returns (uint) {
    return _counter.current();
  }

  function getBalance() external view returns (uint) {
    return address(this).balance;
  }

  function getTotalPayments() external view onlyOwner returns(uint) {
    return totalPayments;
  }

}