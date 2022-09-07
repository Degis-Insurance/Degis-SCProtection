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
    "0x1be1a151ba3d24f594ee971dc9b843f23b5ba80e"
  );
  console.log(userInfo.share.toString());

  const poolInfo = await farming.getPoolArrays(2);
  console.log("Token in this farming:", poolInfo[0]);
  console.log("Amount in this farming:", poolInfo[1]);
  console.log("Weight in this farming:", poolInfo[2]);

  const amount = await farming.getUserLPAmount(
    1,
    "0x1be1a151ba3d24f594ee971dc9b843f23b5ba80e"
  );
  console.log(amount.toString());

  const counter = await farming.counter();
  console.log("counter", counter.toString());
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

  const addr = "0x1be1a151ba3d24f594ee971dc9b843f23b5ba80e";

  const userInfo = await farming.users(1, addr);
  console.log("User shares: ", userInfo.share.toString());
  console.log("User reward debt: ", userInfo.rewardDebt.toString());

  const userAmount = await farming.getUserLPAmount(1, addr);
  console.log("User lp amount: ", userAmount[0].toString());
});

task("addPool", "Add new farming pool")
  .addParam("rewardtoken", "reward token address", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);

    const tx = await farming.addPool(taskArgs.rewardtoken);
    console.log("Tx details:", await tx.wait());
  });

task("addToken", "Add new token into a farming pool")
  .addParam("token", "farming lp token address", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);

    const weight = parseUnits("1", 12);

    const tx = await farming.addToken(1, taskArgs.token, weight);
    console.log("Tx details:", await tx.wait());
  });

task("updatePool", "Add new token into a farming pool")
  .addParam("id", "farming lp token address", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);

    const tx = await farming.updatePool(1);
    console.log("Tx details:", await tx.wait());
  });
