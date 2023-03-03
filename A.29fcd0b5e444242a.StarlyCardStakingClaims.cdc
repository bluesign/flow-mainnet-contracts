import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import StarlyIDParser from 0x5b82f21c0edf76e3
import StarlyMetadata from 0x5b82f21c0edf76e3
import StarlyMetadataViews from 0x5b82f21c0edf76e3
import StakedStarlyCard from 0x29fcd0b5e444242a
import StarlyCardStaking from 0x29fcd0b5e444242a
import StarlyToken from 0x142fa6570b62fd97
import StarlyTokenStaking from 0x76a9b420a331b9f0

pub contract StarlyCardStakingClaims {

    pub event ClaimPaid(amount: UFix64, to: Address, paidStakeIDs: [UInt64])

    pub var claimingEnabled: Bool
    access(contract) var recentClaims: @{Address: RecentClaims}

    pub let AdminStoragePath: StoragePath

    pub resource RecentClaims {
        access(self) let timestamps: [UFix64]
        access(self) let claimAmounts: [UFix64]

        pub var windowSizeSeconds: UFix64

        pub fun addClaim(timestamp: UFix64, starlyID: String, amountToClaim: UFix64, maxDailyClaimAmount: UFix64): UFix64 {
            let thresholdTimestamp = timestamp - self.windowSizeSeconds

            var i = 0
            var alreadyClaimed = 0.0
            // remove old claims
            while i < self.timestamps.length {
                if self.timestamps[i] <= thresholdTimestamp {
                    self.timestamps.remove(at: i)
                    self.claimAmounts.remove(at: i)
                } else {
                    alreadyClaimed = alreadyClaimed + self.claimAmounts[i]
                    i = i + 1
                }
            }

            let availableAmount = maxDailyClaimAmount.saturatingSubtract(alreadyClaimed)
            if availableAmount <= 0.0 {
                return 0.0
            }
            let claimAmount = amountToClaim < availableAmount ? amountToClaim : availableAmount

            self.timestamps.append(timestamp)
            self.claimAmounts.append(claimAmount)

            return claimAmount
        }

        pub fun getClaimedAmount(): UFix64 {
            let thresholdTimestamp = getCurrentBlock().timestamp - self.windowSizeSeconds
            var i = 0
            var claimedAmount = 0.0
            while i < self.timestamps.length {
                if self.timestamps[i] > thresholdTimestamp {
                    claimedAmount = claimedAmount + self.claimAmounts[i]
                }
                i = i + 1
            }
            return claimedAmount
        }

        init() {
            self.windowSizeSeconds = UFix64(24 * 60 * 60)

            self.timestamps = []
            self.claimAmounts = []
        }
    }

    pub fun claim(ids: [UInt64], address: Address) {
        pre {
            StarlyCardStakingClaims.claimingEnabled: "Claiming is disabled"
        }

        let maxDailyClaimAmount = self.getDailyClaimAmountLimitByAddress(address: address)
        if !self.recentClaims.containsKey(address) {
            self.recentClaims[address] <-! create RecentClaims()
        }

        let remainingResourceEditor = self.account.borrow<&{StarlyCardStaking.IEditor}>(from: StarlyCardStaking.EditorProxyStoragePath)
            ?? panic("Could not borrow a reference to StarlyCardStaking.EditorProxyStoragePath!")

        // get all staked cards
        let account = getAccount(address)
        let cardStakeCollectionRef = account
            .getCapability(StakedStarlyCard.CollectionPublicPath)!
            .borrow<&{StakedStarlyCard.CollectionPublic, NonFungibleToken.CollectionPublic}>()
            ?? panic("Could not borrow capability from public StarlyTokenStaking collection!")

        let userRecentClaims = (&self.recentClaims[address] as &RecentClaims?)!

        let currentTimestamp = getCurrentBlock().timestamp
        var payoutAmount = 0.0
        let paidStakeIDs: [UInt64] = []
        for id in ids {
            let nft = cardStakeCollectionRef.borrowStakePublic(id: id)
            let starlyID = nft.getStarlyID()
            let stakeTimestamp = nft.getStakeTimestamp()
            let metadata = StarlyMetadata.getCardEdition(starlyID: starlyID) ?? panic("Missing metadata")
            let collectionID = metadata.collection.id
            let initialResource = metadata.score ?? 0.0
            let remainingResource = StarlyCardStaking.getRemainingResource(collectionID: collectionID, starlyID: starlyID) ?? initialResource
            if remainingResource <= 0.0 {
                continue
            }

            let amountToClaim = nft.getUnlockedResource()

            let claimAmount = userRecentClaims.addClaim(
                timestamp: currentTimestamp,
                starlyID: starlyID,
                amountToClaim: amountToClaim,
                maxDailyClaimAmount: maxDailyClaimAmount)

            if claimAmount <= 0.0 {
                continue
            }

            let newRemainingResource = remainingResource - claimAmount
            remainingResourceEditor.setRemainingResource(
                collectionID: collectionID,
                starlyID: starlyID,
                remainingResource: newRemainingResource)

            payoutAmount = payoutAmount + claimAmount
            paidStakeIDs.append(id)
        }

        if payoutAmount > 0.0 {
            let claimVaultRef = StarlyCardStakingClaims.account.borrow<&StarlyToken.Vault>(from: StarlyToken.TokenStoragePath)!
            let receiverRef = account.getCapability(StarlyToken.TokenPublicReceiverPath).borrow<&{FungibleToken.Receiver}>()
                ?? panic("Could not borrow StarlyToken receiver reference to the beneficiary's vault!")

            receiverRef.deposit(from: <-claimVaultRef.withdraw(amount: payoutAmount))
            emit ClaimPaid(amount: payoutAmount, to: address, paidStakeIDs: paidStakeIDs)
        }
    }

    pub fun getClaimedAmountByAddress(address: Address): UFix64 {
        if !self.recentClaims.containsKey(address) {
            return 0.0
        } else {
            let userRecentClaims = (&self.recentClaims[address] as &RecentClaims?)!
            return userRecentClaims.getClaimedAmount()
        }
    }

    pub fun getRemainingDailyClaimAmountByAddress(address: Address): UFix64 {
        return self.getDailyClaimAmountLimitByAddress(address: address).saturatingSubtract(self.getClaimedAmountByAddress(address: address))
    }

    pub fun getDailyClaimAmountLimitByAddress(address: Address): UFix64 {
        let stakeCollectionRef = getAccount(address).getCapability(StarlyTokenStaking.CollectionPublicPath)!
            .borrow<&{StarlyTokenStaking.CollectionPublic, NonFungibleToken.CollectionPublic}>()
            ?? panic("Could not borrow capability from public StarlyTokenStaking collection!")

        let stakedAmount = stakeCollectionRef.getStakedAmount()
        return self.getDailyClaimAmount(stakedAmount: stakedAmount)
    }

    pub fun getDailyClaimAmount(stakedAmount: UFix64): UFix64 {
        return stakedAmount / 100.0
    }

    pub resource Admin {
        pub fun setClaimingEnabled(_ enabled: Bool) {
            StarlyCardStakingClaims.claimingEnabled = enabled
        }
    }

    init() {
        self.claimingEnabled = true
        self.recentClaims <- {}

        self.AdminStoragePath = /storage/starlyCardStakingClaimsAdmin

        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        if (self.account.borrow<&StarlyToken.Vault>(from: StarlyToken.TokenStoragePath) == nil) {
            self.account.save(<-StarlyToken.createEmptyVault(), to: StarlyToken.TokenStoragePath)
            self.account.link<&StarlyToken.Vault{FungibleToken.Receiver}>(
                StarlyToken.TokenPublicReceiverPath,
                target: StarlyToken.TokenStoragePath)
            self.account.link<&StarlyToken.Vault{FungibleToken.Balance}>(
                StarlyToken.TokenPublicBalancePath,
                target: StarlyToken.TokenStoragePath)
        }
    }
}
