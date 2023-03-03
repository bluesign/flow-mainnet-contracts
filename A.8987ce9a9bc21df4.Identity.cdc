pub contract Identity {
  pub event DelegationAdded(chainId: UInt8, operator: String, caller: Address?)

  pub let DelegationStoragePath: StoragePath
  pub let DelegationPublicPath: PublicPath
  pub var AddressesLookup: {String: { Address: Bool } }

  pub enum CHAINS: UInt8 {
    pub case EVM
    pub case FLOW
    pub case BSC
    pub case TRON
  }

  pub resource Delegation {
    pub let chainId: CHAINS
    pub let address: String


    // We set the Chain id of the address
    init(chainId: CHAINS, address: String) {
        self.chainId = chainId
        self.address = address
    }
  }

  pub resource interface DelegationsPublic {
    pub fun getDelegatedChains(): [CHAINS]
    pub fun getDelegation(chainId: CHAINS): &Delegation?
  }

  // Resource that contains functions to set and get delegations
  pub resource Delegations: DelegationsPublic {
    pub var delegations: @{CHAINS: Delegation}

    pub fun set(
     chainId: UInt8,
     address: String
  ) {
    let formattedAddress = address.toLower()

    var newDelegation <- create Delegation(chainId: Identity.CHAINS(rawInput: chainId) ?? panic ("Invalid chain"), address: formattedAddress)

    let lookups = Identity.AddressesLookup[formattedAddress]
    if (lookups != nil) {
      let lookup = lookups![self.owner!.address]
      if (lookup == nil) {
        lookups!.insert(key: self.owner!.address, true)
        Identity.AddressesLookup.insert(key: formattedAddress, lookups!)
      }
    } else {
      var lookups: { Address: Bool } = {}
      lookups.insert(key: self.owner!.address, true)
      Identity.AddressesLookup.insert(key: formattedAddress, lookups)
    }

    var oldDelegation = self.getDelegation(chainId: Identity.CHAINS(rawInput:chainId)  ?? panic ("Invalid chain"))
    if (oldDelegation != nil) {
      let lookupsToRemove = Identity.AddressesLookup[oldDelegation!.address]
      lookupsToRemove!.remove(key: self.owner!.address)

      if (lookupsToRemove!.length == 0) {
         Identity.AddressesLookup.remove(key: oldDelegation!.address)
      } else {
        Identity.AddressesLookup[oldDelegation!.address] = lookupsToRemove
      }
    }


     let oldDelegation2 <- self.delegations[newDelegation.chainId] <- newDelegation

      destroy oldDelegation2
   }

    pub fun getDelegatedChains(): [CHAINS] {
      return self.delegations.keys
    }

    pub fun getDelegation(chainId: CHAINS): &Delegation? {
      return &self.delegations[chainId] as &Delegation?
    }

    init() {
      self.delegations <- {}
    }

    destroy () {
      destroy self.delegations
    }
  }

  pub fun createDelegations(): @Delegations {
    return <- create Delegations()
  }

  pub fun getLookupsKeys(): [String] {
    return self.AddressesLookup.keys
  }

  pub fun getLookupsByDelegatedAddress(address: String): { Address: Bool }?  {
    return self.AddressesLookup[address]
  }

  init() {
    self.DelegationStoragePath = /storage/Identity_v2
    self.DelegationPublicPath = /public/Identity_v2
    self.AddressesLookup = {}

     // Create a Collection for the deployer
    let delegations <- create Delegations()
    self.account.save(<-delegations, to: self.DelegationStoragePath)

    self.account.link<&Identity.Delegations{Identity.DelegationsPublic}>(
      self.DelegationPublicPath,
      target: self.DelegationStoragePath
    )
  }
}
