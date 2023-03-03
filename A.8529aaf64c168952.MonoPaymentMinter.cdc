import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MonoGold from 0x8529aaf64c168952
import MonoSilver from 0x8529aaf64c168952
import FUSD from 0x3c5959b568896393

pub contract MonoPaymentMinter {
    pub let AdminStoragePath: StoragePath

    pub var goldPrice: UFix64?
    pub var goldStartTime: UFix64?
    pub var goldEndTime: UFix64?
    pub var goldBaseUri: String?
    pub var silverPrice: UFix64?
    pub var silverStartTime: UFix64?
    pub var silverEndTime: UFix64?
    pub var silverBaseUri: String?

    pub fun paymentMintGold(
        payment: @FungibleToken.Vault,
        recipient: &{NonFungibleToken.CollectionPublic}
    ){
        pre {
            self.goldStartTime! <= getCurrentBlock().timestamp: "sale not started yet"
            self.goldEndTime! > getCurrentBlock().timestamp: "sale already ended"
            payment.isInstance(Type<@FUSD.Vault>()): "payment vault is not requested fungible token"
            payment.balance == self.goldPrice!: "payment vault does not contain requested price"
        }
        let fusdReceiver = self.account.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)!
        let receiver = fusdReceiver.borrow()!

        receiver.deposit(from: <- payment)

        let minter = self.account.borrow<&MonoGold.NFTMinter>(from: MonoGold.MinterStoragePath)!
        let metadata: {String:String} = {}
        metadata["token_uri"] = self.goldBaseUri!.concat("/").concat(MonoGold.totalSupply.toString())
        minter.mintNFT(recipient: recipient, metadata: metadata)
    }

    pub fun paymentMintSilver(
            payment: @FungibleToken.Vault,
            recipient: &{NonFungibleToken.CollectionPublic}
    ){
        pre {
            self.silverStartTime! <= getCurrentBlock().timestamp: "sale not started yet"
            self.silverEndTime! > getCurrentBlock().timestamp: "sale already ended"
            payment.isInstance(Type<@FUSD.Vault>()): "payment vault is not requested fungible token"
            payment.balance == self.silverPrice!: "payment vault does not contain requested price"
        }
        let fusdReceiver = self.account.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)!
        let receiver = fusdReceiver.borrow()!

        receiver.deposit(from: <- payment)

        let minter = self.account.borrow<&MonoSilver.NFTMinter>(from: MonoSilver.MinterStoragePath)!
        let metadata: {String:String} = {}
        metadata["token_uri"] = self.silverBaseUri!.concat("/").concat(MonoSilver.totalSupply.toString())
        minter.mintNFT(recipient: recipient, metadata: metadata)
    }

    pub resource Administrator {
        pub fun setGold(goldPrice: UFix64, goldStartTime: UFix64, goldEndTime: UFix64,goldBaseUri: String){
            MonoPaymentMinter.goldPrice = goldPrice
            MonoPaymentMinter.goldStartTime = goldStartTime
            MonoPaymentMinter.goldEndTime = goldEndTime
            MonoPaymentMinter.goldBaseUri = goldBaseUri
        }

        pub fun setSilver(silverPrice: UFix64, silverStartTime: UFix64, silverEndTime: UFix64, silverBaseUri: String){
            MonoPaymentMinter.silverPrice = silverPrice
            MonoPaymentMinter.silverStartTime = silverStartTime
            MonoPaymentMinter.silverEndTime = silverEndTime
            MonoPaymentMinter.silverBaseUri = silverBaseUri
        }
    }
    init() {
        self.goldPrice = nil
        self.goldStartTime = nil
        self.goldEndTime = nil
        self.goldBaseUri = nil
        self.silverPrice = nil
        self.silverStartTime = nil
        self.silverEndTime = nil
        self.silverBaseUri = nil
        self.AdminStoragePath = /storage/MonoPaymentMinterAdmin
        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
    }
}
