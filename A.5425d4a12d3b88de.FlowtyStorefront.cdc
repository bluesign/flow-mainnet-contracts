import NFTStorefrontV2 from 0x3cdbb3d569211ff3

access(all) contract FlowtyStorefront {
    access(all) fun getStorefrontRef(owner: Address): &NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic} {
        return getAccount(owner)
                .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
                    NFTStorefrontV2.StorefrontPublicPath
                )
                .borrow()
                ?? panic("Could not borrow public storefront from address")
    }
}