import { Interface, JsonRpcProvider } from "ethers";
import { abi as WorkoutManagementAbi } from "../../artifacts/contracts/WorkoutManagement.sol/WorkoutManagement.json";

async function estimateGasFromRawData() {
  const provider = new JsonRpcProvider("https://rpc.apothem.network");

  const iface = new Interface(WorkoutManagementAbi);

  try {
    const gasEstimate = await provider.estimateGas({
      from: "0x24c02645D3463ACCb81AFCeD2ba978BA1f76B00A",
      to: "0x4A7828a699D43A4071E896A519C98E7EBB5C71e6",
      data: "0x4e86049600000000000000000000000000000000000000000000000000000000000000fd",
    });

    console.log(`Estimated Gas: ${gasEstimate.toString()}`);
  } catch (error: any) {
    if (error.data) {
      try {
        // Decode the revert error
        const decodedError = iface.parseError(error.data);
        console.log("Custom Error:", decodedError?.name);
        console.log("Arguments:", decodedError?.args);
      } catch (decodeError) {
        console.error("Failed to decode error:", decodeError);
      }
    } else {
      console.error("Transaction failed:", error);
    }
  }
}

estimateGasFromRawData()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
