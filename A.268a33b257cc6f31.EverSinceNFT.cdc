// EverSinceNFT.cdc
//
// This is a complete version of the EverSinceNFT contract
// that includes withdraw and deposit functionality, as well as a
// collection resource that can be used to bundle NFTs together.
//
// It also includes a definition for the Minter resource,
// which can be used by admins to mint new NFTs.
//
// Learn more about non-fungible tokens in this tutorial: https://docs.onflow.org/docs/non-fungible-tokens
// import NonFungibleToken from 0x631e88ae7f1d7c20
// import MetadataViews from 0x631e88ae7f1d7c20
// import FungibleToken from 0x9a0766d93b6608b7

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract EverSinceNFT : NonFungibleToken{

    // Declare Path constants so paths do not have to be hardcoded
    // in transactions and scripts

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event UseBonus(id: UInt64)

    pub var totalSupply: UInt64

    // Declare the NFT resource type
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver  {
        // The unique ID that differentiates each NFT
        pub let id: UInt64
        pub var metadata: { String : String }
        // Initialize both fields in the init function
        init(initID: UInt64, metadata:{String : String}) {
            self.id = initID
            self.metadata = metadata
        }
        pub fun getMetadata(): {String : String} {
            return self.metadata
        }

        pub fun useBonus(){
            assert(self.metadata["bonus"] != "0",message:"cannot use NFT if bonus is zero")
            self.metadata["bonus"] = "0"
            emit UseBonus(id: self.id)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ];
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                if(self.metadata["bonus"]!="0"){
                    return MetadataViews.Display(
                        id: self.id.toString(),
                        bonus: self.metadata["bonus"]!,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metadata["uri"]!
                        )
                    )
                }
                    else{
                        return MetadataViews.Display(
                        id: self.id.toString(),
                        bonus: self.metadata["bonus"]!,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metadata["usedUri"]!
                        )
                    )
                    }
            }
            return nil;
        }
}


    pub resource interface EverSinceNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} // from MetadataViews
        pub fun borrowEverSinceNFT(id: UInt64): &EverSinceNFT.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow EverSinceNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }
    // The definition of the Collection resource that
    // holds the NFTs that a user owns
    pub resource Collection: 
        NonFungibleToken.Provider,
        NonFungibleToken.Receiver,
        NonFungibleToken.CollectionPublic,
        MetadataViews.ResolverCollection,
        EverSinceNFTCollectionPublic {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @EverSinceNFT.NFT
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

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let card = nft as! &EverSinceNFT.NFT
            return card as &AnyResource{MetadataViews.Resolver}
        }

        pub fun borrowEverSinceNFT(id: UInt64): &EverSinceNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &EverSinceNFT.NFT
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

    // creates a new empty Collection resource and returns it 
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    //
    // Resource that would be owned by an admin or by a smart contract 
    // that allows them to mint new NFTs when needed
    pub resource NFTMinter {
        // mintNFT 
        //
        // Function that mints a new NFT with a new ID
        // and returns it to the caller
        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, metadata: {String : String}) {
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-create EverSinceNFT.NFT(initID: EverSinceNFT.totalSupply, metadata: metadata))

            EverSinceNFT.totalSupply = EverSinceNFT.totalSupply + (1 as UInt64)
        }
    }

	init() {
        self.CollectionStoragePath = /storage/nftTutorialCollection
        self.CollectionPublicPath = /public/nftTutorialCollection
        self.MinterStoragePath = /storage/nftTutorialMinter
        self.totalSupply = 0
		// store an empty NFT Collection in account storage
        self.account.save(<-self.createEmptyCollection(), to: self.CollectionStoragePath)

        // publish a reference to the Collection in storage
        // create a public capability for the collection
        self.account.link<&EverSinceNFT.Collection{NonFungibleToken.CollectionPublic, EverSinceNFT.EverSinceNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // store a minter resource in account storage
        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)
        emit ContractInitialized()

	}
}
 
 