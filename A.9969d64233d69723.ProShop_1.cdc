// ProShop.cdc

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import Gear_1 from 0x9969d64233d69723

pub contract ProShop_1: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64)
    pub event newPlayerAdded(player: Address)
    pub event TokenBaseURISet(newBaseURI: String)
    pub event playerRemoved(player: Address)
    pub event promotedMembership(player: Address)
    pub event demotedMembership(player: Address)
    pub event playerEarnedPoint(player: Address, point: UFix64)
    pub event addedMemberPoints(players: [Address], points: [UFix64])
    pub event ProShopListed(id: UInt64, price: UFix64, seller: Address?)
    pub event WeekStarted(week: UInt64)
    pub event buyGearFromProShop(id: UInt64, from: Address?)
    pub event gearPurchased(gearId: UInt64, points: UFix64)
    pub event listForSale(gearId: UInt64, price: UFix64)
    pub event setNewOwner(oldAddress:Address, newAddress: Address)
    pub event transferredProshop (id: UInt64, from:Address, to: Address)
    pub event ProShopUpgraded (id: UInt64)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath

    // totalSupply
    // The total number of ProShops that have been minted
    //
    pub var totalSupply: UInt64
    pub var weekId: UInt64
    access(self) var owners: {UInt64:Address}

    // baseURI
    //
    pub var baseURI: String

    // NFT
    // A ProShop as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT {
        // The token's ID
        pub let id: UInt64
        // The token's available points
        pub var points: UFix64
        
        access(self) var currentWeekPoints: UFix64
        access(self) var lastGameWeekId: UInt64
        // The token's name
        pub let name: String

        // Map between address and proshopmember struct
        //
        access(self) var members: {Address: ProShopMember}

        access(self) var memberContributes: {Address: SaleCut}

        access(self) var gameWeeks: {UInt64: GameWeek}

        // The ProShop token's unsold Gear's List - an Array
        // of tokenIds of Gear Tokens
        //
        access(self) var gearsNFTs: @{UInt64: NonFungibleToken.NFT}

        // The ProShop token's gear points mapping - a Dictionary
        // of key-value pairs showing the points of each Gear token's ID
        //
        access(self) let gearPoints: {UInt64: GearPoint}

        //proshop meta
        pub let metadata: {String: String}

        // The total score of all players' voting on Pro Shop
        //
        // pub var voteScore: Int8

        // The owner's share
        //
        pub var ownerShare: UFix64

        // initializer
        //
        init(proshopId: UInt64, name: String, points: UFix64, metadata: {String: String}, owner: Address, receiver: Capability<&{FungibleToken.Receiver}>) {
            self.id = proshopId
            self.name = name
            self.members = {}
            self.metadata = metadata
            self.points = points
            self.gearsNFTs <- {}
            self.gearPoints = {}
            self.lastGameWeekId = 0
            self.currentWeekPoints = 0.0
            // self.voteScore = 0
            // self.restrictStat = false
            self.ownerShare = 0.0
            // self.isLocked = false
            self.memberContributes = {}

            self.members[owner] = ProShopMember(role:Role.owner, receiver: receiver)
            self.gameWeeks = {}
            ProShop_1.owners[proshopId] = owner
        }

        // destructor
        destroy() {
            destroy self.gearsNFTs
            ProShop_1.totalSupply = ProShop_1.totalSupply - 1
        }

        pub fun upgrade(metadata: {String: String}) {
			pre {
				metadata != nil: "Cannot upgrade until the new metadata is created"
			}
			
			for key in metadata.keys {
				self.metadata[key] = metadata[key]!
			}
		}

        pub fun getGearPoints(): {UInt64: GearPoint} {
            return self.gearPoints
        }

        pub fun getMembers(): {Address: ProShopMember} {
            return self.members
        }

        pub fun setProShopOwner(address: Address, receiver: Capability<&{FungibleToken.Receiver}>) {
            var oldOwnerAddress : Address = 0x00
            for key in self.members.keys {
                if let member = self.members[key] {
                    if member.role == Role.owner {
                        oldOwnerAddress = key
                        break
                    } 
                } else {
                    panic("Could not find a member for the specified player address")
                }
            }

            self.members[oldOwnerAddress] = nil
            self.members[address] = ProShopMember(role: Role.owner, receiver: receiver)
            //set owner address in global array
            ProShop_1.owners[self.id] = address
            emit setNewOwner(oldAddress:oldOwnerAddress, newAddress: address)
        }

        // join new player to ProShop token
        //
        pub fun join(player: Address, receiver: Capability<&{FungibleToken.Receiver}>) {
            pre {
                self.members[player] == nil:
                    "This player already exists"
            }

            self.members[player] = ProShopMember(role: Role.member, receiver: receiver)
            
            emit newPlayerAdded(player: player)
        }

        // kick player from ProShop token
        //
        pub fun kick(player: Address) {
            pre {
                self.members[player] != nil:
                    "This player doesn't exists"
            }

            self.members[player] = nil
            
            emit playerRemoved(player: player)
        }

        pub fun setOwnerShare(share: UFix64) {
            self.ownerShare = share
        }

        // make membership as officer
        //
        pub fun promote(player: Address) {
            pre {
                self.members[player] != nil:
                    "This member not exists"
            }
            
            if let member = self.members[player] {
                member.setRole(role: Role.officer)
                self.members[player] = member
            } else {
                panic("Could not find a member for the specified player address")
            }

            emit promotedMembership(player: player)
        }
        // make membership as member
        //
        pub fun demote(player: Address) {
            pre {
                self.members[player] != nil:
                    "This member not exists"
            }

            if let member = self.members[player] {
                member.setRole(role: Role.member)
                self.members[player] = member
            } else {
                panic("Could not find a member for the specified player address")
            }

            emit demotedMembership(player: player)
        }

        pub fun addMemberPoints(players: [Address], points: [UFix64]) {
            pre {
                players.length != 0 && points.length !=0 && players.length == points.length:
                    "Wrong parameters"
            }

            var index: UInt64 = 0
            for player in players {
                let point = points[index]
                if let member = self.members[player] {
                    member.points = member.points + point
                    self.members[player] = member
                    self.points = self.points + point
                    self.currentWeekPoints = self.currentWeekPoints + point
                } else {
                    panic("Could not find a member for the specified player address")
                }

                index = index + 1
            }

            self.setContributesAndGameWeek()            

            emit addedMemberPoints(players: players, points: points)
        }

        pub fun setContributesAndGameWeek() {
            //prepare contribute
            for address in self.members.keys {
                if let member = self.members[address] {
                    if member.role == Role.owner {
                        self.memberContributes[address] = SaleCut(receiver: member.getReceiver(), amount: self.ownerShare + (100.0 - self.ownerShare) * member.points / self.currentWeekPoints ) 
                    } else {
                        self.memberContributes[address] = SaleCut(receiver: member.getReceiver(), amount: (100.0 - self.ownerShare) * member.points / self.currentWeekPoints)
                    }
                } else {
                    panic("Could not find a member for the specified player address")
                }
            }

            if let gameWeek = self.gameWeeks[ProShop_1.weekId] {
                gameWeek.points = self.currentWeekPoints
                gameWeek.setMemberContributes(contributes: self.memberContributes)
                self.gameWeeks[ProShop_1.weekId] = gameWeek
            } else {
                self.gameWeeks[ProShop_1.weekId] = GameWeek(points: self.currentWeekPoints, contributes:self.memberContributes)
            }
        }
        
        pub fun listForSale(gearId: UInt64, price: UFix64) {
            pre {
                self.gearsNFTs[gearId] != nil: 
                    "Gear doesnot exist!"
            }

            if let gearPoint = self.gearPoints[gearId] {
                gearPoint.price = price
                self.gearPoints[gearId] = gearPoint

                emit listForSale(gearId: gearId, price: price)
            } else {
                panic("Could not find a gear point of gear token id")
            }
        }

        pub fun getGearPrice(gearId: UInt64): UFix64 {
            pre {
                self.gearsNFTs[gearId] != nil: 
                    "Gear doesnot exist!"
            }

            if let gearPoint = self.gearPoints[gearId] {
                return gearPoint.price
            } else {
                panic("Could not find a gear point of gear token id")
            }

            return 0.0
        }

        pub fun purchaseGearForProShopWithPoints(gear: @NonFungibleToken.NFT, points: UFix64) {
            pre {
                self.points >= points: 
                    "Available points is not enough"
                self.lastGameWeekId > 0: 
                    "No gameweek yet"
            }

            let gearId : UInt64 = gear.id
            let oldToken <- self.gearsNFTs[gearId] <- gear
            var gearContributes: {Address: SaleCut} = {}

            var remainPoints = points
            while self.lastGameWeekId <= ProShop_1.weekId {
                var gameWeek = self.gameWeeks[self.lastGameWeekId]!
                if gameWeek == nil || gameWeek.points == 0.0 {
                    if gameWeek != nil {
                        self.gameWeeks[self.lastGameWeekId] = nil
                    }
                    self.lastGameWeekId = self.lastGameWeekId + 1
                    continue
                }

                var chargedPoints: UFix64 = remainPoints
                if gameWeek.points < remainPoints {
                    chargedPoints = gameWeek.points
                }
                var chargePercent: UFix64 = chargedPoints / points
                for address in gameWeek.getMemberContributes().keys {
                    if let saleCut = gameWeek.getMemberContributes()[address] {
                        if let gearSaleCut = gearContributes[address] {
                            gearSaleCut.amount = gearSaleCut.amount + saleCut.amount * chargePercent
                            gearContributes[address] = gearSaleCut
                        } else {
                            gearContributes[address] = SaleCut(receiver: saleCut.receiver, amount: saleCut.amount * chargePercent)
                        }
                    }
                }

                if self.lastGameWeekId == ProShop_1.weekId { //current week
                    for address in self.members.keys {
                        if let member = self.members[address] {
                            member.points = member.points * (gameWeek.points - chargedPoints) / gameWeek.points
                            self.members[address] = member
                        } else {
                            panic("Could not find a member for the specified member address")
                        }
                    }
                }         

                gameWeek.points = gameWeek.points - chargedPoints
                remainPoints = remainPoints - chargedPoints
                
                if gameWeek.points <= 0.0 {
                    self.gameWeeks[self.lastGameWeekId] = nil
                    self.lastGameWeekId = self.lastGameWeekId + 1
                } else {
                    self.gameWeeks[self.lastGameWeekId] = gameWeek
                }
                
                if remainPoints <= 0.0 {
                    break
                }
            }
            self.points = self.points - points
            self.gearPoints[gearId] = GearPoint(points: points, contributes: gearContributes, price: 0.0)

            destroy oldToken

            emit gearPurchased(gearId: gearId, points: points)
        }

        pub fun buyGearFromProShop(gearTokenId: UInt64, payment: @FungibleToken.Vault): @NonFungibleToken.NFT {
            pre {
                self.gearsNFTs[gearTokenId] != nil: 
                    "Gear doesnot exist!"
            }

            if let gearPoint = self.gearPoints[gearTokenId] {
                if gearPoint.price == 0.0 {
                    panic("Cannot sell because price doesnot set for this gear")
                }

                if gearPoint.price != payment.balance {
                    panic("Cannot sell because payment is not equal as price")
                }

                let contributes = gearPoint.getContributes()
                var index: Int = 0 
                for address in contributes.keys {
                    index = index+1
                    if let saleCut = contributes[address] {

                        let benefitAmount = gearPoint.price * (saleCut.amount / 100.0)
                        if let member = self.members[address] {
                            member.earnedAmount = member.earnedAmount + benefitAmount
                            self.members[address] = member
                        }

                        if let receiver = saleCut.receiver.borrow() {
                            let paymentCut <-payment.withdraw(amount: benefitAmount)
                            receiver.deposit(from: <-paymentCut)
                        } else {
                            panic("Could not get receiver")
                        }
                    } else {
                         panic("Could not get sale cut of member")
                    }
                }

                gearPoint.sellWeekId = ProShop_1.weekId
                self.gearPoints[gearTokenId] = gearPoint
            } else {
                panic("Could not find a gear point of gear token id")
            }

            destroy payment

            let token <- self.gearsNFTs.remove(key: gearTokenId) ?? panic("missing NFT")
            
            self.gearPoints.remove(key: gearTokenId)
            emit buyGearFromProShop(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun startWeek() {
            self.currentWeekPoints = 0.0

            for address in self.members.keys {
                if let member = self.members[address] {
                    member.points = 0.0
                    self.members[address] = member
                } else {
                    panic("Could not find a member for the specified player address")
                }
            }

            self.gameWeeks[ProShop_1.weekId] = GameWeek(points: 0.0, contributes:{})

            if self.lastGameWeekId == 0 {
                self.lastGameWeekId = ProShop_1.weekId
            }
        }
    }

    // Role Enum in Member
    //
    pub enum Role: UInt8 {
        pub case owner
        pub case officer
        pub case member
    }

    // ProShop Member
    // membership
    //
    pub struct ProShopMember {
        // The role enum
        pub var role: Role
        // The token's available points
        pub(set) var points: UFix64
        // The member's status
        pub var status: Bool
        
        // Earned from point contribution in lifetime
        //
        pub(set) var earnedAmount: UFix64
        
        access(self) let receiver: Capability<&{FungibleToken.Receiver}>

        // initializer
        //
        init(role: Role, receiver: Capability<&{FungibleToken.Receiver}>) {
            self.role = role
            self.points = 0.0
            self.status = false
            self.earnedAmount = 0.0
            self.receiver = receiver
        }

        pub fun setRole(role: Role) {
            self.role = role
        }

        pub fun getReceiver(): Capability<&{FungibleToken.Receiver}> {
            return self.receiver
        }
    }

    pub struct GearPoint {
        // The token's available points
        pub(set) var points: UFix64

        access(self) var contributes: {Address: SaleCut}

        pub(set) var price: UFix64

        pub(set) var buyWeekId: UInt64
        pub(set) var sellWeekId: UInt64
        
        // initializer
        //
        init(points: UFix64, contributes: {Address: SaleCut}, price: UFix64) {
            self.points = points
            self.contributes = contributes
            self.price = price
            self.buyWeekId = ProShop_1.weekId
            self.sellWeekId = 0
        }

        pub fun getContributes(): {Address: SaleCut} {
            return self.contributes
        }
    }

    pub struct GameWeek {
        pub(set) var points: UFix64
        pub(set) var weekId: UInt64
        access(self) var memberContributes: {Address: SaleCut}

        init(points: UFix64, contributes: {Address: SaleCut}) {
            self.points = points
            self.memberContributes = contributes
            self.weekId = ProShop_1.weekId
        }

        pub fun getMemberContributes(): {Address: SaleCut} {
            return self.memberContributes
        }

        pub fun setMemberContributes(contributes: {Address: SaleCut}) {
            self.memberContributes = contributes
        }
    }

    pub struct SaleCut {
        // The receiver for the payment.
        // Note that we do not store an address to find the Vault that this represents,
        // as the link or resource that we fetch in this way may be manipulated,
        // so to find the address that a cut goes to you must get this struct and then
        // call receiver.borrow()!.owner.address on it.
        // This can be done efficiently in a script.
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        // The amount of the payment FungibleToken that will be paid to the receiver.
        pub(set) var amount: UFix64
        // initializer
        //
        init(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
            self.receiver = receiver
            self.amount = amount
        }
    }

    // Admin is a special authorization resource that 
    // allows the owner to perform important ProShop 
    // functions for actions on ProShop like invite/kick
    // player, 
    //
    pub resource Admin {

        pub fun setBaseURI(newBaseURI: String) {
            ProShop_1.baseURI = newBaseURI
            emit TokenBaseURISet(newBaseURI: newBaseURI)
        }

        pub fun startWeek(week: UInt64) {
            pre {
                ProShop_1.weekId < week: 
                    "Week is not correct"
            }
            ProShop_1.weekId =  week
            var tokenId:UInt64 = 0
            while tokenId < ProShop_1.totalSupply {
                let proshoptoken = self.borrowProShop(id: tokenId)
                proshoptoken.startWeek()
                tokenId = tokenId + 1
            }
            emit WeekStarted(week: ProShop_1.weekId)
        }

        // add player in ProShop token
        //
        pub fun addMember(player: Address, id: UInt64, receiver: Capability<&{FungibleToken.Receiver}>) {
             let proshoptoken = self.borrowProShop(id: id)
            proshoptoken.join(player: player, receiver: receiver)            
        }

        // remove player in ProShop token
        //
        pub fun removeMember(player: Address, id: UInt64) {
            let proshoptoken = self.borrowProShop(id: id)
            proshoptoken.kick(player: player)            
        }

        pub fun promoteMembership(player: Address, id: UInt64) {
            let proshoptoken = self.borrowProShop(id: id)
            proshoptoken.promote(player: player)   
        }

        pub fun demoteMembership(player: Address, id: UInt64) {
            let proshoptoken = self.borrowProShop(id: id)
            proshoptoken.demote(player: player)  
        }

        pub fun setOwnerShare(id: UInt64, share: UFix64) {
            let proshoptoken = self.borrowProShop(id: id)
            proshoptoken.setOwnerShare(share: share)     
        }

        pub fun addMemberPoints(id: UInt64, players: [Address], points: [UFix64]) {
            let proshoptoken = self.borrowProShop(id: id)

            proshoptoken.addMemberPoints(players: players, points: points)   
        }

        pub fun upgrade(id: UInt64, metadata: {String: String}) {
			let proshoptoken = self.borrowProShop(id: id)
			proshoptoken.upgrade(metadata: metadata)
			emit ProShopUpgraded(id: id)
		}

        access(self) fun borrowProShop(id: UInt64): &ProShop_1.NFT {
            let ownerAddress = ProShop_1.owners[id]!
            let account = getAccount(ownerAddress)
            let ref = account.getCapability(ProShop_1.CollectionPublicPath)!.borrow<&{ProShop_1.ProShopCollectionPublic}>()
                ?? panic("Could not borrow public reference")

            return ref.borrowProShop(id:id)!
        }
    }

    // This is the interface that users can cast their ProShop Collection as
    // to allow others to deposit ProShop into their Collection. It also allows for reading
    // the details of ProShop in the Collection.
    pub resource interface ProShopCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun getUnsoldGears(id: UInt64): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowProShop(id: UInt64): &ProShop_1.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ProShop reference: The ID of the returned reference is incorrect"
            }
        }
        
        pub fun buyGearFromProShop(id: UInt64, gearTokenId: UInt64, payment: @FungibleToken.Vault): @NonFungibleToken.NFT
    }

    // Collection
    // A collection of ProShop NFTs owned by an account
    //
    pub resource Collection: ProShopCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
        access(self) var prices: {UInt64: UFix64}

        // listForSale lists an NFT for sale in this sale collection
        // at the specified price
        //
        // Parameters: token: The NFT to be put up for sale
        //             price: The price of the NFT
        // pub fun listForSale(token: @ProShop_1.NFT, price: UFix64) {
        //     pre {
        //         // Check that price of the listing is > 0
        //         price > 0.0: 
        //             "Price must be greater than 0"
        //     }
        //     // get the ID of the token
        //     let id = token.id

        //     // Set the token's price
        //     self.prices[token.id] = price

        //     // Deposit the token into the sale collection
        //     self.deposit(token: <-token)

        //     emit ProShopListed(id: id, price: price, seller: self.owner?.address)
        // }

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            // pre {
            //     //only can be called by admin or owner
            //     (self.owner?.address == ProShop_1.account.address):
            //         "signer must be owner"
            // }
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @ProShop_1.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
            // ProShop_1.proshopNFTs[id] = &self.ownedNFTs[id] as! &ProShop_1.NFT

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun transferProshop(tokenId: UInt64, recipient: Address, receiver: Capability<&{FungibleToken.Receiver}>) {
            var token <- self.withdraw(withdrawID: tokenId) as! @ProShop_1.NFT
            token.setProShopOwner(address: recipient, receiver: receiver)

            let recipientAccount = getAccount(recipient)
            let proshopPublicCollection = recipientAccount.getCapability(ProShop_1.CollectionPublicPath)!.borrow<&{ProShop_1.ProShopCollectionPublic}>()
                 ?? panic("Could not borrow public reference of recipient")
            
            let tokenId: UInt64 = token.id
            proshopPublicCollection.deposit(token: <-token)
            emit transferredProshop (id: tokenId, from: self.owner!.address, to: recipient)
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowProShop
        // Gets a reference to an NFT in the collection as a ProShop,
        // exposing all of its fields (including the ProShop attributes).
        // This is safe as there are no functions that can be called on the ProShop.
        //
        pub fun borrowProShop(id: UInt64): &ProShop_1.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &ProShop_1.NFT
            } else {
                return nil
            }
        }

        pub fun buyGearFromProShop(id: UInt64, gearTokenId: UInt64, payment: @FungibleToken.Vault): @NonFungibleToken.NFT {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let proshoptoken = ref as! &ProShop_1.NFT
            return <-proshoptoken.buyGearFromProShop(gearTokenId: gearTokenId, payment: <-payment)
        }

        pub fun getUnsoldGears(id: UInt64): [UInt64] {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let proshoptoken = ref as! &ProShop_1.NFT
            return proshoptoken.getGearPoints().keys
        }

        pub fun getGearPoints(id: UInt64): {UInt64: GearPoint} {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let proshoptoken = ref as! &ProShop_1.NFT
            return proshoptoken.getGearPoints()
        }

        pub fun listForSale(id: UInt64, gearId: UInt64, price: UFix64) {
            let ownerAddress = ProShop_1.owners[id]!
            let account = getAccount(ownerAddress)
            
            let ref = account.getCapability(ProShop_1.CollectionPublicPath)!.borrow<&{ProShop_1.ProShopCollectionPublic}>()
                ?? panic("Could not borrow public reference")

            let proshoptoken = ref.borrowProShop(id: id)!   

            //check access privilege
            let authAddress = self.owner?.address!
            if(authAddress != ProShop_1.account.address) { //if auth user is not admin
                if let member = proshoptoken.getMembers()[authAddress] {
                    if member.role == Role.member {
                        panic("Normal member doesn't have privilege to purchase.")
                    } 
                } else {
                    panic("Could not find a member in the Proshop")
                }
            }         
            proshoptoken.listForSale(gearId: gearId, price: price)
        }

        pub fun purchaseGearForProShopWithPoints(id: UInt64, gear: @NonFungibleToken.NFT, points: UFix64) {
            let ownerAddress = ProShop_1.owners[id]!
            let account = getAccount(ownerAddress)
            
            let ref = account.getCapability(ProShop_1.CollectionPublicPath)!.borrow<&{ProShop_1.ProShopCollectionPublic}>()
                ?? panic("Could not borrow public reference")

            let proshoptoken = ref.borrowProShop(id: id)!   
            //check access privilege
            let authAddress = self.owner?.address!
            if(authAddress != ProShop_1.account.address) { //if auth user is not admin
                if let member = proshoptoken.getMembers()[authAddress] {
                    if member.role == Role.member {
                        panic("Normal member don't have privilege.")
                    } 
                } else {
                    panic("Could not find a member in the Proshop")
                }
            }     
            proshoptoken.purchaseGearForProShopWithPoints(gear: <- gear, points: points)
        }

        pub fun getAuthAccount(): Address {
            return ProShop_1.account.address
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
            self.prices = {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    // Resource that allows an admin to mint new NFTs
    //
	pub resource NFTMinter {

		// mintProShop
        // Mints a new ProShop NFT with a new ID
		// and deposits it in the recipients collection using their collection reference
        //
		pub fun mintProShop(recipient: &{NonFungibleToken.CollectionPublic}, name: String, metadata: {String: String}, owner: Address, receiver: Capability<&{FungibleToken.Receiver}>) {
            emit Minted(id: ProShop_1.totalSupply)


			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create ProShop_1.NFT(
                proshopId: ProShop_1.totalSupply,
                name: name,
                points: 0.0,
                metadata: metadata,
                owner: owner,
                receiver: receiver,
            ))

            ProShop_1.totalSupply = ProShop_1.totalSupply + (1 as UInt64)
		}
	}

    // SalePublic 
    //
    // The interface that a user can publish a capability to their sale
    // to allow others to access their sale
    pub resource interface SalePublic {
        pub var cutPercentage: UFix64
        pub fun purchase(tokenID: UInt64, buyTokens: @FungibleToken.Vault): @ProShop_1.NFT {
            post {
                result.id == tokenID: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }
        pub fun getPrice(tokenID: UInt64): UFix64?
        pub fun getIDs(): [UInt64]
        pub fun borrowProShop(id: UInt64): &ProShop_1.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow ProShop reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // fetch
    // Get a reference to a ProShop from an account's Collection, if available.
    // If an account does not have a ProShop.Collection, panic.
    // If it has a collection but does not contain the proshopId, return nil.
    // If it has a collection and that collection contains the proshopId, return a reference to that.
    //
    pub fun fetch(_ from: Address, proshopId: UInt64): &ProShop_1.NFT? {
        let collection = getAccount(from)
            .getCapability(ProShop_1.CollectionPublicPath)
            .borrow<&ProShop_1.Collection{ProShop_1.ProShopCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust ProShop.Collection.borowProShop to get the correct proshopId
        // (it checks it before returning it).
        return collection.borrowProShop(id: proshopId)
    }

    // initializer
    //
	init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/ProShopCollection_1
        self.CollectionPublicPath = /public/ProShopCollection_1
        self.MinterStoragePath = /storage/ProShopMinter_1
        self.AdminStoragePath = /storage/ProShopAdmin_1
        self.AdminPrivatePath = /private/ProShopAdminUpgrade_1

        // Initialize the total supply
        self.totalSupply = 0
        self.owners = {}
        self.weekId = 0
        self.baseURI = ""

        // Create a Minter resource and save it to admin storage
        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)

        self.account.save(<-create Admin(), to: self.AdminStoragePath)

        self.account.link<&ProShop_1.Admin>(
            self.AdminPrivatePath,
            target: self.AdminStoragePath
        ) ?? panic("Could not get a capability to the admin")

        emit ContractInitialized()
	}
}
 
