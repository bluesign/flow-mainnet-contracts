import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import LicensedNFT from 0x01ab36aaf654a13e

// RaribleNFT token contract
//
pub contract RaribleNFT : NonFungibleToken, LicensedNFT {

    pub var totalSupply: UInt64

    pub var collectionPublicPath: PublicPath
    pub var collectionStoragePath: StoragePath
    pub var minterPublicPath: PublicPath
    pub var minterStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event Mint(id: UInt64, creator: Address, metadata: {String:String}, royalties: [LicensedNFT.Royalty])
    pub event Destroy(id: UInt64)

    pub struct Royalty {
        pub let address: Address
        pub let fee: UFix64

        init(address: Address, fee: UFix64) {
            self.address = address
            self.fee = fee
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let creator: Address
        access(self) let metadata: {String:String}
        access(self) let royalties: [LicensedNFT.Royalty]

        init(id: UInt64, creator: Address, metadata: {String:String}, royalties: [LicensedNFT.Royalty]) {
            self.id = id
            self.creator = creator
            self.metadata = metadata
            self.royalties = royalties
        }

        pub fun getViews(): [Type] {
            return [Type<MetadataViews.Display>()]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.metadata["name"] ?? "",
                        description: self.metadata["description"] ?? "",
                        thumbnail: MetadataViews.HTTPFile(url: self.metadata["metaURI"] ?? ""),
                    )
            }
            return nil
        }

        pub fun getMetadata(): {String:String} {
            return self.metadata
        }

        pub fun getRoyalties(): [LicensedNFT.Royalty] {
            return self.royalties
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface CollectionPublic {
        pub fun borrow(id: UInt64): &NFT?
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, LicensedNFT.CollectionPublic, CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @RaribleNFT.NFT
            let id: UInt64 = token.id
            let dummy <- self.ownedNFTs[id] <- token
            destroy dummy
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
            let authRef = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            let ref = authRef as! &NFT
            return ref as! &{MetadataViews.Resolver}
        }

        pub fun borrow(id: UInt64): &NFT? {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return ref as! &RaribleNFT.NFT
        }

        pub fun getMetadata(id: UInt64): {String:String} {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return (ref as! &RaribleNFT.NFT).getMetadata()
        }

        pub fun getRoyalties(id: UInt64): [LicensedNFT.Royalty] {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return (ref as! &LicensedNFT.NFT).getRoyalties()
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource Minter {
        pub fun mintTo(creator: Capability<&{NonFungibleToken.Receiver}>, metadata: {String:String}, royalties: [LicensedNFT.Royalty]): &NonFungibleToken.NFT {
            let token <- create NFT(
                id: RaribleNFT.totalSupply,
                creator: creator.address,
                metadata: metadata,
                royalties: royalties
            )
            RaribleNFT.totalSupply = RaribleNFT.totalSupply + 1
            let tokenRef = &token as &NonFungibleToken.NFT
            emit Mint(id: token.id, creator: creator.address, metadata: metadata, royalties: royalties)
            creator.borrow()!.deposit(token: <- token)
            return tokenRef
        }
    }

    pub fun minter(): Capability<&Minter> {
        return self.account.getCapability<&Minter>(self.minterPublicPath)
    }

    init() {
        self.totalSupply = 0
        self.collectionPublicPath = /public/RaribleNFTCollection
        self.collectionStoragePath = /storage/RaribleNFTCollection
        self.minterPublicPath = /public/RaribleNFTMinter
        self.minterStoragePath = /storage/RaribleNFTMinter

        let minter <- create Minter()
        self.account.save(<- minter, to: self.minterStoragePath)
        self.account.link<&Minter>(self.minterPublicPath, target: self.minterStoragePath)

        let collection <- self.createEmptyCollection()
        self.account.save(<- collection, to: self.collectionStoragePath)
        self.account.link<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(self.collectionPublicPath, target: self.collectionStoragePath)

        emit ContractInitialized()
    }
}
