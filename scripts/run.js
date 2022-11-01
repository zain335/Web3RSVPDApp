const hht = require("hardhat");

const main = async () => {
  const rsvpContractFactory = await hht.ethers.getContractFactory("Web3RSVP");
  const rsvpContract = await rsvpContractFactory.deploy();
  await rsvpContract.deployed();
  console.log("Contract deployed to: ", rsvpContract.address);
  const [deployer, address1, address2] = await hht.ethers.getSigners();

  let deposit = hht.ethers.utils.parseEther("1");
  let maxCapacity = 3;
  let timestamp = Date.now();
  let evetnDataCID = "QmUWL4UxSegj2i9ggqZSykjB1qYEgy4Ms2FKvfUe8egHcf";

  let txn = await rsvpContract.createNewEvent(
    timestamp,
    deposit,
    maxCapacity,
    evetnDataCID
  );

  let wait = await txn.wait();
  console.log("New Event Created: ", wait.events[0].event, wait.events[0].args);

  let eventId = wait.events[0].args.eventId;
  console.log("Event Id: ", eventId);

  txn = await rsvpContract.createNewRSVP(eventId, { value: deposit });
  wait = await txn.wait();

  console.log("New RSVP Created: ", wait.events[0].event, wait.events[0].args);

  txn = await rsvpContract
    .connect(address1)
    .createNewRSVP(eventId, { value: deposit });
  wait = await txn.wait();

  console.log(
    `New RSVP using address ${address1} is createrd: ${wait.events[0].event} ${wait.events[0].args}}`
  );

  txn = await rsvpContract
    .connect(address2)
    .createNewRSVP(eventId, { value: deposit });
  wait = await txn.wait();

  console.log(
    `New RSVP using address ${address2} is createrd: ${wait.events[0].event} ${wait.events[0].args}}`
  );

  txn = await rsvpContract.confirmAllAttendees(eventId);
  wait = await txn.wait();
  wait.events.foreach((event) =>
    console.log("Confirmed: ", event.args.attendeeAddress)
  );

  await hht.network.provider.send("evm_increaseTime", [15778800000000]);

  txn = await rsvpContract.withdrawUnclaimedDeposit(eventId);
  wait = await txn.wait();
  console.log("Withdrawn: ", wait.events[0].event, wait.events[0].args);
};
const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
};

runMain();
