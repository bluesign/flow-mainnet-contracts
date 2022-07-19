import MetadataViews from 0x1d7e57aa55817448
import StarlyCollectorScore from 0x5b82f21c0edf76e3
import StarlyMetadataViews from 0x5b82f21c0edf76e3
import StarlyIDParser from 0x5b82f21c0edf76e3

pub contract StarlyMetadata {

    pub struct CollectionMetadata {
        pub let collection: StarlyMetadataViews.Collection
        pub let cards: {UInt32: StarlyMetadataViews.Card}

        init(
            collection: StarlyMetadataViews.Collection,
            cards: {UInt32: StarlyMetadataViews.Card}) {

            self.collection = collection
            self.cards = cards
        }

        pub fun insertCard(cardID: UInt32, card: StarlyMetadataViews.Card) {
            self.cards.insert(key: cardID, card)
        }

        pub fun removeCard(cardID: UInt32) {
            self.cards.remove(key: cardID)
        }
    }

    access(contract) var metadata: {String: CollectionMetadata}

    pub let AdminStoragePath: StoragePath
    pub let EditorStoragePath: StoragePath
    pub let EditorProxyStoragePath: StoragePath
    pub let EditorProxyPublicPath: PublicPath

    pub fun getViews(): [Type] {
        return [
            Type<MetadataViews.Display>(),
            Type<MetadataViews.Edition>(),
            Type<MetadataViews.ExternalURL>(),
            Type<MetadataViews.Traits>(),
            Type<MetadataViews.NFTCollectionDisplay>(),
            Type<MetadataViews.NFTCollectionData>(),
            Type<StarlyMetadataViews.CardEdition>()
        ];
    }

    pub fun resolveView(starlyID: String, view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.Display>():
                return self.getDisplay(starlyID: starlyID);
            case Type<MetadataViews.Edition>():
                return self.getEdition(starlyID: starlyID);
            case Type<MetadataViews.ExternalURL>():
                return self.getExternalURL(starlyID: starlyID);
            case Type<MetadataViews.Traits>():
                return self.getTraits(starlyID: starlyID);
            case Type<MetadataViews.NFTCollectionDisplay>():
                return self.getNFTCollectionDisplay();
            // case Type<MetadataViews.NFTCollectionData>(): implemented in StarlytCard
            case Type<StarlyMetadataViews.CardEdition>():
                return self.getCardEdition(starlyID: starlyID);
        }
        return nil;
    }

    pub fun getDisplay(starlyID: String): MetadataViews.Display? {
        if let cardEdition = self.getCardEdition(starlyID: starlyID) {
            let card = cardEdition.card
            let title = card.title
            let edition = cardEdition.edition.toString()
            let editions = card.editions.toString()
            let creatorName = cardEdition.collection.creator.name
            return MetadataViews.Display(
                name: title.concat(" #").concat(edition).concat("/").concat(editions).concat(" by ").concat(creatorName),
                description: cardEdition.card.description,
                thumbnail: MetadataViews.HTTPFile(url: cardEdition.card.mediaSizes[0]!.url)
            )
        }
        return nil
    }

    pub fun getEdition(starlyID: String): MetadataViews.Edition? {
        if let cardEdition = self.getCardEdition(starlyID: starlyID) {
            let card = cardEdition.card
            let edition = cardEdition.edition
            let editions = card.editions
            return MetadataViews.Edition(
                name: "Card",
                number: UInt64(edition),
                max: UInt64(editions)
            )
        }
        return nil
    }

    pub fun getExternalURL(starlyID: String): MetadataViews.ExternalURL? {
        if let cardEdition = self.getCardEdition(starlyID: starlyID) {
            return MetadataViews.ExternalURL(
                url: cardEdition.url
            )
        }
        return nil
    }

    pub fun getTraits(starlyID: String): MetadataViews.Traits? {
        if let cardEdition = self.getCardEdition(starlyID: starlyID) {
            let collection = cardEdition.collection
            let creator = collection.creator
            let card = cardEdition.card
            return MetadataViews.Traits([
                MetadataViews.Trait(name:"Name", value: card.title, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Description", value: card.description, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Rarity", value: card.rarity, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Collection (Name)", value: collection.title, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Collection (URL)", value: collection.url, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Creator (Name)", value: creator.name, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Creator (Username)", value: creator.username, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Creator (URL)", value: creator.url, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Edition", value: cardEdition.edition, displayType: "Numeric", rarity: nil),
                MetadataViews.Trait(name:"Editions", value: card.editions, displayType: "Numeric", rarity: nil),
                MetadataViews.Trait(name:"Collector Score", value: cardEdition.score ?? 0.0, displayType: "Numeric", rarity: nil),
                MetadataViews.Trait(name:"URL", value: cardEdition.url, displayType: "String", rarity: nil),
                MetadataViews.Trait(name:"Preview URL", value: cardEdition.previewUrl, displayType: "String", rarity: nil)
            ])
        }
        return nil
    }

    pub fun getNFTCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
        return MetadataViews.NFTCollectionDisplay(
            name: "Starly",
            description: "Starly is a launchpad and marketplace for gamified NFT collections on Flow.",
            externalURL: MetadataViews.ExternalURL("https://starly.io"),
            squareImage: MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: "https://storage.googleapis.com/starly-prod.appspot.com/assets/starly-square-logo.jpg"
                ),
                mediaType: "image/jpeg"),
            bannerImage: MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: "https://storage.googleapis.com/starly-prod.appspot.com/assets/starly-banner.jpg"
                ),
                mediaType: "image/jpeg"),
            socials: {
                "twitter": MetadataViews.ExternalURL("https://twitter.com/StarlyNFT"),
                "discord": MetadataViews.ExternalURL("https://discord.gg/starly"),
                "medium": MetadataViews.ExternalURL("https://medium.com/@StarlyNFT")
            }
        )
    }

    pub fun getCardEdition(starlyID: String): StarlyMetadataViews.CardEdition? {
        let starlyID = StarlyIDParser.parse(starlyID: starlyID)
        let collectionMetadataOptional = self.metadata[starlyID.collectionID]
        if let collectionMetadata = collectionMetadataOptional {
            let cardOptional = collectionMetadata.cards[starlyID.cardID]
            if let card = cardOptional {
                return StarlyMetadataViews.CardEdition(
                    collection: collectionMetadata.collection,
                    card: card,
                    edition: starlyID.edition,
                    score: StarlyCollectorScore.getCollectorScore(
                        collectionID: starlyID.collectionID,
                        rarity: card.rarity,
                        edition: starlyID.edition,
                        editions: card.editions,
                        priceCoefficient: collectionMetadata.collection.priceCoefficient),
                    url: card.url.concat("/").concat(starlyID.edition.toString()),
                    previewUrl: card.previewUrl.concat("/").concat(starlyID.edition.toString())
                )
            }
        }
        return nil
    }

    pub resource interface IEditor {
        pub fun putCollectionCard(collectionID: String, cardID: UInt32, card: StarlyMetadataViews.Card)
        pub fun putMetadata(collectionID: String, metadata: CollectionMetadata)
        pub fun deleteCollectionCard(collectionID: String, cardID: UInt32)
        pub fun deleteMetadata(collectionID: String)
    }

    pub resource Editor: IEditor {
        pub fun putCollectionCard(collectionID: String, cardID: UInt32, card: StarlyMetadataViews.Card) {
            StarlyMetadata.metadata[collectionID]?.insertCard(cardID: cardID, card: card)
        }

        pub fun putMetadata(collectionID: String, metadata: CollectionMetadata) {
            StarlyMetadata.metadata.insert(key: collectionID, metadata)
        }

        pub fun deleteCollectionCard(collectionID: String, cardID: UInt32) {
            StarlyMetadata.metadata[collectionID]?.removeCard(cardID: cardID)
        }

        pub fun deleteMetadata(collectionID: String) {
            StarlyMetadata.metadata.remove(key: collectionID)
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

        pub fun putCollectionCard(collectionID: String, cardID: UInt32, card: StarlyMetadataViews.Card) {
            self.editorCapability!.borrow()!
            .putCollectionCard(collectionID: collectionID, cardID: cardID, card: card)
        }

        pub fun putMetadata(collectionID: String, metadata: CollectionMetadata) {
            self.editorCapability!.borrow()!
            .putMetadata(collectionID: collectionID, metadata: metadata)
        }

        pub fun deleteCollectionCard(collectionID: String, cardID: UInt32) {
            self.editorCapability!.borrow()!
            .deleteCollectionCard(collectionID: collectionID, cardID: cardID)
        }

        pub fun deleteMetadata(collectionID: String) {
            self.editorCapability!.borrow()!
            .deleteMetadata(collectionID: collectionID)
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
        self.metadata = {}

        self.AdminStoragePath = /storage/starlyMetadataAdmin
        self.EditorStoragePath = /storage/starlyMetadataEditor
        self.EditorProxyPublicPath = /public/starlyMetadataEditorProxy
        self.EditorProxyStoragePath = /storage/starlyMetadataEditorProxy

        let admin <- create Admin()
        let editor <- admin.createNewEditor()
        self.account.save(<-admin, to: self.AdminStoragePath)
        self.account.save(<-editor, to: self.EditorStoragePath)
    }
}
