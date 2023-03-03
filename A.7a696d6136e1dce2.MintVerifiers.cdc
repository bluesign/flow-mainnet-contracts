import FLOAT from 0x2d4c3caffbeab845
import EmeraldPass from 0x6a07dbeb03167a13

// Created by Emerald City DAO for Touchstone (https://touchstone.city/)

pub contract MintVerifiers {

  pub struct interface IVerifier {
		 pub let verifier: String
     pub let type: Type
     // A return value of nil means passing, otherwise
     // you return the error.
		 pub fun verify(_ params: {String: AnyStruct}): String?
	}

  pub struct SingularFLOAT: IVerifier {
    pub let verifier: String
    pub let type: Type
    pub let eventOwner: Address
    pub let eventId: UInt64
    pub let eventURL: String
    pub let eventCap: Capability<&FLOAT.FLOATEvents{FLOAT.FLOATEventsPublic}>

    pub fun verify(_ params: {String: AnyStruct}): String? {
      let minter: Address = params["minter"]! as! Address

      if let minterCollection = getAccount(minter).getCapability(FLOAT.FLOATCollectionPublicPath).borrow<&FLOAT.Collection{FLOAT.CollectionPublic}>() {
        if minterCollection.ownedIdsFromEvent(eventId: self.eventId).length <= 0 {
          return "The minter does not own a FLOAT from the required event."
        }
      } else {
        return "The minter does not have a FLOAT Collection set up."
      }
      
      return nil
    }

    init(_eventOwner: Address, _eventId: UInt64, _eventURL: String) {
      self.verifier = "Singular FLOAT"
      self.type = self.getType()
      self.eventOwner = _eventOwner
      self.eventId = _eventId
      self.eventURL = _eventURL
      self.eventCap = getAccount(_eventOwner).getCapability<&FLOAT.FLOATEvents{FLOAT.FLOATEventsPublic}>(FLOAT.FLOATEventsPublicPath)
      assert(self.eventCap.check(), message: "This is not a valid FLOAT Event.")
      assert(self.eventCap.borrow()!.getIDs().contains(_eventId), message: "This is not a valid eventId.")
    }
  }

  pub struct HasEmeraldPass: IVerifier {
    pub let verifier: String
    pub let type: Type

    pub fun verify(_ params: {String: AnyStruct}): String? {
      let minter: Address = params["minter"]! as! Address
      
      if !EmeraldPass.isActive(user: minter) {
        return "The minter does not have an active Emerald Pass subscription."
      }
      
      return nil
    }

    init() {
      self.verifier = "Has Emerald Pass"
      self.type = self.getType()
    }
  }

  pub fun checkPassing(verifiers: [{IVerifier}], params: {String: AnyStruct}): [Bool] {
    let answer: [Bool] = []
    for verifier in verifiers {
      answer.append(verifier.verify(params) == nil)
    }
    return answer
  }

}