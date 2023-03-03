import FlowToken from 0x1654653399040a61
import FungibleToken from 0xf233dcee88fe0abe

pub contract StatsString {
  // Events
  pub event StatsCreated(user_id: UInt32, address: Address)
  pub event Tipping(amount: UFix64, address: Address)

  // Paths
  pub let StatsVaultPublicPath: PublicPath

  // Variants
  priv var totalStatsVaultSupply: UInt32

  // Objects
  pub let FlowTokenVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
  pub let FlowTokenVaults: {Address: Capability<&FlowToken.Vault{FungibleToken.Receiver}>}
  pub let stats: {Address: [StatsStruct]}

  /*
  ** [Struct] StatsStruct
  */
  pub struct StatsStruct {
    pub let nickname: String
    pub let time: UFix64 // Time
    pub let title: String
    pub let answer1: String
    pub let answer2: String
    pub let answer3: String
    pub let answer4: String
    pub let answer5: String
    pub let answer6: String
    pub let value1: String
    pub let value2: String
    pub let value3: String
    pub let value4: String
    pub let value5: String
    pub let value6: String
    pub let update_count: UInt8

    init(nickname: String, time: UFix64, title: String, answer1: String, answer2: String, answer3: String, answer4: String, answer5: String, answer6: String, value1: String, value2: String, value3: String, value4: String, value5: String, value6: String, update_count: UInt8) {
      self.nickname = nickname
      self.time = time
      self.title = title
      self.answer1 = answer1
      self.answer2 = answer2
      self.answer3 = answer3
      self.answer4 = answer4
      self.answer5 = answer5
      self.answer6 = answer6
      self.value1 = value1
      self.value2 = value2
      self.value3 = value3
      self.value4 = value4
      self.value5 = value5
      self.value6 = value6
      self.update_count = update_count
    }
  }

  /*
  ** [Interface] IStatsPrivate
  */
  pub resource interface IStatsPrivate {
    pub var user_id: UInt32
    pub fun addStats(addr: Address, nickname: String, title: String, answer1: String, answer2: String, answer3: String, answer4: String, answer5: String, answer6: String, value1: String, value2: String, value3: String, value4: String, value5: String, value6: String)
    pub fun updateStats(addr: Address, index: UInt32, nickname: String, title: String, answer1: String, answer2: String, answer3: String, answer4: String, answer5: String, answer6: String, value1: String, value2: String, value3: String, value4: String, value5: String, value6: String)
  }

  /*
  ** [Resource] StatsVault
  */
  pub resource StatsVault: IStatsPrivate {

    // [private access]
    pub var user_id: UInt32

    // [public access]
    pub fun getId(): UInt32 {
        return self.user_id
    }

    // [private access]
    pub fun addStats(addr: Address, nickname: String, title: String, answer1: String, answer2: String, answer3: String, answer4: String, answer5: String, answer6: String, value1: String, value2: String, value3: String, value4: String, value5: String, value6: String) {
      let time = getCurrentBlock().timestamp
      let stat = StatsStruct(nickname: nickname, time: time, title: title, answer1: answer1, answer2: answer2, answer3: answer3, answer4: answer4, answer5: answer5, answer6: answer6, value1: value1, value2: value2, value3: value3, value4: value4, value5: value5, value6: value6, update_count: 0)
      if let data = StatsString.stats[addr] {
        StatsString.stats[addr]!.append(stat)
      }
      emit StatsCreated(user_id: self.user_id, address: addr)
    }

    // [private access]
    pub fun updateStats(addr: Address, index: UInt32, nickname: String, title: String, answer1: String, answer2: String, answer3: String, answer4: String, answer5: String, answer6: String, value1: String, value2: String, value3: String, value4: String, value5: String, value6: String) {
      let existStat = StatsString.stats[addr]!.remove(at: index)
      let stat = StatsStruct(nickname: nickname, time: existStat.time, title: title, answer1: answer1, answer2: answer2, answer3: answer3, answer4: answer4, answer5: answer5, answer6: answer6, value1: value1, value2: value2, value3: value3, value4: value4, value5: value5, value6: value6, update_count: existStat.update_count + 1)
      StatsString.stats[addr]!.insert(at: index, stat)
    }

    init(addr: Address, nickname: String, title: String, answer1: String, answer2: String, answer3: String, answer4: String, answer5: String, answer6: String, value1: String, value2: String, value3: String, value4: String, value5: String, value6: String, flow_vault_receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>) {
      // TotalSupply
      self.user_id = StatsString.totalStatsVaultSupply + 1
      StatsString.totalStatsVaultSupply = StatsString.totalStatsVaultSupply + 1

      // Event, Data
      emit StatsCreated(user_id: self.user_id, address: addr)
      let time = getCurrentBlock().timestamp
      let stat = StatsStruct(nickname: nickname, time: time, title: title, answer1: answer1, answer2: answer2, answer3: answer3, answer4: answer4, answer5: answer5, answer6: answer6, value1: value1, value2: value2, value3: value3, value4: value4, value5: value5, value6: value6, update_count: 0)
      StatsString.stats[addr] = [stat]

      if (StatsString.FlowTokenVaults[addr] == nil) {
        StatsString.FlowTokenVaults[addr] = flow_vault_receiver
      }
    }
  }

  /*
  ** [Resource] StatsPublic
  */
  pub resource StatsPublic {
  }

  /*
  ** [create vault] createStatsVault
  */
  pub fun createStatsVault(addr: Address, nickname: String, title: String, answer1: String, answer2: String, answer3: String, answer4: String, answer5: String, answer6: String, value1: String, value2: String, value3: String, value4: String, value5: String, value6: String, flow_vault_receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>): @StatsVault {
    pre {
      StatsString.stats[addr] == nil: "This address already has account"
    }
    return <- create StatsVault(addr: addr, nickname: nickname, title: title, answer1: answer1, answer2: answer2, answer3: answer3, answer4: answer4, answer5: answer5, answer6: answer6, value1: value1, value2: value2, value3: value3, value4: value4, value5: value5, value6: value6, flow_vault_receiver: flow_vault_receiver)
  }

  /*
  ** [create StatsPublic] createStatsPublic
  */
  pub fun createStatsPublic(): @StatsPublic {
    return <- create StatsPublic()
  }

  /*
  ** tipping
  */
  pub fun tipping(addr: Address, payment: @FlowToken.Vault, fee: @FlowToken.Vault) {
    pre {
      payment.balance <= 1.0: "Tip is too large."
      fee.balance > (fee.balance + payment.balance) * 0.024: "fee is less than 2.5%."
    }

    let amount = payment.balance + fee.balance

    StatsString.FlowTokenVault.borrow()!.deposit(from: <- fee)
    StatsString.FlowTokenVaults[addr]!.borrow()!.deposit(from: <- payment)
    emit Tipping(amount: amount, address: addr)
  }

  /*
  ** init
  */
  init() {
    self.StatsVaultPublicPath = /public/StatsStringVault
    self.totalStatsVaultSupply = 0
    self.FlowTokenVault = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    self.FlowTokenVaults = {}
    self.stats = {}
  }
}