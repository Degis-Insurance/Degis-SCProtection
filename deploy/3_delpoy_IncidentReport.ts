import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import {
  getExternalTokenAddress,
  readAddressList,
  storeAddressList,
} from "../scripts/contractAddress";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  const { deployer } = await getNamedAccounts();

  console.log("\n-----------------------------------------------------------");
  console.log("-----  Network:  ", network.name);
  console.log("-----  Deployer: ", deployer);
  console.log("-----------------------------------------------------------\n");

  // Read address list from local file
  const addressList = readAddressList();

  let degAddress: string, veDegAddress: string, shieldAddress: string;

  [degAddress, veDegAddress, shieldAddress] = getExternalTokenAddress(
    network.name
  );

  // Proxy Admin contract artifact
  const incidentReport = await deploy("IncidentReport", {
    contract: "IncidentReport",
    from: deployer,
    args: [degAddress, veDegAddress, shieldAddress],
    log: true,
  });
  addressList[network.name].IncidentReport = incidentReport.address;

  console.log("\ndeployed to address: ", incidentReport.address);

  //   await hre.run("verify:verify", {
  //     address: insurancePoolFactory.address,
  //     constructorArguments: [],
  //   });

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["IncidentReport"];
export default func;
