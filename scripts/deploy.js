const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying Agent Sentinel with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(balance), "XRP\n");

  // 1. Deploy SentinelRegistry
  console.log("1. Deploying SentinelRegistry...");
  const SentinelRegistry = await hre.ethers.getContractFactory("SentinelRegistry");
  const registry = await SentinelRegistry.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("   SentinelRegistry deployed to:", registryAddress);

  // 2. Deploy SentinelRequests
  console.log("\n2. Deploying SentinelRequests...");
  const SentinelRequests = await hre.ethers.getContractFactory("SentinelRequests");
  const requests = await SentinelRequests.deploy(registryAddress);
  await requests.waitForDeployment();
  const requestsAddress = await requests.getAddress();
  console.log("   SentinelRequests deployed to:", requestsAddress);

  console.log("\n========================================");
  console.log("Agent Sentinel Deployment Complete!");
  console.log("========================================");
  console.log("SentinelRegistry:  ", registryAddress);
  console.log("SentinelRequests:  ", requestsAddress);
  console.log("Auditor (Sentinel):", deployer.address);
  console.log("Min Audit Fee:      5 XRP");
  console.log("========================================\n");

  // Check remaining balance
  const finalBalance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Gas used:", hre.ethers.formatEther(balance - finalBalance), "XRP");
  console.log("Remaining balance:", hre.ethers.formatEther(finalBalance), "XRP");

  // Grant free audits to Xavi's contracts
  console.log("\n3. Granting free audit eligibility to Xavi contracts...");
  const xaviContracts = [
    "0xe5dBb1aE26662f93A932768EaD38588d6537Ea37", // TipJar
    "0x05c3Bd69f5Af459f06146032a78fa4B9C95eDEA0", // BountyBoard
    "0xb7527F782000c80EB0c142d87A07543f0CA24515", // PredictionMarket
    "0xe3C0F448a7D36126B782928fAed0C34175d30358", // RWA Launchpad
    "0x7A44A9eE0D6C6BBf25A16c7DcFf424e8476731C2", // CrossLedger
    "0xa20C5Baf735E7585A1294a43b487E33f40B84414", // Marketplace
    "0x6F177EC261E7ebd58C488a8a807eb50190c00c9d", // WXRP
    "0x648Bd4cD5E2799BdbDF6494a8fb05C1169A75BA2", // XaviFactory
    "0xf3829D62B24Ed8f43d1a4F25f5c14b3f41D794E8", // XaviRouter
  ];
  
  for (const addr of xaviContracts) {
    try {
      const tx = await requests.grantFreeAudit(addr);
      await tx.wait();
      console.log("   Granted free audit:", addr.slice(0, 10) + "...");
    } catch (e) {
      console.log("   Failed to grant:", addr.slice(0, 10) + "...", e.message);
    }
  }
  
  console.log("\nAll Xavi contracts eligible for free audits!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
