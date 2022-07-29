import FungibleToken from 0xf233dcee88fe0abe
import JoyrideMultiToken from 0xecfad18ba9582d4f
import JoyrideAccounts from 0xecfad18ba9582d4f

pub contract JoyridePayments {

  access(contract) var accountsCapability : Capability<&{JoyrideAccounts.GrantsTokenRewards, JoyrideAccounts.SharesProfits, JoyrideAccounts.PlayerAccounts}>?
  access(contract) var treasuryCapability : Capability<&JoyrideMultiToken.PlatformAdmin>?
  access(contract) let authorizedBackendAccounts: {Address:Bool}
  access(contract) let transactionStore: {String:{String:Bool}}

  pub event DebitTransactionCreate(playerID: String, txID: String, tokenContext: String, amount: UFix64, gameID: String, notes: String)
  pub event CreditTransactionCreate(playerID: String, txID: String, tokenContext: String, amount: UFix64, gameID: String, notes: String)
  pub event DebitTransactionReverted(playerID: String, txID: String, tokenContext: String, amount: UFix64, gameID: String)
  pub event DebitTransactionFinalized(playerID: String, txID: String, tokenContext: String, amount: UFix64, gameID: String, profit: UFix64)

  pub event TxFailed_DuplicateTxID(txID: String, notes: String)
  pub event TxFailed_ByTxTypeAndTxID(txID: String, txType: String, notes: String)

  init() {
    self.accountsCapability = nil
    self.treasuryCapability = nil
    self.authorizedBackendAccounts = {}
    self.transactionStore = {}

    let p2eAdmin <- create PaymentsAdmin()
    self.account.save(<-p2eAdmin, to: /storage/PaymentsAdmin)
    self.account.link<&PaymentsAdmin{WalletAdmin}>(/private/PaymentsAdmin, target: /storage/PaymentsAdmin)
  }

  //Pretty sure this is safe to be public, since a valid Capability<&JRXToken.AdminVault.{JRXToken.ConvertsRewards}> can only be created by the JRXToken contract account.
  pub fun linkAccountsCapability(accountsCapability : Capability<&JoyrideAccounts.JoyrideAccountsAdmin{JoyrideAccounts.GrantsTokenRewards, JoyrideAccounts.SharesProfits, JoyrideAccounts.PlayerAccounts}>) {
      if(!accountsCapability.check()) {panic("Capability from Invalid Source")}
      self.accountsCapability = accountsCapability
  }

  //Pretty sure this is safe to be public, since a valid Capability<&JRXToken.AdminVault.{JRXToken.ConvertsRewards}> can only be created by the JRXToken contract account.
  pub fun linkTreasuryCapability(treasuryCapability : Capability<&JoyrideMultiToken.PlatformAdmin>) {
      if(!treasuryCapability.check()) {panic("Capability from Invalid Source")}
      self.treasuryCapability = treasuryCapability
  }

  pub fun getPlay2EarnCapabilities(account: AuthAccount) : Capability<&PaymentsAdmin{WalletAdmin}> {
    if(account.address == self.account.address || self.authorizedBackendAccounts.containsKey(account.address)){
      return self.account.getCapability<&PaymentsAdmin{WalletAdmin}>(/private/PaymentsAdmin)
    }
    panic("Not Authorized")
  }

  pub resource interface WalletAdmin {
    pub fun PlayerTransaction(playerID: String, tokenContext: String, amount:Fix64, gameID: String, txID: String, reward: Bool, notes: String) : Bool
    pub fun FinalizeTransactionWithDevPercentage(txID: String, profit: UFix64, devPercentage: UFix64) : Bool
    pub fun RefundTransaction(txID: String) : Bool
  }

  pub resource Transaction {
    pub var vault : @FungibleToken.Vault
    pub let playerID : String
    pub let transactionID : String
    pub let creationTime: UFix64
    pub let gameID: String

    init(vault: @FungibleToken.Vault, playerID : String, gameID : String, txID : String) {
      self.vault <- vault
      self.playerID = playerID
      self.transactionID = txID
      self.gameID = gameID
      self.creationTime = getCurrentBlock().timestamp
    }

    destroy() {
      destroy self.vault
    }

    pub fun Refund(txID: String) : Bool {
      if(JoyridePayments.accountsCapability == nil) {
        emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "RefundTX", notes: txID.concat(": JoyrideAccountsAdmin Accounts Capability Null"))
        return false
      }

      let accountsAdmin = JoyridePayments.accountsCapability!.borrow()
      if(accountsAdmin == nil) {
        emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "RefundTX", notes: txID.concat(": JoyrideAccountsAdmin Accounts Capability Null"))
        return false
      }
      var vault <- self.vault.withdraw(amount: self.vault.balance)
      let undepositable <- accountsAdmin!.PlayerDeposit(playerID:self.playerID, vault: <-vault)
      if(undepositable != nil) {
        emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "RefundTX", notes: txID.concat(": Failed to deposit Admin Withdrawn vault in PlayerAccount"))
        self.vault.deposit(from: <- undepositable!)
        return false
      } else {
        destroy undepositable
        emit DebitTransactionReverted(playerID: self.playerID, txID: self.transactionID, tokenContext: self.vault.getType().identifier, amount: self.vault.balance, gameID: self.gameID)
        return true
      }
    }

    pub fun Finalize(txID: String, profit: UFix64, devPercentage: UFix64): Bool {
       if(JoyridePayments.accountsCapability == nil) {
         emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "FinalizeTX", notes: txID.concat(": JoyrideAccountsAdmin Accounts Capability Null"))
         return false
       }

       let accountsAdmin = JoyridePayments.accountsCapability!.borrow()
       if(accountsAdmin == nil) {
         emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "FinalizeTX", notes: txID.concat(": JoyrideAccountsAdmin Accounts Capability Null"))
         return false
       }

      if(JoyridePayments.treasuryCapability == nil) {
        emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "FinalizeTX", notes: txID.concat(": JoyrideMultiToken PlatformAdmin Capability Null"))
        return false
      }

      let treasury = JoyridePayments.treasuryCapability!.borrow()
      if(treasury == nil) {
        emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "FinalizeTX", notes: txID.concat(": JoyrideMultiToken PlatformAdmin Capability Null"))
        return false
      }

      let vault <- self.vault.withdraw(amount: profit)

      let remainder <- accountsAdmin!.ShareProfitsWithDevPercentage(profits: <- vault, inGameID: self.gameID, fromPlayerID: self.playerID, devPercentage: devPercentage)
      remainder.deposit(from: <- self.vault.withdraw(amount: self.vault.balance))

      treasury!.deposit(vault: JoyrideMultiToken.Vaults.treasury, from: <-remainder)
      emit DebitTransactionFinalized(playerID: self.playerID, txID: self.transactionID, tokenContext: self.vault.getType().identifier, amount: self.vault.balance, gameID: self.gameID, profit: profit)
      return true
    }
  }

  pub resource PaymentsAdmin : WalletAdmin {
    access(self) let pendingTransactions : @{String: Transaction}

    init() {
      self.pendingTransactions <- {}
    }

    destroy() {
      destroy self.pendingTransactions
    }

    pub fun AuthorizeBackendAccount(authorizedAddress: Address) {
      JoyridePayments.authorizedBackendAccounts[authorizedAddress] = true
    }

    pub fun DeAuthorizeBackendAccount(deauthorizedAddress: Address) {
      JoyridePayments.authorizedBackendAccounts.remove(key: deauthorizedAddress)
    }

    pub fun PlayerTransaction(playerID: String, tokenContext: String, amount: Fix64, gameID: String, txID: String, reward: Bool, notes: String) : Bool {
      if(self.pendingTransactions.containsKey(txID) || (JoyridePayments.transactionStore.containsKey(playerID) && JoyridePayments.transactionStore[playerID]![txID] != nil)) {
        emit TxFailed_DuplicateTxID(txID:txID,notes:notes)
        return false
      }

      if(amount < 0.0) {
        let debit = UFix64(amount * -1.0)
        let accountManager = JoyridePayments.accountsCapability!.borrow()
        if(accountManager == nil) {
            emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "DebitTX", notes: txID.concat(": JoyrideAccountsAdmin Accounts Capability Null"))
            return false
        }

        let vault <- accountManager!.EscrowWithdrawWithTnxId(playerID:playerID, txID: txID, amount:debit, tokenContext: tokenContext)
        if(vault == nil) {
          emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "DebitTX", notes: txID.concat(": player withdraw vault failed"))
          destroy vault
          return false
        }

        let tx <- create Transaction(vault: <- vault!, playerID: playerID, gameID: gameID, txID: txID)
        destroy <- self.pendingTransactions.insert(key: txID, <- tx)
        emit DebitTransactionCreate(playerID: playerID, txID: txID, tokenContext: tokenContext, amount: debit, gameID: gameID,  notes: notes)
      } else {
        let credit = UFix64(amount)
        let treasury = JoyridePayments.treasuryCapability!.borrow()
        if(treasury == nil) {
            emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "CreditTX", notes: txID.concat(": JoyrideMultiToken PlatformAdmin Capability Null"))
            return false
        }
        let vault <- treasury!.withdraw(vault: JoyrideMultiToken.Vaults.treasury, tokenContext: tokenContext, amount: credit, purpose: notes)
        if(vault == nil) {
          emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "CreditTX", notes: txID.concat(": Withdraw token vault from JoyrideMultiToken PlatformAdmin account is failed"))
          destroy vault
          return false
        } else {
          let undepositable <- JoyridePayments.accountsCapability!.borrow()!.PlayerDeposit(playerID: playerID, vault: <- vault!)
          if(undepositable != nil) {
            emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "CreditTX", notes: txID.concat(": Failed to deposit Admin Withdrawn vault in PlayerAccount"))
            treasury!.deposit(vault: JoyrideMultiToken.Vaults.treasury, from: <-undepositable!)
            return false
          } else {
            emit CreditTransactionCreate(playerID: playerID, txID: txID, tokenContext: tokenContext, amount: credit, gameID: gameID,  notes: "Vault Not Null")
            destroy undepositable
          }
        }
      }

      if(!JoyridePayments.transactionStore.containsKey(playerID)) {
        JoyridePayments.transactionStore[playerID] = {}
      }

      JoyridePayments.transactionStore[playerID]!.insert(key: txID, true)

      return true
    }

    pub fun FinalizeTransaction(txID: String, profit: UFix64): Bool {
        return self.FinalizeTransactionWithDevPercentage(txID: txID, profit: profit, devPercentage: 0.0)
    }

    pub fun FinalizeTransactionWithDevPercentage(txID: String, profit: UFix64, devPercentage: UFix64) : Bool {
      let tx <- self.pendingTransactions.remove(key: txID)
      if(tx == nil) {
        emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "FinalizeTX", notes: txID.concat(": Not found in pending debit transaction list"))
        destroy tx
        return false
      } else {
        let isFinalizeSuccess = tx?.Finalize(txID: txID, profit: profit, devPercentage: devPercentage)
        if(isFinalizeSuccess == true) {
         destroy tx
         return true
        } else {
         destroy <- self.pendingTransactions.insert(key: txID, <- tx!)
         return false
        }
      }
    }

    pub fun RefundTransaction(txID: String) : Bool {
      let tx <- self.pendingTransactions.remove(key: txID)
      if(tx == nil) {
        emit TxFailed_ByTxTypeAndTxID(txID: txID, txType: "RefundTX", notes: txID.concat(": Not found in pending debit transaction list"))
        destroy tx
        return false
      } else {
        let isRefundSuccess = tx?.Refund(txID: txID) // if this false then send vault back to pending transactino
        if (isRefundSuccess == true) {
          destroy tx
          return true
        } else {
         destroy <- self.pendingTransactions.insert(key: txID, <- tx!)
         return false
        }
      }
    }
  }

  pub struct PlayerTransactionData {
      pub var playerID: String
      pub var reward: Fix64
      pub var txID: String
      pub var rewardTokens: Bool
      pub var gameID: String
      pub var notes: String
      pub var tokenTransactionType: String
      pub var profit: UFix64
      pub var currencyTokenContext: String

      init(playerID: String, reward: Fix64, txID: String, rewardTokens: Bool, gameID: String, notes: String,
        tokenTransactionType: String, profit: UFix64, currencyTokenContext: String) {
          self.playerID = playerID
          self.reward = reward
          self.txID = txID
          self.rewardTokens = rewardTokens
          self.gameID = gameID
          self.notes = notes
          self.tokenTransactionType = tokenTransactionType
          self.profit = profit
          self.currencyTokenContext = currencyTokenContext
      }
    }

    pub struct PlayerTransactionDataWithDevPercentage {
        pub var playerID: String
        pub var reward: Fix64
        pub var txID: String
        pub var rewardTokens: Bool
        pub var gameID: String
        pub var notes: String
        pub var tokenTransactionType: String
        pub var profit: UFix64
        pub var currencyTokenContext: String
        pub var devPercentage: UFix64

        init(playerID: String, reward: Fix64, txID: String, rewardTokens: Bool, gameID: String, notes: String,
          tokenTransactionType: String, profit: UFix64, currencyTokenContext: String, devPercentage: UFix64) {
            self.playerID = playerID
            self.reward = reward
            self.txID = txID
            self.rewardTokens = rewardTokens
            self.gameID = gameID
            self.notes = notes
            self.tokenTransactionType = tokenTransactionType
            self.profit = profit
            self.currencyTokenContext = currencyTokenContext
            self.devPercentage = devPercentage
        }
    }

    pub struct FinalizeTransactionData {
      pub var txID: String
      pub var profit: UFix64

      init(txID: String, profit: UFix64) {
          self.txID = txID
          self.profit = profit
      }
    }

    pub struct RevertTransactionData {
      pub var txID: String

      init(txID: String) {
          self.txID = txID
      }
    }
}