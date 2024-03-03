import {ethers} from "hardhat";

async function main() {

    const MyERC20 = await ethers.deployContract("MyERC20");

    await MyERC20.waitForDeployment();


    const Airdrop = await ethers.deployContract("Airdrop", [9783, MyERC20.target]);

    await Airdrop.waitForDeployment();

    console.log(` deployed to ${Airdrop.target}`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
