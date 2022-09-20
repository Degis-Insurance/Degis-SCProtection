import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";

import {
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

  const priorityPoolFactoryAddress =
    addressList[network.name].PriorityPoolFactory;
  const weightedFarmingPoolAddress =
    addressList[network.name].WeightedFarmingPool;
  const protectionPoolAddress = addressList[network.name].ProtectionPool;
  const policyCenterAddress = addressList[network.name].PolicyCenter;
  const payoutPoolAddress = addressList[network.name].PayoutPool;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [
          priorityPoolFactoryAddress,
          weightedFarmingPoolAddress,
          protectionPoolAddress,
          policyCenterAddress,
          payoutPoolAddress,
        ],
      },
    },
  };

  // Payout pool contract artifact
  const priorityPoolDeployer = await deploy("PriorityPoolDeployer", {
    contract: "PriorityPoolDeployer",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].PriorityPoolDeployer = priorityPoolDeployer.address;

  impList[network.name].PriorityPoolDeployer =
    priorityPoolDeployer.implementation;

  console.log(
    "Payout pool deployer deployed to address: ",
    priorityPoolDeployer.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["PriorityPoolDeployer"];
export default func;
