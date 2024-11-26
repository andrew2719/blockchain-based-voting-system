import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// Load the tree
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json", "utf8")));

// Find the proof for a given voter
const voter = "voter1";
let proof;

for (const [i, v] of tree.entries()) {
  if (v[0] === voter) {
    proof = tree.getProof(i);
    break;
  }
}

console.log('Value:', [voter]);
console.log('Proof:', proof);