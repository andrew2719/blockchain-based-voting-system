// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract VotingL1 {
    // Address of L2 contract (will be set after deployment)
    address public l2ContractAddress;
    
    // Merkle root for voter verification
    bytes32 public root;
    
    // Bitmap to track which indices have been voted
    mapping(uint256 => uint256) public votedBitmap;
    
    // Candidate vote tracking
    mapping(uint256 => uint256) public candidateVotes;
    
    // Total votes to be batched
    uint256 public constant BATCH_VOTE_THRESHOLD = 10;
    
    // Current batch vote count
    uint256 public currentBatchVoteCount;

    constructor(bytes32 _root) {
        root = _root;
    }

    // Set L2 contract address (can only be set once)
    function setL2ContractAddress(address _l2Address) external {
        require(l2ContractAddress == address(0), "L2 address already set");
        l2ContractAddress = _l2Address;
    }

    // Verify if a vote index has already been used
    function isVoted(uint256 index) public view returns (bool) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        return (votedBitmap[wordIndex] & (1 << bitIndex)) != 0;
    }

    // Mark a vote as used in the bitmap
    function markVoteUsed(uint256 index) internal {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        votedBitmap[wordIndex] |= (1 << bitIndex);
    }

    // Receive batch of votes from L2
    function receiveBatchVotes(
        uint256[] memory candidateIds, 
        uint256[] memory indices
    ) external {
        // Ensure caller is the L2 contract
        require(msg.sender == l2ContractAddress, "Unauthorized");
        
        // Process each vote in the batch
        for (uint256 i = 0; i < candidateIds.length; i++) {
            require(!isVoted(indices[i]), "Index already voted");
            
            candidateVotes[candidateIds[i]]++;
            markVoteUsed(indices[i]);
        }
    }
}

