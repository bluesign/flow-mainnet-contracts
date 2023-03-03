import FlowToken from 0x1654653399040a61
import DynamicImport from 0x252861170fb58171

pub contract Proxy_0x1654653399040a61 {
    
    pub resource ContractObject : DynamicImport.ImportInterface {

        pub fun dynamicImport(name: String): auth &AnyStruct?{  
            if name=="FlowToken"{
                return &FlowToken as auth &AnyStruct
            }
            return nil 
        }
        
    }
    
    init(){
        self.account.save(<-create ContractObject(), to: /storage/A0x1654653399040a61)
    }

}   



