import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import StarlyCard from 0x5b82f21c0edf76e3
import StarlyCardStaking from 0x29fcd0b5e444242a
import StarlyIDParser from 0x5b82f21c0edf76e3
import StarlyMetadata from 0x5b82f21c0edf76e3
import StarlyToken from 0x142fa6570b62fd97

pub contract StakedStarlyCard: NonFungibleToken {

    pub event CardStaked(
        id: UInt64,
        starlyID: String,
        beneficiary: Address,
        stakeTimestamp: UFix64,
        remainingResourceAtStakeTimestamp: UFix64)
    pub event CardUnstaked(
        id: UInt64,
        starlyID: String
        beneficiary: Address,
        stakeTimestamp: UFix64,
        unstakeTimestamp: UFix64,
        remainingResourceAtUnstakeTimestamp: UFix64)
    pub event StakeBurned(id: UInt64, starlyID: String)
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event ContractInitialized()

    pub var stakingEnabled: Bool
    pub var unstakingEnabled: Bool
    pub var totalSupply: UInt64

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let MinterStoragePath: StoragePath
    pub let BurnerStoragePath: StoragePath

    pub resource interface StakePublic {
        pub fun getStarlyID(): String
        pub fun getBeneficiary(): Address
        pub fun getStakeTimestamp(): UFix64
        pub fun getRemainingResourceAtStakeTimestamp(): UFix64
        pub fun getUnlockedResource(): UFix64
        pub fun borrowStarlyCard(): &StarlyCard.NFT
    }

    pub struct StakeMetadataView {
        pub let id: UInt64
        pub let starlyID: String
        pub let stakeTimestamp: UFix64
        pub let remainingResource: UFix64
        pub let remainingResourceAtStakeTimestamp: UFix64

        init(
            id: UInt64,
            starlyID: String,
            stakeTimestamp: UFix64,
            remainingResource: UFix64,
            remainingResourceAtStakeTimestamp: UFix64) {
            self.id = id
            self.starlyID = starlyID
            self.stakeTimestamp = stakeTimestamp
            self.remainingResource = remainingResource
            self.remainingResourceAtStakeTimestamp = remainingResourceAtStakeTimestamp
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver, StakePublic {
        pub let id: UInt64
        access(contract) let starlyCard: @StarlyCard.NFT
        pub let beneficiary: Address
        pub let stakeTimestamp: UFix64
        pub let remainingResourceAtStakeTimestamp: UFix64

        init(
            id: UInt64,
            starlyCard: @StarlyCard.NFT,
            beneficiary: Address,
            stakeTimestamp: UFix64,
            remainingResourceAtStakeTimestamp: UFix64) {
            self.id = id
            self.starlyCard <-starlyCard
            self.beneficiary = beneficiary
            self.stakeTimestamp = stakeTimestamp
            self.remainingResourceAtStakeTimestamp = remainingResourceAtStakeTimestamp
        }

        destroy () {
            let starlyID = self.starlyCard.starlyID
            let collectionRef = getAccount(self.beneficiary).getCapability(StarlyCard.CollectionPublicPath)!.borrow<&{NonFungibleToken.CollectionPublic}>()!
            collectionRef.deposit(token: <-self.starlyCard)
            emit StakeBurned(id: self.id, starlyID: starlyID)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<StakeMetadataView>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "StakedStarlyCard #".concat(self.id.toString()),
                        description: "id: ".concat(self.id.toString())
                            .concat(", stakeTimestamp: ").concat(UInt64(self.stakeTimestamp).toString()),
                        thumbnail: MetadataViews.HTTPFile(url: ""))
                case Type<StakeMetadataView>():
                    return StakeMetadataView(
                        id: self.id,
                        starlyID: self.starlyCard.starlyID,
                        stakeTimestamp: self.stakeTimestamp,
                        remainingResource: StarlyCardStaking.getRemainingResourceWithDefault(starlyID: self.starlyCard.starlyID),
                        remainingResourceAtStakeTimestamp: self.remainingResourceAtStakeTimestamp)
            }
            return nil
        }

        pub fun getStarlyID(): String {
            return self.starlyCard.starlyID
        }

        pub fun getBeneficiary(): Address {
            return self.beneficiary
        }

        pub fun getStakeTimestamp(): UFix64 {
            return self.stakeTimestamp
        }

        pub fun getRemainingResourceAtStakeTimestamp(): UFix64 {
            return self.remainingResourceAtStakeTimestamp
        }

        pub fun getUnlockedResource(): UFix64 {
            let starlyID = self.starlyCard.starlyID
            let stakeTimestamp = self.stakeTimestamp
            let remainingResourceAtStakeTimestamp = self.remainingResourceAtStakeTimestamp
            let stakedSeconds = getCurrentBlock().timestamp - stakeTimestamp

            let metadata = StarlyMetadata.getCardEdition(starlyID: starlyID) ?? panic("Missing metadata")
            let collectionID = metadata.collection.id
            let initialResource = metadata.score ?? 0.0
            let claimedResourceBeforeStaking = initialResource - remainingResourceAtStakeTimestamp
            let remainingResource = StarlyCardStaking.getRemainingResource(collectionID: collectionID, starlyID: starlyID) ?? initialResource
            if remainingResource <= 0.0 {
                return 0.0
            }

            let claimedResource = remainingResourceAtStakeTimestamp - remainingResource
            let claimResourcePerSecond = initialResource / 0.31556952 // using scale factor of 10*9 to avoid precision errors
            let unlockedResource = stakedSeconds * claimResourcePerSecond / 100000000.0 - claimedResource
            return unlockedResource > remainingResource ? remainingResource : unlockedResource
        }

        pub fun borrowStarlyCard(): &StarlyCard.NFT {
            let ref = &self.starlyCard as auth &NonFungibleToken.NFT
            return ref as! &StarlyCard.NFT
        }
    }

    // We put stake creation logic into minter, its job is to have checks, emit events, update counters
    pub resource NFTMinter {

        pub fun mintStake(
            starlyCard: @StarlyCard.NFT,
            beneficiary: Address,
            stakeTimestamp: UFix64): @StakedStarlyCard.NFT {

            pre {
                StakedStarlyCard.stakingEnabled: "Staking is disabled"
            }

            let starlyID = starlyCard.starlyID
            let remainingResource = StarlyCardStaking.getRemainingResourceWithDefault(starlyID: starlyID)
            let stake <- create NFT(
                id: StakedStarlyCard.totalSupply,
                starlyCard: <-starlyCard,
                beneficiary: beneficiary,
                stakeTimestamp: stakeTimestamp,
                remainingResourceAtStakeTimestamp: remainingResource)
            StakedStarlyCard.totalSupply = StakedStarlyCard.totalSupply + (1 as UInt64)
            emit CardStaked(
                id: stake.id,
                starlyID: starlyID,
                beneficiary: beneficiary,
                stakeTimestamp: stakeTimestamp,
                remainingResourceAtStakeTimestamp: remainingResource)
            return <-stake
        }
    }

    // We put stake unstaking logic into burner, its job is to have checks, emit events, update counters
    pub resource NFTBurner {

        pub fun burnStake(stake: @StakedStarlyCard.NFT) {
            pre {
                StakedStarlyCard.unstakingEnabled: "Unstaking is disabled"
                stake.stakeTimestamp < getCurrentBlock().timestamp: "Cannot unstake stake with stakeTimestamp more or equal to current timestamp"
            }

            let id = stake.id
            let starlyID = stake.starlyCard.starlyID
            let beneficiary = stake.beneficiary
            let stakeTimestamp = stake.stakeTimestamp
            let timestamp = getCurrentBlock().timestamp
            let seconds = timestamp - stake.stakeTimestamp
            destroy stake

            let remainingResource = StarlyCardStaking.getRemainingResourceWithDefault(starlyID: starlyID)
            emit CardUnstaked(
                id: id,
                starlyID: starlyID,
                beneficiary: beneficiary,
                stakeTimestamp: stakeTimestamp,
                unstakeTimestamp: timestamp,
                remainingResourceAtUnstakeTimestamp: remainingResource)
        }
    }

    pub resource interface CollectionPublic {
        pub fun getIDs(): [UInt64]
        pub fun borrowStakePublic(id: UInt64): &StakedStarlyCard.NFT{StakedStarlyCard.StakePublic, NonFungibleToken.INFT}
    }

    pub resource interface CollectionPrivate {
        pub fun borrowStakePrivate(id: UInt64): &StakedStarlyCard.NFT
        pub fun stake(starlyCard: @StarlyCard.NFT, beneficiary: Address)
        pub fun unstake(id: UInt64)
        pub fun claimAll(limit: Int)
    }

    pub resource Collection:
        NonFungibleToken.Provider,
        NonFungibleToken.Receiver,
        NonFungibleToken.CollectionPublic,
        CollectionPublic,
        CollectionPrivate,
        MetadataViews.ResolverCollection {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        destroy() {
            destroy self.ownedNFTs
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let stake <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: stake.id, from: self.owner?.address)
            return <-stake
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @StakedStarlyCard.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            let stake = nft as! &StakedStarlyCard.NFT
            return stake as &AnyResource{MetadataViews.Resolver}
        }

        pub fun borrowStakePublic(id: UInt64): &StakedStarlyCard.NFT{StakedStarlyCard.StakePublic, NonFungibleToken.INFT} {
            let stakeRef = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            let intermediateRef = stakeRef as! auth &StakedStarlyCard.NFT
            return intermediateRef as &StakedStarlyCard.NFT{StakedStarlyCard.StakePublic, NonFungibleToken.INFT}
        }

        pub fun stake(starlyCard: @StarlyCard.NFT, beneficiary: Address) {
            let minter = StakedStarlyCard.account.borrow<&NFTMinter>(from: StakedStarlyCard.MinterStoragePath)!
            let stake <- minter.mintStake(
                starlyCard: <-starlyCard,
                beneficiary: beneficiary,
                stakeTimestamp: getCurrentBlock().timestamp)
            self.deposit(token: <-stake)
        }

        pub fun unstake(id: UInt64) {
            let burner = StakedStarlyCard.account.borrow<&NFTBurner>(from: StakedStarlyCard.BurnerStoragePath)!
            let stake <- self.withdraw(withdrawID: id) as! @StakedStarlyCard.NFT
            burner.burnStake(stake: <-stake)
        }

        pub fun borrowStakePrivate(id: UInt64): &StakedStarlyCard.NFT {
            let stakePassRef = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            return stakePassRef as! &StakedStarlyCard.NFT
        }

        pub fun claimAll(limit: Int) {
            var i = 0
            let stakeIDs = self.getIDs()
            for stakeID in stakeIDs {
                let stakeRef = self.borrowStakePrivate(id: stakeID)
                let starlyID = stakeRef.starlyCard.starlyID
                let parsedStarlyID = StarlyIDParser.parse(starlyID: starlyID)
                let collectionID = parsedStarlyID.collectionID
                let remainingResource = StarlyCardStaking.getRemainingResource(collectionID: collectionID, starlyID: starlyID)
                if (i > limit) {
                    return
                }
                i = i + 1
            }
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource Admin {
        pub fun setStakingEnabled(_ enabled: Bool) {
            StakedStarlyCard.stakingEnabled = enabled
        }

        pub fun setUnstakingEnabled(_ enabled: Bool) {
            StakedStarlyCard.unstakingEnabled = enabled
        }

        pub fun createNFTMinter(): @NFTMinter {
            return <-create NFTMinter()
        }

        pub fun createNFTBurner(): @NFTBurner {
            return <-create NFTBurner()
        }
    }

    init() {
        self.stakingEnabled = true
        self.unstakingEnabled = true
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/stakedStarlyCardCollection
        self.CollectionPublicPath = /public/stakedStarlyCardCollection
        self.AdminStoragePath = /storage/stakedStarlyCardAdmin
        self.MinterStoragePath = /storage/stakedStarlyCardMinter
        self.BurnerStoragePath = /storage/stakedStarlyCardBurner

        let admin <- create Admin()
        let minter <- admin.createNFTMinter()
        let burner <- admin.createNFTBurner()
        self.account.save(<-admin, to: self.AdminStoragePath)
        self.account.save(<-minter, to: self.MinterStoragePath)
        self.account.save(<-burner, to: self.BurnerStoragePath)

        emit ContractInitialized()
    }
}
