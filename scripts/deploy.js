async function main() {
  // update the name here
  const Factory = await ethers.getContractFactory("Factory");

  // Start deployment, returning a promise that resolves to a contract object
  const factory = await Factory.deploy();

  console.log("Contract deployed to address:", factory.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
