pub contract Circle{
//Circle is the contract; circleNFT is the NFT
    pub var totalSupply: UInt64
    
    pub resource circleNFT {
        pub let badge_id: UInt64
        pub let circle: String
        
        init(){//Initialize the the badge id 
            self.badge_id = Circle.totalSupply
            Circle.totalSupply = Circle.totalSupply + (1 as UInt64)
            self.circle = "Producer"
        }
    }

    pub resource interface iCollectionPublic {
        //get a list of the ids
        pub fun getIDs(): [UInt64]
        pub fun deposit(token: @circleNFT)
    }

    pub resource circleCollection: iCollectionPublic {
        //Instead of storing and acccessing storage path we will access NFT 
        //from a collection. Only one thing can be stored in storage

        pub var ownedNFTs: @{UInt64:circleNFT}
        //map a id to an NFT (the badge)

        pub fun deposit(token:@circleNFT){
            /*The force-assignment operator (<-!) assigns a resource-typed 
            value to an optional-typed variable if the variable is nil.  */
            self.ownedNFTs[token.badge_id]<-! token
        }

        pub fun withdraw(id:UInt64): @circleNFT{
            let token <-self.ownedNFTs.remove(key: id)?? panic("This collection does not contain NFT with that id")

            return <- token
        }

        pub fun getIDs(): [UInt64]
        {
            return self.ownedNFTs.keys            
        }

        init(){
            self.ownedNFTs <- {}
        }
        destroy(){
            //You have a resouce inside of a resource so you have a destroy function
            destroy self.ownedNFTs
        }
    }

    pub fun createCircleCollection(): @circleCollection{
        return <-create circleCollection()

    }

    pub resource NFTMinter{
        pub fun createCircleNFT():@circleNFT{
            return <-create circleNFT()
        }
        init(){
            
        }
    }

    pub fun createCircleNFT(): @circleNFT{
        return <-create circleNFT()
    }
    init(){
        self.totalSupply = 0
        self.account.save(<-create NFTMinter(), to: /storage/adminMinter)
        
    }
}