import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from  0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract RaptaAccessory: NonFungibleToken {

//STORAGE PATHS
    //Accessory Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    //Template Paths
    pub let TemplateStoragePath: StoragePath
    pub let TemplatePublicPath: PublicPath
//EVENTS
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64, templateId: UInt64)
    pub event Destroyed(id: UInt64)
    pub event TemplateCreated(id: UInt64, name: String, category: String, mintLimit: UInt64)
//VARIABLES
    pub var totalSupply: UInt64
    pub var royalties: [Royalty]
    access(self) let totalMintedAccessories: { UInt64: UInt64 }
    access(account) var royaltyCut: UFix64
    access(account) var marketplaceCut: UFix64
//ENUMERABLES
    pub enum RoyaltyType: UInt8{
        pub case fixed
        pub case percentage
    }
//STRUCTS
    //Royalty Structs
    pub struct Royalties {
        pub let royalty: [Royalty]
        init(
            royalty: [Royalty]
        ) {
            self.royalty = royalty
        }
    }
    pub struct Royalty {
        pub let wallet:Capability<&{FungibleToken.Receiver}> 
        pub let cut: UFix64
        pub let type: RoyaltyType
        init(
            wallet:Capability<&{FungibleToken.Receiver}>, cut: UFix64, type: RoyaltyType
        ){
            self.wallet=wallet
            self.cut=cut
            self.type=type
        }
    }
    //Accessory Struct
    pub struct AccessoryData {
        pub let id: UInt64
        pub let templateId: UInt64
        pub var name: String
        pub var description: String
        pub var category: String
        pub var nextSerialNumber: UInt64

        init(
            id: UInt64,
            templateId: UInt64, 
        ){
            self.id = id
            self.templateId = templateId
            let template = RaptaAccessory.getAccessoryTemplate(id: templateId)!
            self.name = template.name
            self.description= template.description
            self.category= template.category
            self.nextSerialNumber = 1
        }
    }
    //Template Struct
    pub struct TemplateData {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let category: String
        pub let png: String
        pub let layer: String
        pub let mintLimit: UInt64
        pub let totalMintedAccessories: UInt64

        init (
            id: UInt64,
            name: String,
            description: String,
            category: String,
            png: String,
            layer: String,
            mintLimit: UInt64,
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.category = category
            self.png = png
            self.layer = layer
            self.mintLimit = mintLimit
            self.totalMintedAccessories = RaptaAccessory.getTotalMintedAccessoriesByTemplate(id: id)!
        }
    }
//INTERFACES
    //Accessory Interfaces
    pub resource interface Public {
        pub fun getMint(): UInt64
        pub fun getTemplateId(): UInt64
        pub fun getCategory(): String
    }
    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowAccessory(id: UInt64): &RaptaAccessory.NFT? {
            post {
                (result == nil) || (result?.id == id):
                "Cannot borrow accessory reference: The ID of the returned reference is incorrect"
            }
        }
    }
    //Template Interfaces
    pub resource interface TemplatePublic {
        pub let id: UInt64
        pub var name: String
        pub var description: String
        pub var category: String
        pub var mintLimit: UInt64
        pub var png: String
        pub var layer: String
    }
    pub resource interface TemplateCollectionPublic {
        pub fun getIDs(): [UInt64]
        pub fun borrowAccessoryTemplate(id: UInt64): &RaptaAccessory.Template?
    }
