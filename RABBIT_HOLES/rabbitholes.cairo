%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (
    assert_lt, 
    assert_le, 
    assert_not_zero, 
    assert_nn,
)
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
)
from openzeppelin.access.ownable import (
    Ownable_initializer,
    Ownable_only_owner,
    Ownable_get_owner,
    Ownable_transfer_ownership,
)
from openzeppelin.token.erc20.library import (
    ERC20_name,
    ERC20_symbol,
    ERC20_totalSupply,
    ERC20_decimals,
    ERC20_balanceOf,
    ERC20_mint,
    ERC20_burn,
    ERC20_initializer,
)

############################
# @author DegenDeveloper.eth
# May 5, 2022
#
# This contract allows accounts to start permanent discussion threads for any topic.
# 
# Accounts can leave comments in existing discussion threads.
# 
# These discussion threads are `holes` and the comments inside are `rabbits`
#
# To dig a hole, an account must pay the DIG_FEE. In exchange for digging a hole,
# the account will be minted `dig_reward` number of RBIT.
#
# To leave a rabbit in a hole, an account will burn 1 RBIT.
#
# This contract stores indexes for each hole, rabbit, and account for easier frontend parsing.
##############################################################################################

##########
# Structs 
########

###################################################
# This struct stores data members for each hole dug
# @param digger The account that dug the hole
# @param title The felt representation for the hole's title ( < 32 char)
# @param timestamp The time the hole was dug
# @param rabbit_count The number of rabbits in the hole
#######################################################
struct Hole:
    member digger: felt
    member title: felt
    member timestamp: felt
    member rabbit_count: felt
end
######################################################
# This struct stores data members for each rabbit left
# @param leaver The account that left the rabbit
# @param timestamp The time the rabbit was left
# @param hole_index The index for the hole the rabbit belongs in
# @param comment_stack_start The index the comment starts at in the comment_stack
# @param comment_stack_len The number of comment indexes (felts) the comment fills
##################################################################################
struct Rabbit:
    member leaver: felt
    member timestamp: felt
    member hole_index: felt
    member comment_stack_start: felt
    member comment_stack_len: felt
end

######################
# Hole/Rabbit Storage
####################

# lookup for a hole's index by its title felt
@storage_var
func hole_indexes(title: felt) -> (index: felt):
end
# current number of holes
@storage_var
func current_hole_index() -> (index: felt):
end
# current number of rabbits
@storage_var
func current_rabbit_index() -> (index: felt):
end
# all holes by index
@storage_var
func hole_storage(index: felt) -> (hole: Hole):
end
# all rabbits by index
@storage_var
func rabbit_storage(index: felt) -> (rabbit: Rabbit):
end
# lookup for rabbits in hole
@storage_var
func rabbit_in_hole_storage(hole_index: felt, rabbit_index: felt) -> (rabbit_index: felt):
end 

#######################
# Fees/Rewards Storage
#####################

# the reward for digging a hole in RBIT
@storage_var
func dig_reward_storage() -> (reward: felt):
end
# the fee for digging a hole (in erc20 token undetermined yet)
@storage_var
func dig_fee_storage() -> (reward: felt):
end

##################
# Comment Storage
################

# length of comment stack; number of comment chunks
@storage_var
func comment_stack_len() -> (len: felt):
end
# the entire comment stack; all comment chunks
@storage_var
func comment_stack(comment_index: felt) -> (comment_chunk: felt):
end

##################
# Account Storage
################

# number of holes by each account
@storage_var
func account_holes_count(account: felt) -> (count: felt):
end
# number of rabbits by each account
@storage_var
func account_rabbits_count(account: felt) -> (count: felt):
end
# all holes from an account by index
@storage_var
func account_holes(account: felt, index: felt) -> (hole_index: felt):
end
# all rabbits from an account by index
@storage_var
func account_rabbits(account: felt, index: felt) -> (rabbit_index: felt):
end
# number of accounts that have dug holes
@storage_var 
func number_of_accounts() -> (count: felt):
end
# each account by index
@storage_var
func accounts_by_index(index: felt) -> (account: felt):
end
# lookup for an account's index
@storage_var
func account_indexes(account: felt) -> (index: felt):
end

##############
# Constructor
############

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        owner: felt
    ):
    # mint owner initial supply of tokens (1000 RBIT)
    let initial_supply: Uint256 = Uint256(1000 * 1000000000000000000, 0)
    ERC20_mint(owner, initial_supply)
    # sets collection name, symbol and decimals
    ERC20_initializer(name, symbol, 18)
    # sets contract owner
    Ownable_initializer(owner)
    # set the fee (in wei) for digging hole (Not yet implemented)
    dig_fee_storage.write(10 * 1000000000000000000)
    # set number of RBIT minted for digging hole (25 RBIT)
    dig_reward_storage.write(25 * 1000000000000000000)
    
    return ()
end

########
# Owner 
######

