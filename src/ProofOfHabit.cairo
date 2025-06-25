#[starknet::contract]
pub mod ProofOfHabit {
    use core::array::{ArrayTrait};
    use core::num::traits::Zero;
    use core::traits::Into;
    use proof_of_habit::base::types::{Entry, Habit};
    use proof_of_habit::interfaces::IProofOfHabit::IProofOfHabit;
    use starknet::storage::*;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    // Constants for time calculations
    const SECONDS_IN_DAY: u64 = 24 * 3600;
    const SECONDS_IN_48_HOURS: u64 = 48 * 3600;

    #[storage]
    pub struct Storage {
        // Usernames: address <-> username mapping
        pub username_to_address: Map<
            felt252, ContractAddress,
        >, // Maps username to address for uniqueness check
        pub address_to_username: Map<ContractAddress, felt252>, // Maps address to username
        // Habit creation
        pub next_habit_id: u32, // Counter for unique habit IDs
        pub habits: Map<u32, Habit>, // Maps habit_id to Habit struct
        pub user_habit_count: Map<
            ContractAddress, u32,
        >, // Maps user address to their total habit count
        pub user_habits_id_list: Map<
            (ContractAddress, u32), u32,
        >, // Maps (user, index) to habit_id
        // Habit logging
        pub habit_log_count: Map<u32, u32>, // Maps habit_id to its total log count
        pub habit_logs: Map<(u32, u32), Entry>, // Maps (habit_id, log_index) to Entry struct
        pub longest_streaks: Map<ContractAddress, u32>,
        pub user_total_logs: Map<ContractAddress, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UsernameSet: UsernameSet,
        HabitCreated: HabitCreated,
        EntryLogged: EntryLogged,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UsernameSet {
        pub user: ContractAddress,
        pub username: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct HabitCreated {
        pub owner: ContractAddress,
        pub habit_id: u32,
        pub title: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EntryLogged {
        pub habit_id: u32,
        pub timestamp: u64,
        pub message: ByteArray,
        pub picture_uri: ByteArray,
    }


    #[abi(embed_v0)]
    pub impl ProofOfHabitImpl of IProofOfHabit<ContractState> {
        fn set_user_name(ref self: ContractState, name: felt252) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'PoH: Zero address');

            // Check if caller already has a username
            let existing_username = self.address_to_username.read(caller);
            assert(existing_username.is_zero(), 'PoH: Username already set');

            // Check if username is already taken
            let existing_address = self.username_to_address.read(name);
            assert(existing_address.is_zero(), 'PoH: Username taken');

            // Set the username mappings
            self.address_to_username.write(caller, name);
            self.username_to_address.write(name, caller);

            self.emit(Event::UsernameSet(UsernameSet { user: caller, username: name }));
        }

        fn create_habit(ref self: ContractState, title: ByteArray, description: ByteArray) -> u32 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'PoH: Zero address');
            // Optional: Could add a check that user has set a username

            let current_habit_id = self.next_habit_id.read();
            let new_habit_id = current_habit_id + 1;
            self.next_habit_id.write(new_habit_id);

            let current_timestamp = get_block_timestamp();

            let new_habit = Habit {
                owner: caller,
                title: title.clone(),
                description: description,
                created_at: current_timestamp,
                last_log_at: 0, // 0 indicates no logs yet
                streak_count: 0, // Streak starts at 0
                total_log_count: 0,
            };

            self.habits.write(new_habit_id, new_habit);

            // Increase users total habits
            let user_habit_idx = self.user_habit_count.read(caller);
            self.user_habit_count.write(caller, user_habit_idx + 1);

            // Add habit to user's list
            self.user_habits_id_list.write((caller, user_habit_idx + 1), new_habit_id);

            // Initialize log count for the new habit
            self.habit_log_count.write(new_habit_id, 0);

            self
                .emit(
                    Event::HabitCreated(
                        HabitCreated { owner: caller, habit_id: new_habit_id, title: title },
                    ),
                );

            new_habit_id
        }