//RESOURCES
    //Accessory Resources
    pub resource NFT: NonFungibleToken.INFT, Public, MetadataViews.Resolver {
        pub let id: UInt64
        pub let mint: UInt64
        pub let templateId: UInt64
        pub let name: String
        pub let description: String
        access(contract) let royalties : Royalties


        init( 
            templateId: UInt64,
            royalties: Royalties
        ) {
            self.id = self.uuid
            self.mint = RaptaAccessory.getTotalMintedAccessoriesByTemplate(id: templateId)! + 1
            self.templateId = templateId
            self.name = RaptaAccessory.getAccessoryTemplate(id: templateId)!.name
            self.description = RaptaAccessory.getAccessoryTemplate(id: templateId)!.description
            self.royalties = royalties

            RaptaAccessory.setTotalMintedAccessoriesByTemplate(id: templateId, value: self.mint)
        }

        pub fun getID(): UInt64 {
            return self.id
        }
        pub fun getMint(): UInt64 {
            return self.mint
        }
        pub fun getName(): String {
            return self.name
        }
        pub fun getTemplateId(): UInt64 {
            return self.templateId
        }
        pub fun getTemplate(): RaptaAccessory.TemplateData {
            return RaptaAccessory.getAccessoryTemplate(id: self.templateId)!
        }
        pub fun getPNG(): String {
            return self.getTemplate().png!
        }
        pub fun getLayer(): String {
            return self.getTemplate().layer!
        }
        pub fun getCategory(): String {
            return self.getTemplate().category
        }
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Royalties>()
            ]
        }
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.getTemplate().png!
                        )
                    )

                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://eqmusic.io/rapta/accessories/".concat(self.id.toString()).concat(".png"))

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: RaptaAccessory.CollectionStoragePath,
                        publicPath: RaptaAccessory.CollectionPublicPath,
                        providerPath: /private/RaptaAccessory,
                        publicCollection: Type<&RaptaAccessory.Collection{NonFungibleToken.CollectionPublic, RaptaAccessory.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        publicLinkedType: Type<&RaptaAccessory.Collection{NonFungibleToken.CollectionPublic, RaptaAccessory.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&RaptaAccessory.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, MetadataViews.ResolverCollection, RaptaAccessory.CollectionPublic}>(),
                        createEmptyCollection: (fun (): @NonFungibleToken.Collection {
                            return <-RaptaAccessory.createEmptyCollection()
                        }),
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://eqmusic.io/media/raptaAccessoryCollection.png"
                        ),
                        mediaType: "image/png"
                    )

                    return MetadataViews.NFTCollectionDisplay(
                        name: "Rapta Icon Accessory",
                        description: "custom made gear, with real-life utility, made specially for your rapta icon",
                        externalURL: MetadataViews.ExternalURL("https://eqmusic.io/rapta"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "hoo.be": MetadataViews.ExternalURL("https://hoo.be/rapta"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/_rapta"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/rapta")
                        }
                    )

                case Type<MetadataViews.Royalties>(): 
                    return MetadataViews.Royalties(cutInfos: [])
            
            }
            return nil
        }
    }
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @RaptaAccessory.NFT
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

        pub fun borrowAccessory(id: UInt64): &RaptaAccessory.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &RaptaAccessory.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            pre {
                self.ownedNFTs[id] != nil : "NFT does not exist"
            }
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let accessory = nft as! &RaptaAccessory.NFT
            return accessory as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }
    //Template Resources
    pub resource Template: TemplatePublic {
        pub let id: UInt64
        pub var name: String
        pub var description: String
        pub var category: String
        pub var mintLimit: UInt64
        pub var png: String
        pub var layer: String

        init(
            name: String,
            description: String,
            category: String,
            mintLimit: UInt64,
            png: String,
            layer: String
        ) {
            RaptaAccessory.totalSupply = RaptaAccessory.totalSupply + 1

            self.id = RaptaAccessory.totalSupply
            self.name = name
            self.description = description
            self.category = category
            self.mintLimit = mintLimit
            self.png = png
            self.layer = layer
        }

        pub fun updatePNG(newPNG: String) {
            self.png = newPNG
        }
        pub fun updateLayer(newLayer: String) {
            self.layer = newLayer
        }
        pub fun updateDescription(newDescription: String) {
            self.description = newDescription
        }
        pub fun updateCategory(newCategory: String){
            self.category = newCategory
        }
        pub fun updateName(newName: String){
            self.name = newName
        }
        pub fun updateMintLimit(newLimit: UInt64){
            self.mintLimit = newLimit
        }
    }
    pub resource TemplateCollection: TemplateCollectionPublic {
        pub var ownedTemplates: @{UInt64: RaptaAccessory.Template}

        init () {
            self.ownedTemplates <- {}
        }

        pub fun deposit(template: @RaptaAccessory.Template) {
            let id: UInt64 = template.id
            let oldTemplate <- self.ownedTemplates[id] <- template
            destroy oldTemplate
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedTemplates.keys
        }

        pub fun borrowAccessoryTemplate(id: UInt64): &RaptaAccessory.Template? {
            if self.ownedTemplates[id] != nil {
                let ref = (&self.ownedTemplates[id] as auth &RaptaAccessory.Template?)!
                return ref as! &RaptaAccessory.Template
            } else {
                return nil
            }
        }

        destroy() {
            destroy self.ownedTemplates
        }
    }
