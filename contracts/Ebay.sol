pragma solidity ^0.8.14;


contract Ebay {

    // Use Cases:
    // 1. Add an auction
    //  => Create an auction and add it to the mapping of auctions
    //  => Increment number of auctions
    // 2. Make an offer to an existing auction (payable)
    //  => Receives an AuctionId as parameter and only adds the offer if the value is higher than the current bestOffer and the auction is still valid.
    //  => Transfer offerValue to the smartContract
    // 3. Execute trade (when the auction ends)
    //  => Transfer money from the contract to the seller
    //  => Transfer money back to the loser offers


    // Structure of an Auction
    struct Auction {
        uint id;
        string name;
        string description;
        address seller;
        uint minimumOfferPrice;
        uint auctionEnd;
        uint[] offerIds;
        uint bestOfferId;
    }
    // Mapping of all auctions
    mapping(uint => Auction) public auctions;
    // Keeping track of the number of auctions
    uint private nextAuctionId = 1;

    // Structure of an Offer
    struct Offer {
        uint id;
        address buyer;
        uint offerValue;
        uint auctionId;
    }
    // Keeping track of the number of offers
    uint private nextOfferId = 1;

    // Mapping of all offers
    mapping(uint => Offer) public offers;

    // Mapping of auctions by user
    mapping(address => uint[]) public auctionsByUser;

    // Mapping of offers by user
    mapping(address => uint[]) public offersByUser;

    function addAuction(string calldata _name, string calldata desc, uint minPrice, uint duration) external {
        require(
            duration >= 1 days && duration <= 10 days,
            "Duration should be between 1 to 10 days"
        );
        uint[] memory offerIds = new uint[](0);

         // Notethat Duration param is number of seconds, so current time + duration
        auctions[nextAuctionId]=Auction(
            nextAuctionId,
            _name,
            desc,
            msg.sender,
            minPrice,
            block.timestamp + duration,
            offerIds,
            0
        );
        // adding it to the auctionsByUser mapping
        auctionsByUser[msg.sender].push(nextAuctionId);
        nextAuctionId++;

    }

    function addOffer(uint _auctionId) external payable auctionExists(_auctionId) {
        
        Auction storage selectedAuction = auctions[_auctionId];
        require (selectedAuction.auctionEnd > block.timestamp, 'This auction has ended');
        Offer storage bestOffer = offers[selectedAuction.bestOfferId];
        // Does that user have a previous offer??
        uint prevOffer = getPreviousHighestOfferFromUser(_auctionId);
        if (prevOffer > 0){
            require (bestOffer.offerValue <  (msg.value + offers[prevOffer].offerValue) && (msg.value + offers[prevOffer].offerValue) > selectedAuction.minimumOfferPrice, 'Offer Value should be higher than current best offer');
        } else {
            require (bestOffer.offerValue <  msg.value && msg.value > selectedAuction.minimumOfferPrice, 'Offer Value should be higher than current best offer');
        }
        
        // Assigning the new best Offer Id
        selectedAuction.bestOfferId = nextOfferId;
        // Adding it to the current Auction offers
        selectedAuction.offerIds.push(nextOfferId);
        // creating the new Offer and adding it to the offers array
        offers[nextOfferId] = Offer (
            nextOfferId,
             msg.sender,
             msg.value+prevOffer,
             _auctionId
        ); 
        // Adding it to the offersByUser array
        offersByUser[msg.sender].push(nextOfferId);


        nextOfferId++;
    }

    function getPreviousHighestOfferFromUser(uint _auctionId) internal view auctionExists(_auctionId) returns(uint){
        
        uint prevHighestOfferId = 0;
        uint prevHighestOfferValue = 0;
        uint[] memory userOffers = offersByUser[msg.sender];
        for (uint i = 0; i < userOffers.length; i++){
            Offer memory currentOffer = offers[userOffers[i]];
            if(currentOffer.auctionId == _auctionId)
            {
                if(currentOffer.offerValue > prevHighestOfferValue)
                {
                    prevHighestOfferId = currentOffer.id;
                    prevHighestOfferValue = currentOffer.offerValue;
                }
            }
        }
        return prevHighestOfferId;

    }

    // Transfer the winning offer value to the buyer
    // Transfer the rest of the 
    function trade(uint _auctionId) external auctionExists(_auctionId){
        Auction storage selectedAuction = auctions[_auctionId];
        require (block.timestamp > selectedAuction.auctionEnd, 'Auction is still active');

        // Sending money back to all the offers that aren't the bestOffer
        for(uint i=0; i < selectedAuction.offerIds.length; i++){
            uint curOfferId = selectedAuction.offerIds[i];
            Offer memory current = offers[curOfferId];
            if(current.id != selectedAuction.bestOfferId){
                (bool success, ) = current.buyer.call{value:current.offerValue}("");
                require(success, "Transferring to seller failed");
            }
            
        }
        // Sending money to the seller.
        Offer memory bestOffer = offers[selectedAuction.bestOfferId];
        uint winningOfferValue = bestOffer.offerValue;
        (bool success, ) = selectedAuction.seller.call{value:winningOfferValue}("");
        require(success, "Transferring to seller failed");

    }

    modifier auctionExists(uint auctionId){
        require (auctionId > 0 && auctionId < nextAuctionId, 'Invalid Auction');
        _;
    }

    function getAuctions() 
        external 
        view 
        returns (Auction[] memory)
    {
        Auction[] memory _auctions = new Auction[](nextAuctionId-1);
        for (uint i=1; i < nextAuctionId; i++){
            _auctions[i-1]=auctions[i];
        }
        return _auctions;
    }

    function getUserAuctions(address _user) 
        external 
        view 
        returns (Auction[] memory)
    {
        uint[] storage userAuctionIds = auctionsByUser[_user];
        Auction[] memory _auctions = new Auction[](userAuctionIds.length);
        for (uint i=0; i < userAuctionIds.length; i++){
            uint auctionId = userAuctionIds[i];
            _auctions[i] = auctions[auctionId];
        }
        return _auctions;
    }

    function getUserOffers(address _user) 
        external 
        view 
        returns (Offer[] memory)
    {
        uint[] storage userOfferIds = offersByUser[_user];
        Offer[] memory _offers = new Offer[](userOfferIds.length);
        for (uint i=0; i < userOfferIds.length; i++){
            uint offerId = userOfferIds[i]; 
            _offers[i] = offers[offerId];
        }
        return _offers;
    }

    function getAuctionOffers(uint _auctionId)
        external
        view
        returns (Offer[] memory)
    {
        Auction storage auction = auctions[_auctionId];
        uint[] storage offerIds = auction.offerIds;
        Offer[] memory _offers = new Offer[](offerIds.length);
        for(uint i=0; i<offerIds.length; i++){
            uint offerId = offerIds[i];
            _offers[i]=offers[offerId];
        }
        return _offers;
    }

}