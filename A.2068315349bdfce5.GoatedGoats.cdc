/*
    A NFT contract for the Goated Goats NFT.
    
    Key Callouts: 
    * Limit of 10,000 NFTs (Id 1-1,000)
    * Equip functionality to hold traits. When `equipped`, the old NFT is destroyed, and a new one created (new ID as well) - but with the same main Goat ID which is a separate metadata.
    * Unequip allows removing traits. When 'unequipped', the old NFT is destroyed, and a new one created (new ID as well) - but with the same main Goat ID which is a separate metadata
    * Redeemable by public function that accepts in a GoatedGoatsVouchers
    * Collection-level metadata (Name of collection, total supply, royalty information, etc)
    * Edition-level metadata (Base goat ipfs link, Base Goat color)
    * Edition-level traits metadata (Link of Trait slot (String) to GoatedGoatsTraits resource)
    * When equipped, or unequipped - keep a tally of how many actions have happened
    * When equip or unequip, allow for switching traits of 2,3,4 with 3,5,6 in one transaction (counting as a single action)
    * Hold timestamp of when last ChangeEquip action has occurred
*/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import GoatedGoatsTrait from 0x2068315349bdfce5
import MetadataViews from 0x1d7e57aa55817448

pub contract GoatedGoats: NonFungibleToken {
    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Events
    // -----------------------------------------------------------------------

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    // -----------------------------------------------------------------------
    // GoatedGoats Events
    // -----------------------------------------------------------------------

    pub event Mint(id: UInt64)
    pub event Burn(id: UInt64)

    // -----------------------------------------------------------------------
    // Named Paths
    // -----------------------------------------------------------------------

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Fields
    // -----------------------------------------------------------------------

    pub var totalSupply: UInt64

    // -----------------------------------------------------------------------
    // GoatedGoats Fields
    // -----------------------------------------------------------------------
    pub var name: String

    access(self) var collectionMetadata: { String: String }
    // NOTE: This is a map of goatID to metadata, unlike other contracts here that map with editionID
    access(self) let idToGoatMetadata: { UInt64: GoatMetadata }
    access(self) let editionIDToGoatID: { UInt64: UInt64 }

    pub struct GoatMetadata {
        pub let metadata: { String: String }
        pub let traitSlots: UInt8

        init(metadata: { String: String }, traitSlots: UInt8) {
            self.metadata = metadata
            self.traitSlots = traitSlots
        }
    }

    pub resource NFT : NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let goatID: UInt64
        // The following 4 can be constants as they are only updated on burn/mints
        // Keeps count of how many trait actions have taken place on this goat, e.g. equip/unequip
        pub let traitActions: UInt64
        // Last time a traitAction took place.
        pub let lastTraitActionDate: UFix64
        // Time the goat was created independent of equip/unequip.
        pub let goatCreationDate: UFix64
        // Map of traits to GoatedGoatsTrait NFTs.
        // There can only be one Trait per slot.
        access(account) let traits: @{String: GoatedGoatsTrait.NFT}

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Royalties>()
            ]
        }

                access(account) fun removeTrait(_ key: String) : @GoatedGoatsTrait.NFT? {
                    return <- self.traits.remove(key: key)
                }

                access(account) fun setTrait( key: String, value: @GoatedGoatsTrait.NFT?) : @GoatedGoatsTrait.NFT? {
                    let old <- self.traits[key] <- value
                    return <- old
                }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let metadata= self.getMetadata()
            switch view {
                //init(name: String, value: AnyStruct, displayType: String?, rarity: Rarity?) {
                case Type<MetadataViews.Traits>():
                    let traits : [MetadataViews.Trait] =[]
                    if let slots = self.getTraitSlots() {
                        traits.append(MetadataViews.Trait(name:"TraitSlots", value: slots , displayType:"Number", rarity: nil))
                    }
                    if let skinFileName = metadata["skinFileName"] {
                        let skin = GoatedGoats.formatFileName(value: skinFileName, prefix:"skin")
                        let skinRarity = metadata["skinRarity"]!
                        traits.append(MetadataViews.Trait(name:"Skin", value: skin, displayType:"String", rarity: MetadataViews.Rarity(score:nil, max:nil, description: skinRarity)))
                    }

                    for traitSlot in self.traits.keys {
                        let ref = (&self.traits[traitSlot] as &GoatedGoatsTrait.NFT?)!
                        let metadata = ref.getMetadata()
                        let traitSlotName = metadata["traitSlot"]!
                        let traitName = GoatedGoats.formatFileName(value: metadata["fileName"]!, prefix: traitSlotName)
                        
                        traits.append(MetadataViews.Trait(name:traitSlot, value: traitName, displayType:"String", rarity: MetadataViews.Rarity(score:nil, max:nil, description: metadata["rarity"]!)))
                    }

                    return MetadataViews.Traits(traits)


                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                                        storagePath: GoatedGoats.CollectionStoragePath, 
                                        publicPath: GoatedGoats.CollectionPublicPath, 
                                        providerPath: /private/GoatCollection, 
                                        publicCollection: Type<&GoatedGoats.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, GoatedGoats.GoatCollectionPublic, MetadataViews.ResolverCollection}>(),
                                        publicLinkedType: Type<&GoatedGoats.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, GoatedGoats.GoatCollectionPublic, MetadataViews.ResolverCollection}>(), 
                                        providerLinkedType: Type<&GoatedGoats.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, GoatedGoats.GoatCollectionPublic, MetadataViews.ResolverCollection}>(), createEmptyCollectionFunction: fun(): @NonFungibleToken.Collection {return <- GoatedGoats.createEmptyCollection()})

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let externalURL = MetadataViews.ExternalURL("https://goatedgoats.com")
                    let squareImage = MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://goatedgoats.com/_ipx/w_32,q_75/%2FLogo.png?url=%2FLogo.png&w=32&q=75"), mediaType: "image/png")

                    let bannerImage = MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://goatedgoats.com/_ipx/w_32,q_75/%2FLogo.png?url=%2FLogo.png&w=32&q=75"), mediaType: "image/png")

                    let socialMap : {String : MetadataViews.ExternalURL} = {
                        "twitter" : MetadataViews.ExternalURL("https://twitter.com/goatedgoats")
                    }
                    return MetadataViews.NFTCollectionDisplay(name: "GoatedGoats", description: "GoatedGoats", externalURL: externalURL, squareImage: squareImage, bannerImage: bannerImage, socials: socialMap)


                case Type<MetadataViews.Display>():
                    var ipfsImage = MetadataViews.IPFSFile(cid: "No thumbnail cid set", path: "No thumbnail pat set")
                    if (metadata.containsKey("thumbnailCID")) {
                        ipfsImage = MetadataViews.IPFSFile(cid: metadata["thumbnailCID"]!, path: metadata["thumbnailPath"])
                    }
                    return MetadataViews.Display(
                        name: metadata["name"] ?? "Goated Goat ".concat(self.goatID.toString()),
                        description: metadata["description"] ?? "No description set",
                        thumbnail: ipfsImage
                    )
                
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(
                        "https://GoatedGoats.com"
                    )
                
                case Type<MetadataViews.Royalties>():
                    let royaltyReceiver = getAccount(0xd7081a5c66dc3e7f).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

                    return MetadataViews.Royalties(
                        [MetadataViews.Royalty(recepient: royaltyReceiver, cut: 0.05, description: "This is the royalty receiver for goats")]
                    )
            }

            return nil
        }

        pub fun getMetadata(): {String: String} {
            if (GoatedGoats.idToGoatMetadata[self.goatID] != nil) {
                return GoatedGoats.idToGoatMetadata[self.goatID]!.metadata
            } else {
                return {}
            }
        }

        pub fun getTraitSlots(): UInt8? {
            if (GoatedGoats.idToGoatMetadata[self.goatID] != nil) {
                return GoatedGoats.idToGoatMetadata[self.goatID]!.traitSlots
            } else {
                return nil
            }
        }

        // Check if a trait name is currently equipped on this goat.
        pub fun isTraitEquipped(traitSlot: String): Bool {
            return self.traits.containsKey(traitSlot)
        }

        // Get metadata for all traits currently equipped on the NFT.
        pub fun getEquippedTraits(): [{String: AnyStruct}] {
            let traitsData: [{String: AnyStruct}] = []
            for traitSlot in self.traits.keys {
                let ref = (&self.traits[traitSlot] as &GoatedGoatsTrait.NFT?)!
                let map: {String: AnyStruct} = {}
                map["traitID"] = ref.id
                map["traitPackID"] = ref.packID
                map["traitEditionMetadata"] = ref.getMetadata()
                traitsData.append(map)
            }
            return traitsData
        }
        
        init(id: UInt64, goatID: UInt64, traitActions: UInt64, goatCreationDate: UFix64, lastTraitActionDate: UFix64) {
            self.id = id
            self.goatID = goatID
            self.traitActions = traitActions
            self.goatCreationDate = goatCreationDate
            self.lastTraitActionDate = lastTraitActionDate
            self.traits <- {}
            // Map the edition ID to goat ID
            GoatedGoats.editionIDToGoatID.insert(key: id, goatID)
            emit Mint(id: self.id)
        }

        destroy() {
            assert(self.traits.length == 0, message: "Can not destroy Goat that has equipped traits.")
            destroy self.traits
            emit Burn(id: self.id)
        }
    }

    pub resource interface GoatCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun getGoatIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowGoat(id: UInt64): &GoatedGoats.NFT? {
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow GoatedGoats reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: GoatCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @GoatedGoats.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun getGoatIDs(): [UInt64] {
            let goatIDs: [UInt64] = []
            for id in self.getIDs() {
                goatIDs.append(self.borrowGoat(id: id)!.goatID)
            }
            return goatIDs
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowGoat(id: UInt64): &GoatedGoats.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &GoatedGoats.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let goat = nft as! &GoatedGoats.NFT
            return goat as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // -----------------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------------
    access(account) fun setEditionMetadata(goatID: UInt64, metadata: {String: String}, traitSlots: UInt8) {
        self.idToGoatMetadata[goatID] = GoatMetadata(metadata: metadata, traitSlots: traitSlots)
    }

    access(account) fun setCollectionMetadata(metadata: {String: String}) {
        self.collectionMetadata = metadata
    }

    access(account) fun mint(nftID: UInt64, goatID: UInt64, traitActions: UInt64, goatCreationDate: UFix64, lastTraitActionDate: UFix64) : @NonFungibleToken.NFT {
        self.totalSupply = self.totalSupply + 1
        return <-create NFT(id: nftID, goatID: goatID, traitActions: traitActions, goatCreationDate: goatCreationDate, lastTraitActionDate: lastTraitActionDate)
    }

    // -----------------------------------------------------------------------
    // Public Functions
    // -----------------------------------------------------------------------
    pub fun getTotalSupply(): UInt64 {
        return self.totalSupply
    }

    pub fun getName(): String {
        return self.name
    }

    pub fun getCollectionMetadata(): {String: String} {
        return self.collectionMetadata
    }

    pub fun getEditionMetadata(_ goatID: UInt64): {String: String} {
        if (self.idToGoatMetadata[goatID] != nil) {
            return self.idToGoatMetadata[goatID]!.metadata
        } else {
            return {}
        }
    }
     
    pub fun getEditionTraitSlots(_ goatID: UInt64): UInt8? {
        if (self.idToGoatMetadata[goatID] != nil) {
            return self.idToGoatMetadata[goatID]!.traitSlots
        } else {
            return nil
        }
    }

    access(contract) fun formatFileName(value:String, prefix:String):String {
        let length= value.length
        let start=prefix.length+1
        let trimmed = value.slice(from:start, upTo: length-4)
        return  trimmed
    }

    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Functions
    // -----------------------------------------------------------------------
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    init() {
        self.name = "Goated Goats"
        self.totalSupply = 0

        self.collectionMetadata = {}
        self.idToGoatMetadata = {}
        self.editionIDToGoatID = {}

        self.CollectionStoragePath = /storage/GoatCollection
        self.CollectionPublicPath = /public/GoatCollection

        emit ContractInitialized()
    }
}
 
