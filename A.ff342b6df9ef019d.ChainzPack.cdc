import ChainzNFT from 0xff342b6df9ef019d
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import FungibleToken from 0xf233dcee88fe0abe

pub contract ChainzPack: NonFungibleToken {

    pub var totalSupply: UInt64
    pub var nextPackTypeId: UInt64
    access(self) let packTypes: {UInt64: PackType}

    pub struct PackType {
        pub let id: UInt64
        pub let name: String
        pub let price: UFix64
        pub var amountMinted: UInt64
        pub let reserved: UInt64
        pub var takenFromReserved: UInt64
        pub let maxSupply: UInt64
        pub var isSaleActive: Bool
        pub let extra: {String: String}

        pub fun minted() {
            self.amountMinted = self.amountMinted + 1
        }

        pub fun usedReserve() {
            self.takenFromReserved = self.takenFromReserved + 1
        }

        pub fun toggleActive() {
            self.isSaleActive = !self.isSaleActive
        }

        init(_name: String, _price: UFix64, _maxSupply: UInt64, _reserved: UInt64, _extra: {String: String}) {
            self.id = ChainzPack.nextPackTypeId
            self.name = _name
            self.price = _price
            self.amountMinted = 0
            self.maxSupply = _maxSupply
            self.reserved = _reserved
            self.takenFromReserved = 0
            self.isSaleActive = false
            self.extra = _extra
        }
    }

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub resource NFT: NonFungibleToken.INFT {
        // The Pack's id
        pub let id: UInt64
        pub let sequence: UInt64
        pub let packTypeId: UInt64

        init(_packTypeId: UInt64) {
            self.id = self.uuid
            ChainzPack.totalSupply = ChainzPack.totalSupply + 1
            self.sequence = ChainzPack.totalSupply
            self.packTypeId = _packTypeId
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowPack(id: UInt64): &ChainzPack.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow Pack reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // IPackCollectionAdminAccessible
    // Exposes the openPack which allows an admin to
    // open a pack in this collection.
    //
    pub resource interface AdminAccessible {
        access(account) fun openPack(id: UInt64, cardCollectionRef: &ChainzNFT.Collection{ChainzNFT.CollectionPublic}, names: [String], descriptions: [String], thumbnails: [String], metadatas: [{String: String}])
    }

    // Collection
    // a collection of Pack resources so that users can
    // own Packs in a collection and trade them back and forth.
    //
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, AdminAccessible  {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @ChainzPack.NFT
            let id: UInt64 = token.id
            self.ownedNFTs[id] <-! token
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing Pack")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        // openPack
        // This method removes a Pack from this Collection and then
        // deposits newly minted Cards into the Collection reference by
        // calling depositBatch on the reference. 
        //
        // The Pack is also destroyed in the process so it will no longer
        // exist
        //
        access(account) fun openPack(id: UInt64, cardCollectionRef: &ChainzNFT.Collection{ChainzNFT.CollectionPublic}, names: [String], descriptions: [String], thumbnails: [String], metadatas: [{String: String}]) {
            let pack <- self.withdraw(withdrawID: id)
            var i: Int = 0
            // Mints new Cards into this empty Collection
            while i < names.length {
                let newCard: @ChainzNFT.NFT <- ChainzNFT.createNFT(name: names[i], description: descriptions[i], thumbnail: thumbnails[i], metadata: metadatas[i])
                cardCollectionRef.deposit(token: <-newCard)
                i = i + 1
            }
        
            destroy pack
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowPack(id: UInt64): &ChainzPack.NFT? {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return ref as! &ChainzPack.NFT?
        }

        destroy() {
            destroy self.ownedNFTs
        }

        init() {   
            self.ownedNFTs <- {}
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    access(account) fun createPackType(name: String, price: UFix64, maxSupply: UInt64, reserved: UInt64, extra: {String: String}) {
        self.packTypes[self.nextPackTypeId] = PackType(_name: name, _price: price, _maxSupply: maxSupply, _reserved: reserved, _extra: extra)
        self.nextPackTypeId = self.nextPackTypeId + 1
    }

    access(account) fun toggleActive(packTypeId: UInt64) {
        let packType = (&self.packTypes[packTypeId] as &PackType?) ?? panic("This Pack Type does not exist.")
        packType.toggleActive()
    }

    pub fun getPackType(packTypeId: UInt64): PackType? {
        return self.packTypes[packTypeId]
    }

    pub fun mintPack(packCollectionRef: &ChainzPack.Collection{ChainzPack.CollectionPublic}, packTypeId: UInt64, payment: @DapperUtilityCoin.Vault) {
        let packType = (&self.packTypes[packTypeId] as &PackType?) ?? panic("This Pack Type does not exist.")
        assert(payment.balance == packType.price, message: "The correct payment amount was not passed in.")
        assert(packType.amountMinted < packType.maxSupply - packType.reserved, message: "This Pack Type is sold out.")
        assert(packType.isSaleActive, message: "The drop is not currently active.")
        packCollectionRef.deposit(token: <- create NFT(_packTypeId: packTypeId))
        packType.minted()

        // WHERE DOES THE PAYMENT GO?
        let treasury = getAccount(0xd1120ae332f528f0).getCapability(/public/dapperUtilityCoinReceiver)
                            .borrow<&{FungibleToken.Receiver}>() 
                            ?? panic("This is not a Dapper Wallet account.")
        treasury.deposit(from: <- payment)
    }

    access(account) fun reserveMint(packCollectionRef: &ChainzPack.Collection{ChainzPack.CollectionPublic}, packTypeId: UInt64) {
        let packType = (&self.packTypes[packTypeId] as &PackType?) ?? panic("This Pack Type does not exist.")
        assert(packType.amountMinted < packType.maxSupply, message: "This Pack Type is sold out.")
        assert(packType.takenFromReserved < packType.reserved, message: "You have used up all of the reserves.")
        packCollectionRef.deposit(token: <- create NFT(_packTypeId: packTypeId))
        packType.minted()
        packType.usedReserve()
    }

    init() {
        self.totalSupply = 0
        self.nextPackTypeId = 0
        self.packTypes = {}

        self.CollectionStoragePath = /storage/ChainzPackCollection
        self.CollectionPublicPath = /public/ChainzPackCollection

        emit ContractInitialized()
    }
}
 