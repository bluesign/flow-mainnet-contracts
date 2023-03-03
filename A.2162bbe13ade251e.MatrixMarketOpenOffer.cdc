import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448

pub contract MatrixMarketOpenOffer {

    // initialize StoragePath and OpenOfferPublicPath
    pub event MatrixMarketOpenOfferInitialized()

    // MatrixMarketOpenOffer initialized
    pub event OpenOfferInitialized(OpenOfferResourceId: UInt64)

    pub event OpenOfferDestroyed(OpenOfferResourceId: UInt64)

    // event: create a bid
    pub event OfferAvailable(
        bidAddress: Address,
        bidId: UInt64,
        vaultType: Type,
        bidPrice: UFix64,
        nftType: Type,
        nftId: UInt64,
        brutto: UFix64,
        cuts: {Address:UFix64},
        expirationTime: UFix64,
    )

    // event: close a bid (purchased or removed)
    pub event OfferCompleted(
        bidId: UInt64,
        purchased: Bool,
    )

    // payment splitter
    pub struct Cut {
        pub let receiver: Capability<&{FungibleToken.Receiver}>
        pub let amount: UFix64

        init(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
            self.receiver = receiver
            self.amount = amount
        }
    }

    pub struct OfferDetails {
        pub let bidId: UInt64
        pub let vaultType: Type
        pub let bidPrice: UFix64
        pub let nftType: Type
        pub let nftId: UInt64
        pub let brutto: UFix64
        pub let cuts: [Cut]
        pub let expirationTime: UFix64

        pub var purchased: Bool

        access(contract) fun setToPurchased() {
            self.purchased = true
        }

        init(
            bidId: UInt64,
            vaultType: Type,
            bidPrice: UFix64,
            nftType: Type,
            nftId: UInt64,
            brutto: UFix64,
            cuts: [Cut],
            expirationTime: UFix64,
        ) {
            self.bidId = bidId
            self.vaultType = vaultType
            self.bidPrice = bidPrice
            self.nftType = nftType
            self.nftId = nftId
            self.brutto = brutto
            self.cuts = cuts
            self.expirationTime = expirationTime
            self.purchased = false
        }
    }

    pub resource interface OfferPublic {
        pub fun purchase(item: @NonFungibleToken.NFT): @FungibleToken.Vault?
        pub fun getDetails(): OfferDetails
    }

    pub resource Offer: OfferPublic {
        access(self) let details: OfferDetails
        access(contract) let vaultRefCapability: Capability<&{FungibleToken.Receiver, FungibleToken.Balance, FungibleToken.Provider}>
        access(contract) let rewardCapability: Capability<&{NonFungibleToken.CollectionPublic}>

        init(
            vaultRefCapability: Capability<&{FungibleToken.Receiver, FungibleToken.Balance, FungibleToken.Provider}>,
            offerPrice: UFix64,
            rewardCapability: Capability<&{NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftId: UInt64,
            cuts: [Cut],
            expirationTime: UFix64,
        ) {
            pre {
                rewardCapability.check(): "reward capability not valid"
                cuts.length <= 10: "length of cuts too long"
            }
            self.vaultRefCapability = vaultRefCapability
            self.rewardCapability = rewardCapability

            var price: UFix64 = offerPrice
            let cutsInfo: {Address:UFix64} = {}

            for cut in cuts {
                assert(cut.receiver.check(), message: "invalid cut receiver")
                assert(price > cut.amount, message: "price must be > 0")

                price = price - cut.amount
                cutsInfo[cut.receiver.address] = cut.amount
            }

            let vaultRef = self.vaultRefCapability.borrow() ?? panic("cannot borrow vaultRefCapability")
            self.details = OfferDetails(
                bidId: self.uuid,
                vaultType: vaultRef.getType(),
                bidPrice: price,
                nftType: nftType,
                nftId: nftId,
                brutto: offerPrice,
                cuts: cuts,
                expirationTime: expirationTime,
            )

            emit OfferAvailable(
                bidAddress: rewardCapability.address,
                bidId: self.details.bidId,
                vaultType: self.details.vaultType,
                bidPrice: self.details.bidPrice,
                nftType: self.details.nftType,
                nftId: self.details.nftId,
                brutto: self.details.brutto,
                cuts: cutsInfo,
                expirationTime: self.details.expirationTime,
            )
        }

        pub fun purchase(item: @NonFungibleToken.NFT): @FungibleToken.Vault {
            pre {
                self.details.expirationTime > getCurrentBlock().timestamp: "Offer has expired"
                !self.details.purchased: "Offer has already been purchased"
                item.isInstance(self.details.nftType): "item NFT is not of specified type"
                item.id == self.details.nftId: "item NFT does not have specified ID"
            }
            self.details.setToPurchased()

            self.rewardCapability.borrow()!.deposit(token: <- item)

            let payment <- self.vaultRefCapability.borrow()!.withdraw(amount: self.details.brutto)

            for cut in self.details.cuts {
                if let receiver = cut.receiver.borrow() {
                    let part <- payment.withdraw(amount: cut.amount)
                    receiver.deposit(from: <- part)
                }
            }

            emit OfferCompleted(
                bidId: self.details.bidId,
                purchased: self.details.purchased,
            )

            return <- payment
        }

        pub fun getDetails(): OfferDetails {
            return self.details
        }

        destroy() {
            if !self.details.purchased {
                emit OfferCompleted(
                    bidId: self.details.bidId,
                    purchased: self.details.purchased,
                )
            }
        }
    }

    pub resource interface OpenOfferManager {
        pub fun createOffer(
            vaultRefCapability: Capability<&{FungibleToken.Receiver, FungibleToken.Balance, FungibleToken.Provider}>,
            offerPrice: UFix64,
            rewardCapability: Capability<&{NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftId: UInt64,
            cuts: [Cut],
            expirationTime: UFix64,
        ): UInt64
        pub fun removeOffer(bidId: UInt64)
    }

    pub resource interface OpenOfferPublic {
        pub fun getOfferIds(): [UInt64]
        pub fun borrowOffer(bidId: UInt64): &Offer{OfferPublic}?
        pub fun cleanup(bidId: UInt64)
    }

    pub resource OpenOffer : OpenOfferManager, OpenOfferPublic {
        access(self) var bids: @{UInt64:Offer}

        pub fun createOffer(
            vaultRefCapability: Capability<&{FungibleToken.Receiver,FungibleToken.Balance,FungibleToken.Provider}>,
            offerPrice: UFix64,
            rewardCapability: Capability<&{NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftId: UInt64,
            cuts: [Cut],
            expirationTime: UFix64,
        ): UInt64 {
            let bid <- create Offer(
                vaultRefCapability: vaultRefCapability,
                offerPrice: offerPrice,
                rewardCapability: rewardCapability,
                nftType: nftType,
                nftId: nftId,
                cuts: cuts,
                expirationTime: expirationTime,
            )

            let bidId = bid.uuid
            let dummy <- self.bids[bidId] <- bid
            destroy dummy

            return bidId
        }

        pub fun removeOffer(bidId: UInt64) {
            destroy self.bids.remove(key: bidId) ?? panic("missing bid")
        }

        pub fun getOfferIds(): [UInt64] {
            return self.bids.keys
        }

        pub fun borrowOffer(bidId: UInt64): &Offer{OfferPublic}? {
            if self.bids[bidId] != nil {
                return &self.bids[bidId] as! &Offer{OfferPublic}?
            } else {
                return nil
            }
        }

        pub fun cleanup(bidId: UInt64) {
            pre {
                self.bids[bidId] != nil: "could not find Offer with given id"
            }
            let bid <- self.bids.remove(key: bidId)!
            assert(bid.getDetails().purchased == true, message: "Offer is not purchased, only admin can remove")
            destroy bid
        }

        init() {
            self.bids <- {}
            emit OpenOfferInitialized(OpenOfferResourceId: self.uuid)
        }

        destroy() {
            destroy self.bids
            emit OpenOfferDestroyed(OpenOfferResourceId: self.uuid)
        }
    }

    // create openbid resource
    pub fun createOpenOffer(): @OpenOffer {
        return <-create OpenOffer()
    }

    pub let OpenOfferStoragePath: StoragePath
    pub let OpenOfferPublicPath: PublicPath

    init () {
        self.OpenOfferStoragePath = /storage/MatrixMarketOpenOffer
        self.OpenOfferPublicPath = /public/MatrixMarketOpenOffer

        emit MatrixMarketOpenOfferInitialized()
    }
}
