import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";

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

  const [degAddress, veDegAddress] = getExternalTokenAddress(
    network.name
  );

  const protectionPoolAddress = addressList[network.name].ProtectionPool;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [
          degAddress,
          veDegAddress,
          protectionPoolAddress
        ],
      },
    },
  };

  // PolicyCenter contract artifact
  const policyCenter = await deploy("PolicyCenter", {
    contract: "PolicyCenter",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].PolicyCenter = policyCenter.address;

  impList[network.name].PolicyCenter = policyCenter.implementation;

  console.log("\npolicy center deployed to address: ", policyCenter.address);

  // Store the address list after deployment
  storeAddressList(addressList);
  storeImpList(impList);
};

func.tags = ["PolicyCenter"];
export default func;
