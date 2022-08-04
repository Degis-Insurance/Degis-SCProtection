import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../scripts/contractAddress";

task("setDeg", "Set deg token address in a contract")
  .addParam("contract", "Contract to be set deg address", null, types.string)
  .setAction(async (taskArgs, hre) => {
    console.log("\n Setting Address... \n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const incidentReportAddress = addressList[network.name].IncidentReport;
  });
