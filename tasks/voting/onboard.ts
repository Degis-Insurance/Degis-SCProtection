import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../../scripts/contractAddress";
import {
  OnboardProposal,
  OnboardProposal__factory,
} from "../../typechain-types";

// npx hardhat proposeNewPool --network avaxNew
// --name BTC.b --token 0x152b9d0FdC40C096757F570A51E494bd4b943E50
// --capacity 5000 --premium 280

// --name ETH.b --token 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB
// --capacity 5000 --premium 280

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

    const currentId = await onboardProposal.proposalCounter();
    console.log("Current proposal id:", currentId.toString());

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

    const res = p.result.toString();

    if (res == "1") console.log("Passed");
    else if (res == "2") console.log("Reject");
    else if (res == "3") console.log("Tied");
    else console.log("Failed");

    // const veDEG: MockVeDEG = new MockVeDEG__factory(dev_account).attach(
    //   addressList[network.name].MockVeDEG
    // );

    // const totalSupply = await veDEG.totalSupply();
    // console.log(formatEther(totalSupply));
  });

task("closeProposal", "Close a proposal voting result")
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

    const tx = await onboardProposal.closeProposal(taskArgs.id);
    console.log("Tx details:", await tx.wait());
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

    const currentId = await onboardProposal.proposalCounter();
    console.log("Current proposal id:", currentId.toString());

    const proposal = await onboardProposal.proposals(taskArgs.id);
    console.log(proposal);
  });

task("setQuorumProposal", "Start a new report for a pool")
  .addParam("quorum", "Quorum ratio", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnboardProposal);

    const newQuorum = taskArgs.quorum;

    const tx = await onboardProposal.setQuorumRatio(newQuorum);

    console.log("tx details", await tx.wait());
  });
