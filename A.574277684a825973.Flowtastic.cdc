pub contract Flowtastic {

    // Declare a Path constant so we don't need to harcode in tx
    pub let ReviewCollectionStoragePath: StoragePath
    pub let ReviewCollectionPublicPath: PublicPath

    // Declare the Review resource type - nothing changed here!
    pub resource Review {
        // The unique ID that differentiates each Review
        pub let id: UInt64

        // String mapping to hold metadata
        pub var metadata: {String: String}

        // Initialize both fields in the init function
        init(metadata: {String: String}) {
            self.id = self.uuid
            self.metadata = metadata
        }
    }

    // Function to create a new Review
    pub fun createReview(metadata: {String: String}): @Review {
        return <-create Review(metadata: metadata)
    }

    pub resource interface CollectionPublic {
        pub fun getIDs(): [UInt64]
        pub fun borrowReview(id: UInt64): &Review? 
    }

    // Declare a Collection resource that contains Reviews.
    // it does so via `saveReview()`, 
    // and stores them in `self.reviews`
    pub resource Collection: CollectionPublic {
        // an object containing the reviews
        pub var reviews: @{UInt64: Review}

        // a method to save a review in the collection
        pub fun saveReview(review: @Review) {
            // add the new review to the dictionary with 
            // a force assignment (check glossary!)
            // If there were to be a value at that key, 
            // it would fail/revert. 
            self.reviews[review.id] <-! review
        }

        // get all the id's of the reviews in the collection
        pub fun getIDs(): [UInt64] {
            return self.reviews.keys
        }

        pub fun borrowReview(id: UInt64): &Review? {
            if self.reviews[id] != nil {
                let ref = (&self.reviews[id] as &Flowtastic.Review?)!
                return ref
            }
            return nil
        }

        init() {
            self.reviews <- {}
        }

        destroy() {
            // when the Colletion resource is destroyed, 
            // we need to explicitly destroy the reviews too.
            destroy self.reviews
        }
    }

    // create a new collection
    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    init() {
        // assign the storage path to /storage/ReviewCollection
        self.ReviewCollectionStoragePath = /storage/ReviewCollection
        self.ReviewCollectionPublicPath = /public/ReviewCollection
        // save the empty collection to the storage path
        self.account.save(<-self.createEmptyCollection(), to: self.ReviewCollectionStoragePath)
        // publish a reference to the Collection in storage
        self.account.link<&{CollectionPublic}>(self.ReviewCollectionPublicPath, target: self.ReviewCollectionStoragePath)
    }
}