//FUNCTIONS
//Accessory Functions
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }
    pub fun getpngForAccessory(address: Address, accessoryId: UInt64): String? {
        let account = getAccount(address)
        if let collection = account.getCapability(self.CollectionPublicPath).borrow<&{RaptaAccessory.CollectionPublic}>() {
            return collection.borrowAccessory(id: accessoryId)!.getPNG()
        }
        return nil
    }
    pub fun getAccessory(address: Address, accessoryId: UInt64) : AccessoryData? {
        let account = getAccount(address)
        if let collection = account.getCapability(self.CollectionPublicPath).borrow<&{RaptaAccessory.CollectionPublic}>() {
            if let accessory = collection.borrowAccessory(id: accessoryId) {
                return AccessoryData(
                    id: accessoryId,
                    templateId: accessory!.templateId
                )
            }
        }
        return nil
    }
    pub fun getAccessories(address: Address): [AccessoryData] {
        var accessoryData: [AccessoryData] = []
        let account = getAccount(address)

        if let collection = account.getCapability(self.CollectionPublicPath).borrow<&{RaptaAccessory.CollectionPublic}>() {
            for id in collection.getIDs() {
                var accessory = collection.borrowAccessory(id: id)
                accessoryData.append(AccessoryData(
                    id: id,
                    templateId: accessory!.templateId
                ))
            }
        }
        return accessoryData
    } 

    access(account) fun mintAccessory(templateId: UInt64): @RaptaAccessory.NFT {
        let template: RaptaAccessory.TemplateData = RaptaAccessory.getAccessoryTemplate(id: templateId)!
        let totalMintedAccessories: UInt64 = RaptaAccessory.getTotalMintedAccessoriesByTemplate(id: templateId)!

        if(totalMintedAccessories >= template.mintLimit) {
            panic("this collection has reached it's limit")
        }

        if(templateId <= 3){
            panic("accessories from these series are not mintable")
        }

        var accessory <- create NFT(templateId: templateId, royalties: Royalties(royalty: RaptaAccessory.royalties))
        emit Mint(id: accessory.id, templateId: templateId)

        return <- accessory
    }
//Template Functions
    access(account) fun createEmptyTemplateCollection(): @RaptaAccessory.TemplateCollection {
        return <- create TemplateCollection()
    }
    pub fun getAccessoryTemplates() : [TemplateData] {
        var accessoryTemplateData: [TemplateData] = []

        if let templateCollection = self.account.getCapability(self.TemplatePublicPath).borrow<&{RaptaAccessory.TemplateCollectionPublic}>() {
            for id in templateCollection.getIDs() {
                var template = templateCollection.borrowAccessoryTemplate(id: id)
                accessoryTemplateData.append(TemplateData(
                    id: id,
                    name: template!.name,
                    description: template!.description,
                    category: template!.category,
                    png: template!.png,
                    layer: template!.layer,
                    mintLimit: template!.mintLimit,
                ))
            }
        }  
        return accessoryTemplateData 
    }
    pub fun getAccessoryTemplate(id: UInt64) : TemplateData? {
        if let templateCollection = self.account.getCapability(self.TemplatePublicPath).borrow<&{RaptaAccessory.TemplateCollectionPublic}>() {
            if let template = templateCollection.borrowAccessoryTemplate(id: id) {
                return TemplateData(
                    id: id,
                    name: template!.name,
                    description: template!.description,
                    category: template!.category,
                    png: template!.png,
                    layer: template!.layer,
                    mintLimit: template!.mintLimit,
                )
            }
        }
        return nil   
    }
    pub fun getTotalMintedAccessoriesByTemplate(id: UInt64) : UInt64? {
        return RaptaAccessory.totalMintedAccessories[id]
    }
    access(contract) fun setTotalMintedAccessoriesByTemplate(id: UInt64, value: UInt64) {
        RaptaAccessory.totalMintedAccessories[id] = value
    }
    access(account) fun initialAccessories(templateId: UInt64): @RaptaAccessory.NFT { 
        pre {
            RaptaAccessory.getAccessoryTemplate(id: templateId) != nil : "Template doesn't exist"
            RaptaAccessory.getTotalMintedAccessoriesByTemplate(id: templateId)! < RaptaAccessory.getAccessoryTemplate(id: templateId)!.mintLimit : "Cannot mint RaptaAccessory - mint limit reached"  
        }

        let newNFT: @NFT <- create RaptaAccessory.NFT(templateId: templateId, royalties: Royalties(royalty: RaptaAccessory.royalties))
        emit Mint(id: newNFT.id, templateId: templateId)
        return <- newNFT
    }
    access(contract) fun starterTemplate( 
        name: String, 
        description: String, 
        category: String, 
        mintLimit: UInt64, 
        png: String,
        layer: String
    ) : @RaptaAccessory.Template  { 

        var newTemplate <- create Template(
            name: name,
            description: description,
            category: category,
            mintLimit: mintLimit,
            png: png,
            layer: layer
        )

        emit TemplateCreated(id: newTemplate.id, name: newTemplate.name, category: newTemplate.category, mintLimit: newTemplate.mintLimit)
        RaptaAccessory.setTotalMintedAccessoriesByTemplate(id: newTemplate.id, value: 0)
        return <- newTemplate
    }
    access(account) fun createAccessoryTemplate( 
        name: String, 
        description: String, 
        category: String, 
        mintLimit: UInt64, 
        png: String,
        layer: String
    ) { 

        var newTemplate <- create Template(
            name: name,
            description: description,
            category: category,
            mintLimit: mintLimit,
            png: png,
            layer: layer
        )

        emit TemplateCreated(id: newTemplate.id, name: newTemplate.name, category: newTemplate.category, mintLimit: newTemplate.mintLimit)
        RaptaAccessory.setTotalMintedAccessoriesByTemplate(id: newTemplate.id, value: 0)
        self.account.borrow<&RaptaAccessory.TemplateCollection>(from: RaptaAccessory.TemplateStoragePath)!.deposit(template: <- newTemplate)

    }
