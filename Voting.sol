// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.12;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
contract Voting is Ownable{
    struct Voter{
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal{
        string description;
        uint voteCount;
    }

    enum WorkflowStatus{
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    enum resultStatus{
        notStarted,
        equality,
        finish
    }

    WorkflowStatus public status;
    resultStatus public unanimity;
    uint winningProposalId;
    mapping(address => Voter) whitelist;
    Proposal[] public Proposals;


    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    //MODIFIERS

    modifier registering(){
        require(status == WorkflowStatus.RegisteringVoters, "Not possible now");
        _;
    }

    modifier proposalsRegistering(){
        require(status == WorkflowStatus.ProposalsRegistrationStarted, "Not possible now");
        _;
    }

    modifier proposalsRegisteringEnded(){
        require(status == WorkflowStatus.ProposalsRegistrationEnded, "Not possible now");
        _;
    }

    modifier voting(){
        require(status == WorkflowStatus.VotingSessionStarted, "Not possible now");
        _;
    }

    modifier votingClose(){
        require(status == WorkflowStatus.VotingSessionEnded, "Not possible now");
        _;
    }

    modifier voteDisplaying(){
        require(status == WorkflowStatus.VotesTallied, "Not possible now");
        _;
    }

    modifier onlyRegistred(){
        require(whitelist[msg.sender].isRegistered == true, "Sorry, you're not allowed to vote");
        _;
    } 

    //STATUS CHANGING FUNCTIONS

    function startProposalsRegistering()external onlyOwner registering{
        status = WorkflowStatus.ProposalsRegistrationStarted;
    }

    function endProposalsRegistering()external onlyOwner proposalsRegistering{
        status = WorkflowStatus.ProposalsRegistrationEnded;
    }

    function startVotingSession()external onlyOwner proposalsRegisteringEnded{
        status = WorkflowStatus.VotingSessionStarted;
    }

    function endVotingSession()external onlyOwner voting{
        status = WorkflowStatus.VotingSessionEnded;
    }

    function displayVotes()external onlyOwner votingClose returns(bool){
        status = WorkflowStatus.VotesTallied;
        countVotes();
        if(unanimity == resultStatus.finish){
            return true;
        }
            return false;

    }

    function newCycle()external onlyOwner voteDisplaying{
        status = WorkflowStatus.RegisteringVoters;
    }

    /*
        only owner can add someone to the whitelist, and only during the registering step
    */
    function register(address _address)external onlyOwner registering {
        whitelist[_address].isRegistered = true;
    }

    function propose(string memory _description)external onlyRegistred proposalsRegistering{
        Proposal memory p = Proposal(_description, 0);
        Proposals.push(p);
    }

    function vote(uint id)external onlyRegistred voting{
        require(whitelist[msg.sender].hasVoted == false, "You can't vote twice");
        whitelist[msg.sender].hasVoted = true;
        whitelist[msg.sender].votedProposalId = id;
        Proposals[id].voteCount += 1;
    }

    function countVotes()private returns(uint, uint){
        uint tmp;
        uint index; //index of the winner
        for(uint i; i < Proposals.length; i++){
            if(Proposals[i].voteCount > tmp){                       //find the higher countVote
                tmp = Proposals[i].voteCount;
                index = i;
            }
        }
        uint count;
        for (uint j; j < Proposals.length; j++){
            if(tmp == Proposals[j].voteCount){                      //Check if there is not equality
                count ++;
            }
        }
        if(count > 1){
            unanimity = resultStatus.equality; 
        }

        return(index, tmp);
    }
    
    //DEVELOPPEMENT

    function countProposals()external view returns(uint){
        return Proposals.length;
    }
}