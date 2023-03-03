pub contract TFCSoulbounds {

    // Events
    pub event AddedItemToSoulbounds(itemName: String)
    pub event RemovedItemFromSoulbounds(itemName: String)
    pub event ContractInitialized()

    // Named Paths
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath

    access (contract) var soulboundItems: {String: Bool}

    pub resource Administrator {

        pub fun addNewItemToSoulboundList(itemName: String) {
            TFCSoulbounds.soulboundItems.insert(key: itemName, true)
            emit AddedItemToSoulbounds(itemName: itemName)
        }

        pub fun removeItemFromSoulboundList(itemName: String) {
            TFCSoulbounds.soulboundItems.remove(key: itemName)
            emit RemovedItemFromSoulbounds(itemName: itemName)
        }
    }

    pub fun getSoulboundItemsList(): [String] {
        return self.soulboundItems.keys
    }

    pub fun isItemSoulbound(itemName: String): Bool {
        return self.soulboundItems.containsKey(itemName)
    }

    init() {
        // Set our named paths
        self.AdminStoragePath = /storage/TFCSoulboundsAdmin
        self.AdminPrivatePath=/private/TFCSoulboundsAdminPrivate

        // Initialize Vars
        self.soulboundItems = {}

        // Create a Admin resource and save it to storage
        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
        self.account.link<&Administrator>(self.AdminPrivatePath, target: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
 