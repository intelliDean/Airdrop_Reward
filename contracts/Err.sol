// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Err {

    error ZERO_ADDRESS_NOT_ALLOWED();
    error MAXIMUM_TOKEN_SUPPLY_REACHED();
    error INSUFFICIENT_ALLOWANCE_BALANCE();
    error INSUFFICIENT_BALANCE();
    error ONLY_OWNER_IS_ALLOWED();
    error BALANCE_MORE_THAN_TOTAL_SUPPLY();
    error CANNOT_BURN_ZERO_TOKEN();


    error ADDRESS_ZERO_NOT_ALLOWED();
    error ONLY_OWNER();
    error NAME_CANNOT_BE_EMPTY();
    error NAME_TOO_LONG();
    error YOU_ARE_NOT_A_PARTICIPANT();
    error YOU_HAVE_ALREADY_REGISTERED();
    error RESULT_IS_NOT_READY();
    error YOU_HAVE_NOT_PARTICIPATED();
    error YOU_ARE_NOT_REGISTERED();
    error MAX_POOL_NOT_REACHED();
    error REQUEST_NOT_FOUND();
    error WINNERS_ARE_NOT_SELECTED_YET();
    error YOU_DO_NOT_QUALIFY_FOR_THIS_AIRDROP();
    error YOU_DO_NOT_HAVE_BALANCE_YET();
    error COULD_NOT_BE_CLAIMED__TRY_AGAIN_LATER();

}