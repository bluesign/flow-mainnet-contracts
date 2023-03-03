import IStats from 0x9bcd6bb87052c775

access(all) contract Stats2: IStats  {
  pub let stats: {UInt64: String}

  // The init() function is required if the contract contains any fields.
  init() {
    self.stats = { 1: "Uno", 2: "Dos" }
  }
}
