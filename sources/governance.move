module overmind::governance {

    //==============================================================================================
    // Dependencies - DO NOT MODIFY
    //==============================================================================================

    use aptos_framework::voting;    
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::simple_map::{Self, SimpleMap};
    use aptos_token_objects::collection::{Self, Collection};
    use aptos_framework::account::{Self, SignerCapability};
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::property_map;
    use std::vector;
    use aptos_token_objects::token;
    use aptos_framework::event::{Self, EventHandle};
    use std::string_utils;

    #[test_only]
    use aptos_framework::transaction_context;

    //==============================================================================================
    // Constants - DO NOT MODIFY
    //==============================================================================================

    const MAX_U64: u64 = 18446744073709551615;

    const SEED: vector<u8> = b"governance";

    // Base strings
    const BASE_PROPOSAL_ID_KEY: vector<u8> = b"vote_for_proposal_id_#";
    const BASE_TOKEN_DESCRIPTION: vector<u8> = b"Governance token for account: ";

    const PROPOSAL_STATE_SUCCEEDED: u64 = 1;

    // Starting values
    const STARTING_MINIMUM_VOTING_THRESHOLD: u128 = 1;
    const STARTING_VOTING_DURATION_SECONDS: u64 = 86400; // 1 day
    const STARTING_GOVERNANCE_TOKEN_DESCRIPTION: vector<u8> = b"unset governance token description";
    const STARTING_GOVERNANCE_TOKEN_URI: vector<u8> = b"unset governance token uri";

    // Admin starting values
    const ADMIN_STARTING_VOTING_POWER: u64 = 1;
    const ADMIN_STARTING_PROPOSAL_ABILITY: bool = true;
    const ADMIN_STARTING_URI: vector<u8> = b"";

    // Resource account key values
    const RESOURCE_ACCOUNT_SIGNER_CAP_KEY: vector<u8> = b"resource account signer";
    const RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION: vector<u8> = b"signer cap of the module's resource account";

    const GOVERNANCE_TOKEN_COLLECTION_NAME: vector<u8> = b"Governance membership token collection";

    // Governance token keys
    const GOVERNANCE_TOKEN_VOTING_POWER_KEY: vector<u8> = b"voting_power";
    const GOVERNANCE_TOKEN_PROPOSAL_ABILITY_KEY: vector<u8> = b"proposal_ability";

    // Metadata keys
    const METADATA_LOCATION_KEY: vector<u8> = b"metadata_location";
    const METADATA_HASH_KEY: vector<u8> = b"metadata_hash";

    //==============================================================================================
    // Error codes - DO NOT MODIFY
    //==============================================================================================

    const EVoterAlreadyVotedOnProposal: u64 = 11;
    const EProposalVotingIsClosed: u64 = 12;
    const EInvalidMetadataLocation: u64 = 13;
    const EInvalidMetadataHash: u64 = 14;
    const EAccountDoesNotHaveProposalAbility: u64 = 15;
    const EProposalCannotBeResolved: u64 = 16;
    const EAddressIsNotAnObject: u64 = 18;
    const EAccountIsNotResourceAccount: u64 = 19;
    const EInvalidProposalId: u64 = 20;
    const EHashDoesNotExist: u64 = 21;

    //==============================================================================================
    // Module Structs - DO NOT MODIFY
    //==============================================================================================

    /*
        The proposal type used with the aptos_framework::voting module
    */
    struct GovernanceProposalType has store, drop {}

    /*
        Holds the minimum voting threshold and voting duration seconds which can be dynamically changed
        via the module's governance proposals
    */
    struct GovernanceConfig has key, drop {
        // the minimum number of supporting votes a proposal needs in order to pass
        minimum_voting_threshold: u128, 
        // the number of seconds which voting is open for a proposal
        voting_duration_seconds: u64,
    }

    /*
        Holds all of the signer caps of signers that are available to the proposals
    */
    struct GovernanceResponsibility has key, drop {
        signer_caps: SimpleMap<GovernanceResponsibilityKey, SignerCapability>
    }

    /*
        The key structure for the GovernanceResponsibility SimpleMap. We include a description to help
        with understandability when looking at available signer caps.
    */
    struct GovernanceResponsibilityKey has store, drop {
        // the label of the signer cap
        key: String, 
        // the description of the signer cap
        description: String
    }

    /*
        A list of approved proposal execution hashes. This is used to make sure only approved proposal
        scripts can be ran
    */
    struct ApprovedExecutionHashes has key {
        hashes: SimpleMap<u64, vector<u8>>
    }

    /*
        The token type for this module's governance token
    */
    struct GovernanceToken has key {
        // Used to mutate the token uri
        mutator_ref: token::MutatorRef,
        // Used to burn tokens
        burn_ref: token::BurnRef,
        // Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
    }

    /*
        The object to hold all of the events emitted by this module
    */
    struct GovernanceEvents has key {
        create_proposal_events: EventHandle<CreateProposalEvent>,
        vote_events: EventHandle<VoteEvent>,
        updated_governance_config_events: EventHandle<UpdateGovernanceConfigEvent>,
        update_governance_responsibility_events: EventHandle<UpdateGovernanceResponsibilityEvent>,
        add_approved_execution_hash_events: EventHandle<AddApprovedExecutionHashEvent>,
        resolve_proposal_events: EventHandle<ResolveProposalEvent>
    }

    //==============================================================================================
    // Event structs - DO NOT MODIFY
    //==============================================================================================

    struct  CreateProposalEvent  has store, drop {
        proposer: address, 
        proposer_governance_token_address: address, 
        proposal_id: u64, 
        execution_hash: vector<u8>,
        proposal_metadata: SimpleMap<String, vector<u8>>
    }

    struct VoteEvent has store, drop {
        proposal_id: u64, 
        voter: address, 
        voting_power: u64, 
        should_pass: bool
    }

    struct UpdateGovernanceConfigEvent has store, drop {
        old_minimum_voting_threshold: u128, 
        old_voting_duration_seconds: u64, 
        new_mimimum_voting_threshold: u128, 
        new_voting_duration_seconds: u64
    }

    struct UpdateGovernanceResponsibilityEvent has store, drop {
        old_signer_key: Option<String>,
        old_signer_description: Option<String>,
        new_signer_key: String, 
        new_signer_description: String
    }

    struct AddApprovedExecutionHashEvent has store, drop {
        proposal_id: u64
    }

    struct ResolveProposalEvent has store, drop {
        proposal_id: u64, 
        signer_key: String, 
        signer_description: String
    }

    //==============================================================================================
    // Functions
    //==============================================================================================

    /* 
        Initializes the module.
        @param admin - signer representing the admin
    */
    fun init_module(admin: &signer) {

        // TODO: Create the resource account using the admin account and the provide SEED constant

        // TODO: Register with the aptos_framework::voting module using the GovernanceProposalType and resource account

        // TODO: Create an unlimited NFT collection with the following aspects: 
        //       - creator: resource account
        //       - description: STARTING_GOVERNANCE_TOKEN_DESCRIPTION 
        //       - name: GOVERNANCE_TOKEN_COLLECTION_NAME
        //       - royalty: no royalty
        //       - uri: STARTING_GOVERNANCE_TOKEN_URI

        // TODO: Mint a governance token for the admin with the following aspects: 
        //       - uri: ADMIN_STARTING_URI
        //       - voting power: ADMIN_STARTING_VOTING_POWER
        //       - can propose: ADMIN_STARTING_PROPOSAL_ABILITY
        // 
        // HINT: use the mint_governance_token below

        // TODO: Create the GovernanceConfig object with STARTING_MINIMUM_VOTING_THRESHOLD and 
        //       STARTING_VOTING_DURATION_SECONDS

        // TODO: Create the GovernanceResponsibility, initialized with the resource account's signer cap

        // TODO: Create the ApprovedExecutionHashes with an empty map

        // TODO: Create the GovernanceEvents object
        
        // TODO: Move the 4 new global objects to the resource account

    }

    /* 
        Create a proposal
        @param proposer - signer representing the account who is creating the proposal
        @param execution_hash - A hash of the proposal's execution script module
        @param metadata_location - The location of the proposal's metadata (used by the voting module)
        @param metadata_hash - The hash of the proposal's metadata (used by the voting module)
    */
    public entry fun create_proposal(
        proposer: &signer,
        execution_hash: vector<u8>,
        metadata_location: vector<u8>,
        metadata_hash: vector<u8>,
        is_multi_step_proposal: bool,
    ) acquires GovernanceConfig, GovernanceEvents {

        // TODO: Get the address of the proposer's expected governance token and make sure it is an object
        // 
        // HINT: Use the check_if_address_is_an_object function below

        // TODO: Create the governance token object and make sure the proposer has the ability to create proposals
        //
        // HINT: Use the check_if_account_can_create_proposal function below

        // TODO: Create the proposal metadata using the metadata location and hash
        // 
        // HINT: Use the create_proposal_metadata function below

        // TODO: Generate the early resolution vote threshold 
        // 
        // HINT: Use the generate_early_resolution_vote_threshold function below

        // TODO: Create the new proposal
        //
        // HINT: Use the create_proposal_internal function below

        // TODO: Emit a new CreateProposalEvent

    }

    /* 
        Vote for a specific proposal
        @param voter - signer representing the account who is voting 
        @param proposal_id - The id of the proposal to vote for
        @param should_pass - Whether the voter wants the proposal to pass or not
    */
    public entry fun vote (
        voter: &signer, 
        proposal_id: u64, 
        should_pass: bool
    ) acquires GovernanceToken, GovernanceEvents {

        // TODO: Get the address of the voter's expected governance token and make sure it is an object
        // 
        // HINT: Use the check_if_address_is_an_object function below
        
        // TODO: Fetch the governance token object from the expected address
        
        // TODO: Ensure that the voter has not already voted on this proposal
        //
        // HINT: Use the check_if_voter_has_not_voted_on_proposal function below

        // TODO: Ensure that voting is still open for the proposal
        //
        // HINT: Use the check_if_proposal_voting_is_open function below

        // TODO: Generate the proposal id key and add this vote to the governance token's property_map
        // 
        // HINT: Use the generate_proposal_id_key function to generate the proposal id key

        // TODO: Fetch the voter's voting power and execute the vote
        // 
        // HINT: Use the vote_internal function below 

        // TODO: Emit a VoteEvent

    }

    /* 
        Modifies the governance config global object with new value(s)
        @param resource_account_signer - signer representing the module's resource account
        @param minimum_voting_threshold - the new minimum voting threshold
        @param voting_duration_seconds - the new voting duraton in seconds
    */
    public fun update_governance_config(
        resource_account_signer: &signer, 
        minimum_voting_threshold: u128, 
        voting_duration_seconds: u64
    ) acquires GovernanceConfig, GovernanceEvents {

        // TODO: Get the address of the resource_account_signer and ensure it is the actual resource account
        //
        // HINT: Use the check_if_account_is_resource_account_address function below
        
        // TODO: Borrow the GovernanceConfig
        
        // TODO: Record the old config values
        
        // TODO: Update the config with the new values

        // TODO: Emit the UpdateGovernanceConfigEvent

    }

    /* 
        Modifies the governance responsibility with a new or updated signer capability
        @param resource_account_signer - signer representing the module's resource account
        @param key - the key of the signer cap to be added or updated
        @param description - the description of the signer cap to be added or updated
        @param signer_cap - the new signer cap to be added
    */
    public fun update_governance_responsibility(
        resource_account_signer: &signer,
        key: String, 
        description: String,
        signer_cap: SignerCapability
    )  acquires GovernanceResponsibility, GovernanceEvents {

        // TODO: Get the address of the resource_account_signer and ensure it is the actual resource account
        //
        // HINT: Use the check_if_account_is_resource_account_address function below

        // TODO: Update the GovernanceResponsibility's with the new key, description, and signer_cap

        // TODO: Emit the UpdateGovernanceResponsibilityEvent

    }

    /* 
        Add a proposal's execution script hash to the approved list of hashes once it has been passed
        @param proposal_id - the id of the proposal 
    */
    public entry fun add_approved_script_hash(proposal_id: u64) acquires ApprovedExecutionHashes, GovernanceEvents {
        let resource_account_address = get_resource_account_address();

        // TODO: Ensure the proposal id is valid
        // 
        // HINT: Use the check_if_proposal_id_is_valid function below

        // TODO: Ensure the proposal can be resolved
        // 
        // HINT: Use the check_if_proposal_can_be_resolved function below

        
        // TODO: Update ApprovedExecutionHashes with this proposal's hash
        // 
        // HINT: If this is a multi-step proposal, the proposal id will already exist in the 
        //       ApprovedExecutionHashes map. We will update execution hash in ApprovedExecutionHashes 
        //       to be the next_execution_hash.
        //
        //       Use voting::get_execution_hash to get the execution hash of the proposal

        // Emit the AddApprovedExecutionHashEvent
        
    }

    /* 
        Removes a proposals hash, and returns the requested signer (to be used for in the execution script)
        @param proposal_id - the id of the proposal 
        @param signer_key - the key associated with the desired signer
        @param signer_description - the description associated with the desired signer
    */
    public fun resolve(
        proposal_id: u64, 
        signer_key: String, 
        signer_description: String
    ): signer acquires GovernanceResponsibility, ApprovedExecutionHashes, GovernanceEvents { 
        let resource_account_address = get_resource_account_address();

        // TODO: Resolve the proposal in the aptos_framework::voting module
        // 
        // HINT: Use voting;:resolve 

        // TODO: Remove the proposal's hash from the approved hashes
        // 
        // HINT: Use the remove_approved_hash function below

        // TODO: Emit the ResolveProposalEvent

        // TODO: Fetch and return the requested signer
        // 
        // HINT: Use the get_signer function below

    }

    /* 
        Updates a multi-step proposal's with the next hash and returns the requested signer
        @param proposal_id - the id of the proposal 
        @param signer_key - the key associated with the desired signer
        @param signer_description - the description associated with the desired signer
    */
    public fun resolve_multi_step_proposal(
        proposal_id: u64, 
        signer_key: String, 
        signer_description: String, 
        next_execution_hash: vector<u8>
    ): signer acquires GovernanceResponsibility, ApprovedExecutionHashes, GovernanceEvents { 

        // TODO: Resolve the proposal in the aptos_framework::voting module
        // 
        // HINT: Use voting::resolve_proposal_v2 

        // TODO: Check if the next_execution_hash is empty. If so, remove the approved hash from the
        //       hash list. If it isn't, replace the current hash with the next hash. 
        // 
        // HINT: Use the remove_approved_hash and add_approved_script_hash functions

        // TODO: Emit the ResolveProposalEvent

        // TODO: Fetch and return the requested signer
        // 
        // HINT: Use the get_signer function below

    }

    /* 
        Adds a new member to the governance structure by minting them a governance token
        @param resource_account_signer - signer representing the module's resource account (the governance token creator)
        @param uri - the URI for the new governance token
        @param soul_bound_to - the address of the new account for the governance token to be minted for
        @param voting_power - the number of votes the new governance member has per proposal
        @param can_propose - whether or not the new governance member has the ability to create proposals
    */
    public fun mint_governance_token(
        creator: &signer, 
        uri: String, 
        soul_bound_to: address,
        voting_power: u64, 
        can_propose: bool
    ) {

        // TODO: Generate the description for this new governance token
        // 
        // HINT: use the generate_governance_token_description function below

        // TODO: Generate the name for this new governance token
        // 
        // HINT: use the generate_governance_token_name function below

        // TODO: Create a new named token in the governance token collection with no royalty

        // TODO: Transfer the token to the new member address and disable ungated transfer to enable
        //       soul bound functionality

        // TODO: Create the property_map for the new token with the voting power and proposal ability

        // TODO: Create the GovernanceToken object and move it to the new token object signer
        
    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================

    /* 
        Removes a proposal's execution script hash from the approved list of hashes
        @param proposal_id - the id of the proposal 
    */
    inline fun remove_approved_hash(proposal_id: u64) acquires ApprovedExecutionHashes {
        // TODO: Remove the resolved proposal's hash from the approved hash map
        // 
        // HINT: If the hash map doesn't contain the proposal id, then abort with EHashDoesNotExist

    }

    /* 
        Internally gathers the proposal information and creates the proposal 
        @param proposer - the address of the account that is creating the proposal
        @param execution_hash - the hash of the proposal's execution script
        @param early_resolution_vote_threshold - the number of votes this proposal needs to be resolved before the expiration time
        @param metadata - a map that stores information about this proposal
        @param is_multi_step_proposal - indicating if the proposal is single-step or multi-step
    */
    fun create_proposal_internal(
        proposer: address, 
        execution_hash: vector<u8>,
        early_resolution_vote_threshold: Option<u128>,
        metadata: SimpleMap<String, vector<u8>>,
        is_multi_step_proposal: bool,
    ): u64 acquires GovernanceConfig {

        // TODO: Generate the expiration timestamp in seconds using the governance config's voting
        //       duration

        // TODO: Create the proposal in the aptos_framework::voting module
        //
        // HINT: Use voting::create_proposal_v2

    }

    /* 
        Internally records the new proposal vote 
        @param proposal_id - the id of the proposal being voted on
        @param num_votes - the number of votes to add to this proposal
        @param should_pass - whether or not the votes should go for or against the proposal
    */
    fun vote_internal(
        proposal_id: u64, 
        num_votes: u64, 
        should_pass: bool
    ) {

        // TODO: Call the vote function in the aptos_framework::voting module
        // 
        // HINT: Use voting::vote

    }

    /* 
        Retrieves the signer of the desired account from the governance responsibility object
        @param key - the key associated with the desired signer
        @param description - the description associated with the desired signer
    */
    inline fun get_signer(key: String, description: String): signer acquires GovernanceResponsibility {
        
        // TODO: Retrieve the signer cap of the desired account using the key and description

        // TODO: Generate the signer with the signer cap and return it

    }

    /* 
        Creates the new proposal id key for the governance token's property_map
        @param proposal_id - the id of the proposal id to create the key for
    */
    inline fun generate_proposal_id_key(proposal_id: u64): String {
        // TODO: Append the proposal_id to the BASE_PROPOSAL_ID_KEY String and return it
        // 
        // HINT: Use string_utils::to_string_with_integer_types

    }

    /* 
        Creates the SimpleMap holding the proposal metadata
        @param metadata_location: The location of the metadata (used in the voting module)
        @param metadata_hash: The hash of the metadata (used in the voting module)
    */
    inline fun create_proposal_metadata(
        metadata_location: vector<u8>,
        metadata_hash: vector<u8>
    ): SimpleMap<String, vector<u8>> {
        
        // TODO: Ensure the metadata_location is valid
        // 
        // HINT: Use the check_if_metadata_location_is_valid function below

        // TODO: Ensure the metadata_hash is valid
        // 
        // HINT: Use the check_if_metadata_hash_is_valid function below

        // TODO: Create a simple map with the metadata_location and metadata_hash, and return it
        //
        // HINT: Use the provided METADATA_LOCATION_KEY & METADATA_HASH_KEY keys

    }

    /* 
        Retrieves the total supply of governance tokens 
    */
    inline fun get_total_supply_of_governance_token(): Option<u64> {

        // TODO: Fetch the governance token address from the module's resource account

        // TODO: Return the count of the governance token collection

    }

    /* 
        Generates the early resolution voting threshold using the total supply of governance tokens
    */
    inline fun generate_early_resolution_vote_threshold(): Option<u128> {
        
        // TODO: Fetch the total supply of governance tokens
        //
        // HINT: Use the get_total_supply_of_governance_token function 

        // TODO: Set the early resolution vote threshold
        //
        // HINT: If the total supply is option::none(), set the early resolution vote threshold to option::none()
        // 
        //       if the total supply is option::some(), set the early resolution vote threshold to 
        //       50% of the supply + 1. The + 1 is to avoid rounding errors

        // TODO: Return the early resolution vote threshold

    }

    /* 
        Retrieves the address of this module's resource account
    */
    inline fun get_resource_account_address(): address {
        // TODO: Create the module's resource account address and return it

    }

    /* 
        Create the description for a new governance token to be minted for a new account
        @param account_address - the address of the account the token is being minted for
    */
    inline fun generate_governance_token_description(account_address: address): String {
        // TODO: Append the account_address' bytes to the BASE_TOKEN_DESCRIPTION String and return it
        // 
        // HINT: Use string_utils::to_string_with_canonical_addresses

    }

    /* 
        Create the name for a new governance token to be minted for a new account
        @param account_address - the address of the account the token is being minted for
    */
    inline fun generate_governance_token_name(account_address: address): String {
        // TODO: Return the String of the account_address' bytes
        // 
        // HINT: Use string_utils::to_string_with_canonical_addresses
        
    }

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    inline fun check_if_voter_has_not_voted_on_proposal(
        proposal_id: u64, 
        governance_token: Object<GovernanceToken>
    ) {

        // TODO: Use the generate_proposal_id_key function to generate the proposal_id_key for the 
        //       new proposal

        // TODO: Ensure the governance token's propery_map does not contain the proposal_id_key key. 
        //       Otherwise, abort with code: EVoterAlreadyVotedOnProposal

    }

    inline fun check_if_proposal_voting_is_open(proposal_id: u64) {
        // TODO: Ensure the proposal's voting is not closed. Otherwise, abort with code: EProposalVotingIsClosed
        // 
        // HINT: Use voting::is_voting_closed

    }

    inline fun check_if_metadata_location_is_valid(metadata_location: vector<u8>) {
        // TODO: Ensure the metadata_location length is below or equal to 256. Otherwise, abort with 
        //       code: EInvalidMetadataLocation
        
    }

    inline fun check_if_metadata_hash_is_valid(metadata_hash: vector<u8>) {
        // TODO: Ensure the metadata_hash length is below or equal to 256. Otherwise, abort with 
        //       code: EInvalidMetadataHash
        
    }

    inline fun check_if_account_can_create_proposal(governance_token: Object<GovernanceToken>) {
        // TODO: Ensure the governance token's proposal ability property is true. Otherwise, abort
        //       with code: EAccountDoesNotHaveProposalAbility

    }

    inline fun check_if_proposal_can_be_resolved(proposal_id: u64) {
        // TODO: Ensure the proposal's state is equal to PROPOSAL_STATE_SUCCEEDED. Otherwise, abort 
        //       with code: EProposalCannotBeResolved
        // 
        // HINT: Use voting::get_proposal_state 

    }

    inline fun check_if_address_is_an_object(object_address: address) {
        // TODO: Ensure the object address is associated with an existing object. Otherwise, abort
        //       with code: EAddressIsNotAnObject

    }

    inline fun check_if_account_is_resource_account_address(account_address: address) {
        // TODO: Ensure the given address is the module's resource account's address. Otherwise, 
        //       abort with code: EAccountIsNotResourceAccount

    }

    inline fun check_if_proposal_id_is_valid(proposal_id: u64) {
        // TODO: Ensure that proposal_id is less than the next proposal id in the voting module. If 
        //       not, abort with code: EInvalidProposalId
        //
        // HINT: Use voting::next_proposal_id
        
    }


    //==============================================================================================
    // Tests - DO NOT MODIFY
    //==============================================================================================


    #[test(admin = @overmind, account = @0xA)]
    fun test_init_module_success(
        admin: &signer
    ) acquires GovernanceResponsibility, GovernanceConfig, ApprovedExecutionHashes {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        init_module(admin);

        let expected_resource_account_address = account::create_resource_address(&@overmind, SEED);

        let next_proposal_id = voting::next_proposal_id<GovernanceProposalType>(expected_resource_account_address);
        assert!(next_proposal_id == 0, 0);

        assert!(exists<GovernanceConfig>(expected_resource_account_address) == true, 0);
        assert!(exists<GovernanceResponsibility>(expected_resource_account_address) == true, 0);
        assert!(exists<ApprovedExecutionHashes>(expected_resource_account_address) == true, 0);
        assert!(exists<GovernanceEvents>(expected_resource_account_address) == true, 0);

        let approved_execution_hashes = borrow_global<ApprovedExecutionHashes>(expected_resource_account_address);
        let (hash_keys, _)= simple_map::to_vec_pair<u64, vector<u8>>(approved_execution_hashes.hashes);
        let number_of_approved_hashes = vector::length<u64>(&hash_keys);
        assert!(number_of_approved_hashes == 0, 0);

        let governance_config = borrow_global<GovernanceConfig>(expected_resource_account_address);
        assert!(governance_config.minimum_voting_threshold == STARTING_MINIMUM_VOTING_THRESHOLD, 0);
        assert!(governance_config.voting_duration_seconds == STARTING_VOTING_DURATION_SECONDS, 0);

        let governance_responsibility = borrow_global<GovernanceResponsibility>(expected_resource_account_address);
        let resource_account_responsibility = GovernanceResponsibilityKey {
            key: string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY),
            description: string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION)
        };
        assert!(
            simple_map::contains_key<GovernanceResponsibilityKey, SignerCapability>(
                &governance_responsibility.signer_caps, 
                &resource_account_responsibility
            ) == true, 
            0
        );
        let resource_account_signer_cap = simple_map::borrow<GovernanceResponsibilityKey, SignerCapability>(
            &governance_responsibility.signer_caps, 
            &resource_account_responsibility
        );
        let actual_resource_account_address = account::get_signer_capability_address(resource_account_signer_cap);
        assert!(actual_resource_account_address == expected_resource_account_address, 0);

        let expected_governance_token_collection_address = collection::create_collection_address(
            &expected_resource_account_address,
            &string::utf8(GOVERNANCE_TOKEN_COLLECTION_NAME)
        );
        assert!(object::is_object(expected_governance_token_collection_address) == true, 0);
        let governance_token_collection = object::address_to_object<Collection>(expected_governance_token_collection_address);
        assert!(object::owner<Collection>(governance_token_collection) == expected_resource_account_address, 0);
        assert!(
            collection::creator<Collection>(governance_token_collection) == expected_resource_account_address, 
            0
        );
        assert!(
            option::is_some<u64>(&collection::count<Collection>(governance_token_collection)) == true, 
            0
        );
        assert!(
            option::contains<u64>(&collection::count<Collection>(governance_token_collection), &1) == true, 
            0
        );
        assert!(
            collection::description<Collection>(governance_token_collection) == string::utf8(STARTING_GOVERNANCE_TOKEN_DESCRIPTION), 
            0
        );
        assert!(
            collection::name<Collection>(governance_token_collection) == string::utf8(GOVERNANCE_TOKEN_COLLECTION_NAME), 
            0
        );
        assert!(
            collection::uri<Collection>(governance_token_collection) == string::utf8(STARTING_GOVERNANCE_TOKEN_URI), 
            0
        );

        let expected_admin_token_address = token::create_token_address(
            &expected_resource_account_address, 
            &string::utf8(GOVERNANCE_TOKEN_COLLECTION_NAME),
            &string::utf8(b"@0000000000000000000000000000000000000000000000000000000000001337")
        );
        assert!(
            object::is_object(expected_admin_token_address) == true, 
            0
        );
        let admin_token = object::address_to_object<GovernanceToken>(expected_admin_token_address);
        assert!(
            object::owner<GovernanceToken>(admin_token) == signer::address_of(admin), 
            0
        );
        assert!(
            token::creator<GovernanceToken>(admin_token) == expected_resource_account_address, 
            0
        );
        assert!(
            token::collection_name<GovernanceToken>(admin_token) == string::utf8(GOVERNANCE_TOKEN_COLLECTION_NAME), 
            0
        );
        let description = string::utf8(b"Governance token for account: @0000000000000000000000000000000000000000000000000000000000001337");
        assert!(
            token::description<GovernanceToken>(admin_token) == description, 
            0
        );
        assert!(
            token::name<GovernanceToken>(admin_token) == string::utf8(b"@0000000000000000000000000000000000000000000000000000000000001337"), 
            0
        );
        assert!(
            token::uri<GovernanceToken>(admin_token) == string::utf8(b""), 
            0
        );
        assert!(
            option::is_none(&token::royalty<GovernanceToken>(admin_token)) == true, 
            0
        );
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_create_proposal_success_admin_creates_proposal(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        

        let resource_account_address = account::create_resource_address(&@overmind, SEED);


        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        let governance_config = borrow_global<GovernanceConfig>(resource_account_address);

        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 0, 0);
        let proposal_expiration_seconds = voting::get_proposal_expiration_secs<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_expiration_seconds == timestamp::now_seconds() + governance_config.voting_duration_seconds,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_minimum_vote_threshold = voting::get_min_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_minimum_vote_threshold == governance_config.minimum_voting_threshold,
            0
        );
        let proposal_early_resolution_vote_threshold = voting::get_early_resolution_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            option::contains<u128>(&proposal_early_resolution_vote_threshold, &1),
            0
        );
        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );
        let proposal_is_resolved = voting::is_resolved<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_resolved == false,
            0
        );
        let proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == false,
            0
        );

        timestamp::update_global_time_for_test_secs(STARTING_VOTING_DURATION_SECONDS + 600);

        proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == true,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, user = @0xA)]
    fun test_create_proposal_success_minimum_threshold_changed(
        admin: &signer,
        user: &signer
    ) acquires GovernanceConfig, GovernanceEvents, GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        add_new_member_for_test(
            user_address, 
            1, 
            true
        );

        update_governance_config_for_test(
            2, 
            STARTING_VOTING_DURATION_SECONDS
        );

        let resource_account_address = account::create_resource_address(&@overmind, SEED);


        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 0, 0);
        let proposal_expiration_seconds = voting::get_proposal_expiration_secs<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_expiration_seconds == timestamp::now_seconds() + STARTING_VOTING_DURATION_SECONDS,
            0
        );
        let proposal_minimum_vote_threshold = voting::get_min_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_minimum_vote_threshold == 2,
            0
        );
        let proposal_early_resolution_vote_threshold = voting::get_early_resolution_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            option::contains<u128>(&proposal_early_resolution_vote_threshold, &2),
            0
        );
        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );
        let proposal_is_resolved = voting::is_resolved<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_resolved == false,
            0
        );
        let proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == false,
            0
        );

        timestamp::update_global_time_for_test_secs(STARTING_VOTING_DURATION_SECONDS + 600);

        proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == true,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 1, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind)]
    fun test_create_proposal_success_voting_duration_changed(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceEvents, GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        update_governance_config_for_test(
            1, 
            STARTING_VOTING_DURATION_SECONDS * 2
        );

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 0, 0);
        let proposal_expiration_seconds = voting::get_proposal_expiration_secs<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_expiration_seconds == timestamp::now_seconds() + STARTING_VOTING_DURATION_SECONDS * 2,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_minimum_vote_threshold = voting::get_min_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_minimum_vote_threshold == STARTING_MINIMUM_VOTING_THRESHOLD,
            0
        );
        let proposal_early_resolution_vote_threshold = voting::get_early_resolution_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            option::contains<u128>(&proposal_early_resolution_vote_threshold, &1),
            0
        );
        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );
        let proposal_is_resolved = voting::is_resolved<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_resolved == false,
            0
        );
        let proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == false,
            0
        );

        timestamp::update_global_time_for_test_secs(STARTING_VOTING_DURATION_SECONDS + 600);

        proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == false,
            0
        );

        timestamp::update_global_time_for_test_secs(2 * STARTING_VOTING_DURATION_SECONDS + 600);

        proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == true,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 1, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EAccountDoesNotHaveProposalAbility)]
    fun test_create_proposal_failure_no_proposal_abilty_for_user(
        admin: &signer, 
        user: &signer
    ) acquires GovernanceConfig, GovernanceEvents, GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        add_new_member_for_test(
            user_address, 
            1, 
            false
        );

        update_governance_config_for_test(
            2, 
            STARTING_VOTING_DURATION_SECONDS
        );

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EAddressIsNotAnObject)]
    fun test_create_proposal_failure_not_governance_member(
        admin: &signer, 
        user: &signer
    ) acquires GovernanceConfig, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EInvalidMetadataLocation)]
    fun test_create_proposal_failure_too_long_metadata_location(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
        ];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EInvalidMetadataHash)]
    fun test_create_proposal_failure_too_long_metadata_hash(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
            23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
        ];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );
    }

    #[test(admin = @overmind, user = @0xA)]
    fun test_create_proposal_success_other_user_creates_proposal(
        admin: &signer, 
        user: &signer
    ) acquires GovernanceConfig, GovernanceEvents, GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        add_new_member_for_test(
            user_address, 
            1, 
            true
        );

        update_governance_config_for_test(
            2, 
            STARTING_VOTING_DURATION_SECONDS
        );

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        let governance_config = borrow_global<GovernanceConfig>(resource_account_address);

        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 0, 0);
        let proposal_expiration_seconds = voting::get_proposal_expiration_secs<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_expiration_seconds == timestamp::now_seconds() + governance_config.voting_duration_seconds,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_minimum_vote_threshold = voting::get_min_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_minimum_vote_threshold == governance_config.minimum_voting_threshold,
            0
        );
        let proposal_early_resolution_vote_threshold = voting::get_early_resolution_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            option::contains<u128>(&proposal_early_resolution_vote_threshold, &2),
            0
        );
        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );
        let proposal_is_resolved = voting::is_resolved<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_resolved == false,
            0
        );
        let proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == false,
            0
        );

        timestamp::update_global_time_for_test_secs(STARTING_VOTING_DURATION_SECONDS + 600);

        proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == true,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 1, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, user = @0xA)]
    fun test_create_proposal_success_multiple_proposals_by_same_user(
        admin: &signer, 
        user: &signer
    ) acquires GovernanceConfig, GovernanceEvents, GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        add_new_member_for_test(
            user_address, 
            1, 
            true
        );

        update_governance_config_for_test(
            2, 
            STARTING_VOTING_DURATION_SECONDS
        );

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        let governance_config = borrow_global<GovernanceConfig>(resource_account_address);

        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 0, 0);
        let proposal_expiration_seconds = voting::get_proposal_expiration_secs<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_expiration_seconds == timestamp::now_seconds() + governance_config.voting_duration_seconds,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_minimum_vote_threshold = voting::get_min_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_minimum_vote_threshold == governance_config.minimum_voting_threshold,
            0
        );
        let proposal_early_resolution_vote_threshold = voting::get_early_resolution_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            option::contains<u128>(&proposal_early_resolution_vote_threshold, &2),
            0
        );
        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );
        let proposal_is_resolved = voting::is_resolved<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_resolved == false,
            0
        );
        let proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == false,
            0
        );

        timestamp::update_global_time_for_test_secs(STARTING_VOTING_DURATION_SECONDS + 600);

        proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == true,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 3, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 1, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, user = @0xA)]
    fun test_create_proposal_success_multiple_proposals_by_different_users(
        admin: &signer, 
        user: &signer
    ) acquires GovernanceConfig, GovernanceEvents, GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        add_new_member_for_test(
            user_address, 
            1, 
            true
        );

        update_governance_config_for_test(
            2, 
            STARTING_VOTING_DURATION_SECONDS
        );

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        create_proposal(
            user,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        let governance_config = borrow_global<GovernanceConfig>(resource_account_address);

        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 0, 0);
        let proposal_expiration_seconds = voting::get_proposal_expiration_secs<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_expiration_seconds == timestamp::now_seconds() + governance_config.voting_duration_seconds,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_execution_hash = voting::get_execution_hash<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_execution_hash == expected_execution_hash,
            0
        );
        let proposal_minimum_vote_threshold = voting::get_min_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_minimum_vote_threshold == governance_config.minimum_voting_threshold,
            0
        );
        let proposal_early_resolution_vote_threshold = voting::get_early_resolution_vote_threshold<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            option::contains<u128>(&proposal_early_resolution_vote_threshold, &2),
            0
        );
        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );
        let proposal_is_resolved = voting::is_resolved<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_resolved == false,
            0
        );
        let proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == false,
            0
        );

        timestamp::update_global_time_for_test_secs(STARTING_VOTING_DURATION_SECONDS + 600);

        proposal_is_voting_closed = voting::is_voting_closed<GovernanceProposalType>(
            resource_account_address, 
            0
        );
        assert!(
            proposal_is_voting_closed == true,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 3, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 1, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_vote_success_vote_by_admin_voted_should_pass(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceToken, GovernanceEvents  {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            proposal_id
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );

        vote(
            admin, 
            proposal_id, 
            true
        );

        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            proposal_id
        );
        assert!(
            proposal_votes_yes == 1,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );
        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 1, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 1, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_vote_success_vote_by_admin_voted_should_not_pass(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceToken, GovernanceEvents  {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            proposal_id
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 0,
            0
        );

        vote(
            admin, 
            proposal_id, 
            false
        );

        let (proposal_votes_yes, proposal_votes_no) = voting::get_votes<GovernanceProposalType>(
            resource_account_address, 
            proposal_id
        );
        assert!(
            proposal_votes_yes == 0,
            0
        );
        assert!(
            proposal_votes_no == 1,
            0
        );
        let proposal_state = voting::get_proposal_state<GovernanceProposalType>(
            resource_account_address, 
            0
        ); 
        assert!(proposal_state == 3, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 1, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EAddressIsNotAnObject)]
    fun test_vote_failure_not_governance_member(
        admin: &signer,
        user: &signer
    ) acquires GovernanceConfig, GovernanceToken, GovernanceEvents  {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            user, 
            proposal_id, 
            true
        );
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EVoterAlreadyVotedOnProposal)]
    fun test_vote_failure_already_voted(
        admin: &signer,
        user: &signer
    ) acquires GovernanceConfig, GovernanceToken, GovernanceEvents, GovernanceResponsibility  {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        add_new_member_for_test(
            user_address, 
            1, 
            true
        );

        update_governance_config_for_test(
            2, 
            STARTING_VOTING_DURATION_SECONDS
        );

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            user, 
            proposal_id, 
            true
        );

        vote(
            user, 
            proposal_id, 
            true
        );
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EProposalVotingIsClosed)]
    fun test_vote_failure_voting_closed(
        admin: &signer,
        user: &signer
    ) acquires GovernanceConfig, GovernanceToken, GovernanceEvents, GovernanceResponsibility  {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user_address = signer::address_of(user);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        add_new_member_for_test(
            user_address, 
            1, 
            true
        );

        update_governance_config_for_test(
            2, 
            STARTING_VOTING_DURATION_SECONDS
        );

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            user, 
            proposal_id, 
            true
        );

        timestamp::update_global_time_for_test_secs(STARTING_VOTING_DURATION_SECONDS + 600);

        vote(
            admin, 
            proposal_id, 
            true
        );
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_add_approved_script_hash_success_added(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceToken, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);
        // let expected_admin_token_address = token::create_token_address(
        //     &resource_account_address, 
        //     &string::utf8(GOVERNANCE_TOKEN_COLLECTION_NAME),
        //     &string::utf8(bcs::to_bytes<address>(&signer::address_of(admin)))
        // );

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            admin, 
            proposal_id, 
            true
        );

        add_approved_script_hash(proposal_id);

        let approved_hashes = borrow_global<ApprovedExecutionHashes>(resource_account_address);
        let hashes = &approved_hashes.hashes;
        assert!(
            simple_map::contains_key(hashes, &proposal_id) == true,
            0
        );
        let proposal_hash = simple_map::borrow(hashes, &proposal_id);
        assert!(
            *proposal_hash == expected_execution_hash,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 1, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 1, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_add_approved_script_hash_success_added_twice(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceToken, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);
        // let expected_admin_token_address = token::create_token_address(
        //     &resource_account_address, 
        //     &string::utf8(GOVERNANCE_TOKEN_COLLECTION_NAME),
        //     &string::utf8(bcs::to_bytes<address>(&signer::address_of(admin)))
        // );

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            admin, 
            proposal_id, 
            true
        );

        add_approved_script_hash(proposal_id);

        add_approved_script_hash(proposal_id);

        let approved_hashes = borrow_global<ApprovedExecutionHashes>(resource_account_address);
        let hashes = &approved_hashes.hashes;
        assert!(
            simple_map::contains_key(hashes, &proposal_id) == true,
            0
        );
        let proposal_hash = simple_map::borrow(hashes, &proposal_id);
        assert!(
            *proposal_hash == expected_execution_hash,
            0
        );

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 1, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 2, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EProposalCannotBeResolved)]
    fun test_add_approved_script_hash_failure_cannot_be_resolved(
        admin: &signer
    ) acquires GovernanceConfig, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        add_approved_script_hash(proposal_id);
    }

    #[test(admin = @overmind, user = @0xA)]
    #[expected_failure(abort_code = EInvalidProposalId)]
    fun test_add_approved_script_hash_failure_invalid_proposal_id(
        admin: &signer
    ) acquires GovernanceConfig, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        add_approved_script_hash(100);
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_resolve_success_resolved(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceResponsibility, GovernanceToken, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            admin, 
            proposal_id, 
            true
        );

        timestamp::update_global_time_for_test_secs(1200);

        add_approved_script_hash(proposal_id);

        let resolve_signer = resolve(
            proposal_id, 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY), 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION)
        );

        let approved_hashes = borrow_global<ApprovedExecutionHashes>(resource_account_address);
        let hashes = &approved_hashes.hashes;
        assert!(
            simple_map::contains_key(hashes, &proposal_id) == false,
            0
        );

        let resolve_signer_address = signer::address_of(&resolve_signer);
        assert!(resolve_signer_address == resource_account_address, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 1, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 1, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 1, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_resolve_multi_step_proposal_success_next_hash(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceResponsibility, GovernanceToken, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            true
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            admin, 
            proposal_id, 
            true
        );

        timestamp::update_global_time_for_test_secs(1200);

        add_approved_script_hash(proposal_id);

        let resolve_signer = resolve_multi_step_proposal(
            proposal_id, 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY), 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION), 
            expected_execution_hash
        );

        let approved_hashes = borrow_global<ApprovedExecutionHashes>(resource_account_address);
        let hashes = &approved_hashes.hashes;
        assert!(
            simple_map::contains_key(hashes, &proposal_id) == true,
            0
        );

        let resolve_signer_address = signer::address_of(&resolve_signer);
        assert!(resolve_signer_address == resource_account_address, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 1, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 2, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 1, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_resolve_multi_step_proposal_success_no_next_hash(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceResponsibility, GovernanceToken, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            true
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            admin, 
            proposal_id, 
            true
        );

        timestamp::update_global_time_for_test_secs(1200);

        add_approved_script_hash(proposal_id);

        let resolve_signer = resolve_multi_step_proposal(
            proposal_id, 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY), 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION), 
            vector<u8>[]
        );

        let approved_hashes = borrow_global<ApprovedExecutionHashes>(resource_account_address);
        let hashes = &approved_hashes.hashes;
        assert!(
            simple_map::contains_key(hashes, &proposal_id) == false,
            0
        );

        let resolve_signer_address = signer::address_of(&resolve_signer);
        assert!(resolve_signer_address == resource_account_address, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 1, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 1, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 1, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 1, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    #[expected_failure(abort_code = EHashDoesNotExist)]
    fun test_resolve_failure_has_not_been_added_to_approved_hashes(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceResponsibility, GovernanceToken, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = transaction_context::get_script_hash();
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            admin, 
            proposal_id, 
            true
        );

        timestamp::update_global_time_for_test_secs(1200);

        let _resolve_signer = resolve(
            proposal_id, 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY), 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION)
        );
    }

    #[test(admin = @overmind, account = @0xA)]
    #[expected_failure] // todo: add code
    fun test_resolve_failure_non_matching_hash(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceResponsibility, GovernanceToken, ApprovedExecutionHashes, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let proposal_id = voting::next_proposal_id<GovernanceProposalType>(resource_account_address);

        let expected_execution_hash = vector<u8>[23];
        let metadata_location = vector<u8>[23];
        let meatadata_hash = vector<u8>[23];
        create_proposal(
            admin,
            expected_execution_hash,
            metadata_location,
            meatadata_hash,
            false
        );

        timestamp::update_global_time_for_test_secs(600);

        vote(
            admin, 
            proposal_id, 
            true
        );

        timestamp::update_global_time_for_test_secs(1200);

        add_approved_script_hash(proposal_id);

        let _resolve_signer = resolve(
            proposal_id, 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY), 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION)
        );
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_update_governance_responsibility_success_replace_existing_signer_cap(
        admin: &signer
    ) acquires GovernanceResponsibility, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        init_module(admin);

        let (new_resource_signer, new_signer_cap) = account::create_resource_account(admin, b"new");
        let expected_new_resource_address = signer::address_of(&new_resource_signer);

        let resource_account_address = get_resource_account_address();

        let resource_account_signer = get_signer(
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY),
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION),
        );

        update_governance_responsibility(
            &resource_account_signer,
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY),
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION),
            new_signer_cap
        );

        let governance_responsibility = borrow_global<GovernanceResponsibility>(resource_account_address);
        let new_signer_cap = simple_map::borrow<GovernanceResponsibilityKey, SignerCapability>(
            &governance_responsibility.signer_caps, 
            & GovernanceResponsibilityKey {
                key: string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY),
                description: string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION)
            }
        );  
        let actual_new_resource_account_address = account::get_signer_capability_address(new_signer_cap);
        assert!(expected_new_resource_address == actual_new_resource_account_address, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 0, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 1, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_update_governance_responsibility_success_add_new_signer_cap(
        admin: &signer
    ) acquires GovernanceResponsibility, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        init_module(admin);

        let (new_resource_signer, new_signer_cap) = account::create_resource_account(admin, b"new");
        let expected_new_resource_address = signer::address_of(&new_resource_signer);

        let resource_account_address = get_resource_account_address();

        let resource_account_signer = get_signer(
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY),
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION),
        );

        update_governance_responsibility(
            &resource_account_signer,
            string::utf8(b"new key"),
            string::utf8(b"new description"),
            new_signer_cap
        );

        let governance_responsibility = borrow_global<GovernanceResponsibility>(resource_account_address);
        let new_signer_cap = simple_map::borrow<GovernanceResponsibilityKey, SignerCapability>(
            &governance_responsibility.signer_caps, 
            & GovernanceResponsibilityKey {
                key: string::utf8(b"new key"),
                description: string::utf8(b"new description"),
            }
        );  
        let actual_new_resource_account_address = account::get_signer_capability_address(new_signer_cap);
        assert!(expected_new_resource_address == actual_new_resource_account_address, 0);
        
        let resource_signer_cap = simple_map::borrow<GovernanceResponsibilityKey, SignerCapability>(
            &governance_responsibility.signer_caps, 
            & GovernanceResponsibilityKey {
                key: string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY),
                description: string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION),
            }
        );  
        let actual_resource_account_address = account::get_signer_capability_address(resource_signer_cap);
        assert!(resource_account_address == actual_resource_account_address, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 0, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 0, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 1, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    #[expected_failure(abort_code = EAccountIsNotResourceAccount)]
    fun test_update_governance_responsibility_failure_not_resource_account(
        admin: &signer
    ) acquires GovernanceResponsibility, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        init_module(admin);

        let (_, new_signer_cap) = account::create_resource_account(admin, b"new");

        update_governance_responsibility(
            admin,
            string::utf8(b"new key"),
            string::utf8(b"new description"),
            new_signer_cap
        );
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_update_governance_config_success_new_values(
        admin: &signer
    ) acquires GovernanceResponsibility, GovernanceConfig, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        init_module(admin);

        let resource_account_address = account::create_resource_address(&@overmind, SEED);

        let resource_account_signer = get_signer(
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY),
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION),
        );

        update_governance_config(
            &resource_account_signer, 
            89, 
            7
        );

        let governance_config = borrow_global<GovernanceConfig>(resource_account_address);
        assert!(governance_config.minimum_voting_threshold == 89, 0);
        assert!(governance_config.voting_duration_seconds == 7, 0);

        let create_proposal_events_count = get_create_proposal_events_count();
        assert!(create_proposal_events_count == 0, 0);
        let vote_events_count = get_vote_events_count();
        assert!(vote_events_count == 0, 0);
        let updated_governance_config_events_count = get_updated_governance_config_events_count();
        assert!(updated_governance_config_events_count == 1, 0);
        let update_governance_responsibility_events_count = get_update_governance_responsibility_events_count();
        assert!(update_governance_responsibility_events_count == 0, 0);
        let add_approved_execution_hash_events_count = get_add_approved_execution_hash_events_count();
        assert!(add_approved_execution_hash_events_count == 0, 0);
        let resolve_proposal_events_count = get_resolve_proposal_events_count();
        assert!(resolve_proposal_events_count == 0, 0);
    }

    #[test(admin = @overmind, account = @0xA)]
    #[expected_failure(abort_code = EAccountIsNotResourceAccount)]
    fun test_update_governance_config_failure_not_resource_account(
        admin: &signer
    ) acquires GovernanceConfig, GovernanceEvents {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        init_module(admin);

        update_governance_config(
            admin, 
            89, 
            7
        );
    }

    #[test(admin = @overmind, account = @0xA)]
    fun test_create_proposal_metadata_success() {
        let metadata_location = vector<u8>[28, 19];
        let metadata_hash = vector<u8>[84, 1];

        let metadata_map = create_proposal_metadata(metadata_location, metadata_hash);

        assert!(
            simple_map::contains_key<String, vector<u8>>(
                &metadata_map, 
                &string::utf8(METADATA_LOCATION_KEY)
            ) == true,
            0
        );
        assert!(
            simple_map::contains_key<String, vector<u8>>(
                &metadata_map, 
                &string::utf8(METADATA_HASH_KEY)
            ) == true,
            0
        );
        assert!(
            *simple_map::borrow<String, vector<u8>>(
                &metadata_map, 
                &string::utf8(METADATA_LOCATION_KEY)
            ) == metadata_location,
            0
        );
        assert!(
            *simple_map::borrow<String, vector<u8>>(
                &metadata_map, 
                &string::utf8(METADATA_HASH_KEY)
            ) == metadata_hash,
            0
        );
    }

    #[test(admin = @overmind, user1 = @0xA, user2 = @0xB)]
    fun test_get_total_supply_of_governance_token_success_1(
        admin: &signer,
        user1: &signer,
        user2: &signer
    ) acquires GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user1_address = signer::address_of(user1);
        account::create_account_for_test(user1_address);

        let user2_address = signer::address_of(user2);
        account::create_account_for_test(user2_address);

        init_module(admin);

        add_new_member_for_test(
            user1_address, 
            1, 
            false
        );

        add_new_member_for_test(
            user2_address, 
            1, 
            false
        );

        let token_supply = get_total_supply_of_governance_token();
        assert!(option::is_some<u64>(&token_supply) == true, 0);
        assert!(option::borrow<u64>(&token_supply) == &3, 0)
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun test_get_total_supply_of_governance_token_success_2(
        admin: &signer,
        user1: &signer
    ) acquires GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user1_address = signer::address_of(user1);
        account::create_account_for_test(user1_address);

        init_module(admin);

        add_new_member_for_test(
            user1_address, 
            1, 
            false
        );

        let token_supply = get_total_supply_of_governance_token();
        assert!(option::is_some<u64>(&token_supply) == true, 0);
        assert!(option::borrow<u64>(&token_supply) == &2, 0)
    }

    #[test(admin = @overmind, user1 = @0xA, user2 = @0xB)]
    fun test_generate_early_resolution_vote_threshold_success_1(
        admin: &signer,
        user1: &signer,
        user2: &signer
    ) acquires GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user1_address = signer::address_of(user1);
        account::create_account_for_test(user1_address);

        let user2_address = signer::address_of(user2);
        account::create_account_for_test(user2_address);

        init_module(admin);

        add_new_member_for_test(
            user1_address, 
            1, 
            false
        );

        add_new_member_for_test(
            user2_address, 
            1, 
            false
        );

        let voting_threshold = generate_early_resolution_vote_threshold();
        assert!(option::is_some<u128>(&voting_threshold) == true, 0);
        assert!(option::borrow<u128>(&voting_threshold) == &2, 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    fun test_generate_early_resolution_vote_threshold_success_2(
        admin: &signer,
        user1: &signer
    ) acquires GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user1_address = signer::address_of(user1);
        account::create_account_for_test(user1_address);

        init_module(admin);

        add_new_member_for_test(
            user1_address, 
            1, 
            false
        );

        let voting_threshold = generate_early_resolution_vote_threshold();
        assert!(option::is_some<u128>(&voting_threshold) == true, 0);
        assert!(option::borrow<u128>(&voting_threshold) == &2, 0);
    }

    #[test(admin = @overmind, user1 = @0xA)]
    #[expected_failure]
    fun test_mint_governance_token_failure_governance_token_already_exists(
        admin: &signer,
        user1: &signer
    ) acquires GovernanceResponsibility {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let user1_address = signer::address_of(user1);
        account::create_account_for_test(user1_address);

        init_module(admin);

        add_new_member_for_test(
            user1_address, 
            1, 
            false
        );
        add_new_member_for_test(
            user1_address, 
            1, 
            false
        );

        let token_supply = get_total_supply_of_governance_token();
        assert!(option::is_some<u64>(&token_supply) == true, 0);
        assert!(option::borrow<u64>(&token_supply) == &2, 0)
    }

    #[test(admin = @overmind)]
    fun test_get_resource_account_address_success(
        admin: &signer
    ) {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        init_module(admin);

        let actual_resource_account_address = get_resource_account_address();
        let expected_resource_account_address = account::create_resource_address(&@overmind, SEED);

        assert!(actual_resource_account_address == expected_resource_account_address, 0);
    }

    #[test(admin = @overmind)]
    fun test_generate_governance_token_description_success(
        admin: &signer
    ) {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let actual_token_description = generate_governance_token_description(admin_address);
        let expected_token_description = string::utf8(b"Governance token for account: @0000000000000000000000000000000000000000000000000000000000001337");

        assert!(actual_token_description == expected_token_description, 0);
    }

    #[test(admin = @overmind)]
    fun test_generate_governance_token_name_success(
        admin: &signer
    ) {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let actual_token_name = generate_governance_token_name(admin_address);
        let expected_token_name = string::utf8(b"@0000000000000000000000000000000000000000000000000000000000001337");

        assert!(actual_token_name == expected_token_name, 0);
    }

    #[test(admin = @overmind)]
    fun test_generate_proposal_id_key_success_1() {

        let actual_proposal_id_key = generate_proposal_id_key(1);
        let expected_proposal_id_key = string::utf8(b"vote_for_proposal_id_#1");

        assert!(actual_proposal_id_key == expected_proposal_id_key, 0);
    }

    #[test_only]
    inline fun get_create_proposal_events_count(): u64 acquires GovernanceEvents {
        let governance_events = borrow_global<GovernanceEvents>(get_resource_account_address());
        event::counter<CreateProposalEvent>(&governance_events.create_proposal_events)
    }

    #[test_only]
    inline fun get_vote_events_count(): u64 acquires GovernanceEvents {
        let governance_events = borrow_global<GovernanceEvents>(get_resource_account_address());
        event::counter<VoteEvent>(&governance_events.vote_events)
    }

    #[test_only]
    inline fun get_updated_governance_config_events_count(): u64 acquires GovernanceEvents {
        let governance_events = borrow_global<GovernanceEvents>(get_resource_account_address());
        event::counter<UpdateGovernanceConfigEvent>(&governance_events.updated_governance_config_events)
    }

    #[test_only]
    inline fun get_update_governance_responsibility_events_count(): u64 acquires GovernanceEvents {
        let governance_events = borrow_global<GovernanceEvents>(get_resource_account_address());
        event::counter<UpdateGovernanceResponsibilityEvent>(&governance_events.update_governance_responsibility_events)
    }

    #[test_only]
    inline fun get_add_approved_execution_hash_events_count(): u64 acquires GovernanceEvents {
        let governance_events = borrow_global<GovernanceEvents>(get_resource_account_address());
        event::counter<AddApprovedExecutionHashEvent>(&governance_events.add_approved_execution_hash_events)
    }

    #[test_only]
    inline fun get_resolve_proposal_events_count(): u64 acquires GovernanceEvents {
        let governance_events = borrow_global<GovernanceEvents>(get_resource_account_address());
        event::counter<ResolveProposalEvent>(&governance_events.resolve_proposal_events)
    }

    #[test_only]
    inline fun add_new_member_for_test(
        soul_bound_to: address, 
        voting_power: u64, 
        can_propose: bool
    ) acquires GovernanceResponsibility {
        let resource_account_signer = get_signer(
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY), 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION)
        );

        let uri = string::utf8(b"");

        mint_governance_token(
            &resource_account_signer, 
            uri, 
            soul_bound_to, 
            voting_power, 
            can_propose
        );
    
    }

    #[test_only]
    inline fun update_governance_config_for_test(
        minimum_voting_threshold: u128, 
        voting_duration_seconds: u64
    ) acquires GovernanceConfig, GovernanceEvents, GovernanceResponsibility {
        let resource_account_signer = get_signer(
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_KEY), 
            string::utf8(RESOURCE_ACCOUNT_SIGNER_CAP_DESCRIPTION)
        );

        update_governance_config(
            &resource_account_signer, 
            minimum_voting_threshold, 
            voting_duration_seconds
        );
    }

}