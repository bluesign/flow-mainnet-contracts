/************************************************************************
## The Flow Non-Fungible Token standard
## `NonFungibleToken` contract interface
The interface that all non-fungible token contracts could conform to.
If a user wants to deploy a new Relic contract, their contract would need
to implement the NonFungibleToken interface.
Their contract would have to follow all the rules and naming
that the interface specifies.
## `Relic` resource
The core resource type that represents an Relic in the smart contract.
## `Collection` Resource
The resource that stores a user's Relic collection.
It includes a few functions to allow the owner to easily
move tokens in and out of the collection.
## `Provider` and `Receiver` resource interfaces
These interfaces declare functions with some pre and post conditions
that require the Collection to follow certain naming and behavior standards.
They are separate because it gives the user the ability to share a reference
to their Collection that only exposes the fields and functions in one or more
of the interfaces. It also gives users the ability to make custom resources
that implement these interfaces to do various things with the tokens.
By using resources and interfaces, users of Relic smart contracts can send
and receive tokens peer-to-peer, without having to interact with a central ledger
smart contract.
To send an Relic to another user, a user would simply withdraw the Relic
from their Collection, then call the deposit function on another user's
Collection to complete the transfer.
--
Customized for the Modern Musician Relic Contract
developed by info@spaceleaf.io
************************************************************************/

// The main Relic contract interface. Other Relic contracts will
// import and implement this interface
//
pub contract interface NonFungibleToken {

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64

    // Event that emitted when the Relic contract is initialized
    //
    pub event ContractInitialized()

    // Event that is emitted when a token is withdrawn,
    // indicating the owner of the collection that it was withdrawn from.
    //
    // If the collection is not in an account's storage, `from` will be `nil`.
    //
    pub event Withdraw(id: UInt64, from: Address?)

    // Event that emitted when a token is deposited to a collection.
    //
    // It indicates the owner of the collection that it was deposited to.
    //
    pub event Deposit(id: UInt64, to: Address?)


    // emits an event when a transfer is conducted
    pub event Transfer(id: UInt64, from: Address?, to: Address?)


    // Interface that the Relics have to conform to
    //
    pub resource interface INFT {
        // The unique ID that each Relic has
        pub let id: UInt64
    }

    // Requirement that all conforming Relic smart contracts have
    // to define a resource called Relic that conforms to IRelic
    pub resource Relic: INFT {
        pub let id: UInt64
    }

    // Interface to mediate withdraws from the Collection
    //
    pub resource interface Provider {
        // withdraw removes an Relic from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @Relic {
            post {
                result.id == withdrawID: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }
    }

    // Interface to mediate deposits to the Collection
    //
    pub resource interface Receiver {

        // deposit takes an Relic as an argument and adds it to the Collection
        //
        pub fun deposit(token: @Relic)
    }

    // Interface that an account would commonly 
    // publish for their collection
    pub resource interface CollectionPublic {
        pub fun deposit(token: @Relic)
        pub fun getIDs(): [UInt64]
        pub fun borrowRelic(id: UInt64): &Relic
    }

    // Requirement for the the concrete resource type
    // to be declared in the implementing contract
    //
    pub resource Collection: Provider, Receiver, CollectionPublic {

        // Dictionary to hold the Relics in the Collection
        // pub var ownedRelics: @{UInt64: Relic} - ORIGINAL
        access(contract) var ownedRelics: @{UInt64: Relic}

        // withdraw removes an Relic from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @Relic

        // deposit takes a Relic and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @Relic)

        pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
            post {
                self.ownedRelics[id] == nil: "You didn't transfter the intended Relic."
                recipient.borrowRelic(id: id) != nil: "You didn't transfer the intended Relic."
            }
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64]

        // Returns a borrowed reference to an Relic in the collection
        // so that the caller can read data and call methods from it
        pub fun borrowRelic(id: UInt64): &Relic {
            pre {
                self.ownedRelics[id] != nil: "Relic does not exist in the collection!"
            }
        }
    }

    // createEmptyCollection creates an empty Collection
    // and returns it to the caller so that they can own Relics
    pub fun createEmptyCollection(): @Collection {
        post {
            result.getIDs().length == 0: "The created collection must be empty!"
        }
    }
}