import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../scripts/contractAddress";
import {
  Executor,
  Executor__factory,
  IncidentReport,
  IncidentReport__factory,
  PriorityPoolFactory,
  PriorityPoolFactory__factory,
  MockDEG,
  MockDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
  PolicyCenter,
  PolicyCenter__factory,
  ProtectionPool,
  ProtectionPool__factory,
} from "../typechain-types";
import { parseUnits } from "ethers/lib/utils";

task("setAllAddress", "Set all addresses");

task("setProtectionPool", "Set contract address in protectionPool").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in reinsurance pool\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    // Addresses to be set
    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;
    const incidentReportAddress = addressList[network.name].IncidentReport;
    const policyCenterAddress = addressList[network.name].PolicyCenter;
  

    const protectionPool: ProtectionPool = new ProtectionPool__factory(
      dev_account
    ).attach(addressList[network.name].ProtectionPool);

    if ((await protectionPool.policyCenter()) != policyCenterAddress) {
      const tx_1 = await protectionPool.setPolicyCenter(policyCenterAddress);
      console.log("Tx details: ", await tx_1.wait());
    }

    if (
      (await protectionPool.priorityPoolFactory()) != priorityPoolFactoryAddress
    ) {
      const tx_2 = await protectionPool.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await protectionPool.incidentReport()) != incidentReportAddress) {
      const tx_3 = await protectionPool.setIncidentReport(
        incidentReportAddress
      );
      console.log("Tx details: ", await tx_3.wait());
    }

    console.log("\nFinish setting contract addresses in protection pool\n");
  }
);

task(
  "setInsurancePoolFactory",
  "Set contract address in insurancePoolFactory"
).setAction(async (_, hre) => {
  console.log("\nSetting contract addresses in insurancePoolFactory\n");

  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const reinsurancePoolAddress = addressList[network.name].ReinsurancePool;
  const executorAddress = addressList[network.name].Executor;
  const policyCenterAddress = addressList[network.name].PolicyCenter;

  const priorityPoolFactory: PriorityPoolFactory =
    new PriorityPoolFactory__factory(dev_account).attach(
      addressList[network.name].PriorityPoolFactory
    );

  // if ((await priorityPoolFactory.policyCenter()) != policyCenterAddress) {
  //   const tx_1 = await priorityPoolFactory.setPolicyCenter(
  //     policyCenterAddress
  //   );
  //   console.log("Tx details: ", await tx_1.wait());
  // }

  // if ((await priorityPoolFactory.protectionPool()) != reinsurancePoolAddress) {
  //   const tx_2 = await priorityPoolFactory.setProtectionPool(
  //     reinsurancePoolAddress
  //   );
  //   console.log("Tx details: ", await tx_2.wait());
  // }

  // if ((await insurancePoolFactory.executor()) != executorAddress) {
  //   const tx_3 = await insurancePoolFactory.setExecutor(executorAddress);
  //   console.log("Tx details: ", await tx_3.wait());
  // }

  console.log(
    "\nFinish setting contract addresses in insurance pool factory\n"
  );
});

task("setIncidentReport", "Set contract address in incident report").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in incident report\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const reinsurancePoolAddress = addressList[network.name].ReinsurancePool;
    const insurancePoolFactoryAddress =
      addressList[network.name].InsurancePoolFactory;
    const policyCenterAddress = addressList[network.name].PolicyCenter;

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    if (
      (await incidentReport.priorityPoolFactory()) !=
      insurancePoolFactoryAddress
    ) {
      const tx_3 = await incidentReport.setPriorityPoolFactory(
        insurancePoolFactoryAddress
      );
      console.log("Tx details: ", await tx_3.wait());
    }

    console.log("\nFinish setting contract addresses in incident report\n");
  }
);

task("setOnboardProposal", "Set contract address in onboardProposal").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in onbardproposal\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const executorAddress = addressList[network.name].Executor;
    const insurancePoolFactoryAddress =
      addressList[network.name].InsurancePoolFactory;

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnboardProposal);

    if (
      (await onboardProposal.priorityPoolFactory()) !=
      insurancePoolFactoryAddress
    ) {
      const tx_2 = await onboardProposal.setPriorityPoolFactory(
        insurancePoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    console.log("\nFinish setting contract addresses in onboard proposal\n");
  }
);

task("setPolicyCenter", "Set contract address in policyCenter").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in onbardproposal\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const executorAddress = addressList[network.name].Executor;
    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;
    const protectionPoolAddress = addressList[network.name].ProtectionPool;
    const exchangeAddress = addressList[network.name].MockExchange;

    const policyCenter: PolicyCenter = new PolicyCenter__factory(
      dev_account
    ).attach(addressList[network.name].PolicyCenter);

    if (
      (await policyCenter.priorityPoolFactory()) != priorityPoolFactoryAddress
    ) {
      const tx_2 = await policyCenter.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await policyCenter.protectionPool()) != protectionPoolAddress) {
      const tx_3 = await policyCenter.setProtectionPool(protectionPoolAddress);
      console.log("Tx details: ", await tx_3.wait());
    }

    if ((await policyCenter.exchange()) != exchangeAddress) {
      const tx_4 = await policyCenter.setExchange(exchangeAddress);
      console.log("Tx details: ", await tx_4.wait());
    }

    console.log("\nFinish setting contract addresses in policy center\n");
  }
);

task("setExecutor", "Set contract address in executor").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in executor\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const policyCenterAddress = addressList[network.name].PolicyCenter;
    const priorityPoolFactoryAddress =
      addressList[network.name].priorityPoolFactory;
    const protectionPoolAddress = addressList[network.name].ProtectionPool;
    const incidentReportAddress = addressList[network.name].IncidentReport;
    const onboardProposalAddress = addressList[network.name].OnboardProposal;

    const executor: Executor = new Executor__factory(dev_account).attach(
      addressList[network.name].Executor
    );

    if ((await executor.priorityPoolFactory()) != priorityPoolFactoryAddress) {
      const tx_2 = await executor.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await executor.incidentReport()) != incidentReportAddress) {
      const tx_4 = await executor.setIncidentReport(incidentReportAddress);
      console.log("Tx details: ", await tx_4.wait());
    }

    if ((await executor.onboardProposal()) != onboardProposalAddress) {
      const tx_5 = await executor.setOnboardProposal(onboardProposalAddress);
      console.log("Tx details: ", await tx_5.wait());
    }

    console.log("\nFinish setting contract addresses in executor\n");
  }
);

task("mintToken").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const deg: MockDEG = new MockDEG__factory(dev_account).attach(
    addressList[network.name].MockDEG
  );

  const tx = await deg.mintDegis(dev_account.address, parseUnits("1000"));
  console.log("tx details", await tx.wait());
});
