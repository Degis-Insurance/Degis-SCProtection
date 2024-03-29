import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";

import {
  readAddressList,
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
  const impList = readAddressList();

  const policyCenterAddress = addressList[network.name].PolicyCenter;
  const factoryAddress = addressList[network.name].PriorityPoolFactory;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [policyCenterAddress, factoryAddress],
      },
    },
  };

  // WeightedFarmingPool contract artifact
  const weightedFarmingPool = await deploy("WeightedFarmingPool", {
    contract: "WeightedFarmingPool",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].WeightedFarmingPool = weightedFarmingPool.address;

  impList[network.name].WeightedFarmingPool =
    weightedFarmingPool.implementation;

  console.log(
    "WeightedFarmingPool deployed to address: ",
    weightedFarmingPool.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
  storeImpList(impList);
};

func.tags = ["WeightedFarmingPool"];
export default func;
