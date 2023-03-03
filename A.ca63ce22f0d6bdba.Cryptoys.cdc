import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import CryptoysMetadataView from 0xca63ce22f0d6bdba
import ICryptoys from 0xca63ce22f0d6bdba

// Cryptoys
// The jam.
//
pub contract Cryptoys: NonFungibleToken, ICryptoys {
    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event AddedToBucket(owner: Address, key: String, id: UInt64, uuid: UInt64)
    pub event WithdrawnFromBucket(owner: Address, key: String, id: UInt64, uuid: UInt64)
    pub event Minted(id: UInt64, uuid: UInt64, metadata: {String:String}, royalties: [Royalty])
    pub event RoyaltyUpserted(name: String, royalty: Royalty)
    pub event DisplayUpdated(id: UInt64, image: String, video: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // totalSupply
    // The total number of Cryptoys that have been minted
    //
    pub var totalSupply: UInt64

    // NFT
    // A Cryptoy as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver, ICryptoys.INFT {
        // The token's ID
        pub let id: UInt64
        access(account) let metadata: {String: String}
        access(account) let royalties: [String]
        access(account) let bucket: @{String: {UInt64: AnyResource{ICryptoys.INFT}}}

        init(
            id:         UInt64,
            metadata:  {String: String},
            royalties: [String]?
        ){
            pre {
                metadata.length != 0: "Cryptoy failed to initialize: metadata cannot be empty"
            }
            self.id       = id
            self.metadata = metadata 

            self.royalties = royalties ?? []
            self.bucket <- {}
        }

        pub fun getMetadata(): {String: String} {
            return self.metadata
        }

        pub fun getDisplay(): Display {
            var image = ""
            var video = ""

            if Cryptoys.display[self.id] != nil {
                image     = Cryptoys.display[self.id]!.image
                video     = Cryptoys.display[self.id]!.video
            } 

            if image == "" {
                image = self.metadata["image"] ?? ""
            }

            if video == "" {
                video = self.metadata["video"] ?? ""
            }

            return Cryptoys.Display(image: image, video: video)
        }

        pub fun getRoyalties(): [Royalty] {
            var nftRoyalties: [Royalty] = []
            for royalty in self.royalties {
                var nftRoyalty: Royalty? =  Cryptoys.royalties[royalty]
                if nftRoyalty != nil {
                    nftRoyalties.append(nftRoyalty!)
                }
            }
            return nftRoyalties
        }

        access(account) fun withdrawBucketItem(_ key: String, _ itemUuid: UInt64): @AnyResource{ICryptoys.INFT} {
            let resources = self.borrowBucketResourcesByKey(key) ?? panic("withdrawBucketItem() failed to find resources by key: ".concat(key))

            let nft <- resources.remove(key: itemUuid) ?? panic("withdrawBucketItem() failed to find NFT in bucket with id: ".concat(itemUuid.toString()))
           
            emit WithdrawnFromBucket(owner: self.owner!.address, key: key, id: self.id, uuid: itemUuid)

            return <- nft
        }

        pub fun addToBucket(_ key: String, _ nft: @AnyResource{ICryptoys.INFT}) {
            let nftUuid: UInt64 = nft.uuid

            let resources =  self.borrowBucketResourcesByKey(key)
            if resources == nil {
                let bucket = self.borrowBucket()
                bucket[key] <-! {nftUuid: <- nft}
            } else {
                let exitingBucket = resources!
                exitingBucket[nftUuid] <-! nft
            }

            emit AddedToBucket(owner: self.owner!.address, key: key, id: self.id, uuid: nftUuid)
        }

        pub fun borrowBucketResourcesByKey(_ key: String): &{UInt64: AnyResource{ICryptoys.INFT}}? {
            return &self.bucket[key] as &{UInt64: AnyResource{ICryptoys.INFT}}?
        }

        pub fun borrowBucket(): &{String: {UInt64: AnyResource{ICryptoys.INFT}}} {
            return &self.bucket as &{String: {UInt64: AnyResource{ICryptoys.INFT}}}
        }

        pub fun getBucketKeys(): [String] {
            return self.borrowBucket().keys
        }

        pub fun getBucketResourceIdsByKey(_ key: String): [UInt64] {
            let resources = self.borrowBucketResourcesByKey(key) ?? panic("getBucketResourceIdsByKey() failed to find resources by key: ".concat(key))
            return resources.keys
        }

        pub fun borrowBucketItem(_ key: String, _ itemUuid: UInt64): &AnyResource{ICryptoys.INFT} {
            let resources = self.borrowBucketResourcesByKey(key) ??  panic("borrowBucketItem() failed to find resources by key: ".concat(key))
            
            let bucketItem = &resources[itemUuid] as auth &AnyResource{ICryptoys.INFT}? ?? panic("borrowBucketItem() failed to borrow resource with id: ".concat(itemUuid.toString()))
            return bucketItem as! &Cryptoys.NFT
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<CryptoysMetadataView.Cryptoy>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            var display = self.getDisplay()

            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.metadata["type"] ?? "",
                        description: self.metadata["description"] ?? "",
                        thumbnail: MetadataViews.HTTPFile(
                            url: display.image
                        )
                    )
                case Type<CryptoysMetadataView.Cryptoy>():
                    return CryptoysMetadataView.Cryptoy(
                        name:        self.metadata["type"],
                        description: self.metadata["description"],
                        image:       display.image,
                        coreImage:   self.metadata["coreImage"],
                        video:       display.video,
                        platformId:  self.metadata["platformId"],
                        category:    self.metadata["category"],
                        type:        self.metadata["type"],
                        skin:        self.metadata["skin"],
                        tier:        self.metadata["tier"],
                        rarity:      self.metadata["rarity"],
                        edition:     self.metadata["edition"],
                        series:      self.metadata["series"],
                        legionId:    self.metadata["legionId"],
                        creator:     self.metadata["creator"],
                        packaging:   self.metadata["packaging"],
                        termsUrl:    self.metadata["termsUrl"],
                    )
            }

            return nil
        }

        destroy() {
            destroy self.bucket
        }
    }

    // Collection
    // A collection of Cryptoy NFTs owned by an account
    //
    pub resource Collection: ICryptoys.CryptoysCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("withdraw() failed: missing NFT with id: ".concat(withdrawID.toString()))

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Cryptoys.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowCryptoy(id: UInt64): &AnyResource{ICryptoys.INFT} {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Cryptoys.NFT
            } else {
                return panic("borrowCryptoy() failed: cryptoy not found with id: ".concat(id.toString()))
            }
        }

        pub fun borrowBucketItem(_ id: UInt64, _ key: String, _ itemUuid: UInt64): &AnyResource{ICryptoys.INFT} {
            if self.ownedNFTs[id] == nil {
                return panic("borrowBucketItem() failed: parent cryptoy not found with id: ".concat(id.toString()))
            }
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let cryptoyRef = ref as! &Cryptoys.NFT

            return cryptoyRef.borrowBucketItem(key, itemUuid)
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let cryptoyNFT = nft as! &Cryptoys.NFT
            return cryptoyNFT
        }

        pub fun getRoyalties(id: UInt64): [Royalty] {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return (ref as! &NFT).getRoyalties()
        }

        pub fun withdrawBucketItem(parentId: UInt64, key: String, itemUuid: UInt64): @AnyResource{ICryptoys.INFT} {
            if self.ownedNFTs[parentId] == nil {
                panic("withdrawBucketItem() failed: parent cryptoy not found with id: ".concat(parentId.toString()))
            }
            let nftRef = (&self.ownedNFTs[parentId] as auth &NonFungibleToken.NFT?)!
            let cryptoyRef =  nftRef as! &Cryptoys.NFT

            return <- cryptoyRef.withdrawBucketItem(key, itemUuid)
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    pub struct Royalty {
        pub let name: String
        pub let address: Address
        pub let fee: UFix64

        init(name: String, address: Address, fee: UFix64) {
            self.name = name
            self.address = address
            self.fee = fee
        }
    }

    pub struct Display {
        pub let image: String
        pub let video: String

        init(image: String, video: String) {
            self.image = image
            self.video = video
        }
    }
    
    // royalties
    // royalties for each INFT
    //
    access(account) let royalties: {String: Royalty}

    // display for each composed NFTs
    //
    access(account) let display: {UInt64: Display}

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Admin
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs and update royalties
    //
    pub resource Admin {

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(
            recipient: Capability<&{NonFungibleToken.CollectionPublic}>, 
            metadata:  {String: String},
            royaltyNames: [String]?
        ): UInt64 {
            var nftRoyalties: [Royalty] = []

            if royaltyNames != nil {
                for royalty in royaltyNames! {
                    var nftRoyalty = Cryptoys.royalties[royalty]
                    if nftRoyalty == nil {
                        panic("mintNFT() failed: royalty not found: ".concat(royalty))
                    }
                    nftRoyalties.append(nftRoyalty!)
                }
            }

            let nftId = Cryptoys.totalSupply

            // deposit it in the recipient's account using their reference
            var nft <- create Cryptoys.NFT(
                id:        nftId, 
                metadata:  metadata,
                royalties: royaltyNames
            )

            emit Minted(id: nft.id, uuid: nft.uuid, metadata: nft.getMetadata(), royalties: nftRoyalties)

            Cryptoys.totalSupply = Cryptoys.totalSupply + 1

            recipient.borrow()!.deposit(token: <- nft)

            return nftId
        }

        pub fun upsertRoyalty(royalty: Royalty){
            Cryptoys.royalties[royalty.name] = royalty

            emit RoyaltyUpserted(name: royalty.name, royalty: royalty)
        }

        pub fun updateDisplay(cryptoy: &AnyResource{ICryptoys.INFT}, display: Display?) {
            if display != nil {
                 Cryptoys.display.insert(key: cryptoy.id, display!)
            } else {
                 Cryptoys.display.remove(key: cryptoy.id)
            }

            var display = cryptoy.getDisplay()
            emit DisplayUpdated(id: cryptoy.id, image: display.image, video: display.video)
        }

        pub fun getRoyalties(): {String: Royalty}{
            return Cryptoys.royalties
        }
    }

    // initializer
    //
    init() {
        // Set our named paths
        self.AdminStoragePath      = /storage/cryptoysAdmin
        self.CollectionStoragePath = /storage/cryptoysCollection
        self.CollectionPublicPath  = /public/cryptoysCollection

        // Initialize the total supply
        self.totalSupply = 0
        self.royalties = {}
        self.display = {}

        // store an empty NFT Collection in account storage
        self.account.save(<-self.createEmptyCollection(), to: self.CollectionStoragePath)

        // publish a reference to the Collection in storage
        self.account.link<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,ICryptoys.CryptoysCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        // Create a admin resource and save it to storage
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
 