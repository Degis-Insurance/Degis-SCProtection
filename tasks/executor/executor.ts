import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../../scripts/contractAddress";
import { Executor, Executor__factory } from "../../typechain-types";
import { parseUnits } from "ethers/lib/utils";

task("executeProposal", "Execute a proposal when it is passed")
  .addParam("id", "Propsoal id to be executed", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const executor: Executor = new Executor__factory(dev_account).attach(
      addressList[network.name].Executor
    );

    const tx = await executor.executeProposal(taskArgs.id);
    console.log("tx details", await tx.wait());
  });

task("executeReport")
  .addParam("id", "Report id to be executed", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const executor: Executor = new Executor__factory(dev_account).attach(
      addressList[network.name].Executor
    );

    const treasury = await executor.treasury();
    console.log("Treasury:", treasury);

    const incident = await executor.incidentReport();
    console.log("incident report", incident);

    const tx = await executor.executeReport(taskArgs.id);
    console.log("tx details", await tx.wait());

    const alreadyExecuted = await executor.reportExecuted(taskArgs.id);
    console.log(alreadyExecuted);
  });
