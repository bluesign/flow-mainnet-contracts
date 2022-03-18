import FUSD from 0x3c5959b568896393

pub contract FlowtyUtils {
    access(contract) var Attributes: {String: AnyStruct}

    pub let FlowtyUtilsStoragePath: StoragePath

    pub resource FlowtyUtilsAdmin {
        // addSupportedTokenType
        // add a supported token type that can be used in Flowty loans
        pub fun addSupportedTokenType(type: Type) {
            var supportedTokens = FlowtyUtils.Attributes["supportedTokens"]
            if supportedTokens == nil {
                supportedTokens = [Type<@FUSD.Vault>()] as! [Type] 
            }

            let tokens = supportedTokens! as! [Type]

            if !FlowtyUtils.isTokenSupported(type: type) {
                tokens.append(type)
            }

            FlowtyUtils.Attributes["supportedTokens"] = tokens
        }
    }

    pub fun getSupportedTokens(): AnyStruct {
        return self.Attributes["supportedTokens"]!
    }

    // getAllowedTokens
    // return an array of types that are able to be used as the payment type
    // for loans
    pub fun getAllowedTokens(): [Type] {
        var supportedTokens = self.Attributes["supportedTokens"]
        return supportedTokens != nil ? supportedTokens! as! [Type] : [Type<@FUSD.Vault>()]
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

    

    init() {
        self.Attributes = {}

        self.FlowtyUtilsStoragePath = /storage/FlowtyUtils

        let utilsAdmin <- create FlowtyUtilsAdmin()
        self.account.save(<-utilsAdmin, to: self.FlowtyUtilsStoragePath)
    }
}