
pub contract MetadataViews {


    pub resource interface Resolver {
        pub fun getViews(): [Type]
        pub fun resolveView(_ view: Type): AnyStruct?
    }


    pub resource interface ResolverCollection {
        pub fun borrowViewResolver(id: UInt64): &{Resolver}
        pub fun getIDs(): [UInt64]
    }


    pub struct Display {
        // 作品名称
        pub let name: String
        pub let taskId: String
        // 作品描述
        pub let description: String
        // 缩略图路径
        pub let thumbnail: String

        init(
            name: String,
            description: String,
            taskId: String,
            thumbnail: String
        ) {
            self.name = name
            self.description = description
            self.taskId = taskId
            self.thumbnail = thumbnail
        }
    }


    pub struct interface File {
        pub fun uri(): String
    }


    pub struct HTTPFile: File {
        pub let url: String
        
        init(url: String) {
            self.url = url
        }
        
        pub fun uri(): String {
            return self.url
        }
        
    }

    pub struct IPFSFile: File {

        pub let cid: String
        pub let path: String?

        init(cid: String, path: String?) {
            self.cid = cid
            self.path = path
        }

        // This function returns the IPFS native URL for this file.
        //
        // Ref: https://docs.ipfs.io/how-to/address-ipfs-on-web/#native-urls
        //
        pub fun uri(): String {
            if let path = self.path {
                return "ipfs://".concat(self.cid).concat("/").concat(path)
            }
            
            return "ipfs://".concat(self.cid)
        }
    }
}
