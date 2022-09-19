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

task("claimPayout", "Mint reward token to weighted farming pool").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const policyCenter: PolicyCenter = new PolicyCenter__factory(
      dev_account
    ).attach(addressList[network.name].PolicyCenter);
    const crFactory: CoverRightTokenFactory =
      new CoverRightTokenFactory__factory(dev_account).attach(
        addressList[network.name].CoverRightTokenFactory
      );
    const shield: MockSHIELD = new MockSHIELD__factory(dev_account).attach(
      addressList[network.name].MockShield
    );

    const shieldBalanceBefore = await shield.balanceOf(dev_account.address);
    console.log("Balance before: ", formatUnits(shieldBalanceBefore, 6));

    const crTokenAddress = await crFactory.getCRTokenAddress(1, 1667260799, 1);
    console.log("CR token address: ", crTokenAddress);

    // const tx = await policyCenter.claimPayout(1, crTokenAddress, 1);
    // console.log("tx details", await tx.wait());

    const shieldBalanceAfter = await shield.balanceOf(dev_account.address);
    console.log("Balance after: ", formatUnits(shieldBalanceAfter, 6));

    console.log(
      "Claim amount: ",
      formatUnits(shieldBalanceAfter.sub(shieldBalanceBefore), 6)
    );
  }
);

task("buyCover", "Buy a cover")
  .addParam("id", "Pool id to buy", null, types.string)
  .addParam("amount", "Cover amount", null, types.string)
  .addParam("length", "Cover length in month", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const tx = await center.buyCover(
      taskArgs.id,
      parseUnits(taskArgs.amount, 6),
      taskArgs.length,
      parseUnits("10000")
    );

    console.log("Tx details", await tx.wait());
  });
