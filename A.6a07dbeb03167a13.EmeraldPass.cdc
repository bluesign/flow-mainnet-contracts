import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import FlowToken from 0x1654653399040a61

// The official Emerald Pass contract. Access premium features across Emerald City tools and education by having an active subscription.
// Purchase or learn more about Emerald Pass: https://pass.ecdao.org/
// Created by Emerald City

pub contract EmeraldPass {

  access(self) var treasury: ECTreasury
  // Maps the type of a token to its pricing
  access(self) var pricing: {Type: Pricing}
  pub var purchased: UInt64

  pub let VaultPublicPath: PublicPath
  pub let VaultStoragePath: StoragePath

  pub event ChangedPricing(newPricing: {UFix64: UFix64})
  pub event Purchased(subscriber: Address, time: UFix64, vaultType: Type)
  pub event Donation(by: Address, to: Address, vaultType: Type)

  pub struct ECTreasury {
    pub let tokenTypeToVault: {Type: Capability<&{FungibleToken.Receiver}>}

    pub fun getSupportedTokens(): [Type] {
      return self.tokenTypeToVault.keys
    }

    init() {
      let ecAccount: PublicAccount = getAccount(0x5643fd47a29770e7)
      self.tokenTypeToVault = {
        Type<@FUSD.Vault>(): ecAccount.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver),
        Type<@FlowToken.Vault>(): ecAccount.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
      }
    }
  }

  pub struct Pricing {
    // examples in $FUSD
    // 100.0 -> 2629743.0 (1 month)
    // 1000.0 -> 31556926.0 (1 year)
    pub let costToTime: {UFix64: UFix64}

    pub fun getTime(cost: UFix64): UFix64? {
      return self.costToTime[cost]
    }

    init(_ costToTime: {UFix64: UFix64}) {
      self.costToTime = costToTime
    }
  }

  pub resource interface VaultPublic {
    pub var endDate: UFix64
    pub fun purchase(payment: @FungibleToken.Vault)
    access(account) fun addTime(time: UFix64)
    pub fun isActive(): Bool
  }

  pub resource Vault: VaultPublic {

    pub var endDate: UFix64

    pub fun purchase(payment: @FungibleToken.Vault) {
      let paymentType: Type = payment.getType()
      let pricing: Pricing = EmeraldPass.getPricing(vaultType: paymentType) ?? panic("This is not a supported form of payment.")
      let time: UFix64 = pricing.getTime(cost: payment.balance) ?? panic("The balance of the Vault you sent in does not correlate to any supported amounts of time.")
      
      EmeraldPass.depositToECTreasury(vault: <- payment)
      self.addTime(time: time)

      EmeraldPass.purchased = EmeraldPass.purchased + 1
      emit Purchased(subscriber: self.owner!.address, time: time, vaultType: paymentType)
    }

    pub fun isActive(): Bool {
      return getCurrentBlock().timestamp <= self.endDate
    }

    access(account) fun addTime(time: UFix64) {
      // If you're already active, just add more time to the end date.
      // Otherwise, start the subscription now and set the end date.
      if self.isActive() {
        self.endDate = self.endDate + time
      } else {
        self.endDate = getCurrentBlock().timestamp + time
      }
    }

    init() {
      self.endDate = 0.0
    }

  }

  pub fun createVault(): @Vault {
    return <- create Vault()
  }

  pub resource Admin {

    pub fun changePricing(newPricing: {Type: Pricing}) {
      EmeraldPass.pricing = newPricing
    }

    pub fun giveUserTime(user: Address, time: UFix64) {
      let userVault = getAccount(user).getCapability(EmeraldPass.VaultPublicPath)
                      .borrow<&Vault{VaultPublic}>() ?? panic("This receiver has not set up a Vault for Emerald Pass yet.")
      userVault.addTime(time: time)
    }
  
  }

  // A public function because, well, ... um ... you can
  // always call this if you want! :D ;) <3
  pub fun depositToECTreasury(vault: @FungibleToken.Vault) {
    pre {
      self.getTreasury()[vault.getType()] != nil: "We have not set up this payment yet."
    }
    self.getTreasury()[vault.getType()]!.borrow()!.deposit(from: <- vault)
  }

  // A function you can call to donate subscription time to someone else
  pub fun donate(nicePerson: Address, to: Address, payment: @FungibleToken.Vault) {
    let userVault = getAccount(to).getCapability(EmeraldPass.VaultPublicPath)
                      .borrow<&Vault{VaultPublic}>() ?? panic("This receiver has not set up a Vault for Emerald Pass yet.")
    let paymentType: Type = payment.getType()
    userVault.purchase(payment: <- payment)
    emit Donation(by: nicePerson, to: to, vaultType: paymentType)
  }

  // Checks to see if a user is currently subscribed to Emerald Pass
  pub fun isActive(user: Address): Bool {
    return getAccount(user).getCapability(EmeraldPass.VaultPublicPath).borrow<&Vault{VaultPublic}>()?.isActive() == true
  }

  pub fun getAllPricing(): {Type: Pricing} {
    return self.pricing
  }

  pub fun getPricing(vaultType: Type): Pricing? {
    return self.getAllPricing()[vaultType]
  }

  pub fun getTreasury(): {Type: Capability<&{FungibleToken.Receiver}>} {
    return ECTreasury().tokenTypeToVault
  }

  pub fun getUserVault(user: Address): &Vault{VaultPublic}? {
    return getAccount(user).getCapability(EmeraldPass.VaultPublicPath)
            .borrow<&Vault{VaultPublic}>()
  }

  init() {
    self.treasury = ECTreasury()
    self.pricing = {
      Type<@FUSD.Vault>(): Pricing({
        100.0: 2629743.0, // 1 month
        1000.0: 31556926.0 // 1 year
      })
    }
    self.purchased = 0

    self.VaultPublicPath = /public/EmeraldPass
    self.VaultStoragePath = /storage/EmeraldPass

    self.account.save(<- create Admin(), to: /storage/EmeraldPassAdmin)
  }
  
}
 