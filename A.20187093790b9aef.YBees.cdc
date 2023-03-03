/*
    Description: 

    authors: Joseph Djenandji, Matthew Balazsi, Jennifer McIntyre
    
    This smart contract contains the core functionality for Mint PFP NFT. 
    
    MINT is a platform where teams can create a fully branded environment to sell NFTs and launch branded marketplaces. 
    This will give fans a fully immersive experience as they interact with drops, buy and sell in the marketplace, and 
    deepen their relationships with the brand.


    Enjoy!
*/

// import NonFungibleToken from "./NonFungibleToken.cdc"
// import MetadataViews from "./MetadataViews.cdc"

// for tests
// import NonFungibleToken from "0xNonFungibleToken"
// import MetadataViews from "0xMetadataViews"
// import FungibleToken from "0xFungibleToken"

// for testnet
// import NonFungibleToken from 0x631e88ae7f1d7c20
// import MetadataViews from 0x631e88ae7f1d7c20

// for mainnet
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448


pub contract YBees: NonFungibleToken {

    // -----------------------------------------------------------------------
    // MintPFPs contract Events
    // -----------------------------------------------------------------------

    // Emitted when the MintPFPs contract is created
    pub event ContractInitialized()


    // Emitted when a new item was minted
    pub event ItemMinted(itemID:UInt64, merchantID: UInt32, name: String)

    // Item related events 
    //
    // Emitted when an Item is withdrawn from a Collection
    pub event Withdraw(id: UInt64, from: Address?)
    // Emitted when an Item is deposited into a Collection
    pub event Deposit(id: UInt64, to: Address?)
    // Emitted when an Item is withdrawn from a Collection
    pub event ItemMutated(id: UInt64, mutation: ItemData)
    // Emitted when adding a default royalty recipient
    pub event DefaultRoyaltyAdded(name: String, rate: UFix64)
    // Emitted when removing a default royalty recipient
    pub event DefaultRoyaltyRemoved(name: String)
    // Emitted when an existing Royalty rate is changed
    pub event DefaultRoyaltyRateChanged(name: String, previousRate: UFix64, rate: UFix64)
    // Emitted when adding a royalty for a specific NFT
    pub event RoyaltyForPFPAdded(tokenID: UInt64, name: String, rate: UFix64)
    // Emitted when an existing Royalty rate is changed
    pub event RoyaltyForPFPChanged(tokenID: UInt64, name: String, previousRate: UFix64, rate: UFix64)
    // Emitted when an existing Royalty rate is changed
    pub event RoyaltyForPFPRemoved(tokenID: UInt64, name: String)
    // Emitted when reverting the Royalty rate of a given NFT back to default settings
    pub event RoyaltyForPFPRevertedToDefault(tokenID: UInt64)
    // Emitted when an Item is destroyed
    pub event ItemDestroyed(id: UInt64)


    // Named paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let MutatorStoragePath: StoragePath


    // -----------------------------------------------------------------------
    // MintPFPs contract-level fields.
    // These contain actual values that are stored in the smart contract.
    // -----------------------------------------------------------------------



    // The ID that is used to create Admins. 
    // Every Admins should have a unique identifier.
    pub var nextAdminID: UInt32

    // The ID that is used to create Mutators. 
    // Every Mutators should have a unique identifier.
    pub var nextMutatorID: UInt32

    // If ever a mutator goes rouge, we would like to be able to have the option of
    // locking the mutator's ability to mutate NFTs. Additionally, we would like
    // to be able to unlock them too.
    pub var lockedMutators: {UInt32: Bool}

    // The merchant ID (see MintPFPs)
    pub var merchantID: UInt32


    // The total number of MintPFPs NFTs that have been created
    // Because NFTs can be destroyed, it doesn't necessarily mean that this
    // reflects the total number of NFTs in existence, just the number that
    // have been minted to date. Also used as global nft IDs for minting.
    pub var totalSupply: UInt64


    // Mutations are upgrades or modifications of the NFTs' metadata.
    // These will be store at the contract level, allowing dapps administrators to 
    // mutate NFTs even after they have been transferred to other wallets.
    // It also ensures that the original metadata of the NFT will never be deleted
    // offering some protection to the holder.
    pub var mutations: {UInt64: ItemData}



    // the default royalties will be applied to all PFPs unless a specific royalty 
    // is set for a given PFP
    pub var defaultRoyalties: {String: MetadataViews.Royalty}

    // If a specific NFT requires their own royalties, 
    // the default royalties can be overwritten in this dictionary.
    pub var royaltiesForSpecificPFP: {UInt64: {String: MetadataViews.Royalty}}

    pub var ExternalURL: MetadataViews.ExternalURL

    pub var Socials: {String: MetadataViews.ExternalURL}

    pub var Description: String

    pub var SquareImage: MetadataViews.Media

    pub var BannerImage: MetadataViews.Media





    // -----------------------------------------------------------------------
    // MintPFPs contract-level Composite Type definitions
    // -----------------------------------------------------------------------
    // These are just *definitions* for Types that this contract
    // and other accounts can use. These definitions do not contain
    // actual stored values, but an instance (or object) of one of these Types
    // can be created by this contract that contains stored values.
    // -----------------------------------------------------------------------
   
    // The struct representing an NFT Item data
    pub struct ItemData {


        // The ID of the merchant 
        pub let merchantID: UInt32

        // the name
        pub let name: String

        // the description
        pub let description: String

        // The thumbnail
        pub let thumbnail: String

        // the thumbnail cid (if thumbnailHosting is IPFS )
        pub let thumbnailCID: String

        // the thumbnail path (if thumbnailHosting is IPFS )
        pub let thumbnailPathIPFS: String?

        // The mimetype of the thumbnail
        pub let thumbnailMimeType: String

        // The method of hosting the thumbnail (IPFS | HTTPFile)
        pub let thumbnailHosting: String

        // the media file
        pub let mediaURL: String

        // the media cid (if mediaHosting is IPFS )
        pub let mediaCID: String

        // the media path (if mediaHosting is IPFS )
        pub let mediaPathIPFS: String?

        // the mimetype
        pub let mimetype: String

        // the method of hosting the media file (IPFS | HTTPFile)
        pub let mediaHosting: String

        // the attributes
        pub let attributes: {String: String}

        // rarity
        pub let rarity: String
        



        init(name: String, description: String, thumbnail: String, thumbnailCID: String, thumbnailPathIPFS: String?, thumbnailMimeType: String, thumbnailHosting: String, mediaURL: String, mediaCID: String, mediaPathIPFS: String?, mimetype: String, mediaHosting: String, attributes: {String: String}, rarity: String) {
            self.merchantID = YBees.merchantID
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.thumbnailMimeType = thumbnailMimeType
            self.thumbnailCID = thumbnailCID
            self.thumbnailPathIPFS = thumbnailPathIPFS
            self.thumbnailHosting = thumbnailHosting
            self.mediaURL = mediaURL
            self.mediaCID = mediaCID
            self.mediaPathIPFS = mediaPathIPFS
            self.mediaHosting = mediaHosting
            self.mimetype = mimetype
            self.attributes = attributes
            self.rarity = rarity
        }

    }

    // The resource that represents the Item NFTs
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        // Global unique item ID
        pub let id: UInt64

        // Struct of MintPFPs metadata
        pub let data: ItemData


        init(name: String, description: String, thumbnail: String, thumbnailCID: String, thumbnailPathIPFS: String?, thumbnailMimeType: String, thumbnailHosting: String, mediaURL: String, mediaCID: String, mediaPathIPFS: String?, mimetype: String, mediaHosting: String, attributes: {String: String}, rarity: String) {
            
            pre{

            }
            // Increment the global Item IDs
            YBees.totalSupply = YBees.totalSupply + (1 as UInt64)

            self.id = YBees.totalSupply

             // Set the metadata struct
            self.data = ItemData(name: name, description: description, thumbnail: thumbnail, thumbnailCID: thumbnailCID, thumbnailPathIPFS: thumbnailPathIPFS, thumbnailMimeType: thumbnailMimeType, thumbnailHosting: thumbnailHosting, mediaURL: mediaURL, mediaCID: mediaCID, mediaPathIPFS: mediaPathIPFS, mimetype: mimetype, mediaHosting: mediaHosting, attributes: attributes, rarity: rarity)

            emit ItemMinted(itemID: self.id, merchantID:  YBees.merchantID, name: name)
            
        }

        pub fun getSerialNumber(): UInt64 {
            return self.id;
        }

        pub fun getOriginalData(): ItemData {
            return self.data;
        }

        pub fun getMutation(): ItemData? {

            return YBees.mutations[self.id];
        }

        pub fun getData(): ItemData {
            return self.getMutation() ?? self.getOriginalData(); 
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
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
                    let data = self.getData();

                    var thumbnail: AnyStruct{MetadataViews.File} =  MetadataViews.HTTPFile(
                            url: data.thumbnail
                        )
                    if data.thumbnailHosting == "IPFS" {
                        thumbnail =  MetadataViews.IPFSFile(
                            cid: data.thumbnailCID, 
                            path: data.thumbnailPathIPFS
                        )
                    }
                    return MetadataViews.Display(
                        name: data.name,
                        description: data.description,
                        thumbnail: thumbnail
                    )

                case Type<MetadataViews.Editions>():
                    let editionInfo = MetadataViews.Edition(name: self.data.name, number: UInt64(1), max:1)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )

                case Type<MetadataViews.Royalties>():
                    let royaltiesDictionary = YBees.royaltiesForSpecificPFP[self.id] ?? YBees.defaultRoyalties 
                    var royalties: [MetadataViews.Royalty] = []
                    for royaltyName in royaltiesDictionary.keys {
                        royalties.append(royaltiesDictionary[royaltyName]!)
                    }
                  return MetadataViews.Royalties(royalties)

                case Type<MetadataViews.ExternalURL>():
                    return YBees.ExternalURL
                
                case Type<MetadataViews.NFTCollectionData>():
                    return  MetadataViews.NFTCollectionData(
                        storagePath: YBees.CollectionStoragePath,
                        publicPath: YBees.CollectionPublicPath,
                        providerPath: /private/YBeesCollection,
                        publicCollection: Type<&YBees.Collection{YBees.YBeesCollectionPublic}>(),
                        publicLinkedType: Type<&YBees.Collection{YBeesCollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&YBees.Collection{YBeesCollectionPublic,NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-YBees.createEmptyCollection()
                        })
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let data = self.getData();
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: data.thumbnail
                        ),
                        mediaType: data.thumbnailMimeType
                    )

                    return MetadataViews.NFTCollectionDisplay(
                        name: "YBees",
                        description: YBees.Description,
                        externalURL: YBees.ExternalURL,
                        squareImage: YBees.SquareImage,
                        bannerImage: YBees.BannerImage,
                        socials: YBees.Socials
                    )

                case Type<MetadataViews.Traits>():
                    // exclude mintedTime and foo to show other uses of Traits
                    let excludedTraits = ["name", "description", "thumbnail", "externalUrl"]
                    let data = self.getData();
                    let dict = data.attributes;
                    let traitsView = MetadataViews.dictToTraits(dict: dict, excludedNames: excludedTraits)
                    
                    return traitsView

            }
            return nil
        }


        // If the Item is destroyed, emit an event to indicate 
        // to outside ovbservers that it has been destroyed
        destroy() {
            emit ItemDestroyed(id: self.id)
        }

    }

    // Mutator is an authorization resource that allows for the mutations of NFTs 
    pub resource Mutator {

        pub let id: UInt32
       
        init(id: UInt32) {
            self.id = id
        }

        // Mutator role should only be able to mutate a NFT
        pub fun mutatePFP(tokenID: UInt64, name: String, description: String, thumbnail: String, thumbnailCID: String, thumbnailPathIPFS: String?, thumbnailMimeType: String, thumbnailHosting: String, mediaURL: String, mediaCID: String, mediaPathIPFS: String?, mimetype: String, mediaHosting: String, attributes: {String: String}, rarity: String){

           pre{
                tokenID <= YBees.totalSupply: "the tokenID does not exist"
           }
                if (YBees.lockedMutators[self.id] != true) {
                    let mutation = ItemData(name: name, description: description, thumbnail: thumbnail, thumbnailCID: thumbnailCID, thumbnailPathIPFS: thumbnailPathIPFS, thumbnailMimeType: thumbnailMimeType, thumbnailHosting: thumbnailHosting, mediaURL: mediaURL, mediaCID: mediaCID, mediaPathIPFS: mediaPathIPFS, mimetype: mimetype, mediaHosting: mediaHosting, attributes: attributes, rarity: rarity)

                    YBees.mutations[tokenID] = mutation
                    emit ItemMutated(id: tokenID, mutation: mutation)
                }
                else {
                    log("Cannot let mutator mutate")
                }
        }
    }

    // Admin is a special authorization resource that 
    // allows the owner to perform important functions to modify the 
    // various aspects of the Editions and Items
    //
    pub resource Admin {

        pub let id: UInt32
       

        init(id: UInt32) {
            self.id = id
        }

        pub fun setExternalURL(url: String) {
            YBees.ExternalURL = MetadataViews.ExternalURL(url);
        }

        pub fun addSocial(key: String, url: String): {String: MetadataViews.ExternalURL} {
            YBees.Socials.insert(key: key, MetadataViews.ExternalURL(url));
            return YBees.getSocials();
        }

        pub fun removeSocial(key: String): {String: MetadataViews.ExternalURL} {
            YBees.Socials.remove(key: key);
            return YBees.getSocials();
        }

        pub fun setDescription(description: String) {
            YBees.Description = description;
        }

        pub fun setSquareImage(url: String, mediaType: String) {
            YBees.SquareImage = MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: url
                ),
                mediaType: mediaType
            );
        }

        pub fun setBannerImage(url: String, mediaType: String) {
            YBees.BannerImage = MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: url
                ),
                mediaType: mediaType
            );
        }

        // createNewAdmin creates a new Admin resource
        //
        pub fun createNewAdmin(): @Admin {
            

            let newID = YBees.nextAdminID
             // Increment the ID so that it isn't used again
            YBees.nextAdminID = YBees.nextAdminID + (1 as UInt32)

            return <-create Admin(id: newID)
        }

        // createNewMutator creates a new Mutator resource
        pub fun createNewMutator(): @Mutator {
            

            let newID = YBees.nextMutatorID
             // Increment the ID so that it isn't used again
            YBees.nextMutatorID = YBees.nextMutatorID + (1 as UInt32)

            return <-create Mutator(id: newID)
        }

        // Locks a mutator
        pub fun lockMutator(id: UInt32): Int{
            YBees.lockedMutators.insert(key: id, true);
            return YBees.lockedMutators.length;
        }

        // Unlocks a mutator
        pub fun unlockMutator(id: UInt32): Int{
            YBees.lockedMutators.remove(key: id);
            return YBees.lockedMutators.length;
        }

        pub fun setMerchantID(merchantID: UInt32): UInt32{
            YBees.merchantID=merchantID;
            return YBees.merchantID;
        }


        pub fun mintPFP(name: String, description: String, thumbnail: String, thumbnailCID: String, thumbnailPathIPFS: String?, thumbnailMimeType: String, thumbnailHosting: String, mediaURL: String, mediaCID: String, mediaPathIPFS: String?, mimetype: String, mediaHosting: String, attributes: {String: String}, rarity: String): @NFT {

             // Mint the new item
            let newItem: @NFT <- create NFT(name: name, description: description, thumbnail: thumbnail, thumbnailCID: thumbnailCID, thumbnailPathIPFS: thumbnailPathIPFS, thumbnailMimeType: thumbnailMimeType, thumbnailHosting: thumbnailHosting, mediaURL: mediaURL, mediaCID: mediaCID, mediaPathIPFS: mediaPathIPFS, mimetype: mimetype, mediaHosting: mediaHosting, attributes: attributes, rarity: rarity)


            return <-newItem

        }

        pub fun mutatePFP(tokenID: UInt64, name: String, description: String, thumbnail: String, thumbnailCID: String, thumbnailPathIPFS: String?, thumbnailMimeType: String, thumbnailHosting: String, mediaURL: String, mediaCID: String, mediaPathIPFS: String?,mimetype: String, mediaHosting: String, attributes: {String: String}, rarity: String){

           pre{
                tokenID <= YBees.totalSupply: "the tokenID does not exist"
           }
                let mutation = ItemData(name: name, description: description, thumbnail: thumbnail, thumbnailCID: thumbnailCID, thumbnailPathIPFS: thumbnailPathIPFS, thumbnailMimeType: thumbnailMimeType, thumbnailHosting: thumbnailHosting, mediaURL: mediaURL, mediaCID: mediaCID, mediaPathIPFS: mediaPathIPFS, mimetype: mimetype, mediaHosting:mediaHosting, attributes: attributes, rarity: rarity)

                YBees.mutations[tokenID] = mutation
                emit ItemMutated(id: tokenID, mutation: mutation)
        }


        // addDefaultRoyalty adds a new default recipient for the cut of the sale
        //
        // Parameters: name: the key to store the new royalty
        //             recipientAddress: the wallet address of the recipient of the cut of the sale
        //             rate: the percentage of the sale that goes to that recipient
        //
        pub fun addDefaultRoyalty(name: String, royalty: MetadataViews.Royalty, rate: UFix64){

            pre {
                YBees.defaultRoyalties[name] == nil: "The royalty with that name already exists"
                rate > 0.0: "Cannot set rate to less than 0%"
                rate <= 1.0: "Cannot set rate to more than 100%"
            }
            YBees.defaultRoyalties[name] = royalty

            // emit DefaultRoyaltyAdded(name: name, rate: rate)

            

        }


        // changeDefaultRoyaltyRate updates a recipient's part of the cut of the sale
        //
        // Parameters: name: the key of the recipient to update
        //             rate: the new percentage of the sale that goes to that recipient
        //
        pub fun changeDefaultRoyaltyRate(name: String, rate: UFix64) {
            pre {
                YBees.defaultRoyalties[name] != nil: "The royalty with that name does not exist"
                rate > 0.0: "Cannot set rate to less than 0%"
                rate <= 1.0: "Cannot set rate to more than 100%"
            }
            let royalty = YBees.defaultRoyalties[name]!
            let previousRate = royalty.cut
            let previousRecipientAddress  = royalty.receiver
            YBees.defaultRoyalties[name] = MetadataViews.Royalty(recipientAddress: previousRecipientAddress, cut: UFix64(rate), description: "YBees Royalties")
            emit DefaultRoyaltyRateChanged(name: name, previousRate: previousRate, rate: rate)
        }

        // removeDefaultRoyalty removes a default recipient from the cut of the sale
        //
        // Parameters: name: the key to store the royalty to remove
        pub fun removeDefaultRoyalty(name: String) {
            pre {
                YBees.defaultRoyalties[name] != nil: "The royalty with that name does not exist"
            }
            YBees.defaultRoyalties.remove(key: name)
            emit DefaultRoyaltyRemoved(name: name)
        }



        // addRoyaltyForPFP adds a new recipient for the cut of the sale on a specific PFP
        //
        // Parameters: tokenID: the unique ID of the PFP
        //             name: the key to store the new royalty
        //             recipientAddress: the wallet address of the recipient of the cut of the sale
        //             rate: the percentage of the sale that goes to that recipient
        //
        pub fun addRoyaltyForPFP(tokenID: UInt64, name: String, royalty: MetadataViews.Royalty, rate: UFix64){

            pre {
                rate > 0.0: "Cannot set rate to less than 0%"
                rate <= 1.0: "Cannot set rate to more than 100%"
            }

            if  YBees.royaltiesForSpecificPFP.containsKey(tokenID) == false{

                let newEntry: {String: MetadataViews.Royalty}= {}
                newEntry.insert(key: name, royalty)
                YBees.royaltiesForSpecificPFP!.insert(key: tokenID, newEntry)
                emit RoyaltyForPFPAdded(tokenID: tokenID, name: name, rate: rate)
                return
            }

            // the TokenID already has an entry

             if  YBees.royaltiesForSpecificPFP[tokenID]!.containsKey(name) {
                 // the entry already exists
                 panic("The royalty with that name already exists")

             }
            YBees.royaltiesForSpecificPFP[tokenID]!.insert(key: name, royalty)

            emit RoyaltyForPFPAdded(tokenID: tokenID, name: name, rate: rate)

            

        }


        // changeRoyaltyRateForPFP changes the royalty rate for the sale on a specific PFP
        //
        // Parameters: tokenID: the unique ID of the PFP
        //             name: the key to store the new royalty
        //             rate: the percentage of the sale that goes to that recipient
        //
        pub fun changeRoyaltyRateForPFP(tokenID: UInt64, name: String, rate: UFix64){

            pre {
                rate > 0.0: "Cannot set rate to less than 0%"
                rate <= 1.0: "Cannot set rate to more than 100%"
            }

            let previousRoyalty: MetadataViews.Royalty = YBees.royaltiesForSpecificPFP[tokenID]![name]!

            let newRoyalty = MetadataViews.Royalty(recipientAddress: previousRoyalty.receiver, cut: UFix64(rate), description: "YBees Royalties")
            YBees.royaltiesForSpecificPFP[tokenID]!.insert(key: name,  newRoyalty);

            emit RoyaltyForPFPChanged(tokenID: tokenID, name: name, previousRate: previousRoyalty.cut, rate: rate)

        }

        // removeRoyaltyForPFP changes the royalty rate for the sale on a specific PFP
        //
        // Parameters: tokenID: the unique ID of the PFP
        //             name: the key to store the royalty to remove
        //
        pub fun removeRoyaltyForPFP(tokenID: UInt64, name: String){

            YBees.royaltiesForSpecificPFP[tokenID]!.remove(key: name);
            emit RoyaltyForPFPRemoved(tokenID: tokenID, name: name)

        }


        // revertRoyaltyForPFPToDefault removes the royalty setttings for the specific PFP
        // so it uses the default roylaties going forward
        //
        // Parameters: tokenID: the unique ID of the PFP
        //
        pub fun revertRoyaltyForPFPToDefault(tokenID: UInt64){

            YBees.royaltiesForSpecificPFP.remove(key: tokenID);
            emit RoyaltyForPFPRevertedToDefault(tokenID: tokenID)

        }


    }



    // This is the interface that users can cast their MintPFPs Collection as
    // to allow others to deposit MintPFPs into their Collection. It also allows for reading
    // the IDs of MintPFPs in the Collection.
    pub resource interface YBeesCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowYBees(id: UInt64): &YBees.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow PFP reference: The ID of the returned reference is incorrect"
            }
        }
        
    }



    // Collection is a resource that every user who owns NFTs 
    // will store in their account to manage their NFTS
    //
    pub resource Collection: YBeesCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection { 
        // Dictionary of MintPFPs conforming tokens
        // NFT is a resource type with a UInt64 ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }




        // withdraw removes a MintPFPs from the Collection and moves it to the caller
        //
        // Parameters: withdrawID: The ID of the NFT 
        // that is to be removed from the Collection
        //
        // returns: @NonFungibleToken.NFT the token that was withdrawn
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {

            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot withdraw: PFP does not exist in the collection")

            emit Withdraw(id: token.id, from: self.owner?.address)
            
            // Return the withdrawn token
            return <-token
        }

        // batchWithdraw withdraws multiple tokens and returns them as a Collection
        //
        // Parameters: ids: An array of IDs to withdraw
        //
        // Returns: @NonFungibleToken.Collection: A collection that contains
        //                                        the withdrawn MintPFPs items
        //
        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            // Create a new empty Collection
            var batchCollection <- create Collection()
            
            // Iterate through the ids and withdraw them from the Collection
            for id in ids {

                let token <-self.withdraw(withdrawID: id)

                batchCollection.deposit(token: <-token)
            }
            
            // Return the withdrawn tokens
            return <-batchCollection
        }

        // deposit takes a MintPFPs and adds it to the Collections dictionary
        //
        // Paramters: token: the NFT to be deposited in the collection
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            
            // Cast the deposited token as a MintPFPs NFT to make sure
            // it is the correct type
            let token <- token as! @YBees.NFT

            // Get the token's ID
            let id = token.id

            // Add the new token to the dictionary
            let oldToken <- self.ownedNFTs[id] <- token

            // Only emit a deposit event if the Collection 
            // is in an account's storage
            if self.owner?.address != nil {
                emit Deposit(id: id, to: self.owner?.address)
            }

            // Destroy the empty old token that was "removed"
            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this Collection
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {

            // Get an array of the IDs to be deposited
            let keys = tokens.getIDs()

            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the empty Collection
            destroy tokens
        }

        // getIDs returns an array of the IDs that are in the Collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT Returns a borrowed reference to a MintPFPs in the Collection
        // so that the caller can read its ID
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        //
        // Note: This only allows the caller to read the ID of the NFT,
        // not any MintPFPs specific data. Please use borrowYBeess to 
        // read MintPFPs data.
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowYBees returns a borrowed reference to a MintPFPs
        // so that the caller can read data and call methods from it.
        // They can use this to read its editionID, editionNumber,
        // or any edition data associated with it by
        // getting the editionID and reading those fields from
        // the smart contract.
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        pub fun borrowYBees(id: UInt64): &YBees.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &YBees.NFT
            } else {
                return nil
            }
        }

        // Making the collection conform to MetadataViews.Resolver
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let YBeesNFT = nft as! &YBees.NFT
            return YBeesNFT as &AnyResource{MetadataViews.Resolver}
        }

        // If a transaction destroys the Collection object,
        // All the NFTs contained within are also destroyed
        //
        destroy() {
            destroy self.ownedNFTs
        }
    }



    // -----------------------------------------------------------------------
    // MintPFPs contract-level function definitions
    // -----------------------------------------------------------------------

    // createEmptyCollection creates a new, empty Collection object so that
    // a user can store it in their account storage.
    // Once they have a Collection in their storage, they are able to receive
    // MintPFPs in transactions.
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <-create YBees.Collection()
    }

    pub fun createEmptyMintPFPsCollection(): @YBees.Collection {
        return <-create YBees.Collection()
    }

    pub fun getExternalURL(): MetadataViews.ExternalURL {
        return YBees.ExternalURL;
    }

    pub fun getSocials(): {String: MetadataViews.ExternalURL} {
        return YBees.Socials;
    }

    pub fun getDescription(): String {
        return YBees.Description
    }

    pub fun getSquareImage(): MetadataViews.Media {
        return YBees.SquareImage;
    }

    pub fun getBannerImage(): MetadataViews.Media {
        return YBees.BannerImage;
    }

    // Returns all of the locked mutator IDs
    pub fun getLockedMutators() : {UInt32: Bool} {
        return YBees.lockedMutators;
    }

    // getMerchantID returns the merchant ID
    pub fun getMerchantID(): UInt32 {
        return self.merchantID
    }


    // getDefaultRoyalties returns the default royalties
    pub fun getDefaultRoyalties(): {String: MetadataViews.Royalty} {
        return self.defaultRoyalties
    }

    // getDefaultRoyalties returns the default royalties
    pub fun getDefaultRoyaltyNames(): [String] {
        return self.defaultRoyalties.keys
    }

    // getDefaultRoyaltyRate returns a royalty object
    pub fun getDefaultRoyalty(name: String): MetadataViews.Royalty? {
            return self.defaultRoyalties[name]
    }

    // returns the default
    pub fun getTotalDefaultRoyaltyRate(): UFix64 {
            var totalRoyalty = 0.0
            for key in self.defaultRoyalties.keys {
                let royal = self.defaultRoyalties[key] ?? panic("Royalty does not exist")
                totalRoyalty = totalRoyalty + royal.cut
            }
            return totalRoyalty
    }


    // getRoyaltiesForPFP returns the specific royalties for a PFP or the default royalties
    pub fun getRoyaltiesForPFP(tokenID: UInt64): {String: MetadataViews.Royalty} {
        return self.royaltiesForSpecificPFP[tokenID] ?? self.getDefaultRoyalties()
    }

    //  getRoyaltyNamesForPFP returns the  royalty names for a specific PFP or the default royalty names
    pub fun getRoyaltyNamesForPFP(tokenID: UInt64): [String] {
        return self.royaltiesForSpecificPFP[tokenID]?.keys ?? self.getDefaultRoyaltyNames()
    }

    // getRoyaltyNamesForPFP returns a given royalty for a specific PFP or the default royalty names
    pub fun getRoyaltyForPFP(tokenID: UInt64, name: String): MetadataViews.Royalty? {

        if  self.royaltiesForSpecificPFP.containsKey(tokenID){
          let royaltiesForPFP:  {String: MetadataViews.Royalty} = self.royaltiesForSpecificPFP[tokenID]!
          return royaltiesForPFP[name]!
        }

        // if no specific royalty is set
        return self.getDefaultRoyalty(name: name)
    }

    // getTotalRoyaltyRateForPFP returns the total royalty rate for a give PFP
    pub fun getTotalRoyaltyRateForPFP(tokenID: UInt64): UFix64 {

       var totalRoyalty = 0.0
       let royalties = self.getRoyaltiesForPFP(tokenID: tokenID)
        for key in royalties.keys {
            let royal = royalties[key] ?? panic("Royalty does not exist")
            totalRoyalty = totalRoyalty + royal.cut
        }
        return totalRoyalty
    }

    





    // -----------------------------------------------------------------------
    // MintPFPs initialization function
    // -----------------------------------------------------------------------
    //
    init() {
        // Initialize contract fields
        
        self.totalSupply = 0
        self.merchantID = 36
        self.mutations = {}
        self.defaultRoyalties = {}
        self.royaltiesForSpecificPFP = {}
        self.lockedMutators = {}
        self.ExternalURL = MetadataViews.ExternalURL("https://google.ca")
        self.Socials = {"test": MetadataViews.ExternalURL("https://google.ca")}
        self.Description = "Templated Contract!"
        self.SquareImage = MetadataViews.Media(
            file: MetadataViews.HTTPFile(
                url: "https://mint-store-metadata.s3.us-east-2.amazonaws.com/BSC-Young-Boys/BSC_Young_Boys_logo.png"
            ),
            mediaType: "image/png"
        )

        self.BannerImage = MetadataViews.Media(
            file: MetadataViews.HTTPFile(
                url: "https://mint-store-metadata.s3.us-east-2.amazonaws.com/BSC-Young-Boys/BSC_Young_Boys_logo.png"
            ),
            mediaType: "image/png"
        )

        self.CollectionStoragePath = /storage/YBeesCollection
        self.CollectionPublicPath = /public/YBeesCollection
        self.AdminStoragePath = /storage/YBeesAdmin
        self.MutatorStoragePath = /storage/YBeesMutator

        // Put a new Collection in storage
        self.account.save<@Collection>(<- create Collection(), to: self.CollectionStoragePath)

        // Create a public capability for the Collection
        self.account.link<&{YBeesCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        // Put the admin ressource in storage
        self.account.save<@Admin>(<- create Admin(id: 1), to: self.AdminStoragePath)
        self.nextAdminID = 2

        // Put the admin ressource in storage
        self.account.save<@Mutator>(<- create Mutator(id: 1), to: self.MutatorStoragePath)
        self.nextMutatorID = 2

        emit ContractInitialized()
    }


}
    
 