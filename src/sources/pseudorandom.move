/// @title pseudorandom
/// @notice A pseudo random module on-chain.
/// @dev Warning: 
/// The random mechanism in smart contracts is different from 
/// that in traditional programming languages. The value generated 
/// by random is predictable to Miners, so it can only be used in 
/// simple scenarios where Miners have no incentive to cheat. If 
/// large amounts of money are involved, DO NOT USE THIS MODULE to 
/// generate random numbers; try a more secure way.
module suidoku::pseudorandom {
    use std::bcs;
    use std::hash;
    use std::vector;

    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use suidoku::bcd;

    const ENOT_ROOT: u64 = 0;
    const EHIGH_ARG_GREATER_THAN_LOW_ARG: u64 = 1;

    /// Object that wraps an integer counter.
    struct Counter has key {
        id: UID,
        value: u64
    }

    /// Share a `Counter` resource with value `i`.
    fun init(ctx: &mut TxContext) {
        // Create and share a Counter object. This is a privileged operation that
        // can only be done inside the module that declares the `Counter` object
        transfer::share_object(
            Counter {
                id: object::new(ctx),
                value: 0
            }
        );
    }

    /// Increment the value of the supplied `Counter` resource.
    fun increment(counter: &mut Counter): u64 {
        let c_ref = &mut counter.value;
        *c_ref = *c_ref + 1;
        *c_ref
    }

