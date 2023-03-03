import FlowToken from 0x1654653399040a61
import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

import LostAndFound from 0x473d6a2c37eab5be

import RoyaltiesOverride from 0x3cdbb3d569211ff3


pub contract FlowtyUtils {
    access(contract) var Attributes: {String: AnyStruct}

    pub let FlowtyUtilsStoragePath: StoragePath

    pub struct NFTIdentifier {
        // TODO: add an optional field here so that we can make nft identifiers operate
        // based on metadata 
        // TODO: add uuid here as an optional
        pub let nftType: Type
        pub let nftID: UInt64

        pub init(nftType: Type, nftID: UInt64) {
            self.nftType = nftType
            self.nftID = nftID
        }
    }

    pub struct CollectionInfo {
        pub let nftType: Type
        pub let storagePath: StoragePath
        pub let privatePath: PrivatePath
        pub let collectionPublicPath: PublicPath

        init(
            nftType: Type, 
            storagePath: StoragePath, 
            privatePath: PrivatePath, 
            collectionPublicPath: PublicPath
        ) {
            self.nftType = nftType
            self.storagePath = storagePath
            self.privatePath = privatePath
            self.collectionPublicPath = collectionPublicPath
        }
    }

    pub struct TokenInfo {
        pub let tokenType: Type
        pub let storagePath: StoragePath
        pub let balancePath: PublicPath
        pub let receiverPath: PublicPath
        pub let providerPath: PrivatePath

        init(
            tokenType: Type, 
            storagePath: StoragePath, 
            balancePath: PublicPath, 
            receiverPath: PublicPath, 
            providerPath: PrivatePath
        ) {
            self.tokenType = tokenType
            self.storagePath = storagePath
            self.balancePath = balancePath
            self.receiverPath = receiverPath
            self.providerPath = providerPath
        }
    }
    
    // PaymentCut
    // A struct representing a recipient that must be sent a certain amount
    // of the payment when a tx is executed.
    //
    pub struct PaymentCut {
        // The receiver for the payment.
        // Note that we do not store an address to find the Vault that this represents,
        // as the link or resource that we fetch in this way may be manipulated,
        // so to find the address that a cut goes to you must get this struct and then
        // call receiver.borrow().owner.address on it.
        // This can be done efficiently in a script.
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        // The amount of the payment FungibleToken that will be paid to the receiver.
        pub let amount: UFix64

        // initializer
        //
        init(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
            self.receiver = receiver
            self.amount = amount
        }
    }

    pub resource FlowtyUtilsAdmin {
        pub fun setBalancePath(key: String, path: PublicPath): Bool {
            if FlowtyUtils.Attributes["balancePaths"] == nil {
                FlowtyUtils.Attributes["balancePaths"] = BalancePaths()
            }

            return (FlowtyUtils.Attributes["balancePaths"]! as! BalancePaths).set(key: key, path: path)
        }

        // addSupportedTokenType
        // add a supported token type that can be used in Flowty loans
        pub fun addSupportedTokenType(tokenInfo: TokenInfo) {
            var supportedTokens = FlowtyUtils.Attributes["supportedTokens"]
            if supportedTokens == nil {
                supportedTokens = {} as {Type: TokenInfo}
            }

            let tokens = supportedTokens! as! {Type: TokenInfo}
            tokens[tokenInfo.tokenType] = tokenInfo
            FlowtyUtils.Attributes["supportedTokens"] = tokens
        }

        // addSupportedTokenType
        // add a supported token type that can be used in Flowty loans
        pub fun addSupportedNFT(collectionInfo: CollectionInfo) {
            var supportedTypes = FlowtyUtils.Attributes["supportedNFTs"]
            if supportedTypes == nil {
                supportedTypes = {} as {Type: CollectionInfo}
            }

            let tokens = supportedTypes! as! {Type: CollectionInfo}
            tokens[collectionInfo.nftType] = collectionInfo
            FlowtyUtils.Attributes["supportedNFTs"] = tokens
        }
    }

    pub fun getCollectionInfo(_ type: Type): CollectionInfo? {
        let value = self.Attributes["supportedNFTs"]
        if value == nil {
            return nil
        }

        let supportedNFTs = value! as! {Type: CollectionInfo}
        return supportedNFTs[type]
    }

    pub fun getAllCollections(): {Type: CollectionInfo} {
        let value = self.Attributes["supportedNFTs"]
        if value == nil {
            return {}
        }

        return value! as! {Type: CollectionInfo}
        
    }

    pub fun getTokenInfo(_ type: Type): TokenInfo? {
        let value = self.Attributes["supportedTokens"]
        if value == nil {
            return nil
        }

        let supportedTokens = value! as! {Type: TokenInfo}
        return supportedTokens[type]
    }

    pub fun getSupportedTokens(): [Type] {
        let attribute = self.Attributes["supportedTokens"]
        if attribute == nil {
            return []
        }
        let supportedTokens = attribute! as! {Type: TokenInfo}
        return supportedTokens.keys
    }

    pub fun getSupportedNFTs(): [Type] {
        let supportedNFTs = self.Attributes["supportedNFTs"]! as! {Type: CollectionInfo}
        return supportedNFTs.keys
    }

    // isNFTTypeSupported
    // check if the given type is able to be used as payment
    pub fun isNFTTypeSupported(type: Type): Bool {
        for t in FlowtyUtils.getSupportedNFTs() {
            if t == type {
                return true
            }
        }

        return false
    }

    pub fun validateNFTIdentifier(
        nftIdenfitier: NFTIdentifier, 
        cap: Capability<&{NonFungibleToken.CollectionPublic}>
    ): Bool {
        if !cap.check() {
            return false
        }

        let collectionPublic = cap.borrow()!
        let ids = collectionPublic.getIDs()
        if !ids.contains(nftIdenfitier.nftID) {
            return false
        }

        let nft = cap.borrow()!.borrowNFT(id: nftIdenfitier.nftID)
        if nft == nil {
            return false
        }

        if nft.id != nftIdenfitier.nftID || nft.getType() != nftIdenfitier.nftType {
            return false
        }

        return true
    }

    pub fun validateNFTIdentifiers(
        nftIdentifiers: [NFTIdentifier],
        caps: [Capability<&{NonFungibleToken.CollectionPublic}>]
    ): Bool {
        if nftIdentifiers.length != caps.length {
            return false
        }
        
        for index, nftIdenfitier in nftIdentifiers {
            let cap = caps[index]
            if !FlowtyUtils.validateNFTIdentifier(nftIdenfitier: nftIdenfitier, cap: cap) {
                return false
            }
        }

        return true
    }

    pub fun getRoyalty(nftID: UInt64, cap: Capability<&{MetadataViews.ResolverCollection}>): MetadataViews.Royalties? {
        if !cap.check() {
            return nil
        }

        let resolver = cap.borrow()!.borrowViewResolver(id: nftID)
        return resolver.resolveView(Type<MetadataViews.Royalties>()) as? MetadataViews.Royalties
    }

    pub fun calculateRoyaltyRate(_ royalties: [MetadataViews.Royalties?]): UFix64 {
        var total = 0.0
        if royalties.length == 0 {
            return total
        }

        for view in royalties {
            var rate = 0.0
            if view != nil {
                for r in view!.getRoyalties() {
                    rate = rate + r.cut
                }
            }    

            total = total + rate
        }

        return total / UFix64(royalties.length)
    }

    pub fun getRoyaltiesFromNftIdentifiers(_ identifiers: [NFTIdentifier], address: Address): [MetadataViews.Royalties] {
        let royalties = [] as [MetadataViews.Royalties]
        let caps: {Type: Capability<&{MetadataViews.ResolverCollection}>} = {}
        let account = getAccount(address)

        for identifier in identifiers {
            if caps[identifier.nftType] == nil {
                let collectionInfo = FlowtyUtils.getCollectionInfo(identifier.nftType)!
                caps[identifier.nftType] = account.getCapability<&{MetadataViews.ResolverCollection}>(collectionInfo.collectionPublicPath)
            }

            let cap = caps[identifier.nftType]!
            if !cap.check() {
                // This capability isn't valid! We cannot evaluate its royalties so we have to mark this as empty for now
                continue
            }

            let resolver = cap.borrow()!.borrowViewResolver(id: identifier.nftID)
            let royalty = resolver.resolveView(Type<MetadataViews.Royalties>())
            if royalty != nil {
                royalties.append(royalty! as! MetadataViews.Royalties)
            }
            
        }

        return royalties
    }

    pub fun timeRemaining(_ startTime: UFix64, _ term: UFix64): Fix64 {
        let currentTime = getCurrentBlock().timestamp
        let remaining = Fix64(startTime + currentTime) - Fix64(currentTime)
        return remaining
    }

    access(self) fun getDepositor(): &LostAndFound.Depositor {
        return self.account.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)!
    }

    access(account) fun trySendFungibleTokens(vault: @FungibleToken.Vault, tokenInfo: TokenInfo, to: Address, memo: String?, display: MetadataViews.Display?) {
        pre {
            tokenInfo.tokenType == vault.getType(): "vault type must match token info type"
        }

        let cap = getAccount(to).getCapability<&{FungibleToken.Receiver}>(tokenInfo.receiverPath)
        if cap.check() {
            cap.borrow()!.deposit(from: <-vault)
            return 
        }

        FlowtyUtils.depositFungibleTokens(vault: <-vault, to: to, memo: memo, display: display)
    }

    access(account) fun depositFungibleTokens(vault: @FungibleToken.Vault, to: Address, memo: String?, display: MetadataViews.Display?) {
        let depositor = FlowtyUtils.getDepositor()
        depositor.deposit(redeemer: to, item: <-vault, memo: memo, display: display)
    }

    access(account) fun trySendNonFungibleTokens(nft: @NonFungibleToken.NFT, collectionInfo: CollectionInfo, to: Address, memo: String?, display: MetadataViews.Display?) {
        pre {
            nft.getType() == collectionInfo.nftType: "nft type must match collectionInfo type"
        }

        let depositCap = getAccount(to).getCapability<&{NonFungibleToken.CollectionPublic}>(collectionInfo.collectionPublicPath)
        if depositCap.check() {
            depositCap.borrow()!.deposit(token: <-nft)
            return 
        }

        let cap = getAccount(to).getCapability<&{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(collectionInfo.collectionPublicPath)
        var display: MetadataViews.Display? = nil
        if cap.check() {
            display = cap.borrow()!.borrowViewResolver(id: nft.id).resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?
        }

        let depositor = FlowtyUtils.getDepositor()
        depositor.trySendResource(item: <-nft, cap: cap, memo: memo, display: display)
    }

    access(account) fun sendNFTs(addr: Address, nfts: @[NonFungibleToken.NFT]) {
        let collectionInfos = FlowtyUtils.getAllCollections()
        let account = getAccount(addr)
        let depositor = FlowtyUtils.getDepositor()

        while nfts.length > 0 {
            let nft <- nfts.removeFirst()
            let nftType = nft.getType()

            FlowtyUtils.trySendNonFungibleTokens(nft: <-nft, collectionInfo: collectionInfos[nftType]!, to: addr, memo: nil, display: nil)
        }

        destroy nfts
    }

    /*
        We cannot know the real value of each item being transacted with. Because of that, we will simply split 
        the royalty rate evenly amongst each MetadataViews.Royalties item, and then split that piece of the royalty
        evenly amongst each Royalty in that item.

        For example, let's say we have two MetadataRoyalties entries:
        1. A single cutInfo of 5%
        2. Two cutInfos of 1% and 5%

        And let's also say that the royaltyRate is 5%. In that scenario, half of the vault goes to each Royalties entry.
        All of the first half goes to cutInfo #1's destination. The second half should send 1/6 of its half to the first
        cutInfo, and 5/6 of the second half to the second cutInfo.

        So if we had a loan of 1000 tokens, 25 goes to cutInfo 1, ~4.16 goes to cutInfo2.1, and ~20.4 to cutInfo2.
     */   
    pub fun metadataRoyaltiesToRoyaltyCuts(tokenInfo: TokenInfo, mdRoyalties: [MetadataViews.Royalties]): [RoyaltyCut] {
        if mdRoyalties.length == 0 {
            return []
        }
        
        let royaltyCuts: {Address: RoyaltyCut} = {}

        // the cut for each Royalties object is split evenly, regardless of the hypothetical value
        // difference between each asset they came from.
        let cutPerRoyalties = 1.0 / UFix64(mdRoyalties.length)

        // for each royalties struct, calculate the sum totals to go to each benefiary
        // then roll them up in 
        for royalties in mdRoyalties {
            // we need to know the total % taken from this set of royalties so that we can
            // calculate the total proportion taken from each Royalty struct inside of it. 
            // Unfortunately there isn't another way to do this since the total cut amount 
            // isn't pre-populated by the Royalties standard
            var royaltiesTotal = 0.0
            for cutInfo in royalties.getRoyalties() {
                royaltiesTotal = royaltiesTotal + cutInfo.cut
            }

            for cutInfo in royalties.getRoyalties() {
                if royaltyCuts[cutInfo.receiver.address] == nil {
                    let cap = getAccount(cutInfo.receiver.address).getCapability<&{FungibleToken.Receiver}>(tokenInfo.receiverPath)
                    royaltyCuts[cutInfo.receiver.address] = RoyaltyCut(cap: cap, percentage: 0.0)
                }

                royaltyCuts[cutInfo.receiver.address]!.add(p: cutInfo.cut / royaltiesTotal * cutPerRoyalties)
            }
        }

        return royaltyCuts.values
    }

    pub struct RoyaltyCut {
        pub let cap: Capability<&{FungibleToken.Receiver}>
        pub var percentage: UFix64

        init(cap: Capability<&{FungibleToken.Receiver}>, percentage: UFix64) {
            self.cap = cap
            self.percentage = percentage
        }

        pub fun add(p: UFix64) {
            self.percentage = self.percentage + p
        }
    }

    access(account) fun distributeRoyalties(royaltyCuts: [RoyaltyCut], vault: @FungibleToken.Vault) {
        let depositor = FlowtyUtils.getDepositor()
        FlowtyUtils.distributeRoyaltiesWithDepositor(royaltyCuts: royaltyCuts, depositor: depositor, vault: <-vault)
    }

    pub fun distributeRoyaltiesWithDepositor(royaltyCuts: [RoyaltyCut], depositor: &LostAndFound.Depositor, vault: @FungibleToken.Vault) {
        let depositor = FlowtyUtils.getDepositor()
        let startBalance = vault.balance
        for index, rs in royaltyCuts {
            if index == royaltyCuts.length - 1 {
                depositor.trySendResource(item: <-vault, cap: rs.cap, memo: "flowty royalty distribution", display: nil)  
                return 
            }
            depositor.trySendResource(item: <-vault.withdraw(amount: startBalance * rs.percentage), cap: rs.cap, memo: "flowty royalty distribution", display: nil)
        }
        destroy vault
    }

    // getAllowedTokens
    // return an array of types that are able to be used as the payment type
    // for loans
    pub fun getAllowedTokens(): [Type] {
        var supportedTokens = self.Attributes["supportedTokens"]
        if supportedTokens == nil {
            return []
        }
        
        let tokens = supportedTokens! as! {Type: TokenInfo}
        return tokens.keys
    }

    // isTokenSupported
    // check if the given type is able to be used as payment
    pub fun isTokenSupported(type: Type): Bool {
        for t in FlowtyUtils.getAllowedTokens() {
            if t == type {
                return true
            }
        }

        return false
    }

    access(account) fun depositToLostAndFound(
        redeemer: Address,
        item: @AnyResource,
        memo: String?,
        display: MetadataViews.Display?
    ) {
        let depositor = FlowtyUtils.account.borrow<&LostAndFound.Depositor>(from: LostAndFound.DepositorStoragePath)
        if depositor == nil {
            let depositEstimate <- LostAndFound.estimateDeposit(redeemer: redeemer, item: <- item, memo: memo, display: display)

            let flowtyFlowVault = self.account.borrow<&FlowToken.Vault{FungibleToken.Provider}>(from: /storage/flowTokenVault)
            assert(flowtyFlowVault != nil, message: "FlowToken vault is not set up")
            let storagePaymentVault <- flowtyFlowVault!.withdraw(amount: depositEstimate.storageFee)

            let item <- depositEstimate.withdraw()
            destroy depositEstimate

            let flowtyFlowReceiver = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)

            LostAndFound.deposit(
                redeemer: redeemer,
                item: <- item,
                memo: memo,
                display: display,
                storagePayment: &storagePaymentVault as &FungibleToken.Vault,
                flowTokenRepayment: flowtyFlowReceiver
            )

            flowtyFlowReceiver.borrow()!.deposit(from: <-storagePaymentVault)   
            return
        }

        depositor!.deposit(redeemer: redeemer, item: <-item, memo: memo, display: display)

    }

    access(account) fun trySendFungibleTokenVault(vault: @FungibleToken.Vault, receiver: Capability<&{FungibleToken.Receiver}>){
        if !receiver.check() {
            self.depositToLostAndFound(
                redeemer: receiver.address,
                item: <- vault,
                memo: nil,
                display: nil,
            )
        } else {
            receiver.borrow()!.deposit(from: <-vault)
        }
    }

    access(account) fun trySendNFT(nft: @NonFungibleToken.NFT, receiver: Capability<&{NonFungibleToken.CollectionPublic}>) {
        if !receiver.check() {
            self.depositToLostAndFound(
                redeemer: receiver.address,
                item: <- nft,
                memo: nil,
                display: nil,
            )
        } else {
            receiver.borrow()!.deposit(token: <-nft)
        }
    }

    pub struct BalancePaths {
        access(self) var paths: {String: PublicPath}

        access(account) fun get(key: String): PublicPath? {
            return self.paths[key]
        }
        

        access(account) fun set(key: String, path: PublicPath): Bool {
            let pathOverwritten = self.paths[key] != nil

            self.paths[key] = path

            return pathOverwritten
        }

        init() {
            self.paths = {}
        }
    }

    access(account) fun balancePaths(): BalancePaths {
        if self.Attributes["balancePaths"] == nil {
            self.Attributes["balancePaths"] = BalancePaths()
        }

        return self.Attributes["balancePaths"]! as! BalancePaths
    }

    pub fun getTokenBalance(address: Address, vaultType: Type): UFix64 {
        // get the account for the address we want the balance for
        let user = getAccount(address)

        // get the balance path for the user for the given fungible token
        let balancePath = self.balancePaths().get(key: vaultType.identifier)

        assert(balancePath != nil, message: "No balance path configured for ".concat(vaultType.identifier))
        
        // get the FungibleToken.Balance capability located at the path
        let vaultCap = user.getCapability<&{FungibleToken.Balance}>(balancePath!)
        
        // check the capability exists
        if !vaultCap.check() {
            return 0.0
        }

        // borrow the reference
        let vaultRef = vaultCap.borrow()

        // get the balance of the account
        return vaultRef?.balance ?? 0.0
    }


    pub fun getRoyaltyRate(_ nft: &NonFungibleToken.NFT): UFix64 {
        // check for overrides first

        if RoyaltiesOverride.get(nft.getType()) {
            return 0.0
        }

        let royalties = nft.resolveView(Type<MetadataViews.Royalties>()) as! MetadataViews.Royalties?
        if royalties == nil {
            return 0.0
        }

        // count the royalty rate now, then we'll pick them all up after the fact when a loan is settled?
        var total = 0.0
        for r in royalties!.getRoyalties() {
            total = total + r.cut
        }

        return total
    }


    init() {
        self.Attributes = {}

        self.FlowtyUtilsStoragePath = /storage/FlowtyUtils

        let utilsAdmin <- create FlowtyUtilsAdmin()
        self.account.save(<-utilsAdmin, to: self.FlowtyUtilsStoragePath)

        let flowTokenReceiver = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let depositor <- LostAndFound.createDepositor(flowTokenReceiver, lowBalanceThreshold: 10.0)
        self.account.save(<-depositor, to: LostAndFound.DepositorStoragePath)
    }
}
 