import NonFungibleToken from  0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import RaptaAccessory from 0xc8eb8906f29b7a9c

pub contract RaptaIcon: NonFungibleToken {

//STORAGE PATHS
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
//EVENTS
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64)
	pub event AccessoryAdded(raptaIconId: UInt64, accessory: String)
	pub event AccessoryRemoved(raptaIconId: UInt64, accessory: String)
    pub event Updated(iconId: UInt64)
//VARIABLES
    pub var totalSupply: UInt64
    pub var dynamicImage: String
    pub var png: String
    pub var layer: String
    pub var royalties: [Royalty]
    access(account) var royaltyCut: UFix64
    access(account) var marketplaceCut: UFix64
//ENUMERABLES
    pub enum RoyaltyType: UInt8{
        pub case fixed
        pub case percentage
    }
//STRUCTS
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
    pub struct IconData {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let accessories: &{String: RaptaAccessory.NFT}
        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            accessories: &{String: RaptaAccessory.NFT}
        ){
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.accessories = accessories 
        }
    }
//INTERFACES
    pub resource interface Public {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub fun getAccessories(): &{String: RaptaAccessory.NFT}
        pub fun getPng(): String
    }

    pub resource interface Private {
        pub fun addAccessory(accessory: @RaptaAccessory.NFT): @RaptaAccessory.NFT?
        pub fun removeAccessory(category: String): @RaptaAccessory.NFT?
        access(contract) fun toggleThumbnail()
        access(contract) fun updatePNG(newPNG: String)
        access(contract) fun updateLayer(newLayer: String)
    }

    pub resource interface CollectionPublic {    
        pub fun deposit(token: @NonFungibleToken.NFT) 
		pub fun getIDs(): [UInt64]
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
		pub fun borrowIcon(id: UInt64): &RaptaIcon.NFT? {
			post {
				(result == nil) || (result?.id == id):
					"Cannot borrow Rapta reference: the ID of the returned reference is incorrect"
			}
		}
    }
