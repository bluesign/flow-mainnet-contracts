import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract ByteNextBridge {
    pub let UserStoragePath: StoragePath;
    pub let AdminStoragePath: StoragePath;
    pub let UserPublicPath: PublicPath;

    pub event FungibleRequested(account: Address, tokenType: String, destinationChain: UInt64, amount: UFix64, recipient: String);
    pub event NonFungibleRequested(account: Address, collectionType: String, destinationChain: UInt64, ids: [UInt64], recipient: String);
    pub event UserFungibleVerified(account: Address, tokenType: String, amount: UFix64, hash: String);
    pub event UserNonFungibleVerified(account: Address, collectionType: String, ids: [UInt64], hash: String);
    pub event FungibleFulfilled(account: Address, tokenType: String, amount: UFix64);
    pub event NonFungibleFulfilled(account: Address, collectionType: String, ids: [UInt64]);

    access(self) let allowedChains: {UInt64: Bool};
    access(self) let allowedFungibleTokens: {String: Bool};
    access(self) let allowedNonFungibleTokens: {String: Bool};
    access(self) let chainAddressLengths: {UInt64: UInt64};
    access(self) let addedHashes: {String: Bool};
    access(self) var feeTokenType: String;
    access(self) let nonFungibleFees: {UInt64: UFix64};
    access(self) var maxNftCountPerTransaction: UInt64;
    access(self) var feeTokenReceiver: Capability<&AnyResource{FungibleToken.Receiver}>?;
    access(self) let fungibleTokenReceiver: {String: Capability<&AnyResource{FungibleToken.Receiver}>};
    access(self) let nonFungibleTokenReceiver: {String: Capability<&AnyResource{NonFungibleToken.Receiver}>};

    pub resource interface BridgeStorePublic {
        pub fun verifyFungibleForUser(
            tokens: @FungibleToken.Vault,
            hash: String);

        pub fun verifyNonFungibleForUser(
            collection: @NonFungibleToken.Collection,
            hash: String);

        pub fun getUserFungibleBalance(tokenType: String): UFix64;
        pub fun getUserNonFungibleIds(collectionType: String): [UInt64];
    }

    pub resource BridgeStore: BridgeStorePublic {
        access(self) let userVaults: @{String: FungibleToken.Vault};
        access(self) let userCollections: @{String: NonFungibleToken.Collection};
        
        init () {
            self.userVaults <- {};
            self.userCollections <- {};
        }

        destroy() {
            destroy self.userVaults;
            destroy self.userCollections;
        }

        /**
        User call this function to bridge their tokens to `destinationChain`
        */
        pub fun depositFungible(destinationChain: UInt64, tokens: @FungibleToken.Vault, recipient: String) {
            pre{
                ByteNextBridge.allowedChains[destinationChain] == true: "Destination chain is not supported";
                ByteNextBridge.chainAddressLengths[destinationChain] == UInt64(recipient.length): "recipient addres is invalid length";
                tokens.balance > 0.0: "amount to be bridge is zero";
            }

            let owner = self.owner??panic("owner is nil");

            var tokenAmount = tokens.balance;
            var tokenType = self.getTokenType(type: tokens.getType());

            if(!ByteNextBridge.isAllowedFungibleToken(tokenType: tokenType)){
                panic("Token type is not supported");
            }

            destroy tokens;

            // let fungibleTokenReceiver = ByteNextBridge.fungibleTokenReceiver[tokenType] ?? panic("fungibleTokenReceiver has not been configured");

            // //Transfer tokens to platform account
            // let receiverRef = fungibleTokenReceiver.borrow() ?? panic("Can not borrow fungibleTokenReceiver");
            // receiverRef.deposit(from: <- tokens);
            
            emit FungibleRequested(
                account: owner.address,
                tokenType: tokenType,
                destinationChain: destinationChain,
                amount: tokenAmount,
                recipient: recipient);
        }

        pub fun depositNonFungible(destinationChain: UInt64,
            collection: @NonFungibleToken.Collection, feeTokens: @FungibleToken.Vault, recipient: String) {
            pre{
                ByteNextBridge.allowedChains[destinationChain] == true: "Destination chain is not supported";
                ByteNextBridge.chainAddressLengths[destinationChain] == UInt64(recipient.length): "recipient addres is invalid length";
                collection.getIDs().length > 0: "There is no NFT to bridge";
                ByteNextBridge.nonFungibleTokenReceiver != nil: "nonFungibleTokenReceiver is not configured";
                collection.getIDs().length <= Int(ByteNextBridge.maxNftCountPerTransaction): "Reach the limitation of NFT quantity";
            }

            let owner = self.owner ?? panic("owner is nil");
            var collectionType: String = self.getTokenType(type: collection.getType());
            if(!ByteNextBridge.isAllowedNonFungibleToken(collectionType: collectionType)){
                    panic("NFT type is not supported");
            }

            if(ByteNextBridge.nonFungibleFees[destinationChain] != nil && ByteNextBridge.nonFungibleFees[destinationChain]! > 0.0){
                if(feeTokens.balance != ByteNextBridge.nonFungibleFees[destinationChain]!){
                    panic("Fee is invalid");
                }
                if(feeTokens.getType().identifier != ByteNextBridge.feeTokenType){
                    panic("Invalid fee token type");
                }

                if(ByteNextBridge.feeTokenReceiver == nil){
                    panic("feeTokenReceiver has not been configured yet");
                }

                let receiverRef = ByteNextBridge.feeTokenReceiver!.borrow() ?? panic ("Can not borrow feeTokenReceiver reference");

                receiverRef!.deposit(from: <- feeTokens);
            }else{
                if(feeTokens.balance > 0.0){
                    panic("feeTokens has tokens");
                }
                destroy feeTokens;
            }

            let ids = collection.getIDs();

            let nonFungibleTokenReceiver = ByteNextBridge.nonFungibleTokenReceiver[collectionType] ?? panic("nonFungibleTokenReceiver has not been configured");

            //Burn NFT
            let receiverRef = nonFungibleTokenReceiver.borrow() ?? panic("Can not borrow nonFungibleTokenReceiver");
            for id in ids {
              receiverRef.deposit(token: <- collection.withdraw(withdrawID: id));
            }
            
            destroy collection;

            emit NonFungibleRequested(
                account: owner.address,
                collectionType: collectionType,
                destinationChain: destinationChain,
                ids: ids,
                recipient: recipient
            );
        }

        /**
        * Admins or any user can call this function to deposit specific fund for specific user
        * Normally, when a bridging is detected, admin will call this function so that user can fulfill their tokens
        */
        pub fun verifyFungibleForUser(tokens: @FungibleToken.Vault, hash: String){
            pre{
                tokens.balance > 0.0: "Nothing to verify for user";
                ByteNextBridge.addedHashes[hash] == nil || ByteNextBridge.addedHashes[hash] == false: "This hash has been added before";
            }

            var tokenType = self.getTokenType(type: tokens.getType());
            var tokenAmount = tokens.balance;

            //Add balance to user's vault
            self._depositBridgeVault(tokenType: tokenType, tokens: <- tokens);

            //Mark as this transaction hash has been processed to prevent duplicating
            ByteNextBridge.addedHashes[hash] = true;

            emit UserFungibleVerified(
                account: self.owner!.address,
                tokenType: tokenType,
                amount: tokenAmount,
                hash: hash);
        }

        pub fun verifyNonFungibleForUser(collection: @NonFungibleToken.Collection, hash: String){
            pre{
                collection.getIDs().length > 0: "Nothing to verify for user";
                ByteNextBridge.addedHashes[hash] == nil || ByteNextBridge.addedHashes[hash] == false: "This hash has been added before";
            }

            var collectionType = self.getTokenType(type: collection.getType());
            if(!ByteNextBridge.isAllowedNonFungibleToken(collectionType: collectionType)){
                panic("NFT type is not supported");
            }

            let owner = self.owner ?? panic("owner is nil");

            //Mark as this transaction hash has been processed to prevent duplicating
            ByteNextBridge.addedHashes[hash] = true;

            let ids = collection.getIDs();
            self._depositNonFungible(collectionType: collectionType, collection: <- collection);

            emit UserNonFungibleVerified(
                account: self.owner!.address,
                collectionType: collectionType,
                ids: ids,
                hash: hash);
        }

        /**
        User claim their tokens
         */
        pub fun fulfillFungible(tokenType: String): @FungibleToken.Vault{
            pre{
                self.owner != nil: "Owner is nil";
                self.userVaults.containsKey(tokenType): "tokenType is invalid or not existed";
            }            

            let userVault <- self.userVaults.remove(key: tokenType)!;
            if(userVault.balance == 0.0){
                panic("Nothing for token type to fulfill");
            }
            
            emit FungibleFulfilled(
                account: self.owner!.address,
                tokenType: tokenType,
                amount: userVault.balance
            );

            return <- userVault;
        }

        pub fun fulfillNonFungible(collectionType: String): @NonFungibleToken.Collection{
            pre{
                self.owner != nil: "Owner is nil";
                self.userCollections.containsKey(collectionType): "collectionType is invalid or not existed";
            }            

            let collection <- self.userCollections.remove(key: collectionType)!;
            let ids = collection.getIDs();
            if(ids.length == 0){
                panic("Collect is empty for fulfilling");
            }
            
            emit NonFungibleFulfilled(
                account: self.owner!.address,
                collectionType: collectionType,
                ids: ids
            );

            return <- collection;
        }

        pub fun getUserFungibleBalance(tokenType: String): UFix64{
            if(!self.userVaults.containsKey(tokenType)){
                return 0.0;
            }

            let userVault <- self.userVaults.remove(key: tokenType)!;

            let balance = userVault.balance;
            let emptyVault <- self.userVaults.insert(key: tokenType, <- userVault);
            destroy emptyVault;
            return balance;
        }

        pub fun getUserNonFungibleIds(collectionType: String): [UInt64]{
            if(!self.userCollections.containsKey(collectionType)){
                return [];
            }

            let collection <- self.userCollections.remove(key: collectionType)!;
            let ids = collection.getIDs();
            let emptyCollection <- self.userCollections.insert(key: collectionType, <- collection);
            destroy emptyCollection;
            return ids;
        }

        access(self) fun getTokenType(type: Type): String{
            return type.identifier;
        }

        access(self) fun _depositBridgeVault(tokenType: String, tokens: @FungibleToken.Vault){
            if(self.userVaults.containsKey(tokenType)){
                var oldVault: @FungibleToken.Vault <- self.userVaults.remove(key: tokenType)!;
                tokens.deposit(from: <- oldVault);
            }
            
            var emptyVault <- self.userVaults.insert(key: tokenType, <- tokens);
            destroy emptyVault;
        }

        access(self) fun _depositNonFungible(collectionType: String, collection: @NonFungibleToken.Collection){
            if(self.userCollections.containsKey(collectionType)){
                var oldCollection: @NonFungibleToken.Collection <- self.userCollections.remove(key: collectionType)!;
                if(oldCollection.getIDs().length > 0){
                    for id in oldCollection.getIDs() {
                        collection.deposit(token: <- oldCollection.withdraw(withdrawID: id));
                    }
                }

                destroy  oldCollection;
            }
            
            var emptyCollection <- self.userCollections.insert(key: collectionType, <- collection);
            destroy emptyCollection;
        }
    }

    pub resource Administrator{
        pub fun setAllowedChains(chainNumbers: [UInt64], value: Bool){
            pre{
                chainNumbers.length > 0: "chainNumbers is empty";
            }

            for chainNumber in chainNumbers{
                ByteNextBridge.allowedChains[chainNumber] = value;
            }
        }

        pub fun setChainAddressLength(chainNumbers: [UInt64], addressLengths: [UInt64]){
            pre{
                chainNumbers.length > 0: "chainNumbers is empty";
                chainNumbers.length == addressLengths.length: "chainNumbers and addressLengths do not match";
            }
            
            var index = 0;
            for chainNumber in chainNumbers{
                ByteNextBridge.chainAddressLengths[chainNumber] = addressLengths[index];
                index = index + 1;
            }
        }

        pub fun setFeeTokenType(feeTokenType: String, feeTokenReceiver: Capability<&AnyResource{FungibleToken.Receiver}>){
            ByteNextBridge.feeTokenType = feeTokenType;
            ByteNextBridge.feeTokenReceiver = feeTokenReceiver;
        }

        pub fun setFungibleReceiver(tokenType: String, fungibleTokenReceiver: Capability<&AnyResource{FungibleToken.Receiver}>){
            ByteNextBridge.fungibleTokenReceiver[tokenType] = fungibleTokenReceiver;
        }

        pub fun setNonFungibleReceiver(collectionType: String, nonFungibleTokenReceiver: Capability<&AnyResource{NonFungibleToken.Receiver}>){
            ByteNextBridge.nonFungibleTokenReceiver[collectionType] = nonFungibleTokenReceiver;
        }

        pub fun setFee(toChains: [UInt64], fees: [UFix64]){
            let count = toChains.length;
            var index = 0;
            while(index < toChains.length){
                ByteNextBridge.nonFungibleFees[toChains[index]] = fees[index];
                index = index + 1;
            }
        }

        pub fun setAllowedFungibleToken(tokenTypes: [String], value: Bool){
            for tokenType in tokenTypes{
                ByteNextBridge.allowedFungibleTokens[tokenType] = value;
            }
        }

        pub fun setAllowedNonFungibleToken(collectionTypes: [String], value: Bool){
            for collectionType in collectionTypes{
                ByteNextBridge.allowedNonFungibleTokens[collectionType] = value;
            }
        }

        pub fun setMaxNftCountPerTransaction(value: UInt64){
            ByteNextBridge.maxNftCountPerTransaction = value;
        }
    }

    pub fun createBridgeStore(): @ByteNextBridge.BridgeStore{
        return <- create ByteNextBridge.BridgeStore();
    }

    pub fun isAllowedFungibleToken(tokenType: String): Bool{
        if(self.allowedFungibleTokens.containsKey(tokenType) && 
        self.allowedFungibleTokens[tokenType] == true){
            return true;
        }

        return false;
    }

    pub fun isAllowedNonFungibleToken(collectionType: String): Bool{
        if(self.allowedNonFungibleTokens.containsKey(collectionType) && 
        self.allowedNonFungibleTokens[collectionType] == true){
            return true;
        }

        return false;
    }

    pub fun getFeeTokenType(): String{
        return self.feeTokenType;
    }

    pub fun getFee(toChain: UInt64): UFix64{
        if(!self.nonFungibleFees.containsKey(toChain)){
            panic("toChain is invalid");
        }

        return self.nonFungibleFees[toChain]!;
    }

    pub fun getMaxNftCountPerTransaction(): UInt64{
        return self.maxNftCountPerTransaction;
    }

    init(){
            self.UserStoragePath = /storage/byteNextBridge;
            self.AdminStoragePath = /storage/byteNextBridgeAdmin;
            self.UserPublicPath = /public/byteNextBridge;

            self.allowedChains = {};
            self.chainAddressLengths = {};
            self.allowedFungibleTokens = {};
            self.allowedNonFungibleTokens = {};
            self.addedHashes = {};
            self.feeTokenType = "";
            self.nonFungibleFees = {};
            self.feeTokenReceiver = nil;
            self.fungibleTokenReceiver = {};
            self.nonFungibleTokenReceiver = {};
            self.maxNftCountPerTransaction = 50;

            self.account.save(<- create Administrator(), to: self.AdminStoragePath);
            self.account.save(<- create BridgeStore(), to: self.UserStoragePath);
            
            self.account.link<&BridgeStore{BridgeStorePublic}>(self.UserPublicPath, target: self.UserStoragePath);
    }
}