// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
contract VotingL2 {
    // Address of L1 contract (will be set after deployment)
    address public l1ContractAddress;
    
    // Merkle root for voter verification
    bytes32 public root;
    
    // Bitmap to track which indices have been voted
    mapping(uint256 => uint256) public votedBitmap;
    
    // Candidate vote tracking
    mapping(uint256 => uint256) public candidateVotes;
    
    // Total votes to be batched
    uint256 public constant BATCH_VOTE_THRESHOLD = 1;
    
    // Current batch vote count
    uint256 public currentBatchVoteCount = 0;

    constructor(bytes32 _root) {
        root = _root;
    }

    // Set L1 contract address (can only be set once)
    function setL1ContractAddress(address _l1Address) external {
        require(l1ContractAddress == address(0), "L1 address already set");
        l1ContractAddress = _l1Address;
    }

    // Verify voter using Merkle proof
    function verify(
        bytes32[] memory proof,
        string memory voterid,
        string memory idx
    ) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(voterid, idx))));
        return MerkleProof.verify(proof, root, leaf);
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

    uint256[] private currentBatchCandidateIds;
    uint256[] private currentBatchIndices;
    // Cast a vote
    function vote(
        bytes32[] memory proof,
        string memory voterid,
        string memory idx,
        uint256 candidateId
    ) external {
        // Existing verification code...
        require(verify(proof, voterid, idx), "Invalid voter proof");
        
        uint256 index = _stringToUint(idx);
        require(!isVoted(index), "Already voted");
        
        markVoteUsed(index);
        candidateVotes[candidateId]++;
        
        // Add vote to current batch
        currentBatchCandidateIds.push(candidateId);
        currentBatchIndices.push(index);
        currentBatchVoteCount = currentBatchVoteCount + 1;
        
        if (currentBatchVoteCount >= BATCH_VOTE_THRESHOLD) {
            _submitBatchToL1();
        }
    }

    // Submit batch votes to L1
    function _submitBatchToL1() internal {
        require(currentBatchVoteCount > 0, "No votes to submit");
        require(l1ContractAddress != address(0), "L1 address not set");

        // Create memory arrays for batch data
        uint256[] memory batchCandidateIds = new uint256[](currentBatchVoteCount);
        uint256[] memory batchIndices = new uint256[](currentBatchVoteCount);

        // Copy current batch data to memory arrays
        for (uint256 i = 0; i < currentBatchVoteCount; i++) {
            batchCandidateIds[i] = currentBatchCandidateIds[i];
            batchIndices[i] = currentBatchIndices[i];
        }

        // Reset batch storage
        delete currentBatchCandidateIds;
        delete currentBatchIndices;
        currentBatchVoteCount = 0;

        // Submit to L1
        (bool success, ) = l1ContractAddress.call(
            abi.encodeWithSignature(
                "receiveBatchVotes(uint256[],uint256[])",
                batchCandidateIds,
                batchIndices
            )
        );
        require(success, "Batch submission failed");
    }

    // Utility function to convert string to uint256
    function _stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
}