//RESOURCES
    pub resource NFT: NonFungibleToken.INFT, Public, Private, MetadataViews.Resolver {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        // ipfs base image
        pub var png: String 
        // base layer without accessories
        pub var layer: String 
        // dynamic image compiled according to accessories
        pub var dynamicImage: String
        // public image (dymanic vs png) 
        pub var thumbnail: String 
        access(contract) let accessories: @{String: RaptaAccessory.NFT}
        access(contract) let royalties : Royalties

       
        init(
            royalties: Royalties
        ){
        
            RaptaIcon.totalSupply = RaptaIcon.totalSupply + 1
            
            self.id = RaptaIcon.totalSupply
            self.name = "Rapta Icon"
            self.description = "the icon is a clay-character representation of Rapta in his 2022 era, designed by @krovenn."
            self.png = RaptaIcon.png
            self.layer = RaptaIcon.layer
            self.dynamicImage = RaptaIcon.dynamicImage.concat(self.id.toString().concat(".png"))
            self.thumbnail = self.png
            self.accessories <- {
                "jacket": <- RaptaAccessory.initialAccessories(templateId: 1), 
                "pants": <- RaptaAccessory.initialAccessories(templateId: 2), 
                "shoes": <- RaptaAccessory.initialAccessories(templateId: 3) 
            }
            self.royalties = royalties
            emit Mint(id: self.id)
        }

        destroy() {
            destroy self.accessories
        }
        pub fun getID(): UInt64 {
            return self.id
        }
        pub fun getName(): String {
            return self.name
        }
        pub fun getDescription(): String {
            return self.description
        }
        pub fun getPng(): String {
            return self.png
        }
        pub fun getThumbnail() :String {
            return self.thumbnail
        }
        pub fun getAccessories(): &{String: RaptaAccessory.NFT} {
            return &self.accessories as &{String: RaptaAccessory.NFT}
        }
        pub fun addAccessory(accessory: @RaptaAccessory.NFT): @RaptaAccessory.NFT? {
            let id: UInt64 = accessory.id
            let category = accessory.getCategory()
            let name = accessory.getName()
            let removedAccessory <- self.accessories[category] <- accessory
            emit AccessoryAdded(raptaIconId: self.id, accessory: name)
            return <- removedAccessory
        }
        pub fun removeAccessory(category: String): @RaptaAccessory.NFT? {
            let removedAccessory <- self.accessories.remove(key: category)!
            emit AccessoryRemoved(raptaIconId: self.id, accessory: category)
            return <- removedAccessory
        }
        pub fun toggleThumbnail() {
            if self.thumbnail == self.png {
                self.thumbnail = self.dynamicImage
            }
            else if self.thumbnail == self.dynamicImage {
                self.thumbnail = self.png
            } else {
                self.thumbnail = self.png
            }
        }
        access(contract) fun updateLayer(newLayer: String) {
            self.layer = newLayer
        }
        access(contract) fun updatePNG(newPNG: String) {
            self.png = newPNG
        }
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
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
                        url: self.thumbnail
                        )
                    )

                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://eqmusic.io/rapta/icons/".concat(self.id.toString()).concat(".png"))

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: RaptaIcon.CollectionStoragePath,
                        publicPath: RaptaIcon.CollectionPublicPath,
                        providerPath: /private/RaptaCollection,
                        publicCollection: Type<&RaptaIcon.Collection{RaptaIcon.CollectionPublic}>(),
                        publicLinkedType: Type<&RaptaIcon.Collection{RaptaIcon.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&RaptaIcon.Collection{RaptaIcon.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-RaptaIcon.createEmptyCollection()
                        })
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://eqmusic.io/media/raptaCollection.png"
                        ),
                        mediaType: "image/png+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Rapta Collection",
                        description: "444 icons. collect and get access to exclusive offerings and interactive experiences with Rapta.",
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
                    let royalties : [MetadataViews.Royalty] = []
                    var count: Int = 0
                    for royalty in self.royalties.royalty {
                        royalties.append(MetadataViews.Royalty(recepient: royalty.wallet, cut: royalty.cut, description: "Rapta Icon Royalty ".concat(count.toString())))
                        count = count + Int(1)
                    }
                    return MetadataViews.Royalties(cutInfos: royalties)
            }
            return nil
        }
    }  
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        destroy() {
            destroy self.ownedNFTs
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let id: UInt64 = token.id
            let token <- token as! @RaptaIcon.NFT
            let removedToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy removedToken
        }
        
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist in this collection.")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowIcon(id: UInt64): &RaptaIcon.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &RaptaIcon.NFT
            } else {
                return nil
            }
        }

        pub fun borrowIconPrivate(id: UInt64): &{RaptaIcon.Private}? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &RaptaIcon.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            pre {
                self.ownedNFTs[id] != nil : "NFT does not exist"
            }
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let RaptaIcon = nft as! &RaptaIcon.NFT
            return RaptaIcon as &AnyResource{MetadataViews.Resolver}
        }
    }
    pub resource Admin {
        pub fun mintIcon(user: Address): @NFT {
            pre {
                RaptaIcon.totalSupply < 444 : "This collection is sold out"
            }
            
            let acct = getAccount(user)
            let collection = acct.getCapability<&RaptaIcon.Collection{RaptaIcon.CollectionPublic}>(RaptaIcon.CollectionPublicPath).borrow()!
            let icons = collection.getIDs().length

            return <- create NFT(royalties: Royalties(royalty: RaptaIcon.royalties))    
        }

        pub fun mintAccessory(templateId: UInt64): @RaptaAccessory.NFT {
            let accessory <- RaptaAccessory.mintAccessory(templateId: templateId)
            return <- accessory
       }   

        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }

        pub fun updateContractPng(newPng: String) {
            RaptaIcon.png = newPng
        }

        pub fun updateIconLayer(user: AuthAccount, id: UInt64, newLayer: String) {
            let icon = user.borrow<&RaptaIcon.Collection>(from: RaptaIcon.CollectionStoragePath)!.borrowIcon(id: id)!
            icon.updateLayer(newLayer: newLayer)
            emit Updated(iconId: id)
        }

        pub fun updateIconPng(user: AuthAccount, id: UInt64, newPNG: String) {
            let icon = user.borrow<&RaptaIcon.Collection>(from: RaptaIcon.CollectionStoragePath)!.borrowIcon(id: id)!
            icon.updatePNG(newPNG: newPNG)
            emit Updated(iconId: id)
        }

        pub fun setRoyaltyCut(value: UFix64) {
            RaptaIcon.setRoyaltyCut(value: value)
        }

        pub fun setMarketplaceCut(value: UFix64) {
            RaptaIcon.setMarketplaceCut(value: value)
        }

        pub fun createAccessoryTemplate(name: String, description: String, category: String, mintLimit: UInt64, png: String, layer: String) {
            RaptaAccessory.createAccessoryTemplate(name: name, description: description, category: category, mintLimit: mintLimit, png: png, layer: layer)
        }

        pub fun setRoyalites(newRoyalties: [Royalty]): [RaptaIcon.Royalty] {
            RaptaIcon.setRoyalites(newRoyalties: newRoyalties)
            return RaptaIcon.royalties
        }
    }
