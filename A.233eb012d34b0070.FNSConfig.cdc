
pub contract FNSConfig {

  access(self) var inboxFTWhitelist: {String: Bool}
  access(self) var inboxNFTWhitelist: {String: Bool}

  access(self) let _reservedFields: {String: AnyStruct}

  access(self) let rootDomainConfig: {String: {String: AnyStruct}}

  access(self) let userConfig: {Address: {String: AnyStruct}}

  access(self) let domainConfig: {String: {String: AnyStruct}}



  access(account) fun updateFTWhitelist(key: String, flag: Bool) {
    self.inboxFTWhitelist[key] = flag
  }

  access(account) fun updateNFTWhitelist(key: String, flag: Bool) {
    self.inboxNFTWhitelist[key] = flag
  }

  access(account) fun setFTWhitelist(_ val:{String: Bool}) {
    self.inboxFTWhitelist = val
  }

  access(account) fun setNFTWhitelist(_ val:{String: Bool}) {
    self.inboxNFTWhitelist = val
  }



  pub fun checkFTWhitelist(_ typeIdentifier: String) :Bool {
    return self.inboxFTWhitelist[typeIdentifier] ?? false
  }

   pub fun checkNFTWhitelist(_ typeIdentifier: String) :Bool {
    return self.inboxNFTWhitelist[typeIdentifier] ?? false
  }

  
  pub fun getWhitelist(_ type: String): {String: Bool} {
    if type == "NFT" {
      return self.inboxNFTWhitelist
    }
    return self.inboxFTWhitelist
  }


  init() {
    self.inboxFTWhitelist = {}
    self.inboxNFTWhitelist = {}
    self._reservedFields = {}
    self.rootDomainConfig = {}
    self.userConfig = {}
    self.domainConfig = {}
  }
}