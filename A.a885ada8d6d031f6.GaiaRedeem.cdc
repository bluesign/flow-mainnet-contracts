import NonFungibleToken from 0x1d7e57aa55817448

pub contract GaiaRedeem {
    pub event ContractInitialized()
    pub event NFTRedeemed(
        nftType: Type,
        nftID: UInt64,
        address: Address,
        info: {String: String}?
    )
    pub event RedeemableAdded(nftType: Type, nftID: UInt64, info: {String: String}?)
    pub event RedeemableRemoved(nftType: Type, nftID: UInt64)

    pub fun getRedeemerStoragePath(): StoragePath {
        return /storage/GaiaRedeemer
    }

    pub fun getRedeemerPublicPath(): PublicPath {
        return /public/GaiaRedeemer
    }

    pub struct RedeemableInfo {
        pub let info: {String: String}?
        pub let redeemed: Bool

        init(info: {String: String}?, redeemed: Bool) {
            self.info = info
            self.redeemed = redeemed
        }
    }

    pub struct Redeemable {
        pub let nftType: Type
        pub let nftID: UInt64
        pub let info: {String: String}?

        init(nftType: Type, nftID: UInt64, info: {String: String}?) {
            self.nftType = nftType
            self.nftID = nftID
            self.info = info
        }
    }

    pub resource interface RedeemerAdmin {
        pub fun addRedeemable(nftType: Type, nftID: UInt64, info: {String: String}?)
        pub fun removeRedeemable(nftType: Type, nftID: UInt64)
    }

    pub resource interface RedeemerPublic {
        pub fun redeemNFT(nft: @{NonFungibleToken.INFT}, address: Address)
        pub fun getRedeemableInfo(nftType: Type, nftID: UInt64): RedeemableInfo?
    }

    pub resource Redeemer: RedeemerAdmin, RedeemerPublic {
        access(self) let redeemables: {Type: {UInt64: RedeemableInfo}}

        init() {
            self.redeemables = {}
        }

        pub fun addRedeemable(nftType: Type, nftID: UInt64, info: {String: String}?) {
            if !self.redeemables.containsKey(nftType) {
                self.redeemables[nftType] = {}
            }

            let old = self.redeemables[nftType]!.insert(key: nftID, RedeemableInfo(info: info, redeemed: false))
            assert(old == nil, message: "Redeemable already exists")
            emit RedeemableAdded(nftType: nftType, nftID: nftID, info: info)
        }

        pub fun removeRedeemable(nftType: Type, nftID: UInt64) {
            self.redeemables[nftType]!.remove(key: nftID)
            emit RedeemableRemoved(nftType: nftType, nftID: nftID)
        }

        pub fun redeemNFT(nft: @{NonFungibleToken.INFT}, address: Address) {
            let redeemableInfo = self.redeemables[nft.getType()]!.remove(key: nft.id)
            assert(redeemableInfo != nil, message: "No redeemable for nft")
            assert(redeemableInfo!.redeemed == false, message: "NFT has already been redeemed")
            self.redeemables[nft.getType()]!.insert(key: nft.id, RedeemableInfo(info: redeemableInfo!.info, redeemed: true))
            emit NFTRedeemed(nftType: nft.getType(), nftID: nft.id, address: address, info: redeemableInfo!.info)
            destroy nft
        }

        pub fun getRedeemableInfo(nftType: Type, nftID: UInt64): RedeemableInfo? {
            if self.redeemables[nftType]?.containsKey(nftID) ?? false {
                return self.redeemables[nftType]![nftID]
            } else {
                return nil
            }
        }
    }

    access(contract) fun createRedeemer(): @Redeemer {
        return <- create Redeemer()
    }

    init() {
        let admin <- self.createRedeemer()
        self.account.save(<- admin, to: self.getRedeemerStoragePath())
        self.account.link<&{RedeemerPublic}>(self.getRedeemerPublicPath(), target: self.getRedeemerStoragePath())

        emit ContractInitialized()
    }
}