//FUNCTIONS
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun getRoyaltyCut(): UFix64{
        return self.royaltyCut
    }

    pub fun getMarketplaceCut(): UFix64{
        return self.marketplaceCut
    }

    access(account) fun setRoyaltyCut(value: UFix64){
        self.royaltyCut = value
    }

    access(account) fun setMarketplaceCut(value: UFix64){
        self.marketplaceCut = value
    }

    access(account) fun setRoyalites(newRoyalties: [Royalty]): [RaptaIcon.Royalty] {
        self.royalties = newRoyalties
        return self.royalties
    }

    pub fun addAccessory(account: AuthAccount, iconId: UInt64, accessoryId: UInt64) {
        let iconCollection: &RaptaIcon.Collection = account.borrow<&RaptaIcon.Collection>(from: RaptaIcon.CollectionStoragePath)!
        let accessories: &RaptaAccessory.Collection = account.borrow<&RaptaAccessory.Collection>(from: RaptaAccessory.CollectionStoragePath)!
        let accessory: @RaptaAccessory.NFT <- accessories.withdraw(withdrawID: accessoryId) as! @RaptaAccessory.NFT

        let icon: &{RaptaIcon.Private} = iconCollection.borrowIcon(id: iconId)!
        let accessorize <- icon.addAccessory(accessory: <- accessory)
        if (accessorize != nil) {
            accessories.deposit(token: <- accessorize!)
        } else {
            destroy accessorize
        }
        emit Updated(iconId: iconId)
    }

    pub fun removeAccessory(account: AuthAccount, iconId: UInt64, category: String){
        let icon: &RaptaIcon.NFT = account.borrow<&RaptaIcon.Collection>(from: RaptaIcon.CollectionStoragePath)!.borrowIcon(id: iconId)!
        let accessories: &RaptaAccessory.Collection = account.borrow<&RaptaAccessory.Collection>(from: RaptaAccessory.CollectionStoragePath)!

        let removedAccessory <- icon.removeAccessory(category: category)
        if (removedAccessory != nil) {
            accessories.deposit(token: <- removedAccessory!)
        } else {
            destroy removedAccessory
        }
    }

     pub fun mintIcon(user: Address): @NFT {
            pre {
                RaptaIcon.totalSupply < 444 : "This collection is sold out"
            }
            
            let acct = getAccount(user)
            let collection = acct.getCapability<&RaptaIcon.Collection{RaptaIcon.CollectionPublic}>(RaptaIcon.CollectionPublicPath).borrow()!
            let icons = collection.getIDs().length
            if (icons >= 1) {
                panic("This collection only allows one mint per wallet")
            }
            return <- create NFT(royalties: Royalties(royalty: RaptaIcon.royalties))    
    }


//INITIALIZER
    init() {
        self.CollectionPublicPath = /public/RaptaIconCollection
        self.CollectionStoragePath = /storage/RaptaIconCollection
        self.AdminStoragePath = /storage/RaptaIconAdmin

        self.totalSupply = 0
        self.dynamicImage = "https://eqmusic.io/rapta/icons/"
        self.png = "https://ipfs.io/ipfs/QmQS5yghWJGHSohUqy1M1yR2QDTq3cUJKifQMXopdgQdsV"
        self.layer = "raptaBaseLayer.png"
        self.royalties = []
        self.royaltyCut = 0.025
        self.marketplaceCut = 0.05

        self.account.save(<- create Admin(), to: RaptaIcon.AdminStoragePath)
        self.account.save(<- RaptaIcon.createEmptyCollection(), to: RaptaIcon.CollectionStoragePath)
        self.account.link<&RaptaIcon.Collection{RaptaIcon.CollectionPublic}>(RaptaIcon.CollectionPublicPath, target: RaptaIcon.CollectionStoragePath)

        emit ContractInitialized()
    }
}


 