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

  const [, , shieldAddress] = getExternalTokenAddress(network.name);
  const policyCenterAddress = addressList[network.name].PolicyCenter;
  const crTokenFactoryAddress =
    addressList[network.name].CoverRightTokenFactory;
  const priorityPoolFactoryAddress =
    addressList[network.name].PriorityPoolFactory;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [
          shieldAddress,
          policyCenterAddress,
          crTokenFactoryAddress,
          priorityPoolFactoryAddress,
        ],
      },
    },
  };

  // Payout pool contract artifact
  const payoutPool = await deploy("PayoutPool", {
    contract: "PayoutPool",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].PayoutPool = payoutPool.address;

  console.log("Payout pool deployed to address: ", payoutPool.address, "\n");

  impList[network.name].PayoutPool = payoutPool.implementation;

  // Store the address list after deployment
  storeAddressList(addressList);
  storeImpList(impList);
};

func.tags = ["PayoutPool"];
export default func;
