import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../../scripts/contractAddress";
import {
  IncidentReport,
  IncidentReport__factory,
  OnboardProposal,
  OnboardProposal__factory,
} from "../../typechain-types";
import { parseUnits } from "ethers/lib/utils";

task("newReport", "Start a new report for a pool")
  .addParam("id", "Pool id", null, types.string)
  .addParam("payout", "Payout amount", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const tx = await incidentReport.report(taskArgs.id, taskArgs.payout);

    console.log("tx details", await tx.wait());
  });

task("startVoting", "Start voting process of a proposal")
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
