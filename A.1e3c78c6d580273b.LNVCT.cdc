// Description: Smart Contract for Live Nation Virtual Commemorative Tickets
// SPDX-License-Identifier: UNLICENSED

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448


pub contract LNVCT : NonFungibleToken{
    
    pub var totalSupply: UInt64
    pub var maxEditionNumbersForShows: {String: UInt64}
    pub var name: String
    
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    
    
    pub struct Rarity{
        pub let rarity: UFix64?
        pub let rarityName: String
        pub let parts: {String: RarityPart}

        init(rarity: UFix64?, rarityName: String, parts:{String:RarityPart}) {
            self.rarity=rarity
            self.rarityName=rarityName
            self.parts=parts
        }
    }

    pub struct RarityPart{

        pub let rarity: UFix64?
        pub let rarityName: String
        pub let name: String

        init(rarity: UFix64?, rarityName: String, name:String) {

            self.rarity=rarity
            self.rarityName=rarityName
            self.name=name
        }

    }
    
    pub resource interface NFTModifier {
        access(account) fun markAttendanceHelper(attendance: String)
        access(account) fun setURLMetadataHelper(newURL:String,newThumbnail:String)
        access(account) fun setRarityHelper(rarity:UFix64, rarityName:String, rarityValue:String)
        access(account) fun setEditionHelper(editionNumber:UInt64, maxEdition:UInt64)
        access(account) fun setMaxEditionForShowHelper(description:String, maxEdition:UInt64)
        access(account) fun setMetadataHelper(metadata_name: String, metadata_value: String)
    
    }
    
    pub resource NFT : NonFungibleToken.INFT, MetadataViews.Resolver,NFTModifier{
        
        pub let id: UInt64
        pub var link: String
        pub var batch: UInt32
        pub var sequence: UInt16
        pub var limit: UInt16
        pub var attendance: String
        pub var name: String
        pub var description: String
        pub var thumbnail: String

        pub var rarity: UFix64?
		pub var rarityName: String
        pub var rarityValue: String
		pub var parts: {String: RarityPart}

        pub var editionNumber: UInt64
        pub var maxEdition: UInt64?
        
        
        pub var metadata: {String: String}

        access(account) fun markAttendanceHelper(attendance: String) {
            self.attendance = attendance
            log("Attendance is set to: ")
            log(self.attendance)
            
        }

        access(account) fun setURLMetadataHelper(newURL:String,newThumbnail:String){
            self.link = newURL
            self.thumbnail = newThumbnail
            log("URL metadata is set to: ")
            log(self.link)
            log(self.thumbnail)
        
        }
        
        access(account) fun setRarityHelper(rarity:UFix64, rarityName:String, rarityValue:String)  {
            
            self.rarity = rarity
            self.rarityName = rarityName
            self.rarityValue = rarityValue
            
            self.parts = {rarityName:RarityPart(rarity: rarity, rarityName: rarityName, name:rarityValue)}
            
            log("Rarity metadata is updated")
        }


        access(account) fun setEditionHelper(editionNumber:UInt64, maxEdition:UInt64)  {
            
            self.editionNumber = editionNumber
            self.maxEdition = maxEdition
            
            log("Edition metadata is updated")
        }

        access(account) fun setMaxEditionForShowHelper(description:String, maxEdition:UInt64)  {
            
            LNVCT.maxEditionNumbersForShows.insert(key: description,maxEdition) 
            log("Max Edition metadata for the Show is updated")
        }
        
        access(account) fun setMetadataHelper(metadata_name: String, metadata_value: String)  {
            
            self.metadata.insert(key: metadata_name, metadata_value)
            log("Custom Metadata store is updated")
        }

        
        
        init(initID: UInt64, initlink: String, initbatch: UInt32, initsequence: UInt16, initlimit: UInt16,name:String,description:String,thumbnail:String,editionNumber:UInt64, metadata:{String:String}) {

            self.id = initID
            self.link = initlink
            self.batch = initbatch
            self.sequence=initsequence
            self.limit=initlimit

            self.attendance = "null"

            self.name = name 
            self.description = description
            self.thumbnail = thumbnail
            
            self.rarity = nil
            self.rarityName = "Tier"
            self.rarityValue= "null"
            self.parts = {self.rarityName:RarityPart(rarity: self.rarity, rarityName: self.rarityName, name:self.rarityValue)}
            self.editionNumber =editionNumber
        

            let containsShowName= LNVCT.maxEditionNumbersForShows.containsKey(description)
            if containsShowName{            
                let currentMaxEditionValue = LNVCT.maxEditionNumbersForShows[description] ?? nil
                self.maxEdition = currentMaxEditionValue
            } 
            else{
            self.maxEdition = nil
            }            
            
            self.metadata = metadata
    
        }
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<Rarity>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<Rarity>():
                    return Rarity(
                        rarity : self.rarity,
                        rarityName: self.rarityName,
                        parts : self.parts

                    )
            }

            return nil
        }
    }

    pub resource interface LNVCTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT        
        pub fun borrowLNVCT(id: UInt64): &LNVCT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow LNVCT reference: The ID of the returned reference is incorrect"
            }
        }
    }


    pub resource Collection: LNVCTCollectionPublic,NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID)!
            
            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @LNVCT.NFT    
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
            
        }


        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        destroy() {
            destroy self.ownedNFTs
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let exampleNFT = nft as! &LNVCT.NFT
            return exampleNFT as &AnyResource{MetadataViews.Resolver}
        }

        pub fun borrowLNVCT(id: UInt64): &LNVCT.NFT? {
            if self.ownedNFTs[id] == nil {
                return nil
            }
            else {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &LNVCT.NFT
            }
        }

    }

    pub fun createEmptyCollection(): @LNVCT.Collection {
        return <- create Collection()
    }

    pub resource NFTMinter {
        pub var minterID: UInt64
        
        init() {
            self.minterID = 0    
        }

        pub fun mintNFT(glink: String, gbatch: UInt32, glimit: UInt16, gsequence:UInt16,name:String,description:String,thumbnail:String,editionNumber:UInt64,metadata:{String: String}): @NFT {

            let tokenID = (UInt64(gbatch) << 32) | (UInt64(glimit) << 16) | UInt64(gsequence)
            var newNFT <- create NFT(initID: tokenID, initlink: glink, initbatch: gbatch, initsequence: gsequence, initlimit: glimit,name:name, description: description,thumbnail:thumbnail,editionNumber:editionNumber,metadata:metadata)
            self.minterID= tokenID
            LNVCT.totalSupply = LNVCT.totalSupply + 1

            return <-newNFT
        }
    }


    pub resource Modifier {

        pub var ModifierID: UInt64
        
        pub fun markAttendance(currentNFT: &LNVCT.NFT?, attendance:String) : String {
            let ref2 =  currentNFT!

            ref2.markAttendanceHelper(attendance: attendance)
            log("Attendance is set to: ")
            log(ref2.attendance)
            return ref2.attendance
        }

        pub fun setURLMetadata(currentNFT: &LNVCT.NFT?, newURL:String,newThumbnail:String) : String {
            let ref2 =  currentNFT!
            ref2.setURLMetadataHelper(newURL: newURL,newThumbnail:newThumbnail)
            log("URL metadata is set to: ")
            log(newURL)
            return newURL
        }
        
        pub fun setRarity(currentNFT: &LNVCT.NFT?, rarity:UFix64, rarityName:String, rarityValue:String)  {
            
            let ref2 =  currentNFT!
            ref2.setRarityHelper(rarity: rarity, rarityName: rarityName, rarityValue: rarityValue)
            log("Rarity metadata is updated")
        }


        pub fun setEdition(currentNFT: &LNVCT.NFT?, editionNumber:UInt64, maxEdition:UInt64)  {
            
            let ref2 =  currentNFT!
            ref2.setEditionHelper(editionNumber: editionNumber, maxEdition: maxEdition)
            log("Edition metadata is updated")
        }

        pub fun setMaxEditionForShow(description:String, maxEdition:UInt64)  {


            LNVCT.maxEditionNumbersForShows.insert(key: description,maxEdition) 
            log("Max Edition metadata for the Show is updated")
        }
        
        pub fun setMetadata(currentNFT: &LNVCT.NFT?, metadata_name: String, metadata_value: String)  {
            
            let ref2 =  currentNFT!
            ref2.setMetadataHelper(metadata_name: metadata_name, metadata_value: metadata_value)
            log("Custom Metadata store is updated")
        }


        init() {
            self.ModifierID = 0    
        }
        
    }
	init() {


        self.CollectionStoragePath = /storage/LNVCTCollection
        self.CollectionPublicPath = /public/LNVCTCollection
        self.MinterStoragePath = /storage/LNVCTMinter


        self.totalSupply = 0
        self.maxEditionNumbersForShows = {}
        self.name = "Live Nation Virtual Commemorative Tickets"
        
            

		self.account.save(<-self.createEmptyCollection(), to: self.CollectionStoragePath)
        self.account.link<&{LNVCT.LNVCTCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)
        self.account.save(<-create Modifier(), to: /storage/LNVCTModifier)
        emit ContractInitialized()
	}
}
 
 