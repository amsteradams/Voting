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
    //Used to check if there is an equality, stay at not started until the last voting state *
    enum resultStatus{
        notStarted,
        equality,
        finish
    }

    WorkflowStatus public status; //vote state
    resultStatus public unanimity; // *
    address[] public Voters; //Used to restart whitelist's vote if admin choose to restart voting due to an equality
    uint winningProposalId;
    uint amountWinning; //Amount of vote for the winning proposal
    mapping(address => Voter) whitelist;
    Proposal[] public Proposals;


    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus indexed previousStatus, WorkflowStatus indexed newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    //MODIFIERS

    /*
        Check if actual voting state is 'registeringVoters'
    */
    modifier registering(){
        require(status == WorkflowStatus.RegisteringVoters, "Not possible now");
        _;
    }

    /*
        Check if actual voting state is 'ProposalsRegistrationStarted'
    */
    modifier proposalsRegistering(){
        require(status == WorkflowStatus.ProposalsRegistrationStarted, "Not possible now");
        _;
    }

    /*
        Check if actual voting state is 'ProposalsRegistrationEnded'
    */
    modifier proposalsRegisteringEnded(){
        require(status == WorkflowStatus.ProposalsRegistrationEnded, "Not possible now");
        _;
    }

    /*
        Check if actual voting state is 'VotingSessionStarted'
    */
    modifier voting(){
        require(status == WorkflowStatus.VotingSessionStarted, "Not possible now");
        _;
    }

    /*
        Check if actual voting state is 'VotingSessionsEnded'
    */
    modifier votingClose(){
        require(status == WorkflowStatus.VotingSessionEnded, "Not possible now");
        _;
    }

    /*
        Check if actual voting state is 'VotesTallied'
    */
    modifier voteDisplaying(){
        require(status == WorkflowStatus.VotesTallied, "Not possible now");
        _;
    }

    /*
        Check if msg.sender is regitered
    */
    modifier onlyRegistred(){
        require(whitelist[msg.sender].isRegistered == true, "Sorry, you're not allowed to vote");
        _;
    } 

    //STATUS CHANGING FUNCTIONS

    /*
        change voting state REGISTERING to PROPOSALS REGISTRATION STARTED
    */
    function startProposalsRegistering()external onlyOwner registering{
        status = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /*
        change voting state PROPOSALS REGISTRATION STARTED to PROPOSALS REGISTRATION ENDED
    */
    function endProposalsRegistering()external onlyOwner proposalsRegistering{
        status = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /*
        change voting state PROPOSALS REGISTRATION ENDED to VOTING SESSION STARTED
    */
    function startVotingSession()external onlyOwner proposalsRegisteringEnded{
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /*
        change voting state VOTING SESSIONS STARTED to VOTING SESSION ENDED
    */
    function endVotingSession()external onlyOwner voting{
        status = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /*
        -change voting state to VOTING TALLIED
        -set winner and the amount of vote he gets
        -if there is not equality return true, else return false
    */
    function displayVotes()external onlyOwner votingClose returns(bool){
        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
        (winningProposalId, amountWinning) = countVotes();
        if(unanimity == resultStatus.finish){
            return true;
        }
            return false;
    }

    /*
        -this function is only usable if resultStatus is on 'equality'
        -restart voting but keep all proposals
        -change voting state to VOTING SESSIONS STARTED
    */
    function retry()external onlyOwner voteDisplaying{
        require(unanimity == resultStatus.equality, "Sorry, democraty talks");
        for(uint i; i < Proposals.length; i++){
            Proposals[i].voteCount =0;
        }
        for(uint j; j < Voters.length; j++){
            whitelist[Voters[j]].hasVoted = false;
            whitelist[Voters[j]].votedProposalId = 0;
        }
        winningProposalId = 0;
        amountWinning = 0;
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.VotesTallied, WorkflowStatus.VotingSessionStarted);
    }

    /*
        -this function is only usable if voting state is VOTES TALLIED
        -reset everything
    */
    function newCycle()external onlyOwner voteDisplaying{
        status = WorkflowStatus.RegisteringVoters;
        emit WorkflowStatusChange(WorkflowStatus.VotesTallied, WorkflowStatus.RegisteringVoters);
        winningProposalId = 0;
        amountWinning = 0;
        delete Proposals;
        for(uint j; j < Voters.length; j++){
            whitelist[Voters[j]].isRegistered = false;
            whitelist[Voters[j]].hasVoted = false;
            whitelist[Voters[j]].votedProposalId = 0;
        }
        delete Voters;
        unanimity = resultStatus.notStarted;
    }

    /*
        admin register someone
    */
    function register(address _address)external onlyOwner registering {
        for(uint i; i<Voters.length; i++){
            if(Voters[i] == _address){
                revert();                               //Mean that _address is already regitered
            }
        }
        whitelist[_address].isRegistered = true;
        Voters.push(_address);
        emit VoterRegistered(_address);
    }

    /*
        regitered address add proposal
    */
    function propose(string memory _description)external onlyRegistred proposalsRegistering{
        Proposal memory p = Proposal(_description, 0);
        Proposals.push(p);
    }

    /*
        registered address vote for a proposal
    */
    function vote(uint id)external onlyRegistred voting{
        require(whitelist[msg.sender].hasVoted == false, "You can't vote twice");
        whitelist[msg.sender].hasVoted = true;
        whitelist[msg.sender].votedProposalId = id;
        Proposals[id].voteCount += 1;
        emit Voted(msg.sender, id);
    }

    /*
        first check the winner
        check if there is another proposal with the same vote amount
        set unanimity 
        return index of the winning proposal and the vote amount
    */
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
            if(tmp == Proposals[j].voteCount){                      //Check if there is equality
                count ++;
            }
        }
        if(count > 1){
            unanimity = resultStatus.equality; 
        }
        else{
            unanimity = resultStatus.finish;
        }

        return(index, tmp);
    }

    //GETTERS

    /*
        Display the winning proposal id with its vote amount
        Everybody can see it, not only registered
    */
    function result()external view voteDisplaying returns(uint, uint){
        return (winningProposalId, amountWinning);
    }

    /*
        Return true if there is no equality
    */
    function Unanimity()external view voteDisplaying returns(bool){
        if(unanimity == resultStatus.finish){
            return true;
        }
            return false;
    }

    /*
        return abstentionism (%)
    */
    function seeAbstention()external view voteDisplaying returns(uint){
        uint count;
        for(uint i; i<Voters.length; i++){
            if(whitelist[Voters[i]].hasVoted == false){
                count ++;
            }
        }
        return ((count * 100) / Voters.length);
    }

    /*
        return voting state
    */
    function seeCycleStatus()external view returns(WorkflowStatus){
        return status;
    }
    
    /*
        return Voter information
    */
    function seeVoter(address _address)external view returns(Voter memory){
        return whitelist[_address];
    }

    /*
        return amount of proposals
    */
    function countProposals()external view returns(uint){
        return Proposals.length;
    }
}