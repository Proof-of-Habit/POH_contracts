use starknet::ContractAddress;
#[derive(Drop, Serde, starknet::Store)]
pub struct Habit {
    pub owner: ContractAddress,
    pub title: ByteArray,
    pub description: ByteArray,
    pub created_at: u64,
    pub last_log_at: u64,
    pub streak_count: u32,
    pub total_log_count: u32,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Entry {
    pub message: ByteArray,
    pub timestamp: u64,
    pub picture_uri: ByteArray,
}
