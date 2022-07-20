async function main() {
  // update the name here
  const Buffer = await ethers.getContractFactory("Buffer");

  // Start deployment, returning a promise that resolves to a contract object
  const buffer = await Buffer.deploy();

  console.log("Contract deployed to address:", buffer.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
