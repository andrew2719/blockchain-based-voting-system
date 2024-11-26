import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// Voters
const values = [
  ["voter1","1"],
  ["voter2","2"],
  ["voter3","3"],
  ["voter4","4"]
];

// Generate the Merkle tree
const tree = StandardMerkleTree.of(values, ["string","string"]);

// Output the Merkle root
console.log('Merkle Root:', tree.root);

// Save the tree to a file
fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));