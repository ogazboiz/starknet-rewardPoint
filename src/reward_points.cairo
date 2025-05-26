use starknet::ContractAddress;

#[starknet::interface]
trait IRewardPoints<TContractState> {
    fn add_points(ref self: TContractState, user: ContractAddress, points: u256);
    fn redeem_points(ref self: TContractState, user: ContractAddress, points: u256);
    fn transfer_points(ref self: TContractState, to_user: ContractAddress, points: u256);
    fn get_balance(self: @TContractState, user: ContractAddress) -> u256;
    fn get_owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod RewardPointsContract {
    use starknet::{ContractAddress, get_caller_address};
    // ✅ FIXED: Import the correct storage traits for Cairo 2.11.4
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        StorageMapReadAccess, StorageMapWriteAccess, Map
    };

    #[storage]
    struct Storage {
        // ✅ FIXED: Use u256 instead of felt252 for proper comparison support
        user_points: Map<ContractAddress, u256>,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PointsAdded: PointsAdded,
        PointsRedeemed: PointsRedeemed,
        PointsTransferred: PointsTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct PointsAdded {
        #[key]
        user: ContractAddress,
        points: u256,
        new_balance: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PointsRedeemed {
        #[key]
        user: ContractAddress,
        points: u256,
        remaining_balance: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PointsTransferred {
        #[key]
        from_user: ContractAddress,
        #[key]
        to_user: ContractAddress,
        points: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl RewardPointsImpl of super::IRewardPoints<ContractState> {
        /// Adds points to a user's balance
        /// @param user: The address of the user to add points to
        /// @param points: The number of points to add
        fn add_points(ref self: ContractState, user: ContractAddress, points: u256) {
            // Only owner can add points
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can add points');
            
            // ✅ FIXED: u256 supports comparison operators
            assert(points > 0, 'Points must be positive');
            
            // Get current balance and add new points
            let current_balance = self.user_points.read(user);
            let new_balance = current_balance + points;
            
            // Update storage
            self.user_points.write(user, new_balance);
            
            // Emit event
            self.emit(Event::PointsAdded(PointsAdded {
                user,
                points,
                new_balance,
            }));
        }

        /// Redeems points from a user's balance
        /// @param user: The address of the user redeeming points
        /// @param points: The number of points to redeem
        fn redeem_points(ref self: ContractState, user: ContractAddress, points: u256) {
            // User can only redeem their own points or owner can redeem for anyone
            let caller = get_caller_address();
            assert(caller == user || caller == self.owner.read(), 'Unauthorized redemption');
            
            // ✅ FIXED: u256 supports comparison operators
            assert(points > 0, 'Points must be positive');
            
            // Read current balance - FIRST read the balance
            let current_balance = self.user_points.read(user);
            
            // ✅ FIXED: Check if user has enough points - use assert here as requested
            assert(current_balance >= points, 'Insufficient points');
            
            // Deduct points
            let remaining_balance = current_balance - points;
            self.user_points.write(user, remaining_balance);
            
            // Emit event
            self.emit(Event::PointsRedeemed(PointsRedeemed {
                user,
                points,
                remaining_balance,
            }));
        }

        /// Transfers points between users
        /// @param to_user: The address to transfer points to
        /// @param points: The number of points to transfer
        fn transfer_points(ref self: ContractState, to_user: ContractAddress, points: u256) {
            let from_user = get_caller_address();
            
            // ✅ FIXED: u256 supports comparison operators
            assert(points > 0, 'Points must be positive');
            
            // Ensure not transferring to self
            assert(from_user != to_user, 'Cannot transfer to self');
            
            // Read balances
            let from_balance = self.user_points.read(from_user);
            let to_balance = self.user_points.read(to_user);
            
            // ✅ FIXED: Check if sender has enough points
            assert(from_balance >= points, 'Insufficient points');
            
            // Update balances
            self.user_points.write(from_user, from_balance - points);
            self.user_points.write(to_user, to_balance + points);
            
            // Emit event
            self.emit(Event::PointsTransferred(PointsTransferred {
                from_user,
                to_user,
                points,
            }));
        }

        /// Gets the point balance of a user
        /// @param user: The address to check balance for
        /// @return: The user's point balance
        fn get_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }

        /// Gets the contract owner
        /// @return: The owner's address
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }
}