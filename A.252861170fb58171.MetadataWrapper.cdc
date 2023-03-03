import MetadataViews from 0x1d7e57aa55817448

pub contract MetadataWrapper {

    pub fun baseViews(): [Type]{
        return [
            Type<MetadataViews.Display>(),
            Type<MetadataViews.Medias>(),
            Type<MetadataViews.Traits>(),
            Type<MetadataViews.NFTView>()
        ]
    }
    pub fun buildView(_ view: Type, _ attributes: {String:AnyStruct}): AnyStruct?{
        switch view {
                    case Type<MetadataViews.Display>():
                        return MetadataViews.Display(
                            name: attributes["_display.name"]! as! String,
                            description: attributes["_display.description"]! as! String,
                            thumbnail: MetadataViews.HTTPFile(url: attributes["_display.thumbnail"]! as! String)
                        )

                    case Type<MetadataViews.Medias>():
                        if let medias = attributes["_medias"]{
                            var items:[MetadataViews.Media] = []
                            for media in (medias as! [MetadataViews.Media]) {
                                items.append(media as! MetadataViews.Media)
                            }
                            return MetadataViews.Medias(
                                items:items
                            )
                        }
                        return nil 
                    case Type<MetadataViews.ExternalURL>():
                        if let url = attributes["_externalURL"]{
                            return MetadataViews.ExternalURL(url as! String)
                        }
                        return nil

                    case Type<MetadataViews.Traits>():
                        var traits:[MetadataViews.Trait] = []
                        for k in attributes.keys{
                            if k[0]!="_"{
                                traits.append(MetadataViews.Trait(name:k ,value: attributes[k]!, displayType: nil, rarity: nil))
                            }
                        }
                        return MetadataViews.Traits(traits)
  
                     case Type<MetadataViews.NFTView>():
                        return MetadataViews.NFTView(
                                id: attributes["id"]! as! UInt64,
                                uuid: attributes["uuid"]! as! UInt64,
                                display: self.buildView(Type<MetadataViews.Display>(), attributes) as! MetadataViews.Display?,
                                externalURL: self.buildView(Type<MetadataViews.ExternalURL>(), attributes) as! MetadataViews.ExternalURL?,
                                collectionData: self.buildView(Type<MetadataViews.NFTCollectionData>(), attributes) as! MetadataViews.NFTCollectionData?,
                                collectionDisplay: self.buildView(Type<MetadataViews.NFTCollectionDisplay>(), attributes) as! MetadataViews.NFTCollectionDisplay?, 
                                royalties: self.buildView(Type<MetadataViews.Royalties>(), attributes) as! MetadataViews.Royalties?,
                                traits: self.buildView(Type<MetadataViews.Traits>(), attributes) as! MetadataViews.Traits?
                        )
        }
        return nil 
    }

    pub resource interface WrapperInterface{
        pub var address: Address
        pub var id : UInt64
        pub var type: Type
        pub var publicPath : PublicPath
        pub var contractData: {String:AnyStruct}
        pub var attributes: {String:AnyStruct}

        pub fun getViews(): [Type] 
        pub fun resolveView(_ view: Type): AnyStruct?
        pub fun setData(address: Address, id: UInt64)
    }
resolveViews
    pub fun resolveViewsByPath(_ path: PublicPath, address: Address, ids: [UInt64], views: [Type]): {UInt64: [AnyStruct]}{
        var res: {UInt64: [AnyStruct]} = {}

        if let wrapper = getAccount(self.account.address).getCapability(path).borrow<&{WrapperInterface}>(){
            for id in ids{
                wrapper.setData(address: address, id: id)
                var v: [AnyStruct]= []
                for view in views{
                    if let resolved = wrapper.resolveView(view){
                        v.append(resolved)
                    }
                }
                res[id]=v
            }
        }

        return res
    }

    pub fun resolveViews(_ type: String,  address: Address, ids: [UInt64], views: [Type]): {UInt64: [AnyStruct]}{
        var res: {UInt64: [AnyStruct]} = {}

        if let wrapper = self.account.borrow<&{WrapperInterface}>(from: StoragePath(identifier:type)!){
            for id in ids{
                wrapper.setData(address: address, id: id)
                var v: [AnyStruct]= []
                for view in views{
                    if let resolved = wrapper.resolveView(view){
                        v.append(resolved)
                    }
                }
                res[id]=v
            }
        }

        return res
    }
}