# Sets the fee for digging a hole
# @param amount A felt for the amount of wei to charge per dig
@external
func setDigFee{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(amount: felt):
    Ownable_only_owner()
    dig_fee_storage.write(amount)
    return()
end
# Sets the number of RBIT minted to an account for digging a hole
# @param amount The number of RBIT to mint in wei
@external
func setDigReward{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(amount: felt):
    Ownable_only_owner()
    dig_reward_storage.write(amount)
    return()
end
# Sets a new contract owner
# @param new_owner The address to set as contract owner
@external
func transferOwnership{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(new_owner: felt):
    Ownable_only_owner()
    Ownable_transfer_ownership(new_owner)
    return()
end

###########
# Internal
#########

# recursive function to make the comment for a specific rabbit
func _comment_creator{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(start: felt, len: felt, comment: felt*):
    if len == 0:
        return ()
    end
    let (c) = comment_stack.read(start+len)
    assert [comment] = c
    _comment_creator(start=start, len=len - 1, comment=comment + 1)
    return ()
end
# recursive function to set the comment stack for a rabbit's comment
func _leave_rabbit{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(comment_len: felt, comment: felt*):
    if comment_len == 0:
        return()
    end
    let displacement: felt = comment_stack_len.read()
    let index = displacement + comment_len
    comment_stack.write(index, [comment])
    _leave_rabbit(comment_len - 1, comment + 1)
    return()
end

#########
# Public
#######

# Use this function to leave a rabbit in an existing hole
# @notice Account will burn 1 RBIT 
# @param hole_index The hole to leave the rabbit in
# @param comment_len The length of the comment array
# @param comment An array of felts representing the rabbit's comment
@external
func leave_rabbit{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(hole_index: felt, comment_len: felt, comment: felt*):
    alloc_locals
    let current_hole_id: felt = current_hole_index.read()
    let hole_diff: felt = current_hole_id - hole_index
    # require hole not dug yet
    with_attr error_message(
            "Rabbitholes: Hole not dug yet"):
        assert_le(hole_index, current_hole_id)
    end
    with_attr error_message(
            "Rabbitholes: Invalid hole index"):
        assert_not_zero(hole_index)
    end
    # sets rabbit comment on comment stack
    _leave_rabbit(comment_len, comment)
    let account: felt = get_caller_address()
    let id: felt = current_rabbit_index.read()
    let timestamp: felt = get_block_timestamp()
    let current_hole: Hole = hole_storage.read(hole_index)
    let current_comment_index: felt = comment_stack_len.read()
    let current_rabbits_in_hole: felt = current_hole.rabbit_count    
    let current_rabbits_from_account: felt = account_rabbits_count.read(account)
    # create and store new rabbit struct
    rabbit_storage.write(id+1, Rabbit(leaver=account, comment_stack_start=current_comment_index, comment_stack_len=comment_len, timestamp=timestamp, hole_index=hole_index))
    # increment rabbits in hole and store updated count
    hole_storage.write(hole_index, Hole(digger=current_hole.digger, title=current_hole.title, timestamp=current_hole.timestamp, rabbit_count=current_rabbits_in_hole + 1))
    # set rabbit in hole
    rabbit_in_hole_storage.write(hole_index, current_rabbits_in_hole + 1, id + 1)
    # set account's rabbit
    account_rabbits.write(account, current_rabbits_from_account + 1, id + 1)
    # increment number of rabbits from account
    account_rabbits_count.write(account, current_rabbits_from_account + 1)
    # increment comment stack len by comment_len
    comment_stack_len.write(current_comment_index + comment_len)
    # increment number of rabbits in contract
    current_rabbit_index.write(id + 1)
    # burn 1 rbit
    let burn_amount: Uint256 = Uint256(1 * 1000000000000000000, 0)
    ERC20_burn(account, burn_amount)
    return()
end
# Use this function to dig a hole
# @notice Account will pay the dig fee
# @notice Account will be minted dig reward number of RBIT
# @param title The felt representation for a hole's title
@external
func dig_hole{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(title: felt):
    alloc_locals
    ## NEED TO CHARGE DIG FEE
    let hole_index_lookup: felt = hole_indexes.read(title)
    # require hole not dug yet
    with_attr error_message(
            "Rabbitholes: Hole already dug"):
        assert hole_index_lookup = 0
    end
    let account: felt = get_caller_address()
    let timestamp: felt = get_block_timestamp()
    let id: felt = current_hole_index.read()
    let current_holes_from_account: felt = account_holes_count.read(account)
    # create and store new hole struct
    hole_storage.write(id+1, Hole(digger=account, title=title, timestamp=timestamp, rabbit_count=0))
    # set index for hole title
    hole_indexes.write(title, id + 1)
    # set account's holes
    account_holes.write(account, current_holes_from_account + 1, id + 1)
    # increment number of holes from account
    account_holes_count.write(account, current_holes_from_account + 1)
    # increment number of holes in contract
    current_hole_index.write(id + 1)
    # mint RBIT
    let reward: felt = dig_reward_storage.read()
    let amount: Uint256 = Uint256(reward, 0)
    ERC20_mint(account, amount)
    # check account index
    let account_index: felt = account_indexes.read(account)
    if account_index == 0:
        let current_account_count: felt = number_of_accounts.read()
        # set account index
        accounts_by_index.write(current_account_count + 1, account)
        # set account's index
        account_indexes.write(account, current_account_count + 1)
        # increment account total
        number_of_accounts.write(current_account_count + 1)
        return()
    end
    return()
end

############
# Read-only
##########

# returns the number of holes dug
@view 
func number_of_holes{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (holes: felt):
    let holes: felt = current_hole_index.read()
    return (holes)
end
# returns the number of rabbits left
@view 
func number_of_rabbits{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (rabbits: felt):
    let rabbits: felt = current_rabbit_index.read()
    return (rabbits)
end
# returns the index for a hole (by title felt)
@view
func index_of_hole{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(title: felt) -> (index: felt):
    let index: felt = hole_indexes.read(title)
    return (index)
end
# returns a hole by index
@view
func hole_by_index{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(index: felt) -> (hole: Hole):
    let hole: Hole = hole_storage.read(index)
    return (hole)
end
# returns a rabbit by index
@view
func rabbit_by_index{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(index: felt) -> (rabbit: Rabbit):
    let rabbit: Rabbit = rabbit_storage.read(index)
    return (rabbit)
end
# returns a rabbit in hole by index
@view
func rabbit_in_hole{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(hole_index: felt, rabbit_index: felt) -> (rabbit_index: felt):
    let rabbit_index: felt = rabbit_in_hole_storage.read(hole_index, rabbit_index)
    return (rabbit_index)
end
# returns a comment for a rabbit by index
@view
func rabbit_comment_by_index{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(index: felt) -> (comment_len: felt, comment: felt*):
    alloc_locals
    let this_rabbit: Rabbit = rabbit_storage.read(index)
    let r_comment_start:felt = this_rabbit.comment_stack_start
    let r_comment_len: felt = this_rabbit.comment_stack_len
    let (comment) = alloc()
    _comment_creator(r_comment_start, r_comment_len, comment)
    return (r_comment_len, comment)
end
# returns the number of holes dug by an account
@view 
func number_of_holes_from_account{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (amount: felt):
    let amount: felt = account_holes_count.read(account)
    return (amount)
end
# returns the number of rabbits left by an account
@view 
func number_of_rabbits_from_account{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (amount: felt):
    let amount: felt = account_rabbits_count.read(account)
    return (amount)
end
# return a hole by index from account
# @param account The account to lookup
# @param index The index in account_holes to lookup
@view 
func holes_from_account_by_index{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(account: felt, index: felt) -> (hole_index: felt):
    let hole_index: felt = account_holes.read(account, index)
    return (hole_index)
end
# return a rabbit by index from account
# @param account The account to lookup
# @param index The index in account_rabbits to lookup
@view 
func rabbits_from_account_by_index{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(account: felt, index: felt) -> (rabbit_index: felt):
    let rabbit_index: felt = account_rabbits.read(account, index)
    return (rabbit_index)
end
# returns the index for an account
@view
func account_index{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (index: felt):
    let index: felt = account_indexes.read(account)
    return(index)
end
# returns an account by index
@view
func account_by_index{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(index: felt) -> (account: felt):
    let account: felt = accounts_by_index.read(index)
    return(account)
end
# returns the total number of accounts (diggers)
@view
func accounts_total{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (count: felt):
    let count: felt = number_of_accounts.read()
    return(count)
end
# returns the fee to dig a hole in wei
@view
func dig_fee{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (fee: felt):
    let fee: felt = dig_fee_storage.read()
    return (fee)
end
# returns the reward for digging a hole in RBIT
@view
func dig_reward{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (reward: felt):
    let reward: felt = dig_reward_storage.read()
    return (reward)
end
# returns the contract owner
@view
func owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let owner: felt = Ownable_get_owner()
    return (owner)
end
# returns the name of the collection as a felt
@view
func name{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    let (name) = ERC20_name()
    return (name)
end
# returns the symbol for the collection as a felt
@view
func symbol{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    let (symbol) = ERC20_symbol()
    return (symbol)
end
# returns the total number of tokens in circulation (minted - burned)
@view
func totalSupply{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply: Uint256) = ERC20_totalSupply()
    return (totalSupply)
end
# returns the number of decimals for this token (for wallet viewing only)
@view
func decimals{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (decimals: felt):
    let decimals: felt = ERC20_decimals()
    return (decimals)
end
# returns the token balance for an account
@view
func balanceOf{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(account: felt) -> (balance: Uint256):
    let (balance: Uint256) = ERC20_balanceOf(account)
    return (balance)
end
