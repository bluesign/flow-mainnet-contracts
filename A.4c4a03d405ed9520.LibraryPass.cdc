import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract LibraryPass: NonFungibleToken {
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, name: String,ipfsLink: String)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub var totalSupply: UInt64

    pub resource interface Public {
        pub let id: UInt64
        pub let metadata: Metadata
    }

    //you can extend these fields if you need
    pub struct Metadata {
        pub let name: String
        pub let ipfsLink: String

        init(name: String,ipfsLink: String) {
            self.name=name
            //Stored in the ipfs
            self.ipfsLink=ipfsLink
        }
    }

    pub resource NFT: NonFungibleToken.INFT, Public, MetadataViews.Resolver {
        pub let id: UInt64
        pub let metadata: Metadata
        pub let type: UInt64
        init(initID: UInt64,metadata: Metadata, type: UInt64) {
            self.id = initID
            self.metadata=metadata
            self.type=type
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "LibraryPass",
                        description: "Ebook NFT",
                        thumbnail: MetadataViews.HTTPFile(
                            url: "url"
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([])
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://publishednft.io/")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: LibraryPass.CollectionStoragePath,
                        publicPath: LibraryPass.CollectionPublicPath,
                        providerPath: /private/libraryPassCollection,
                        publicCollection: Type<&LibraryPass.Collection{LibraryPass.LibraryPassCollectionPublic}>(),
                        publicLinkedType: Type<&LibraryPass.Collection{LibraryPass.LibraryPassCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&LibraryPass.Collection{LibraryPass.LibraryPassCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-LibraryPass.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://publishednft.io/logo-desktop.png"
                        ),
                        mediaType: "image/png"
                    )
                    var collectionName = "The LibraryPass Collection"
                    if (self.id % 2 == 1) {
                        collectionName = "The LibraryPass Collection"
                    }
                    return MetadataViews.NFTCollectionDisplay(
                        name: collectionName,
                        description: "The LibraryPass is an NFT that is used in Published NFT.",
                        externalURL: MetadataViews.ExternalURL("https://publishednft.io/"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/publishednft/"),
                            "linktr": MetadataViews.ExternalURL("https://linktr.ee/publishednft")
                        }
                    )
            }
            return nil
        }
    }

    pub resource interface LibraryPassCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowLibraryPass(id: UInt64): &LibraryPass.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow LibraryPass reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: LibraryPassCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @LibraryPass.NFT

            let id: UInt64 = token.id

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

        pub fun borrowLibraryPass(id: UInt64): &LibraryPass.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &LibraryPass.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let libraryPass = nft as! &LibraryPass.NFT
            return libraryPass as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }        
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub struct NftData {
        pub let metadata: LibraryPass.Metadata
        pub let id: UInt64
        pub let type: UInt64
        init(metadata: LibraryPass.Metadata, id: UInt64, type: UInt64) {
            self.metadata= metadata
            self.id=id
            self.type=type
        }
    }

    pub fun getNft(address:Address) : [NftData] {
        var libraryPassData: [NftData] = []
        let account=getAccount(address)

        if let libraryPassCollection= account.getCapability(self.CollectionPublicPath).borrow<&{LibraryPass.LibraryPassCollectionPublic}>()  {
            for id in libraryPassCollection.getIDs() {
                var libraryPass=libraryPassCollection.borrowLibraryPass(id: id)
                libraryPassData.append(NftData(metadata: libraryPass!.metadata, id: id, type: libraryPass!.type))
            }
        }
        return libraryPassData
    }

	pub resource NFTMinter {
		pub fun mintNFT(
		recipient: &{NonFungibleToken.CollectionPublic},
		name: String,
        ipfsLink: String,
        type: UInt64) {
            emit Minted(id: LibraryPass.totalSupply, name: name, ipfsLink: ipfsLink)

			recipient.deposit(token: <-create LibraryPass.NFT(
			    initID: LibraryPass.totalSupply,
			    metadata: Metadata(
                    name: name,
                    ipfsLink:ipfsLink,
                ),
                type: type))

            LibraryPass.totalSupply = LibraryPass.totalSupply + (1 as UInt64)
		}
	}

    init() {
        self.CollectionStoragePath = /storage/LibraryPassCollection
        self.CollectionPublicPath = /public/LibraryPassCollection
        self.MinterStoragePath = /storage/LibraryPassMinter

        self.totalSupply = 0

        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        let collection <- LibraryPass.createEmptyCollection()
        self.account.save(<-collection, to: LibraryPass.CollectionStoragePath)
        self.account.link<&LibraryPass.Collection{NonFungibleToken.CollectionPublic, LibraryPass.LibraryPassCollectionPublic}>(LibraryPass.CollectionPublicPath, target: LibraryPass.CollectionStoragePath)

        emit ContractInitialized()
    }
}
