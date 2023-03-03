import KeeprNFTStorefront from 0x5eb12ad3d5a99945

pub contract KeeprAdmin {

    pub let KeeprAdminStoragePath: StoragePath
    pub let KeeprAdminPublicPath: PublicPath

    pub event InitAdmin()
    pub event AddedCapability(owner: Address)

    pub resource interface AdminStorefrontManagerPublic {
        pub fun addCapability(_ cap: Capability<&KeeprNFTStorefront.Storefront>, owner: Address)
    }

    pub resource AdminStorefront {
        access(all) let account: Address
        access(all) let storefrontCapability: Capability<&KeeprNFTStorefront.Storefront>

        init(account: Address, storefrontCapability: Capability<&KeeprNFTStorefront.Storefront>) {
            self.account = account
            self.storefrontCapability = storefrontCapability
        }
    }

    pub resource AdminStorefrontManager: AdminStorefrontManagerPublic {
        access(self) var storefronts: @{Address: AdminStorefront}

        init() {
            self.storefronts <- {}

            emit InitAdmin()
        }

        destroy() {
            destroy self.storefronts
        }

        pub fun addCapability(_ cap: Capability<&KeeprNFTStorefront.Storefront>, owner: Address) {
            let storefront <- create AdminStorefront(account: owner, storefrontCapability: cap)
            let oldStorefront <- self.storefronts[owner] <- storefront
            destroy oldStorefront
        }

        pub fun getCapability(owner: Address): &AdminStorefront? {
            return &self.storefronts[owner] as! &AdminStorefront?
        }
    }

    pub fun createStorefrontManager(): @AdminStorefrontManager {
        return <-create AdminStorefrontManager()
    }

    init() {
        self.KeeprAdminStoragePath = /storage/keepradmin002
        self.KeeprAdminPublicPath = /public/keepradmin002
    }

}