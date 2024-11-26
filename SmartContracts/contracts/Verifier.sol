pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Verifier {
    bytes32 private root;

    constructor(bytes32 _root) {
        root = _root;
    }

    function verify(
        bytes32[] memory proof,
        string memory voterid,
        string memory idx
    ) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(voterid,idx))));
        return MerkleProof.verify(proof, root, leaf);
    }
}