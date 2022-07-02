const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Ebay Contract", () => {
  let Ebay, EbayContract;
  let RECIPIENT_ADDRESS;
  let buyer1, buyer2, seller1, seller2;

  beforeEach(async () => {
    Ebay = await ethers.getContractFactory("Ebay");
    [buyer1, buyer2, seller1, seller2] = await ethers.getSigners();
    EbayContract = await Ebay.deploy();
    await EbayContract.deployed();

  });

    describe("Testing Add Auction", () => {
        beforeEach(async () => {
        
        });

        it("Should add auction 1", async () => {
        await EbayContract.addAuction("First Auction", "Testing1", 250, 86400);
        let auctions = await EbayContract.getAuctions();
        let numberOfAuctions = auctions.length;
        console.log("Length: "+numberOfAuctions);
        expect(numberOfAuctions).to.equal(1);
        let auctionsByUser = await EbayContract.getUserAuctions(buyer1.address);
        let NumberOfAuctionsByUser = auctionsByUser.length;
        expect(NumberOfAuctionsByUser).to.equal(1);
        });

        it("Should not add auction ", async () => {
            await expect(
                EbayContract.addAuction("First Auction", "Testing2", 250, 8600)
            ).to.be.revertedWith("Duration should be between 1 to 10 days");
            });
    
    });

    describe("Testing Add Offer", () => {
        beforeEach(async () => {
            await EbayContract.addAuction("First Auction", "Testing1", 250, 86400);
            await EbayContract.addAuction("Second Auction", "Testing2", 200, 172800);
        
        });

        it("Should not add offer - Invalid Auction", async () => {
            let overrides = { value: 251};
            await expect(
                EbayContract.addOffer(12, overrides)
            ).to.be.revertedWith("Invalid Auction");
        });

        it("Should not add offer - Auction expired ", async () => {
            let overrides = { value: 251};

        await ethers.provider.send('evm_increaseTime', [86401]);
        await ethers.provider.send('evm_mine');
            await expect(
                EbayContract.addOffer(1, overrides)
            ).to.be.revertedWith("This auction has ended");
        });

        it("Should not add offer - Invalid offer value 1", async () => {
            let overrides = { value: 251};
            await EbayContract.addOffer(1, overrides);
            console.log("After first offer");
            await expect(
                 EbayContract.connect(buyer2).addOffer(1, overrides)
            ).to.be.revertedWith("Offer Value should be higher than current best offer");
        });

        it("Should not add offer - Invalid offer value 2", async () => {
            let overrides = { value: 251};
            await EbayContract.addOffer(1, overrides);
           
            let overrides2 = { value: 252};
            await EbayContract.connect(buyer2).addOffer(1, overrides2);
            console.log("After second offer");
            let overrides3 = { value: 1};
            await expect(
                 EbayContract.addOffer(1, overrides3)
            ).to.be.revertedWith("Offer Value should be higher than current best offer");
        });

    

        it("Should add an Offer to Auction 1", async () => {
        let overrides = { value: 251};
        await EbayContract.addOffer(1, overrides);
        let offersByAuction = await EbayContract.getAuctionOffers(1);
        let oValue = offersByAuction[offersByAuction.length - 1].offerValue;
        expect(oValue).to.equal(251);

        // Added to the offers mapping
        // let offers = await EbayContract.getOffers();
        // let numberOfOffers = offers.length;
        // console.log("Length: "+numberOfAuctions);
        // expect(numberOfOffers).to.equal(1);


        });

        it("Should add offer - highest offer has prior offers", async () => {
            let overrides = { value: 251};
            await EbayContract.addOffer(1, overrides);
           
            let overrides2 = { value: 252};
            await EbayContract.connect(buyer2).addOffer(1, overrides2);
            //console.log("After second offer");
            let overrides3 = { value: 2};
            await EbayContract.addOffer(1, overrides3);
            let offersByAuction = await EbayContract.getAuctionOffers(1);
            expect(offersByAuction.length).to.equal(3);
            let oValue = offersByAuction[offersByAuction.length - 1].offerValue;
            expect(oValue).to.equal(253);
            
        });

        // it("Should not add auction ", async () => {
        //     await expect(
        //         EbayContract.addAuction("First Auction", "Testing2", 250, 8600)
        //     ).to.be.revertedWith("Duration should be between 1 to 10 days");
        //     });
    
    });


});
