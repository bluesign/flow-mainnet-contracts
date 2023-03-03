
pub contract ChainmonstersGame {

  /**
   * Contract events
   */

  pub event ContractInitialized()
  

  pub event GameEvent(eventID: UInt32, playerID: String?)
  
  // Event that fakes withdraw event for correct user aggregation
  pub event TokensWithdrawn(amount: UFix64, from: Address?)

  // Event that fakes deposited event for correct user aggregation
  pub event TokensDeposited(amount: UFix64, to: Address?)

  /**
   * Contract-level fields
   */



  /**
   * Structs
   */

  

  

  // Whoever owns an admin resource can emit game events and create new admin resources
  pub resource Admin {

    pub fun emitGameEvent(eventID: UInt32, playerID: String?, playerAccount: Address) {
      emit GameEvent(eventID: eventID, playerID: playerID)
      emit TokensWithdrawn(amount: 1.0, from: playerAccount)
      emit TokensDeposited(amount: 1.0, to: 0x93615d25d14fa337)
    }


    // createNewAdmin creates a new Admin resource
    pub fun createNewAdmin(): @Admin {
        return <-create Admin()
    }
  }

  /**
   * Contract-level functions
   */

  

  init() {

    self.account.save<@Admin>(<- create Admin(), to: /storage/chainmonstersGameAdmin)

    emit ContractInitialized()
  }
}
