import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract DriverzAirdrop: NonFungibleToken {

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event DriverzAirdropMinted(id: UInt64, name: String, ipfsLink: String)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    pub var totalSupply: UInt64

    pub struct DriverzAirdropMetadata {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let ipfsLink: String

        init(id: UInt64 ,name: String, description: String, ipfsLink: String) {
            self.id = id
            self.name=name
            self.description = description
            self.ipfsLink=ipfsLink
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub var ipfsLink: String

        init(initID: UInt64, name: String, description: String, ipfsLink: String) {
            self.id = initID
            self.name = name
            self.description = description
            self.ipfsLink = ipfsLink
        }

        pub fun revealThumbnail() {
            let urlBase = "QmP45SUvQjwfdbsnXMyGf5BiHF51KSmVkvB9QAkRgviLnV/"
            let newImage = urlBase.concat(self.id.toString()).concat(".png")
            self.ipfsLink = newImage
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<DriverzAirdrop.DriverzAirdropMetadata>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.ipfsLink,
                            path: nil
                        )
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://driverznftairdrops.io/")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: DriverzAirdrop.CollectionStoragePath,
                        publicPath: DriverzAirdrop.CollectionPublicPath,
                        providerPath: /private/SoulMadeMainCollection,
                        publicCollection: Type<&Collection{CollectionPublic}>(),
                        publicLinkedType: Type<&Collection{CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Collection{CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <- DriverzAirdrop.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                           url: "https://driverznftairdrops.io/DriverzNFT-logo.png"
                        ),
                        mediaType: "image"
                    )
                    let bannerMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://driverznftairdrops.io/DriverzNFT-logo.png"
                        ),
                        mediaType: "image"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "DriverzAirdrop",
                        description: "DriverzAirdrop Collection",
                        externalURL: MetadataViews.ExternalURL("https://driverznftairdrops.io/"),
                        squareImage: squareMedia,
                        bannerImage: bannerMedia,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/driverznft"),
                            "discord": MetadataViews.ExternalURL("https://discord.gg/TdxXJEPhhv")
                        }
                    )
                case Type<DriverzAirdrop.DriverzAirdropMetadata>():
                    return DriverzAirdrop.DriverzAirdropMetadata(
                        id: self.id,
                        name: self.name,
                        description: self.description,
                        ipfsLink: self.ipfsLink
                    )
            }
            return nil
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowArt(id: UInt64): &DriverzAirdrop.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow DriverzAirdrop reference: The ID of the returned reference is incorrect"
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
            let token <- token as! @DriverzAirdrop.NFT

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
            let mainNFT = nft as! &DriverzAirdrop.NFT
            return mainNFT as &{MetadataViews.Resolver}
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowArt(id: UInt64): &DriverzAirdrop.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &DriverzAirdrop.NFT
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
        ipfsLink: String) {
            emit DriverzAirdropMinted(id: DriverzAirdrop.totalSupply, name: name, ipfsLink: ipfsLink)

			recipient.deposit(token: <- create DriverzAirdrop.NFT(
			    initID: DriverzAirdrop.totalSupply,
                name: name,
                description: description,
			    ipfsLink: ipfsLink)
            )

            DriverzAirdrop.totalSupply = DriverzAirdrop.totalSupply + (1 as UInt64)
		}
	}

    init() {
        self.CollectionStoragePath = /storage/DriverzAirdropCollection
        self.CollectionPublicPath = /public/DriverzAirdropCollection
        self.AdminStoragePath = /storage/DriverzAirdropMinter

        self.totalSupply = 0

        let minter <- create Admin()
        self.account.save(<-minter, to: self.AdminStoragePath)

        let collection <- DriverzAirdrop.createEmptyCollection()
        self.account.save(<-collection, to: DriverzAirdrop.CollectionStoragePath)
        self.account.link<&DriverzAirdrop.Collection{NonFungibleToken.CollectionPublic, DriverzAirdrop.CollectionPublic}>(DriverzAirdrop.CollectionPublicPath, target: DriverzAirdrop.CollectionStoragePath)

        emit ContractInitialized()
    }
}