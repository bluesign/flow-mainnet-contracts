import Rumble from 0x165daadd2a9437c6

pub contract TokenManager {

  pub var cooldown: UFix64

  pub let VaultPublicPath: PublicPath
  pub let VaultStoragePath: StoragePath

  pub resource interface Public {
    pub fun deposit(from: @Rumble.Vault)
    pub fun canWithdraw(): Bool
    pub fun getBalance(): UFix64
    access(account) fun distribute(to: Address, amount: UFix64)
  }

  pub resource LockedVault: Public {
    access(self) let tokens: @Rumble.Vault
    pub var withdrawTimestamp: UFix64

    pub fun deposit(from: @Rumble.Vault) {
      self.tokens.deposit(from: <- from)
      self.withdrawTimestamp = getCurrentBlock().timestamp + TokenManager.cooldown
    }

    pub fun withdraw(amount: UFix64): @Rumble.Vault {
      pre {
        self.canWithdraw(): "User cannot withdraw yet."
      }
      let tokens <- self.tokens.withdraw(amount: amount) as! @Rumble.Vault
      return <- tokens
    }

    access(account) fun distribute(to: Address, amount: UFix64) {
      let recipientVault = getAccount(to).getCapability(TokenManager.VaultPublicPath)
            .borrow<&LockedVault{Public}>() ?? panic("This user does not have a vault set up.")

      let tokens <- self.tokens.withdraw(amount: amount) as! @Rumble.Vault
      recipientVault.deposit(from: <- tokens)
    }

    pub fun canWithdraw(): Bool {
      return getCurrentBlock().timestamp >= self.withdrawTimestamp
    }

    pub fun getBalance(): UFix64 {
      return self.tokens.balance
    }

    init() {
      self.tokens <- Rumble.createEmptyVault()
      self.withdrawTimestamp = getCurrentBlock().timestamp
    }

    destroy() {
      destroy self.tokens
    }
  }

  pub fun createEmptyVault(): @LockedVault {
    return <- create LockedVault()
  }

  pub fun checkUserDepositStatusIsValid(user: Address, amount: UFix64): Bool {
    let userVault = getAccount(user).getCapability(TokenManager.VaultPublicPath)
            .borrow<&LockedVault{Public}>() ?? panic("This user does not have a vault set up.")
    return userVault.getBalance() >= amount
  }

  access(account) fun changeCooldown(newCooldown: UFix64) {
    self.cooldown = newCooldown
  }

  init() {
    self.cooldown = 0.0

    self.VaultPublicPath = /public/BloxsmithLockedVault
    self.VaultStoragePath = /storage/BloxsmithLockedVault
  }

}