// Wealth, Fame, Power.
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FlowToken from 0x1654653399040a61

pub contract NFTDayTreasureChest: NonFungibleToken {

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    pub var totalSupply: UInt64
    pub var retired: Bool
    access(self) var whitelist: [Address]
    access(self) var minted: [Address]
    access(self) var royalties: [MetadataViews.Royalty]
    
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let thumbnail: String
        access(self) let royalties: [MetadataViews.Royalty]
    
        init() {
            self.id = NFTDayTreasureChest.totalSupply
            self.name = "NFT Day Treasure Chest"
            self.description = "This treasure chest has been inspected by an adventurous hunter."
            self.thumbnail = "https://basicbeasts.mypinata.cloud/ipfs/QmUYVdSE1CLdcL8Z7FZdH7ye8tMdGnkbyVPpeQFW6tcYHy"
            self.royalties = NFTDayTreasureChest.royalties
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
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
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "NFT Day Treasure Chest Edition", number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://basicbeasts.io/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: NFTDayTreasureChest.CollectionStoragePath,
                        publicPath: NFTDayTreasureChest.CollectionPublicPath,
                        providerPath: /private/NFTDayTreasureChestCollection,
                        publicCollection: Type<&NFTDayTreasureChest.Collection{NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic}>(),
                        publicLinkedType: Type<&NFTDayTreasureChest.Collection{NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&NFTDayTreasureChest.Collection{NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-NFTDayTreasureChest.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://basicbeasts.mypinata.cloud/ipfs/QmZLx5Tw7Fydm923kSkqcf5PuABtcwofuv6c2APc9iR41J"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The NFT Day Treasure Chest Collection",
                        description: "This collection is used for the Basic Beasts Treasure Hunt to celebrate international #NFTDay.",
                        externalURL: MetadataViews.ExternalURL("https://basicbeasts.io"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/basicbeastsnft")
                        }
                    )
            }
            return nil
        }
    }

    pub resource interface NFTDayTreasureChestCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowNFTDayTreasureChest(id: UInt64): &NFTDayTreasureChest.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow NFTDayTreasureChest reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: NFTDayTreasureChestCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

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
            let token <- token as! @NFTDayTreasureChest.NFT

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
 
        pub fun borrowNFTDayTreasureChest(id: UInt64): &NFTDayTreasureChest.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &NFTDayTreasureChest.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let NFTDayTreasureChest = nft as! &NFTDayTreasureChest.NFT
            return NFTDayTreasureChest as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}) {
            pre {
                !self.retired : "Cannot mint Treasure Chest: NFT Day Treasure Chest is retired"
                self.whitelist.contains(recipient.owner!.address) : "Cannot mint Treasure Chest: Address is not whitelisted"
                !self.minted.contains(recipient.owner!.address) : "Cannot mint Treasure Chest: Address has already minted"
            }

            // create a new NFT
            var newNFT <- create NFT()

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            self.minted.append(recipient.owner!.address)

            NFTDayTreasureChest.totalSupply = NFTDayTreasureChest.totalSupply + UInt64(1)
    }

    pub resource Admin {

        pub fun whitelistAddress(address: Address) {
            if !NFTDayTreasureChest.whitelist.contains(address) {
                NFTDayTreasureChest.whitelist.append(address)
            }
        }

        pub fun retire() {
            if !NFTDayTreasureChest.retired {
                NFTDayTreasureChest.retired = true
            }
        }

        pub fun addRoyalty(beneficiaryCapability: Capability<&AnyResource{FungibleToken.Receiver}>, cut: UFix64, description: String) {

            // Make sure the royalty capability is valid before minting the NFT
            if !beneficiaryCapability.check() { panic("Beneficiary capability is not valid!") }

            NFTDayTreasureChest.royalties.append(
                MetadataViews.Royalty(
                    receiver: beneficiaryCapability,
                    cut: cut,
                    description: description
                )
            )
        }

    }

    pub fun getWhitelist(): [Address] {
        return self.whitelist
    }

    pub fun getMinted(): [Address] {
        return self.minted
    }

    init() {
        // Initialize contract fields
        self.totalSupply = 0
        self.retired = false
        self.whitelist = []
        self.minted = []
        self.royalties = [MetadataViews.Royalty(
							recepient: self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
							cut: 0.05, // 5% royalty on secondary sales
							description: "Basic Beasts 5% royalty from secondary sales."
						)]

        // Set the named paths
        self.CollectionStoragePath = /storage/bbNFTDayTreasureChestCollection
        self.CollectionPublicPath = /public/bbNFTDayTreasureChestCollection
        self.AdminStoragePath = /storage/bbNFTDayTreasureChestAdmin

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&NFTDayTreasureChest.Collection{NonFungibleToken.CollectionPublic, NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Admin resource and save it to storage
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}