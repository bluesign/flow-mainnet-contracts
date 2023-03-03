import KissoNFT from 0xc73076dd06d3b5b6
import AdminToken from 0xc73076dd06d3b5b6
import Clock from 0xc73076dd06d3b5b6
import NonFungibleToken from 0x1d7e57aa55817448

pub contract DAO {

    pub var totalProposals: UInt64

    pub event ContractInitialized()
    pub event ProposalOpened(id: UInt64)
    pub event ProposalClosed(id: UInt64)
    pub event ProposalCancelled(id: UInt64)
    pub event VotesCast(voter: Address, proposalID: UInt64, choice: UInt64)

    // key for the proposal dictionaries represents the index of total proposals
    access(account) let proposals: {UInt64: Proposal}
    access(account) var openProposalIDs: [UInt64]
    access(account) var closedProposalIDs: [UInt64]
    access(account) var cancelledProposalIDs: [UInt64]
    access(account) let ineligible: {Address: UFix64}

    pub enum Status: UInt8 {
        pub case open // icludes a proposal before voting has started
        pub case closed
        pub case cancelled
    }

    pub struct Choice {
        pub let title: String
        pub let description: String // assumed this text is unsafe, client consumers should sanitize before display
        pub var votesCount: UInt64

        pub fun incrementVotesCount(numVotes: UInt64) {
            self.votesCount = self.votesCount + numVotes
        }

        init (
            title: String,
            description: String
        ) {
            self.title = title
            self.description = description
            self.votesCount = 0
        }

    }

    pub struct Vote {
        pub let weight: UInt64
        pub let choice: UInt64

        init(
            weight: UInt64,
            choice: UInt64
        ) {
            self.weight = weight
            self.choice = choice
        }
    }

    pub struct Votes {
        pub let votes: {UInt64: Vote} // key is the uuid of a voting NFT

        pub fun castVote(nftUUID: UInt64, weight: UInt64, choice: UInt64) {
            pre {
                self.votes[nftUUID] == nil : "that NFT has already been used to vote in this proposal"
            }
            self.votes.insert(key: nftUUID, Vote(weight: weight, choice: choice))
        }

        init () {
            self.votes = {}
        }
    }

    pub struct Proposal {
        pub let creator: Address
        pub let title: String
        pub let description: String
        pub let choices: {UInt64: Choice} // key resresents the id of the choice
        pub let start: UFix64
        pub let end: UFix64
        pub var status: Status
        pub let voters: {Address: Votes}
        pub let opened: UFix64
        pub var closed: UFix64?
        pub var cancelled: UFix64?

        pub fun addVoter(address: Address) {
            self.voters.insert(key: address, Votes())
        }

        pub fun setClosed() {
            self.closed = Clock.getTime()
        }

        pub fun setCancelled() {
            self.cancelled = Clock.getTime()
        }

        pub fun markClosedStatus() {
            self.status = Status(rawValue: 1)!
            self.closed = Clock.getTime()
        }

        pub fun markCancelledStatus() {
            self.status = Status(rawValue: 2)!
            self.cancelled = Clock.getTime()
        }

        init (
            creator: Address,
            title: String,
            description: String,
            choices: {UInt64: Choice},
            start: UFix64,
            end: UFix64,
        ) {
            self.creator = creator
            self.title = title
            self.description = description
            self.choices = choices
            self.start = start
            self.end = end
            self.status = Status(rawValue: 0)!
            self.voters = {}
            self.opened = Clock.getTime()
            self.closed = nil
            self.cancelled = nil
        }
    }

    pub fun createProposal(
        nftRef: &KissoNFT.NFT, 
        nftCollectionRef: &KissoNFT.Collection{NonFungibleToken.Provider},
        title: String,
        description: String,
        choices: {UInt64: Choice},
        start: UFix64,
        end: UFix64
        ) {
        pre {
            nftRef.owner!.address == nftCollectionRef.owner!.address : "nft owner must be the same as the nft collection owner"
            start >= Clock.getTime() : "Start time cannot be in the past"
            end >= Clock.getTime() : "End time cannot be in the past"
            end > start : "End time must be later than the start time"
            DAO.ineligible[nftRef.owner!.address] == nil : "Address is not eligible for creating a proposal"
        }

        let collectionOwnerAddress = nftCollectionRef.owner!.address

        DAO.proposals.insert(key: DAO.totalProposals, Proposal(
            creator: collectionOwnerAddress,
            title: title,
            description: description,
            choices: choices,
            start: start,
            end: end
        ))
        DAO.openProposalIDs.append(DAO.totalProposals)

        emit ProposalOpened(id: DAO.totalProposals)

        DAO.totalProposals = DAO.totalProposals + UInt64(1)

    }

    pub fun castVote(proposalID: UInt64, nftCollectionRef: &KissoNFT.Collection{KissoNFT.KissoNFTCollectionPrivate, NonFungibleToken.Provider}, choice: UInt64) {
        pre {
            DAO.proposals[proposalID] != nil : "That proposal with that ID doesn't exist"
            DAO.proposals[proposalID]!.start < Clock.getTime() : "The proposal voting period has not started."
            DAO.proposals[proposalID]!.end > Clock.getTime() : "The proposal voting period has ended."
        }

        let collectionOwnerAddress = nftCollectionRef.owner!.address

        // add the voter to this proposal if they don't exist already
        if (DAO.proposals[proposalID]!.voters[collectionOwnerAddress]) == nil {
            DAO.proposals[proposalID]!.addVoter(address: collectionOwnerAddress)
        }

        let collectionOwnerVotingWeights: {UInt64: UInt64} = nftCollectionRef.getVotingWeights()

        for uuidKey in collectionOwnerVotingWeights.keys {

            let uuidVotingWeight: UInt64 = collectionOwnerVotingWeights[uuidKey]!
            // cast vote
            DAO.proposals[proposalID]!.voters[collectionOwnerAddress]!.castVote(nftUUID: uuidKey, weight: uuidVotingWeight, choice: choice)

            // increment the choices count for the proposal
            DAO.proposals[proposalID]!.choices[choice]!.incrementVotesCount(numVotes: uuidVotingWeight)

        }

        emit VotesCast(voter: collectionOwnerAddress, proposalID: proposalID, choice: choice)

    }

    pub fun getOpenProposalIDs(): [UInt64] {
        return DAO.openProposalIDs
    }

    pub fun getClosedProposalIDs(): [UInt64] {
        return DAO.closedProposalIDs
    }

    pub fun getCancelledProposalIDs(): [UInt64] {
        return DAO.cancelledProposalIDs
    }

    pub fun getProposal(proposalID: UInt64): Proposal? {
        pre {
            DAO.proposals[proposalID] != nil : "Proposal with that ID cannot be found"
        }

        return DAO.proposals[proposalID]
    }

    pub fun cancelOpenProposal(proposalID: UInt64, ref: &AdminToken.Token?) {
        pre {
            DAO.proposals[proposalID] != nil : "Proposal with that ID cannot be found"
        }

        AdminToken.checkAuthorizedAdmin(ref) // check for authorized admin

        DAO.proposals[proposalID]!.markCancelledStatus()
        let proposalIndex = DAO.openProposalIDs.firstIndex(of: proposalID)!
        let removedProposalID = DAO.openProposalIDs.remove(at: proposalIndex)
        DAO.cancelledProposalIDs.append(removedProposalID)
        
        emit ProposalCancelled(id: removedProposalID)

    }

    pub fun closeOpenProposal(proposalID: UInt64) {
        pre {
            DAO.proposals[proposalID] != nil : "Proposal with that ID cannot be found"
            DAO.proposals[proposalID]!.end <= Clock.getTime() : "The proposal open period has not yet ended."
        }

        DAO.proposals[proposalID]!.markClosedStatus()
        let proposalIndex = DAO.openProposalIDs.firstIndex(of: proposalID)!
        let removedProposalID = DAO.openProposalIDs.remove(at: proposalIndex)
        DAO.closedProposalIDs.append(removedProposalID)

        emit ProposalClosed(id: removedProposalID)

    }

    pub fun addIneligibleAddress(
        address: Address, 
        ref: &AdminToken.Token?
    ) {
        pre {
            DAO.ineligible[address] == nil : "Address is already ineligible"
        }

        AdminToken.checkAuthorizedAdmin(ref) // check for authorized admin

        DAO.ineligible.insert(key: address, Clock.getTime())
    }

    pub fun removeIneligibleAddress(
        address: Address, 
        ref: &AdminToken.Token?
    ) {
        pre {
            DAO.ineligible[address] != nil : "Cannot find address in ineligible dictionary"
        }

        AdminToken.checkAuthorizedAdmin(ref) // check for authorized admin

        DAO.ineligible.remove(key: address)
    }


    init() {
        self.totalProposals = 0
        self.proposals = {}
        self.openProposalIDs = []
        self.closedProposalIDs = []
        self.cancelledProposalIDs = []
        self.ineligible = {}

        emit ContractInitialized()
    }
}
