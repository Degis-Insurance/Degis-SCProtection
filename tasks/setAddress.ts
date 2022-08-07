import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../scripts/contractAddress";
import {
  Executor,
  Executor__factory,
  IncidentReport,
  IncidentReport__factory,
  InsurancePoolFactory,
  InsurancePoolFactory__factory,
  OnboardProposal,
  OnboardProposal__factory,
  PolicyCenter,
  PolicyCenter__factory,
  ReinsurancePool,
  ReinsurancePool__factory,
} from "../typechain-types";

task("setReinsurancePool", "Set contract address in reinsurancePool").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in reinsurance pool\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const insurancePoolFactoryAddress =
      addressList[network.name].InsurancePoolFactory;
    const incidentReportAddress = addressList[network.name].IncidentReport;
    const policyCenterAddress = addressList[network.name].PolicyCenter;

    const reinsurancePool: ReinsurancePool = new ReinsurancePool__factory(
      dev_account
    ).attach(addressList[network.name].ReinsurancePool);

    if ((await reinsurancePool.policyCenter()) != policyCenterAddress) {
      const tx_1 = await reinsurancePool.setPolicyCenter(policyCenterAddress);
      console.log("Tx details: ", await tx_1.wait());
    }

    if (
      (await reinsurancePool.insurancePoolFactory()) !=
      insurancePoolFactoryAddress
    ) {
      const tx_2 = await reinsurancePool.setInsurancePoolFactory(
        insurancePoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await reinsurancePool.incidentReport()) != incidentReportAddress) {
      const tx_3 = await reinsurancePool.setIncidentReport(
        incidentReportAddress
      );
      console.log("Tx details: ", await tx_3.wait());
    }

    console.log("\nFinish setting contract addresses in reinsurance pool\n");
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

  const insurancePoolFactory: InsurancePoolFactory =
    new InsurancePoolFactory__factory(dev_account).attach(
      addressList[network.name].InsurancePoolFactory
    );

  if ((await insurancePoolFactory.policyCenter()) != policyCenterAddress) {
    const tx_1 = await insurancePoolFactory.setPolicyCenter(
      policyCenterAddress
    );
    console.log("Tx details: ", await tx_1.wait());
  }

  if (
    (await insurancePoolFactory.reinsurancePool()) != reinsurancePoolAddress
  ) {
    const tx_2 = await insurancePoolFactory.setReinsurancePool(
      reinsurancePoolAddress
    );
    console.log("Tx details: ", await tx_2.wait());
  }

  if ((await insurancePoolFactory.executor()) != executorAddress) {
    const tx_3 = await insurancePoolFactory.setExecutor(executorAddress);
    console.log("Tx details: ", await tx_3.wait());
  }

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

    if ((await incidentReport.policyCenter()) != policyCenterAddress) {
      const tx_1 = await incidentReport.setPolicyCenter(policyCenterAddress);
      console.log("Tx details: ", await tx_1.wait());
    }

    if ((await incidentReport.reinsurancePool()) != reinsurancePoolAddress) {
      const tx_2 = await incidentReport.setReinsurancePool(
        reinsurancePoolAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if (
      (await incidentReport.insurancePoolFactory()) !=
      insurancePoolFactoryAddress
    ) {
      const tx_3 = await incidentReport.setInsurancePoolFactory(
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

    if ((await onboardProposal.executor()) != executorAddress) {
      const tx_1 = await onboardProposal.setExecutor(executorAddress);
      console.log("Tx details: ", await tx_1.wait());
    }

    if (
      (await onboardProposal.insurancePoolFactory()) !=
      insurancePoolFactoryAddress
    ) {
      const tx_2 = await onboardProposal.setInsurancePoolFactory(
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
    const insurancePoolFactoryAddress =
      addressList[network.name].InsurancePoolFactory;
    const reinsurancePoolAddress = addressList[network.name].ReinsurancePool;
    const exchangeAddress = addressList[network.name].MockExchange;

    const policyCenter: PolicyCenter = new PolicyCenter__factory(
      dev_account
    ).attach(addressList[network.name].PolicyCenter);

    if ((await policyCenter.executor()) != executorAddress) {
      const tx_1 = await policyCenter.setExecutor(executorAddress);
      console.log("Tx details: ", await tx_1.wait());
    }

    if (
      (await policyCenter.insurancePoolFactory()) != insurancePoolFactoryAddress
    ) {
      const tx_2 = await policyCenter.setInsurancePoolFactory(
        insurancePoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await policyCenter.reinsurancePool()) != reinsurancePoolAddress) {
      const tx_3 = await policyCenter.setReinsurancePool(
        reinsurancePoolAddress
      );
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
    const insurancePoolFactoryAddress =
      addressList[network.name].InsurancePoolFactory;
    const reinsurancePoolAddress = addressList[network.name].ReinsurancePool;
    const incidentReportAddress = addressList[network.name].IncidentReport;
    const onboardProposalAddress = addressList[network.name].OnboardProposal;

    const executor: Executor = new Executor__factory(dev_account).attach(
      addressList[network.name].Executor
    );

    if ((await executor.policyCenter()) != policyCenterAddress) {
      const tx_1 = await executor.setPolicyCenter(policyCenterAddress);
      console.log("Tx details: ", await tx_1.wait());
    }

    if (
      (await executor.insurancePoolFactory()) != insurancePoolFactoryAddress
    ) {
      const tx_2 = await executor.setInsurancePoolFactory(
        insurancePoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await executor.reinsurancePool()) != reinsurancePoolAddress) {
      const tx_3 = await executor.setReinsurancePool(reinsurancePoolAddress);
      console.log("Tx details: ", await tx_3.wait());
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
