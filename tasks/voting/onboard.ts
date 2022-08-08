import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../../scripts/contractAddress";
import {
  OnboardProposal,
  OnboardProposal__factory,
} from "../../typechain-types";
import { parseUnits } from "ethers/lib/utils";

task("proposeNewPool", "Proposa a new pool in onboard proposal")
  .addParam("name", "Protocol name", null, types.string)
  .addParam("token", "Token address", null, types.string)
  .addParam("capacity", "Max capacity", null, types.string)
  .addParam("premium", "Premium ratio annually", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnbardProposal);

    const tx = await onboardProposal.propose(
      taskArgs.name,
      taskArgs.token,
      parseUnits(taskArgs.maxCapacity, 6),
      taskArgs.premiumRatio
    );

    console.log("tx details", await tx.wait());
  });