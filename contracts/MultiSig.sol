// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.14;

import "./interfaces/IMultiSig.sol";
import "./lib/SafeMath.sol";

abstract contract MultiSig is IMultiSig {

    using SafeMath for uint256;

    address [] private ownerList;
    mapping(address => bool) private ownerMap;

    uint256 private transactionIncrement;
    mapping(uint256 => Transaction) internal transactionMap;

    mapping(uint256 => mapping(address => bool)) private transactionAddressConfirmedMap;

    uint256 private numConfirmationsRequired;

    /////////////////////////////// Start Modifiers ///////////////////////////////

    // Start Modifiers

    // Modifier to check if the sender is an owner
    modifier onlyOwner() {
        require(ownerMap[msg.sender], "not owner");
        _;
    }

    // Modifier to check if the transaction exists
    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId > 0 && _transactionId <= transactionIncrement, "Transaction does not exist");
        _;
    }

    // Modifier to check if the transaction has not been executed
    modifier notExecuted(uint256 _transactionId) {
        require(transactionMap[_transactionId].executed == address(0), "Transaction already executed");
        _;
    }

    // Modifier to check if the transaction has not been confirmed by the sender
    modifier notConfirmed(uint256 _transactionId) {
        require(!transactionAddressConfirmedMap[_transactionId][msg.sender], "Transaction already confirmed");
        _;
    }

    /////////////////////////////// End Modifiers ///////////////////////////////

    // End Modifiers

    // Constructor to initialize the contract with owners and the required number of confirmations
    constructor(address [] memory _owners, uint256 _numConfirmationsRequired) {

        require (_numConfirmationsRequired > 1 , "The Number of confirmations required must be greater than one");
        require (_owners.length >= _numConfirmationsRequired , "The number of owners must be greater than or equal to the number of confirmations required");

        transactionIncrement = 0;
        numConfirmationsRequired = _numConfirmationsRequired;
        addOwners(_owners);
    }

    // Internal function to add owners to the contract
    function addOwners(address[] memory _owners) internal {
        
        for (uint256 i = 0 ; i < _owners.length ; i = i.add(1)) {

            require (_owners[i] != address(0) , "Zero address not Allowed");
            require (!ownerMap[_owners[i]] , "The Owner not unique");

            ownerMap[_owners[i]] = true;
            ownerList.push(_owners[i]);
        }

    }
    // Function to get the list of owners
    function getOwners() external view returns (address[] memory) {
        return ownerList;
    }

    // Internal function to submit a transaction
    function submitTransaction(address _sender, string memory _functionName, bytes memory _data) internal returns (uint256 _transactionId) {
    
        require (_sender != address(0) , "Zero address not Allowed");
	    require(bytes(_functionName).length > 0, "The Function name is required");
	    require(_data.length > 0, "The Data is required");

        transactionIncrement = transactionIncrement.add(1);
    
        transactionMap[transactionIncrement].from           = _sender;
        transactionMap[transactionIncrement].executed       = address(0);
        transactionMap[transactionIncrement].functionName   = _functionName;
        transactionMap[transactionIncrement].data           = _data;
        transactionMap[transactionIncrement].createdAt      =  block.timestamp;
        transactionMap[transactionIncrement].updatedAt      =  block.timestamp;

        emit SubmitTransaction (_sender, transactionIncrement);

        return transactionIncrement;
    }
    // Function to confirm a transaction
    function confirmTransaction(uint256 _transactionId) external onlyOwner 
        transactionExists(_transactionId) 
        notExecuted(_transactionId) 
        notConfirmed(_transactionId) {

        transactionMap[_transactionId].confirmed.push(msg.sender);
        transactionMap[_transactionId].numConfirmations = transactionMap[_transactionId].numConfirmations.add(1);
        transactionAddressConfirmedMap[_transactionId][msg.sender] = true;
        transactionMap[_transactionId].updatedAt = block.timestamp;

        emit ConfirmTransaction(msg.sender, _transactionId);
    }
    // Function to execute a transaction
    function executeTransaction(uint256 _transactionId) external  onlyOwner transactionExists(_transactionId) 
        notExecuted(_transactionId) {

        require(transactionMap[_transactionId].numConfirmations >= numConfirmationsRequired, "cannot execute tx");

        transactionMap[_transactionId].executed = msg.sender;
        transactionMap[_transactionId].updatedAt = block.timestamp;

        executeFunction(_transactionId);
        
        emit ExecuteTransaction(msg.sender, _transactionId);
    }
    // Function to get the details of a transaction
    function getTransaction (uint256 _transactionId) external onlyOwner view returns (Transaction memory transactions_) {
        return transactionMap[_transactionId];
    }
    // Function to get all transactions with pagination
    function getAllTransactions (uint256 _pageNo, uint256 _perPage) external onlyOwner view returns (Transaction [] memory transactions_, uint256 totalList_) {
        require((_pageNo.mul(_perPage)) <= transactionIncrement, "Page is Out of Range");
        uint256 no_transaction = (transactionIncrement.sub(_pageNo.mul(_perPage))) < _perPage ?
        (transactionIncrement.sub(_pageNo.mul(_perPage))) : _perPage;
        Transaction[] memory transactions = new Transaction[](no_transaction);
        for (uint256 i = 0; i < transactions.length; i= i.add(1)) {
            transactions[i] = transactionMap[(_pageNo.mul(_perPage)) + (i.add(1))];
        }
        return (transactions, transactionIncrement);
    }
    // Internal function to execute the function specified in the transaction
    function executeFunction (uint256 _transactionId) internal virtual returns (bytes memory);
}