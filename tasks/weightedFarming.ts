import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../scripts/contractAddress";
import {
  MockVeDEG,
  MockVeDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
  WeightedFarmingPool,
  WeightedFarmingPool__factory,
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

task("checkFarming", "Check farming status").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
    dev_account
  ).attach(addressList[network.name].WeightedFarmingPool);

  const userInfo = await farming.users(
    1,
    "0x7d4d243ed1b432d6eda029f5e35a4e5c871738ad"
  );
  console.log(userInfo.share.toString());

  const poolInfo = await farming.getPoolArrays(1);
  console.log("Token in this farming:", poolInfo[0]);
  console.log("Amount in this farming:", poolInfo[1]);
  console.log("Weight in this farming:", poolInfo[2]);

  const amount = await farming.getUserLPAmount(
    1,
    "0x7d4d243ed1b432d6eda029f5e35a4e5c871738ad"
  );
  console.log(amount.toString());
});

task("checkFarmings", "Check farming status").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
    dev_account
  ).attach(addressList[network.name].WeightedFarmingPool);

  const addr = "0x7d4d243ed1b432d6eda029f5e35a4e5c871738ad";

  const userInfo = await farming.users(1, addr);
  console.log("User shares: ", userInfo.share.toString());
  console.log("User reward debt: ", userInfo.rewardDebt.toString());

  const userAmount = await farming.getUserLPAmount(1, addr);
  console.log("User lp amount: ", userAmount[0]);
});
