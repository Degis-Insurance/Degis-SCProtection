import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import {
  readAddressList,
  readPriorityPoolList,
  storePriorityPoolList,
} from "../scripts/contractAddress";
import {
  CoverRightTokenFactory,
  CoverRightTokenFactory__factory,
  MockSHIELD,
  MockSHIELD__factory,
  MockVeDEG,
  MockVeDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
  PolicyCenter,
  PolicyCenter__factory,
  PriorityPoolFactory,
  PriorityPoolFactory__factory,
  WeightedFarmingPool,
  WeightedFarmingPool__factory,
} from "../typechain-types";
import { formatEther, formatUnits, parseUnits } from "ethers/lib/utils";

task("prepare", "Preparation").setAction(async (taskArgs, hre) => {
  await hre.run("mintMockUSD");
  await hre.run("setAllAddress");
  await hre.run("mintShield");
  await hre.run("mintMockERC20");

  await hre.run("deployPoolLocal");
});

task("deployPoolLocal", "Deploy a new priority pool by owner").setAction(
  async (_, hre) => {
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
      "Test",
      addressList[network.name].MockERC20,
      4000,
      400
    );

    console.log("tx details", await tx.wait());

    const currentCounter = await factory.poolCounter();
    const poolInfo = await factory.pools(currentCounter);

    // Store the new farming pool
    const poolObject = {
      id: currentCounter.toString(),
      poolAddress: poolInfo.poolAddress,
      name: poolInfo.protocolName,
      token: poolInfo.protocolToken,
      premium: poolInfo.basePremiumRatio.toString(),
    };
    priorityPoolList[network.name][currentCounter.toString()] = poolObject;

    storePriorityPoolList(priorityPoolList);
  }
);

task("kkk").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const policyCenter: PolicyCenter = new PolicyCenter__factory(
    dev_account
  ).attach(addressList[network.name].PolicyCenter);

  const exchangeAddress = await policyCenter.exchange();
  console.log("Exchange address", exchangeAddress);
});