    /// Acquire a seed using: the hash of the counter, epoch, sender address, and new object ID.
    fun seed(counter: &mut Counter, ctx: &mut TxContext): vector<u8> {
        let counter_val = increment(counter);
        let counter_bytes = bcs::to_bytes(&counter_val);

        let epoch: u64 = tx_context::epoch(ctx);
        let epoch_bytes: vector<u8> = bcs::to_bytes(&epoch);

        let sender = tx_context::sender(ctx);
        let sender_bytes: vector<u8> = bcs::to_bytes(&sender);

        let uid = object::new(ctx);
        let object_id_bytes: vector<u8> = object::uid_to_bytes(&uid);
        object::delete(uid);

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, counter_bytes);
        vector::append<u8>(&mut info, sender_bytes);
        vector::append<u8>(&mut info, epoch_bytes);
        vector::append<u8>(&mut info, object_id_bytes);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }

    /// Acquire a seed using: the hash of the epoch, sender address, and new object ID.
    fun seed_no_counter(ctx: &mut TxContext): vector<u8> {
        let epoch: u64 = tx_context::epoch(ctx);
        let epoch_bytes: vector<u8> = bcs::to_bytes(&epoch);

        let sender = tx_context::sender(ctx);
        let sender_bytes: vector<u8> = bcs::to_bytes(&sender);

        let uid = object::new(ctx);
        let object_id_bytes: vector<u8> = object::uid_to_bytes(&uid);
        object::delete(uid);

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, sender_bytes);
        vector::append<u8>(&mut info, epoch_bytes);
        vector::append<u8>(&mut info, object_id_bytes);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }
    
    /// Acquire a seed using: the hash of the counter and sender address.
    fun seed_no_ctx(sender: address, counter: &mut Counter): vector<u8> {
        let counter_val = increment(counter);
        let counter_bytes = bcs::to_bytes(&counter_val);

        let sender_bytes: vector<u8> = bcs::to_bytes(&sender);

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, counter_bytes);
        vector::append<u8>(&mut info, sender_bytes);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }

    /// Acquire a seed using: the hash of the counter.
    fun seed_with_counter(counter: &mut Counter): vector<u8> {
        let counter_val = increment(counter);
        let counter_bytes = bcs::to_bytes(&counter_val);

        let hash: vector<u8> = hash::sha3_256(counter_bytes);
        hash
    }


    /// Generate a random u128
    public fun rand_u128_with_seed(seed: vector<u8>): u128 {
        bcd::bytes_to_u128(seed)
    }

    /// Generate a random integer range in [low, high).
    public fun rand_u128_range_with_seed(seed: vector<u8>, low: u128, high: u128): u128 {
        assert!(high > low, EHIGH_ARG_GREATER_THAN_LOW_ARG);
        let value = rand_u128_with_seed(seed);
        (value % (high - low)) + low
    }

    /// Generate a random u64
    public fun rand_u64_with_seed(seed: vector<u8>): u64 {
        bcd::bytes_to_u64(seed)
    }

    /// Generate a random integer range in [low, high).
    public fun rand_u64_range_with_seed(seed: vector<u8>, low: u64, high: u64): u64 {
        assert!(high > low, EHIGH_ARG_GREATER_THAN_LOW_ARG);
        let value = rand_u64_with_seed(seed);
        (value % (high - low)) + low
    }

    public fun rand_u128(counter: &mut Counter, ctx: &mut TxContext): u128 {
        rand_u128_with_seed(seed(counter, ctx)) 
    }

    public fun rand_u128_range(
        counter: &mut Counter,
        low: u128,
        high: u128,
        ctx: &mut TxContext
    ): u128 {
        rand_u128_range_with_seed(seed(counter, ctx), low, high) 
    }

    public fun rand_u64(counter: &mut Counter, ctx: &mut TxContext): u64 {
        rand_u64_with_seed(seed(counter, ctx)) 
    }

    public fun rand_u64_range(
        counter: &mut Counter,
        low: u64,
        high: u64,
        ctx: &mut TxContext
    ): u64 {
        rand_u64_range_with_seed(seed(counter, ctx), low, high) 
    }

    public fun rand_u128_no_counter(ctx: &mut TxContext): u128 {
        rand_u128_with_seed(seed_no_counter(ctx)) 
    }

    public fun rand_u128_range_no_counter(
        low: u128,
        high: u128, 
        ctx: &mut TxContext
    ): u128 {
        rand_u128_range_with_seed(seed_no_counter(ctx), low, high) 
    }

    public fun rand_u64_no_counter(ctx: &mut TxContext): u64 { 
        rand_u64_with_seed(seed_no_counter(ctx)) 
    }

    public fun rand_u64_range_no_counter(
        low: u64,
        high: u64, 
        ctx: &mut TxContext
    ): u64 { 
        rand_u64_range_with_seed(seed_no_counter(ctx), low, high) 
    }

    public fun rand_u128_no_ctx(sender: address, counter: &mut Counter): u128 { 
        rand_u128_with_seed(seed_no_ctx(sender, counter)) 
    }

    public fun rand_u128_range_no_ctx(
        sender: address,
        counter: &mut Counter, 
        low: u128, 
        high: u128
    ): u128 { 
        rand_u128_range_with_seed(seed_no_ctx(sender, counter), low, high) 
    }

    public fun rand_u64_no_ctx(sender: address, counter: &mut Counter): u64 { 
        rand_u64_with_seed(seed_no_ctx(sender, counter)) 
    }

    public fun rand_u64_range_no_ctx(
        sender: address,
        counter: &mut Counter,
        low: u64,
        high: u64
    ): u64 { 
        rand_u64_range_with_seed(seed_no_ctx(sender, counter), low, high) 
    }

    public fun rand_u128_with_counter(counter: &mut Counter): u128 { 
        rand_u128_with_seed(seed_with_counter(counter)) 
    }

    public fun rand_u128_range_with_counter(
        counter: &mut Counter,
        low: u128,
        high: u128
    ): u128 { 
        rand_u128_range_with_seed(seed_with_counter(counter), low, high) 
    }

    public fun rand_u64_with_counter(counter: &mut Counter): u64 { 
        rand_u64_with_seed(seed_with_counter(counter)) 
    }

    public fun rand_u64_range_with_counter(
        counter: &mut Counter,
        low: u64, 
        high: u64
    ): u64 { 
        rand_u64_range_with_seed(seed_with_counter(counter), low, high) 
    }
}
