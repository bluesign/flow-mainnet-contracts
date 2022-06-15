// mainnet
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

// testnet
// import NonFungibleToken from 0x631e88ae7f1d7c20
// import MetadataViews from 0x631e88ae7f1d7c20

// local
//  import NonFungibleToken from "./NonFungibleToken.cdc"
//  import MetadataViews from "./MetadataViews.cdc"

 pub contract ArleeSceneVoucher : NonFungibleToken{

    // Total number of ArleeSceneVoucher NFT in existence
    pub var totalSupply: UInt64 

    // Active Status
    pub var mintable: Bool

    // Free Mint List and quota
    access(account) var freeMintAcct : {Address : UInt64}

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Created(id: UInt64, species: String, royalties: [Royalty], creator:Address)

    pub event FreeMintListAcctUpdated(address: Address, mint:UInt64)
    pub event FreeMintListAcctRemoved(address: Address)

    pub event MarketplaceCutUpdate(oldCut:UFix64, newCut:UFix64)

    // Paths
    pub let CollectionStoragePath : StoragePath
    pub let CollectionPublicPath : PublicPath

    // Royalty
    pub var marketplaceCut: UFix64
    pub let arlequinWallet: Address

    // Royalty Struct (For later royalty and marketplace implementation)
    pub struct Royalty{
        pub let creditor: String
        pub let wallet: Address
        pub let cut: UFix64

        init(creditor:String, wallet: Address, cut: UFix64){
            self.creditor = creditor
            self.wallet = wallet
            self.cut = cut
        }
    }

    // ArleeSceneVoucher NFT (includes the species, metadata)
    pub resource NFT : NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let species: String
        access(contract) let royalties: [Royalty]

        init(species: String, royalties:[Royalty]){
            self.id = ArleeSceneVoucher.totalSupply
            self.species = species
            self.royalties = royalties

            // update totalSupply
            ArleeSceneVoucher.totalSupply = ArleeSceneVoucher.totalSupply +1
        }

        // Function to return royalty
        pub fun getRoyalties(): [Royalty] {
            return self.royalties
        }

        // MetadataViews Implementation
        pub fun getViews(): [Type] {
          return [Type<MetadataViews.Display>(), 
                  Type<[Royalty]>()]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name : "Arlee Scene NFT Voucher" ,
                        description : "This voucher entitles the owner to claim a ".concat(self.species).concat(" Arlequin NFT."),
                        thumbnail : MetadataViews.HTTPFile(url:"https://painter.arlequin.gg/voucher/".concat(self.species))
                    )

                case Type<[Royalty]>():
                    return self.royalties
            } 
            return nil
        }
    }
    

    // Collection Interfaces Needed for borrowing NFTs
    pub resource interface CollectionPublic {
        pub fun getIDs() : [UInt64]
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(collection: @NonFungibleToken.Collection)
        pub fun borrowNFT(id : UInt64) : &NonFungibleToken.NFT
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}
        pub fun borrowArleeSceneVoucher(id : UInt64) : &ArleeSceneVoucher.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Component reference: The ID of the returned reference is incorrect"
            }
        }
    }


    // Collection that implements NonFungible Token Standard with Collection Public and MetaDataViews
    pub resource Collection : CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs : @{UInt64: NonFungibleToken.NFT}

        init(){
            self.ownedNFTs <- {}
        }

        destroy(){
            destroy self.ownedNFTs
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot find Alree Scene Voucher NFT in your Collection, id: ".concat(withdrawID.toString()))

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <- token
        }

        pub fun batchWithdraw(withdrawIDs: [UInt64]): @NonFungibleToken.Collection{
            let collection <- ArleeSceneVoucher.createEmptyCollection()
            for id in withdrawIDs {
                let nft <- self.ownedNFTs.remove(key: id) ?? panic("Cannot find Arlee Scene Voucher NFT in your Collection, id: ".concat(id.toString()))
                collection.deposit(token: <- nft) 
            }
            return <- collection
        }

        pub fun deposit(token: @NonFungibleToken.NFT){
            let token <- token as! @ArleeSceneVoucher.NFT

            let id:UInt64 = token.id

            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id:id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun batchDeposit(collection: @NonFungibleToken.Collection){
            for id in collection.getIDs() {
                let token <- collection.withdraw(withdrawID: id)
                self.deposit(token: <- token)
            }
            destroy collection
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowArleeSceneVoucher(id: UInt64): &ArleeSceneVoucher.NFT? {
            if self.ownedNFTs[id] == nil {
                return nil
            }

            let nftRef = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let ref = nftRef as! &ArleeSceneVoucher.NFT

            return ref
            
        }

        //MetadataViews Implementation
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
            let nftRef = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let ArleeSceneVoucherRef = nftRef as! &ArleeSceneVoucher.NFT

            return ArleeSceneVoucherRef as &{MetadataViews.Resolver}
        }

    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    /* Query Function (Can also be done in Arlee Contract) */
    // return true if the address holds the Scene NFT
    pub fun getArleeSceneVoucherIDs(addr: Address): [UInt64]? {
        let holderCap = getAccount(addr).getCapability<&ArleeSceneVoucher.Collection{ArleeSceneVoucher.CollectionPublic}>(ArleeSceneVoucher.CollectionPublicPath)
        
        if holderCap.borrow() == nil {
            return nil
        }
        
        let holderRef = holderCap.borrow() ?? panic("Cannot borrow Arlee Scene Voucher Collection Reference")
        return holderRef.getIDs()

    }

    pub fun getRoyalty(): [Royalty] {
        return [Royalty(creditor: "Arlequin", wallet: ArleeSceneVoucher.arlequinWallet, cut: ArleeSceneVoucher.marketplaceCut)]
    }

    pub fun getFreeMintAcct(): {Address : UInt64} {
        return ArleeSceneVoucher.freeMintAcct
    }

    pub fun getFreeMintQuota(addr: Address) : UInt64? {
        return ArleeSceneVoucher.freeMintAcct[addr]
    }

    /* Admin Function */
    access(account) fun setMarketplaceCut(cut: UFix64) {
        let oldCut = ArleeSceneVoucher.marketplaceCut
        ArleeSceneVoucher.marketplaceCut = cut

        emit MarketplaceCutUpdate(oldCut:oldCut, newCut:cut)
    }

    access(account) fun mintVoucherNFT(recipient:&ArleeSceneVoucher.Collection{ArleeSceneVoucher.CollectionPublic}, species:String) {
        pre{
            ArleeSceneVoucher.mintable : "Public minting is not available at the moment."
        }
        // further checks
        assert(recipient.owner != nil , message:"Cannot pass in a Collection reference with no owner")
        let ownerAddr = recipient.owner!.address

        let royalties = ArleeSceneVoucher.getRoyalty()
        let newNFT <- create ArleeSceneVoucher.NFT(species: species, royalties:royalties)
        
        emit Created(id:newNFT.id, species:species, royalties:royalties, creator: ownerAddr)
        recipient.deposit(token: <- newNFT) 
    }

    access(account) fun addFreeMintAcct(addr: Address, mint:UInt64) {
        pre{
            ArleeSceneVoucher.freeMintAcct[addr] == nil : "This address is already registered in Free Mint list, please use other functions for altering"
        }
        ArleeSceneVoucher.freeMintAcct[addr] = mint

        emit FreeMintListAcctUpdated(address: addr, mint:mint)
    }

    access(account) fun batchAddFreeMintAcct(list:{Address: UInt64}) {
        for addr in list.keys {
            if ArleeSceneVoucher.freeMintAcct[addr] == nil {
                ArleeSceneVoucher.addFreeMintAcct(addr: addr, mint:list[addr]!)
            } else {
                ArleeSceneVoucher.addFreeMintAcctQuota(addr: addr, additionalMint: list[addr]!)
            }
        }
    }

    access(account) fun removeFreeMintAcct(addr: Address) {
        pre{
            ArleeSceneVoucher.freeMintAcct[addr] != nil : "This address is not given Free Mint Quota."
        }
        ArleeSceneVoucher.freeMintAcct.remove(key: addr)

        emit FreeMintListAcctRemoved(address: addr)
    }

    access(account) fun setFreeMintAcctQuota(addr: Address, mint: UInt64) {
        pre{
            mint > 0 : "Minting limit cannot be smaller than 1"
            ArleeSceneVoucher.freeMintAcct[addr] != nil : "This address is not given Free Mint Quota"
        }
        ArleeSceneVoucher.freeMintAcct[addr] = mint

        emit FreeMintListAcctUpdated(address: addr, mint:mint)
    }

    access(account) fun addFreeMintAcctQuota(addr: Address, additionalMint: UInt64) {
        pre{
            ArleeSceneVoucher.freeMintAcct[addr] != nil : "This address is not given Free Mint Quota"
        }
        ArleeSceneVoucher.freeMintAcct[addr] = additionalMint + ArleeSceneVoucher.freeMintAcct[addr]!

        emit FreeMintListAcctUpdated(address: addr, mint:ArleeSceneVoucher.freeMintAcct[addr]!)
    }

    access(account) fun setMintable(mintable: Bool) {
        ArleeSceneVoucher.mintable = mintable
    }

    init(){
        self.totalSupply = 0

        self.mintable = false
        
        self.freeMintAcct = {}

        // Paths
        self.CollectionStoragePath = /storage/ArleeSceneVoucher
        self.CollectionPublicPath = /public/ArleeSceneVoucher

        // Royalty
        self.marketplaceCut = 0.05
        self.arlequinWallet = self.account.address

        // Setup Account 
        
        self.account.save(<- ArleeSceneVoucher.createEmptyCollection() , to: ArleeSceneVoucher.CollectionStoragePath)
        self.account.link<&ArleeSceneVoucher.Collection{ArleeSceneVoucher.CollectionPublic, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(ArleeSceneVoucher.CollectionPublicPath, target:ArleeSceneVoucher.CollectionStoragePath)
        
    }
        
 }