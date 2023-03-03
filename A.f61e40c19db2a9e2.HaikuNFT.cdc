// This contract implements Bitku's HaikuNFT including the NFT resource which
// stores the text of each haiku and the function for minting+generating haiku.

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FlowToken from 0x1654653399040a61
import FUSD from 0x3c5959b568896393
import FungibleToken from 0xf233dcee88fe0abe

import Words from 0xf61e40c19db2a9e2
import Model from 0xf61e40c19db2a9e2
import SpaceModel from 0xf61e40c19db2a9e2
import EndModel from 0xf61e40c19db2a9e2


pub contract HaikuNFT: NonFungibleToken {

    pub let maxSupply: UInt64
    pub var totalSupply: UInt64
    pub let preMint: UInt64
    pub let priceDelta: UFix64
    pub let HaikuCollectionStoragePath: StoragePath
    pub let HaikuCollectionPublicPath: PublicPath
    pub let flowStorageFeePerHaiku: UFix64
    pub let transactionFee: UFix64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let text: String

        init(initID: UInt64, text: String) {
            self.id = initID
            self.text = text
        }

        pub fun getRenderedURL(): String {
            var text = ""
            var i = 0
            while i < self.text.length {
                switch self.text[i].toString() {
                    case " ":
                        text = text.concat("%20")
                    case "\n":
                        text = text.concat("%0A")
                    default:
                        text = text.concat(self.text[i].toString())
                }
                i = i + 1
            }

            return "https://render.bitku.art/?text=".concat(text)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.License>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Serial>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            // Note: This needs to be changed for each environment before deployment
            let base_url = "https://bitku.art/"
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Bitku # ".concat(self.id.toString()),
                        description: self.text,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.getRenderedURL()
                        )
                    )
                case Type<MetadataViews.Editions>():
                    let editionInfo = MetadataViews.Edition(name: "Bitku", number: self.id, max: HaikuNFT.maxSupply)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.ExternalURL>():
                    let address = self.owner?.address!
                    return MetadataViews.ExternalURL(
                        base_url
                        .concat("#")
                        .concat(address.toString())
                        .concat("/")
                        .concat(self.id.toString())
                    )
                case Type<MetadataViews.License>():
                    return MetadataViews.License("Apache-2.0")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: HaikuNFT.HaikuCollectionStoragePath,
                        publicPath: HaikuNFT.HaikuCollectionPublicPath,
                        providerPath: /private/BitkuCollection,
                        publicCollection: Type<&HaikuNFT.Collection{HaikuNFT.HaikuCollectionPublic}>(),
                        publicLinkedType: Type<&HaikuNFT.Collection{HaikuNFT.HaikuCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&HaikuNFT.Collection{HaikuNFT.HaikuCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-HaikuNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Bitku",
                        description: "Generative Haiku NFT on Flow",
                        externalURL: MetadataViews.ExternalURL(base_url),
                        squareImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: "https://bitku.art/logo512.png"
                            ),
                            mediaType: "image/png"
                        ),
                        bannerImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: "https://bitku.art/banner1200x630.png"
                            ),
                            mediaType: "image/png"
                        ),
                        socials: {
                            "discord": MetadataViews.ExternalURL("https://discord.gg/bKTHTd5ztx"),
                            "github": MetadataViews.ExternalURL("https://github.com/docmarionum1/bitku")
                        }
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([])
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
            }

            return nil
        }
    }

    pub resource interface HaikuCollectionPublic {
        pub fun borrowHaiku(id: UInt64): &HaikuNFT.NFT?

        // Require all of the base NFT functions to be delcared as well
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, HaikuCollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @HaikuNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowHaiku(id: UInt64): &HaikuNFT.NFT? {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return ref as! &HaikuNFT.NFT?
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let haikuNFT = nft as! &HaikuNFT.NFT
            return haikuNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun rand(i: UInt64, m: UInt64): UInt64 {
        return ((i * m) + UInt64(666)) % UInt64(0xfeedface)
    }

    pub fun ceil(_ i: UFix64): Int {
        if i > UFix64(UInt64(i)) {
            return Int(i) + 1
        }

        return Int(i)
    }

    pub fun getOptions(lineNum: Int, previousPreviousWord: String, previousWord: String): {String: Int} {
        let wordPair: String = previousPreviousWord.concat(" ").concat(previousWord)

        // Check surrounding lines in case this exact one is not defined for these words
        // < 3 ensures that we can check up to two lines away, which would be the max from line 0 -> 2 or vice versa
        var i = 0
        while i < 3 {
            var line = lineNum + i
            
            if (SpaceModel.model.containsKey(wordPair)) && (SpaceModel.model[wordPair]!.containsKey(line)) {
                return SpaceModel.model[wordPair]![line]!
            }
            if Model.model.containsKey(previousWord) && Model.model[previousWord]!.containsKey(line) {
                return Model.model[previousWord]![line]!
            }

            line = lineNum - i

            if SpaceModel.model.containsKey(wordPair) && SpaceModel.model[wordPair]!.containsKey(line) {
                return SpaceModel.model[wordPair]![line]!
            }
            if Model.model.containsKey(previousWord) && Model.model[previousWord]!.containsKey(line) {
                return Model.model[previousWord]![line]!
            }

            i = i + 1
        }

        return {"c": 1} // a == END, c == "\n"
    }

    pub fun getEndOptions(previousPreviousWord: String, previousWord: String): {String: Int} {
        // When we get too many syllables on the last line, try to get options from the end model
        let wordPair: String = previousPreviousWord.concat(" ").concat(previousWord)

        if EndModel.model.containsKey(wordPair) {
            return EndModel.model[wordPair]!
        }
        if EndModel.model.containsKey(previousWord) {
            return EndModel.model[previousWord]!
        }

        return {}
    }

    pub fun currentPrice(): UFix64 {
        let i = UFix64(self.totalSupply - self.preMint)
        var price = i*i*i*self.priceDelta

        // If it's the very first bitku, spot them the transaction fee to keep the price 0 FUSD
        if i > 0.0 {
            price = price + self.transactionFee
        }

        return price
    }

    pub fun captalize(_ a: String): String {
        switch a {
            case "a": return "A"
            case "b": return "B"
            case "c": return "C"
            case "d": return "D"
            case "e": return "E"
            case "f": return "F"
            case "g": return "G"
            case "h": return "H"
            case "i": return "I"
            case "j": return "J"
            case "k": return "K"
            case "l": return "L"
            case "m": return "M"
            case "n": return "N"
            case "o": return "O"
            case "p": return "P"
            case "q": return "Q"
            case "r": return "R"
            case "s": return "S"
            case "t": return "T"
            case "u": return "U"
            case "v": return "V"
            case "w": return "W"
            case "x": return "X"
            case "y": return "Y"
            case "z": return "Z"
            default: return a
        }
    }

    priv fun generateHaiku(_ seed: UInt64): String {
        var randNumber = seed
        var totalSyllables: Int = 0
        var lineSyllables: Int = 0
        var lineNum: Int = 0
        var previousPreviousWord: String = ""
        var previousWord: String = "b" // b == START
        var haiku: String = ""

        while previousWord != "END" {
            // Enforce line lengths
            if (lineNum == 0 && lineSyllables >= 5) || (lineNum == 1 && lineSyllables >= 7) {
                haiku = haiku.concat("\n")
                lineNum = lineNum + 1
                lineSyllables = 0
                previousPreviousWord = previousWord
                previousWord = "c" // c == "\n"
            } else {
                var options: {String: Int} = {}

                // When we get too many syllables on the last line, try to get options from the end model before falling back on the other models
                var end = false
                if lineNum == 2 && lineSyllables >= 4 {
                    options = HaikuNFT.getEndOptions(previousPreviousWord: previousPreviousWord, previousWord: previousWord)
                    if options.length > 0 {
                        end = true
                    }
                }
                
                // If it's not time to end, or if we didn't find end options
                if !end {
                    options = HaikuNFT.getOptions(lineNum: lineNum, previousPreviousWord: previousPreviousWord, previousWord: previousWord)
                }

                // Go through the options that we found
                let cumSums = options.values
                randNumber = HaikuNFT.rand(i: randNumber, m: 666)

                // Due to a change in the cadence implementation (https://github.com/onflow/cadence/pull/1156)
                // We can no longer rely on dictionaries to be ordered, so we need to get the max cumulative sum
                // by checking all of the values. Then we'll need to go through and find the closest value greater than
                // i.

                // Get the max cumulative sum
                var maxCumSum = 0
                for cumSum in cumSums {
                    if cumSum > maxCumSum {
                        maxCumSum = cumSum
                    }
                }

                // Our target index
                let i = Int(randNumber % UInt64(maxCumSum))

                // Keep track of the best match
                var best_match = 99999
                var best_match_index = 0

                // Find the best match in the array of cumulative sums
                var index = 0
                while index < cumSums.length {
                    let cumSum = cumSums[index]
                    if cumSum >= i && cumSum < best_match {
                        best_match = cumSum
                        best_match_index = index
                    }
                    index = index + 1
                }
                
                // Get the word at the index of the best match
                let word = options.keys[best_match_index]
                let uncompressedWord = Words.uncompress[word]!


                // Process the word, appending to the haiku and ending if necessary
                
                if uncompressedWord == "END" {
                    previousWord = "END"
                    break
                }

                if uncompressedWord == "\n" {
                    haiku = haiku.concat("\n")
                    lineNum = lineNum + 1
                    lineSyllables = 0
                } else if previousWord == "b" || previousWord == "c" { // START or \n
                    haiku = haiku.concat(
                        HaikuNFT.captalize(uncompressedWord.slice(from: 0, upTo: 1))
                    ).concat(
                        uncompressedWord.slice(from: 1, upTo: uncompressedWord.length)
                    )
                } else {
                    haiku = haiku.concat(" ").concat(uncompressedWord)
                }
                previousPreviousWord = previousWord
                previousWord = word
                totalSyllables = totalSyllables + Words.syllables[uncompressedWord]!
                lineSyllables = lineSyllables + Words.syllables[uncompressedWord]!

                if end {
                    break
                }
            }
        }

        return haiku
    }
    
    pub fun mintHaiku(recipient: &NonFungibleToken.Collection, vault: @FungibleToken.Vault, id: UInt64, flowReceiverRef: &FlowToken.Vault{FungibleToken.Receiver}) {
        pre {
            // Make sure that the ID matches the current ID
            id == HaikuNFT.totalSupply: "The given ID has already been minted."

            // Make sure that the ID is not greater than the max supply
            id < HaikuNFT.maxSupply: "There are no haiku left."

            // Make sure that the given vault has enough FLOW
            vault.balance >= HaikuNFT.currentPrice(): "The given FLOW vault doesn't have enough FLOW."

            // Don't allow someone to mint a haiku to an external collection until the premint is finished
            id >= HaikuNFT.preMint: "The pre-mint is not finished."
        }
        // https://github.com/onflow/flow-core-contracts/blob/master/transactions/flowToken/transfer_tokens.cdc

        // Deposit payment in contract vault
        let contractReceiverRef = self.account
            .getCapability(/public/fusdReceiver)
            .borrow<&{FungibleToken.Receiver}>() ?? panic("Could not borrow reference to contract's fusd receiver")
        contractReceiverRef.deposit(from: <- vault)

        // Seed the random number generator with the transaction info
        var blockId = getCurrentBlock().id

        var randNumber = self.totalSupply
        for byte in blockId {
           randNumber = HaikuNFT.rand(i: randNumber, m: UInt64(byte))
        }

        // Include the id in seed
        randNumber = HaikuNFT.rand(i: randNumber, m: id)

        let haiku = HaikuNFT.generateHaiku(randNumber)

        // Spot the minter some FLOW to cover storage costs
        let flowVaultRef = self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the contract's FLOW Vault!")

        let flowVault <- flowVaultRef.withdraw(amount: self.flowStorageFeePerHaiku)
        flowReceiverRef.deposit(from: <-flowVault)

        // Deposit the new haiku into the user's haiku collection
        recipient.deposit(token: <- create HaikuNFT.NFT(initID: HaikuNFT.totalSupply, text: haiku))

        // Increment the total supply
        HaikuNFT.totalSupply = HaikuNFT.totalSupply + (1 as UInt64)
    }

    
    // Premint 8 haikus; this is done in function that will be called 8 times to result in a total of 64 haikus. 
    // This is done outside of contract deployment because the computation limit is too low to do all 64 during deployment.
    // This function will save each haiku to the contract's collection.
    // This function will fail if the premint number (64) has already been exceeded. 
    // So this function can be called more times, but will have no effect.
    pub fun preMintHaikus(num: UInt64): UInt64 {
        pre {
            // Make sure that the this wouldn't exceed the pre-mint
            (HaikuNFT.totalSupply + num) <= HaikuNFT.preMint: "This would pre-mint more than the limit"
        }

        var maxId = self.totalSupply + num

        let collection = self.account.borrow<&NonFungibleToken.Collection>(from: HaikuNFT.HaikuCollectionStoragePath)
            ?? panic("Could not borrow reference to NFT Collection!")

        while self.totalSupply < maxId {
            let haiku = HaikuNFT.generateHaiku(self.totalSupply * UInt64(0xdeadbeef))
            collection.deposit(token: <- create HaikuNFT.NFT(initID: HaikuNFT.totalSupply, text: haiku))
            self.totalSupply = self.totalSupply + (1 as UInt64) 
        }

        return self.totalSupply
    }


    init() {
        // Set paths
        self.HaikuCollectionStoragePath = /storage/BitkuCollection
        self.HaikuCollectionPublicPath = /public/BitkuCollection

        // Initialize the total supply
        self.totalSupply = 0
        self.maxSupply = 1024
        self.preMint = 64

        self.priceDelta = 0.00000345

        // Transfer a small amount of FLOW to the minter to cover any possible storage costs
        self.flowStorageFeePerHaiku = 0.00005 // Amount of FLOW to transfer
        self.transactionFee = 0.1 // FUSD transaction fee to cover the above FLOW

        // Create a Collection resource and save it to storage
        let collection <- create Collection()

        self.account.save(<-collection, to: self.HaikuCollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&HaikuNFT.Collection{NonFungibleToken.CollectionPublic, HaikuNFT.HaikuCollectionPublic, MetadataViews.ResolverCollection}>(
            self.HaikuCollectionPublicPath,
            target: self.HaikuCollectionStoragePath
        )

        emit ContractInitialized()
    }
}
