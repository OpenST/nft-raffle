import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

export interface Signers {
  deployer: SignerWithAddress;
  arbiter: SignerWithAddress;
  organiser: SignerWithAddress;
  challenger: SignerWithAddress;
  anyone: SignerWithAddress;
}
