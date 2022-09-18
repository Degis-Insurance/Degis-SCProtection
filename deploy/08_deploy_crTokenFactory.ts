import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";

import {
  readAddressList,
  readImpList,
  storeAddressList,
  storeImpList,
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

  const policyCenterAddress = addressList[network.name].PolicyCenter;
  const incidentReportAddress = addressList[network.name].IncidentReport;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [policyCenterAddress, incidentReportAddress],
      },
    },
  };

  // CoverRightTokenFactory contract artifact
  const crTokenFactory = await deploy("CoverRightTokenFactory", {
    contract: "CoverRightTokenFactory",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].CoverRightTokenFactory = crTokenFactory.address;

  console.log(
    "\nCoverRightTokenFactory deployed to address: ",
    crTokenFactory.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
  storeImpList(impList);
};

func.tags = ["CoverRightTokenFactory"];
export default func;
