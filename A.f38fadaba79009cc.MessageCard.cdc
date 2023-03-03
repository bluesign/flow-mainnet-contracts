// _____________________________________________________________________________
//     _   _                                            __                      
//     /  /|                                          /    )                   /
// ---/| /-|----__---__---__----__----__----__-------/---------__---)__----__-/-
//   / |/  |  /___) (_ ` (_ ` /   ) /   ) /___)     /        /   ) /   ) /   /  
// _/__/___|_(___ _(__)_(__)_(___(_(___/_(___ _____(____/___(___(_/_____(___/___
//                                    /                                         
//                                (_ /                                          

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract MessageCard: NonFungibleToken {
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let CollectionStoragePath: StoragePath
    pub let TemplatesPublicPath: PublicPath
    pub let TemplatesPrivatePath: PrivatePath
    pub let TemplatesStoragePath: StoragePath
    pub var totalSupply: UInt64
    pub var totalTemplates: UInt64
    access(account) var thumbnailBaseUrl: String
    access(account) var description: String
    access(account) var royalties: MetadataViews.Royalties?
    access(account) var externalURLBase: String?
    access(account) var nftCollectionDisplay: MetadataViews.NFTCollectionDisplay?

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event Minted(id: UInt64, templateId: UInt64)
    pub event Destroyed(id: UInt64)
    pub event UsedTemplateChanged(id: UInt64, templateId: UInt64)
    pub event TemplateCreated(templateId: UInt64, creator: Address, name: String, description: String)
    pub event TemplateDestroyed(templateId: UInt64, creator: Address, name: String)

    pub struct RenderResult {
        pub var dataType: String
        pub var data: AnyStruct
        pub var extraData: {String: AnyStruct}

        init(
            dataType: String,
            data: AnyStruct,
            extraData: {String: AnyStruct},
        ) {
            self.dataType = dataType
            self.data = data
            self.extraData = extraData
        }
    }

    pub struct interface IRenderer {
        pub fun render(params: {String: AnyStruct}): RenderResult
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub var params: {String: AnyStruct}
        pub var templatesCapability: Capability<&Templates{TemplatesPublic}>
        pub var templateId: UInt64

        access(account) fun updateParams(params: {String: AnyStruct}) {
            self.params = params
        }

        access(account) fun updateTemplate(templatesCapability: Capability<&Templates{TemplatesPublic}>, templateId: UInt64) {
            pre {
                templateId != self.templateId: "Same templateId"
            }
            post {
                self.isValidTemplate(): "Invalid template"
            }
            self.templatesCapability = templatesCapability
            self.templateId = templateId
            emit UsedTemplateChanged(id: self.id, templateId: self.templateId)
        }

        pub fun isValidTemplate(): Bool {
            if let templates = self.templatesCapability.borrow() {
                if let template = templates.borrowPublicTemplateRef(templateId: self.templateId) {
                    return true
                }
            }
            return false
        }

        pub fun getRenderer(): {IRenderer}? {
            if let templates = self.templatesCapability.borrow() {
                if let template = templates.borrowPublicTemplateRef(templateId: self.templateId) {
                    return template.getRenderer()
                }
            }
            return nil
        }

        pub fun getViews(): [Type] {
            let views = [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
            if MessageCard.royalties != nil {
                views.append(Type<MetadataViews.Royalties>())
            }
            if MessageCard.externalURLBase != nil {
                views.append(Type<MetadataViews.ExternalURL>())
            }
            if MessageCard.nftCollectionDisplay != nil {
                views.append(Type<MetadataViews.NFTCollectionDisplay>())
            }
            return views
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "#".concat(self.id.toString()),
                        description: MessageCard.description,
                        thumbnail: MetadataViews.HTTPFile(url: MessageCard.thumbnailBaseUrl.concat(self.id.toString())),
                    )
                case Type<MetadataViews.Royalties>():
                    return MessageCard.royalties
                case Type<MetadataViews.ExternalURL>():
                    if MessageCard.externalURLBase != nil {
                        return MetadataViews.ExternalURL(MessageCard.externalURLBase!.concat(self.owner!.address.toString()).concat("/card/").concat(self.id.toString()))
                    }
                    return nil
                case Type<MetadataViews.Traits>():
                    if let renderer = self.getRenderer() {
                        let renderResult = renderer.render(params: self.params)
                        return MetadataViews.Traits([
                            MetadataViews.Trait(name: "dataType", value: renderResult.dataType, displayType: nil, rarity: nil),
                            MetadataViews.Trait(name: "data", value: renderResult.data, displayType: nil, rarity: nil),
                            MetadataViews.Trait(name: "extraData", value: renderResult.extraData, displayType: nil, rarity: nil)
                        ])
                    }
                    return nil
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: MessageCard.CollectionStoragePath,
                        publicPath: MessageCard.CollectionPublicPath,
                        providerPath: MessageCard.CollectionPrivatePath,
                        publicCollection: Type<&Collection{CollectionPublic}>(),
                        publicLinkedType: Type<&Collection{CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Collection{CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <- MessageCard.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MessageCard.nftCollectionDisplay
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
            }
            return nil
        }

        init(
            params: {String: AnyStruct},
            templatesCapability: Capability<&Templates{TemplatesPublic}>,
            templateId: UInt64,
        ) {
            post {
                self.isValidTemplate(): "Invalid template"
            }
            MessageCard.totalSupply = MessageCard.totalSupply + 1
            self.id = MessageCard.totalSupply
            self.params = params
            self.templatesCapability = templatesCapability
            self.templateId = templateId
            emit Minted(id: self.id, templateId: templateId)
        }

        destroy() {
            emit Destroyed(id: self.id)
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowMessageCard(id: UInt64): &MessageCard.NFT? {
            post {
                (result == nil) || (result?.id == id): "Cannot borrow MessageCard reference"
            }
        }
    }

    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @MessageCard.NFT
            let id: UInt64 = token.id
            self.ownedNFTs[id] <-! token
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowMessageCard(id: UInt64): &MessageCard.NFT? {
            if self.ownedNFTs[id] != nil {
                return (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &MessageCard.NFT
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &MessageCard.NFT
            return nft as &AnyResource{MetadataViews.Resolver}
        }

        pub fun updateParams(id: UInt64, params: {String: AnyStruct}) {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &MessageCard.NFT
            nft.updateParams(params: params)
        }

        pub fun updateTemplate(id: UInt64, templatesCapability: Capability<&Templates{TemplatesPublic}>, templateId: UInt64) {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &MessageCard.NFT
            nft.updateTemplate(templatesCapability: templatesCapability, templateId: templateId)
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub resource interface TemplatePublic {
        pub let templateId: UInt64
        pub fun getRenderer(): {IRenderer}
    }

    pub resource Template: TemplatePublic {
        pub let templateId: UInt64
        pub let creator: Address
        pub let name: String
        pub let description: String
        pub var renderer: {IRenderer}

        pub fun getRenderer(): {IRenderer} {
            return self.renderer
        }

        pub fun updateRenderer(renderer: {IRenderer}) {
            self.renderer = renderer
        }

        init(
            creator: Address,
            name: String, 
            description: String,
            renderer: {IRenderer}
        ) {
            MessageCard.totalTemplates = MessageCard.totalTemplates + 1
            self.templateId = MessageCard.totalTemplates
            self.creator = creator
            self.name = name
            self.description = description
            self.renderer = renderer
            emit TemplateCreated(templateId: self.templateId, creator: self.creator, name: self.name, description: self.description)
        }

        destroy() {
            emit TemplateDestroyed(templateId: self.templateId, creator: self.creator, name: self.name)
        }
    }

    pub resource interface TemplatesPublic {
        pub fun getIDs(): [UInt64]
        pub fun borrowPublicTemplateRef(templateId: UInt64): &Template{TemplatePublic}?
        access(account) fun borrowTemplatesRef(): &Templates
    }

    pub resource Templates: TemplatesPublic {
        access(account) var templates: @{UInt64: Template}

        pub fun createTemplate(
            name: String, 
            description: String,
            renderer: {IRenderer},
        ): UInt64 {
            let template <- create Template(
                creator: self.owner!.address,
                name: name, 
                description: description,
                renderer: renderer
            )
            let templateId = template.templateId
            self.templates[templateId] <-! template
            return templateId
        }

        pub fun deleteTemplate(templateId: UInt64) {
            let template <- self.templates.remove(key: templateId)
            assert(template != nil, message: "Not Found")
            destroy template
        }

        pub fun getIDs(): [UInt64] {
            return self.templates.keys
        }

        pub fun borrowPublicTemplateRef(templateId: UInt64): &Template{TemplatePublic}? {
            return &self.templates[templateId] as &Template{TemplatePublic}?
        }

        access(account) fun borrowTemplatesRef(): &Templates {
            return &self as &Templates
        }

        pub fun borrowTemplateRef(templateId: UInt64): &Template? {
            return &self.templates[templateId] as &Template?
        }

        init() {
            self.templates <- {}
        }

        destroy() {
            destroy self.templates
        }
    }

    pub resource Maintainer {
        pub fun setThumbnailBaseUrl(url: String) {
            MessageCard.thumbnailBaseUrl = url
        }

        pub fun setDescription(description: String) {
            MessageCard.description = description
        }

        pub fun setRoyalties(royalties: MetadataViews.Royalties) {
            MessageCard.royalties = royalties
        }

        pub fun setExternalURLBase(externalURLBase: String) {
            MessageCard.externalURLBase = externalURLBase
        }

        pub fun setNFTCollectionDisplay(nftCollectionDisplay: MetadataViews.NFTCollectionDisplay) {
            MessageCard.nftCollectionDisplay = nftCollectionDisplay
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun createEmptyTemplateCollection(): @Templates {
        return <- create Templates()
    }

    pub fun mint(
        params: {String: AnyStruct},
        templatesCapability: Capability<&Templates{TemplatesPublic}>,
        templateId: UInt64,
    ): @NFT {
        return <- create NFT(
            params: params,
            templatesCapability: templatesCapability,
            templateId: templateId
        )
    }

    init() {
        self.CollectionPublicPath = /public/MessageCardCollectionPublicPath
        self.CollectionPrivatePath = /private/MessageCardCollectionPrivatePath
        self.CollectionStoragePath = /storage/MessageCardCollectionStoragePath
        self.TemplatesPublicPath = /public/MessageCardTemplatesPublicPath
        self.TemplatesPrivatePath = /private/MessageCardTemplatesPrivatePath
        self.TemplatesStoragePath = /storage/MessageCardTemplatesStoragePath
        self.totalSupply = 0
        self.totalTemplates = 0
        self.thumbnailBaseUrl = "https://i.imgur.com/QbZ5SVO.png#"
        self.description = "You can create or use any template to create a permanent digital message card."
        self.royalties = nil
        self.externalURLBase = nil
        self.nftCollectionDisplay = nil

        self.account.save(<- create Maintainer(), to: /storage/MessageCardMaintainer)
        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&MessageCard.Collection{NonFungibleToken.CollectionPublic, MessageCard.CollectionPublic, MetadataViews.ResolverCollection}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        emit ContractInitialized()
    }
}
