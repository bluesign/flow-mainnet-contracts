import FlowToken from 0x1654653399040a61
import FungibleToken from 0xf233dcee88fe0abe

pub contract TicketsBeta {
  // Events
  pub event DispenserRequested(dispenser_id: UInt32, address: Address)
  pub event DispenserGranted(dispenser_id: UInt32, address: Address)
  pub event TicketRequested(dispenser_id: UInt32, user_id: UInt32, address: Address)
  pub event TicketUsed(dispenser_id: UInt32, user_id: UInt32, token_id: UInt64, address: Address, price: UFix64)
  pub event CrowdFunding(dispenser_id: UInt32, user_id: UInt32, address: Address, fund: UFix64)
  pub event Refund(dispenser_id: UInt32, user_id: UInt32, address: Address, amount: UFix64)

  // Paths
  pub let AdminPublicStoragePath: StoragePath
  pub let AdminPrivateStoragePath: StoragePath
  pub let AdminPublicPath: PublicPath
  pub let CapabilityReceiverVaultPublicPath: PublicPath
  pub let AdminPrivatePath: PrivatePath
  pub let DispenserVaultPublicPath: PublicPath
  pub let DispenserVaultPrivatePath: PrivatePath
  pub let TicketVaultPublicPath: PublicPath
  pub let TicketVaultPrivatePath: PrivatePath

  // Variants
  priv var totalDispenserVaultSupply: UInt32
  priv var totalTicketSupply: UInt64
  priv var totalTicketVaultSupply: UInt32
  priv var adminCapabilityHolder: Bool

  pub let FlowTokenVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
  pub let DispenserFlowTokenVault: {UInt32: Capability<&FlowToken.Vault{FungibleToken.Receiver}>}
  pub let UserFlowTokenVault: {UInt32: Capability<&FlowToken.Vault{FungibleToken.Receiver}>}

  // Objects
  priv let dispenserOwners: {UInt32: DispenserStruct}
  priv let ticketInfo: [TicketStruct]
  priv let ticketRequesters: {UInt32: {UInt32: RequestStruct}}

  /*
  ** [Struct]DispenserStruct
  */
  pub struct DispenserStruct {
    access(contract) let dispenser_id: UInt32
    access(contract) let address: Address
    access(contract) let domain: String
    priv let description: String
    priv let paid: UFix64
    pub(set) var grant: Bool

    init(dispenser_id: UInt32, address: Address, domain: String, description: String, paid: UFix64, grant: Bool) {
      self.address = address
      self.dispenser_id = dispenser_id
      self.domain = domain
      self.description = description
      self.paid = paid
      self.grant = grant
    }
  }

  /*
  ** [Struct]　TicketStruct
  */
  pub struct TicketStruct {
    access(contract) let dispenser_id: UInt32
    priv let domain: String
    priv let type: UInt8
    priv let name: String
    priv let where_to_use: String
    priv let when_to_use: String
    priv let price: UFix64

    init(dispenser_id: UInt32, domain: String, type: UInt8, name: String, where_to_use: String, when_to_use: String, price: UFix64) {
      self.dispenser_id = dispenser_id
      self.domain = domain
      self.type = type
      self.name = name
      self.where_to_use = where_to_use
      self.when_to_use = when_to_use
      self.price = price
    }
  } 

  /*
  ** [Struct] RequestStruct
  */
  pub struct RequestStruct {
    pub let user_id: UInt32
    pub let address: Address
    pub(set) var latest_token: UInt64?
    pub(set) var time: UFix64 // Time
    pub(set) var count: UInt8
    pub(set) var paid: UFix64
    pub let crowdfunding: Bool

    init(time: UFix64, user_id: UInt32, address: Address, crowdfunding: Bool) {
      self.user_id = user_id
      self.address = address
      self.latest_token = nil
      self.time = time
      self.count = 1
      self.paid = 0.0
      self.crowdfunding = crowdfunding
    }
  }

  /*
  ** [Resource] Admin
  */
  pub resource Admin {
  
    pub fun mintDispenser(dispenser_id: UInt32, address: Address): @Dispenser {
      pre {
        TicketsBeta.dispenserOwners[dispenser_id] != nil : "Requested address is not in previously requested list."
        TicketsBeta.dispenserOwners[dispenser_id]!.grant == false : "Requested address is already minted."
      }
      if let data = TicketsBeta.dispenserOwners[dispenser_id] {
        data.grant = true
        TicketsBeta.dispenserOwners[dispenser_id] = data
      }
      emit DispenserGranted(dispenser_id: dispenser_id, address: address)
      return <- create Dispenser()
    }

    init() {
    }
  }

  /*
  ** [Resource] AdminPublic
  */
  pub resource AdminPublic {
    // [public access]
    pub fun getDispenserRequesters(): [DispenserStruct] {
      var dispenserArr: [DispenserStruct] = []
      for data in TicketsBeta.dispenserOwners.values {
        if (data.grant == false) {
          dispenserArr.append(data)
        }
      }

      return dispenserArr
    }

    // [public access]
    pub fun getAllDispensers(): [DispenserStruct] {
      var dispenserArr: [DispenserStruct] = []
      for data in TicketsBeta.dispenserOwners.values {
        dispenserArr.append(data)
      }

      return dispenserArr
    }

    init() {
    }

    // [public access]
    pub fun getTicketRequesters(dispenser_id: UInt32): {UInt32: RequestStruct}? {
      return TicketsBeta.ticketRequesters[dispenser_id]
    }
  }

  /*
  ** [Interface] IDispenserPublic
  */
  pub resource interface IProxyCapabilityReceiverPublic {
    pub fun deposit(cap: Capability<&Admin>)
  }

  /*
  ** [Resource] CapabilityReceiverVault
  */
  pub resource CapabilityReceiverVault: IProxyCapabilityReceiverPublic {
  
    // [private access]
    pub var proxyCapabilityReceiver: Capability<&Admin>?

    // [public access]
    pub fun deposit(cap: Capability<&Admin>) {
      pre {
        TicketsBeta.adminCapabilityHolder == false : "Admin capability vault is already assigned."
      }
      if (self.proxyCapabilityReceiver == nil) {
        self.proxyCapabilityReceiver = cap
        TicketsBeta.adminCapabilityHolder = true
      }
    }

    init() {
      self.proxyCapabilityReceiver = nil
    }
  }

  /*
  ** [create vault] createCapabilityReceiverVault
  */
  pub fun createCapabilityReceiverVault(): @CapabilityReceiverVault {
    return <- create CapabilityReceiverVault()
  }

  /*
  ** [Resource] Dispenser
  */
  pub resource Dispenser {

    priv var last_token_id: UInt64

    pub fun getLatestMintedTokenId(): UInt64 {
      return self.last_token_id
    }

    pub fun mintTicket(secret_code: String, dispenser_id: UInt32, user_id: UInt32): @Ticket {
      let token <- create Ticket(secret_code: secret_code, dispenser_id: dispenser_id)
      if(TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![user_id] {
          let ref = &TicketsBeta.ticketRequesters[dispenser_id]![user_id]! as &RequestStruct
          ref.latest_token = token.getId()
          self.last_token_id = token.getId()
        }
      }
      return <- token
    }

    pub fun addTicketInfo(dispenser_id: UInt32, type: UInt8, name: String, where_to_use: String, when_to_use: String, price: UFix64, flow_vault_receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>) {
      let domain = TicketsBeta.dispenserOwners[dispenser_id]!.domain
      let ticket = TicketStruct(dispenser_id: dispenser_id, domain: domain, type: type, name: name, where_to_use: where_to_use, when_to_use: when_to_use, price: price)
      TicketsBeta.ticketInfo.append(ticket)
      if (TicketsBeta.DispenserFlowTokenVault[dispenser_id] == nil) {
        TicketsBeta.DispenserFlowTokenVault[dispenser_id] = flow_vault_receiver
      }
    }

    pub fun updateTicketInfo(index: UInt32, dispenser_id: UInt32, type: UInt8, name: String, where_to_use: String, when_to_use: String, price: UFix64) {
      let domain = TicketsBeta.dispenserOwners[dispenser_id]!.domain
      let ticket = TicketStruct(dispenser_id: dispenser_id, domain: domain, type: type, name: name, where_to_use: where_to_use, when_to_use: when_to_use, price: price)
      let existTicket = TicketsBeta.ticketInfo.remove(at: index)
      if (existTicket.dispenser_id == dispenser_id) {
        TicketsBeta.ticketInfo.insert(at: index, ticket)
      } else {
        panic("Something is not going right.")
      }
    }

    init() {
      self.last_token_id = 0
    }
  }

  /*
  ** [Interface] IDispenserPrivate
  */
  pub resource interface IDispenserPrivate {
    pub var ownedDispenser: @Dispenser?
    pub var dispenser_id: UInt32
    pub fun addTicketInfo(type: UInt8, name: String, where_to_use: String, when_to_use: String, price: UFix64, flow_vault_receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>)
    pub fun updateTicketInfo(index: UInt32, type: UInt8, name: String, where_to_use: String, when_to_use: String, price: UFix64)
  }

  /*
  ** [Interface] IDispenserPublic
  */
  pub resource interface IDispenserPublic {
    pub fun deposit(minter: @Dispenser)
    pub fun hasDispenser(): Bool
    pub fun getId(): UInt32
    pub fun getTicketRequesters(): {UInt32: RequestStruct}?
    pub fun getLatestMintedTokenId(): UInt64?
  }

  /*
  ** [Resource] DispenserVault
  */
  pub resource DispenserVault: IDispenserPrivate, IDispenserPublic {

    // [private access]
    pub var ownedDispenser: @Dispenser?

    // [private access]
    pub var dispenser_id: UInt32

    // [public access]
    pub fun deposit(minter: @Dispenser) {
      if (self.ownedDispenser == nil) {
        self.ownedDispenser <-! minter
      } else {
        destroy minter
      }
    }

    // [public access]
    pub fun hasDispenser(): Bool {
      if (self.ownedDispenser != nil) {
        return true
      } else {
        return false
      }
    }

    // [public access]
    pub fun getId(): UInt32 {
        return self.dispenser_id
    }

    // [public access]
    pub fun getTicketRequesters(): {UInt32: RequestStruct}? {
      return TicketsBeta.ticketRequesters[self.dispenser_id]
    }

    // [public access]
    pub fun getLatestMintedTokenId(): UInt64? {
      return self.ownedDispenser?.getLatestMintedTokenId()
    }

    // [private access]
    pub fun addTicketInfo(type: UInt8, name: String, where_to_use: String, when_to_use: String, price: UFix64, flow_vault_receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>) {
      self.ownedDispenser?.addTicketInfo(dispenser_id: self.dispenser_id, type: type, name: name, where_to_use: where_to_use, when_to_use: when_to_use, price: price, flow_vault_receiver: flow_vault_receiver)
    }

    // [private access]
    pub fun updateTicketInfo(index: UInt32, type: UInt8, name: String, where_to_use: String, when_to_use: String, price: UFix64) {
      self.ownedDispenser?.updateTicketInfo(index: index, dispenser_id: self.dispenser_id, type: type, name: name, where_to_use: where_to_use, when_to_use: when_to_use, price: price)
    }

    // [private access]
    pub fun mintTicket(secret_code: String, user_id: UInt32): @Ticket? {
      return <- self.ownedDispenser?.mintTicket(secret_code: secret_code, dispenser_id: self.dispenser_id, user_id: user_id)
    }

    // [private access]
    pub fun refund(dispenser_id: UInt32, address: Address, user_id: UInt32, repayment: @FlowToken.Vault) {
      pre {
        repayment.balance > 0.0: "refund is not set."
        TicketsBeta.UserFlowTokenVault[user_id] != nil: "The beneficiary has not yet set up the Vault."
        TicketsBeta.ticketRequesters.containsKey(dispenser_id): "Sender has not right to refund."
        TicketsBeta.ticketRequesters[dispenser_id]!.containsKey(user_id): "Sender has not right to refund."
        TicketsBeta.ticketRequesters[dispenser_id]![user_id]!.paid >= repayment.balance: "refund is larger than paid amount."
      }

      let fund: UFix64 = repayment.balance
      if(TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![user_id] {
          let ref = &TicketsBeta.ticketRequesters[dispenser_id]![user_id]! as &RequestStruct
          ref.paid = data.paid - fund // refund
        }
      }
      TicketsBeta.UserFlowTokenVault[user_id]!.borrow()!.deposit(from: <- repayment)
      emit Refund(dispenser_id: dispenser_id, user_id: user_id, address: address, amount: fund)
    }

    destroy() {
      destroy self.ownedDispenser
    }

    init(_ address: Address, _ domain: String, _ description: String, _ paid: UFix64) {
      // TotalSupply
      self.dispenser_id = TicketsBeta.totalDispenserVaultSupply + 1
      TicketsBeta.totalDispenserVaultSupply = TicketsBeta.totalDispenserVaultSupply + 1

      // Event, Data
      emit DispenserRequested(dispenser_id: self.dispenser_id, address: address)
      self.ownedDispenser <- nil
      TicketsBeta.dispenserOwners[self.dispenser_id] = DispenserStruct(dispenser_id: self.dispenser_id, address: address, domain: domain, description: description, paid: paid, grant: false)
    }
  }

  /*
  ** [create vault] createDispenserVault
  */
  pub fun createDispenserVault(address: Address, domain: String, description: String, payment: @FlowToken.Vault): @DispenserVault {
    pre {
      payment.balance >= 0.3: "Payment is not sufficient"
    }
    let paid: UFix64 = payment.balance
    TicketsBeta.FlowTokenVault.borrow()!.deposit(from: <- payment)
    return <- create DispenserVault(address, domain, description, paid)
  }

  /*
  ** [Resource] Ticket
  */
  pub resource Ticket {
    priv let token_id: UInt64
    priv let dispenser_id: UInt32
    priv let secret_code: String
    priv var readable_code: String
    priv var price: UFix64
    priv var used_time: UFix64?
    priv var created_time: UFix64

    pub fun getId(): UInt64 {
      return self.token_id
    }

    pub fun getCode(): String {
      return self.readable_code
    }

    pub fun getUsedTime(): UFix64? {
      return self.used_time
    }

    pub fun getCreatedTime(): UFix64 {
      return self.created_time
    }

    pub fun useTicket(price: UFix64) {
      pre {
        self.readable_code == "": "Something went wrong."
      }
      self.readable_code = self.secret_code
      self.price = price
      self.used_time = getCurrentBlock().timestamp
    }

    pub fun useCrowdfundingTicket() {
      pre {
        self.readable_code == "": "Something went wrong."
      }
      self.readable_code = self.secret_code
      self.used_time = getCurrentBlock().timestamp
    }

    init(secret_code: String, dispenser_id: UInt32) {
      // TotalSupply
      self.token_id = TicketsBeta.totalTicketSupply + 1
      TicketsBeta.totalTicketSupply = TicketsBeta.totalTicketSupply + 1

      // Event, Data
      self.dispenser_id = dispenser_id
      self.secret_code = secret_code // チケット名称
      self.readable_code = "" // チケット枚数
      self.price = 0.0
      self.used_time = nil
      self.created_time = getCurrentBlock().timestamp
    }
  }

  /*
  ** [Interface] ITicketPrivate
  */
  pub resource interface ITicketPrivate {
    access(contract) var ownedTicket: @{UInt64: Ticket}
    pub fun requestTicket(dispenser_id: UInt32, address: Address)
    pub fun useTicket(dispenser_id: UInt32, token_id: UInt64, address: Address, payment: @FlowToken.Vault, fee: @FlowToken.Vault)
    pub fun prepareCrowdfund(dispenser_id: UInt32, address: Address)
    pub fun crowdfunding(dispenser_id: UInt32, address: Address, payment: @FlowToken.Vault, fee: @FlowToken.Vault)
  }

  /*
  ** [Interface] ITicketPublic
  */
  pub resource interface ITicketPublic {
    pub fun deposit(token: @Ticket)
    pub fun getId(): UInt32
    pub fun getCode(dispenser_id: UInt32): {UInt64: String}?
    pub fun getUsedTime(dispenser_id: UInt32): {UInt64: UFix64??}?
    pub fun getCreatedTime(dispenser_id: UInt32): {UInt64: UFix64?}?
  }

  /*
  ** [Ticket Vault] TicketVault
  */
  pub resource TicketVault: ITicketPrivate, ITicketPublic {

    priv var user_id: UInt32
    access(contract) var ownedTicket: @{UInt64: Ticket}
    access(contract) var contribution: [UInt32]

    // [public access]
    pub fun deposit(token: @Ticket) {
      pre {
        self.ownedTicket[token.getId()] == nil : "You have same ticket."
      }
      self.ownedTicket[token.getId()] <-! token
    }

    // [public access]
    pub fun getId(): UInt32 {
        return self.user_id
    }

    // [public access]
    pub fun getCode(dispenser_id: UInt32): {UInt64: String}? {
      if(TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![self.user_id] {
          if (data.latest_token == nil) {
            return nil
          }
          let token_id = data.latest_token!
          return {token_id: self.ownedTicket[token_id]?.getCode()!}
        }
      }
      return nil
    }

    // [public access]
    pub fun getUsedTime(dispenser_id: UInt32): {UInt64: UFix64??}? {
      if(TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![self.user_id] {
          if (data.latest_token == nil) {
            return nil
          }
          let token_id = data.latest_token!
          return {token_id: self.ownedTicket[token_id]?.getUsedTime()}
        }
      }
      return nil
    }

    // [public access]
    pub fun getCreatedTime(dispenser_id: UInt32): {UInt64: UFix64?}? {
      if(TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![self.user_id] {
          if (data.latest_token == nil) {
            return nil
          }
          let token_id = data.latest_token!
          return {token_id: self.ownedTicket[token_id]?.getCreatedTime()}
        }
      }
      return nil
    }

    // [private access]
    pub fun requestTicket(dispenser_id: UInt32, address: Address) {
      let time = getCurrentBlock().timestamp
      if (TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![self.user_id] {
          let ref = &TicketsBeta.ticketRequesters[dispenser_id]![self.user_id]! as &RequestStruct
          ref.count = data.count + 1
          ref.time = time
          ref.latest_token = nil

          emit TicketRequested(dispenser_id: dispenser_id, user_id: self.user_id, address: address)
        } else {
          let requestStruct = RequestStruct(time: time, user_id: self.user_id, address: address, crowdfunding: false)
          if let data = TicketsBeta.ticketRequesters[dispenser_id] {
            data[self.user_id] = requestStruct
            TicketsBeta.ticketRequesters[dispenser_id] = data
          }
        }
      } else {
        let requestStruct = RequestStruct(time: time, user_id: self.user_id, address: address, crowdfunding: false)
        TicketsBeta.ticketRequesters[dispenser_id] = {self.user_id: requestStruct}
      }
    }

    // [private access]
    pub fun useTicket(dispenser_id: UInt32, token_id: UInt64, address: Address, payment: @FlowToken.Vault, fee: @FlowToken.Vault) {
      pre {
        fee.balance > (fee.balance + payment.balance) * 0.024: "fee is less than 2.5%."
        TicketsBeta.DispenserFlowTokenVault[dispenser_id] != nil: "Receiver is not set."
        TicketsBeta.ticketRequesters.containsKey(dispenser_id): "Ticket is not requested."
        TicketsBeta.ticketRequesters[dispenser_id]![self.user_id]!.crowdfunding == false : "crowdfunding cannot use ticket with fee."
      }

      let price: UFix64 = payment.balance + fee.balance
      if(TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![self.user_id] {
          let ref = &TicketsBeta.ticketRequesters[dispenser_id]![self.user_id]! as &RequestStruct
          ref.paid = data.paid + price
        }
      }
      self.ownedTicket[token_id]?.useTicket(price: price)
      TicketsBeta.FlowTokenVault.borrow()!.deposit(from: <- fee)
      TicketsBeta.DispenserFlowTokenVault[dispenser_id]!.borrow()!.deposit(from: <- payment)
      emit TicketUsed(dispenser_id: dispenser_id, user_id: self.user_id, token_id: token_id, address: address, price: price)
    }

    // [private access]
    pub fun prepareCrowdfund(dispenser_id: UInt32, address: Address) {
      let time = getCurrentBlock().timestamp
      if (!TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        let requestStruct = RequestStruct(time: time, user_id: self.user_id, address: address, crowdfunding: true)
        TicketsBeta.ticketRequesters[dispenser_id] = {self.user_id: requestStruct}
      } else {
        if let data = TicketsBeta.ticketRequesters[dispenser_id] {
          if (!data.containsKey(self.user_id)) {
            let requestStruct = RequestStruct(time: time, user_id: self.user_id, address: address, crowdfunding: true)
            data[self.user_id] = requestStruct
            TicketsBeta.ticketRequesters[dispenser_id] = data
          }
        }
      }
    }

    // [private access]
    pub fun crowdfunding(dispenser_id: UInt32, address: Address, payment: @FlowToken.Vault, fee: @FlowToken.Vault) {
      pre {
        fee.balance > (fee.balance + payment.balance) * 0.024: "fee is less than 2.5%."
        TicketsBeta.DispenserFlowTokenVault[dispenser_id] != nil: "Receiver is not set."
        TicketsBeta.ticketRequesters.containsKey(dispenser_id): "crowdfunding registration info is not set."
        TicketsBeta.ticketRequesters[dispenser_id]![self.user_id]!.crowdfunding == true : "this ticket requester is not asking crowdfunding."
      }

      let fund: UFix64 = payment.balance + fee.balance
      if(TicketsBeta.ticketRequesters.containsKey(dispenser_id)) {
        if let data = TicketsBeta.ticketRequesters[dispenser_id]![self.user_id] {
          let ref = &TicketsBeta.ticketRequesters[dispenser_id]![self.user_id]! as &RequestStruct
          ref.paid = data.paid + fund
        }
      }
      TicketsBeta.FlowTokenVault.borrow()!.deposit(from: <- fee)
      TicketsBeta.DispenserFlowTokenVault[dispenser_id]!.borrow()!.deposit(from: <- payment)
      emit CrowdFunding(dispenser_id: dispenser_id, user_id: self.user_id, address: address, fund: fund)
      self.contribution.append(dispenser_id)
    }

    pub fun setRefundVault(flow_vault_receiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>) {
      pre {
        TicketsBeta.UserFlowTokenVault[self.user_id] == nil: "You have already requested a refund once."
      }

      if (TicketsBeta.UserFlowTokenVault[self.user_id] == nil) {
        TicketsBeta.UserFlowTokenVault[self.user_id] = flow_vault_receiver
      }
    }

    // [private access]
    pub fun useCrowdfundingTicket(dispenser_id: UInt32, token_id: UInt64, address: Address) {
      pre {
        TicketsBeta.DispenserFlowTokenVault[dispenser_id] != nil: "Receiver is not set."
        TicketsBeta.ticketRequesters.containsKey(dispenser_id): "Ticket is not requested."
        TicketsBeta.ticketRequesters[dispenser_id]![self.user_id]!.crowdfunding == true : "this ticket is not for crowdfunding."
      }

      self.ownedTicket[token_id]?.useCrowdfundingTicket()
      emit TicketUsed(dispenser_id: dispenser_id, user_id: self.user_id, token_id: token_id, address: address, price: 0.0)
    }

    destroy() {
      destroy self.ownedTicket
    }

    init(_ dispenser_id: UInt32, _ address: Address, _ crowdfunding: Bool) {
      // TotalSupply
      self.user_id = TicketsBeta.totalTicketVaultSupply + 1
      TicketsBeta.totalTicketVaultSupply = TicketsBeta.totalTicketVaultSupply + 1

      // Event, Data
      self.ownedTicket <- {}
      self.contribution = []
      let time = getCurrentBlock().timestamp
      let requestStruct = RequestStruct(time: time, user_id: self.user_id, address: address, crowdfunding: crowdfunding)
      if let data = TicketsBeta.ticketRequesters[dispenser_id] {
        data[self.user_id] = requestStruct
        TicketsBeta.ticketRequesters[dispenser_id] = data
      } else {
        TicketsBeta.ticketRequesters[dispenser_id] = {self.user_id: requestStruct}
      }
      emit TicketRequested(dispenser_id: dispenser_id, user_id: self.user_id, address: address)
    }
  }

  /*
  ** [create vault] createTicketVault
  */
  pub fun createTicketVault(dispenser_id: UInt32, address: Address, crowdfunding: Bool): @TicketVault {
    return <- create TicketVault(dispenser_id, address, crowdfunding)
  }

  /*
  ** [Public Function] getDispenserDomains
  */
  pub fun getDispenserDomains(): [String] {
    var dispenserArr: [String] = []
    for data in TicketsBeta.dispenserOwners.values {
      dispenserArr.append(data.domain)
    }
    return dispenserArr
  }

  /*
  ** [Public Function] getDispenserInfo
  */
  pub fun getDispenserInfo(address: Address): {UInt32: String}? {
    var dispenserArr: [DispenserStruct] = []
    for data in TicketsBeta.dispenserOwners.values {
      if (data.address == address) {
        return {data.dispenser_id: data.domain}
      }
    }
    return nil
  }

  /*
  ** [Public Function] getTickets
  */
  pub fun getTickets(): [TicketStruct] {
    return TicketsBeta.ticketInfo
  }

  /*
  ** [Public Function] getTicketRequestStatus
  */
  pub fun getTicketRequestStatus(dispenser_id: UInt32, user_id: UInt32): RequestStruct? {
    return TicketsBeta.ticketRequesters[dispenser_id]![user_id]
  }

  /*
  ** [Public Function] isSetRefundVault
  */
  pub fun isSetRefundVault(user_id: UInt32): Bool {
    return TicketsBeta.UserFlowTokenVault[user_id] != nil
  }

  /*
  ** init
  */
  init() {
    self.AdminPrivateStoragePath = /storage/TicketsBetaAdmin
    self.AdminPublicStoragePath = /storage/TicketsBetaAdminPublic
    self.AdminPublicPath = /public/TicketsBetaAdminPublic
    self.CapabilityReceiverVaultPublicPath = /public/TicketsBetaCapabilityReceiverVault
    self.DispenserVaultPublicPath = /public/TicketsBetaDispenserVault
    self.TicketVaultPublicPath = /public/TicketsBetaVault
    self.AdminPrivatePath = /private/TicketsBetaAdmin
    self.DispenserVaultPrivatePath = /private/TicketsBetaDispenserVault
    self.TicketVaultPrivatePath = /private/TicketsBetaVault
    self.totalDispenserVaultSupply = 0
    self.totalTicketSupply = 0
    self.totalTicketVaultSupply = 0
    self.adminCapabilityHolder = false
    self.dispenserOwners = {}
    self.ticketRequesters = {}
    self.ticketInfo = []

    self.FlowTokenVault = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    self.DispenserFlowTokenVault = {}
    self.UserFlowTokenVault = {}

    // grant admin resource and link capability receiver
    self.account.save<@TicketsBeta.Admin>( <- create Admin(), to: self.AdminPrivateStoragePath)
    self.account.link<&TicketsBeta.Admin>(self.AdminPrivatePath, target: self.AdminPrivateStoragePath)
    self.account.save<@TicketsBeta.AdminPublic>(<- create AdminPublic(), to: self.AdminPublicStoragePath)
    self.account.link<&TicketsBeta.AdminPublic>(self.AdminPublicPath, target: self.AdminPublicStoragePath)
  }
}