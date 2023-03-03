//
//  _____         _            _
// /  ___|       | |          | |
// \ `--.   __ _ | | __ _   _ | |_   __ _  _ __   ___
//  `--. \ / _` || |/ /| | | || __| / _` || '__| / _ \
// /\__/ /| (_| ||   < | |_| || |_ | (_| || |   | (_) |
// \____/  \__,_||_|\_\ \__,_| \__| \__,_||_|    \___/
//
//
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import SakutaroPoemContent from 0x754c1187102a4b94

pub contract SakutaroPoemReplica: NonFungibleToken {
    pub let CollectionPublicPath: PublicPath
    pub let CollectionStoragePath: StoragePath
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64)
    pub event Destroy(id: UInt64)

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        init(id: UInt64) {
            self.id = id
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let poem = self.getPoem()
                    return MetadataViews.Display(
                        name: (poem?.title ?? SakutaroPoemContent.name).concat(" [Replica]"),
                        description: SakutaroPoemContent.description,
                        thumbnail: MetadataViews.IPFSFile(cid: poem?.ipfsCid ?? "", path: nil),
                    )
            }
            return nil
        }

        pub fun getPoemID(): UInt32? {
            if self.owner == nil {
              return nil
            }
            var num: UInt32 = 0
            var val = self.owner!.address.toBytes()
            for v in val {
                num = num + UInt32(v)
            }
            return num % 39
        }

        pub fun getPoem(): SakutaroPoemContent.Poem? {
            let poemID = self.getPoemID()
            if poemID == nil {
              return nil
            }
            return SakutaroPoemContent.getPoem(poemID!)
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface SakutaroPoemReplicaCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowPoem(id: UInt64): &SakutaroPoemReplica.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Poem reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: SakutaroPoemReplicaCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @SakutaroPoemReplica.NFT
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
 
        pub fun borrowPoem(id: UInt64): &SakutaroPoemReplica.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &SakutaroPoemReplica.NFT?
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return nft as! &SakutaroPoemReplica.NFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun mintNFT() : @NFT {
        pre {
            SakutaroPoemReplica.totalSupply < 10000: "Can't mint any more"
        }
        SakutaroPoemReplica.totalSupply = SakutaroPoemReplica.totalSupply + 1
        let token <- create NFT(id: SakutaroPoemReplica.totalSupply)
        emit Mint(id: token.id)
        return <- token
    }

    init() {
        self.CollectionPublicPath = /public/SakutaroPoemReplicaCollection
        self.CollectionStoragePath = /storage/SakutaroPoemReplicaCollection
        self.totalSupply = 0

        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&SakutaroPoemReplica.Collection{NonFungibleToken.CollectionPublic, SakutaroPoemReplica.SakutaroPoemReplicaCollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
