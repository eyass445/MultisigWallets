// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.14;

interface IMultiSig {

    // Defining the Transaction struct
    struct Transaction {
        address from;               // Address that submitted the transaction
        address executed;           // Address that executed the transaction
        uint256 numConfirmations;   // Number of confirmations for the transaction
        string functionName;        // Name of the function to be executed in the transaction
        bytes data;                 // Data to be passed to the function
        address[] confirmed;        // Array of addresses that confirmed the transaction
        uint256 createdAt;          // Timestamp when the transaction was created
        uint256 updatedAt;          // Timestamp when the transaction was last updated
    }

    // Defining events for submitting, confirming, and executing transactions
    event SubmitTransaction(address indexed from, uint256 indexed transactionId); 
    event ConfirmTransaction(address indexed from, uint256 indexed transactionId);
    event ExecuteTransaction(address indexed from, uint256 indexed transactionId);

    // Function to get the list of owners
    function getOwners() external view returns (address[] memory);

    // Function to confirm a transaction
    function confirmTransaction(uint256 _transactionId) external;
    
    // Function to execute a transaction
    function executeTransaction(uint256 _transactionId) external  ;

    // Function to get the details of a transaction
    function getTransaction (uint256 _transactionId) external view returns (Transaction memory transactions_);

    // Function to get all transactions with pagination
    function getAllTransactions (uint256 _pageNo, uint256 _perPage) external view returns (Transaction [] memory transactions_, uint256 totalList_);

}