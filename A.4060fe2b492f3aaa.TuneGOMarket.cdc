import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import TicalUniverse from 0xfef48806337aabf1
import TuneGO from 0x0d9bc5af3fc0c2e3

// Contract
//
pub contract TuneGOMarket {

    // Events
    //
    pub event ContractInitialized()
    pub event SaleOfferCreated(
        saleOfferId: UInt64,
        collectibleId: UInt64,
        collectibleType: String,
        tunegoFee: MarketFee,
        royalties: [Royalty],
        price: UFix64, 
    )
    pub event SaleOfferAccepted(saleOfferId: UInt64, buyer: Address)
    pub event SaleOfferRemoved(saleOfferId: UInt64)
    pub event TuneGOMarketFeeSet(receiver: Address, percentage: UFix64)

    // Paths
    //
    access(all) let CollectionPublicPath: PublicPath
    access(all) let CollectionStoragePath: StoragePath
    access(all) let AdminPublicPath: PublicPath
    access(all) let AdminStoragePath: StoragePath

    // Royalty
    //
    pub struct Royalty {
        pub let receiver: Address
        pub let percentage: UFix64

        init(receiver: Address, percentage: UFix64) {
            self.receiver = receiver
            self.percentage = percentage
        }
    }

    // MarketFee
    //
    pub struct MarketFee {
        pub let receiver: Address
        pub let percentage: UFix64

        init(receiver: Address, percentage: UFix64) {
            self.receiver = receiver
            self.percentage = percentage
        }
    }

    // Market config
    //
    access(contract) var TuneGOFee: MarketFee
    access(contract) let SupportedNFTTypes: [Type]

    // SaleOfferPublic
    //
    access(all) resource interface SaleOfferPublic {
        pub let collectibleId: UInt64
        pub let collectibleType: Type
        pub let price: UFix64
        pub var isCompleted: Bool

        pub fun borrowCollectible(): &NonFungibleToken.NFT
        pub fun purchase(
            payment: @FungibleToken.Vault,
            buyerCollection: Capability<&{NonFungibleToken.Receiver}>
        ): @NonFungibleToken.NFT
    }

    // SaleOffer
    //
    access(all) resource SaleOffer: SaleOfferPublic {
        pub var isCompleted: Bool
        pub let collectibleId: UInt64
        pub let collectibleType: Type 
        pub let price: UFix64

        access(self) let paymentReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        access(self) let royalties: [Royalty]
        access(self) let saleItemProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
        access(self) let tunegoPaymentFeeReceiver: Capability<&{FungibleToken.Receiver}>
        access(self) let tunegoPaymentFeePercentage: UFix64

        pub fun purchase(
            payment: @FungibleToken.Vault,
            buyerCollection: Capability<&{NonFungibleToken.Receiver}>
        ): @NonFungibleToken.NFT {
            pre {
                payment.balance == self.price: "Payment does not equal offer price"
                self.isCompleted == false: "The sale offer has already been accepted"
            }
            self.isCompleted = true

            let tunegoFee = self.price * self.tunegoPaymentFeePercentage / 100.0
            let tunegoFeePayment <- payment.withdraw(amount: tunegoFee);

            self.tunegoPaymentFeeReceiver.borrow()!.deposit(from: <-tunegoFeePayment)

            for royalty in self.royalties {
                let royaltyAccount = getAccount(royalty.receiver)
                let royaltyVault = royaltyAccount.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)

                if royaltyVault.check() {
                    let royaltyAmount = self.price * royalty.percentage / 100.0
                    let royaltyPayment <- payment.withdraw(amount: royaltyAmount);
                    royaltyVault.borrow()!.deposit(from: <- royaltyPayment)
                }
            }
            self.paymentReceiver.borrow()!.deposit(from: <- payment)

            let nft <- self.saleItemProviderCapability.borrow()!.withdraw(withdrawID: self.collectibleId)

            emit SaleOfferAccepted(saleOfferId: self.uuid, buyer: buyerCollection.address)

            return <- nft
        }

        pub fun borrowCollectible(): &NonFungibleToken.NFT {
            let saleItemProvider = self.saleItemProviderCapability.borrow()!.borrowNFT(id: self.collectibleId)
            assert(saleItemProvider.isInstance(self.collectibleType), message: "Collectible has wrong type")
            assert(saleItemProvider.id == self.collectibleId, message: "Collectible has wrong ID")

            return saleItemProvider as &NonFungibleToken.NFT
        }

        init(
            saleItemProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            collectibleType: Type,
            collectibleId: UInt64,
            royalties: [Royalty],
            price: UFix64,
            paymentReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        ) {
            assert(price > 0.0, message: "Sale price amount must be greater than 0")

            let saleItemProvider = saleItemProviderCapability.borrow()
            assert(saleItemProvider != nil, message: "Cannot access sale item from provider")

            let collectible = saleItemProvider!.borrowNFT(id: collectibleId)
            assert(collectible.isInstance(collectibleType), message: "Collectible is not of specified type")
            assert(collectible.id == collectibleId, message: "Collectible does not have specified ID")
            assert(TuneGOMarket.SupportedNFTTypes.contains(collectible.getType()), message: "Collectible is not of supported type")
            assert(paymentReceiver.borrow() != nil, message: "Missing payment receiver vault")

            var totalRoyaltiesPercentage: UFix64 = 0.0
            for royalty in royalties {
                let account = getAccount(royalty.receiver)
                let vault = account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                assert(vault.borrow() != nil, message: "Missing royalty receiver vault")

                totalRoyaltiesPercentage = totalRoyaltiesPercentage + royalty.percentage;
            }
            let totalFeesPercentage = totalRoyaltiesPercentage + TuneGOMarket.TuneGOFee.percentage;
            assert(totalFeesPercentage < 100.0, message: "Total fees percentage is too high")

            self.isCompleted = false
            self.saleItemProviderCapability = saleItemProviderCapability
            self.collectibleType = collectibleType
            self.collectibleId = collectibleId
            self.royalties = royalties
            self.price = price
            self.paymentReceiver = paymentReceiver

            let tunegoAccount = getAccount(TuneGOMarket.TuneGOFee.receiver)
            self.tunegoPaymentFeeReceiver = tunegoAccount.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            self.tunegoPaymentFeePercentage = TuneGOMarket.TuneGOFee.percentage
        }
    }

    // CollectionManager
    //
    pub resource interface CollectionManager {
        pub fun createSaleOffer (
            saleItemProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            collectibleType: Type,
            collectibleId: UInt64,
            royalties: [Royalty],
            price: UFix64,
            paymentReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        ): UInt64
        pub fun removeSaleOffer(saleOfferId: UInt64)
    }

    // CollectionPublic
    //
    pub resource interface CollectionPublic {
        pub fun getSaleOfferIDs(): [UInt64]
        pub fun borrowSaleOffer(saleOfferId: UInt64): &SaleOffer{SaleOfferPublic}?
    }

    // Collection
    //
    pub resource Collection : CollectionManager, CollectionPublic {
        access(self) var saleOffers: @{UInt64: SaleOffer}

        pub fun createSaleOffer (
            saleItemProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            collectibleType: Type,
            collectibleId: UInt64,
            royalties: [Royalty],
            price: UFix64,
            paymentReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
        ): UInt64 {
            let saleOffer <- create SaleOffer(
                saleItemProviderCapability: saleItemProviderCapability,
                collectibleType: collectibleType,
                collectibleId: collectibleId,
                royalties: royalties,
                price: price,
                paymentReceiver: paymentReceiver
            )

            let saleOfferId = saleOffer.uuid
            let oldOffer <- self.saleOffers[saleOfferId] <- saleOffer
            destroy oldOffer

            emit SaleOfferCreated(
                saleOfferId: saleOfferId,
                collectibleId: collectibleId,
                collectibleType: collectibleType.identifier,
                tunegoFee: TuneGOMarket.TuneGOFee,
                royalties: royalties,
                price: price,
            )

            return saleOfferId
        }

        pub fun removeSaleOffer(saleOfferId: UInt64) {

            emit SaleOfferRemoved(saleOfferId: saleOfferId)

            let saleOffer <- (self.saleOffers.remove(key: saleOfferId) ?? panic("missing SaleOffer"))

            destroy saleOffer
        }

        pub fun getSaleOfferIDs(): [UInt64] {
            return self.saleOffers.keys
        }

        pub fun borrowSaleOffer(saleOfferId: UInt64): &SaleOffer{SaleOfferPublic}? {
            if self.saleOffers[saleOfferId] == nil {
                return nil
            } else {
                return &self.saleOffers[saleOfferId] as! &SaleOffer{SaleOfferPublic}
            }
        }

        init () {
            self.saleOffers <- {}
        }

        destroy () {
            destroy self.saleOffers
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <-create Collection()
    }

    pub fun getMarketFee(): MarketFee {
        return MarketFee(
            receiver: self.TuneGOFee.receiver,
            percentage: self.TuneGOFee.percentage
        )
    }

    pub resource Admin {

        pub fun setTuneGOFee(tunegoFee: MarketFee) {
            TuneGOMarket.TuneGOFee = tunegoFee
            emit TuneGOMarketFeeSet(receiver: tunegoFee.receiver, percentage: tunegoFee.percentage)
        }

        pub fun addSupportedNFTType(nftType: Type) {
            TuneGOMarket.SupportedNFTTypes.append(nftType)
        }

        pub fun createNewAdmin(): @Admin {
            return <- create Admin()
        }
    }

    init () {
        self.CollectionPublicPath = /public/tunegoMarketCollection
        self.CollectionStoragePath = /storage/tunegoMarketCollection
        self.AdminPublicPath = /public/tunegoMarketAdmin
        self.AdminStoragePath = /storage/tunegoMarketAdmin

        self.account.save<@Admin>(<- create Admin(), to: TuneGOMarket.AdminStoragePath)
        self.SupportedNFTTypes = [ Type<@TuneGO.NFT>(), Type<@TicalUniverse.NFT>() ]

        let initialMarketFee = MarketFee(
            receiver: self.account.address,
            percentage: UFix64(2.5)
        )
        self.TuneGOFee = initialMarketFee
        emit TuneGOMarketFeeSet(receiver: initialMarketFee.receiver, percentage: initialMarketFee.percentage)

        emit ContractInitialized()
    }
}
