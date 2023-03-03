import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import CollecticoRoyalties from 0xffe32280cd5b72a3
import CollecticoStandardNFT from 0x11cbef9729b236f3
import CollecticoStandardViews from 0x11cbef9729b236f3
import CollectionResolver from 0x11cbef9729b236f3

/*
    General Purpose Collection
    (c) CollecticoLabs.com
 */
pub contract OGs: NonFungibleToken, CollecticoStandardNFT, CollectionResolver {
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, itemId: UInt64, serialNumber: UInt64)
    pub event Claimed(id: UInt64, itemId: UInt64, claimId: String)
    pub event Destroyed(id: UInt64, itemId: UInt64, serialNumber: UInt64)
    pub event ItemCreated(id: UInt64, name: String)
    pub event ItemDeleted(id: UInt64)
    pub event CollectionMetadataUpdated(keys: [String])
    pub event NewAdminCreated(receiver: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionProviderPath: PrivatePath
    pub let AdminStoragePath: StoragePath
    
    pub var totalSupply: UInt64
    pub let contractName: String

    access(self) var items: @{UInt64: Item}
    access(self) var nextItemId: UInt64

    access(self) var metadata: {String: AnyStruct}

    access(self) var claims: {String: Bool}

    access(self) var defaultRoyalties: [MetadataViews.Royalty]

    // for the future use
    access(self) var nftViewResolvers: @{String: AnyResource{CollecticoStandardViews.NFTViewResolver}} 
    access(self) var itemViewResolvers: @{String: AnyResource{CollecticoStandardViews.ItemViewResolver}}

    pub fun getViews(): [Type] {
        return [
            Type<MetadataViews.Display>(),
            Type<MetadataViews.ExternalURL>(),
            Type<MetadataViews.NFTCollectionDisplay>(),
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.Royalties>(),
            Type<MetadataViews.License>(),
            Type<CollecticoStandardViews.ContractInfo>()
        ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.Display>():
                return MetadataViews.Display(
                    name: self.metadata["name"]! as! String,
                    description: self.metadata["description"]! as! String,
                    thumbnail: (self.metadata["squareImage"]! as! MetadataViews.Media).file
                )
            case Type<MetadataViews.ExternalURL>():
                return self.getExternalURL()
            case Type<MetadataViews.NFTCollectionDisplay>():
                return self.getCollectionDisplay()
            case Type<MetadataViews.NFTCollectionData>():
                return self.getCollectionData()
            case Type<MetadataViews.Royalties>():
                return MetadataViews.Royalties(
                    self.defaultRoyalties.concat(CollecticoRoyalties.getIssuerRoyalties())
                )
            case Type<MetadataViews.License>():
                let licenseId: String? = self.metadata["_licenseId"] as! String?
                return licenseId != nil ? MetadataViews.License(licenseId!) : nil
            case Type<CollecticoStandardViews.ContractInfo>():
                return self.getContractInfo()
        }
        return nil
    }

    pub resource Item: CollecticoStandardNFT.IItem, MetadataViews.Resolver {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let thumbnail: AnyStruct{MetadataViews.File}
        pub let metadata: {String: AnyStruct}?
        pub let maxSupply: UInt64?
        pub let royalties: MetadataViews.Royalties?
        pub var numMinted: UInt64
        pub var numDestroyed: UInt64
        pub var isLocked: Bool
        pub let isTransferable: Bool
        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: AnyStruct{MetadataViews.File},
            metadata: {String: AnyStruct}?,
            maxSupply: UInt64?,
            isTransferable: Bool,
            royalties: [MetadataViews.Royalty]?
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.metadata = metadata
            self.maxSupply = maxSupply
            self.isTransferable = isTransferable
            if royalties != nil && royalties!.length > 0 {
                self.royalties = MetadataViews.Royalties(royalties!.concat(CollecticoRoyalties.getIssuerRoyalties()))
            } else {
                let defaultRoyalties = OGs.defaultRoyalties.concat(CollecticoRoyalties.getIssuerRoyalties())
                if defaultRoyalties.length > 0 {
                    self.royalties = MetadataViews.Royalties(defaultRoyalties)
                } else {
                    self.royalties = nil
                }
            }
            self.numMinted = 0
            self.numDestroyed = 0
            self.isLocked = false
        }

        access(contract) fun incrementNumMinted() {
            self.numMinted = self.numMinted + 1
        }

        access(contract) fun incrementNumDestroyed() {
            self.numDestroyed = self.numDestroyed + 1
        }

        access(contract) fun lock() {
            self.isLocked = true
        }

        pub fun getTotalSupply(): UInt64 {
            return self.numMinted - self.numDestroyed
        }

        pub fun getViews(): [Type] {
            return [
                Type<CollecticoStandardViews.ItemView>(),
                Type<CollecticoStandardViews.ContractInfo>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Medias>(),
                Type<MetadataViews.License>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<CollecticoStandardViews.ItemView>():
                    return CollecticoStandardViews.ItemView(
                        id: self.id,
                        name: self.name,
                        description: self.description,
                        thumbnail: self.thumbnail,
                        metadata: self.metadata,
                        totalSupply: self.getTotalSupply(),
                        maxSupply: self.maxSupply,
                        isLocked: self.isLocked,
                        isTransferable: self.isTransferable,
                        contractInfo: OGs.getContractInfo(),
                        collectionDisplay: OGs.getCollectionDisplay(),
                        royalties: MetadataViews.getRoyalties(&self as &OGs.Item{MetadataViews.Resolver}),
                        display: MetadataViews.getDisplay(&self as &OGs.Item{MetadataViews.Resolver}),
                        traits: MetadataViews.getTraits(&self as &OGs.Item{MetadataViews.Resolver}),
                        medias: MetadataViews.getMedias(&self as &OGs.Item{MetadataViews.Resolver}),
                        license: MetadataViews.getLicense(&self as &OGs.Item{MetadataViews.Resolver})
                    )
                case Type<CollecticoStandardViews.ContractInfo>():
                    return OGs.getContractInfo()
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: self.thumbnail
                    )
                case Type<MetadataViews.Traits>():
                    return OGs.dictToTraits(dict: self.metadata, excludedNames: nil)
                case Type<MetadataViews.Royalties>():
                    return self.royalties
                case Type<MetadataViews.Medias>():
                    return OGs.dictToMedias(dict: self.metadata, excludedNames: nil)
                case Type<MetadataViews.License>():
                    var licenseId: String? = OGs.getDictValue(dict: self.metadata, key: "_licenseId", type: Type<String>()) as! String?
                    if licenseId == nil {
                        licenseId = OGs.getDictValue(dict: OGs.metadata, key: "_licenseId", type: Type<String>()) as! String?
                    }
                    return licenseId != nil ? MetadataViews.License(licenseId!) : nil
                case Type<MetadataViews.ExternalURL>():
                    return OGs.getExternalURL()
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return OGs.getCollectionDisplay()
                case Type<MetadataViews.NFTCollectionData>():
                    return OGs.getCollectionData()
            }
            return nil
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let itemId: UInt64
        pub let serialNumber: UInt64
        pub let metadata: {String: AnyStruct}?
        pub let royalties: MetadataViews.Royalties? // reserved for the fututure use
        pub var isTransferable: Bool

        init(
            id: UInt64,
            itemId: UInt64,
            serialNumber: UInt64,
            isTransferable: Bool,
            metadata: {String: AnyStruct}?,
            royalties: [MetadataViews.Royalty]?
        ) {
            self.id = id
            self.itemId = itemId
            self.serialNumber = serialNumber
            self.isTransferable = isTransferable
            self.metadata = metadata
            if royalties != nil && royalties!.length > 0 {
                self.royalties = MetadataViews.Royalties(royalties!.concat(CollecticoRoyalties.getIssuerRoyalties()))
            } else {
                self.royalties = nil // it will fallback to the item's royalties
            }
            emit Minted(id: id, itemId: itemId, serialNumber: serialNumber)
        }

        destroy() {
            let item = OGs.getItemRef(itemId: self.itemId)
            item.incrementNumDestroyed()
            emit Destroyed(id: self.id, itemId: self.itemId, serialNumber: self.serialNumber)
        }

    
        pub fun getViews(): [Type] {
            return [
                Type<CollecticoStandardViews.NFTView>(),
                Type<CollecticoStandardViews.ContractInfo>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Medias>(),
                Type<MetadataViews.License>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let item = OGs.getItemRef(itemId: self.itemId)
            switch view {
                case Type<CollecticoStandardViews.NFTView>():
                    return CollecticoStandardViews.NFTView(
                        id: self.id,
                        itemId: self.itemId,
                        itemName: item.name.concat(" #").concat(self.serialNumber.toString()),
                        itemDescription: item.description,
                        itemThumbnail: item.thumbnail,
                        itemMetadata: item.metadata,
                        serialNumber: self.serialNumber,
                        metadata: self.metadata,
                        itemTotalSupply: item.getTotalSupply(),
                        itemMaxSupply: item.maxSupply,
                        isTransferable: self.isTransferable,
                        contractInfo: OGs.getContractInfo(),
                        collectionDisplay: OGs.getCollectionDisplay(),
                        royalties: MetadataViews.getRoyalties(&self as &OGs.NFT{MetadataViews.Resolver}),
                        display: MetadataViews.getDisplay(&self as &OGs.NFT{MetadataViews.Resolver}),
                        traits: MetadataViews.getTraits(&self as &OGs.NFT{MetadataViews.Resolver}),
                        editions: MetadataViews.getEditions(&self as &OGs.NFT{MetadataViews.Resolver}),
                        medias: MetadataViews.getMedias(&self as &OGs.NFT{MetadataViews.Resolver}),
                        license: MetadataViews.getLicense(&self as &OGs.NFT{MetadataViews.Resolver})
                    )
                case Type<CollecticoStandardViews.ContractInfo>():
                    return OGs.getContractInfo()
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: item.name.concat(" #").concat(self.serialNumber.toString()),
                        description: item.description,
                        thumbnail: item.thumbnail
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.Editions>():
                    let editionInfo = MetadataViews.Edition(name: item.name, number: self.serialNumber, max: item.maxSupply)
                    return MetadataViews.Editions([editionInfo])
                case Type<MetadataViews.Traits>():
                    let mergedMetadata = OGs.mergeDicts(item.metadata, self.metadata)
                    return OGs.dictToTraits(dict: mergedMetadata, excludedNames: nil)
                case Type<MetadataViews.Royalties>():
                    return self.royalties != nil ? self.royalties : item.royalties
                case Type<MetadataViews.Medias>():
                    return OGs.dictToMedias(dict: item.metadata, excludedNames: nil)
                case Type<MetadataViews.License>():
                    return MetadataViews.getLicense(item as &OGs.Item{MetadataViews.Resolver})
                case Type<MetadataViews.ExternalURL>():
                    return OGs.getExternalURL()
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return OGs.getCollectionDisplay()
                case Type<MetadataViews.NFTCollectionData>():
                    return OGs.getCollectionData()
            }
            return nil
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowCollecticoNFT(id: UInt64): &OGs.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow CollecticoNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            // Borrow nft and check if locked
            let nft = self.borrowCollecticoNFT(id: withdrawID) ?? panic("Requested NFT does not exist in the collection")
            if !nft.isTransferable {
                panic("Cannot withdraw: NFT is not transferable (Soulbound)")
            }

            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Requested NFT does not exist in the collection")
            
            emit Withdraw(id: token.id, from: self.owner?.address)

            return <- token
        }

        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            // Create a new empty Collection
            var batchCollection <- create Collection()
            
            // Iterate through the ids and withdraw them from the Collection
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            
            // Return the withdrawn tokens
            return <-batchCollection
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @OGs.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {

            // Get an array of the IDs to be deposited
            let keys = tokens.getIDs()

            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the empty Collection
            destroy tokens
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
 
        pub fun borrowCollecticoNFT(id: UInt64): &OGs.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &OGs.NFT
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let collecticoNFT = nft as! &OGs.NFT
            return collecticoNFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun getAllItemsRef(): [&Item] {
        let resultItems: [&Item] = []
        for key in self.items.keys {
            let item = self.getItemRef(itemId: key)
            resultItems.append(item)
        }
        return resultItems
    }

    pub fun getAllItems(view: Type): [AnyStruct] {
        let resultItems: [AnyStruct] = []
        for key in self.items.keys {
            let item = self.getItemRef(itemId: key)
            let itemView = item.resolveView(view)
            if (itemView == nil) {
                return [] // Unsupported view
            }
            resultItems.append(itemView!)
        }
        return resultItems
    }

    pub fun getItemRef(itemId: UInt64): &Item {
        pre {
            self.items[itemId] != nil: "Item doesn't exist"
        }
        let item = &self.items[itemId] as &Item?
        return item!
    }

    pub fun getItem(itemId: UInt64, view: Type): AnyStruct? {
        pre {
            self.items[itemId] != nil : "Item doesn't exist"
        }
        let item: &Item{MetadataViews.Resolver} = self.getItemRef(itemId: itemId)
        return item.resolveView(view)
    }

    pub fun isClaimed(claimId: String): Bool {
        return self.claims.containsKey(claimId);
    }

    pub fun areClaimed(claimIds: [String]): {String: Bool} {
        let res: {String: Bool} = {}
        for claimId in claimIds {
            res.insert(key: claimId, self.isClaimed(claimId: claimId))
        }
        return res
    }

    pub fun countNFTsMintedPerItem(itemId: UInt64): UInt64 {
        let item = self.getItemRef(itemId: itemId)
        return item.numMinted;
    }

    pub fun countNFTsDestroyedPerItem(itemId: UInt64): UInt64 {
        let item = self.getItemRef(itemId: itemId)
        return item.numDestroyed;
    }

    pub fun isItemSupplyValid(itemId: UInt64): Bool {
         let item = self.getItemRef(itemId: itemId)
         return item.maxSupply == nil || item.getTotalSupply() <= item.maxSupply!
    }

    pub fun isItemLocked(itemId: UInt64): Bool {
        let item = self.getItemRef(itemId: itemId)
        return item.isLocked
    }
    
    pub fun assertCollectionMetadataIsValid() {
        // assert display data:
        self.assertDictEntry(self.metadata, "name", Type<String>(), true)
        self.assertDictEntry(self.metadata, "description", Type<String>(), true)
        self.assertDictEntry(self.metadata, "externalURL", Type<MetadataViews.ExternalURL>(), true)
        self.assertDictEntry(self.metadata, "squareImage", Type<MetadataViews.Media>(), true)
        self.assertDictEntry(self.metadata, "bannerImage", Type<MetadataViews.Media>(), true)
        self.assertDictEntry(self.metadata, "socials", Type<{String: MetadataViews.ExternalURL}>(), true)
        self.assertDictEntry(self.metadata, "_licenseId", Type<String>(), false)
    }

    pub fun getExternalURL() : MetadataViews.ExternalURL {
        return self.metadata["externalURL"]! as! MetadataViews.ExternalURL
    }

    pub fun getContractInfo() : CollecticoStandardViews.ContractInfo {
        return CollecticoStandardViews.ContractInfo(
            name: self.contractName,
            address: self.account.address
        )
    }

    pub fun getCollectionDisplay() : MetadataViews.NFTCollectionDisplay {
        return MetadataViews.NFTCollectionDisplay(
            name: self.metadata["name"]! as! String,
            description: self.metadata["description"]! as! String,
            externalURL: self.metadata["externalURL"]! as! MetadataViews.ExternalURL,
            squareImage: self.metadata["squareImage"]! as! MetadataViews.Media,
            bannerImage: self.metadata["bannerImage"]! as! MetadataViews.Media,
            socials: self.metadata["socials"]! as! {String: MetadataViews.ExternalURL}
        )
    }

    pub fun getCollectionData() : MetadataViews.NFTCollectionData {
        return MetadataViews.NFTCollectionData(
            storagePath: self.CollectionStoragePath,
            publicPath: self.CollectionPublicPath,
            providerPath: self.CollectionProviderPath,
            publicCollection: Type<&OGs.Collection{OGs.CollectionPublic}>(),
            publicLinkedType: Type<&OGs.Collection{OGs.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&OGs.Collection{OGs.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                return <-OGs.createEmptyCollection()
            })
        )
    }

    pub fun assertItemMetadataIsValid(itemId: UInt64) {
        let item = self.getItemRef(itemId: itemId)
        self.assertDictEntry(item.metadata, "_licenseId", Type<String>(), false)
    }

    pub fun assertDictEntry(_ dict: {String: AnyStruct}?, _ key: String, _ type: Type, _ required: Bool) {
        if dict != nil {
            self.assertValueAndType(name: key, value: dict![key], type: type, required: required)
        }
    }

    pub fun assertValueAndType(name: String, value: AnyStruct?, type: Type, required: Bool) {
        if required {
            assert(value != nil, message: "Missing required value for '".concat(name).concat("'"))
        }
        if value != nil {
            assert(value!.isInstance(type),
                message: "Incorrect type for '"
                    .concat(name).concat("' - expected ")
                    .concat(type.identifier)
                    .concat(", got ")
                    .concat(value!.getType().identifier)
            )
        }
    }

    pub fun getDictValue(dict: {String: AnyStruct}?, key: String, type: Type): AnyStruct? {
        if dict == nil || dict![key] == nil || !dict![key]!.isInstance(type) {
            return nil
        }
        return dict![key]!
    }

    pub fun dictToTraits(dict: {String: AnyStruct}?, excludedNames: [String]?): MetadataViews.Traits? {
        let traits = self.dictToTraitArray(dict: dict, excludedNames: excludedNames)
        return traits.length != 0 ? MetadataViews.Traits(traits) : nil
    }

    pub fun dictToTraitArray(dict: {String: AnyStruct}?, excludedNames: [String]?): [MetadataViews.Trait] {
        if dict == nil {
            return []
        }
        let dictionary = dict!
        if excludedNames != nil {
            for k in excludedNames! {
                dictionary.remove(key: k)
            }
        }
        let traits: [MetadataViews.Trait] = []
        for k in dictionary.keys {
            if dictionary[k] == nil || k.length < 1 || k[0] == "_" { // key starts with '_' character or value is nil
                continue
            }
            if dictionary[k]!.isInstance(Type<MetadataViews.Trait>()) {
                traits.append(dictionary[k]! as! MetadataViews.Trait)
            } else if dictionary[k]!.isInstance(Type<String>()) {
                traits.append(MetadataViews.Trait(name: k, value: dictionary[k]!, displayType: nil, rarity: nil))
            } else if dictionary[k]!.isInstance(Type<{String: AnyStruct?}>()) { 
                // {String: AnyStruct?} just in case and for explicity, it's not needed as of now, {String: AnyStruct} works as well
                let trait: {String: AnyStruct?} = dictionary[k]! as! {String: AnyStruct?}
                var displayType: String? = nil
                var rarity: MetadataViews.Rarity? = nil
                // Purposefully checking and casting to String? instead of String due to rare cases
                // when displayType != nil AND all the other fields == nil 
                // then the type of such dictionary is {String: String?} instead of {String: String}
                if trait["displayType"] != nil && trait["displayType"]!.isInstance(Type<String?>()) {
                    displayType = trait["displayType"]! as! String?
                }
                // Purposefully checking and casting to MetadataViews.Rarity? instead of MetadataViews.Rarity- see reasoning above
                if trait["rarity"] != nil && trait["rarity"]!.isInstance(Type<MetadataViews.Rarity?>()) {
                    rarity = trait["rarity"]! as! MetadataViews.Rarity?
                }
                traits.append(MetadataViews.Trait(name: k, value: trait["value"], displayType: displayType, rarity: rarity))
            }
        }
        return traits
    }

    pub fun dictToMedias(dict: {String: AnyStruct}?, excludedNames: [String]?): MetadataViews.Medias? {
        let medias = self.dictToMediaArray(dict: dict, excludedNames: excludedNames)
        return medias.length != 0 ? MetadataViews.Medias(medias) : nil
    }

    pub fun dictToMediaArray(dict: {String: AnyStruct}?, excludedNames: [String]?): [MetadataViews.Media] {
        if dict == nil {
            return []
        }
        let dictionary = dict!
        if excludedNames != nil {
            for k in excludedNames! {
                dictionary.remove(key: k)
            }
        }
        let medias: [MetadataViews.Media] = []
        for k in dictionary.keys {
            if dictionary[k] == nil || k.length < 6 || k.slice(from: 0, upTo: 6) != "_media" {
                continue
            }
            if dictionary[k]!.isInstance(Type<MetadataViews.Media>()) {
                medias.append(dictionary[k]! as! MetadataViews.Media)
            } else if dictionary[k]!.isInstance(Type<{String: AnyStruct?}>()) {
                let media: {String: AnyStruct} = dictionary[k]! as! {String: AnyStruct}
                var file: AnyStruct{MetadataViews.File}? = nil
                var mediaType: String? = nil
                if media["mediaType"] != nil && media["mediaType"]!.isInstance(Type<String>()) {
                    mediaType = media["mediaType"]! as! String
                }
                if media["file"] != nil && media["file"]!.isInstance(Type<AnyStruct{MetadataViews.File}>()) {
                    file = media["file"]! as! AnyStruct{MetadataViews.File}
                }
                if file != nil && mediaType != nil {
                    medias.append(MetadataViews.Media(file: file!, mediaType: mediaType!))
                }
            }
        }
        return medias
    }

    pub fun mergeDicts(_ dict1: {String: AnyStruct}?, _ dict2: {String: AnyStruct}?): {String: AnyStruct}? {
        if dict1 == nil {
            return dict2
        } else if dict2 == nil {
            return dict1
        }
        for k in dict2!.keys {
            if dict2![k]! != nil {
                dict1!.insert(key: k, dict2![k]!)
            }    
        } 
        return dict1
    }

    pub resource Admin {

        // for the future use
        pub let data: {String: AnyStruct}

        init() {
            self.data = {}
        }

        pub fun createItem(
            name: String,
            description: String,
            thumbnail: MetadataViews.Media,
            metadata: {String: AnyStruct}?,
            maxSupply: UInt64?,
            isTransferable: Bool?,
            royalties: [MetadataViews.Royalty]?
        ): UInt64 {
            let newItemId = OGs.nextItemId;
            OGs.items[newItemId] <-! create Item(
                id: newItemId,
                name: name,
                description: description,
                thumbnail: thumbnail.file,
                metadata: metadata != nil ? metadata! : {},
                maxSupply: maxSupply,
                isTransferable: isTransferable != nil ? isTransferable! : true,
                royalties: royalties
            )
            OGs.assertItemMetadataIsValid(itemId: newItemId);
            OGs.nextItemId = newItemId + 1
            
            emit ItemCreated(id: newItemId, name: name)
            return newItemId
        }

        pub fun deleteItem(itemId: UInt64) {
            pre {
                OGs.items[itemId] != nil: "Item doesn't exist"
                OGs.countNFTsMintedPerItem(itemId: itemId) == OGs.countNFTsDestroyedPerItem(itemId: itemId):
                    "Cannot delete item that has existing NFTs"
            }
            let item <- OGs.items.remove(key: itemId)
            emit ItemDeleted(id: itemId)
            destroy item
        }

        pub fun lockItem(itemId: UInt64) {
            pre {
                OGs.items[itemId] != nil: "Item doesn't exist"
            }
            let item = OGs.getItemRef(itemId: itemId)
            item.lock()
        }

        pub fun mintNFT(itemId: UInt64, isTransferable: Bool?, metadata: {String: AnyStruct}?): @NFT {
            pre {
                OGs.items[itemId] != nil: "Item doesn't exist"
                !OGs.isItemLocked(itemId: itemId): "Item is locked and cannot be minted anymore"
            }
            post {
                OGs.isItemSupplyValid(itemId: itemId): "Max supply reached- cannot mint more NFTs of this type"
            }
            let item = OGs.getItemRef(itemId: itemId)
            let newNFTid = OGs.totalSupply + 1;
            let newSerialNumber = item.numMinted + 1
            let newNFT: @NFT <- create NFT(
                id: newNFTid,
                itemId: itemId,
                serialNumber: newSerialNumber,
                isTransferable: isTransferable != nil ? isTransferable! : item.isTransferable,
                metadata: metadata,
                royalties: nil
            )

            item.incrementNumMinted()
            OGs.totalSupply = OGs.totalSupply + 1
        
            return <- newNFT
        }

        pub fun mintAndClaim(itemId: UInt64, claimId: String, isTransferable: Bool?, metadata: {String: AnyStruct}?): @NFT {
            pre {
                !OGs.claims.containsKey(claimId): "Item already claimed"
            }
            post {
                OGs.claims.containsKey(claimId): "Claim failed"
            }
            let newNFT: @NFT <- self.mintNFT(itemId: itemId, isTransferable: isTransferable, metadata: metadata)
            OGs.claims.insert(key: claimId, true)
            emit Claimed(id: newNFT.id, itemId: newNFT.itemId, claimId: claimId)
            return <- newNFT
        }

        pub fun createNewAdmin(receiver: Address?): @Admin {
            emit NewAdminCreated(receiver: receiver)
            return <- create Admin()
        }

        pub fun updateCollectionMetadata(data: {String: AnyStruct}) {
            for key in data.keys {
                OGs.metadata.insert(key: key, data[key]!)
            }
            OGs.assertCollectionMetadataIsValid()
            emit CollectionMetadataUpdated(keys: data.keys)
        }

        pub fun updateDefaultRoyalties(royalties: [MetadataViews.Royalty]) {
            OGs.defaultRoyalties = royalties
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0
        self.nextItemId = 1
        self.items <- {}
        self.claims = {}
        self.defaultRoyalties = []
        self.nftViewResolvers <- {}
        self.itemViewResolvers <- {}
        self.contractName = "OGs"
        self.metadata = {
            "name": "Collectico OGs",
            "description": "This is Collectico's first collection",
            "externalURL": MetadataViews.ExternalURL("https://collecticolabs.com"),
            "squareImage": MetadataViews.Media(
                file: MetadataViews.IPFSFile(
                    cid: "bafybeiafjzcjwws7m4snfunpgnvxlufr7tbclzxtorlgepek2je3pbuboe",
                    path: "square.png"
                ),
                mediaType: "image/png"
            ),
            "bannerImage": MetadataViews.Media(
                file: MetadataViews.IPFSFile(
                    cid: "bafybeiafjzcjwws7m4snfunpgnvxlufr7tbclzxtorlgepek2je3pbuboe",
                    path: "banner.jpg"
                ),
                mediaType: "image/jpeg"
            ),
            "socials": {
                "twitter": MetadataViews.ExternalURL("https://twitter.com/CollecticoLabs")
            }
        }

        // Set the named paths
        self.CollectionStoragePath = /storage/collecticoOGsCollection
        self.CollectionPublicPath = /public/collecticoOGsCollection
        self.CollectionProviderPath = /private/collecticoOGsCollection
        self.AdminStoragePath = /storage/collecticoOGsAdmin

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&OGs.Collection{NonFungibleToken.CollectionPublic, OGs.CollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create an Admin resource and save it to storage
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
