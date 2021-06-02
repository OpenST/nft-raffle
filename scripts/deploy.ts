import { Contract, ContractFactory } from "ethers";
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main(): Promise<void> {
  // Hardhat always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await run("compile");

  // We get the contract to deploy
  const Raffle: ContractFactory = await ethers.getContractFactory("Raffle");
  const raffle: Contract = await Raffle.deploy(
    "0x2c4e8f2d746113d0696ce89b35f0d8bf88e0aeca",
    "0x0000000000000000000000000000000000000abc",
    1414);
  await raffle.deployed();

  console.log("Raffle deployed to: ", raffle.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
