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

task("setQuorum", "Start a new report for a pool").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const newQuorum = 0;

    const tx = await incidentReport.setQuorumRatio(newQuorum);

    console.log("tx details", await tx.wait());
  }
);

task("setReported", "Start a new report for a pool").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const tx = await incidentReport.setReported(1);

    console.log("tx details", await tx.wait());
  }
);

task("voteReport", "Start a new report for a pool")
  .addParam("id", "Pool id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const tx = await incidentReport.vote(1, 2, parseUnits("4000000", 18));

    console.log("tx details", await tx.wait());
  });

task("startReportVoting", "Start voting process of a report")
  .addParam("id", "Report id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const tx = await incidentReport.startVoting(taskArgs.id);
    console.log("Tx details:", await tx.wait());
  });

task("settleReport", "Settle a report voting")
  .addParam("id", "Report id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const tx = await incidentReport.settle(taskArgs.id);
    console.log("Tx details:", await tx.wait());

    const p = await incidentReport.reports(taskArgs.id);
    console.log(p.result.toString());
  });

task("closeReport", "Close a report voting")
  .addParam("id", "Report id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const tx = await incidentReport.closeReport(taskArgs.id);
    console.log("Tx details:", await tx.wait());

    const p = await incidentReport.reports(1);
    console.log(p.status.toString());
  });

task("getReportInfo", "Get a report info")
  .addParam("id", "Report id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const reportInfo = await incidentReport.reports(taskArgs.id);
    console.log("Report status: ", reportInfo.status.toString());
    console.log("Report vote timestamp: ", reportInfo.voteTimestamp.toString());
    console.log("Pool id: ", reportInfo.poolId.toString());
    console.log("reporter: ", reportInfo.reporter.toString());

    const votingTime = await incidentReport.INCIDENT_VOTING_PERIOD();
    console.log("Voting time: ", votingTime.toString());

    const report = await incidentReport.getReport(1);
    console.log(report);
  });

task("unpausePools", "Unpause pools for a report")
  .addParam("id", "Report id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    const tx = await incidentReport.unpausePools(taskArgs.id);
    console.log("Tx details:", await tx.wait());

    const p = await incidentReport.reports(1);
    console.log(p.status.toString());
  });

task("reported", "Check reported").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const incidentReport: IncidentReport = new IncidentReport__factory(
    dev_account
  ).attach(addressList[network.name].IncidentReport);

  const reported = await incidentReport.reported(1);
  console.log("reported:", reported);
});
