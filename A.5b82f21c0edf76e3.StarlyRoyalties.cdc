pub contract StarlyRoyalties {

    pub struct Royalty {
        pub let address: Address
        pub let cut: UFix64

        init(address: Address, cut: UFix64 ){
            self.address = address
            self.cut = cut
        }
    }

    pub var starlyRoyalty: Royalty
    access(contract) let collectionRoyalties: {String: Royalty}
    access(contract) let minterRoyalties: {String: {String: Royalty}}

    pub let AdminStoragePath: StoragePath
    pub let EditorStoragePath: StoragePath
    pub let EditorProxyStoragePath: StoragePath
    pub let EditorProxyPublicPath: PublicPath

    pub fun getRoyalties(collectionID: String, starlyID: String): [Royalty] {
        let royalties = [self.starlyRoyalty]
        if let collectionRoyalty = self.collectionRoyalties[collectionID] {
            royalties.append(collectionRoyalty)
        }
        if let minterRoyaltiesForCollection = self.minterRoyalties[collectionID] {
            if let minterRoyalty = minterRoyaltiesForCollection[starlyID] {
                royalties.append(minterRoyalty)
            }
        }
        return royalties
    }

    pub fun getStarlyRoyalty(): Royalty {
        return self.starlyRoyalty
    }

    pub fun getCollectionRoyalty(collectionID: String): Royalty? {
        return self.collectionRoyalties[collectionID]
    }

    pub fun getMinterRoyalty(collectionID: String, starlyID: String): Royalty? {
        if let minterRoyaltiesForCollection = self.minterRoyalties[collectionID] {
            return minterRoyaltiesForCollection[starlyID]
        }
        return nil
    }

    pub resource interface IEditor {
        pub fun setStarlyRoyalty(address: Address, cut: UFix64)
        pub fun setCollectionRoyalty(collectionID: String, address: Address, cut: UFix64)
        pub fun deleteCollectionRoyalty(collectionID: String)
        pub fun setMinterRoyalty(collectionID: String, starlyID: String, address: Address, cut: UFix64)
        pub fun deleteMinterRoyalty(collectionID: String, starlyID: String)
    }

    pub resource Editor: IEditor {
        pub fun setStarlyRoyalty(address: Address, cut: UFix64) {
            StarlyRoyalties.starlyRoyalty = Royalty(address: address, cut: cut)
        }

        pub fun setCollectionRoyalty(collectionID: String, address: Address, cut: UFix64) {
            StarlyRoyalties.collectionRoyalties.insert(key: collectionID, Royalty(address: address, cut: cut))
        }

        pub fun deleteCollectionRoyalty(collectionID: String) {
            StarlyRoyalties.collectionRoyalties.remove(key: collectionID)
        }

        pub fun setMinterRoyalty(collectionID: String, starlyID: String, address: Address, cut: UFix64) {
            if !StarlyRoyalties.minterRoyalties.containsKey(collectionID) {
                StarlyRoyalties.minterRoyalties.insert(key: collectionID, {
                    starlyID: Royalty(address: address, cut: cut)
                })
            } else {
                StarlyRoyalties.minterRoyalties[collectionID]!.insert(key: starlyID, Royalty(address: address, cut: cut))
            }
        }

        pub fun deleteMinterRoyalty(collectionID: String, starlyID: String) {
            StarlyRoyalties.minterRoyalties[collectionID]?.remove(key: starlyID)
        }
    }

    pub resource interface EditorProxyPublic {
        pub fun setEditorCapability(cap: Capability<&Editor>)
    }

    pub resource EditorProxy: IEditor, EditorProxyPublic {
        access(self) var editorCapability: Capability<&Editor>?

        pub fun setEditorCapability(cap: Capability<&Editor>) {
            self.editorCapability = cap
        }

        pub fun setStarlyRoyalty(address: Address, cut: UFix64) {
            self.editorCapability!.borrow()!
            .setStarlyRoyalty(address: address, cut: cut)
        }

        pub fun setCollectionRoyalty(collectionID: String, address: Address, cut: UFix64) {
            self.editorCapability!.borrow()!
            .setCollectionRoyalty(collectionID: collectionID, address: address, cut: cut)
        }

        pub fun deleteCollectionRoyalty(collectionID: String) {
            self.editorCapability!.borrow()!
            .deleteCollectionRoyalty(collectionID: collectionID)
        }

        pub fun setMinterRoyalty(collectionID: String, starlyID: String, address: Address, cut: UFix64) {
            self.editorCapability!.borrow()!
            .setMinterRoyalty(collectionID: collectionID, starlyID: starlyID, address: address, cut: cut)
        }

        pub fun deleteMinterRoyalty(collectionID: String, starlyID: String) {
            self.editorCapability!.borrow()!
            .deleteMinterRoyalty(collectionID: collectionID, starlyID: starlyID)
        }

        init() {
            self.editorCapability = nil
        }
    }

    pub fun createEditorProxy(): @EditorProxy {
        return <- create EditorProxy()
    }

    pub resource Admin {
        pub fun createNewEditor(): @Editor {
            return <- create Editor()
        }
    }

    init() {
        self.starlyRoyalty = Royalty(address: 0x12c122ca9266c278, cut: 0.05)
        self.collectionRoyalties = {}
        self.minterRoyalties = {}

        self.AdminStoragePath = /storage/starlyRoyaltiesAdmin
        self.EditorStoragePath = /storage/starlyRoyaltiesEditor
        self.EditorProxyPublicPath = /public/starlyRoyaltiesEditorProxy
        self.EditorProxyStoragePath = /storage/starlyRoyaltiesEditorProxy

        let admin <- create Admin()
        let editor <- admin.createNewEditor()
        self.account.save(<-admin, to: self.AdminStoragePath)
        self.account.save(<-editor, to: self.EditorStoragePath)
    }
}
