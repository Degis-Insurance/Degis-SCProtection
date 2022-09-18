import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";

import {
  getExternalTokenAddress,
  readAddressList,
  readImpList,
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
  const impList = readImpList();

  const [degAddress, veDegAddress, shieldAddress] = getExternalTokenAddress(
    network.name
  );

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [degAddress, veDegAddress, shieldAddress],
      },
    },
  };

  // Proxy Admin contract artifact
  const incidentReport = await deploy("IncidentReport", {
    contract: "IncidentReport",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].IncidentReport = incidentReport.address;

  impList[network.name].IncidentReport = incidentReport.implementation;

  console.log("\ndeployed to address: ", incidentReport.address);

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["IncidentReport"];
export default func;
