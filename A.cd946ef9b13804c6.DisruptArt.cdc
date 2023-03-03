// DisruptArt NFT Marketplace
// NFT smart contract
// NFT Marketplace : www.disrupt.art
// Owner           : Disrupt Art, INC.
// Developer       : www.blaze.ws
// Version         : 0.0.8
// Blockchain      : Flow www.onFlow.org

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract DisruptArt: NonFungibleToken {
   
    // Total number of token supply
    pub var totalSupply: UInt64

    // NFT No of Editions(Multiple copies) limit
    pub var editionLimit: UInt

    /// Path where the `Collection` is stored
    pub let disruptArtStoragePath: StoragePath

    /// Path where the public capability for the `Collection` is
    pub let disruptArtPublicPath: PublicPath

    /// NFT Minter
    pub let disruptArtMinterPath: StoragePath
    
    // Contract Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64, content:String, owner: Address?, name:String)
    pub event GroupMint(id: UInt64, content:String, owner: Address?, name:String, tokenGroupId: UInt64 )


    // TOKEN RESOURCE
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        // Unique identifier for NFT Token
        pub let id :UInt64

        // Meta data to store token data (use dict for data)
        access(self) let metaData: {String : String}
        
        pub fun getMetadata():{String: String} {
            return self.metaData
        }

        // NFT token name
        pub let name:String

        // NFT token creator address
        pub let creator:Address?

        // In current store static dict in meta data
        init( id : UInt64, content : String, name:String, description:String , creator:Address?,previewContent:String,mimeType:String) {
            self.id = id
            self.metaData = {"content" : content, "description": description, "previewContent":previewContent, "mimeType":mimeType }
            self.creator = creator
            self.name = name
        }

        access(self) fun getFlowRoyaltyReceiverPublicPath(): PublicPath {
	     return /public/flowTokenReceiver
        }


        // fn to get the royality details
        access(self) fun genRoyalities():[MetadataViews.Royalty] {

            var royalties:[MetadataViews.Royalty] = []             

            // Creator Royalty
            royalties.append(
                MetadataViews.Royalty(
                    receiver: getAccount(self.creator!).getCapability<&FungibleToken.Vault{FungibleToken.Receiver}>(self.getFlowRoyaltyReceiverPublicPath()),
                    cut: UFix64(0.1),
                    description: "Creator Royalty"
                )
            )

            return royalties
        }
        
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.metaData["description"]!,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.metaData["previewContent"]!
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.genRoyalities()
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://disrupt.art")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: DisruptArt.disruptArtStoragePath,
                        publicPath: DisruptArt.disruptArtPublicPath,
                        providerPath: /private/DisruptArtNFTCollection,
                        publicCollection: Type<&DisruptArt.Collection{DisruptArt.DisruptArtCollectionPublic}>(),
                        publicLinkedType: Type<&DisruptArt.Collection{DisruptArt.DisruptArtCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&DisruptArt.Collection{DisruptArt.DisruptArtCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-DisruptArt.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://disrupt.art/nft/assets/images/logoicon.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "DisruptArt Collection",
                        description: "Discover amazing NFT collections from various disruptor creators. Disrupt.art Marketplace's featured and spotlight NFTs",
                        externalURL: MetadataViews.ExternalURL("https://disrupt.art"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/DisruptArt"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/disrupt.art/"),
                            "discord" : MetadataViews.ExternalURL("https://discord.io/disruptart")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    return []
            }
            return nil
        }

    }

    // Account's public collection
    pub resource interface DisruptArtCollectionPublic {

        pub fun deposit(token:@NonFungibleToken.NFT)

        pub fun getIDs(): [UInt64]

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        
        pub fun borrowDisruptArt(id: UInt64): &DisruptArt.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow CaaPass reference: The ID of the returned reference is incorrect"
            }
        }

    } 

    // NFT Collection resource
    pub resource Collection : DisruptArtCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
        // Contains caller's list of NFTs
        pub var ownedNFTs: @{UInt64 : NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {

            let token <- token as! @DisruptArt.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // function returns token keys of owner
        pub fun getIDs():[UInt64] {
            return self.ownedNFTs.keys
        }

        // function returns token data of token id
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
        
        // Gets a reference to an NFT in the collection as a DisruptArt
        pub fun borrowDisruptArt(id: UInt64): &DisruptArt.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &DisruptArt.NFT
            } else {
                return nil
            }
        }

        // function to check wether the owner have token or not
        pub fun tokenExists(id:UInt64) : Bool {
            return self.ownedNFTs[id] != nil
        }

        pub fun withdraw(withdrawID:UInt64) : @NonFungibleToken.NFT {
            
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token    
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let DisruptArtNFT = nft as! &DisruptArt.NFT
            return DisruptArtNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy(){
            destroy self.ownedNFTs
        }

    }

    // NFT MINTER
    pub resource NFTMinter {

        // Function to mint group of tokens
        pub fun GroupMint(recipient: &{DisruptArtCollectionPublic},content:String, description:String, name:String, edition:UInt, tokenGroupId:UInt64, previewContent:String, mimeType:String) {
            pre {
                DisruptArt.editionLimit >= edition : "Edition count exceeds the limit"
                edition >=2 : "Edition count should be greater than or equal to 2"
            }
            var count = 0 as UInt
            
            while count < edition {
                let token <- create NFT(id: DisruptArt.totalSupply, content:content, name:name, description:description, creator: recipient.owner?.address,previewContent:previewContent,mimeType:mimeType)
                emit GroupMint(id:DisruptArt.totalSupply,content:content,owner: recipient.owner?.address, name:name, tokenGroupId:tokenGroupId)
                recipient.deposit(token: <- token)
                DisruptArt.totalSupply = DisruptArt.totalSupply + 1 as UInt64
                count = count + 1
            }
        }

        pub fun Mint(recipient: &{DisruptArtCollectionPublic},content:String, name:String, description:String,previewContent:String,mimeType:String ) {
            let token <- create NFT(id: DisruptArt.totalSupply, content:content, name:name, description:description, creator: recipient.owner?.address,previewContent:previewContent, mimeType:mimeType)
            emit Mint(id:DisruptArt.totalSupply,content:content,owner: recipient.owner?.address, name:name)
            recipient.deposit(token: <- token)
            DisruptArt.totalSupply = DisruptArt.totalSupply + 1 as UInt64
        } 
    }

    // This is used to create the empty collection. without this address cannot access our NFT token
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create DisruptArt.Collection()
    }
    // Admin can change the maximum supported group minting count limit for the platform. Currently it is 50
    pub resource Admin {
        pub fun changeLimit(limit:UInt) {
            DisruptArt.editionLimit = limit
        }
    }

    // Contract init
    init() {

        // total supply is zero at the time of contract deployment
        self.totalSupply = 0

        self.editionLimit = 10000

        self.disruptArtStoragePath = /storage/DisruptArtNFTCollection

        self.disruptArtPublicPath = /public/DisruptArtNFTPublicCollection

        self.disruptArtMinterPath = /storage/DisruptArtNFTMinter

        self.account.save(<-self.createEmptyCollection(), to: self.disruptArtStoragePath)

        self.account.link<&{DisruptArtCollectionPublic}>(self.disruptArtPublicPath, target:self.disruptArtStoragePath)

        self.account.save(<-create self.Admin(), to: /storage/DirsuptArtAdmin)

        // store a minter resource in account storage
        self.account.save(<-create NFTMinter(), to: self.disruptArtMinterPath)

        emit ContractInitialized()

    }

}

