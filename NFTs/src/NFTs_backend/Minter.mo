//Base libraries
import Principal "mo:base/Principal";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
//Importing libraries from MOPS for custom types
import RBTree "mo:base/RBTree";
import Vec "mo:vector";
import Map "mo:map/Map";
import { phash; nhash } "mo:map/Map";
import RBT "mo:stable-rbtree/StableRBTree";
import LinkedList "mo:linked-list";
//Importing Ledger smart-contract for payments
import Ledger "canister:icp_ledger_canister";
//Locally defined types and Errors
import Types "./Types";

actor Minter {
    stable let OWNER_SHARE = 50;
    stable let USER_SHARE = 950;
    let TRANSFER_FEE : Nat = 10000;
    stable var initialized : Bool = false;
    stable var ownerStorage : Principal = Principal.fromText("aaaaa-aa");
    stable var minter : Principal = Principal.fromText("aaaaa-aa");
    stable var nfts = Vec.new<Text>(); //URIs for all minted NFTs
    stable var ownership = Vec.new<Principal>();
    stable var ownedNfts = Map.new<Principal, RBT.Tree<Nat, Bool>>();
    stable var listedItems = RBT.init<Nat, Types.ListingData>();
    stable var transactionHistory = Vec.new<LinkedList.LinkedList<Types.Transaction>>();
    let lockedItems =  RBTree.RBTree<Nat, Bool>(Nat.compare);

    //Rejecting all anonymous messages
    system func inspect({ caller : Principal }) : Bool {
        not (Principal.isAnonymous(caller))
    };

    //==================================================
    //func group - functions that are called by the contract itself
    //==================================================
    //Remove nft from owned after it is sold or burned
    func remove_owned_nft(id : Nat, owner : Principal) {
        let owned_nfts = Map.get(ownedNfts, phash, owner);
        switch owned_nfts {
            case(null) {};
            case(?owned_nfts) {
                Map.set(ownedNfts, phash,
                owner, RBT.delete(owned_nfts,  Nat.compare, id));
            }
        };
    };

    //Adding nfts to owned after buying or transfering
    func add_owned_nft(id : Nat, owner : Principal) {
        var owned_nfts = Map.get(ownedNfts, phash, owner);
        switch owned_nfts {
            case(null) {
                //Creating an empty tree and adding the token id to it
                var owned_nfts = RBT.init<Nat, Bool>();
                owned_nfts := RBT.put(owned_nfts, Nat.compare, id, true);
                ignore Map.put(ownedNfts, phash, owner, owned_nfts);
            };
            case(?owned_nfts) {
                Map.set(ownedNfts, phash, owner,
                RBT.put(owned_nfts, Nat.compare, id, true));
            }
        };
    };

    //==================================================
    //public shared({caller}) func : async (Result.Result<{}, Types.Errors>) group - functions that are called by the users
    //==================================================
    //Initializing our contract
    public shared({caller}) func initialize(new_owner_storage : Principal) : async Result.Result<{}, Types.Errors> {
    if (initialized == true) {
        return #err(#Already_Initialized);
    } else {
        initialized := true;
        minter := caller;
        ownerStorage := new_owner_storage;
        return #ok{};
      };
    };
    
    //Function for minting new NFTs, which can only be called by minter address
    public shared({caller}) func _mint (uri : Text, _price : Nat64) : async Result.Result<{}, Types.Errors> {
        let price = Nat64.toNat(_price); //Converting Nat64 to Nat
        if (caller == minter) {
            let id = Vec.size(nfts);
            Vec.add(nfts, uri); //Adding the URI of a new token
            Vec.add(ownership, Principal.fromActor(Minter));//Owner - smart contract 
            //Select a cell in the vector with transaction history
            Vec.add(transactionHistory, LinkedList.LinkedList<Types.Transaction>());
            //We put it up for sale
            listedItems := RBT.put(listedItems, Nat.compare, id, {price = price;
            listed_time = Time.now()});
            return #ok{};
        } else {
            return #err(#Unauthorized);
        };
    };

    //Function for burning NFTs by users or Minter
    public shared({caller}) func _burn (_id : Nat64) : async Result.Result<{}, Types.Errors> {
        let id = Nat64.toNat(_id);
        if (caller != Vec.get(ownership, id)) {return #err(#Not_Owner)};
        Vec.put(ownership, id, Principal.fromText("aaaaa-aa"));
        remove_owned_nft(id, caller);
        listedItems := RBT.delete(listedItems, Nat.compare, id);
        return #ok{};
    };

    //Function for listing an owned NFT on the market
    public shared({caller}) func list_nft(_id : Nat64, _price : Nat64) : async Result.Result<{}, Types.Errors> {
        //Converting Nat64 to Nat for ease of use
        let id = Nat64.toNat(_id);
        let price = Nat64.toNat(_price);
        //Checking whether the user owns the token
        let owner = Vec.get(ownership, id);
        if (owner != caller) {
            return #err(#Not_Owner);
        };

        //Checking to see if the token is already up for sale
        let listing = RBT.get(listedItems, Nat.compare, id);
        switch (listing) {
            case (null) {};
            case (?listing) {return #err(#NFT_Already_Listed)};
        };

        //We check that the price is within acceptable standards
        if (price < 100000000 or price > 10000000000000) {
            return #err(#Invalid_Price);
        };

        //We put the token up for sale
        let listed_time = Time.now();
        listedItems := RBT.put(listedItems, Nat.compare, id, {price = price; listed_time = listed_time});
        return #ok{};
    };

    //Function for removing listed owned NFTs from market
    public shared({caller}) func remove_nft_listing(_id : Nat64) : async Result.Result<{}, Types.Errors> {
        //Convert Nat64 to Nat for ease of use
        let id = Nat64.toNat(_id);
        //Checking whether the user owns the token
        let owner = Vec.get(ownership, id);
        if (owner != caller) {
        return #err(#Not_Owner);
        };

        //We check that the token is really listed for sale
        let listing = RBT.get(listedItems, Nat.compare, id);
        switch (listing) {
        case (null) {return #err(#NFT_Not_Listed)};
        case (?listing) {
            //Deleting listing
            listedItems := RBT.delete(listedItems, Nat.compare, id);
        return #ok{};
        };
        };
    };

    //Function for buying NFTs
    public shared({caller}) func buy_nft(_id : Nat64, _price : Nat64) : async Result.Result<{}, Types.Errors> {
        let id = Nat64.toNat(_id); //Converting Nat64 to Nat for convenience
        let is_locked = lockedItems.get(id);
    
        //We check that another user is not currently trying to buy the token
        switch (is_locked) {
            case (null) {};
            case (?is_locked) {
                return #err(#Other_User_Transaction_In_Process);
            }
        };
        
        //Checking that the token is up for sale
        let listing = RBT.get(listedItems, Nat.compare, id);

        switch (listing) {
            case (null) {return #err(#NFT_Not_Listed)};
            case (?listing) {
            //Checking that the user is not trying to buy a token from himself
            let owner = Vec.get(ownership, id);

            if (owner == caller) {return #err(#Self_Buy)};
            //Checking that the user’s approved ICRC-2 balance is sufficient for the purchase
            let allowance_data = await Ledger.icrc2_allowance({
            account = { owner = caller; subaccount = null };
            spender = { owner = Principal.fromActor(Minter); subaccount = null }
            });

            if (allowance_data.allowance < listing.price) {
            return #err(#Insufficient_Funds);
            } else {

            lockedItems.put(id, true); //We block the token for the duration of transaction

            if (owner != Principal.fromActor(Minter)) { //If the owner is the user and not the contract
            
            let result_1 = await Ledger.icrc2_transfer_from({
            amount = listing.price * USER_SHARE / 1000 - TRANSFER_FEE;
            created_at_time = null;
            from = { owner = caller; subaccount = null };
            fee = null;
            memo = null;
            spender_subaccount = null;
            to = { owner = owner; subaccount = null }
            });

            //Checking that the payment to the seller was successful
            switch (result_1) {
            case (#Err(other)) {
                lockedItems.delete(id); //Unlocking the item
                return #err(#Insufficient_Funds);
            };
            case (_) {};
            };

            let result_2 = await Ledger.icrc2_transfer_from({
            amount = listing.price * OWNER_SHARE / 1000 - TRANSFER_FEE;
            created_at_time = null;
            from = { owner = caller; subaccount = null };
            fee = null;
            memo = null;
            spender_subaccount = null;
            to = { owner = ownerStorage; subaccount = null }
            });

            //Checking that the payment of the fee was successful
            switch (result_2) {
            case (#Err(other)) {
                lockedItems.delete(id); //Unlocking the item
                return #err(#Insufficient_Funds);
            };
            case (_) {};
            };

        } else { //If the token seller is our smart contract
            let result = await Ledger.icrc2_transfer_from({
            amount = listing.price - TRANSFER_FEE;
            created_at_time = null;
            from = { owner = caller; subaccount = null };
            fee = null;
            memo = null;
            spender_subaccount = null;
            to = { owner = ownerStorage; subaccount = null }
            });

            //Checking that the payment was successful
            switch (result) {
            case (#Err(other)) {
                lockedItems.delete(id); //Unlocking the item
                return #err(#Insufficient_Funds);
            };
            case (_) {};
            };
        };

        //Updating transaction history
        let transactions_data = Vec.get(transactionHistory, id);

        LinkedList.prepend(transactions_data, {
            from = owner;
            to = caller;
            price = listing.price;
            time = Time.now()
        });
        //If the number of saved transactions is > 10, delete the oldest one
        if (LinkedList.size(transactions_data) > 10) {
            ignore LinkedList.remove(transactions_data, 10);
        };

        if (owner != Principal.fromActor(Minter)){
            //We remove the id of the sold token from those belonging to the seller
            remove_owned_nft(id, owner);
        };
        //Adding the id of the sold token to those belonging to the buyer
        add_owned_nft(id, caller);

        //Removing the token from the list of those listed for sale
        listedItems := RBT.delete(listedItems, Nat.compare, id);
        //We transfer the ownership of the token to the buyer
        Vec.put(ownership, id, caller);
        //We remove the token from the list of those that are currently trying to buy
        lockedItems.delete(id);
        return #ok{};
        };
      
        };
        }
    };

    //==================================================
    //public func group - functions for viewing verified data on the frontend
    //==================================================

    //Function for getting verified listing data on the frontend
    public func get_listings() : async ([{uri : Text; listing_data : Types.ListingData}]) {
        //Buffer, into which we will enter data for each token
        var listings_buffer = Buffer.Buffer<{uri : Text; listing_data : Types.ListingData}>(RBT.size(listedItems));
        //Collecting data - URI from nfts and sales data from listedItems
        for (entry in RBT.iter(listedItems, #fwd)) {
            let nft_uri = Vec.get(nfts, entry.0);
            listings_buffer.add({uri = nft_uri; listing_data = entry.1});
        };
        //Convert Buffer to Array and return response
        return Buffer.toArray(listings_buffer);
    };

    //Function for getting verified data about a single listing and it's transaction history
    public func get_listing_data(_id : Nat64) : async (Result.Result<{uri : Text; owner : Principal;  listing_data : Types.ListingData; transaction_history : [Types.Transaction]}, Types.Errors>) {
         let id = Nat64.toNat(_id);
        let nft_uri : Text = switch(Vec.getOpt(nfts, id)){
            case(null) {return #err(#NFT_Does_Not_Exist)};
            case (?uri) {
                uri;
            }
        };

        let nft_listing_data = switch(RBT.get(listedItems, Nat.compare, id)) {
            case (null) {return #err(#NFT_Not_Listed)};
            case (?listing_data) {listing_data};
        };

        let nft_transaction_history = Vec.get(transactionHistory, id);
        let nft_owner = Vec.get(ownership, id);

        return #ok{uri = nft_uri; owner = nft_owner; listing_data = nft_listing_data;
         transaction_history = LinkedList.toArray(nft_transaction_history)};
    };

    //==================================================
    //public query func group - for fast viewing of not sensitive data on the frontend
    //==================================================

    //Function for viewing total number of NFTs owned by user
    public query func balance_of(owner : Principal) : async (Nat) {
        let user_nfts = Map.get(ownedNfts, phash, owner);
        switch (user_nfts) {
            case (null) {return 0}; //If there is no list of owned tokens => balance = 0
            case (?user_nfts) return RBT.size(user_nfts);
        };
    };

    //Function for viewing ids' of all NFTs owned by the user
    public query func owned_nfts(owner : Principal) : async ([Nat]) {
        let user_nfts = Map.get(ownedNfts, phash, owner);
        switch (user_nfts) {
            case (null) return [];
            case (?user_nfts) {
                let nfts_buffer = Buffer.Buffer<Nat>(RBT.size(user_nfts));
                for (entry in RBT.entries(user_nfts)) {
                nfts_buffer.add(entry.0);
                };
                return Buffer.toArray(nfts_buffer);
        };
        };
    };

    //Function for viewing URI of single NFT
    public query func token_URI(_id : Nat64) : async (Result.Result<Text, Types.Errors>) {
        let id : Nat = Nat64.toNat(_id);
        let nft = Vec.getOpt(nfts, id);
        switch (nft) {
            case (null) {return #err(#NFT_Does_Not_Exist)};
            case (?nft) {return #ok(nft)};
        };
    };

}