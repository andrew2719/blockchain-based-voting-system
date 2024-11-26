import ape
import json
import pytest

@pytest.fixture
def tree_data():
    """Fixture to load Merkle tree data"""
    with open("/home/andrew/coding/blockchain/voting-system/Merkle_tree_prep/tree.json", "r") as file:
        return json.load(file)

@pytest.fixture
def root(tree_data):
    """Fixture to extract Merkle root"""
    return tree_data["tree"][0]

@pytest.fixture
def proof():
    """Fixture for Merkle proof"""
    return [
        '0xfccdaed3a18014f43ad247c914bbd321ae0639602581dc8a3dbef3745f02f66f',
        '0xbc567dddfbabf1934786ee4904760ba9b1949e2f8ab9f015133ec2a5affbdfec'
    ]

@pytest.fixture
def voter_details():
    """Fixture for voter details"""
    return {
        "voter": "voter1",
        "idx": "1"
    }

@pytest.fixture
def candidate_ids():
    """Fixture for candidate IDs"""
    return [1, 2, 3]

@pytest.fixture
def l2_contract(root):
    """Fixture to deploy L2 contract"""
    account = ape.accounts.test_accounts[0]
    return account.deploy(ape.project.VotingL2, root)

@pytest.fixture
def l1_l2_contracts(root):
    """Fixture to deploy and link L1 and L2 contracts"""
    account = ape.accounts.test_accounts[0]
    
    # Deploy contracts
    l1_contract = account.deploy(ape.project.VotingL1, root)
    l2_contract = account.deploy(ape.project.VotingL2, root)
    
    # Set cross-contract addresses
    l1_contract.setL2ContractAddress(l2_contract.address, sender=account)
    l2_contract.setL1ContractAddress(l1_contract.address, sender=account)
    
    return l1_contract, l2_contract

def test_verify(l2_contract, proof, voter_details):
    """Test Merkle proof verification"""
    verification_passed = l2_contract.verify(
        proof, 
        voter_details["voter"], 
        voter_details["idx"], 
        sender=ape.accounts.test_accounts[0]
    )
    assert verification_passed == True

def test_voting_process(l1_l2_contracts, proof, voter_details, candidate_ids):
    """Test complete voting process"""
    _, l2_contract = l1_l2_contracts
    voter_account = ape.accounts.test_accounts[1]
    
    # Ensure the voter can only vote once total
    l2_contract.vote(
        proof, 
        voter_details["voter"], 
        voter_details["idx"], 
        candidate_ids[0], 
        sender=voter_account
    )
    
    # Subsequent votes should fail, regardless of candidate
    with pytest.raises(Exception, match="Already voted"):
        l2_contract.vote(
            proof, 
            voter_details["voter"], 
            voter_details["idx"], 
            candidate_ids[1], 
            sender=voter_account
        )

def test_prevent_double_voting(l1_l2_contracts, proof, voter_details):
    l1_contract, l2_contract = l1_l2_contracts
    """Test prevention of double voting"""
    voter_account1 = ape.accounts.test_accounts[1]
    voter_account2 = ape.accounts.test_accounts[2]
    
    # Initial state checks
    assert l2_contract.candidateVotes(1) == 0
    assert not l2_contract.isVoted(int(voter_details["idx"]))
    
    # First vote should succeed
    tx1 = l2_contract.vote(
        proof, 
        voter_details["voter"], 
        voter_details["idx"], 
        1, 
        sender=voter_account1
    )
    
    # Verify first vote was recorded
    assert l2_contract.candidateVotes(1) == 1
    assert l2_contract.isVoted(int(voter_details["idx"]))
    # Remove this assertion since batch is automatically submitted
    # assert l2_contract.currentBatchVoteCount() == 1
    
    # Verify vote was recorded on L1
    assert l1_contract.candidateVotes(1) == 1
    
    # Second vote should fail (same index)
    with pytest.raises(Exception, match="Already voted"):
        l2_contract.vote(
            proof, 
            voter_details["voter"], 
            voter_details["idx"], 
            2, 
            sender=voter_account2
        )
    
    # Verify state hasn't changed after failed vote
    assert l2_contract.candidateVotes(1) == 1
    assert l2_contract.candidateVotes(2) == 0
    assert l2_contract.currentBatchVoteCount() == 0  # Batch was submitted

def test_batch_vote_submission(l1_l2_contracts, root, candidate_ids):
    """Test batch vote submission to L1 with threshold of 1"""
    l1_contract, l2_contract = l1_l2_contracts
    
    # Choose a single candidate
    candidate_id = candidate_ids[0]
    
    # Use the standard proof 
    proof = [
        '0xfccdaed3a18014f43ad247c914bbd321ae0639602581dc8a3dbef3745f02f66f',
        '0xbc567dddfbabf1934786ee4904760ba9b1949e2f8ab9f015133ec2a5affbdfec'
    ]
    
    # Vote on L2
    l2_contract.vote(
        proof, 
        "voter1", 
        "1", 
        candidate_id, 
        sender=ape.accounts.test_accounts[1]
    )
    
    # Check that batch submission occurred
    assert l2_contract.currentBatchVoteCount() == 0
    
    # Verify vote was recorded on L1
    assert l1_contract.candidateVotes(candidate_id) == 1

def test_address_setting_restrictions(root):
    """Test that contract addresses can only be set once"""
    account = ape.accounts.test_accounts[0]
    
    # Deploy L1 contract
    l1_contract = account.deploy(ape.project.VotingL1, root)
    
    # First setting should succeed
    l1_contract.setL2ContractAddress(ape.accounts.test_accounts[1].address, sender=account)
    
    # Second setting should fail
    with pytest.raises(Exception):
        l1_contract.setL2ContractAddress(ape.accounts.test_accounts[2].address, sender=account)