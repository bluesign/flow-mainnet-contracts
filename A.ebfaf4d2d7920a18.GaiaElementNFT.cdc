import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract GaiaElementNFT: NonFungibleToken {
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event SetAdded(id: UInt64, name: String)
    pub event SetUpdated(id: UInt64, name: String)
    pub event SetRemoved(id: UInt64, name: String)

    pub event ElementAdded(id: UInt64, name: String, setID: UInt64)
    pub event ElementUpdated(id: UInt64, name: String)
    pub event ElementRemoved(id: UInt64, name: String)

    pub event Mint(id: UInt64, setID: UInt64, elementID: UInt64)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPrivatePath: PrivatePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let OwnerStoragePath: StoragePath

    pub var totalSupply: UInt64

    pub var collectionDisplay: MetadataViews.NFTCollectionDisplay
    access(contract) fun setCollectionDisplay(_ collectionDisplay: MetadataViews.NFTCollectionDisplay) {
        self.collectionDisplay = collectionDisplay
    }

    pub var royalties: MetadataViews.Royalties
    access(contract) fun setRoyalties(_ royalties: MetadataViews.Royalties) {
        self.royalties = royalties
    }

    pub struct Set {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let metadata: {String: AnyStruct}

        pub let elements: {UInt64: Element}

        pub fun elementCount(): Int {
            return self.elements.keys.length
        }

        pub fun getElementRef(id: UInt64): &Element {
            return &self.elements[id]! as &GaiaElementNFT.Element
        }

        access(contract) fun addElement(
            elementID: UInt64,
            name: String,
            description: String,
            color: String,
            image: AnyStruct{MetadataViews.File},
            video: AnyStruct{MetadataViews.File}?,
            metadata: {String: AnyStruct},
            maxSupply: UInt64
        ) {
            pre {
                self.elements.containsKey(elementID) == false: "Element ID already in use"
            }
            let element = GaiaElementNFT.Element(
                id: elementID,
                setID: self.id,
                name: name,
                description: description,
                color: color,
                image: image,
                video: video,
                metadata: metadata,
                maxSupply: maxSupply,
            )
            self.elements[elementID] = element

            emit GaiaElementNFT.ElementAdded(id: element.id, name: element.name, setID: self.id)
        }

        access(contract) fun removeElement(id: UInt64) {
            let element = self.getElementRef(id: id)
            assert(!element.isLocked(), message: "Element locked")

            emit GaiaElementNFT.ElementRemoved(id: element.id, name: element.name)

            self.elements.remove(key: element.id)
        }

        // lock set if it has any child elements
        pub fun isLocked(): Bool {
            return self.elementCount() > 0
        }

        init(id: UInt64, name: String, description: String, metadata: {String: AnyStruct}) {
            self.id = id
            self.name = name
            self.description = description
            self.metadata = metadata

            self.elements = {}
        }
    }

    pub let sets: {UInt64: Set}

    pub fun setCount(): Int {
        return self.sets.keys.length
    }

    pub fun getSetRef(id: UInt64): &GaiaElementNFT.Set {
        return &GaiaElementNFT.sets[id]! as &GaiaElementNFT.Set
    }

    access(contract) fun addSet(setID: UInt64, name: String, description: String, metadata: {String: AnyStruct}) {
        pre {
            GaiaElementNFT.sets.containsKey(setID) == false: "Set ID already in use"
        }
        GaiaElementNFT.sets[setID] =
            GaiaElementNFT.Set(id: setID, name:name, description: description, metadata: metadata)

        emit GaiaElementNFT.SetAdded(id: setID, name: name)
    }

    access(contract) fun removeSet(id: UInt64) {
        let set = GaiaElementNFT.getSetRef(id: id)
        assert(!set.isLocked(), message: "Set is locked")

        emit GaiaElementNFT.SetRemoved(id: set.id, name: set.name)

        GaiaElementNFT.sets.remove(key: id)
    }

    pub struct Element {
        pub let id: UInt64
        pub let setID: UInt64

        pub let name: String
        pub let description: String
        pub let color: String
        pub let image: AnyStruct{MetadataViews.File}
        pub let video: AnyStruct{MetadataViews.File}?

        pub let metadata: {String: AnyStruct}

        pub var totalSupply: UInt64
        pub let maxSupply: UInt64

        // mapping of nft mint sequence number to nft id
        pub let nftSerials: {UInt64: UInt64}
        pub fun getNFTSerial(nftID: UInt64): UInt64? {
            return self.nftSerials[nftID]
        }

        pub fun set(): GaiaElementNFT.Set {
            return GaiaElementNFT.sets[self.setID]!
        }

        access(contract) fun mintNFT(nftID: UInt64): @GaiaElementNFT.NFT {
            pre {
                self.totalSupply < self.maxSupply
            }

            let nft <- GaiaElementNFT.mintNFT(nftID: nftID, setID: self.setID, elementID: self.id)

            let serial = self.totalSupply + 1
            self.nftSerials.insert(key: nft.id, serial)

            self.totalSupply = self.totalSupply + 1

            return <- nft
        }

        // lock element if it minted any child NFTs
        pub fun isLocked(): Bool {
            return self.totalSupply > 0
        }

        init(
            id: UInt64,
            setID: UInt64,
            name: String,
            description: String,
            color: String,
            image: AnyStruct{MetadataViews.File},
            video: AnyStruct{MetadataViews.File}?,
            metadata: {String: AnyStruct},
            maxSupply: UInt64,
        ) {
            self.id = id
            self.setID = setID
            self.name = name
            self.description = description
            self.color = color
            self.image = image
            self.video = video
            self.metadata = metadata
            self.maxSupply = maxSupply

            self.nftSerials = {}
            self.totalSupply = 0
        }
    }

    pub struct ElementNFTView {
        pub let id: UInt64
        pub let setID: UInt64
        pub let setName: String
        pub let elementID: UInt64
        pub let name: String
        pub let description: String
        pub let color: String
        pub let image: AnyStruct{MetadataViews.File}
        pub let video: AnyStruct{MetadataViews.File}?
        pub let serialNumber: UInt64

        init(
            id: UInt64,
            setID: UInt64,
            setName: String,
            elementID: UInt64,
            name: String,
            description: String,
            color: String,
            image: AnyStruct{MetadataViews.File},
            video: AnyStruct{MetadataViews.File}?,
            serialNumber: UInt64,
        ) {
            self.id = id
            self.setID = setID
            self.setName = setName
            self.elementID = elementID
            self.name = name
            self.description = description
            self.color = color
            self.image = image
            self.video = video
            self.serialNumber = serialNumber
        }
    }

    access(contract) let nftIDs: {UInt64: Bool}

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let elementID: UInt64
        pub let setID: UInt64

        pub fun set(): &GaiaElementNFT.Set {
            return GaiaElementNFT.getSetRef(id: self.setID)
        }

        pub fun element(): &GaiaElementNFT.Element {
            return self.set().getElementRef(id: self.elementID)
        }

        pub fun serial(): UInt64 {
            return self.element().getNFTSerial(nftID: self.id)!
        }

        pub fun name(): String {
            return self.element().name.concat(" #").concat(self.serial().toString())
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTView>(),
                Type<ElementNFTView>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<ElementNFTView>():
                    let element = self.element()

                    return ElementNFTView(
                        id: self.id,
                        setID: self.setID,
                        setName: self.set().name,
                        elementID: self.elementID,
                        name: element.name,
                        description: element.description,
                        color: element.color,
                        image: element.image,
                        video: element.video,
                        serialNumber: self.serial(),
                    )
                case Type<MetadataViews.NFTView>():
                    let viewResolver = &self as &{MetadataViews.Resolver}
                    return MetadataViews.NFTView(
                        id: self.id,
                        uuid: self.uuid,
                        display: MetadataViews.getDisplay(viewResolver),
                        externalURL: MetadataViews.getExternalURL(viewResolver),
                        collectionData: MetadataViews.getNFTCollectionData(viewResolver),
                        collectionDisplay: MetadataViews.getNFTCollectionDisplay(viewResolver),
                        royalties: MetadataViews.getRoyalties(viewResolver),
                        traits: MetadataViews.getTraits(viewResolver)
                    )
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: self.element().description,
                        thumbnail: self.element().image
                    )
                case Type<MetadataViews.Editions>():
                    let editionInfo = MetadataViews.Edition(
                        name: self.name(),
                        number: self.serial(),
                        max: self.element().maxSupply
                    )
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(editionList)
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.serial())
                case Type<MetadataViews.Royalties>():
                    return GaiaElementNFT.royalties
                case Type<MetadataViews.ExternalURL>():
                    return GaiaElementNFT.collectionDisplay.externalURL
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: GaiaElementNFT.CollectionStoragePath,
                        publicPath: GaiaElementNFT.CollectionPublicPath,
                        providerPath: /private/exampleNFTCollection,
                        publicCollection: Type<&GaiaElementNFT.Collection{GaiaElementNFT.CollectionPublic}>(),
                        publicLinkedType:
                            Type<&GaiaElementNFT.Collection{GaiaElementNFT.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType:
                            Type<&GaiaElementNFT.Collection{GaiaElementNFT.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-GaiaElementNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return GaiaElementNFT.collectionDisplay
                }

            return nil
        }

        init(id: UInt64, setID: UInt64, elementID: UInt64) {
            self.id = id
            self.setID = setID
            self.elementID = elementID
        }
    }

    access(contract) fun mintNFT(nftID: UInt64, setID: UInt64, elementID: UInt64): @GaiaElementNFT.NFT {
        pre {
            GaiaElementNFT.nftIDs.containsKey(nftID) == false: "NFT ID is already in use"
        }
        let nft <- create NFT(id: nftID, setID: setID, elementID: elementID)

        GaiaElementNFT.nftIDs[nftID] = true

        GaiaElementNFT.totalSupply = GaiaElementNFT.totalSupply + 1

        emit GaiaElementNFT.Mint(id: nftID, setID: setID, elementID: elementID)

        return <- nft
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowGaiaElementNFT(id: UInt64): &GaiaElementNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow GaiaElementNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection:
        CollectionPublic,
        NonFungibleToken.Provider,
        NonFungibleToken.Receiver,
        NonFungibleToken.CollectionPublic,
        MetadataViews.ResolverCollection
    {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @GaiaElementNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowGaiaElementNFT(id: UInt64): &GaiaElementNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &GaiaElementNFT.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let exampleNFT = nft as! &GaiaElementNFT.NFT
            return exampleNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }

        init () {
            self.ownedNFTs <- {}
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource NFTMinter {
        pub let maxMints: UInt64

        access(self) var totalMints: UInt64

        pub fun mintNFT(nftID: UInt64, setID: UInt64, elementID: UInt64): @GaiaElementNFT.NFT {
            pre {
                self.totalMints < self.maxMints: "Minter exhausted"
            }

            let set = GaiaElementNFT.getSetRef(id: setID)
            let element = set.getElementRef(id: elementID)
            let nft <- element.mintNFT(nftID: nftID)

            self.totalMints = self.totalMints + 1

            return <- nft
        }

        init(maxMints: UInt64) {
            self.maxMints = maxMints
            self.totalMints = 0
        }
    }

    access(contract) fun createMinter(maxMints: UInt64): @GaiaElementNFT.NFTMinter {
        return <- create GaiaElementNFT.NFTMinter(maxMints: maxMints)
    }

    pub resource Owner {
        pub fun setCollectionDisplay(_ collectionDisplay: MetadataViews.NFTCollectionDisplay) {
            GaiaElementNFT.collectionDisplay = collectionDisplay
        }

        pub fun setRoyalties(_ royalties: MetadataViews.Royalties) {
            GaiaElementNFT.royalties = royalties
        }

        pub fun addSet(setID: UInt64, name: String, description: String, metadata: {String: AnyStruct}) {
            GaiaElementNFT.addSet(setID: setID, name: name, description: description, metadata: metadata)
        }

        pub fun removeSet(id: UInt64) {
            GaiaElementNFT.removeSet(id: id)
        }

        pub fun addElementToSet(
            elementID: UInt64,
            setID: UInt64,
            name: String,
            description: String,
            color: String,
            image: AnyStruct{MetadataViews.File},
            video: AnyStruct{MetadataViews.File}?,
            metadata: {String: AnyStruct},
            maxSupply: UInt64
        ) {
            let set = GaiaElementNFT.getSetRef(id: setID)
            set.addElement(
                elementID: elementID,
                name: name,
                description: description,
                color: color,
                image: image,
                video: video,
                metadata: metadata,
                maxSupply: maxSupply
            )
        }

        pub fun removeElementInSet(setID: UInt64, elementID: UInt64) {
            let set = GaiaElementNFT.getSetRef(id: setID)
            set.removeElement(id: elementID)
        }

        pub fun createMinter(maxMints: UInt64): @GaiaElementNFT.NFTMinter {
            return <- GaiaElementNFT.createMinter(maxMints: maxMints)
        }
    }

    access(contract) fun createOwner(): @GaiaElementNFT.Owner {
        return <- create Owner()
    }

    init() {
        self.CollectionStoragePath = /storage/GaiaElementNFTCollection002
        self.CollectionPrivatePath = /private/GaiaElementNFTCollection002
        self.CollectionPublicPath = /public/GaiaElementNFTCollection002
        self.MinterStoragePath = /storage/GaiaElementNFTMinter001
        self.OwnerStoragePath = /storage/GaiaElementNFTOwner

        self.totalSupply = 0
        self.sets = {}
        self.nftIDs = {}
        self.royalties = MetadataViews.Royalties([])

        self.collectionDisplay = MetadataViews.NFTCollectionDisplay(
            name: "Gaia Elements",
            description: "Gaia Element NFTs on the Flow Blockchain",
            externalURL: MetadataViews.ExternalURL("https://ongaia.com/elements"),
            squareImage: MetadataViews.Media(
                MetadataViews.IPFSFile(cid: "QmdV7UDXCjTj5hVxrLsETwBbp4cHQwUG1m6GfEpotW7wHf", path: "elements-icon.png"),
                mediaType: "image/png"
            ),
            bannerImage: MetadataViews.Media(
                MetadataViews.IPFSFile(cid: "Qmdd43Z3AjLtirHnLk2XbE8XruBg2fCoHoyYpNWhAhGqMb", path: "elements-banner.png"),
                mediaType: "image/png"
            ),
            socials: {
                "twitter": MetadataViews.ExternalURL("https://twitter.com/GaiaMarketplace")
            }
        )

        let collection <- GaiaElementNFT.createEmptyCollection()
        self.account.save(<- collection, to: GaiaElementNFT.CollectionStoragePath)
        self.account.link<&GaiaElementNFT.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, GaiaElementNFT.CollectionPublic, MetadataViews.ResolverCollection}>(
            GaiaElementNFT.CollectionPublicPath,
            target: GaiaElementNFT.CollectionStoragePath
        )

        let owner <- GaiaElementNFT.createOwner()
        self.account.save(<- owner, to: GaiaElementNFT.OwnerStoragePath)

        emit ContractInitialized()
    }
}
