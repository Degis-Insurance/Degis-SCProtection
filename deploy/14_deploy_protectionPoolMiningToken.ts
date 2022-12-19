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

  const name = "ProtectionPoolMiningToken";
  const symbol = "PMT";
  const protectionPoolAddress = addressList[network.name].ProtectionPool;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [name, symbol, protectionPoolAddress],
      },
    },
  };

  // Payout pool contract artifact
  const protectionPoolMiningToken = await deploy("ProtectionPoolMiningToken", {
    contract: "ProtectionPoolMiningToken",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].ProtectionPoolMiningToken =
    protectionPoolMiningToken.address;

  impList[network.name].ProtectionPoolMiningToken =
    protectionPoolMiningToken.implementation;

  console.log(
    "Protection pool mining token deployed to address: ",
    protectionPoolMiningToken.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
  storeImpList(impList);
};

func.tags = ["ProtectionPoolMiningToken"];
export default func;