//INITIALIZER
    init() {
        //Accessory Init
        self.CollectionStoragePath = /storage/RaptaAccessoryCollection
        self.CollectionPublicPath = /public/RaptaAccessoryCollection

        self.account.save<@NonFungibleToken.Collection>(<- RaptaAccessory.createEmptyCollection(), to: RaptaAccessory.CollectionStoragePath)                
        self.account.link<&{RaptaAccessory.CollectionPublic}>(RaptaAccessory.CollectionPublicPath, target: RaptaAccessory.CollectionStoragePath)

        self.royalties = []
        self.royaltyCut = 0.01
        self.marketplaceCut = 0.05

        //Template Init
        self.TemplateStoragePath = /storage/RaptaTemplateCollection
        self.TemplatePublicPath = /public/RaptaTemplateCollection

        self.totalSupply = 0
        self.totalMintedAccessories = {}

        self.account.save<@RaptaAccessory.TemplateCollection>(<-RaptaAccessory.createEmptyTemplateCollection(), to: RaptaAccessory.TemplateStoragePath)
        self.account.link<&{RaptaAccessory.TemplateCollectionPublic}>(RaptaAccessory.TemplatePublicPath, target: RaptaAccessory.TemplateStoragePath)
        let jacket <- self.starterTemplate(
            name: "DZN_ x rapta designer vest concept", 
            description: "a customized piece of gear readily available to apply to your Rapta icon. this accessory is not redeemable in real life but serves as part of a starter back to familiarize you with the process of applying gear to your icon. enjoy.", 
            category: "jacket", 
            mintLimit: 444,
            png: "uri.png",
            layer: "DZNxRaptaVest.png"
        )
        let pants <- self.starterTemplate(
            name: "DZN_ x rapta designer pants concept", 
            description: "a customized piece of gear readily available to apply to your Rapta icon. this accessory is not redeemable in real life but serves as part of a starter back to familiarize you with the process of applying gear to your icon. enjoy.", 
            category: "pants", 
            mintLimit: 444,
            png: "uri.png",
            layer: "DZNxRaptaPants.png"
        )
        let shoes <- self.starterTemplate(
            name: "AFOnes", 
            description: "a customized piece of gear readily available to apply to your Rapta icon. this accessory is not redeemable in real life but serves as part of a starter back to familiarize you with the process of applying gear to your icon. enjoy.", 
            category: "shoes", 
            mintLimit: 444,
            png: "uri.png",
            layer: "AFOnes.png"
        )
        self.account.borrow<&RaptaAccessory.TemplateCollection>(from: RaptaAccessory.TemplateStoragePath)!.deposit(template: <- jacket)
        self.account.borrow<&RaptaAccessory.TemplateCollection>(from: RaptaAccessory.TemplateStoragePath)!.deposit(template: <- pants)
        self.account.borrow<&RaptaAccessory.TemplateCollection>(from: RaptaAccessory.TemplateStoragePath)!.deposit(template: <- shoes)

        emit ContractInitialized()
    }
} 