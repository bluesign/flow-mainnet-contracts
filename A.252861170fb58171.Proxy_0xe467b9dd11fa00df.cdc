import FlowServiceAccount from 0xe467b9dd11fa00df
import DynamicImport from 0x252861170fb58171

pub contract Proxy_0xe467b9dd11fa00df {
    
    pub resource ContractObject : DynamicImport.ImportInterface {

        pub fun dynamicImport(name: String): auth &AnyStruct?{  
            if name=="FlowServiceAccount"{
                return &FlowServiceAccount as auth &AnyStruct
            }
            return nil 
        }
        
    }
    
    init(){
        self.account.save(<-create ContractObject(), to: /storage/A0xe467b9dd11fa00df)
    }

}   



