/*

    BYC - Barter Yard Club

 */

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract BYC {

    // nfts that allow no fee barters
    pub var noFeeBarterNFTs: {String: PublicPath}

    // fees payable by token
    access(contract) var feeByTokenIdentifier: {String :UFix64}
    access(contract) var feeReceiverCapByIdentifier: {String: Capability<&AnyResource{FungibleToken.Receiver}>}

    // fees levied from barters are stored here
    access(contract) var feeVaultsByIdentifier: @{String: FungibleToken.Vault}
    access(contract) var FT_TOKEN_FEE_PERCENTAGE: UFix64

    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // PATHS
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    pub let BarterCollectionStoragePath: StoragePath
    pub let BarterCollectionPublicPath: PublicPath
    pub let BarterCollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath


    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // EVENTS
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    pub event BarterCreated(offerID: UInt64, offeringAddress: Address, counterpartyID: UInt64?, counterpartyAddress: Address?)
    pub event BarterExecuted(id: UInt64)
    pub event BarterDestroyed(id: UInt64)
    pub event FeePaid(amount: UFix64, type: String, payer: Address)


    pub event FeesAcceptedUpdated(identifier: String, fee: UFix64?)
    pub event NoFeeBarterNFTsUpdated(identifier: String)
    pub event NoFeeBarterNFTsRemoved(identifier: String)
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // STRUCTURES
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    pub struct FTMeta {
        pub let amount: UFix64?
        pub let providerType: String?
        pub let receiverType: String?
        pub let publicReceiverPath: String?

        init(_ asset: &FTAsset) {
            self.amount = asset.amount
            self.publicReceiverPath = asset.publicReceiverPath?.toString()
            if asset.providerCap != nil {
                self.providerType = asset.providerCap?.borrow()!!.getType().identifier
            } else {
                self.providerType = nil
            }
            if asset.receiverCap != nil {
                self.receiverType = asset.receiverCap?.borrow()!!.getType().identifier
            } else {
                self.receiverType = nil
            }
        }
    }

    pub struct NFTMeta {
        pub let id: UInt64?
        pub let providerType: String?
        pub let receiverType: String?
        pub let collectionPublicPath: String?

        init(_ asset: &NFTAsset) {
            self.id = asset.id
            self.collectionPublicPath = asset.collectionPublicPath?.toString()
            if asset.providerCap != nil {
                self.providerType = asset.providerCap?.borrow()!!.getType().identifier
            } else {
                self.providerType = nil
            }
            if asset.receiverCap != nil {
                self.receiverType = asset.receiverCap?.borrow()!!.getType().identifier
            } else {
                self.receiverType = nil
            }
        }
    }

    // FTAsset
    //
    // Everything required to send a fixed amount of FT from a provider to a receiver
    // if used as a requestedAssets it will have a receiver and amount and the provider will be passed in the transaction that settles the Barter
    // to check if the requested assets are owned by the specified account we also need to supply the path for the capability
    // the provider side is checked using providerIsValid()
    //
    pub struct FTAsset {
        pub(set) var providerCap: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>?
        pub(set) var receiverCap: Capability<&{FungibleToken.Receiver, FungibleToken.Balance}>?
        pub(set) var publicReceiverPath: PublicPath?

        pub let amount: UFix64?

        init(
            providerCap: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>?,
            receiverCap: Capability<&{FungibleToken.Receiver, FungibleToken.Balance}>?,
            amount: UFix64?,
            publicReceiverPath: PublicPath?
        ) {
            if providerCap != nil {
                assert(providerCap!.borrow() != nil, message: "Invalid FT provider Capability")
            }
            if receiverCap != nil {
                assert(receiverCap!.borrow() != nil, message: "Invaoid FT receiver Capability")
            }
            self.providerCap = providerCap
            self.receiverCap = receiverCap
            self.amount = amount
            self.publicReceiverPath = publicReceiverPath
        }

        pub fun providerIsValid(): Bool {
            assert(self.providerCap!.borrow() != nil, message: "invalid FT provider capability:".concat(self.providerCap!.getType().identifier) )
            assert(self.providerCap!.borrow()!.balance >= self.amount!, message: "Provider has insufficient tokens! Requested:".concat(self.amount!.toString()).concat("/").concat(self.providerCap?.borrow()!!.balance.toString().concat(" available!")) )
            return true
        }
        pub fun receiverIsValid(): Bool {
            assert(self.receiverCap?.borrow() != nil, message: "invalid receiver capability" )
            return true
        }
        pub fun isValid(): Bool {
            self.providerIsValid()
            self.receiverIsValid()
            return true
        }

        pub fun getMeta(): FTMeta {
            return FTMeta(&self as &FTAsset)
        }

        access(contract) fun transfer(_ waiveFee: Bool) {
            // levy fee
            var percentage = 1.0
            if !waiveFee {
                BYC.depositFees(<- self.providerCap!.borrow()!.withdraw(amount: self.amount! * BYC.FT_TOKEN_FEE_PERCENTAGE))
                percentage = 1.0 - BYC.FT_TOKEN_FEE_PERCENTAGE
            }
            // transfer amount minus fee
            self.receiverCap!.borrow()!.deposit(
                from: <- self.providerCap!.borrow()!.withdraw(
                    amount: self.amount! * (percentage)
                )
            )
        }
    }

    // NFT Asset Resource
    //
    // Contains everything required to send a NFT from a provider to a receiver.
    //
    pub struct NFTAsset {
        pub(set) var providerCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>?
        pub(set) var receiverCap: Capability<&{NonFungibleToken.CollectionPublic}>?
        pub let collectionPublicPath: PublicPath?
        pub let id: UInt64?

        init(
            providerCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>?,
            receiverCap: Capability<&{NonFungibleToken.CollectionPublic}>?,
            id: UInt64?,
            collectionPublicPath: PublicPath?
        ) {
            if providerCap != nil {
                assert(providerCap!.borrow() != nil, message: "Invalid NFT Provider Capability")
            }
            if receiverCap != nil {
                assert(receiverCap!.borrow() != nil, message: "Invalid NFT Receiver Capability")
            }
            self.providerCap = providerCap
            self.receiverCap = receiverCap
            self.id = id
            self.collectionPublicPath = collectionPublicPath
        }

        pub fun providerIsValid(): Bool {
            assert(self.providerCap?.borrow() != nil, message: "invalid provider capability" )
            assert(self.providerCap!.borrow()!.getIDs().contains(self.id!), message: "Provider does not have the requested NFT! Requested:".concat(self.id!.toString()))
            return true
        }
        // maybe change name to signify program stops running if invalid
        pub fun isValid(): Bool {
            assert(self.providerIsValid(), message: "invalid provider")
            assert(self.providerCap!.borrow()!.getType() == self.receiverCap!.borrow()!.getType(), message: "Provider and Receiver NFT capability types do not match")
            assert(self.receiverCap?.borrow() != nil, message: "invalid receiver capability" )
            return true
        }
        pub fun doesAddressOwnNFT(_ address: Address): Bool {
            let account = getAccount(address)
            let collectionRef = account.getCapability(self.collectionPublicPath!).borrow<&{NonFungibleToken.CollectionPublic}>()
            // return collectionRef!.getIDs().contains(self.id!)
            return collectionRef!.borrowNFT(id: self.id!) != nil
        }
        pub fun getMeta(): NFTMeta {
            return NFTMeta(&self as &NFTAsset)
        }

        access(contract) fun transfer() {
            self.receiverCap?.borrow()!!.deposit(token: <- self.providerCap?.borrow()!!.withdraw(withdrawID: self.id!))
        }
    }

    // Metadata details of a Barter
    //
    pub struct BarterMeta {
        pub let barterID: UInt64
        pub var counterpartyID: UInt64?
        pub let previousID: UInt64?

        pub let nftAssetsOffered: [NFTMeta]
        pub let ftAssetsOffered: [FTMeta]
        pub let nftAssetsRequested: [NFTMeta]
        pub let ftAssetsRequested: [FTMeta]

        pub let proposerFeeType: String
        pub let proposerFeeAmount: UFix64

        pub let offerAddress: Address
        pub let counterpartyAddress: Address?

        pub let expiresAt: UFix64

        init(_ barterRef: &Barter{BarterPublic}) {
            self.barterID = barterRef.uuid
            self.previousID = barterRef.previousID
            self.counterpartyID = barterRef.linkedID
            self.nftAssetsOffered = barterRef.getNFTAssetsOffered()
            self.ftAssetsOffered = barterRef.getFTAssetsOffered()
            self.nftAssetsRequested = barterRef.getNFTAssetsRequested()
            self.ftAssetsRequested = barterRef.getFTAssetsRequested()
            self.proposerFeeType = barterRef.getProposerFeeType().identifier
            self.proposerFeeAmount = barterRef.getProposerFeeAmount()
            self.offerAddress = barterRef.getOfferAddress()
            self.counterpartyAddress = barterRef.counterpartyAddress
            self.expiresAt = barterRef.expiresAt
        }
    }

    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // RESOURCES
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    // Barter Resource Interfaces
    //
    pub resource interface BarterPublic {
        pub let counterpartyAddress: Address?
        pub let previousID: UInt64?
        pub var linkedID: UInt64?
        pub let expiresAt: UFix64
        pub fun getMetadata(): BarterMeta
        pub fun getNFTAssetsOffered(): [NFTMeta]
        pub fun getFTAssetsOffered(): [FTMeta]
        pub fun getNFTAssetsRequested(): [NFTMeta]
        pub fun getFTAssetsRequested(): [FTMeta]
        pub fun getProposerFeeType(): Type
        pub fun getProposerFeeAmount(): UFix64
        pub fun getOfferAddress(): Address
    }

    // Barter Resource
    //
    // Held in the account of the creator = 'Proposer'
    //
    pub resource Barter: BarterPublic, IRestricted, MetadataViews.Resolver {
        pub let previousID: UInt64? // nil for new Barters, ID if barter is a response to a previous Barter
        pub var linkedID: UInt64? // two identical barters are stored, one in the offering users account and one in the accepting users account..
        pub let counterpartyAddress: Address?
        pub let expiresAt: UFix64

        // Assets involved in this Barter
        access(contract) let nftAssetsOffered: [NFTAsset]
        access(contract) let ftAssetsOffered: [FTAsset]
        access(contract) let nftAssetsRequested: [NFTAsset]
        access(contract) let ftAssetsRequested: [FTAsset]
        access(contract) let proposerFeeCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>

        // Resource initalization
        //
        init(
            ftAssetsOffered: [FTAsset],
            nftAssetsOffered: [NFTAsset],
            ftAssetsRequested: [FTAsset],
            nftAssetsRequested: [NFTAsset],
            counterpartyAddress: Address?,
            expiresAt: UFix64,
            previousBarterID: UInt64?,
            proposerFeeCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>
        ) {
            pre {
                expiresAt > getCurrentBlock().timestamp : "Expiry time must be in the future!"
                nftAssetsOffered.length > 0 || ftAssetsOffered.length > 0 : "Must offer at least 1 asset!"
            }
            let feeProviderRef = proposerFeeCapability.borrow() ?? panic("cannot borrow fee capability")
            assert(BYC.feeByTokenIdentifier[feeProviderRef.getType().identifier] != nil, message: "Fee capability provided is not of a supported type.")
            assert(feeProviderRef.balance > BYC.feeByTokenIdentifier[proposerFeeCapability.borrow()!.getType().identifier]!, message: "Account has insufficient funds to cover fees.")

            for asset in ftAssetsOffered {
                assert(asset.providerIsValid(), message: "Invalid FT Provider details detected ")
            }
            for asset in nftAssetsOffered {
                assert(asset.providerIsValid(), message: "Invalid NFT Provider details detected ")
            }
            for asset in ftAssetsRequested {
                // we only assert the receiver is of correct type not the balance of the account is sufficient as the offering party may wish to request more funds than the requesting party currently has in that particular account
                assert(asset.receiverIsValid(), message: "Invalid Requested FT details detected. ")
            }
            for asset in nftAssetsRequested {
                assert(asset.doesAddressOwnNFT(counterpartyAddress!), message: "Invalid Requested NFT details detected")
            }

            self.counterpartyAddress = counterpartyAddress
            self.previousID = previousBarterID
            self.linkedID = nil

            self.ftAssetsOffered = ftAssetsOffered
            self.nftAssetsOffered = nftAssetsOffered

            self.ftAssetsRequested = ftAssetsRequested
            self.nftAssetsRequested = nftAssetsRequested

            self.expiresAt = expiresAt

            self.proposerFeeCapability = proposerFeeCapability

        }

        // Accept Barter Function
        //
        // Caller must provide all necessary Caps (their Providers and counterpartyies CollectionPublic Receivers)
        // Once populated the barter is executed
        //
        access(contract) fun acceptBarter(
            offeredNFTReceiverCaps: [Capability<&AnyResource{NonFungibleToken.CollectionPublic}>],
            requestedNFTProviderCaps: [Capability<&AnyResource{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>],
            offeredFTReceiverCaps: [Capability<&AnyResource{FungibleToken.Receiver, FungibleToken.Balance}>],
            requestedFTProviderCaps: [Capability<&AnyResource{FungibleToken.Provider, FungibleToken.Balance}>],
            feeCapability: Capability<&AnyResource{FungibleToken.Provider}>
        ) {
            pre {
                getCurrentBlock().timestamp <= self.expiresAt : "Barter has expired."
                offeredFTReceiverCaps.length == self.ftAssetsOffered.length
                offeredNFTReceiverCaps.length == self.nftAssetsOffered.length : offeredNFTReceiverCaps.length.toString().concat(" ").concat(self.nftAssetsOffered.length.toString())
                requestedFTProviderCaps.length == self.ftAssetsRequested.length
                requestedNFTProviderCaps.length == self.nftAssetsRequested.length : requestedNFTProviderCaps.length.toString().concat(" ").concat(self.nftAssetsRequested.length.toString())
            }

            // add offer nft receiver caps
            for i, asset in self.nftAssetsOffered {
                self.nftAssetsOffered[i].receiverCap = offeredNFTReceiverCaps[i]
            }
            // add requested NFT Provider Caps
            for i, asset in self.nftAssetsRequested {
                self.nftAssetsRequested[i].providerCap = requestedNFTProviderCaps[i]
            }
            // add offered ft receiver caps
            for i, asset in self.ftAssetsOffered {
                self.ftAssetsOffered[i].receiverCap = offeredFTReceiverCaps[i]
            }
            // add requested ft provider caps
            for i, asset in self.ftAssetsRequested {
                self.ftAssetsRequested[i].providerCap = requestedFTProviderCaps[i]
            }

            // check both parties accounts for NFTs that allow free barters
            let acceptorAddress = feeCapability.address
            let proposerAddress = self.proposerFeeCapability.address

            var waiveProposerFee = false
            var waiveAcceptorFee = false

            // loop through all accepted nft identifiers and check if each party has any of those nfts
            for nftIdentifier in BYC.noFeeBarterNFTs.keys {
                let collectionPath = BYC.noFeeBarterNFTs[nftIdentifier]!
                waiveProposerFee = BYC.checkAddressOwnsNFT(address: proposerAddress, collectionPath: collectionPath, nftIdentifier: nftIdentifier) || waiveProposerFee // || to preserve previous loop checks
                waiveAcceptorFee = BYC.checkAddressOwnsNFT(address: acceptorAddress, collectionPath: collectionPath, nftIdentifier: nftIdentifier) || waiveAcceptorFee
                if waiveProposerFee && waiveAcceptorFee { break } // no need to check further
            }

            let acceptorFee = BYC.feeByTokenIdentifier[feeCapability.borrow()!.getType().identifier]!
            let proposerFee = BYC.feeByTokenIdentifier[self.proposerFeeCapability.borrow()!.getType().identifier]!

            // if for any reason these capabilities are unlinked or broken then the trade will fail!
            // perhaps better pattern to store fees in contract level dictionary and admin can withdraw at later date
            let proposerFeeReceiver = BYC.feeReceiverCapByIdentifier[self.proposerFeeCapability.borrow()!.getType().identifier]!.borrow()!
            let acceptorFeeReceiver = BYC.feeReceiverCapByIdentifier[feeCapability.borrow()!.getType().identifier]!.borrow()!

            // Each user pays a fee unless they have a BYC approved NFT
            if !waiveProposerFee {
                proposerFeeReceiver.deposit(from: <- feeCapability.borrow()!.withdraw(amount: proposerFee))
                emit FeePaid(amount: proposerFee, type: proposerFeeReceiver.getType().identifier, payer: feeCapability.address)
            }

            if !waiveAcceptorFee {
                acceptorFeeReceiver.deposit(from: <- self.proposerFeeCapability.borrow()!.withdraw(amount: acceptorFee))
                emit FeePaid(amount: acceptorFee, type: proposerFeeReceiver.getType().identifier, payer: self.proposerFeeCapability.address)
            }

            self.executeBarter(waiveProposerFee, waiveAcceptorFee)
        }

        // Execute Barter Function
        //
        // This function iterates through the assets sending them from provider to receiver
        // We can assert as we go through as the whole state reverts if any asset is not validated
        //
        access(contract) fun executeBarter(_ waiveProposerFee: Bool,_ waiveAcceptorFee: Bool) {
            for nft in self.nftAssetsOffered {
                assert(nft.isValid())
                nft.transfer()
            }
            for ft in self.ftAssetsOffered {
                assert(ft.isValid())
                ft.transfer(waiveProposerFee)
            }
            for nft in self.nftAssetsRequested {
                assert(nft.isValid())
                nft.transfer()
            }
            for ft in self.ftAssetsRequested {
                assert(ft.isValid())
                ft.transfer(waiveAcceptorFee)
            }
        }

        access(contract) fun setLinkedID(_ id: UInt64) {
            self.linkedID = id
        }

        pub fun getOfferAddress(): Address {
            return self.nftAssetsOffered.length > 0 ? self.nftAssetsOffered[0].providerCap!.address : self.ftAssetsOffered[0].providerCap!.address
        }

        pub fun getMetadata(): BarterMeta {
            return BarterMeta(&self as &Barter)
        }

        pub fun getNFTAssetsOffered(): [NFTMeta] {
            let assetsMeta: [NFTMeta] = []
            for asset in self.nftAssetsOffered {
                assetsMeta.append(asset.getMeta())
            }
            return assetsMeta
        }

        pub fun getFTAssetsOffered(): [FTMeta] {
            let assetsMeta: [FTMeta] = []
            for asset in self.ftAssetsOffered {
                assetsMeta.append(asset.getMeta())
            }
            return assetsMeta
        }

        pub fun getNFTAssetsRequested(): [NFTMeta] {
            let assetsMeta: [NFTMeta] = []
            for asset in self.nftAssetsRequested {
                assetsMeta.append(asset.getMeta())
            }
            return assetsMeta
        }

        pub fun getFTAssetsRequested(): [FTMeta] {
            let assetsMeta: [FTMeta] = []
            for asset in self.ftAssetsRequested {
                assetsMeta.append(asset.getMeta())
            }
            return assetsMeta
        }

        pub fun getProposerFeeType(): Type {
            return self.proposerFeeCapability.borrow()!.getType()
        }

        pub fun getProposerFeeAmount(): UFix64 {
            pre {
                self.proposerFeeCapability != nil
            }
            return BYC.feeByTokenIdentifier[self.proposerFeeCapability.borrow()!.getType().identifier]!
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<BarterMeta>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Barter Yard Club - ID#".concat(self.uuid.toString()),
                        description: "A Barter Yard Club - Barter resource, representing a Barter of NFTs and FTs between two parties.",
                        thumbnail: MetadataViews.HTTPFile(
                            url: "http://barteryard.club/images/BarterThumbnail.png"
                        )
                    )

                case Type<BarterMeta>():
                    return self.getMetadata()
           }
           return nil
        }

        destroy () {
            emit BarterDestroyed(id: self.uuid)
        }
    }

    // Barter Collection Interfaces
    //

    // two identical barters are stored, one in the offering users account and one in the accepting users account..
    // this id links them and the restricted interface is used internally to clean up the counterparty users barter
    // this allows the user to see all barters without relying on a backend
    pub resource interface IRestricted {
        pub var linkedID: UInt64?
    }

    pub resource interface BarterCollectionPublic {
        pub fun deposit(barter: @Barter)
        pub fun getIDs(): [UInt64]
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver}
        pub fun borrowBarter(id: UInt64): &Barter{BarterPublic}?
        pub fun clean(barterRef: &Barter{IRestricted}, id: UInt64)
        pub fun acceptBarter(
            id: UInt64,
            offeredNFTReceiverCaps: [Capability<&AnyResource{NonFungibleToken.CollectionPublic}>],
            requestedNFTProviderCaps: [Capability<&AnyResource{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>],
            offeredFTReceiverCaps: [Capability<&AnyResource{FungibleToken.Receiver, FungibleToken.Balance}>],
            requestedFTProviderCaps: [Capability<&AnyResource{FungibleToken.Provider, FungibleToken.Balance}>],
            feeCapability: Capability<&AnyResource{FungibleToken.Provider}>
        )
        pub fun counterBarter(
            barterAddress: Address,
            barterID: UInt64,
            ftAssetsOffered: [FTAsset],
            nftAssetsOffered: [NFTAsset],
            ftAssetsRequested: [FTAsset],
            nftAssetsRequested: [NFTAsset],
            expiresAt: UFix64,
            feeCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>
        ): @Barter
    }

    // Barter Collection Resource
    //
    // Lives in users account
    //
    pub resource BarterCollection: BarterCollectionPublic, MetadataViews.ResolverCollection  {
        access(contract) let barters: @{UInt64: Barter}

        init() {
            self.barters <- {}
        }

        destroy() {
            destroy self.barters
        }

        pub fun borrowBarter(id: UInt64): &Barter{BarterPublic}? {
            return &self.barters[id] as &Barter{BarterPublic}?
        }

        // public but access restricted by requiring matching reference
        pub fun clean(barterRef: &Barter{IRestricted}, id: UInt64) {
            if barterRef.uuid != self.barters[id]?.linkedID { return } // early return if referenced id not matching
            destroy <- self.barters.remove(key: id)
        }

        pub fun deposit(barter: @Barter) {
            self.barters[barter.uuid] <-! barter
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            return (&self.barters[id] as &{MetadataViews.Resolver}?)!
        }

        pub fun getIDs(): [UInt64] {
            return self.barters.keys
        }

        // Accept barter function
        //
        // takes a barterID, removes that Barter and calls the accept barter function on it then cleans up afterwards....
        // the Offered Receiver Caps and Requested Provider Caps are required to complete the barter
        //
        pub fun acceptBarter(
            id: UInt64,
            offeredNFTReceiverCaps: [Capability<&AnyResource{NonFungibleToken.CollectionPublic}>],
            requestedNFTProviderCaps: [Capability<&AnyResource{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>],
            offeredFTReceiverCaps: [Capability<&AnyResource{FungibleToken.Receiver, FungibleToken.Balance}>],
            requestedFTProviderCaps: [Capability<&AnyResource{FungibleToken.Provider, FungibleToken.Balance}>],
            feeCapability: Capability<&AnyResource{FungibleToken.Provider}>
        ) {

            let barter <- self.barters.remove(key: id)!

            barter.acceptBarter(    offeredNFTReceiverCaps: offeredNFTReceiverCaps,
                                    requestedNFTProviderCaps: requestedNFTProviderCaps,
                                    offeredFTReceiverCaps: offeredFTReceiverCaps,
                                    requestedFTProviderCaps: requestedFTProviderCaps,
                                    feeCapability: feeCapability)

            // add more info to event
            emit BarterExecuted(id: barter.uuid)

            for uuid in self.barters.keys {
                let barterRef = &self.barters[uuid] as &Barter?
                if barterRef!.previousID == barter.uuid {
                    let oldBarter <- self.barters.remove(key: uuid)!
                    let linkedCollection = getAccount(oldBarter.getOfferAddress()).getCapability(BYC.BarterCollectionPublicPath).borrow<&{BYC.BarterCollectionPublic}>()!
                    linkedCollection.clean(barterRef: &oldBarter as &Barter{IRestricted}, id: oldBarter.linkedID!)
                    destroy oldBarter
                }
            }
            // cleanup boths accounts
            let linkedCollection = getAccount(barter.getOfferAddress()).getCapability(BYC.BarterCollectionPublicPath).borrow<&{BYC.BarterCollectionPublic}>()!
            linkedCollection.clean(barterRef: &barter as &Barter{IRestricted}, id: barter.linkedID!)
            destroy barter
        }

        // counter barter function
        //
        // creates a new barter as a response to an existing barter
        //
        pub fun counterBarter(
            barterAddress: Address,
            barterID: UInt64,
            ftAssetsOffered: [FTAsset],
            nftAssetsOffered: [NFTAsset],
            ftAssetsRequested: [FTAsset],
            nftAssetsRequested: [NFTAsset],
            expiresAt: UFix64,
            feeCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>
        ): @Barter {

            let barterCollectionCap = getAccount(barterAddress).getCapability(BYC.BarterCollectionPublicPath)
            let barterCollectionRef = barterCollectionCap.borrow<&{BarterCollectionPublic}>()!
            let barterRef = barterCollectionRef.borrowBarter(id: barterID)!
            var counterpartyAddress = barterRef.getOfferAddress()
            let counterpartyCollection = getAccount(counterpartyAddress!).getCapability(BYC.BarterCollectionPublicPath).borrow<&{BYC.BarterCollectionPublic}>()!

            // If the caller is the counterparty reject the previous offer (they are responding to an offer)
            // if the caller is another address we just create a new barter with previousBarterID set to id of the barter being countered
            if (self.owner?.address == barterRef.counterpartyAddress) {
                // clean destroys the counter party barter
                counterpartyCollection.clean(barterRef: (&self.barters[barterID] as &Barter{IRestricted}?)!, id: barterRef.linkedID!)
                destroy <- self.barters.remove(key: barterID)
            }

            return <- BYC.createBarter(
                ftAssetsOffered: ftAssetsOffered,
                nftAssetsOffered: nftAssetsOffered,
                ftAssetsRequested: ftAssetsRequested,
                nftAssetsRequested: nftAssetsRequested,
                counterpartyAddress: counterpartyAddress,
                expiresAt: expiresAt,
                feeCapability: feeCapability,
                previousBarterID: barterID)
        }

        // Reject Barter
        //
        // This function is called to reject an offer received
        // Can also be used to cancel an offer made by the user
        //
        pub fun rejectBarter(id: UInt64) {
            pre {
                self.barters.containsKey(id) : "Barter with ID: ".concat(id.toString()).concat(" not found!")
            }
            let barterRef = (&self.barters[id] as &Barter?)!

            if barterRef.counterpartyAddress != nil { // if not a 1-sided barter proposal
                let callerIsCounterparty = self.owner?.address == barterRef.counterpartyAddress
                // check if caller is canceling offer they made or rejecting an offer received
                let linkedAddress = callerIsCounterparty ? barterRef.getOfferAddress() : barterRef.counterpartyAddress!
                let linkedCollection = getAccount(linkedAddress).getCapability(BYC.BarterCollectionPublicPath).borrow<&{BYC.BarterCollectionPublic}>()!
                linkedCollection.clean(barterRef: barterRef, id: barterRef.linkedID!)
            }

            destroy <- self.barters.remove(key: id)

        }
    }

    // Admin Resource
    //
    //
    pub resource Admin {
        //
        pub fun updateFeeByIdentifier(identifier: String, fee: UFix64, feeCap: Capability<&AnyResource{FungibleToken.Receiver}>) {
            BYC.feeReceiverCapByIdentifier[identifier] = feeCap
            BYC.feeByTokenIdentifier[identifier] = fee
            emit FeesAcceptedUpdated(identifier: identifier, fee: fee)
        }

        pub fun removeFeeByIdentifier(identifier: String) {
            pre {
                BYC.feeByTokenIdentifier[identifier] == nil : "Cannot find fee vault identifier: ".concat(identifier)
            }
            BYC.feeByTokenIdentifier[identifier] = nil
            BYC.feeReceiverCapByIdentifier[identifier] = nil
            emit FeesAcceptedUpdated(identifier: identifier, fee: nil)
        }

        //
        pub fun addNoFeeBarterNFT(identifier: String, collectionPath: PublicPath) {
            BYC.noFeeBarterNFTs[identifier] = collectionPath
            emit NoFeeBarterNFTsUpdated(identifier: identifier)
        }

        pub fun removeNoFeeBarterNFT(identifier: String) {
            pre {
                BYC.noFeeBarterNFTs[identifier] == nil : "Cannot find NFT identifier: ".concat(identifier)
            }
            BYC.noFeeBarterNFTs[identifier] = nil
            emit NoFeeBarterNFTsRemoved(identifier: identifier)
        }

        pub fun updateFungibleTokenFee(percentage: UFix64) {
            pre {
                percentage < 1.0 : "Fee must be less than 1.0 (100%)"
            }
            BYC.FT_TOKEN_FEE_PERCENTAGE = percentage
        }

        pub fun withdrawFees(identifier: String): @FungibleToken.Vault {
            return <- BYC.feeVaultsByIdentifier[identifier]?.withdraw!(amount: BYC.feeVaultsByIdentifier[identifier]?.balance!)
        }

    }

    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // PUBLIC FUNCTIONS
    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    // flexible create barter function that can:
    // 1. create a barter proposal if no counterparty is provided
    // 2. create 2 barters if counterparty already has barterCollection setup
    // 3. create 1 barter if counterparty doesn't have barterCollection setup

    pub fun createBarter(
        ftAssetsOffered: [FTAsset],
        nftAssetsOffered: [NFTAsset],
        ftAssetsRequested: [FTAsset],
        nftAssetsRequested: [NFTAsset],
        counterpartyAddress: Address?,
        expiresAt: UFix64,
        feeCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>,
        previousBarterID: UInt64?
    ): @Barter {

        pre {
            expiresAt >= getCurrentBlock().timestamp : "Expiry time must be in the future!"
        }

        if counterpartyAddress == nil { // create barter 1 sided 'proposal'
            let a <- create Barter(
                ftAssetsOffered: ftAssetsOffered,
                nftAssetsOffered: nftAssetsOffered,
                ftAssetsRequested: [],
                nftAssetsRequested: [],
                counterpartyAddress: nil,
                expiresAt: expiresAt,
                previousBarterID: previousBarterID,
                proposerFeeCapability: feeCapability
            )
            emit BarterCreated(
                offerID: a.uuid,
                offeringAddress: a.getOfferAddress(),
                counterpartyID: previousBarterID,
                counterpartyAddress: nil
            )
            return <- a
        }

        let remoteCollectionRef = getAccount(counterpartyAddress!).getCapability(BYC.BarterCollectionPublicPath).borrow<&{BarterCollectionPublic}>()
        if remoteCollectionRef != nil { // we send a linked copy of the Barter to the counterparty
            let a <- create Barter(
                ftAssetsOffered: ftAssetsOffered,
                nftAssetsOffered: nftAssetsOffered,
                ftAssetsRequested: ftAssetsRequested,
                nftAssetsRequested: nftAssetsRequested,
                counterpartyAddress: counterpartyAddress,
                expiresAt: expiresAt,
                previousBarterID: previousBarterID,
                proposerFeeCapability: feeCapability
            )
            assert(a.getOfferAddress() != counterpartyAddress, message:  "Provider of Assets cannot be the counter party") // we assert after so we can use the existing function

            let b <- create Barter(
                ftAssetsOffered: ftAssetsOffered,
                nftAssetsOffered: nftAssetsOffered,
                ftAssetsRequested: ftAssetsRequested,
                nftAssetsRequested: nftAssetsRequested,
                counterpartyAddress: counterpartyAddress,
                expiresAt: expiresAt,
                previousBarterID: previousBarterID,
                proposerFeeCapability: feeCapability
            )
            a.setLinkedID(b.uuid)
            b.setLinkedID(a.uuid)
            emit BarterCreated(
                offerID: a.uuid,
                offeringAddress: a.getOfferAddress(),
                counterpartyID: b.uuid,
                counterpartyAddress: counterpartyAddress
            )
            remoteCollectionRef!.deposit(barter: <- b)
            return <- a
        } else {  // we return a single Barter to the user making the offer..
            let a <- create Barter(
                ftAssetsOffered: ftAssetsOffered,
                nftAssetsOffered: nftAssetsOffered,
                ftAssetsRequested: ftAssetsRequested,
                nftAssetsRequested: nftAssetsRequested,
                counterpartyAddress: counterpartyAddress,
                expiresAt: expiresAt,
                previousBarterID: previousBarterID,
                proposerFeeCapability: feeCapability
            )
            emit BarterCreated(offerID: a.uuid, offeringAddress: a.getOfferAddress(), counterpartyID: nil, counterpartyAddress: counterpartyAddress)
            return <- a
        }
    }

    pub fun createEmptyCollection(): @BarterCollection {
        return <- create BarterCollection()
    }

    pub fun readFeesCollected(): {String:UFix64} {
        let fees: {String:UFix64} = {}
        for key in BYC.feeVaultsByIdentifier.keys {
            fees.insert(key: key, BYC.feeVaultsByIdentifier[key]?.balance!)
        }
        return fees
    }

    access(account) fun depositFees(_ fees: @FungibleToken.Vault) {
        let identifier = fees.getType().identifier
        if BYC.feeVaultsByIdentifier[identifier] == nil {
            BYC.feeVaultsByIdentifier[identifier] <-! fees
        } else {
            BYC.feeVaultsByIdentifier[identifier]?.deposit!(from: <- fees)
        }
    }

    //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    // Helper Functions
    //

    // used to check for NFTs that allow fees to be waived
    pub fun checkAddressOwnsNFT(address: Address, collectionPath: PublicPath, nftIdentifier: String): Bool {
        let collectionRef = getAccount(address).getCapability<&AnyResource{NonFungibleToken.CollectionPublic}>(collectionPath).borrow()
        if collectionRef == nil {
            return false
        }
        for id in collectionRef!.getIDs() {
            let nft = collectionRef!.borrowNFT(id: id)
            if nft.getType().identifier == nftIdentifier { return true }
        }
        return false
    }

    pub fun getFeesAccepted(): {String: UFix64} {
        return self.feeByTokenIdentifier
    }

    pub fun getNoFeeBarterNFTs(): [String] {
        return self.noFeeBarterNFTs.keys
    }

    init() {
        self.BarterCollectionStoragePath = /storage/BYC_Swap
        self.BarterCollectionPublicPath = /public/BYC_Swap
        self.BarterCollectionPrivatePath = /private/BYC_Swap
        self.AdminStoragePath = /storage/BYC_Admin

        self.feeVaultsByIdentifier <- {}
        self.FT_TOKEN_FEE_PERCENTAGE = 0.01

        self.feeByTokenIdentifier = {}
        self.feeReceiverCapByIdentifier = {}
        self.noFeeBarterNFTs = {}

        if self.account.borrow<&Admin>(from: BYC.AdminStoragePath) == nil {
            self.account.save(<- create Admin(), to: BYC.AdminStoragePath)
        }
    }
}