        fn log_entry(
            ref self: ContractState, habit_id: u32, message: ByteArray, picture_uri: ByteArray,
        ) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'PoH: Zero address');

            // Check if habit exists and caller is owner
            let mut habit = self.habits.read(habit_id);
            let mut current_streak = habit.streak_count;
            assert(!habit.owner.is_zero(), 'PoH: Habit not found');
            assert(habit.owner == caller, 'PoH: Not habit owner');

            let current_timestamp = get_block_timestamp();

            // Check if 24 hours have passed since last log
            let twenty_four_hours_in_seconds: u64 = 24 * 60 * 60;
            let forty_eight_hours_in_seconds: u64 = 48 * 60 * 60;

            if habit.last_log_at != 0 { // Not the first log
                assert(
                    current_timestamp >= habit.last_log_at + twenty_four_hours_in_seconds,
                    'PoH: Log entry too soon',
                );

                // Calculate streak
                if current_timestamp < habit.last_log_at + forty_eight_hours_in_seconds {
                    // Logged within 48 hours
                    habit.streak_count = habit.streak_count + 1;
                } else {
                    // Missed > 48 hours, reset streak
                    habit.streak_count = 1;
                }
            } else { // First log for this habit
                habit.streak_count = 1;
            }

            // Create and store the log entry
            let log_index = self.habit_log_count.read(habit_id);
            let new_entry = Entry {
                message: message.clone(), timestamp: current_timestamp, picture_uri: picture_uri.clone(),
            };
            self.habit_logs.write((habit_id, log_index + 1), new_entry);

            // Update habit stats
            habit.last_log_at = current_timestamp;
            habit.total_log_count = habit.total_log_count + 1;
            self.habit_log_count.write(habit_id, habit.total_log_count + 1); // Update the log count map
            self.habits.write(habit_id, habit); // Write back the updated habit struct

            // Update user total logs
            let current_total_user_logs = self.user_total_logs.read(caller);

            self.user_total_logs.write(caller, current_total_user_logs + 1);

            // Update user's longest streak if necessary
            let current_longest = self.longest_streaks.read(caller);
            if current_streak + 1 > current_longest {
                self.longest_streaks.write(caller, current_streak + 1);
            }

            self
                .emit(
                    Event::EntryLogged(
                        EntryLogged {
                            habit_id: habit_id,
                            timestamp: current_timestamp,
                            message: message,
                            picture_uri: picture_uri,
                        },
                    ),
                );
        }

        fn get_user_habits_ids(self: @ContractState, user: ContractAddress) -> Array<u32> {
            let mut habit_ids_array = array![];
            let habit_count = self.user_habit_count.read(user);

            // Iterate through the user's habits list
            let mut i = 1;
            while i != habit_count + 1 {
                let habit_id = self.user_habits_id_list.read((user, i));
                habit_ids_array.append(habit_id);
                i = i + 1;
            }

            habit_ids_array
        }

        fn get_user_habits(self: @ContractState, user: ContractAddress) -> Array<Habit> {
            let user_habit_count = self.user_habit_count.read(user);

            let mut user_habits_array: Array<Habit> = array![];
            let mut i = 1;
            while i != user_habit_count + 1 {
                let habit_id = self.user_habits_id_list.read((user, i));
                let habit = self.habits.read(habit_id);
                user_habits_array.append(habit);
                i = i + 1;
            }
            user_habits_array
        }

        fn get_habit_logs(
            self: @ContractState, habit_id: u32, start: u32, count: u32,
        ) -> Array<Entry> {
            let total_logs = self.habit_log_count.read(habit_id);
            let mut logs_array: Array<Entry> = array![];

            // Ensure start is within bounds and calculate end index
            if start >= total_logs {
                return logs_array; // No logs to return
            }

            let end = if start + count > total_logs {
                total_logs
            } else {
                start + count
            };

            // Iterate through the logs for the specified range
            let mut i = start;
            while i != end + 1 {
                let log_entry = self.habit_logs.read((habit_id, i));
                logs_array.append(log_entry);
                i = i + 1;
            }

            logs_array
        }

        fn get_user_name(self: @ContractState, wallet: ContractAddress) -> felt252 {
            self.address_to_username.read(wallet)
        }

        fn get_wallet_from_user_name(self: @ContractState, user_name: felt252) -> ContractAddress {
            self.username_to_address.read(user_name)
        }

        fn get_total_habit_count(self: @ContractState) -> u32 {
            self.next_habit_id.read() // next_habit_id is the total count + 1
        }

        fn get_total_user_habits(self: @ContractState, user: ContractAddress) -> u32 {
            self.user_habit_count.read(user)
        }

        fn get_habit_log_count(self: @ContractState, habit_id: u32) -> u32 {
            self.habit_log_count.read(habit_id)
        }

        fn get_total_logs_user(self: @ContractState, user: ContractAddress) -> u32{
            self.user_total_logs.read(user)
        }

        fn get_streak(self: @ContractState, habit_id: u32) -> u32 {
            let habit = self.habits.read(habit_id);
            habit.streak_count
        }

        fn get_user_longest_streak(self: @ContractState, user: ContractAddress) -> u32 {
            self.longest_streaks.read(user)
        }
    }
}
