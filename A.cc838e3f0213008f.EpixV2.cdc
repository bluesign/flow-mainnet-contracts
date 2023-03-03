import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
pub contract EpixV2: NonFungibleToken {

    
    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Burn(id: UInt64)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, metadata: String, claimsSize: Int)
    pub event Claimed(id: UInt64)

    pub struct TraitPerCharacter {
      
      pub var totalSupply: UInt64 
      pub var characterName: String
      pub let traitName:String
      pub let traitValue: String

      init(traitName: String, traitValue: String,characterName: String) {
            self.totalSupply = 1
            self.traitName = traitName
            self.traitValue = traitValue
            self.characterName = characterName
        }

      pub fun incrementTotalSupply(){
         self.totalSupply = self.totalSupply + (1 as UInt64)
      }

      pub fun decrementTotalSupply(){
         self.totalSupply = self.totalSupply - (1 as UInt64)
      }   
    }

    pub struct TraitPerTribe {
      
      pub var totalSupply: UInt64 
      pub var tribeName: String
      pub let traitName:String
      pub let traitValue: String

      init(traitName: String, traitValue: String,tribeName: String) {
            self.totalSupply = 1
            self.traitName = traitName
            self.traitValue = traitValue
            self.tribeName = tribeName
        }

      pub fun incrementTotalSupply(){
         self.totalSupply = self.totalSupply + (1 as UInt64)
      }

      pub fun decrementTotalSupply(){
         self.totalSupply = self.totalSupply - (1 as UInt64)
      }   
    }

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64
    pub var totalSupplyOfCertainCharacterNfts: [{String:UInt64}]

    pub var traitsPerCharacter: [TraitPerCharacter]
    pub var traitsPerTribe: [TraitPerTribe]

    // Named paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // Composite data structure to represents, packs and upgrades functionality
    pub struct NFTData {
        pub let name: String
        pub let description: String
        pub let royalties: [MetadataViews.Royalty]
        pub let linkToViewNFTOn:String
        pub let linkToViewCollectionOn:String
        pub let linkToBannerOfCollection:String
        pub let linkToSquareImageOfCollection:String
        pub let linkToTwitterOfCollection:String
        pub let metadata: String
        // contain info about traits of the nft
        pub let traits: [Trait]?
        //contain info about character, tribe and traits the nft has
        pub let metadataOfTraits: {String:String}
        pub let claims: [NFTData]
        
        init(name:String,description:String,royalties:[MetadataViews.Royalty],linkToViewNFTOn:String,linkToViewCollectionOn:String,linkToBannerOfCollection:String,
        linkToSquareImageOfCollection:String,linkToTwitterOfCollection:String,metadata: String, claims: [NFTData],traits: [Trait]?,metadataOfTraits: {String:String}) {
            self.name = name
            self.description = description
            self.royalties = royalties
            self.linkToViewNFTOn = linkToViewNFTOn
            self.linkToViewCollectionOn = linkToViewCollectionOn
            self.linkToBannerOfCollection=linkToBannerOfCollection
            self.linkToSquareImageOfCollection=linkToSquareImageOfCollection
            self.linkToTwitterOfCollection=linkToTwitterOfCollection
            self.metadata = metadata
            self.claims = claims
            self.traits = traits
            self.metadataOfTraits = metadataOfTraits
        }
    }

    pub struct Rarity {    
     pub let max: UFix64
     pub let description: String 
     init(max: UFix64,description:String ) {
            self.max = max
            self.description=description
        }
   }

   pub struct Trait {
     pub let name: String
     pub let value: String
     pub let displayType: String?
     pub let rarity: Rarity
     init(name: String, value: String,displayType: String?,rarity: Rarity) {
            self.name = name
            self.value = value
            self.displayType=displayType
            self.rarity=rarity
        }
   }

    // NFT
    // A Epix NFT
    //
    pub resource NFT: NonFungibleToken.INFT,MetadataViews.Resolver{ //MetadataViews.Resolver {
        // NFT's ID
        pub let id: UInt64
        // NFT's data
        pub let data: NFTData
      
        // initializer
        //
        init(initID: UInt64, initData: NFTData) {
            self.id = initID
            self.data = initData
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
                    return MetadataViews.Display(
                        name: self.data.name,
                        description: self.data.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://api.thisisepix.com/api/v1/nfts/thumbnail?metadata_hash=".concat(self.data.metadata)
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "Epix NFT Edition", number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.data.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(self.data.linkToViewNFTOn)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: EpixV2.CollectionStoragePath,
                        publicPath: EpixV2.CollectionPublicPath,
                        providerPath: /private/EpixV2Collection,
                        publicCollection: Type<&EpixV2.Collection{EpixV2.EpixCollectionPublic}>(),
                        publicLinkedType: Type<&EpixV2.Collection{EpixV2.EpixCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&EpixV2.Collection{EpixV2.EpixCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-EpixV2.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: self.data.linkToSquareImageOfCollection
                        ),
                        mediaType: "image/svg+xml"
                    )

                    let media1 = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: self.data.linkToBannerOfCollection
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Epix Collection",
                        description: "",
                        externalURL: MetadataViews.ExternalURL(self.data.linkToViewCollectionOn),
                        squareImage: media,
                        bannerImage: media1,
                        socials: {
                            "twitter": MetadataViews.ExternalURL(self.data.linkToTwitterOfCollection)
                        }
                    )

                    case Type<MetadataViews.Traits>():
                    // exclude mintedTime and foo to show other uses of Traits

                    // exclude mintedTime and foo to show other uses of Traits

                    if(self.data.traits !=nil){

                    let metadataOfTraits:{String:String} = {}

                    for key in self.data.metadataOfTraits.keys{
                         if(key!="characterName"&& key!="tribeName"){
                           metadataOfTraits[key] = self.data.metadataOfTraits[key]
                         }
                    }

                    let excludedTraits: [String] = []

                    for trait in self.data.traits!{
                        excludedTraits.append(trait.name)
                    }
    
                    let traitsView = MetadataViews.dictToTraits(dict: metadataOfTraits, excludedNames: excludedTraits)

                    var totalSupplyOfCertainCharacterNfts: UInt64 = 0

                    for characterCounter in EpixV2.totalSupplyOfCertainCharacterNfts{
                      for key in characterCounter.keys{
                        if key == self.data.metadataOfTraits["characterName"]!{
                           totalSupplyOfCertainCharacterNfts = characterCounter[key]!
                        }
                      }
                    }

                    for trait in self.data.traits! {
                      // mintedTime is a unix timestamp, we should mark it with a displayType so platforms know how to show it.

                      var traitScore: UFix64 = 0.0

                     for trait2 in EpixV2.traitsPerCharacter!{
                         if(trait2.traitName==trait.name&&trait2.traitValue==self.data.metadataOfTraits[trait.name]&&trait2.characterName==self.data.metadataOfTraits["characterName"]){
                             
                             traitScore = UFix64(trait2.totalSupply)/UFix64(totalSupplyOfCertainCharacterNfts)*UFix64(100)
                            
                             //traitScore = UFix64(trait2.totalSupply)
                         }
                      }
                    let traitRarity = MetadataViews.Rarity(score:traitScore, max: trait.rarity.max, description: trait.rarity.description)
                    
                    let trait = MetadataViews.Trait(name: trait.name, value: trait.value, displayType: trait.displayType, rarity: traitRarity)
                    traitsView.addTrait(trait)
                    }
                    
                    return traitsView
                    }
            
            }
            return nil
    }

        destroy() {
            if(self.data.traits!=nil){

               for trait in self.data.traits!{
                   for index,trait2 in EpixV2.traitsPerCharacter{
                       if(trait2.characterName==self.data.metadataOfTraits["characterName"]! && trait2.traitName==trait.name && trait2.traitValue==trait.value){
                          EpixV2.traitsPerCharacter[index].decrementTotalSupply()
                          if(EpixV2.traitsPerCharacter[index].totalSupply==0){
                             EpixV2.traitsPerCharacter.remove(at: index)
                          }
                       }
                   }
                  
                   for index, trait2 in EpixV2.traitsPerTribe{
                       if(trait2.tribeName==self.data.metadataOfTraits["tribeName"]! && trait2.traitName==trait.name && trait2.traitValue==trait.value){
                          EpixV2.traitsPerTribe[index].decrementTotalSupply()
                          if(EpixV2.traitsPerTribe[index].totalSupply==0){
                             EpixV2.traitsPerTribe.remove(at: index)
                          }
                       }
                     
                   }
               }
            }
            
            for index,characterCounter in EpixV2.totalSupplyOfCertainCharacterNfts{
                for key in characterCounter.keys{
                   if key == self.data.metadataOfTraits["characterName"]!{
                      EpixV2.totalSupplyOfCertainCharacterNfts[index][key] = EpixV2.totalSupplyOfCertainCharacterNfts[index][key]! - 1
                   }
                }
            }
               
            emit Burn(id: self.id)
        }
    }

    pub resource interface EpixCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowEpixNFT(id: UInt64): &EpixV2.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result != nil) && (result?.id == id):
                    "Cannot borrow EpixNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of Epix NFTs owned by an account
    //
    pub resource Collection: EpixCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let epixNFT = nft as! &EpixV2.NFT
            return epixNFT as &AnyResource{MetadataViews.Resolver}
        }

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @EpixV2.NFT
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

        // borrowEpixNFT
        // Gets a reference to an NFT in the collection as a EpixCard,
        // exposing all of its fields.
        // This is safe as there are no functions that can be called on the Epix.
        //
        pub fun borrowEpixNFT(id: UInt64): &EpixV2.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &EpixV2.NFT
            } else {
                return nil
            }
        }

        // claim
        // resource owners when claiming, Mint new NFTs and burn the claimID resource.
        pub fun claim(claimID: UInt64) {
            pre {
                self.ownedNFTs[claimID] != nil : "missing claim NFT"
            }

            let claimTokenRef = self.borrowEpixNFT(id:claimID)!
            if claimTokenRef.data.claims.length == 0 {
                panic("Claim NFT has empty claims")
            }

            for claim in claimTokenRef.data.claims {
             
            var isCharacterAdded: Bool = false

            for index,characterCounter in EpixV2.totalSupplyOfCertainCharacterNfts{
                for key in characterCounter.keys{
                   if key == claim.metadataOfTraits["characterName"]!{
                      isCharacterAdded = true
                      EpixV2.totalSupplyOfCertainCharacterNfts[index][key] = EpixV2.totalSupplyOfCertainCharacterNfts[index][key]! + 1
                   }
                }
            }

            if !isCharacterAdded {
               EpixV2.totalSupplyOfCertainCharacterNfts.append({claim.metadataOfTraits["characterName"]!:1})
            }

             if(claim.traits!=nil){

               for trait in claim.traits!{
                   var isCharacterTraitAdded: Bool = false
                   for index,trait2 in EpixV2.traitsPerCharacter{
                       if(trait2.characterName==claim.metadataOfTraits["characterName"]! && trait2.traitName==trait.name && trait2.traitValue==trait.value){
                          EpixV2.traitsPerCharacter[index].incrementTotalSupply()
                          isCharacterTraitAdded = true
                       }
                   }
                   if(!isCharacterTraitAdded){
                     EpixV2.traitsPerCharacter.append(EpixV2.TraitPerCharacter(trait.name,trait.value,claim.metadataOfTraits["characterName"]!))
                  }
                  
                  var isTribeTraitAdded: Bool = false
                
                   for index, trait2 in EpixV2.traitsPerTribe{
                       if(trait2.tribeName==claim.metadataOfTraits["tribeName"]! && trait2.traitName==trait.name && trait2.traitValue==trait.value){
                          EpixV2.traitsPerTribe[index].incrementTotalSupply()
                          isTribeTraitAdded = true
                       }
                     
                   }
                
                   if(!isTribeTraitAdded){
                     EpixV2.traitsPerTribe.append(EpixV2.TraitPerTribe(trait.name,trait.value,claim.metadataOfTraits["tribeName"]!))
                   }

               }

               EpixV2.totalSupply = EpixV2.totalSupply + (1 as UInt64)
                emit Minted(id: EpixV2.totalSupply, metadata: claim.metadata, claimsSize: claim.claims.length)
    
                self.deposit(token: <-create NFT(initID: EpixV2.totalSupply,initData:claim))
               // self.deposit(token: <-create Epix.NFT(initID: Epix.totalSupply, initData: claim))
               }
            }

            let claimToken <- self.ownedNFTs.remove(key: claimID) ?? panic("missing claim NFT")
            destroy claimToken
            emit Claimed(id: claimID)
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

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {
        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, data: NFTData) {
            EpixV2.totalSupply = EpixV2.totalSupply + (1 as UInt64)

            var isCharacterAdded: Bool = false

            for index,characterCounter in EpixV2.totalSupplyOfCertainCharacterNfts{
                for key in characterCounter.keys{
                   if key == data.metadataOfTraits["characterName"]!{
                      isCharacterAdded = true
                      EpixV2.totalSupplyOfCertainCharacterNfts[index][key] = EpixV2.totalSupplyOfCertainCharacterNfts[index][key]! + 1
                   }
                }
            }

            if !isCharacterAdded {
               EpixV2.totalSupplyOfCertainCharacterNfts.append({data.metadataOfTraits["characterName"]!:1})
            }
            
             
             if(data.traits!=nil){

               for trait in data.traits!{
                   var isCharacterTraitAdded: Bool = false
                   for index,trait2 in EpixV2.traitsPerCharacter{
                       if(trait2.characterName==data.metadataOfTraits["characterName"]! && trait2.traitName==trait.name && trait2.traitValue==trait.value){
                          EpixV2.traitsPerCharacter[index].incrementTotalSupply()
                          isCharacterTraitAdded = true
                       }
                   }
                   if(!isCharacterTraitAdded){
                     EpixV2.traitsPerCharacter.append(EpixV2.TraitPerCharacter(trait.name,trait.value,data.metadataOfTraits["characterName"]!))
                  }
                  
                  var isTribeTraitAdded: Bool = false
                
                   for index, trait2 in EpixV2.traitsPerTribe{
                       if(trait2.tribeName==data.metadataOfTraits["tribeName"]! && trait2.traitName==trait.name && trait2.traitValue==trait.value){
                          EpixV2.traitsPerTribe[index].incrementTotalSupply()
                          isTribeTraitAdded = true
                       }
                     
                   }
                
                   if(!isTribeTraitAdded){
                     EpixV2.traitsPerTribe.append(EpixV2.TraitPerTribe(trait.name,trait.value,data.metadataOfTraits["tribeName"]!))
                   }

               }
            }
            emit Minted(id: EpixV2.totalSupply, metadata: data.metadata, claimsSize: data.claims.length)
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-create EpixV2.NFT(initID: EpixV2.totalSupply,initData: data))
        }
    }

    pub fun getTotalSupplyOfCertainCharacter():[{String:UInt64}]{
      return EpixV2.totalSupplyOfCertainCharacterNfts
    }

    // initializer
    //
    init() {
        self.totalSupply = 0
        self.totalSupplyOfCertainCharacterNfts = []
        self.traitsPerCharacter = []
        self.traitsPerTribe = []
        
        self.CollectionStoragePath = /storage/EpixV2Collection
        self.CollectionPublicPath = /public/EpixV2Collection
        self.MinterStoragePath = /storage/EpixV2Minter

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 