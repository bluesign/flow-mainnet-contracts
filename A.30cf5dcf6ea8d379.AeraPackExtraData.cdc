
pub contract AeraPackExtraData {


	access(contract) let data: {UInt64: {String: AnyStruct}}

	access(account) fun registerItemsForPackType(typeId: UInt64, items:Int) {
		let item = self.data[typeId] ?? {}
		item["items"] = items
		self.data[typeId] = item
	}

	pub fun getItemsPerPackType(_ typeId: UInt64):Int?{
		if let item = self.data[typeId] {
			if let value = item["items"] {
				return value as! Int
			}
		}
		return nil
	}

	access(account) fun registerTierForPackType(typeId: UInt64, tier:String) {
		let item = self.data[typeId] ?? {}
		item["packTier"] = tier
		self.data[typeId] = item
	}

	pub fun getTierPerPackType(_ typeId: UInt64):String?{
		if let item = self.data[typeId] {
			if let value = item["packTier"] {
				return value as! String
			}
		}
		return nil
	}

	access(account) fun registerItemTypeForPackType(typeId: UInt64, itemType:Type) {
		let item = self.data[typeId] ?? {}
		item["itemType"] = itemType
		self.data[typeId] = item
	}

	pub fun getItemTypePerPackType(_ typeId: UInt64):Type?{
		if let item = self.data[typeId] {
			if let value = item["itemType"] {
				return value as! Type
			}
		}
		return nil
	}

	access(account) fun registerReceiverPathForPackType(typeId: UInt64, receiverPath:String) {
		let item = self.data[typeId] ?? {}
		item["receiverPath"] = receiverPath
		self.data[typeId] = item
	}

	pub fun getReceiverPathPerPackType(_ typeId: UInt64):String?{
		if let item = self.data[typeId] {
			if let value = item["receiverPath"] {
				return value as! String
			}
		}
		return "aeraNFTs"
	}

	init() {
		self.data={}

	}
}
