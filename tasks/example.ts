import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../scripts/contractAddress";
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
  WeightedFarmingPool,
  WeightedFarmingPool__factory,
} from "../typechain-types";
import { formatEther, formatUnits, parseUnits } from "ethers/lib/utils";

task("prepare", "Preparation").setAction(async (taskArgs, hre) => {
  await hre.run("mintMockUSD");
  await hre.run("setAllAddress");
  await hre.run("mintShield");
  await hre.run("mintMockERC20");
});
