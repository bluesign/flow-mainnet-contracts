pub contract Messages {
  // Events
  pub event MessageCreated(user_id: UInt32, address: Address)

  // Paths
  pub let TicketsCommentVaultPublicPath: PublicPath

  // Variants
  priv var totalMessagesIds: UInt256

  // Objects
  pub let messages: {Address: MessagesStruct}

  /*
  ** [Struct] MessagesStruct
  */
  pub struct MessagesStruct {
    pub(set) var upvote_tickets: [Address]
    pub(set) var commented_ids: [UInt256]
    pub(set) var got_comments: [CommentsStruct]
    pub(set) var got_upvote: Int256

    init(addr: Address, ticket_addr: Address?, comment: String, is_comment: Bool, message_id: UInt256?, is_organizer: Bool) {
      if (is_organizer == true) {
        self.upvote_tickets = []
        self.commented_ids = []
      } else if (is_comment == true) {
        self.upvote_tickets = []
        self.commented_ids = [message_id!]
      } else {
        self.upvote_tickets = [ticket_addr!]
        self.commented_ids = []
      }
      self.got_comments = []
      self.got_upvote = 0
    }
  }

  /*
  ** [Struct] CommentsStruct
  */
  pub struct CommentsStruct {
    pub let comment: String
    pub let time: UFix64 // Time
    pub let message_id: UInt256

    init(comment: String, time: UFix64) {
      self.message_id = Messages.totalMessagesIds + 1
      Messages.totalMessagesIds = Messages.totalMessagesIds + 1
      self.comment = comment
      self.time = time
    }
  }

  /*
  ** [Interface] IMessagesPrivate
  */
  pub resource interface IMessagesPrivate {
    pub fun addMessages(addr: Address, ticket_addr: Address, comment: String, is_comment: Bool)
    pub fun updateMessages(addr: Address, ticket_addr: Address, index: UInt32, comment: String, is_comment: Bool)
  }

  /*
  ** [Resource] MessagesVault
  */
  pub resource MessagesVault: IMessagesPrivate {

    // [private access]
    pub fun addMessages(addr: Address, ticket_addr: Address, comment: String, is_comment: Bool) {
      let time = getCurrentBlock().timestamp
      var commentSt: CommentsStruct? = nil

      if let data = Messages.messages[addr] {
        // User
        if (is_comment == true) {
          commentSt = CommentsStruct(comment: comment, time: time)
          Messages.messages[addr]!.commented_ids.append(commentSt!.message_id)
        } else {
          Messages.messages[addr]!.upvote_tickets.append(ticket_addr)
        }

        // Organizer
        if let data = Messages.messages[ticket_addr] {
          if (is_comment == true) {
            data.got_comments.append(commentSt!)
          } else {
            data.got_upvote = data.got_upvote + 1
          }
          Messages.messages[ticket_addr] = data
        } else {
          let message = MessagesStruct(addr: ticket_addr, ticket_addr: nil, comment: comment, is_comment: is_comment, message_id: nil, is_organizer: false)
          if (is_comment == true) {
            message.got_comments.append(commentSt!)
          } else {
            message.got_upvote = 1
          }
          Messages.messages[ticket_addr] = message
        }
      }
    }

    // [private access]
    pub fun updateMessages(addr: Address, ticket_addr: Address, index: UInt32, comment: String, is_comment: Bool) {
      if let data = Messages.messages[addr] {
        if (is_comment == true) {
            // Organizer
            let existComment = Messages.messages[ticket_addr]!.got_comments.remove(at: index)
            let newComment = CommentsStruct(comment: comment, time: existComment.time)
            Messages.messages[ticket_addr]!.got_comments.insert(at: index, newComment)
            // User
            Messages.messages[addr]!.commented_ids.append(newComment.message_id)
        } else {
            // User
            Messages.messages[addr]!.upvote_tickets.remove(at: index)
            // Organizer
            if let organizerData = Messages.messages[ticket_addr] {
              organizerData.got_upvote = organizerData.got_upvote - 1
              Messages.messages[ticket_addr] = organizerData
            }
          }
      }
    }

    init(addr: Address, ticket_addr: Address, comment: String, is_comment: Bool) {
      pre {
        Messages.messages[addr] == nil: "This address already has vault"
      }

      let time = getCurrentBlock().timestamp
      var message: MessagesStruct? = nil
      var commentSt: CommentsStruct? = nil
      // User
      if (is_comment == true) {
        commentSt = CommentsStruct(comment: comment, time: time)
        message = MessagesStruct(addr: addr, ticket_addr: ticket_addr, comment: comment, is_comment: is_comment, message_id: commentSt!.message_id, is_organizer: false)
      } else {
        message = MessagesStruct(addr: addr, ticket_addr: ticket_addr, comment: comment, is_comment: is_comment, message_id: nil, is_organizer: false)
      }
      Messages.messages[addr] = message!

      // Organizer
      if let data = Messages.messages[ticket_addr] {
        if (is_comment == true) {
          data.got_comments.append(commentSt!)
        } else {
          data.got_upvote = data.got_upvote + 1
        }
        Messages.messages[ticket_addr] = data
      } else {
        let messageOrganizer = MessagesStruct(addr: ticket_addr, ticket_addr: nil, comment: comment, is_comment: is_comment, message_id: nil, is_organizer: true)
        if (is_comment == true) {
          messageOrganizer.got_comments.append(commentSt!)
        } else {
          messageOrganizer.got_upvote = 1
        }
        Messages.messages[ticket_addr] = messageOrganizer
      }
    }
  }

  /*
  ** [Resource] MessagesPublic
  */
  pub resource MessagesPublic {
  }

  /*
  ** [create vault] createMessagesVault
  */
  pub fun createMessagesVault(addr: Address, ticket_addr: Address, comment: String, is_comment: Bool): @MessagesVault {
    return <- create MessagesVault(addr: addr, ticket_addr: ticket_addr, comment: comment, is_comment: is_comment)
  }

  /*
  ** [create MessagesPublic] createMessagesPublic
  */
  pub fun createMessagesPublic(): @MessagesPublic {
    return <- create MessagesPublic()
  }

  /*
  ** init
  */
  init() {
    self.TicketsCommentVaultPublicPath = /public/TicketsCommentVault
    self.totalMessagesIds = 0
    self.messages = {}
  }
}