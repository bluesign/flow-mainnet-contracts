import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import Profile from 0x097bafa4e0b48eef
 
pub contract XGStudio: NonFungibleToken {

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event NFTDestroyed(id: UInt64)
    pub event NFTMinted(nftId: UInt64, templateId: UInt64, mintNumber: UInt64)
    pub event BrandCreated(brandId: UInt64, brandName: String, author: Address, data:{String: String})
    pub event BrandUpdated(brandId: UInt64, brandName: String, author: Address, data:{String: String})
    pub event SchemaCreated(schemaId: UInt64, schemaName: String, author: Address)
    pub event TemplateCreated(templateId: UInt64, brandId: UInt64, schemaId: UInt64, maxSupply: UInt64)
    pub event TemplateRemoved(templateId: UInt64)

    // Paths
    pub let AdminResourceStoragePath: StoragePath
    pub let NFTMethodsCapabilityPrivatePath: PrivatePath
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStorageCapability: StoragePath
    pub let AdminCapabilityPrivate: PrivatePath

    // Latest brand-id
    pub var lastIssuedBrandId: UInt64

    // Latest schema-id
    pub var lastIssuedSchemaId: UInt64

    // Latest brand-id
    pub var lastIssuedTemplateId: UInt64

    // Total supply of all NFTs that are minted using this contract
    pub var totalSupply: UInt64
    
    // A dictionary that stores all Brands against it's brand-id.
    access(self) var allBrands: {UInt64: Brand}
    access(self) var allSchemas: {UInt64: Schema}
    access(self) var allTemplates: {UInt64: Template}
    access(self) var allNFTs: {UInt64: NFTData}

    // Accounts ability to add capability
    access(self) var whiteListedAccounts: [Address]

    // Create Schema Support all the mentioned Types
    pub enum SchemaType: UInt8 {
        pub case String
        pub case Int
        pub case Fix64
        pub case Bool
        pub case Address
        pub case Array
        pub case Any
        pub case Royalties

    }

    // A structure that contain all the data related to a Brand
    pub struct Brand {
        pub let brandId: UInt64
        pub let brandName: String
        pub let author: Address
        access(contract) var data: {String: String}
        
        init(brandName: String, author: Address, data: {String: String}) {
            pre {
                brandName.length > 0: "Brand name is required";
            }

            let newBrandId = XGStudio.lastIssuedBrandId
            self.brandId = newBrandId
            self.brandName = brandName
            self.author = author
            self.data = data
        }
        pub fun update(data: {String: String}) {
            self.data = data
        }
    }

    // A structure that contain all the data related to a Schema
    pub struct Schema {
        pub let schemaId: UInt64
        pub let schemaName: String
        pub let author: Address
        access(contract) let format: {String: SchemaType}

        init(schemaName: String, author: Address, format: {String: SchemaType}){
            pre {
                schemaName.length > 0: "Could not create schema: name is required"
            }

            let newSchemaId = XGStudio.lastIssuedSchemaId
            self.schemaId = newSchemaId
            self.schemaName = schemaName
            self.author = author
            self.format = format
        }
    }

    // A structure that contain all the data and methods related to Template
    pub struct Template {
        pub let templateId: UInt64
        pub let brandId: UInt64
        pub let schemaId: UInt64
        pub var maxSupply: UInt64
        pub var issuedSupply: UInt64
        access(contract) var immutableData: {String: AnyStruct}

        init(brandId: UInt64, schemaId: UInt64, maxSupply: UInt64, immutableData: {String: AnyStruct}) {
            pre {
                XGStudio.allBrands[brandId] != nil:"Brand Id must be valid"
                XGStudio.allSchemas[schemaId] != nil:"Schema Id must be valid"
                maxSupply > 0 : "MaxSupply must be greater than zero"
                immutableData != nil: "ImmutableData must not be nil"
            }

            self.templateId = XGStudio.lastIssuedTemplateId
            self.brandId = brandId
            self.schemaId = schemaId
            self.maxSupply = maxSupply
            self.immutableData = immutableData
            self.issuedSupply = 0
            // Before creating template, we need to check template data, if it is valid against given schema or not
            let schema = XGStudio.allSchemas[schemaId]!
            var invalidKey: String = ""
            var isValidTemplate = true

            for key in immutableData.keys {
                let value = immutableData[key]!
                if(schema.format[key] == nil) {
                    isValidTemplate = false
                    invalidKey = "key $".concat(key.concat(" not found"))
                    break
                }
                if schema.format[key] == XGStudio.SchemaType.String {
                    if(value as? String == nil) {
                        isValidTemplate = false
                        invalidKey = "key $".concat(key.concat(" has type mismatch"))
                        break
                    }
                }
                else if schema.format[key] == XGStudio.SchemaType.Int {
                    if(value as? Int == nil) {
                        isValidTemplate = false
                        invalidKey = "key $".concat(key.concat(" has type mismatch"))
                        break
                    }
                } 
                else if schema.format[key] == XGStudio.SchemaType.Fix64 {
                    if(value as? Fix64 == nil) {
                        isValidTemplate = false
                        invalidKey = "key $".concat(key.concat(" has type mismatch"))
                        break
                    }
                }else if schema.format[key] == XGStudio.SchemaType.Bool {
                    if(value as? Bool == nil) {
                        isValidTemplate = false
                        invalidKey = "key $".concat(key.concat(" has type mismatch"))
                        break
                    }
                }else if schema.format[key] == XGStudio.SchemaType.Address {
                    if(value as? Address == nil) {
                        isValidTemplate = false
                        invalidKey = "key $".concat(key.concat(" has type mismatch"))
                        break
                    }
                }
                else if schema.format[key] == XGStudio.SchemaType.Array {
                    if(value as? [AnyStruct] == nil) {
                        isValidTemplate = false
                        invalidKey = "key $".concat(key.concat(" has type mismatch"))
                        break
                    }
                }
                else if schema.format[key] == XGStudio.SchemaType.Any {
                    if(value as? {String:AnyStruct} ==nil) {
                        isValidTemplate = false
                        invalidKey = "key $".concat(key.concat(" has type mismatch"))
                        break
                    }
                }
            }
            assert(isValidTemplate, message: "invalid template data. Error: ".concat(invalidKey))
        }

        // a method to get the immutable data of the template
        pub fun getImmutableData(): {String:AnyStruct} {
            return self.immutableData
        }
        
        // a method to increment issued supply for template
        access(contract) fun incrementIssuedSupply(): UInt64 {
            pre {
                self.issuedSupply < self.maxSupply: "Template reached max supply"
            }   

            self.issuedSupply = self.issuedSupply + 1
            return self.issuedSupply
        }
    }

    // A structure that link template and mint-no of NFT
    pub struct NFTData {
        pub let templateID: UInt64
        pub let mintNumber: UInt64
        access(contract) var immutableData: {String: AnyStruct}

        init(templateID: UInt64, mintNumber: UInt64, immutableData: {String: AnyStruct}) {
            self.templateID = templateID
            self.mintNumber = mintNumber
            self.immutableData = immutableData
        }
        // a method to get the immutable data of the NFT
        pub fun getImmutableData(): {String:AnyStruct} {
            return self.immutableData
        }
    }

    // The resource that represents the XGStudio NFTs
    // 
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        access(contract) let data: NFTData

        init(templateID: UInt64, mintNumber: UInt64, immutableData: {String:AnyStruct}) {
            XGStudio.totalSupply = XGStudio.totalSupply + 1
            self.id = XGStudio.totalSupply
            XGStudio.allNFTs[self.id] = NFTData(templateID: templateID, mintNumber: mintNumber, immutableData: immutableData)
            self.data = XGStudio.allNFTs[self.id]!
            emit NFTMinted(nftId: self.id, templateId: templateID, mintNumber: mintNumber)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Medias>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let token = XGStudio.getNFTDataById(nftId: self.id)
            let uniqueData = token.getImmutableData()
            let template =  XGStudio.getTemplateById(templateId: token.templateID)
            let templateData = template.getImmutableData()
            let brand = XGStudio.getBrandById(brandId: template.brandId)


            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: (templateData["title"] as! String?) ?? "",
                        description: self.getAssetDescription(),
                        thumbnail: self.getThumbnailFile()
                    )
                case Type<MetadataViews.Editions>():
                    return MetadataViews.Editions(self.getEditions())
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MetadataViews.NFTCollectionDisplay(
                        name: brand.data["name"] ?? "",
                        description: brand.data["description"] ?? "",
                        externalURL: MetadataViews.ExternalURL(brand.data["websiteUrl"] ?? "https://xgstudios.io"),
                        squareImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: brand.data["squareUrl"] ?? ""
                            ),
                            mediaType: "image/png"
                        ),
                        bannerImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: brand.data["bannerUrl"] ?? ""
                            ),
                            mediaType: "image/png"
                        ),
                        socials: {
                            "twitter": MetadataViews.ExternalURL(brand.data["twitter"] ?? ""),
                            "instagram": MetadataViews.ExternalURL(brand.data["instagram"] ?? ""),
                            "discord": MetadataViews.ExternalURL(brand.data["discord"] ?? ""),
                            "tiktok": MetadataViews.ExternalURL(brand.data["tiktok"] ?? "")
                        }
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL((brand.data["websiteUrl"] ?? "https://xgstudios.io").concat("/rewards/").concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: XGStudio.CollectionStoragePath,
                        publicPath: XGStudio.CollectionPublicPath,
                        providerPath: /private/XGStudioCollectionProvider,
                        publicCollection: Type<&XGStudio.Collection{XGStudio.XGStudioCollectionPublic}>(),
                        publicLinkedType: Type<&XGStudio.Collection{XGStudio.XGStudioCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&XGStudio.Collection{XGStudio.XGStudioCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @XGStudio.Collection {
                            return <- (XGStudio.createEmptyCollection() as! @XGStudio.Collection)
                        })
                    )
                // @TODO: Implement Royalties
                case Type<MetadataViews.Royalties>():
                    return self.getRoyalties()
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.Medias>():
                    let contentFile = self.getContentFile()
                    let contentType = templateData["contentType"] as! String? ?? ""

                    if (contentFile == nil) {
                        return MetadataViews.Medias([])
                    }

                    return MetadataViews.Medias([
                        MetadataViews.Media(
                            contentFile!,
                            contentType == "mp4" ? "video/mp4" : contentType
                        )
                    ])
                case Type<MetadataViews.Traits>():      
                    let dummyExcludes: [String] = [];
            
                    if (templateData["traits"] != nil) {
                        return MetadataViews.dictToTraits(dict: templateData["traits"] as! {String: AnyStruct}, excludedNames: dummyExcludes)
                    }
                    let excludedTraits = [
                        "nftType", "xGRewardType",
                        "contentUrl", 
                        "contentType",
                        "title",
                        "description",
                        "thumbnail",
                        "royalties"
                    ]
                    let traitsView = MetadataViews.dictToTraits(dict: templateData, excludedNames: excludedTraits)

                    var rewardTypeValue: String = "";
                    if (templateData["xGRewardType"] != nil) {
                        rewardTypeValue = templateData["xGRewardType"] as! String? ?? ""
                    } else {
                        rewardTypeValue = templateData["nftType"] as! String? ?? ""
                    }
                    let rewardTypeTrait = MetadataViews.Trait(name: "xGRewardType", value: rewardTypeValue, displayType: nil, rarity: nil)
                    traitsView.addTrait(rewardTypeTrait)

                    //NFT specific traits
                    let NFTTraits = MetadataViews.dictToTraits(dict: self.data.getImmutableData(), excludedNames: dummyExcludes)
                    for trait in NFTTraits.traits {
                        traitsView.addTrait(trait)
                    }
                    return traitsView
            }

            return nil
        }
        /*         
        * Get the NFT description template's thumbnail
         */
        pub fun getAssetDescription(): String {
            let token = XGStudio.getNFTDataById(nftId: self.id)
            let template =  XGStudio.getTemplateById(templateId: token.templateID)
            let templateData = template.getImmutableData()

            //Default behaviour
            if (templateData["description"] != nil) {
                let description = templateData["description"] as! String? ?? ""
                return description
            }


            if (templateData["activityType"] as! String? == "Football") {
                let commonText = 
                    "\n\nGet xG Rewards for your football achievements.\nBuild your collection - your story.\nUnlock xG experiences.\n\nhttps://linktr.ee/xgstudios"
                switch(templateData["xGRewardType"] as! String? ?? "") {
                    case "Team Clean Sheet": 
                        return "Team Clean Sheet: The xG Reward for players who appeared in a fixture where their team kept a clean sheet.".concat(commonText) 
                    case "Goal Scored": 
                        return "Goal: The xG Reward for the scorer of every goal.".concat(commonText)
                    case "Team Goals": 
                        return "Team Goals: The xG Reward for players who appeared in a fixture where their team scored.\nEach reward includes the total goals scored by their team in the game."
                            .concat(commonText)  
                    case "Win": 
                        return "Win: The xG Reward for players who made an appearance a win.".concat(commonText)
                    case "Appearance": 
                        return "Appearance: The xG Reward for players with game time in a fixture.".concat(commonText)
                    case "GK Clean Sheet": 
                        return "Clean Sheet: The xG Reward for goalkeepers who keep a clean sheet in a match.".concat(commonText)
                    case "Hat Trick": 
                        return "Hat Trick: The xG Reward for scorers of three goals in a match.".concat(commonText)
                }
            }

            return ""
        }

        /*
         * Get the thumbnail file from the NFT template's thumbnail
         */
        pub fun getThumbnailFile(): {MetadataViews.File} {
            let token = XGStudio.getNFTDataById(nftId: self.id)
            let template =  XGStudio.getTemplateById(templateId: token.templateID)
            let templateData = template.getImmutableData()

            //Default behaviour
            if (templateData["thumbnail"] != nil) {
                let cid = templateData["thumbnail"] as! String? ?? ""
                return MetadataViews.IPFSFile(cid, "")
            }

            if (templateData["raceName"] as! String? == "Hackney Half Marathon 2022") {
                switch(templateData["nftType"] as! String? ?? "") {
                    case "Finish LE": return MetadataViews.IPFSFile("QmUAoUBy4xPRDqH7BKx5ZpVYcFzums9scZu83ccefLrFkr", "FINISH_LE.png")
                    case "Finish": return MetadataViews.IPFSFile("QmUAoUBy4xPRDqH7BKx5ZpVYcFzums9scZu83ccefLrFkr", "FINISH.png")
                }
                
                switch(templateData["title"] as! String? ?? "") {
                    case "1st Place - HACKNEY HALF 2022": return MetadataViews.IPFSFile("QmUAoUBy4xPRDqH7BKx5ZpVYcFzums9scZu83ccefLrFkr", "1ST.png")
                    case "2nd Place - HACKNEY HALF 2022": return MetadataViews.IPFSFile("QmUAoUBy4xPRDqH7BKx5ZpVYcFzums9scZu83ccefLrFkr", "2ND.png")
                    case "3rd Place - HACKNEY HALF 2022": return MetadataViews.IPFSFile("QmUAoUBy4xPRDqH7BKx5ZpVYcFzums9scZu83ccefLrFkr", "3RD.png")
                }
            }

            if (templateData["raceName"] as! String? == "ASICS London 10K 2022") {
                switch(templateData["nftType"] as! String? ?? "") {
                    case "Finish LE": return MetadataViews.IPFSFile("Qmdu543z9kvSgX5fS54rpF8sFcX4t5ZbaFBk7YhZFQcn5Y", "FINISH_LE.png")
                    case "Finish": return MetadataViews.IPFSFile("Qmdu543z9kvSgX5fS54rpF8sFcX4t5ZbaFBk7YhZFQcn5Y", "FINISH.png")
                }

                switch(templateData["title"] as! String? ?? "") {
                    case "1st - ASICS LONDON 10K": return MetadataViews.IPFSFile("Qmdu543z9kvSgX5fS54rpF8sFcX4t5ZbaFBk7YhZFQcn5Y", "1ST.png")
                    case "2nd - ASICS LONDON 10K": return MetadataViews.IPFSFile("Qmdu543z9kvSgX5fS54rpF8sFcX4t5ZbaFBk7YhZFQcn5Y", "2ND.png")
                    case "3rd - ASICS LONDON 10K": return MetadataViews.IPFSFile("Qmdu543z9kvSgX5fS54rpF8sFcX4t5ZbaFBk7YhZFQcn5Y", "3RD.png")
                }
            }

            if (templateData["raceName"] as! String? == "London Triathlon 2022") {
                return MetadataViews.IPFSFile("QmSr56aRWEDtD9fEHQrQw9gZjZwYuVK68YUDnHyF1vWcqj", "TRIATHLON.png")
            }

            if (templateData["raceName"] as! String? == "London Duathlon 2022") {
                return MetadataViews.IPFSFile("QmSr56aRWEDtD9fEHQrQw9gZjZwYuVK68YUDnHyF1vWcqj", "DUATHLON.png")
            }

            if (templateData["raceName"] as! String? == "London Duathlon 2022") {
                return MetadataViews.IPFSFile("QmPYTarYVgKMXQ4wHxGKLURpUKGzWkdUuyY1AkrKXxHDvn", "xG_GENESIS_FINISH_GNR_THUMB.png")
            }

            if (templateData["activityType"] as! String? == "Football") {
                switch(templateData["xGRewardType"] as! String? ?? "") {
                    case "Team Clean Sheet": return MetadataViews.IPFSFile("QmSPFN7uaUaW1H9GsET9HHKudMCLvB5JyFDPxyQ4FoGd5k", "TEAM_CLEANSHEET.png")
                    case "Goal Scored": return MetadataViews.IPFSFile("QmSPFN7uaUaW1H9GsET9HHKudMCLvB5JyFDPxyQ4FoGd5k", "GOAL_SCORED.png")
                    case "Team Goals": return MetadataViews.IPFSFile("QmSPFN7uaUaW1H9GsET9HHKudMCLvB5JyFDPxyQ4FoGd5k", "TEAM_GOAL.png")
                    case "Win": return MetadataViews.IPFSFile("QmSPFN7uaUaW1H9GsET9HHKudMCLvB5JyFDPxyQ4FoGd5k", "WIN.png")
                    case "Appearance": return MetadataViews.IPFSFile("QmSPFN7uaUaW1H9GsET9HHKudMCLvB5JyFDPxyQ4FoGd5k", "APPEARANCE.png")
                    case "GK Clean Sheet": return MetadataViews.IPFSFile("QmSPFN7uaUaW1H9GsET9HHKudMCLvB5JyFDPxyQ4FoGd5k", "CLEANSHEET.png")
                    case "Hat Trick": return MetadataViews.IPFSFile("QmbB8panH4gg4A3WpzVdoawHtYcXySLKbEphrEoYs9rZC6", "HAT_TRICK_THUMB.png")
                }
            }

            return MetadataViews.HTTPFile("")
        }

        /*
         * Get the content file from the NFT template's contentUrl
         */
        pub fun getContentFile(): {MetadataViews.File}? {
            let token = XGStudio.getNFTDataById(nftId: self.id)
            let template =  XGStudio.getTemplateById(templateId: token.templateID)
            let templateData = template.getImmutableData()

            let contentUrl = templateData["contentUrl"] as! String?

            // Early return if contentUrl is not set
            if (contentUrl == nil || contentUrl!.length < 4) {
                return nil;
            }

            let protocol = contentUrl!.slice(from: 0, upTo: 4)

            // Return legacy URLs starting with http as HTTPFile
            if (protocol == "http") {
                return MetadataViews.HTTPFile(contentUrl!)
            }

            let fileType = contentUrl!.slice(from: contentUrl!.length - 3, upTo: contentUrl!.length)

            // Return legacy URLs ending with .mp4 as HTTPFile, prepended with the IPFS gateway
            if (fileType == "mp4") {
                return MetadataViews.HTTPFile("https://xgstudios.mypinata.cloud/ipfs/".concat(contentUrl!))
            }

            // Return contentUrl as IPFSFile
            return MetadataViews.IPFSFile(contentUrl!, nil)
        }

        pub fun getEditions(): [MetadataViews.Edition] {
            let token = XGStudio.getNFTDataById(nftId: self.id)
            let template =  XGStudio.getTemplateById(templateId: token.templateID)
            let templateData = template.getImmutableData()

            let editions = [
                // Title Edition
                MetadataViews.Edition(
                    name: (templateData["title"] as! String?) ?? "",
                    number: self.data.mintNumber,
                    max: template.maxSupply
                )
            ]

            // If we're dealing with Football and have a season
            if (templateData["activityType"] as! String? == "Football" && templateData["season"] != nil) {
                let season = templateData["season"] as! String?;
                let allTemplates = XGStudio.getAllTemplates()

                // The combined maxSupply of all templates of this season
                var seasonMaxSupply: UInt64 = 0
                // The supply of templates that came before this one
                var earlierSeasonSupply: UInt64 = 0

                for i in allTemplates.keys {
                    let template = allTemplates[i]!
                    let templateData = template.getImmutableData()

                    // We only care about templates with the same season
                    if (templateData["season"] as! String? == season) {
                        // Add maxSupply to the total
                        seasonMaxSupply = seasonMaxSupply + template.maxSupply

                        // Add maxSupply to earlier supply if the template came before this one
                        if (i < token.templateID) {
                            earlierSeasonSupply = earlierSeasonSupply + template.maxSupply
                        }
                    }
                }

                editions.append(
                    // Football Season Edition
                    MetadataViews.Edition(
                        name: season,
                        number: earlierSeasonSupply + self.data.mintNumber,
                        max: seasonMaxSupply
                    )
                )
            }

            return editions
        }

        pub fun getRoyalties(): MetadataViews.Royalties {
            let token = XGStudio.getNFTDataById(nftId: self.id)
            let template =  XGStudio.getTemplateById(templateId: token.templateID)
            let templateData = template.getImmutableData()

            let genericReceiver = getAccount(0x2ce293d39a72a72b).getCapability<&{FungibleToken.Receiver}>(Profile.publicReceiverPath)

            // Only add receiver if the Profile capability exists
            let royalties: [MetadataViews.Royalty] = genericReceiver.check() ? [
                MetadataViews.Royalty(
                    receiver: genericReceiver,
                    cut: 0.025,
                    description: "Artist"
                )
            ] : []

            if (template.brandId == 1) {
                // xGMove
                let receiver = getAccount(0xc2307c44b0903e33).getCapability<&{FungibleToken.Receiver}>(Profile.publicReceiverPath)

                // Only add receiver if the Profile capability exists
                if (receiver.check()) {
                    royalties.append(
                        MetadataViews.Royalty(
                            receiver: receiver,
                            cut: 0.05,
                            description: "xGMove treasury"
                        )
                    )
                }
            } else if (template.brandId == 2) {
                // xGFootball
                let receiver = getAccount(0xa6fa47e9ad815dcf).getCapability<&{FungibleToken.Receiver}>(Profile.publicReceiverPath)

                // Only add receiver if the Profile capability exists
                if (receiver.check()) {
                    royalties.append(
                        MetadataViews.Royalty(
                            receiver: receiver,
                            cut: 0.05,
                            description: "xGFootball treasury"
                        )
                    )
                }
            }

            return MetadataViews.Royalties(royalties)
        }

        destroy() {
            emit NFTDestroyed(id: self.id)
        }
    }


    pub resource interface XGStudioCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowXGStudio_NFT(id: UInt64): &XGStudio.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Reward reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection is a resource that every user who owns NFTs 
    // will store in their account to manage their NFTS
    //
    pub resource Collection: XGStudioCollectionPublic,NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot withdraw: template does not exist in the collection")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @XGStudio.NFT
            let id = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            if self.owner?.address != nil {
                emit Deposit(id: id, to: self.owner?.address)
            }
            destroy oldToken
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

         // borrowXGStudio_NFT returns a borrowed reference to a XGStudio
        // so that the caller can read data and call methods from it.
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        pub fun borrowXGStudio_NFT(id: UInt64): &XGStudio.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &XGStudio.NFT?
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let xgNFT = nft as! &XGStudio.NFT
            return xgNFT
        }


        init() {
            self.ownedNFTs <- {}
        }
        
        
        destroy () {
            destroy self.ownedNFTs
        }
    }

    // Special Capability, that is needed by user to utilize our contract. Only verified user can get this capability so it will add a KYC layer in our white-lable-solution
    pub resource interface UserSpecialCapability {
        pub fun addCapability(cap: Capability<&{NFTMethodsCapability}>)
    }

    // Interface, which contains all the methods that are called by any user to mint NFT and manage brand, schema and template funtionality
    pub resource interface NFTMethodsCapability {
        pub fun createNewBrand(brandName: String, data: {String: String})
        pub fun updateBrandData(brandId: UInt64, data: {String: String})
        pub fun createSchema(schemaName: String, format: {String: SchemaType})
        pub fun createTemplate(brandId: UInt64, schemaId: UInt64, maxSupply: UInt64, immutableData: {String: AnyStruct})
        pub fun mintNFT(templateId: UInt64, account: Address, immutableData:{String:AnyStruct})
        pub fun removeTemplateById(templateId: UInt64): Bool
    }
    
    //AdminCapability to add whiteListedAccounts
    pub resource AdminCapability {
        pub fun addwhiteListedAccount(_user: Address) {
            pre{
                XGStudio.whiteListedAccounts.contains(_user) == false: "user already exist"
            }
            XGStudio.whiteListedAccounts.append(_user)
        }

        pub fun isWhiteListedAccount(_user: Address): Bool {
            return XGStudio.whiteListedAccounts.contains(_user)
        }

        init(){}
    }

    // AdminResource, where are defining all the methods related to Brands, Schema, Template and NFTs
    pub resource AdminResource: UserSpecialCapability, NFTMethodsCapability {
        // a variable which stores all Brands owned by a user
        priv var ownedBrands: {UInt64: Brand}
        // a variable which stores all Schema owned by a user
        priv var ownedSchemas: {UInt64: Schema}
        // a variable which stores all Templates owned by a user
        priv var ownedTemplates: {UInt64: Template}
        // a variable that store user capability to utilize methods 
        access(contract) var capability: Capability<&{NFTMethodsCapability}>?
        // method which provide capability to user to utilize methods
        pub fun addCapability(cap: Capability<&{NFTMethodsCapability}>) {
            pre {
                // we make sure the SpecialCapability is
                // valid before executing the method
                cap.borrow() != nil: "could not borrow a reference to the SpecialCapability"
                self.capability == nil: "resource already has the SpecialCapability"
                XGStudio.whiteListedAccounts.contains(self.owner!.address): "you are not authorized for this action"
            }
            // add the SpecialCapability
            self.capability = cap
        }

        //method to create new Brand, only access by the verified user
        pub fun createNewBrand(brandName: String, data: {String: String}) {
            pre {
                XGStudio.whiteListedAccounts.contains(self.owner!.address): "you are not authorized for this action"
            }
            
            let newBrand = Brand(brandName: brandName, author: self.owner?.address!, data: data)
            XGStudio.allBrands[XGStudio.lastIssuedBrandId] = newBrand
            emit BrandCreated(brandId: XGStudio.lastIssuedBrandId ,brandName: brandName, author: self.owner?.address!, data: data)
            self.ownedBrands[XGStudio.lastIssuedBrandId] = newBrand 
            XGStudio.lastIssuedBrandId = XGStudio.lastIssuedBrandId + 1
        }

        //method to update the existing Brand, only author of brand can update this brand
        pub fun updateBrandData(brandId: UInt64, data: {String: String}) {
            pre{
                XGStudio.whiteListedAccounts.contains(self.owner!.address): "you are not authorized for this action"
                XGStudio.allBrands[brandId] != nil: "brand Id does not exists"
            }

            let oldBrand = XGStudio.allBrands[brandId]
            if self.owner?.address! != oldBrand!.author {
                panic("No permission to update others brand")
            }

            XGStudio.allBrands[brandId]!.update(data: data)
            emit BrandUpdated(brandId: brandId, brandName: oldBrand!.brandName, author: oldBrand!.author, data: data)
        }

        //method to create new Schema, only access by the verified user
        pub fun createSchema(schemaName: String, format: {String: SchemaType}) {
            pre {
                XGStudio.whiteListedAccounts.contains(self.owner!.address): "you are not authorized for this action"
            }

            let newSchema = Schema(schemaName: schemaName, author: self.owner?.address!, format: format)
            XGStudio.allSchemas[XGStudio.lastIssuedSchemaId] = newSchema
            emit SchemaCreated(schemaId: XGStudio.lastIssuedSchemaId, schemaName: schemaName, author: self.owner?.address!)
            self.ownedSchemas[XGStudio.lastIssuedSchemaId] = newSchema
            XGStudio.lastIssuedSchemaId = XGStudio.lastIssuedSchemaId + 1
            
        }

        //method to create new Template, only access by the verified user
        pub fun createTemplate(brandId: UInt64, schemaId: UInt64, maxSupply: UInt64, immutableData: {String: AnyStruct}) {
            pre { 
                XGStudio.whiteListedAccounts.contains(self.owner!.address): "you are not authorized for this action"
                self.ownedBrands[brandId] != nil: "Collection Id Must be valid"
                self.ownedSchemas[schemaId] != nil: "Schema Id Must be valid"
            }

            let newTemplate = Template(brandId: brandId, schemaId: schemaId, maxSupply: maxSupply, immutableData: immutableData)
            XGStudio.allTemplates[XGStudio.lastIssuedTemplateId] = newTemplate
            emit TemplateCreated(templateId: XGStudio.lastIssuedTemplateId, brandId: brandId, schemaId: schemaId, maxSupply: maxSupply)
            self.ownedTemplates[XGStudio.lastIssuedTemplateId] = newTemplate
            XGStudio.lastIssuedTemplateId = XGStudio.lastIssuedTemplateId + 1
        }
        //method to mint NFT, only access by the verified user
        pub fun mintNFT(templateId: UInt64, account: Address, immutableData:{String:AnyStruct}) {
            pre{
                XGStudio.whiteListedAccounts.contains(self.owner!.address): "you are not authorized for this action"
                self.ownedTemplates[templateId]!= nil: "Minter does not have specific template Id"
                XGStudio.allTemplates[templateId] != nil: "Template Id must be valid"
                }
            let receiptAccount = getAccount(account)
            let recipientCollection = receiptAccount
                .getCapability(XGStudio.CollectionPublicPath)
                .borrow<&{XGStudio.XGStudioCollectionPublic}>()
                ?? panic("Could not get receiver reference to the NFT Collection")
            var newNFT: @NFT <- create NFT(templateID: templateId, mintNumber: XGStudio.allTemplates[templateId]!.incrementIssuedSupply(), immutableData:immutableData )
            recipientCollection.deposit(token: <-newNFT)
        }

          //method to remove template by id
        pub fun removeTemplateById(templateId: UInt64): Bool {
            pre {
                XGStudio.whiteListedAccounts.contains(self.owner!.address): "you are not authorized for this action"
                templateId != nil: "invalid template id"
                XGStudio.allTemplates[templateId]!=nil: "template id does not exist"
                XGStudio.allTemplates[templateId]!.issuedSupply == 0: "could not remove template with given id"   
            }
            let mintsData =  XGStudio.allTemplates.remove(key: templateId)
            emit TemplateRemoved(templateId: templateId)
            return true
        }

        init() {
            self.ownedBrands = {}
            self.ownedSchemas = {}
            self.ownedTemplates = {}
            self.capability = nil
        }
    }
    
    //method to create empty Collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create XGStudio.Collection()
    }

    //method to get all brands
    pub fun getAllBrands(): {UInt64: Brand} {
        return XGStudio.allBrands
    }

    //method to get brand by id
    pub fun getBrandById(brandId: UInt64): Brand {
        pre {
            XGStudio.allBrands[brandId] != nil: "brand Id does not exists"
        }
        return XGStudio.allBrands[brandId]!
    }

    //method to get all schema
    pub fun getAllSchemas(): {UInt64: Schema} {
        return XGStudio.allSchemas
    }

    //method to get schema by id
    pub fun getSchemaById(schemaId: UInt64): Schema {
        pre {
            XGStudio.allSchemas[schemaId] != nil: "schema id does not exist"
        }
        return XGStudio.allSchemas[schemaId]!
    }

    //method to get all templates
    pub fun getAllTemplates(): {UInt64: Template} {
        return XGStudio.allTemplates
    }

    //method to get template by id
    pub fun getTemplateById(templateId: UInt64): Template {
        pre {
            XGStudio.allTemplates[templateId]!=nil: "Template id does not exist"
        }
        return XGStudio.allTemplates[templateId]!
    } 

    //method to get nft-data by id
    pub fun getNFTDataById(nftId: UInt64): NFTData {
        pre {
            XGStudio.allNFTs[nftId]!=nil: "nft id does not exist"
        }
        return XGStudio.allNFTs[nftId]!
    }

    //Initialize all variables with default values
    init() {
        self.lastIssuedBrandId = 1
        self.lastIssuedSchemaId = 1
        self.lastIssuedTemplateId = 1
        self.totalSupply = 0
        self.allBrands = {}
        self.allSchemas = {}
        self.allTemplates = {}
        self.allNFTs = {}
        self.whiteListedAccounts = [self.account.address]

        self.AdminResourceStoragePath = /storage/XGStudioAdminResource
        self.CollectionStoragePath = /storage/XGStudioCollection
        self.CollectionPublicPath = /public/XGStudioCollection
        self.AdminStorageCapability = /storage/XGStudioAdminCapability
        self.AdminCapabilityPrivate = /private/XGStudioAdminCapability
        self.NFTMethodsCapabilityPrivatePath = /private/XGStudioNFTMethodsCapability
        
        self.account.save<@AdminCapability>(<- create AdminCapability(), to: /storage/AdminStorageCapability)
        self.account.link<&AdminCapability>(self.AdminCapabilityPrivate, target: /storage/AdminStorageCapability)
        self.account.save<@AdminResource>(<- create AdminResource(), to: self.AdminResourceStoragePath)
        self.account.link<&{NFTMethodsCapability}>(self.NFTMethodsCapabilityPrivatePath, target: self.AdminResourceStoragePath)

        emit ContractInitialized()
    }
}
 
