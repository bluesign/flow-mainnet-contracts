import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FindViews from 0x097bafa4e0b48eef
import AeraNFT from 0x30cf5dcf6ea8d379
import Clock from 0x30cf5dcf6ea8d379

/*
Aera Reward is the NFT for fulfilling all the required panels for a chapter
consists of thumbnail and a DVM
*/

pub contract AeraRewards: NonFungibleToken {

	pub var totalSupply: UInt64

	pub event ContractInitialized()
	pub event Withdraw(id: UInt64, from: Address?)
	pub event Deposit(id: UInt64, to: Address?)
	// TODO: discuss richer event: title, description, image, recipient
	pub event Minted(id:UInt64, address:Address, reward_template_id: UInt64, edition: UInt64)
	// we cannot have address here as it will always be nil
	pub event Burned(id:UInt64, reward_template_id: UInt64, edition: UInt64)
	pub event RewardMetadataRegistered(reward_template_id: UInt64, reward_name: String, thumbnail: String, video: String, max_quantity: UInt64?)
	pub event RewardClaimed(id:UInt64, address:Address, rewardTemplateId:UInt64, rewardName:String, description: String, thumbnailHash: String, edition:UInt64, type:String, soulBounded: Bool, rarity:String, rewardFields:{UInt64 : {String:String}})

	pub let CollectionStoragePath: StoragePath
	pub let CollectionPublicPath: PublicPath
	pub let CollectionPrivatePath: PrivatePath

	access(account) let royalties : [MetadataViews.Royalty]

	pub let rewardTemplates: {UInt64 : MintDetail}
	pub var currentSerial: UInt64

	pub struct RewardClaimedData {

		pub let data: {String:String}

		init(_ data: {String:String}) {
			self.data=data
		}
	}

	pub struct MintDetail {
		pub let reward_template: RewardTemplate
		pub var current_edition: UInt64
		pub var total_supply: UInt64
		pub let max_quantity: UInt64?

		init (reward_template: RewardTemplate, current_edition: UInt64, total_supply: UInt64, max_quantity: UInt64?) {
			self.reward_template = reward_template
			self.current_edition = current_edition
			self.total_supply = total_supply
			self.max_quantity = max_quantity
		}

		access(account) fun mint() : MintDetail {
			pre{
				self.max_quantity == nil || self.max_quantity! >= self.current_edition + UInt64(1) : "Cannot mint reward with edition greater than max quantity"
			}
			self.current_edition = self.current_edition + 1
			self.total_supply = self.total_supply + 1
			return self
		}

		access(account) fun burn() {
			self.total_supply = self.total_supply - 1
		}
	}

	pub struct Media {
		pub let name: String
		pub let media_type: String
		pub let ipfs_hash: String
		pub let extra: {String : AnyStruct}

		init(name: String, media_type: String, ipfs_hash: String) {
			self.name = name
			self.media_type = media_type
			self.ipfs_hash = ipfs_hash
			self.extra = {}
		}
	}

	pub struct RewardTemplate {
		pub let reward_template_id : UInt64
		pub let reward_name : String
		pub let description : String
		pub let thumbnail_hash : String
		pub let video_hash : String
		pub let video_file : String
		pub let video_type : String
		// for struct's use only
		pub var edition: UInt64
		pub let files: [Media]
		pub let type: String
		pub let detail_id : {String: UInt64}
		pub let traits: [MetadataViews.Trait]
		pub let soulBounded: Bool
		pub let rarity: String
		pub let extra: {String : AnyStruct}

		init(reward_template_id : UInt64 , reward_name : String, description : String, thumbnail_hash : String , video_hash : String, video_file : String, video_type : String, files: [Media], type: String, detail_id : {String: UInt64}, traits: [MetadataViews.Trait], soulBounded: Bool, rarity: String) {
			pre{
				video_hash == "" && video_file != "" || video_file == "" && video_hash != "" : "Requires either video_file or video_hash to be empty string"
			}
			self.reward_template_id = reward_template_id
			self.reward_name = reward_name
			self.description = description
			self.thumbnail_hash = thumbnail_hash
			self.video_hash = video_hash
			self.video_file = video_file
			self.video_type = video_type
			self.extra = {}
			self.edition = 0
			self.type=type
			self.detail_id=detail_id
			self.traits=traits
			self.files=files
			self.soulBounded=soulBounded
			self.rarity=rarity
		}

		pub fun getPlayer() : AeraNFT.Player? {
			if let p = self.detail_id["player_id"] {
				return AeraNFT.getPlayer(p)
			}
			return nil
		}

		pub fun getLicense() : AeraNFT.License? {
			if let id = self.detail_id["license_id"] {
				return AeraNFT.getLicense(id)
			}
			return nil
		}

		pub fun getFiles() : [MetadataViews.Media] {
			var m : [MetadataViews.Media] = []
			for f in self.files {
				m.append(MetadataViews.Media(file: MetadataViews.IPFSFile(cid: f.ipfs_hash, path: nil) , mediaType: f.media_type))
			}
			return m
		}

		pub fun getFileAsTraits() : [MetadataViews.Trait] {
			var t : [MetadataViews.Trait] = []
			for f in self.files {
				t.append(MetadataViews.Trait(name: f.name, value: "ipfs://".concat(f.ipfs_hash), displayType: "string", rarity: nil))
			}
			return t
		}

		pub fun getVideoAsFile() : {MetadataViews.File} {
			if self.video_hash != "" {
				return MetadataViews.IPFSFile(cid: self.video_hash, path: nil)
			}
			return MetadataViews.HTTPFile(url: self.video_file)
		}
	}

	access(account) fun addRewardTemplate(reward: RewardTemplate, maxQuantity: UInt64?) {
		let mintDetail = MintDetail(reward_template: reward, current_edition: 0, total_supply: 0, max_quantity: maxQuantity)
		self.rewardTemplates[reward.reward_template_id] = mintDetail
		emit RewardMetadataRegistered(reward_template_id: reward.reward_template_id , reward_name: reward.reward_name , thumbnail: "ipfs://".concat(reward.thumbnail_hash),  video: reward.getVideoAsFile().uri(), max_quantity: maxQuantity)
	}

	pub fun getReward(_ id:UInt64) : RewardTemplate{
		return AeraRewards.rewardTemplates[id]!.reward_template
	}


	pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

		pub let id:UInt64
		pub let reward_template_id: UInt64
		pub let serial: UInt64
		pub let edition: UInt64
		pub let max_edition: UInt64?
		pub var nounce:UInt64
		pub let extra: {String : AnyStruct}

		init(
			reward_template_id: UInt64,
			serial: UInt64,
			edition: UInt64,
			max_edition: UInt64?
		) {
			self.reward_template_id=reward_template_id
			self.nounce=0
			self.id=self.uuid
			self.serial=serial
			self.edition=edition
			self.max_edition=max_edition
			self.extra={
				"mintedAt" : Clock.time()
			}
		}

		destroy() {
			let reward = self.getReward()

			emit Burned(id:self.id, reward_template_id: reward.reward_template_id, edition: self.edition)
			AeraRewards.rewardTemplates[reward.reward_template_id]!.burn()

			AeraRewards.totalSupply = AeraRewards.totalSupply - 1
		}

		pub fun getReward() : AeraRewards.RewardTemplate {
			return AeraRewards.rewardTemplates[self.reward_template_id]!.reward_template
		}

		pub fun getMintedAt() : UFix64? {
			if let minted = self.extra["mintedAt"] {
				let res = minted as! UFix64
				return res
			}
			return nil
		}

		pub fun getViews(): [Type] {
			let views : [Type] =  [
				Type<MetadataViews.Display>(),
				Type<MetadataViews.Medias>(),
				Type<MetadataViews.Royalties>(),
				Type<MetadataViews.ExternalURL>(),
				Type<MetadataViews.NFTCollectionData>(),
				Type<MetadataViews.NFTCollectionDisplay>(),
				Type<MetadataViews.Serial>(),
				Type<MetadataViews.Editions>(),
				Type<MetadataViews.Traits>(),
				Type<MetadataViews.Rarity>(),
				Type<AeraNFT.License>(),
				Type<RewardTemplate>()
			]

			let reward = AeraRewards.rewardTemplates[self.reward_template_id]!.reward_template
			if reward.soulBounded {
				views.append(Type<FindViews.SoulBound>())
			}

			return views
		}

		pub fun resolveView(_ view: Type): AnyStruct? {

			let reward = self.getReward()

			let thumbnail = MetadataViews.IPFSFile(cid: reward.thumbnail_hash, path: nil)
			let ipfsVideo = reward.getVideoAsFile()

			// mind the mediaType here, to be confirmed
			let thumbnailMedia=MetadataViews.Media(file:thumbnail, mediaType: "image/png")
			let media=MetadataViews.Media(file:ipfsVideo, mediaType: reward.video_type)

			switch view {
			case Type<MetadataViews.Display>():
				let name= reward.reward_name
				// Question : Any preferred description on rewrad NFT?
				let description= reward.description

				let thumbnail = thumbnail

				return MetadataViews.Display(
					name: name,
					description: description,
					thumbnail: thumbnail
				)

			case Type<MetadataViews.ExternalURL>():
				if let addr = self.owner?.address {
					return MetadataViews.ExternalURL("https://aera.onefootball.com/collectibles/".concat(addr.toString()).concat("/rewards/").concat(self.id.toString()))
				}
				return MetadataViews.ExternalURL("https://aera.onefootball.com/collectibles/")

			case Type<MetadataViews.Royalties>():
				// return MetadataViews.Royalties(AeraRewards.royalties)
				var address=AeraRewards.account.address
				if address == 0x46625f59708ec2f8 {
					//testnet merchant address
					address=0x4ff956c78244911b
				} else if address==0x30cf5dcf6ea8d379 {
					//mainnet merchant address
					address=0xa9277dcbec7769df
				}

				let ducReceiver = getAccount(address).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)

				return MetadataViews.Royalties([MetadataViews.Royalty(recepient:ducReceiver, cut: 0.06, description:"onefootball largest of 6% or 0.65")])


			case Type<MetadataViews.Medias>():
				let m = [thumbnailMedia, media]
				let r = self.getReward()
				m.appendAll(r.getFiles())
				return MetadataViews.Medias(m)

			case Type<MetadataViews.NFTCollectionDisplay>():
				let externalURL = MetadataViews.ExternalURL("http://aera.onefootbal.com")
				let squareImage = MetadataViews.Media(file: MetadataViews.IPFSFile(cid: "bafkreiameqwyluog75u7zg3dmf56b5mbed7cdgv6uslkph6nvmdf2aipmy", path: nil), mediaType: "image/jpg")
				let bannerImage = MetadataViews.Media(file: MetadataViews.IPFSFile(cid: "bafybeiayhvr2sm4lco3tbsa74blynlnzhhzrjouteyqaq43giuyiln4xb4", path: nil), mediaType: "image/png")

				let socialMap : {String : MetadataViews.ExternalURL} = {
					"twitter" : MetadataViews.ExternalURL("https://twitter.com/aera_football"),
					"discord" : MetadataViews.ExternalURL("https://discord.gg/aera"),
					"instagram" : MetadataViews.ExternalURL("https://www.instagram.com/aera_football/")
				}
				return MetadataViews.NFTCollectionDisplay(name: "Aera Rewards", description: "Aera by OneFootball", externalURL: externalURL, squareImage: squareImage, bannerImage: bannerImage, socials: socialMap)

			case Type<MetadataViews.NFTCollectionData>():
				return MetadataViews.NFTCollectionData(storagePath: AeraRewards.CollectionStoragePath,
				publicPath: AeraRewards.CollectionPublicPath,
				providerPath: AeraRewards.CollectionPrivatePath,
				publicCollection: Type<&Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
				publicLinkedType: Type<&Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
				providerLinkedType: Type<&Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
				createEmptyCollectionFunction: fun(): @NonFungibleToken.Collection {return <- AeraRewards.createEmptyCollection()})


			case Type<MetadataViews.Serial>():
				return MetadataViews.Serial(self.serial)

			case Type<MetadataViews.Editions>():
				return MetadataViews.Editions([
					MetadataViews.Edition(name: "set", number: self.edition, max: self.max_edition)
				])

			case Type<MetadataViews.Traits>():
				let ts : [MetadataViews.Trait] = [
					MetadataViews.Trait(name: "reward_template_id", value: self.reward_template_id, displayType: "number", rarity: nil)
				]

				for detail in reward.detail_id.keys {
					ts.append(MetadataViews.Trait(name: detail, value: reward.detail_id[detail], displayType: "number", rarity:nil))
				}

				if let l = reward.getLicense()  {
					ts.append(MetadataViews.Trait(name: "copyright", value: l.copyright, displayType: "string", rarity:nil))
				}

				if let player = reward.getPlayer() {
					ts.appendAll([
						MetadataViews.Trait(name: "player_jersey_name", value: player.jerseyname, displayType: "string", rarity: nil),
						MetadataViews.Trait(name: "player_position", value: player.position, displayType: "string", rarity: nil),
						MetadataViews.Trait(name: "player_number", value: player.number, displayType: "number", rarity: nil),
						MetadataViews.Trait(name: "player_nationality", value: player.nationality, displayType: "string", rarity: nil),
						MetadataViews.Trait(name: "player_birthday", value: player.birthday, displayType: "date", rarity: nil)
					])
				}

				if let m = self.getMintedAt() {
					ts.append(MetadataViews.Trait(name: "minted_at", value: m, displayType: "date", rarity:nil))
				}

				let r = self.getReward()

				ts.appendAll(r.getFileAsTraits())

				ts.appendAll(r.traits)

				return MetadataViews.Traits(ts)

			case Type<AeraNFT.License>():
				if let license = reward.getLicense() {
					return license
				}
				return nil

			case Type<AeraRewards.RewardTemplate>():
				return AeraRewards.rewardTemplates[self.reward_template_id]!.reward_template

			case Type<FindViews.SoulBound>():
				let reward = AeraRewards.rewardTemplates[self.reward_template_id]!.reward_template
				if reward.soulBounded {
					return FindViews.SoulBound("This reward is soulBounded and canned be moved. Cannot be moved. ID ".concat(self.id.toString()))
				}
				return nil

			case Type<MetadataViews.Rarity>():
				let reward = AeraRewards.rewardTemplates[self.reward_template_id]!.reward_template
				return MetadataViews.Rarity(score: nil, max: nil, description: reward.rarity)
			}
			return nil
		}

		pub fun increaseNounce() {
			self.nounce=self.nounce+1
		}

	}

	pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
		// dictionary of NFT conforming tokens
		// NFT is a resource type with an `UInt64` ID field
		pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

		init () {
			self.ownedNFTs <- {}
		}

		pub fun hasNFT(_ id: UInt64) : Bool {
			return self.ownedNFTs.containsKey(id)
		}

		// TODO: discuss ownedIdsFromReward(rewardTemplateId: UInt64): [UInt64] {}

		// withdraw removes an NFT from the collection and moves it to the caller
		pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
			let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
			emit Withdraw(id: token.id, from: self.owner?.address)

			return <- token
		}

		// deposit takes a NFT and adds it to the collections dictionary
		// and adds the ID to the id array
		pub fun deposit(token: @NonFungibleToken.NFT) {
			let token <- token as! @NFT
			let id: UInt64 = token.id
			token.increaseNounce()
			// add the new token to the dictionary which removes the old one
			let oldToken <- self.ownedNFTs[id] <- token
			emit Deposit(id: id, to: self.owner?.address)
			destroy oldToken
		}

		// getIDs returns an array of the IDs that are in the collection
		pub fun getIDs(): [UInt64] {
			return self.ownedNFTs.keys
		}

		// borrowNFT gets a reference to an NFT in the collection
		// so that the caller can read its metadata and call its methods
		pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
			pre{
				self.ownedNFTs.containsKey(id) : "Cannot borrow reference to Reward NFT ID : ".concat(id.toString())
			}
			return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
		}

		pub fun borrowRewardNFT(id: UInt64) : &AeraRewards.NFT {
			pre{
				self.ownedNFTs.containsKey(id) : "Cannot borrow reference to Reward NFT ID : ".concat(id.toString())
			}
			let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
			return nft as! &AeraRewards.NFT
		}

		pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
			pre{
				self.ownedNFTs.containsKey(id) : "Cannot borrow reference to Reward NFT ID : ".concat(id.toString())
			}
			let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
			let aerarewardNFT = nft as! &NFT
			return aerarewardNFT as &AnyResource{MetadataViews.Resolver}
		}

		destroy() {
			destroy self.ownedNFTs
		}
	}

	// public function that anyone can call to create a new empty collection
	pub fun createEmptyCollection(): @NonFungibleToken.Collection {
		return <- create Collection()
	}

	// mintNFT mints a new NFT with a new ID
	// and deposit it in the recipients collection using their collection reference
	//The distinction between sending in a reference and sending in a capability is that when you send in a reference it cannot be stored. So it can only be used in this method
	//while a capability can be stored and used later. So in this case using a reference is the right choice, but it needs to be owned so that you can have a good event
	access(account) fun mintNFT(
		recipient: &{NonFungibleToken.Receiver},
		rewardTemplateId: UInt64,
		rewardFields: {UInt64 : {String : String}}
	) :UInt64{
		pre {
			recipient.owner != nil : "Recipients NFT collection is not owned"
			self.rewardTemplates.containsKey(rewardTemplateId) : "Reward template does not exist. ID : ".concat(rewardTemplateId.toString())
		}

		AeraRewards.totalSupply = AeraRewards.totalSupply + 1
		AeraRewards.currentSerial = AeraRewards.currentSerial + 1
		let rewardMintDetail = self.rewardTemplates[rewardTemplateId]!.mint()
		// create a new NFT
		var newNFT <- create NFT(
			reward_template_id: rewardTemplateId,
			serial: AeraRewards.currentSerial,
			edition: rewardMintDetail.current_edition,
			max_edition: rewardMintDetail.max_quantity,
		)
		let t=rewardMintDetail.reward_template
		//Always emit events on state changes! always contain human readable and machine readable information
		emit Minted(id:newNFT.id, address:recipient.owner!.address, reward_template_id: rewardTemplateId, edition: rewardMintDetail.current_edition)
		emit RewardClaimed(id:newNFT.id, address:recipient.owner!.address, rewardTemplateId:t.reward_template_id, rewardName:t.reward_name, description: t.description, thumbnailHash: t.thumbnail_hash, edition:rewardMintDetail.current_edition, type:t.type, soulBounded: t.soulBounded, rarity:t.rarity, rewardFields:rewardFields)

		// deposit it in the recipient's account using their reference
		let id = newNFT.id
		recipient.deposit(token: <-newNFT)
		return id
	}

	access(account) fun addRoyaltycut(_ cutInfo: MetadataViews.Royalty) {
		var cutInfos = self.royalties
		cutInfos.append(cutInfo)
		// for validation only
		let royalties = MetadataViews.Royalties(cutInfos)
		self.royalties.append(cutInfo)
	}

	init() {
		// Initialize the total supply
		self.totalSupply = 0
		self.currentSerial = 0
		self.rewardTemplates = {}

		// Set Royalty cuts in a transaction
		self.royalties = []

		// Set the named paths
		self.CollectionStoragePath = /storage/aeraRewardsNFT
		self.CollectionPublicPath = /public/aeraRewardsNFT
		self.CollectionPrivatePath = /private/aeraRewardsNFT

		self.account.save<@NonFungibleToken.Collection>(<- AeraRewards.createEmptyCollection(), to: AeraRewards.CollectionStoragePath)
		self.account.link<&AeraRewards.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(
			AeraRewards.CollectionPublicPath,
			target: AeraRewards.CollectionStoragePath
		)
		self.account.link<&AeraRewards.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(
			AeraRewards.CollectionPrivatePath,
			target: AeraRewards.CollectionStoragePath
		)

		emit ContractInitialized()
	}
}


