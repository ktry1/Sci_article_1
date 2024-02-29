//Base libraries
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Timer "mo:base/Timer";
import { recurringTimer } "mo:base/Timer";
//Importing libraries from MOPS for custom types
import RBT "mo:stable-rbtree/StableRBTree";
//Locally defined types and Errors
import Types "./Types";
//Importing Ledger smart-contract for payments
import Ledger "canister:icp_ledger_canister";

actor OwnerStorage {

    stable var payees = RBT.init<Principal, Nat>();
    stable var timerId : Nat = 0;
    let MAX_SHARES : Nat = 1000;
    var sharesLeft : Nat = 1000;
    let TRANSFER_FEE = 10000;
    var initialized = false;
    var admin : Principal = Principal.fromText("aaaaa-aa");

    func payout() : async () {
        let balance = await Ledger.icrc1_balance_of({owner = Principal.fromActor(OwnerStorage); subaccount = null});
        for (entry in RBT.entries(payees)) {
            ignore await Ledger.icrc1_transfer({
            to = { owner = entry.0; subaccount = null };
            amount = balance * entry.1 / 1000 - TRANSFER_FEE;
            created_at_time = null;
            fee = null;
            from_subaccount = null;
            memo = null
        });
        };
    };

    public shared({caller}) func add_payee(principal : Principal, _share : Nat64) : async Result.Result<{}, Types.Errors> {
        let share = Nat64.toNat(_share);
        if (caller != admin) {return #err(#Unathorized)};
        if (sharesLeft < share) {return #err(#Not_Enough_Shares_left)};
        let payee = RBT.get(payees, Principal.compare, principal);
        switch (payee) {
            case (null) {
                sharesLeft -= share;
                payees := RBT.put(payees, Principal.compare, principal, share);
                return #ok{};
            };
            case (?payee) {return #err(#Payee_Already_Exists)};
        };
    };

    public shared ({caller}) func remove_payee(principal : Principal) : async Result.Result<{}, Types.Errors> {
        if (caller != admin) {return #err(#Unathorized)};
        let payee_share = RBT.get(payees, Principal.compare, principal);
        switch (payee_share) {
            case (null) {return #err(#Payee_Does_Not_Exist)};
            case (?payee_share) {
                payees := RBT.delete(payees, Principal.compare, principal);
                sharesLeft += payee_share;
                return #ok{};
            };
        };
    };

    public shared({caller}) func update_payee(principal : Principal, _share : Nat64) : async Result.Result<{}, Types.Errors>  {
        let share = Nat64.toNat(_share);
        if (caller != admin) {return #err(#Unathorized)};
        let payee_share = RBT.get(payees, Principal.compare, principal);
        switch (payee_share) {
            case (null) {return #err(#Payee_Does_Not_Exist)};
            case (?payee_share) {
                if (sharesLeft + payee_share < share) {return #err(#Not_Enough_Shares_left)};
                payees := RBT.put(payees, Principal.compare, principal, share);
                sharesLeft := sharesLeft + payee_share - share;
                return #ok{};
            };
        }; 
    };

    public shared({caller}) func initialize() {
        admin := caller;
        timerId := recurringTimer(#seconds 2592000, payout);
    };

    public shared ({caller}) func get_payees() : async Result.Result<[(Principal, Nat)], Types.Errors> {
        if (caller != admin) {return #err(#Unathorized)};
        return #ok(Iter.toArray(RBT.iter(payees, #fwd)));
    };

    public shared({caller}) func trigger_payout() : async Result.Result<{}, Types.Errors> {
        if (caller != admin) {return #err(#Unathorized)};
        Timer.cancelTimer(timerId);
        ignore payout();
        timerId := recurringTimer(#seconds 2592000, payout);
        return #ok{};
    };

    public shared({caller}) func transfer_admin(new_admin : Principal) : async Result.Result<{}, Types.Errors> {
        if (caller != admin) {return #err(#Unathorized)};
        admin := new_admin;
        return #ok{};
    };

};