const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Redeploying Agent Sentinel v1.1.0 (Security Hardened)");
  console.log("Deployer:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Balance:", hre.ethers.formatEther(balance), "XRP\n");

  // 1. Deploy Registry
  console.log("1. Deploying SentinelRegistry v1.1.0...");
  const Registry = await hre.ethers.getContractFactory("SentinelRegistry");
  const registry = await Registry.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("   Registry:", registryAddress);

  // 2. Deploy Requests
  console.log("\n2. Deploying SentinelRequests v1.1.0 (with Pausable)...");
  const Requests = await hre.ethers.getContractFactory("SentinelRequests");
  const requests = await Requests.deploy(registryAddress);
  await requests.waitForDeployment();
  const requestsAddress = await requests.getAddress();
  console.log("   Requests:", requestsAddress);

  console.log("\n" + "=".repeat(60));
  console.log("Agent Sentinel v1.1.0 Deployment Complete!");
  console.log("=".repeat(60));
  console.log("SentinelRegistry: ", registryAddress);
  console.log("SentinelRequests: ", requestsAddress);
  console.log("Auditor:          ", deployer.address);
  console.log("=".repeat(60));
  console.log("\nSecurity Features:");
  console.log("  ✓ Registry: 60s cooldown, issue count validation, disclaimer");
  console.log("  ✓ Requests: Pausable, renounceOwnership disabled");
  console.log("=".repeat(60));

  // Grant free audits to Xavi contracts
  console.log("\n3. Granting free audits to Xavi contracts...");
  const xaviContracts = [
    "0xe5dBb1aE26662f93A932768EaD38588d6537Ea37", // TipJar
    "0x05c3Bd69f5Af459f06146032a78fa4B9C95eDEA0", // BountyBoard
    "0xb7527F782000c80EB0c142d87A07543f0CA24515", // PredictionMarket
    "0xe3C0F448a7D36126B782928fAed0C34175d30358", // RWA Launchpad
    "0x7A44A9eE0D6C6BBf25A16c7DcFf424e8476731C2", // CrossLedger
    "0xa20C5Baf735E7585A1294a43b487E33f40B84414", // Marketplace
    "0x6f5A3603b280bEb7b4abc64B896bc6CBB8Cf9F5D", // WXRP v1.1
    "0x69a4E06dC4C08C1b6eE2A007cC66CD44c1e55e2b", // Factory v1.1
    "0xeC06f93aFDc410D49145a06d9c1B7b064eDB76F3", // Router v1.1
  ];
  
  for (const addr of xaviContracts) {
    try {
      const tx = await requests.grantFreeAudit(addr);
      await tx.wait();
      console.log("   Granted:", addr.slice(0, 10) + "...");
    } catch (e) {
      console.log("   Failed:", addr.slice(0, 10) + "...", e.message);
    }
  }

  const finalBalance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("\nGas used:", hre.ethers.formatEther(balance - finalBalance), "XRP");
  console.log("Remaining:", hre.ethers.formatEther(finalBalance), "XRP");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
