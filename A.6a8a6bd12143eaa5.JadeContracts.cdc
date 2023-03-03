// Created by ethos multiverse inc. for Jade(https://jade.ethosnft.com/)

pub contract JadeContracts {

  pub let ContractsBookStoragePath: StoragePath
  pub let ContractsBookPublicPath: PublicPath
  pub let GlobalContractsBookStoragePath: StoragePath
  pub let GlobalContractsBookPublicPath: PublicPath

  pub enum ReservationStatus: UInt8 {
    pub case notFound
    pub case active 
  }

  pub resource interface ContractsBookPublic {
    pub fun getContracts (): [String]
  }

  pub resource ContractsBook: ContractsBookPublic {

    pub let contractNames: {String: Bool}

    init() {
      self.contractNames = {}
    }

    pub fun addContract(contractName: String) {
      pre {
        self.contractNames[contractName] == nil: "Contract already exists."
      }

      let me: Address = self.owner!.address
      self.contractNames[contractName] = true

      let globalContractsBook: &JadeContracts.GlobalContractsBook = JadeContracts.account.borrow<&GlobalContractsBook>(from: JadeContracts.GlobalContractsBookStoragePath)!
      let users: [Address] = globalContractsBook.getAllUsers()
      let containsAddress: Bool = users.contains(me)
      if !containsAddress {
        globalContractsBook.addUser(address: me)
      }
    }

    pub fun getContracts(): [String] {
      return self.contractNames.keys
    }

    pub fun removeContract(contractName: String) {
      self.contractNames.remove(key: contractName)
    }
  }

  pub resource interface GlobalContractsBookPublic {
    pub fun getAllUsers (): [Address]
    pub fun getAddressFromContractName(contractName: String): Address?
  }

  pub resource GlobalContractsBook: GlobalContractsBookPublic {

    pub let allUsers: {Address: Bool}
    pub let reservedContractNames: {String: Address}

    init() {
      self.allUsers = {}
      self.reservedContractNames = {}
    }

    pub fun addUser(address: Address) {
      pre {
        self.allUsers[address] == nil: "User already exists."
      }

      self.allUsers[address] = true
    }

    pub fun reserve(contractName: String, user: Address) {
    
      pre {
        self.getReservationStatus(contractName: contractName) != ReservationStatus.active: contractName.concat(" is already reserved.")
      }
      self.reservedContractNames[contractName] = user
    }

    pub fun removeReservation(contractName: String) {
      self.reservedContractNames.remove(key: contractName)
    }

    pub fun getAllReservations(): {String: Address} {
      return self.reservedContractNames
    }

    pub fun addContractName(contractName: String, address: Address) {
      pre {
        self.reservedContractNames[contractName] == nil: "Contract name already exists."
      }

      self.reservedContractNames[contractName] = address
    }

    pub fun getAllUsers(): [Address] {
      return self.allUsers.keys
    }

    pub fun getReservationStatus(contractName: String): ReservationStatus {
      if self.reservedContractNames[contractName] != nil {
        return ReservationStatus.active
      }
      return ReservationStatus.notFound
    }

    pub fun getAddressFromContractName(contractName: String): Address? {
      if self.getReservationStatus(contractName: contractName) == ReservationStatus.active {
        return self.reservedContractNames[contractName]!
      }
      return nil
    }
  }

  pub fun createContractsBook(): @ContractsBook {
    return <-create ContractsBook()
  }

  pub fun getUserJadeCollections(user: Address): [String] {
    let collections: &JadeContracts.ContractsBook{JadeContracts.ContractsBookPublic} = getAccount(user).getCapability(JadeContracts.ContractsBookPublicPath)
      .borrow<&JadeContracts.ContractsBook{JadeContracts.ContractsBookPublic}>()
      ?? panic("Could not borrow JadeContracts.ContractsBookPublic from user account")

    return collections.getContracts()
  }

  pub fun getGlobalContractsBook(): &GlobalContractsBook{GlobalContractsBookPublic} {
    return self.account.getCapability(JadeContracts.GlobalContractsBookPublicPath)
            .borrow<&GlobalContractsBook{GlobalContractsBookPublic}>()!
  }

  init() {
    self.ContractsBookStoragePath = /storage/JadeContractsBook
    self.ContractsBookPublicPath = /public/JadeContractsBook
    self.GlobalContractsBookStoragePath = /storage/JadeGlobalContractsBook
    self.GlobalContractsBookPublicPath = /public/JadeGlobalContractsBook

    self.account.save(<-create GlobalContractsBook(), to: JadeContracts.GlobalContractsBookStoragePath)
    self.account.link<&GlobalContractsBook{GlobalContractsBookPublic}>(JadeContracts.GlobalContractsBookPublicPath, target: JadeContracts.GlobalContractsBookStoragePath)
  }
}