
pub contract Traceability {
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub event ContractInitialized()
    pub event ProductCodeCreate(code:String)
    pub event ProductCodeRemove(code:String)


    pub resource interface ProductCodePublic {
        pub fun ProductCodeExist(code:String):Bool 
        pub fun GetAllProductCodes():[String] 
        pub fun ProductCodesLength():Integer
    }

    pub resource ProductCodeList: ProductCodePublic{
        pub var CodeMap: { String : Bool }

        init() {
            self.CodeMap = {}
        }

        // public interface contains function that everyone can call
        pub fun ProductCodesLength():Integer{
            return self.CodeMap.length
        }

        pub fun ProductCodeExist(code:String):Bool {
            return self.CodeMap.containsKey(code)
        }

        pub fun GetAllProductCodes():[String] {
            return self.CodeMap.keys
        }

        // only account owner can call the rest of functions
        pub fun AddProductCode(code:String){
            self.CodeMap[code] = true
            emit ProductCodeCreate(code: code)
        }

        pub fun RemoveProductCode(code:String){
            if self.CodeMap.containsKey(code) {
                self.CodeMap.remove(key: code)
                emit ProductCodeRemove(code: code)
            }
        }
    }

    pub fun createCodeList(): @ProductCodeList {
        return <-create ProductCodeList()
    }

    init() {
        self.CollectionStoragePath = /storage/CodeCollection
        self.CollectionPublicPath = /public/CodeCollection

		// store an empty ProductCode Collection in account storage
        self.account.save(<-self.createCodeList(), to: self.CollectionStoragePath)

        // publish a reference to the Collection in storage
        // create a public capability for the collection
        self.account.link<&Traceability.ProductCodeList{ProductCodePublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )
        emit ContractInitialized()
	}
}