// Based on Verses Profile. Needed a Profile without a Wallet Solution. Using MultiFungible Token Instead 0x229e7617283d5085 for a Wallet Solution.
// A Basic Profile. web: DAAM.Agency
// Ami Rajpal: ami@daam.agency
// DAAM Agency (web: daam.agency)

import MetadataViews from 0x1d7e57aa55817448

pub contract DAAM_Profile {
    // Storage:
    pub let publicPath  : PublicPath
    pub let storagePath : StoragePath
    /******************************************************************************************/
    // Events:
    pub event ContractInitialized()
    pub event ProfileCreated(name: String)
    pub event UpdateEmail(email: String?)
    pub event UpdateAbout(about: String?)
    pub event UpdateDescription(description: String?)
    pub event UpdateWeb(web: String)
    pub event UpdateSocial(social: {String:String})
    pub event UpdateAvatar()
    pub event UpdateHeroImage()
    pub event UpdateNotes(notes: [String]) // returning notes.keys     
    pub event RemoveWeb(web: String)
    pub event RemoveSocial(social: String)
    pub event RemoveNotes(note: String)
    /******************************************************************************************/
    // Interface:
    // Public
    pub resource interface Public {
        pub fun getProfile(): UserHandler
    }
    /******************************************************************************************/
    // Structs:
    // UserHandler
    pub struct UserHandler {
        pub let name : String
        pub let email: String?
        pub let about: String?
        pub let description: String?
        pub let web      : [MetadataViews.ExternalURL]
        pub let social   : {String: String}
        pub let avatar   : AnyStruct{MetadataViews.File}?
        pub let heroImage: AnyStruct{MetadataViews.File}?
        pub let notes    : {String: String}

        init(_ user: &User) {
            pre { user != nil }
            self.name  = user.name
            self.email = user.email
            self.about = user.about
            self.description = user.description
            self.web       = user.web
            self.social    = user.social
            self.avatar    = user.avatar
            self.heroImage = user.heroImage
            self.notes     = user.notes
        }
    }
    /******************************************************************************************/
    // Resource:
    // User
    pub resource User: Public
    {
        pub let name : String
        pub var email: String?
        pub var about: String?
        pub var description: String?
        pub var web      : [MetadataViews.ExternalURL]
        pub var social   : {String: String}
        pub var avatar   : AnyStruct{MetadataViews.File}?
        pub var heroImage: AnyStruct{MetadataViews.File}?
        pub var notes    : {String: String}  // {Types of Notes : Note}

        // Init
        init(name: String, about: String?, description: String?, web: String?, social: {String:String}?,
            avatar: AnyStruct{MetadataViews.File}?, heroImage: AnyStruct{MetadataViews.File}?, notes: {String:String}? )
        {
            self.name   = name
            self.email  = nil
            self.about  = about
            self.description = description          
            self.web    = (web != nil) ? [MetadataViews.ExternalURL(web!)] : []
            self.social = (social != nil) ? social! : {}
            self.avatar = avatar
            self.heroImage   = heroImage
            self.notes  = (notes != nil) ? notes! : {}

            emit ProfileCreated(name: self.name)
        }

        priv fun validateEmailPortion(_ ref: [UInt8], _ plusLimit: Int) { // plusLimit limits the number of '+'
            var plus_counter = 0
            for r in ref {
                log("r: ".concat(r.toString()))
                if r == 43 { plus_counter = plus_counter + 1 }
                if ((r < 97 || r > 122) && r != 95 && r != 43) && (r < 48 || r > 57) {  // ascii: 97='a', 122='z', 95='_', 43='+', 48='0', 57='9'
                    panic("Invalid Email Entered")
                }
                if plus_counter > plusLimit { panic("Invalid Email Entered") }
            }
        }

        // Functions
        // Internal Functions
        priv fun verifyEmail(_ entered_name: String, _ entered_at: String, _ entered_dot: String): String {
            let name = entered_name.toLower().utf8
            let at   = entered_at.toLower().utf8
            let dot  = entered_dot.toLower().utf8

            self.validateEmailPortion(name, 1)
            self.validateEmailPortion(at, 0)
            self.validateEmailPortion(dot, 0)
            
            let email = entered_name.toLower().concat("@").concat(entered_at.toLower()).concat(".").concat(entered_dot.toLower())
            assert(email.length <= 40, message: "Email too long.")
            log("Email: ".concat(email))
            return email
        }

        // Set Functions
        pub fun setEmail(name: String?, at: String?, dot: String?) {
            pre { (name==nil && at==nil && dot==nil) || (name!=nil && at!=nil && dot!=nil) : "Invalid Email Entered." }
            if name == nil {
                self.email = nil
                return
            }
            self.email = self.verifyEmail(name!, at!, dot!)
            emit UpdateEmail(email: self.email)
        }

        pub fun setAbout(_ about: String?) {
            self.about = about
            emit UpdateAbout(about: about)
        }

        pub fun setDescription(_ desc: String?)   {
            self.description = desc
            emit UpdateDescription(description: desc)
        }

        pub fun setAvatar(_ avatar: AnyStruct{MetadataViews.File}?)  {
            self.avatar = avatar
            emit UpdateAvatar()
        }

        pub fun setHeroImage(_ hero: AnyStruct{MetadataViews.File}?) {
            self.heroImage = hero
            emit UpdateHeroImage()
        }

        // Add Functions
        pub fun addWeb(_ web: String) {
            for w in self.web {
                assert(w.url != web, message: web.concat(" has already been added."))
            }
            self.web.append(MetadataViews.ExternalURL(web))
            emit UpdateWeb(web: web)
        }

        pub fun addSocial(_ social: {String:String}) {
            for s in social.keys {
                self.social[s] = social[s]
            }
            emit UpdateSocial(social: social)
        }

        pub fun addNotes(_ notes: {String:String}) {
            for n in notes.keys {
                self.notes[n] = notes[n]
            }
            emit UpdateNotes(notes: notes.keys)
        }

        // Remove Functions
        pub fun removeWeb(_ web: String) {
            var counter = 0
            for w in self.web {
                if w.url == web {
                    self.web.remove(at: counter)
                    emit RemoveWeb(web: web)
                    return
                }
                counter = counter + 1
            }
            panic("Could not remove Website. Doesn not exist in list in list.")
        }

        pub fun removeSocial(_ social: String) {
            pre { self.social.containsKey(social) : social.concat(" doesn not exist.") }
            self.social.remove(key:social)
            emit RemoveSocial(social: social)
        }

        pub fun removeNotes(_ note: String) {
            pre { self.notes.containsKey(note) : note.concat(" doesn not exist.") }
            self.notes.remove(key:note)
             emit RemoveNotes(note: note)
        }

        // Resource Public Functions
        pub fun getProfile(): UserHandler {
            return UserHandler(&self as &User)
        }
    } // End User Resource
    /******************************************************************************************/
    // Contract Public Functions:
    pub fun createProfile(name: String, about: String?, description: String?, web: String?, social: {String:String}?,
            avatar: AnyStruct{MetadataViews.File}?, heroImage: AnyStruct{MetadataViews.File}?, notes: {String:String}?): @User
    {
        return <- create User(name:name, about:about, description:description, web:web, social:social, avatar:avatar, heroImage:heroImage, notes:notes) 
    }

    pub fun check(_ address: Address): Bool {
        let ref = getAccount(address).getCapability<&User{Public}>(self.publicPath).borrow() as &User{Public}?
        return (ref != nil)
    }

    // Initialization
    init() {
        let defaultPath = "DAAM_Profile"
        self.publicPath  = PublicPath(identifier : defaultPath)!
        self.storagePath = StoragePath(identifier: defaultPath)!
        emit ContractInitialized()
    }      
}
 