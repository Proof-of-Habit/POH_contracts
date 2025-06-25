use proof_of_habit::base::types::{Entry, Habit};
use starknet::ContractAddress;
#[starknet::interface]
pub trait IProofOfHabit<TContractState> {
    /// Sets a unique username for the caller's wallet address.
    /// # Arguments
    /// * `name` - The desired username.
    fn set_user_name(ref self: TContractState, name: felt252);

    /// Creates a new habit for the caller.
    /// # Arguments
    /// * `title` - The title of the habit.
    /// * `description` - The description of the habit.
    /// # Returns
    /// The unique ID assigned to the created habit.
    fn create_habit(ref self: TContractState, title: ByteArray, description: ByteArray) -> u32;

    /// Logs an entry for a specific habit.
    /// Can only be called by the habit owner once every 24 hours.
    /// Updates streak and log counts based on timing.
    /// # Arguments
    /// * `habit_id` - The ID of the habit to log for.
    /// * `message` - The message for the log entry.
    /// * `picture_uri` - The URI for the associated picture (e.g., IPFS link).
    fn log_entry(
        ref self: TContractState, habit_id: u32, message: ByteArray, picture_uri: ByteArray,
    );

    fn get_user_habits(self: @TContractState, user: ContractAddress) -> Array<Habit>;

    /// Retrieves the list of habit IDs owned by a user.
    /// # Arguments
    /// * `user` - The address of the user.
    /// # Returns
    /// An array of habit IDs.
    fn get_user_habits_ids(self: @TContractState, user: ContractAddress) -> Array<u32>;

    /// Retrieves a paginated list of log entries for a habit.
    /// # Arguments
    /// * `habit_id` - The ID of the habit.
    /// * `start` - The starting index for pagination.
    /// * `count` - The maximum number of entries to retrieve.
    /// # Returns
    /// An array of log entries.
    fn get_habit_logs(
        self: @TContractState, habit_id: u32, start: u32, count: u32,
    ) -> Array<Entry>;

    /// Retrieves the current streak count for a habit.
    /// # Arguments
    /// * `habit_id` - The ID of the habit.
    /// # Returns
    /// The current streak count.
    fn get_streak(self: @TContractState, habit_id: u32) -> u32;
    fn get_user_longest_streak(self: @TContractState, user: ContractAddress) -> u32;

    /// Retrieves the username associated with a wallet address.
    /// # Arguments
    /// * `wallet` - The wallet address.
    /// # Returns
    /// The username felt252, or 0 if not set.
    fn get_user_name(self: @TContractState, wallet: ContractAddress) -> felt252;

    /// Retrieves the wallet address associated with a username.
    /// # Arguments
    /// * `user_name` - The username.
    /// # Returns
    /// The wallet address, or zero address if not found.
    fn get_wallet_from_user_name(self: @TContractState, user_name: felt252) -> ContractAddress;

    /// Retrieves the total number of habits created.
    /// # Returns
    /// The total habit count.
    fn get_total_habit_count(self: @TContractState) -> u32;

    /// Retrieves the total number of logs for a specific habit.
    /// # Arguments
    /// * `habit_id` - The ID of the habit.
    /// # Returns
    /// The total log count for the habit.
    fn get_habit_log_count(self: @TContractState, habit_id: u32) -> u32;

    fn get_total_logs_user(self: @TContractState, user: ContractAddress) -> u32;
    fn get_total_user_habits(self: @TContractState, user: ContractAddress) -> u32;
}
