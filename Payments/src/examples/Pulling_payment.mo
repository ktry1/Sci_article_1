//Base libraries
import Result "mo:base/Result";
import Principal "mo:base/Principal";
//Importing Ledger smart-contract for payments
import Ledger "canister:icp_ledger_canister";
//Importing libraries from MOPS for custom types
import RBT "mo:stable-rbtree/StableRBTree";

//This is an example on how you can use the ICRC-2 standard to safely accept payments from users

actor Contract {

    let TRANSFER_FEE : Nat = 10000; //Fee for Ledger transactions

    //Errors to throw at users
    type Errors = {
        #Insufficient_funds;
    };

    //Data structure for storing user donations
    stable var user_donations = RBT.init<Principal, Nat>();
    
    //Function for pulling user payments
    public shared ({ caller }) func pull_payment() : async Result.Result<{}, Errors> {
        
        //We get the number of tokens approved by the user to our contract
        let allowance_data = await Ledger.icrc2_allowance({
        account = { owner = caller; subaccount = null };
        spender = { owner = Principal.fromActor(Contract); subaccount = null }
        });
        //If the approved amount is more than the transfer fee
        if (allowance_data.allowance > TRANSFER_FEE) {
        //We receive the transfer amount, taking into account the transfer fee
        let donationValue = allowance_data.allowance - TRANSFER_FEE;
        let result = await Ledger.icrc2_transfer_from({
            amount = donationValue; created_at_time = null;
            from = { owner = caller; subaccount = null };
            fee = null; memo = null; spender_subaccount = null;
            to = { owner = Principal.fromActor(Contract); subaccount = null }
        });
        switch (result) {
        case(#Ok(Nat)) {
            //Any functionality to update the user balance, in this case a Red-black tree with donations
            let prevDonationValue = switch (RBT.get(user_donations, Principal.compare, caller)) {
                case (null) {0}; //user did not previously donate
                case (?prevDonationValue) {prevDonationValue}; //user donated previously
            };
            //Updating the user's balance;
            user_donations := RBT.put(user_donations, Principal.compare, caller, prevDonationValue + donationValue);
            return #ok{};
        }; 
        case(#Err(any)) {return #err(#Insufficient_funds)};
        };
        } else {return #err(#Insufficient_funds);}
    }
}