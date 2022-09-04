import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../scripts/contractAddress";
import {
  MockVeDEG,
  MockVeDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
} from "../typechain-types";
import { parseUnits } from "ethers/lib/utils";
import { MockERC20, MockERC20__factory } from "../typechain-types";

task("mintFarmingReward", "Mint reward token to weighted farming pool")
  .addParam("name", "Token name", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farmingPoolAddress = addressList[network.name].WeightedFarmingPool;

    const tokenName = taskArgs.name;

    const token: MockERC20 = new MockERC20__factory(dev_account).attach(
      addressList[network.name].tokenName
    );

    const tx = await token.mint(farmingPoolAddress, parseUnits("10000"));

    console.log("tx details", await tx.wait());
  });
