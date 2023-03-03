pub contract DynamicImport {
    pub resource interface ImportInterface{
         pub fun dynamicImport(name: String): auth &AnyStruct?     
    }

    pub fun dynamicImport(address: Address, contractName: String): auth &AnyStruct?{
        
        if let borrowed = self.account.borrow<&{ImportInterface}>(from:StoragePath(identifier: "A".concat(address.toString()))!){
            return borrowed.dynamicImport(name: contractName)
        }
        return nil
    }
}

