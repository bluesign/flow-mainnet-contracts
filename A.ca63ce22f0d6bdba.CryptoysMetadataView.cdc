pub contract CryptoysMetadataView {
    pub struct Cryptoy {
        pub let name:        String?
        pub let description: String?
        pub let image:       String?
        pub let coreImage:   String?
        pub let video:       String?
        pub let platformId:  String?
        pub let category:    String?
        pub let type:        String?
        pub let skin:        String?
        pub let tier:        String?
        pub let rarity:      String?
        pub let edition:     String?
        pub let series:      String?
        pub let legionId:    String?
        pub let creator:     String?
        pub let packaging:   String?
        pub let termsUrl:    String?

        init(
            name:          String?,
            description:   String?,
            image:         String?,
            coreImage:     String?,
            video:         String?,
            platformId:    String?,
            category:      String?,
            type:          String?,
            skin:          String?,
            tier:          String?,
            rarity:        String?,
            edition:       String?,
            series:        String?,
            legionId:      String?,
            creator:       String?,
            packaging:     String?,
            termsUrl:      String?,
        ){
            self.name        = name
            self.description = description
            self.image       = image
            self.coreImage   = coreImage
            self.video       = video
            self.platformId  = platformId
            self.category    = category
            self.type        = type
            self.skin        = skin
            self.tier        = tier
            self.rarity      = rarity
            self.edition     = edition
            self.series      = series
            self.legionId    = legionId
            self.creator     = creator
            self.packaging   = packaging
            self.termsUrl    = termsUrl
        }        
    }
}
