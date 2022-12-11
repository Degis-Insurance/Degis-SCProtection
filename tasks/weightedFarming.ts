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
import { formatEther, parseUnits } from "ethers/lib/utils";
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
  console.log(userInfo.shares.toString());

  const poolInfo = await farming.getPoolArrays(2);
  console.log("Token in this farming:", poolInfo[0]);
  console.log("Amount in this farming:", poolInfo[1].toString());
  console.log("Weight in this farming:", poolInfo[2].toString());

  const amount = await farming.getUserLPAmount(
    1,
    "0x7d4d243ed1b432d6eda029f5e35a4e5c871738ad"
  );
  console.log(amount.toString());

  const counter = await farming.counter();
  console.log("counter", counter.toString());

  const pool = await farming.pools(2);
  console.log("Pool shares: ", pool.shares.toString());
  console.log("Pool acc reward per share: ", pool.accRewardPerShare.toString());
  console.log("Pool reward token: ", pool.rewardToken);
  console.log("Pool last reward time: ", pool.lastRewardTimestamp.toString());

  const rewardToken: MockERC20 = new MockERC20__factory(dev_account).attach(
    pool.rewardToken
  );
  const balance = await rewardToken.balanceOf(
    addressList[network.name].WeightedFarmingPool
  );
  console.log("Reward token balance: ", formatEther(balance));
});

task("checkFarmingSpeed", "Check farming speed")
  .addParam("id", "Pool id", null, types.string)
  .addParam("year", "Year", null, types.string)
  .addParam("month", "Month", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);

    const rewardSpeed = await farming.speed(
      taskArgs.id,
      taskArgs.year,
      taskArgs.month
    );
    console.log("Reward speed:", hre.ethers.utils.formatEther(rewardSpeed.div(1e12)));

    const pending = await farming.pendingReward(
      taskArgs.id,
      dev_account.address
    );
    console.log("Pending: ", formatEther(pending));

    const userShares = await farming.users(1, dev_account.address);
    console.log("User shares:", userShares.shares.toString());
    console.log("User debt:", userShares.rewardDebt.toString());

    const pool = await farming.pools(1);
    console.log("Pool acc:", pool.accRewardPerShare.toString());
    console.log("Pool shares:", pool.shares.toString());
  });

task("harvest", "Check farming speed")
  .addParam("id", "Pool id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);

    const tx = await farming.harvest(taskArgs.id, dev_account.address);
    console.log("Reward speed:", await tx.wait());
  });

task("setFarmingSpeed", "Check farming speed")
  .addParam("id", "Pool id", null, types.string)
  .addParam("speed", "Speed to add", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);

    const years = [2022, 2022, 2022];
    const months = [9, 10, 11];

    const tx = await farming.updateRewardSpeed(
      taskArgs.id,
      taskArgs.speed,
      years,
      months
    );
    console.log("Tx details: ", await tx.wait());
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
  console.log("User shares: ", userInfo.shares.toString());
  console.log("User reward debt: ", userInfo.rewardDebt.toString());

  const poolInfo = await farming.pools(1);
  console.log(
    "Pool acc reward per share: ",
    poolInfo.accRewardPerShare.toString()
  );
  console.log("Pool shares: ", poolInfo.shares.toString());

  console.log("Pool reward token address: ", poolInfo.rewardToken);

  const poolArray = await farming.getPoolArrays(1);
  console.log("Tokens: ", poolArray[0]);
  console.log("Amount:", poolArray[1]);

  const userAmount = await farming.getUserLPAmount(1, addr);
  console.log("User lp amount: ", userAmount);

  const weights = poolArray[2];
  console.log("Weights: ", weights);
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

    const tx = await farming.addToken(2, taskArgs.token, weight);
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

    const tx = await farming.updatePool(taskArgs.id);
    console.log("Tx details:", await tx.wait());
  });

task("pendingReward", "Pending reward in farming pool")
  .addParam("address", "user address", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);

    const pending = await farming.pendingReward(2, taskArgs.address);
    console.log("Pending reward", formatEther(pending));

    const userInfo = await farming.users(2, taskArgs.address);
    console.log("User share: ", formatEther(userInfo.shares));
    console.log("User debt: ", formatEther(userInfo.rewardDebt));

    const userAmount = await farming.getUserLPAmount(2, taskArgs.address);
    console.log("User lp amount: ", userAmount[0].toString());
  });

task("updateRewardSpeed", "Update reward speed in farming pool").setAction(
  async (_, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const farming: WeightedFarmingPool = new WeightedFarmingPool__factory(
      dev_account
    ).attach(addressList[network.name].WeightedFarmingPool);
  }
);
