import FungibleToken from 0xf233dcee88fe0abe
import ThulToken from 0xe3ad6030cbaff1c2
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract DimensionX: NonFungibleToken {

    pub var totalSupply: UInt64
    pub var customSupply: UInt64
    pub var genesisSupply: UInt64
    pub var commonSupply: UInt64

    pub var totalBurned: UInt64
    pub var customBurned: UInt64
    pub var genesisBurned: UInt64
    pub var commonBurned: UInt64

    pub var thulMintPrice: UFix64
    pub var thulMintEnabled: Bool
    pub var metadataUrl: String
    pub var stakedNfts: {UInt64: Address} // map nftId -> ownerAddress

    pub var crypthulhuAwake: UFix64
    pub var crypthulhuSleepTime: UFix64
    pub fun crypthulhuSleeps(): Bool {
        return getCurrentBlock().timestamp - DimensionX.crypthulhuAwake > DimensionX.crypthulhuSleepTime
    }

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64, type: UInt8)
    pub event Burn(id: UInt64, type: UInt8)
    pub event Stake(id: UInt64, to: Address?)
    pub event Unstake(id: UInt64, from: Address?)
    pub event MinterCreated()

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let MinterStoragePath: StoragePath

    pub enum NFTType: UInt8 {
        pub case custom
        pub case genesis
        pub case common
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        pub let type: NFTType

        init(
            id: UInt64,
            type: NFTType,
        ) {
            self.id = id
            self.type = type
        }

        destroy () {
            DimensionX.totalBurned = DimensionX.totalBurned + UInt64(1)
            switch self.type {
                case NFTType.custom:
                    DimensionX.customBurned = DimensionX.customBurned + UInt64(1)
                    emit Burn(id: self.id, type: UInt8(0))
                case NFTType.genesis:
                    DimensionX.genesisBurned = DimensionX.genesisBurned + UInt64(1)
                    emit Burn(id: self.id, type: UInt8(1))
                
                case NFTType.common:
                    DimensionX.commonBurned = DimensionX.commonBurned + UInt64(1)
                    emit Burn(id: self.id, type: UInt8(2))
                
            }
            
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(
                        url: DimensionX.metadataUrl.concat(self.id.toString())
                    )
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: ("DimensionX #").concat(self.id.toString()),
                        description: "A Superhero capable of doing battle in the DimensionX Game!",
                        thumbnail: MetadataViews.HTTPFile(
                        url: DimensionX.metadataUrl.concat("i/").concat(self.id.toString()).concat(".png")
                        )
                    )
                case Type<MetadataViews.Royalties>():
                    let royalties : [MetadataViews.Royalty] = []
                    royalties.append(MetadataViews.Royalty(recepient: DimensionX.account.getCapability<&{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath()), cut: UFix64(0.10), description: "Crypthulhu royalties"))
                    return MetadataViews.Royalties(cutInfos: royalties)
                   
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: DimensionX.CollectionStoragePath,
                        publicPath: DimensionX.CollectionPublicPath,
                        providerPath: /private/dmxCollection,
                        publicCollection: Type<&DimensionX.Collection{DimensionX.CollectionPublic}>(),
                        publicLinkedType: Type<&DimensionX.Collection{DimensionX.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&DimensionX.Collection{DimensionX.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-DimensionX.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Dimension X",
                        description: "Dimension X is a Free-to-Play, Play-to-Earn strategic role playing game on the Flow blockchain set in the Dimension X comic book universe, where a pan-dimensional explosion created super powered humans, aliens and monsters with radical and terrifying superpowers!",
                        externalURL: MetadataViews.ExternalURL("https://dimensionxnft.com"),
                        squareImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: DimensionX.metadataUrl.concat("collection_image.png")),
                            mediaType: "image/png"
                        ),
                        bannerImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: DimensionX.metadataUrl.concat("collection_banner.png")),
                            mediaType: "image/png"
                        ),
                        socials: {
                            "discord": MetadataViews.ExternalURL("https://discord.gg/BK5yAD6VQg"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/DimensionX_NFT")
                        }
                    )
                    
            }

            return nil
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowDimensionX(id: UInt64): &DimensionX.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow DimensionX reference: the ID of the returned reference is incorrect"
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

        pub fun stake(id: UInt64) {
            pre {
                !DimensionX.stakedNfts.containsKey(id):
                    "Cannot stake: the token is already staked"
            }

            let ownerAddress = self.owner?.address
            DimensionX.stakedNfts[id] = ownerAddress

            emit Stake(id: id, to:ownerAddress)
        }

        pub fun unstake(id: UInt64) {
            pre {
                DimensionX.stakedNfts.containsKey(id):
                    "Cannot unstake: the token is not staked"
                DimensionX.stakedNfts[id] == self.owner?.address:
                    "Cannot unstake: you can only unstake tokens that you own"
                DimensionX.crypthulhuSleeps():
                    "Cannot unstake: you can only unstake through the game at this moment"
            }

            let ownerAddress = DimensionX.stakedNfts[id]
            DimensionX.stakedNfts.remove(key: id)

            emit Unstake(id: id, from: ownerAddress)
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            pre {
                !DimensionX.stakedNfts.containsKey(withdrawID):
                    "Cannot withdraw: the token is staked"
            }

            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @DimensionX.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
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
 
        pub fun borrowDimensionX(id: UInt64): &DimensionX.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &DimensionX.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let dmxNft = nft as! &DimensionX.NFT
            return dmxNft as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {
        // range if possible
        pub fun getNextCustomID(): UInt64 {
            var nextId = DimensionX.customSupply + UInt64(1)
            return (nextId <= 1000) ? nextId : self.getNextCommonID()
        }

        // Determine the next available ID for genesis NFTs and use the reserved
        // range if possible
        pub fun getNextGenesisID(): UInt64 {
            var nextId = UInt64(1000) + DimensionX.genesisSupply + UInt64(1)
            return (nextId <= 11000) ? nextId : panic("Cannot mint more than 10000 genesis NFTs")
        }

        // Determine the next available ID for the rest of NFTs and take into
        // account the custom NFTs that have been minted outside of the reserved
        // range
        pub fun getNextCommonID(): UInt64 {
            var customIdOverflow = Int256(DimensionX.customSupply) - Int256(1000)
            customIdOverflow = customIdOverflow > 0 ? customIdOverflow : 0
            return 11000 + DimensionX.commonSupply + UInt64(customIdOverflow) + UInt64(1)
        }

        pub fun mintCustomNFT(
            recipient: &Collection{NonFungibleToken.CollectionPublic},
        ) {
            var nextId = self.getNextCustomID()

            // Update supply counters
            DimensionX.customSupply = DimensionX.customSupply + UInt64(1)
            DimensionX.totalSupply = DimensionX.totalSupply + UInt64(1)

            self.mint(
                recipient: recipient,
                id: nextId,
                type: DimensionX.NFTType.custom
            )
        }

        pub fun mintGenesisNFT(
            recipient: &Collection{NonFungibleToken.CollectionPublic},
        ) {
            // Determine the next available ID
            var nextId = self.getNextGenesisID()

            // Update supply counters
            DimensionX.genesisSupply = DimensionX.genesisSupply + UInt64(1)
            DimensionX.totalSupply = DimensionX.totalSupply + UInt64(1)

            self.mint(
                recipient: recipient,
                id: nextId,
                type: DimensionX.NFTType.genesis
            )
        }

        pub fun mintNFT(
            recipient: &Collection{NonFungibleToken.CollectionPublic},
        ) {
            // Determine the next available ID
            var nextId = self.getNextCommonID()

            // Update supply counters
            DimensionX.commonSupply = DimensionX.commonSupply + UInt64(1)
            DimensionX.totalSupply = DimensionX.totalSupply + UInt64(1)

            self.mint(
                recipient: recipient,
                id: nextId,
                type: DimensionX.NFTType.common
            )
        }

        pub fun mintStakedNFT(
            recipient: &Collection{NonFungibleToken.CollectionPublic},
        ) {
            var nextId = self.getNextCommonID()
            self.mintNFT(recipient: recipient)
            let ownerAddress = recipient.owner?.address
            DimensionX.stakedNfts[nextId] = ownerAddress
            emit Stake(id: nextId, to:ownerAddress)
        }

        priv fun mint(
            recipient: &Collection{NonFungibleToken.CollectionPublic},
            id: UInt64,
            type: DimensionX.NFTType,
        ) {
            // create a new NFT
            var newNFT <- create NFT(id: id, type: type)
            switch newNFT.type {
                case NFTType.custom:
                    emit Mint(id: id, type: UInt8(0))
                case NFTType.genesis:
                    emit Mint(id: id, type: UInt8(1))
                case NFTType.common:
                    emit Mint(id: id, type: UInt8(2))
            }
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)
        }
    }

    pub resource Admin {
        pub fun unstake(id: UInt64) {
            pre {
                DimensionX.stakedNfts.containsKey(id):
                    "Cannot unstake: the token is not staked"
            }

            let ownerAddress = DimensionX.stakedNfts[id]
            DimensionX.stakedNfts.remove(key: id)

            emit Unstake(id: id, from: ownerAddress)
        }

        pub fun setMetadataUrl(url: String) {
            DimensionX.metadataUrl = url
        }

        pub fun setThulMintPrice(price: UFix64) {
            DimensionX.thulMintPrice = price
        }

        pub fun setThulMintEnabled(enabled: Bool) {
            DimensionX.thulMintEnabled = enabled
        }

        pub fun createNFTMinter(): @NFTMinter {
            emit MinterCreated()
            return <-create NFTMinter()
        }

        pub fun setCrypthulhuSleepTime(time: UFix64) {
            DimensionX.crypthulhuSleepTime = time
            self.crypthulhuAwake()
        }

        pub fun crypthulhuAwake() {
            DimensionX.crypthulhuAwake = getCurrentBlock().timestamp
        }
    }

    pub fun mint(
        recipient: &Collection{NonFungibleToken.CollectionPublic},
        paymentVault: @ThulToken.Vault
    ) {
        pre {
            DimensionX.thulMintEnabled : "Cannot mint: $THUL minting is not enabled"
            paymentVault.balance >= DimensionX.thulMintPrice : "Insufficient funds"
        }

        let minter = self.account.borrow<&NFTMinter>(from: self.MinterStoragePath)!
        minter.mintNFT(recipient: recipient)

        let contractVault = self.account.borrow<&ThulToken.Vault>(from: ThulToken.VaultStoragePath)!
        contractVault.deposit(from: <- paymentVault)
    }

    init() {
        // Initialize supply counters
        self.totalSupply = 0
        self.customSupply = 0
        self.genesisSupply = 0
        self.commonSupply = 0

        // Initialize burned counters
        self.totalBurned = 0
        self.customBurned = 0
        self.genesisBurned = 0
        self.commonBurned = 0

        self.thulMintPrice = UFix64(120)
        self.thulMintEnabled = false
        self.metadataUrl = "https://www.dimensionx.com/api/nfts/"
        self.stakedNfts = {}

        // Initialize Dead Man's Switch
        self.crypthulhuAwake = getCurrentBlock().timestamp
        self.crypthulhuSleepTime = UFix64(60 * 60 * 24 * 30)

        // Set the named paths
        self.CollectionStoragePath = /storage/dmxCollection
        self.CollectionPublicPath = /public/dmxCollection
        self.AdminStoragePath = /storage/dmxAdmin
        self.MinterStoragePath = /storage/dmxMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&DimensionX.Collection{NonFungibleToken.CollectionPublic, CollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        let admin <- create Admin()
        let minter <- admin.createNFTMinter()
        self.account.save(<-admin, to: self.AdminStoragePath)
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}