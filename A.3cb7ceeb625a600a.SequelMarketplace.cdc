import FungibleToken from 0xf233dcee88fe0abe
import NFTStorefront from 0x4eb8a10cb9f87357
import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import Evergreen from 0x3cb7ceeb625a600a

// SequelMarketplace provides convenience functions to create listings for Sequel NFTs in NFTStorefront.
//
// Source: https://github.com/piprate/sequel-flow-contracts
//
pub contract SequelMarketplace {
    // Payment
    //
    pub struct Payment {
        // role is the Evenrgreen role of the party that receives this payment
        pub let role: String
        // receiver is the receiving party's address
        pub let receiver: Address
        // amount is the quantity of the fungible token that will be paid to the receiver.
        pub let amount: UFix64
        // rate is the percentage of the overall sale this payment represents.
        pub let rate: UFix64

        init(role: String, receiver: Address, amount: UFix64, rate: UFix64) {
            self.role = role
            self.receiver = receiver
            self.amount = amount
            self.rate = rate
        }
    }

    // PaymentInstructions
    //
    pub struct PaymentInstructions {
        pub let payments: [Payment]
        pub let saleCuts: [NFTStorefront.SaleCut]

        init(payments: [Payment], saleCuts: [NFTStorefront.SaleCut]) {
            self.payments = payments
            self.saleCuts = saleCuts
        }
    }

    // TokenListed
    // Token available for purchase.
    //
    pub event TokenListed(
        storefrontAddress: Address,
        listingID: UInt64,
        nftType: String,
        nftID: UInt64,
        paymentVaultType: String,
        price: UFix64,
        payments: [Payment],
        asset: String,
        metadataLink: String?,
    )

    // TokenSold
    // Token was sold.
    //
    pub event TokenSold(
        storefrontAddress: Address,
        listingID: UInt64,
        nftType: String,
        nftID: UInt64,
        paymentVaultType: String,
        price: UFix64,
        buyerAddress: Address,
        metadataLink: String?,
    )

    // TokenWithdrawn
    // Token listing was withdrawn.
    //
    pub event TokenWithdrawn(
        storefrontAddress: Address,
        listingID: UInt64,
        nftType: String,
        nftID: UInt64,
        vaultType: String,
        price: UFix64
    )

    // listToken
    pub fun listToken(
        storefront: &NFTStorefront.Storefront,
        nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, Evergreen.CollectionPublic}>,
        nftType: Type,
        nftID: UInt64,
        sellerVaultPath: PublicPath,
        paymentVaultType: Type,
        price: UFix64,
        extraRoles: [Evergreen.Role],
        metadataLink: String?,
    ): UInt64 {
        let token = nftProviderCapability.borrow()!.borrowEvergreenToken(id: nftID)!
        let seller = storefront.owner!.address

        let instructions = self.buildPayments(
            profile: token.getEvergreenProfile(),
            seller: seller,
            sellerRole: "Owner",
            sellerVaultPath: sellerVaultPath,
            price: price,
            defaultReceiverPath: MetadataViews.getRoyaltyReceiverPublicPath(),
            initialSale: false,
            extraRoles: extraRoles)

        let listingID = storefront.createListing(
            nftProviderCapability: nftProviderCapability,
            nftType: nftType,
            nftID: nftID,
            salePaymentVaultType: paymentVaultType,
            saleCuts: instructions.saleCuts
        )

        emit TokenListed(
            storefrontAddress: seller,
            listingID: listingID,
            nftType: nftType.identifier,
            nftID: nftID,
            paymentVaultType: paymentVaultType.identifier,
            price: price,
            payments: instructions.payments,
            asset: token.getAssetID(),
            metadataLink: metadataLink,
        )

        return listingID
    }

    pub fun buyToken(
        storefrontAddress: Address,
        storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic},
        listingID: UInt64,
        listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic},
        paymentVault: @FungibleToken.Vault,
        buyerAddress: Address,
        metadataLink: String?,
    ): @NonFungibleToken.NFT {
        let details = listing.getDetails()

        emit TokenSold(
            storefrontAddress: storefrontAddress,
            listingID: listingID,
            nftType: details.nftType.identifier,
            nftID: details.nftID,
            paymentVaultType: details.salePaymentVaultType.identifier,
            price: details.salePrice,
            buyerAddress: buyerAddress,
            metadataLink: metadataLink
        )

        let item <- listing.purchase(payment: <-paymentVault)
        storefront.cleanup(listingResourceID: listingID)
        return <- item
    }

    pub fun payForMintedTokens(
        unitPrice: UFix64,
        numEditions: UInt64,
        sellerRole: String,
        sellerVaultPath: PublicPath,
        paymentVault: @FungibleToken.Vault,
        evergreenProfile: Evergreen.Profile,
    ) {
        let seller = evergreenProfile.getRole(id: sellerRole)!.address

        let instructions = self.buildPayments(
            profile: evergreenProfile,
            seller: seller,
            sellerRole: sellerRole,
            sellerVaultPath: sellerVaultPath,
            price: unitPrice * UFix64(numEditions),
            defaultReceiverPath: MetadataViews.getRoyaltyReceiverPublicPath(),
            initialSale: true,
            extraRoles: [])

        // Rather than aborting the transaction if any receiver is absent when we try to pay it,
        // we send the payment to the last valid receiver. buildPayments function always
        // puts the seller as the last receiver.
        var residualReceiver: &{FungibleToken.Receiver}? = nil

        for cut in instructions.saleCuts {
            if let receiver = cut.receiver.borrow() {
                let paymentCut <- paymentVault.withdraw(amount: cut.amount)
                receiver.deposit(from: <- paymentCut)
                residualReceiver = receiver
            }
        }

        // At this point, if all receivers were active and available, then the payment Vault will have
        // zero tokens left.
        if paymentVault.balance > 0.0 {
            assert(residualReceiver != nil, message: "No valid residual payment receivers")
            residualReceiver!.deposit(from: <-paymentVault)
        } else {
            destroy paymentVault
        }
    }

    // withdrawToken
    // Cancel sale
    //
    pub fun withdrawToken(
        storefrontAddress: Address,
        storefront: &NFTStorefront.Storefront,
        listingID: UInt64,
    ) {
        let listing = storefront.borrowListing(listingResourceID: listingID)
            ?? panic("listing not found in Storefront")

        let details = listing.getDetails()

        emit TokenWithdrawn(
            storefrontAddress: storefrontAddress,
            listingID: listingID,
            nftType: details.nftType.identifier,
            nftID: details.nftID,
            vaultType: details.salePaymentVaultType.identifier,
            price: details.salePrice
        )

        storefront.removeListing(listingResourceID: listingID)
    }

    // buildPayments constructs a list of payments based on the given Evengreen profile.
    // Any residual amount goes to the given seller's address.
    pub fun buildPayments(
        profile: Evergreen.Profile,
        seller: Address,
        sellerRole: String,
        sellerVaultPath: PublicPath,
        price: UFix64,
        defaultReceiverPath: PublicPath,
        initialSale: Bool,
        extraRoles: [Evergreen.Role]
    ): PaymentInstructions {

        let payments: [Payment] = []
        let saleCuts: [NFTStorefront.SaleCut] = []

        var residualRate = 1.0

        let addPayment = fun (roleID: String, address: Address, receiverPath: PublicPath?, rate: UFix64, mustSucceed: Bool) {
            assert(rate >= 0.0 && rate <= 1.0, message: "Rate must be in range [0..1]")

            if rate != 0.0 {
                let amount = price * rate

                var path = defaultReceiverPath
                if receiverPath != nil {
                    path = receiverPath!
                }

                let receiverCap = getAccount(address).getCapability<&{FungibleToken.Receiver}>(path)
                if receiverCap.check() {
                    payments.append(Payment(role: roleID, receiver: address, amount: amount, rate: rate))
                    saleCuts.append(NFTStorefront.SaleCut(receiver: receiverCap, amount: amount))
                    residualRate = residualRate - rate
                    assert(residualRate >= 0.0 && residualRate <= 1.0, message: "Residual rate must be in range [0..1]")
                } else if mustSucceed {
                    panic("missing fungible token receiver capability for mandatory payment recipient")
                }
            }
        }

        for role in profile.roles {
            addPayment(role.id, role.address, receiverPath: role.receiverPath, role.commissionRate(initialSale: initialSale), false)
        }

        for role in extraRoles {
            addPayment(role.id, role.address, receiverPath: role.receiverPath, role.commissionRate(initialSale: initialSale), false)
        }

        if residualRate > 0.0 {
            addPayment(sellerRole, seller, receiverPath: sellerVaultPath, residualRate, true)
        }

        return PaymentInstructions(payments: payments, saleCuts: saleCuts)
    }
}
