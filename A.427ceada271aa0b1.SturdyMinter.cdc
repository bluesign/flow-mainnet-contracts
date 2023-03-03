import SturdyTokens from 0x427ceada271aa0b1
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c

pub contract SturdyMinter {

  pub event ContractInitialized()

  pub let AdminStoragePath: StoragePath

  pub var mintableSets: {UInt64: MintableSet}

  pub struct MintableSet {
    pub var privateSalePrice: UFix64
    pub var publicSalePrice: UFix64
    pub var whitelistedAccounts: {Address: UInt64}

    pub fun addWhiteListAddress(address: Address, amount: UInt64) {
      pre {
        self.whitelistedAccounts[address] == nil: "Provided Address is already whitelisted"
      }
      self.whitelistedAccounts[address] = amount
    }

    pub fun removeWhiteListAddress(address: Address) {
      pre {
        self.whitelistedAccounts[address] != nil: "Provided Address is not whitelisted"
      }
      self.whitelistedAccounts.remove(key: address)
    }

    pub fun pruneWhitelist() {
      self.whitelistedAccounts = {}
    }

    pub fun updateWhiteListAddressAmount(address: Address, amount: UInt64) {
      pre {
        self.whitelistedAccounts[address] != nil:
          "Provided Address is not whitelisted"
      }
      self.whitelistedAccounts[address] = amount
    }

    pub fun updatePrivateSalePrice(price: UFix64) {
      self.privateSalePrice = price
    }

    pub fun updatePublicSalePrice(price: UFix64) {
      self.publicSalePrice = price
    }

    init(privateSalePrice: UFix64, publicSalePrice: UFix64){
      self.privateSalePrice = privateSalePrice
      self.publicSalePrice= publicSalePrice
      self.whitelistedAccounts = {}
    }
  }

  pub fun mintPrivateNFTWithDUC(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, merchantAccount: Address, numberOfTokens: UInt64) {
    pre {
      SturdyMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! >= 1:
        "Requesting account is not whitelisted"
      // This code is commented for future use case. In case addresses needs a buy amount limit for private sales, this should be discommented.
      // SturdyMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! >= numberOfTokens: "purchaseAmount exceeds allowed whitelist spots"
      paymentVault.balance >= UFix64(numberOfTokens) * SturdyMinter.mintableSets[setID]!.privateSalePrice:
        "Insufficient payment amount."
      paymentVault.getType() == Type<@DapperUtilityCoin.Vault>():
        "payment type not DapperUtilityCoin.Vault."
    }

    let admin = self.account.borrow<&SturdyTokens.Admin>(from: SturdyTokens.AdminStoragePath)
      ?? panic("Could not borrow a reference to the SturdyTokens Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("Set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }
    if (set.isPublic) { panic("Cannot mint public set with mintPrivateNFTWithDUC") }

    // Get DUC receiver reference of SturdyTokens merchant account
    let merchantDUCReceiverRef = getAccount(merchantAccount).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
      assert(merchantDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant DUC receiver")
    // Deposit DUC to SturdyTokens merchant account DUC Vault (it's then forwarded to the main DUC contract afterwards)
    merchantDUCReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive SturdyTokens
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(SturdyTokens.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Mint SturdyTokens NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }

    // Empty whitelist spot
    if (SturdyMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! - numberOfTokens == 0) {
      SturdyMinter.mintableSets[setID]!.removeWhiteListAddress(address: buyer)
    } else {
      let newAmount = SturdyMinter.mintableSets[setID]!.whitelistedAccounts[buyer]! - numberOfTokens
      SturdyMinter.mintableSets[setID]!.updateWhiteListAddressAmount(address: buyer, amount: newAmount)
    }
  }

  pub fun mintPublicNFTWithDUC(buyer: Address, setID: UInt64, paymentVault: @FungibleToken.Vault, merchantAccount: Address, numberOfTokens: UInt64) {
    pre {
      numberOfTokens <= 4:
        "purchaseAmount too large"
      paymentVault.balance >= UFix64(numberOfTokens) * SturdyMinter.mintableSets[setID]!.publicSalePrice:
        "Insufficient payment amount."
      paymentVault.getType() == Type<@DapperUtilityCoin.Vault>():
        "payment type not DapperUtilityCoin.Vault."
    }

    let admin = self.account.borrow<&SturdyTokens.Admin>(from: SturdyTokens.AdminStoragePath)
      ?? panic("Could not borrow a reference to the SturdyTokens Admin")

    let set = admin.borrowSet(setID: setID)
    // Check set availability
    if (set.getAvailableTemplateIDs().length == 0) { panic("Set is empty") }
    // Check set eligibility
    if (set.locked) { panic("Set is locked") }
    if (!set.isPublic) { panic("Cannot mint private set with mintPublicNFTWithDUC") }

    // Get DUC receiver reference of SturdyTokens merchant account
    let merchantDUCReceiverRef = getAccount(merchantAccount).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
      assert(merchantDUCReceiverRef.borrow() != nil, message: "Missing or mis-typed merchant DUC receiver")
    // Deposit DUC to SturdyTokens merchant account DUC Vault (it's then forwarded to the main DUC contract afterwards)
    merchantDUCReceiverRef.borrow()!.deposit(from: <-paymentVault)

    // Get buyer collection public to receive SturdyTokens
    let recipient = getAccount(buyer)
    let NFTReceiver = recipient.getCapability(SturdyTokens.CollectionPublicPath)
      .borrow<&{NonFungibleToken.CollectionPublic}>()
      ?? panic("Could not get receiver reference to the NFT Collection")

    // Mint SturdyTokens NFTs per purchaseAmount
    var mintCounter = numberOfTokens
    while(mintCounter > 0) {
      admin.mintNFT(recipient: NFTReceiver, setID: setID)
      mintCounter = mintCounter - 1
    }
  }

  pub resource Admin {

    pub fun createMintableSet(setID: UInt64, privateSalePrice: UFix64, publicSalePrice: UFix64) {
      pre {
        SturdyMinter.mintableSets[setID] == nil: "Set already exists"
      }
      SturdyMinter.mintableSets[setID] = MintableSet(privateSalePrice: privateSalePrice, publicSalePrice: publicSalePrice)
    }

    pub fun addWhiteListAddress(setID: UInt64, address: Address, amount: UInt64) {
      SturdyMinter.mintableSets[setID]!.addWhiteListAddress(address: address, amount: amount)
    }

    pub fun removeWhiteListAddress(setID: UInt64, address: Address) {
      SturdyMinter.mintableSets[setID]!.removeWhiteListAddress(address: address)
    }

    pub fun pruneWhitelist(setID: UInt64) {
      SturdyMinter.mintableSets[setID]!.pruneWhitelist()
    }

    pub fun updateWhiteListAddressAmount(setID: UInt64, address: Address, amount: UInt64) {
      SturdyMinter.mintableSets[setID]!.updateWhiteListAddressAmount(address: address, amount: amount)
    }

    pub fun updatePrivateSalePrice(setID: UInt64, price: UFix64) {
      SturdyMinter.mintableSets[setID]!.updatePrivateSalePrice(price: price)
    }

    pub fun updatePublicSalePrice(setID: UInt64, price: UFix64) {
      SturdyMinter.mintableSets[setID]!.updatePublicSalePrice(price: price)
    }
  }

  pub fun getWhitelistedAccounts(setID: UInt64): {Address: UInt64} {
    return SturdyMinter.mintableSets[setID]!.whitelistedAccounts
  }

  init() {
    self.AdminStoragePath = /storage/SturdyMinterAdmin

    self.mintableSets = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}