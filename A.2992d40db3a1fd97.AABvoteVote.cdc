import AABvoteNFT from 0x2992d40db3a1fd97

pub contract AABvoteVote {
    pub let votes: {Address: [Vote]}
    pub let star: {Address: UInt}
    pub var allowVote: Bool

    pub event NewVote(voter: Address, candidateId: String, nfts: [UInt64], star: UInt64)

    pub let AdminVoteStoragePath: StoragePath
    pub let AdminStoragePath: StoragePath

    pub enum Level: UInt8 {
        pub case diamond
        pub case platinum
        pub case gold
        pub case silver
    }

    pub fun levelToStar(_ level: Level): UInt64 {
        switch level {
            case Level.diamond:
                return 1500
            case Level.platinum:
                return 1000
            case Level.gold:
                return 500
            case Level.silver:
                return 20
        }

        return 0
    }

    pub struct Vote {
        pub let candidateId: String
        pub let nfts: [UInt64]
        pub let star: UInt64

        init(candidateId: String, nfts: [UInt64], star: UInt64) {
            self.candidateId = candidateId
            self.nfts = nfts
            self.star = star
        }
    }

    pub fun rarityToStar(rarity: UInt8, amount: Int): UInt64 {
        if rarity == AABvoteNFT.Rarity.common.rawValue && amount == 1 {
            return AABvoteVote.levelToStar(Level.silver)
        }

        if rarity == AABvoteNFT.Rarity.common.rawValue && amount == 3 {
            return AABvoteVote.levelToStar(Level.gold)
        }

        if rarity == AABvoteNFT.Rarity.iconic.rawValue && amount == 2 {
            return AABvoteVote.levelToStar(Level.platinum)
        }

        if rarity == AABvoteNFT.Rarity.iconic.rawValue && amount == 3 {
            return AABvoteVote.levelToStar(Level.diamond)
        }

        return 0
    }

    pub resource AdminVote {
        pub fun vote(voter: Address, candidateId: String, nfts: [UInt64], type: UInt8) {
            pre {
                voter != nil: "Invalid voter"
                candidateId != nil: "Cannot vote for a category that doesn't exist"
                nfts.length > 0 && nfts.length <= 3 : "Nfts length must be greater than 0 and less than 4"
            }

            if !AABvoteVote.allowVote {
                panic("Now unable to vote. Please try again!")
            }

            let rarityCond: {UInt8: Int} = { AABvoteNFT.Rarity.common.rawValue: 0, AABvoteNFT.Rarity.iconic.rawValue: 0 }
            let votes = (AABvoteVote.votes[voter] ?? [])

            for nft in nfts {
                let NFT = AABvoteNFT.getNFT(voter, id: nft) ?? panic("NFT doesn't exist")
                let minedNFT = AABvoteNFT.mintedNFTs[nft]!

                if minedNFT.used {
                    panic("Nft ".concat(nft.toString()).concat(" has been used"))
                }

                if minedNFT.ownerMinted != NFT.owner!.address {
                    panic("Nft has been transfer to another wallet")
                }

                if type == AABvoteNFT.Rarity.common.rawValue && NFT.candidateId != candidateId {
                    panic("Invalid nft")
                }

                rarityCond[NFT.rarity] = rarityCond[NFT.rarity]! + 1
            }

            if type == AABvoteNFT.Rarity.common.rawValue && rarityCond[AABvoteNFT.Rarity.common.rawValue] != nfts.length || type == AABvoteNFT.Rarity.iconic.rawValue && rarityCond[AABvoteNFT.Rarity.iconic.rawValue] != nfts.length || rarityCond[AABvoteNFT.Rarity.common.rawValue] != nfts.length && rarityCond[AABvoteNFT.Rarity.iconic.rawValue] != nfts.length {
                panic("Invalid rarity nft")
            }

            var star: UInt64 = 0;

            for key in rarityCond.keys {
                let value = rarityCond[key]!

                if value > 0 {
                    star = AABvoteVote.rarityToStar(rarity: key, amount: value)
                }
            }

            let vote = Vote(candidateId: candidateId, nfts: nfts, star: star)

            votes.append(vote)
            AABvoteVote.votes[voter] = votes
            AABvoteVote.star[voter] = (AABvoteVote.star[voter] ?? 0) + UInt(vote.star)

            for nft in vote.nfts {
                AABvoteNFT.setUsedNFT(id: nft, used: true)
            }

            emit NewVote(voter: voter, candidateId: vote.candidateId, nfts: vote.nfts, star: vote.star)
        }
    }

    pub resource Administrator {
        pub fun setAllowVote(_ allowVote: Bool) {
            AABvoteVote.allowVote = allowVote
        }

        pub fun createAdminVote(): @AdminVote {
            return <- create AdminVote()
        }
    }

    init() {
        self.votes = {}
        self.star = {}
        self.allowVote = true

        self.AdminVoteStoragePath = /storage/AABVoteAdminVoteV1
        self.AdminStoragePath = /storage/AABvoteVoteAdminV1

        let admin <- create Administrator()
        self.account.save<@Administrator>(<-admin, to: self.AdminStoragePath)
    }
}
