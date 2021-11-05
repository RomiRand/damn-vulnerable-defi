const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, attacker;

    const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther('40');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            this.masterCopy.address,
            this.walletFactory.address,
            this.token.address,
            users
        );

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.true;            
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        // walletFactory = this.walletFactory.connect(attacker);
        // await walletFactory.createProxyWithCallback(this.masterCopy.address, "0x00000000", 0, this.walletRegistry.address);

        attack = await (await ethers.getContractFactory('AttackWalletRegistry', attacker)).deploy(
            this.walletFactory.address,
            this.masterCopy.address,
            this.walletRegistry.address,
            users,
            this.token.address
        );
        res = await attack.attack();

        // I like to use this + test events for debugging, I'll just leave this here :)
        /*
        let abi = [
            "event Transfer(address indexed from, address indexed to, uint256 value)",
            "event Approval(address indexed owner, address indexed spender, uint256 value)"
            ];
        let iface = new ethers.utils.Interface(abi);

        receipt = await res.wait();
        for (log of receipt.logs)
        {
            try
            {
                let l = await iface.parseLog(log);
                if (l.name === "Transfer")
                    console.log("Transfer From: " + l.args.from + ", To: " + l.args.to + ", value: " + l.args.value);
                else if (l.name === "Approval")
                    console.log("Approval Owner: " + l.args.owner + ", spender: " + l.args.spender + ", value: " + l.args.value);
                else
                    console.log("Event: " + l.name);
            }
            catch {}
        }
        */
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

            // User is no longer registered as a beneficiary
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Attacker must have taken all tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
