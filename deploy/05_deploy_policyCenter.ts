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

  const protectionPoolAddress = addressList[network.name].ProtectionPool;
  const USDCAddress =
    network.name == "fuji" || network.name == "fujiInternal"
      ? addressList[network.name].MockUSDC
      : addressList[network.name].USDC;

  // PolicyCenter contract artifact
  const policyCenter = await deploy("PolicyCenter", {
    contract: "PolicyCenter",
    from: deployer,
    args: [
      degAddress,
      veDegAddress,
      shieldAddress,
      protectionPoolAddress,
      USDCAddress,
    ],
    log: true,
  });
  addressList[network.name].PolicyCenter = policyCenter.address;

  console.log("\npolicy center deployed to address: ", policyCenter.address);

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["PolicyCenter"];
export default func;
