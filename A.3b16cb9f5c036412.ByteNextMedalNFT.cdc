import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract ByteNextMedalNFT : NonFungibleToken {

    pub var totalSupply: UInt64

    pub var CollectionPublicPath: PublicPath
    pub var CollectionStoragePath: StoragePath
    pub var MinterStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event Mint(id: UInt64, metadata: {String:String})
    pub event Destroy(id: UInt64)

    pub let mintedNfts: {UInt64: Bool};

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        access(self) var metadata: {String:String}

        init(id: UInt64, metadata: {String:String}) {
            self.id = id
            self.metadata = metadata
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

        destroy() {
            ByteNextMedalNFT.mintedNfts[self.id] = false;
            ByteNextMedalNFT.totalSupply = ByteNextMedalNFT.totalSupply - 1;
            emit Destroy(id: self.id)
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrow(id: UInt64): &NFT?
        pub fun borrowMedalNFT(id: UInt64): &ByteNextMedalNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow AADigital reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, CollectionPublic {
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
            let token <- token as! @ByteNextMedalNFT.NFT
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
            return ref as! &ByteNextMedalNFT.NFT
        }

        pub fun borrowMedalNFT(id: UInt64): &ByteNextMedalNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &ByteNextMedalNFT.NFT
            }

            return nil
        }

        pub fun getMetadata(id: UInt64): {String:String} {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return (ref as! &ByteNextMedalNFT.NFT).getMetadata()
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource Minter {
        pub fun mint(id: UInt64, metadata: {String:String}): @NonFungibleToken.NFT {
            pre{
                ByteNextMedalNFT.mintedNfts[id] == nil || ByteNextMedalNFT.mintedNfts[id] == false:
                    "This id has been minted before"
            }
            ByteNextMedalNFT.totalSupply = ByteNextMedalNFT.totalSupply + 1
            let token <- create NFT(
                id: id,
                metadata: metadata
            )

            ByteNextMedalNFT.mintedNfts[id] = true;
            
            emit Mint(id: token.id, metadata: metadata)
            return <- token;
        }
    }

    init() {
        self.totalSupply = 0
        self.CollectionPublicPath = /public/ByteNextMedalNFTCollection
        self.CollectionStoragePath = /storage/ByteNextMedalNFTCollection
        self.MinterStoragePath = /storage/ByteNextMedalNFTMinter

        self.mintedNfts = {};

        let minter <- create Minter()
        self.account.save(<- minter, to: self.MinterStoragePath)

        let collection <- self.createEmptyCollection()
        self.account.save(<- collection, to: self.CollectionStoragePath)
        self.account.link<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        emit ContractInitialized()
    }
}
