import hre from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { Raffle } from "../typechain/Raffle";
import { Signers } from "../types";
import { shouldBehaveLikeRaffle } from "./Raffle.behavior";

const { deployContract } = hre.waffle;

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await hre.ethers.getSigners();
    this.signers.deployer = signers[0];
    // this.signers.arbiter = signers[1];
    // this.signers.organiser = signers[2];
    // this.signers.challenger = signers[3];
    // this.signers.anyone = signers[4];
  });

  describe("Raffle", function () {
    beforeEach(async function () {
      const erc20_OST: string = "0x2c4e8f2d746113d0696ce89b35f0d8bf88e0aeca";
console.log(this.signers.deployer.toString());
//       const arbiter: string = this.signers.arbiter.toString();
      const chainId: number  = 1414;
      const raffleArtifact: Artifact = await hre.artifacts.readArtifact("Raffle");
      this.raffle = <Raffle>await deployContract(
        this.signers.deployer, raffleArtifact,
        [
          erc20_OST,
          "0xF90b24E03483144235E03738461a1f22cf07Ae5D",
          chainId
        ]);
    });

    shouldBehaveLikeRaffle();
  });
});
