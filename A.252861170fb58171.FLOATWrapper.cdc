
    import FLOAT from 0x2d4c3caffbeab845
    import MetadataWrapper from 0x252861170fb58171
    import MetadataViews from 0x1d7e57aa55817448

    pub contract FLOATWrapper {

    pub fun getRef(_ account: Address, _ id: UInt64): &FLOAT.NFT?{
        if let collection = getAccount(account).getCapability(FLOAT.FLOATCollectionPublicPath)
                                               .borrow<&FLOAT.Collection{FLOAT.CollectionPublic}>(){
            if let nft = collection.borrowFLOAT(id: id){
                return nft
            }
        }
        return nil
    } 
       
    pub fun getContractAttributes(): {String:AnyStruct} {
        return {
            "_contract.name":            "FLOAT",
            "_contract.borrow_func":     "borrowFLOAT",
            "_contract.public_iface":    "FLOAT.Collection{FLOAT.CollectionPublic}",
            "_contract.address":         0x2d4c3caffbeab845,
            "_contract.storage_path":    FLOAT.FLOATCollectionStoragePath,
            "_contract.public_path":     FLOAT.FLOATCollectionPublicPath,
            "_contract.external_domain": "https://floats.city/",
            "_contract.type":            Type<@FLOAT.NFT>()
        }
    }

    pub fun getNFTAttributes(_ float: &FLOAT.NFT?): {String:AnyStruct}{

        let display = float!.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display


        return {
            "id": float!.id,
            "uuid": float!.uuid,
            "_display.name": display.name,
            "_display.description": display.description,
            "_display.thumbnail":float!.eventImage,
            //medias 
            "_medias": [
                MetadataViews.Media(file: MetadataViews.HTTPFile(url: float!.eventImage) , mediaType: "image")
            ],
            //externalURL
            "_externalURL": "https://floats.city/".concat((float!.owner!.address as Address).toString()).concat("/float/").concat(float!.id.toString()),
            //other traits 
            "eventName" : float!.eventName,
                "eventDescription" : float!.eventDescription,
                "eventHost" : (float!.eventHost as Address).toString(),
                "eventId" : float!.eventId.toString(),
                "eventImage" : float!.eventImage,
                "serial": float!.serial,
            "dateReceived": float!.dateReceived,
            "royaltyAddress": "0x5643fd47a29770e7",
            "royaltyPercentage": "5.0", 
            "type": float!.getType()           
        }
    }

    
    pub var contractData: {String:AnyStruct}

    pub fun setup(){
        destroy self.account.load<@AnyResource>(from: /storage/FLOAT)
        self.account.save(<- create Wrapper(contractData: self.contractData), to: /storage/FLOAT)

        self.account.unlink(/public/FLOAT)
        self.account.link<&{MetadataWrapper.WrapperInterface}>(/public/FLOAT, target: /storage/FLOAT)
        
        self.account.unlink(FLOAT.FLOATCollectionPublicPath)
        self.account.link<&{MetadataWrapper.WrapperInterface}>(FLOAT.FLOATCollectionPublicPath, target: /storage/FLOAT)
    }

    pub init(){
        self.contractData = self.getContractAttributes()
        self.setup()
    }

    pub resource Wrapper : MetadataWrapper.WrapperInterface {
       
        pub fun setData(address: Address, id: UInt64){
            self.address = address
            self.id = id
            self.attributes = {}
            self.views = {}
            
            for view in MetadataWrapper.baseViews(){
                self.views[view] = "generated"
            }

            if let nft = FLOATWrapper.getRef(self.address, self.id){
                self.attributes = FLOATWrapper.getNFTAttributes(nft)
                if let nftMetadata = nft as? &AnyResource{MetadataViews.Resolver} {
                    for type in nftMetadata.getViews(){
                        self.views[type]="original"              
                    }
                    
                }
            }
        }
        
        pub var address: Address
        pub var type: Type
        pub var id : UInt64
        pub var publicPath : PublicPath

        pub var contractData: {String:AnyStruct}
        pub var attributes: {String:AnyStruct}
        pub var views: {Type: String}
    
        pub fun resolveView(_ view: Type): AnyStruct? {       
            if let nft = FLOATWrapper.getRef(self.address, self.id){         
            if let viewLocation = self.views[view] {
                if viewLocation=="generated"{
                    return MetadataWrapper.buildView(view, self.attributes)
                }
                
                if let nftMetadata = nft as? &AnyResource{MetadataViews.Resolver} {
                    if let resolved = nftMetadata.resolveView(view){
                        return resolved
                    }
                }
                }
            }
            return nil 
        }

       
        pub fun getViews(): [Type] {
            return self.views.keys
        }

        init(contractData: {String:AnyStruct}){
            self.id = 0
            self.publicPath = FLOAT.FLOATCollectionPublicPath
            self.address = FLOATWrapper.account.address 
            self.type = Type<@FLOAT.NFT>()
            self.contractData = contractData
            self.attributes = {}
            self.views = {}
        }  
    }

    }
    