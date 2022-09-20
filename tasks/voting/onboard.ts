import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../../scripts/contractAddress";
import {
  MockVeDEG,
  MockVeDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
} from "../../typechain-types";
import { formatEther, parseUnits } from "ethers/lib/utils";

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
    ).attach(addressList[network.name].OnboardProposal);

    const tx = await onboardProposal.propose(
      taskArgs.name,
      taskArgs.token,
      taskArgs.capacity,
      taskArgs.premium
    );

    console.log("tx details", await tx.wait());
  });

task("startVotingProposal", "Start voting process of a proposal")
  .addParam("id", "Proposal id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnboardProposal);

    const tx = await onboardProposal.startVoting(taskArgs.id);

    console.log("Tx details:", await tx.wait());
  });

task("settleProposal", "Settle a proposal voting result")
  .addParam("id", "Proposal id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnboardProposal);

    const tx = await onboardProposal.settle(taskArgs.id);
    console.log("Tx details:", await tx.wait());

    const p = await onboardProposal.proposals(taskArgs.id);
    console.log(p.result.toString());

    const veDEG: MockVeDEG = new MockVeDEG__factory(dev_account).attach(
      addressList[network.name].MockVeDEG
    );

    const totalSupply = await veDEG.totalSupply();
    console.log(formatEther(totalSupply));
  });

task("getProposal", "Get proposal info")
  .addParam("id", "proposal id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnboardProposal);

    const proposal = await onboardProposal.proposals(taskArgs.id);
    console.log(proposal);
  });

task("setQuorumProposal", "Start a new report for a pool").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnboardProposal);

    const newQuorum = 0;

    const tx = await onboardProposal.setQuorumRatio(newQuorum);

    console.log("tx details", await tx.wait());
  }
);
