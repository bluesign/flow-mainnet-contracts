// SPDX-License-Identifier: MIT

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract TrartContractNFT: NonFungibleToken {

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
	
    pub event Mint(id: UInt64)
    pub event Burn(id: UInt64)

    // -----------------------------------------------------------------------
    // fields.
    // -----------------------------------------------------------------------
	
    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub var totalSupply: UInt64

    access(self) let metadatas: {UInt64: Metadata} 

    // -----------------------------------------------------------------------
    // Metadata
    // -----------------------------------------------------------------------

    // Metadatas are content data of NFTs, those are public data. Anyone can query this to find the detail. 
    // Initialize the metadata value directly during init phase in the NFT resource section. There is no remove function since as a proof of existence.
    pub struct Metadata {
       pub let cardID: UInt64
       pub let data: {String: String} 
	   
       init(cardID: UInt64, data: {String:String}){
           self.cardID = cardID
           self.data = data
       }
    }

    // Get all metadatas
    pub fun getMetadatas(): {UInt64: Metadata} {
        return self.metadatas;
    }

    pub fun getMetadatasCount(): UInt64 {
        return UInt64(self.metadatas.length)
    }

    pub fun getMetadataForCardID(cardID: UInt64): Metadata? {
        return self.metadatas[cardID]
    }
	
    // -----------------------------------------------------------------------
    // NFT
    // -----------------------------------------------------------------------
	
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        init(initID: UInt64, metadata: {String: String}) {
            TrartContractNFT.totalSupply = TrartContractNFT.totalSupply + (1 as UInt64)
            TrartContractNFT.metadatas[initID] = Metadata(cardID: initID, data: metadata)

            self.id = initID
            emit Mint(id: self.id)
        }

        destroy() {
            TrartContractNFT.totalSupply = TrartContractNFT.totalSupply - (1 as UInt64)
            emit Burn(id: self.id)
        }

        pub fun getCardMetadata(): Metadata? {
            return TrartContractNFT.getMetadataForCardID(cardID: self.id)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return self.getDisplay();
                case Type<MetadataViews.Royalties>():
                    return self.getRoyalties();
                case Type<MetadataViews.Traits>():
                    return self.getTraits();
                case Type<MetadataViews.ExternalURL>():
                    return self.getExternalURL();
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return self.getNFTCollectionDisplay();
                case Type<MetadataViews.NFTCollectionData>():
                    return self.getNFTCollectionData();
            }

            return nil
        }  

        pub fun getDisplay(): MetadataViews.Display? {
            if let info  = self.getCardMetadata() {
                let metadata = info.data

                var nftTitle: String = metadata["NAME"]??""

                var nftDesc : String = metadata["CARD NUMBER"]??""
                if metadata["CARD SERIES"] != nil && metadata["CARD NUMBER"] != nil {
                    nftDesc = metadata["CARD SERIES"]??"".concat(" - ").concat(metadata["CARD NUMBER"]??"")
                }

                let ipfsScheme = "ipfs://"
                let httpsScheme = "https://"

                var mediaURL: String = metadata["URI"]?? metadata["URL"]?? ""

                if mediaURL.length > ipfsScheme.length && self.stringStartsWith(string: mediaURL, prefix: ipfsScheme) {
                    mediaURL = "https://trartgateway.mypinata.cloud/ipfs/".concat(mediaURL.slice(from: ipfsScheme.length, upTo: mediaURL.length));
                } else if mediaURL.length > httpsScheme.length && self.stringStartsWith(string: mediaURL, prefix: httpsScheme) {
                    mediaURL = mediaURL
                }

                return MetadataViews.Display(
                    name: nftTitle,
                    description: nftDesc,
                    thumbnail: MetadataViews.HTTPFile(url:mediaURL)
                )

            }
            return nil
        }

        pub fun getRoyalties(): MetadataViews.Royalties? {
            let royalties : [MetadataViews.Royalty] = [
                MetadataViews.Royalty(
                    receiver: getAccount(0x416e01b78d5b45ff).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!,
                    cut: 0.025,
                    description: "Royalty (2.5%)")
            ]
            return MetadataViews.Royalties(cutInfos: royalties)
        }

        pub fun getTraits(): MetadataViews.Traits? {
            if let info  = self.getCardMetadata() {
                let metadata = info.data

                let traits = MetadataViews.Traits([])
                for key in metadata.keys {
                    traits.addTrait(MetadataViews.Trait(name: key, value: metadata[key]??"", displayType: "String", rarity: nil))
                }
                return traits
            }
            return nil
        }

        pub fun getExternalURL(): MetadataViews.ExternalURL? {
  
            if let info  = self.getCardMetadata() {
                let metadata = info.data

                let ipfsScheme = "ipfs://"
                let httpsScheme = "https://"

                var mediaURL: String = metadata["URI"]?? metadata["URL"]?? ""

                if mediaURL.length > ipfsScheme.length && self.stringStartsWith(string: mediaURL, prefix: ipfsScheme) {
                    mediaURL = "https://trartgateway.mypinata.cloud/ipfs/".concat(mediaURL.slice(from: ipfsScheme.length, upTo: mediaURL.length));
                } else if mediaURL.length > httpsScheme.length && self.stringStartsWith(string: mediaURL, prefix: httpsScheme) {
                    mediaURL = mediaURL
                }

                return MetadataViews.ExternalURL(
                    url: mediaURL
                )
            }
            return nil
        }

        pub fun getNFTCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
            return MetadataViews.NFTCollectionDisplay(
                name: "Trart",
                description: "TRART is an international platform with NFTs (non-fungible tokens) from well-known artists around the world.",
                externalURL: MetadataViews.ExternalURL("https://trart.io"),
                squareImage: MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://trart.io/images/TRART_Logo.svg"
                    ),
                    mediaType: "image/svg+xml"),
                bannerImage: MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://trart.io/images/TRART_Banner_1200x630px.png"
                    ),
                    mediaType: "image/png"),
                socials: {
                    "twitter": MetadataViews.ExternalURL("https://twitter.com/IoTrart"),
                    "discord": MetadataViews.ExternalURL("https://discord.com/invite/yEyse2VkQB")
                }
            )
        }

        pub fun getNFTCollectionData(): MetadataViews.NFTCollectionData {
            return MetadataViews.NFTCollectionData(
                storagePath: TrartContractNFT.CollectionStoragePath,
                publicPath: TrartContractNFT.CollectionPublicPath,
                providerPath: /private/TrartContractNFTCollection,
                publicCollection: Type<&TrartContractNFT.Collection{TrartContractNFT.ICardCollectionPublic}>(),
                publicLinkedType: Type<&TrartContractNFT.Collection{TrartContractNFT.ICardCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&TrartContractNFT.Collection{TrartContractNFT.ICardCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-TrartContractNFT.createEmptyCollection()
            }))
        }

        access(self) fun stringStartsWith(string: String, prefix: String): Bool {
            let beginning = string.slice(from: 0, upTo: prefix.length)

            let prefixArray = prefix.utf8
            let beginningArray = beginning.utf8

            for index, element in prefixArray {
                if(beginningArray[index] != prefixArray[index]) {
                    return false
                }
            }

            return true
        }
    }

    // createNFT
    access(account) fun createNFT(cardID: UInt64, metadata: {String: String}): @NFT {
        return <- create NFT(initID: cardID, metadata: metadata)
    }

	// -----------------------------------------------------------------------
    // Collection
    // -----------------------------------------------------------------------
	
    pub resource interface ICardCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		
		pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun borrowCard(id: UInt64): &TrartContractNFT.NFT? {
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow NFT reference: The ID reference is incorrect"
            }
        }
    }

    pub resource Collection: ICardCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot withdraw: NFT does not exist in the collection")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            
            var batchCollection <- create Collection()
            
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }

            return <-batchCollection
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @TrartContractNFT.NFT

            let id: UInt64 = token.id

            let oldToken <- self.ownedNFTs[id] <- token

            if self.owner?.address != nil {
                emit Deposit(id: id, to: self.owner?.address)
            }

            destroy oldToken
        }

        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {

            let keys = tokens.getIDs()

            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            destroy tokens
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowCard(id: UInt64): &TrartContractNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &TrartContractNFT.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let card = nft as! &TrartContractNFT.NFT
            return card as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // -----------------------------------------------------------------------
    // minter
    // -----------------------------------------------------------------------
    
    pub resource NFTMinter {

        pub fun newNFT(cardID: UInt64, data: {String: String}): @NFT {
			return <- TrartContractNFT.createNFT(cardID: cardID, metadata: data)
        }

        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, cardID: UInt64, data: {String: String}) {
			recipient.deposit(token: <- TrartContractNFT.createNFT(cardID: cardID, metadata: data))
        }
    }

    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/TrartContractNFTCollection
        self.CollectionPublicPath = /public/TrartContractNFTCollection
        self.MinterStoragePath = /storage/TrartContractNFTMinter

        // Initialize the member variants
        self.totalSupply = 0
        self.metadatas = {}

         //collection
        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&TrartContractNFT.Collection{TrartContractNFT.ICardCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(TrartContractNFT.CollectionPublicPath, target: TrartContractNFT.CollectionStoragePath)

        // minter
        self.account.save(<- create NFTMinter(), to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 