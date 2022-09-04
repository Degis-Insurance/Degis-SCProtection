import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import {
  readAddressList,
  readPriorityPoolList,
  storePriorityPoolList,
} from "../../scripts/contractAddress";
import {
  MockVeDEG,
  MockVeDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
  PriorityPoolFactory,
  PriorityPoolFactory__factory,
} from "../../typechain-types";
import { parseUnits } from "ethers/lib/utils";

task("deployPriorityPool", "Deploy a new priority pool by owner")
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
    const priorityPoolList = readPriorityPoolList();

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const tx = await factory.deployPool(
      taskArgs.name,
      taskArgs.token,
      taskArgs.capacity,
      taskArgs.premium
    );

    console.log("tx details", await tx.wait());

    const currentCounter = await factory.poolCounter();
    const poolInfo = await factory.pools(currentCounter);

    // Store the new farming pool
    const poolObject = {
      id: currentCounter,
      name: poolInfo.protocolName,
      token: poolInfo.protocolToken,
      premium: poolInfo.basePremiumRatio,
    };
    priorityPoolList[network.name][currentCounter.toString()] = poolObject;

    storePriorityPoolList(priorityPoolList);
  });
