// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.14;

interface IMultiSig {

    struct Transaction {
        address from;
        address executed;
        uint256 numConfirmations;
        string functionName;
        bytes data;
        address[] confirmed;
        uint256 createdAt;
        uint256 updatedAt;
    }

    event SubmitTransaction(address indexed from, uint256 indexed transactionId); 
    event ConfirmTransaction(address indexed from, uint256 indexed transactionId);
    event ExecuteTransaction(address indexed from, uint256 indexed transactionId);

    function getOwners() external view returns (address[] memory);

    function confirmTransaction(uint256 _transactionId) external;
    
    function executeTransaction(uint256 _transactionId) external;

    function getTransaction (uint256 _transactionId) external view returns (Transaction memory transactions_);

    function getAllTransactions (uint256 _pageNo, uint256 _perPage) external view returns (Transaction [] memory transactions_, uint256 totalList_);

}