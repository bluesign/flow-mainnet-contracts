import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract CarClub: NonFungibleToken {

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event CarClubMinted(id: UInt64, name: String, description: String, image: String, traits: {String: String})

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    pub var totalSupply: UInt64

    pub struct CarClubMetadata {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let image: String
        pub let traits: {String: String}

        init(id: UInt64 ,name: String, description: String, image: String, traits: {String: String}) {
            self.id = id
            self.name=name
            self.description = description
            self.image = image
            self.traits = traits
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub var image: String
        pub let traits: {String: String}

        init(id: UInt64 ,name: String, description: String, image: String, traits: {String: String}) {
            self.id = id
            self.name=name
            self.description = description
            self.image = image
            self.traits = traits
        }

        pub fun revealThumbnail() {
            let urlBase = self.image.slice(from: 0, upTo: 47)
            let newImage = urlBase.concat(self.id.toString()).concat(".png")
            self.image = newImage
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.NFTView>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<CarClub.CarClubMetadata>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.image,
                            path: nil
                        )
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://driverzinc.io")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: CarClub.CollectionStoragePath,
                        publicPath: CarClub.CollectionPublicPath,
                        providerPath: CarClub.CollectionPrivatePath,
                        publicCollection: Type<&Collection{NonFungibleToken.CollectionPublic}>(),
                        publicLinkedType: Type<&Collection{CarClub.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Collection{CarClub.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <- CarClub.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                           url: "https://driverzinc.io/DriverzNFT-logo.png"
                        ),
                        mediaType: "image"
                    )
                    let bannerMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://driverzinc.io/DriverzNFT-logo.png"
                        ),
                        mediaType: "image"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "CarClub",
                        description: "CarClub Collection",
                        externalURL: MetadataViews.ExternalURL("https://driverzinc.io/"),
                        squareImage: squareMedia,
                        bannerImage: bannerMedia,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/driverznft"),
                            "discord": MetadataViews.ExternalURL("https://discord.gg/TdxXJEPhhv")
                        }
                    )
                case Type<CarClub.CarClubMetadata>():
                    return CarClub.CarClubMetadata(
                        id: self.id,
                        name: self.name,
                        description: self.description,
                        image: self.image,
                        traits: self.traits
                    )
                case Type<MetadataViews.NFTView>(): 
                let viewResolver = &self as &{MetadataViews.Resolver}
                return MetadataViews.NFTView(
                    id : self.id,
                    uuid: self.uuid,
                    display: MetadataViews.getDisplay(viewResolver),
                    externalURL : MetadataViews.getExternalURL(viewResolver),
                    collectionData : MetadataViews.getNFTCollectionData(viewResolver),
                    collectionDisplay : MetadataViews.getNFTCollectionDisplay(viewResolver),
                    royalties : MetadataViews.getRoyalties(viewResolver),
                    traits : MetadataViews.getTraits(viewResolver)
                )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([])
                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = []
                    for trait in self.traits.keys {
                        traits.append(MetadataViews.Trait(
                            trait: trait,
                            value: self.traits[trait]!,
                            displayType: nil,
                            rarity: nil
                        ))
                    }
                    return MetadataViews.Traits(traits: traits)
            }
            return nil
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowCarClub(id: UInt64): &CarClub.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow CarClub reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @CarClub.NFT

            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}{
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let mainNFT = nft as! &CarClub.NFT
            return mainNFT
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowCarClub(id: UInt64): &CarClub.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &CarClub.NFT
            } else {
                return nil
            }
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

	pub resource Admin {
		pub fun mintNFT(
		recipient: &{NonFungibleToken.CollectionPublic},
		name: String,
        description: String,
        image: String,
        traits: {String: String}
        ) {
            emit CarClubMinted(id: CarClub.totalSupply, name: name, description: description, image: image, traits: traits)

            CarClub.totalSupply = CarClub.totalSupply + (1 as UInt64)
            
			recipient.deposit(token: <- create CarClub.NFT(
			    initID: CarClub.totalSupply,
                name: name,
                description: description,
			    image:image,
                traits: traits
                )
            )
		}

	}

    init() {
        self.CollectionStoragePath = /storage/CarClubCollection
        self.CollectionPublicPath = /public/CarClubCollection
        self.CollectionPrivatePath = /private/CarClubCollection
        self.AdminStoragePath = /storage/CarClubMinter

        self.totalSupply = 0

        let minter <- create Admin()
        self.account.save(<-minter, to: self.AdminStoragePath)

        let collection <- CarClub.createEmptyCollection()
        self.account.save(<-collection, to: CarClub.CollectionStoragePath)
        self.account.link<&CarClub.Collection{NonFungibleToken.CollectionPublic, CarClub.CollectionPublic}>(CarClub.CollectionPublicPath, target: CarClub.CollectionStoragePath)

        emit ContractInitialized()
    }
}
 