import { AddressLike } from "ethers";
import fs from "fs";
import path from "path";

export function getContracts(network: string | number) {
  let json;
  try {
    const env = process.env.NODE_ENV;
    json = fs.readFileSync(
      path.join(
        __dirname,
        `../deployed-contracts/${env}.${network}.contract-addresses.json`
      )
    );
  } catch (err) {
    json = "{}";
  }
  const addresses = JSON.parse(json as string);
  return addresses;
}

export function saveContract(
  network: string | number,
  contract: string,
  address: AddressLike
) {
  const env = process.env.NODE_ENV;

  const addresses = getContracts(network);
  addresses[network] = addresses[network] || {};
  addresses[network][contract] = address;
  fs.writeFileSync(
    path.join(
      __dirname,
      `../deployed-contracts/${env}.${network}.contract-addresses.json`
    ),
    JSON.stringify(addresses, null, "    ")
  );
}
