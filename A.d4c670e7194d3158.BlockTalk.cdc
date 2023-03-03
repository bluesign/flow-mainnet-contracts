pub contract BlockTalk {

  pub let TalkCollectionStoragePath: StoragePath
  pub let TalkCollectionPublicPath: PublicPath

  pub event TalkCreated(id: UInt64)
  pub event TalkSaved(id: UInt64, owner: Address?)
  
  pub resource Talk {
    pub let id: UInt64

    pub var metadata: {String: String}

    init(body: String, tweetID: String?) {
      self.id = self.uuid

      if let _tweetID = tweetID {
        self.metadata = {
          "tweetId": _tweetID,
          "body": body
        }
      } else {
        self.metadata = {
          "body": body
        }
      }
    }
  }

  pub fun createTalk(body: String, tweetID: String?): @Talk {
    let newTalk: @Talk <- create Talk(body: body, tweetID: tweetID)
    emit TalkCreated(id: newTalk.id)
    return <- newTalk
  }

  pub resource interface CollectionPublic {
    pub fun getIDs(): [UInt64]
    pub fun borrowTalk(id: UInt64): &Talk?
  }

  pub resource Collection: CollectionPublic {
    pub var talks: @{UInt64: Talk}

    pub fun saveTalk(talk: @Talk) {
      emit TalkSaved(id: talk.id, owner: self.owner?.address)
      self.talks[talk.id] <-! talk
    }
    
    pub fun getIDs(): [UInt64] {
      return self.talks.keys
    }

    pub fun borrowTalk(id: UInt64): &Talk? {
      if self.talks[id] != nil {
        return (&self.talks[id] as &BlockTalk.Talk?)!
      }
      return nil
    }

    init() {
      self.talks <- {}
    }

    destroy () {
      destroy self.talks
    }
  }

  pub fun createEmptyCollection(): @Collection {
    return <- create Collection()
  }

  init() {
    self.TalkCollectionStoragePath = /storage/BlockTalkCollection
    self.TalkCollectionPublicPath = /public/BlockTalkCollection
    self.account.link<&{CollectionPublic}>(self.TalkCollectionPublicPath, target: self.TalkCollectionStoragePath)
  }
}
 