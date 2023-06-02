import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  DeployFunction,
  DeployResult,
  ProxyOptions,
} from "hardhat-deploy/types";

import {
  getExternalTokenAddress,
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

  const [degAddress, veDegAddress] = getExternalTokenAddress(network.name);

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [degAddress, veDegAddress],
      },
    },
  };

  // Deploy contract
  const protectionPool: DeployResult = await deploy("ProtectionPool", {
    contract: "ProtectionPool",
    from: deployer,
    proxy: proxyOptions,
    log: true,
    args: [],
  });

  addressList[network.name].ProtectionPool = protectionPool.address;
  impList[network.name].ProtectionPool = protectionPool.implementation;

  console.log(
    "Protection pool deployed to address: ",
    protectionPool.address,
    "\n"
  );

  console.log(
    "Protection pool implementation deployed to address: ",
    protectionPool.implementation,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
  storeImpList(impList);
};

func.tags = ["ProtectionPool"];
export default func;
