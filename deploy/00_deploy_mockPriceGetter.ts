import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { readAddressList, storeAddressList } from "../scripts/contractAddress";

/**
 *
 * @notice Mock Price Getter is used in local and fuji test
 *         It will return any token's price as 1e18
 *
 */

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  if (network.name == "avax") {
    console.log("You are deploying mock tokens on mainnet!!!");
    return;
  }

  const { deployer } = await getNamedAccounts();

  console.log("\n-----------------------------------------------------------");
  console.log("-----  Network:  ", network.name);
  console.log("-----  Deployer: ", deployer);
  console.log("-----------------------------------------------------------\n");

  // Read address list from local file
  const addressList = readAddressList();

  // MockPriceGetter contract artifact
  const mockPriceGetter = await deploy("MockPriceGetter", {
    contract: "MockPriceGetter",
    from: deployer,
    args: [],
    log: true,
  });
  addressList[network.name].MockPriceGetter = mockPriceGetter.address;

  console.log(
    "\nmock price getter deployed to address: ",
    mockPriceGetter.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["MockPriceGetter"];
export default func;
