// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract Web3RSVP {
    struct CreateEvent {
        bytes32 eventId;
        string evetnDataCID;
        address eventOwner;
        uint256 eventTimestamp;
        uint256 deposit;
        uint256 maxCapacity;
        address[] confirmedRSVPs;
        address[] claimedRSVPs;
        bool paidOut;
    }

    mapping(bytes32 => CreateEvent) public idToEvent;

    event NewEventCreated(
        bytes32 eventId,
        address creatorAddress,
        uint256 eventTimestamp,
        uint256 maxCapacity,
        uint256 deposit,
        string eventDataCID
    );
    event NewRSVP(
        bytes32 eventId,
        address attendeeAddress,
        uint8 claimedRsvpLength
    );
    event ConfirmedAttendee(bytes32 eventId, address attendeeAddress);
    event DepositsPaidOut(bytes32 eventId);

    function createNewEvent(
        uint256 eventTimestamp,
        uint256 deposit,
        uint256 maxCapacity,
        string calldata eventDataCID
    ) external {
        bytes32 eventId = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                eventTimestamp,
                deposit,
                maxCapacity
            )
        );

        require(idToEvent[eventId].eventTimestamp == 0, "Already Registered");

        address[] memory confirmedRSVPs;
        address[] memory claimedRSVPs;

        idToEvent[eventId] = CreateEvent(
            eventId,
            eventDataCID,
            msg.sender,
            eventTimestamp,
            deposit,
            maxCapacity,
            confirmedRSVPs,
            claimedRSVPs,
            false
        );

        emit NewEventCreated(
            eventId,
            msg.sender,
            eventTimestamp,
            maxCapacity,
            deposit,
            eventDataCID
        );
    }

    function createNewRSVP(bytes32 eventId) external payable {
        CreateEvent storage myEvent = idToEvent[eventId];

        require(msg.value == myEvent.deposit, "NOT ENOUGH");

        require(block.timestamp <= myEvent.eventTimestamp, "Already Happened");

        require(
            myEvent.confirmedRSVPs.length < myEvent.maxCapacity,
            "This event has reached capacity"
        );

        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            require(
                myEvent.confirmedRSVPs[i] != msg.sender,
                "Already Confirmed"
            );
        }

        myEvent.confirmedRSVPs.push(payable(msg.sender));

        emit NewRSVP(eventId, msg.sender, uint8(myEvent.confirmedRSVPs.length));
    }

    function confirmAttendee(bytes32 eventId, address attendee) public {
        CreateEvent storage myEvent = idToEvent[eventId];

        require(msg.sender == myEvent.eventOwner, "Not Authorized");

        address rsvpConfirmed;
        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            if (myEvent.confirmedRSVPs[i] == attendee) {
                rsvpConfirmed = myEvent.confirmedRSVPs[i];
            }
        }

        require(rsvpConfirmed == attendee, "No RSVP to confirm");

        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            require(
                !(myEvent.confirmedRSVPs[i] == attendee),
                "Already Claimed"
            );
        }

        require(myEvent.paidOut == false, "Already paid");

        myEvent.claimedRSVPs.push(attendee);

        (bool sent, ) = attendee.call{value: myEvent.deposit}("");

        if (!sent) {
            myEvent.claimedRSVPs.pop();
        }

        require(sent, "Failed to sped Ether");
        emit ConfirmedAttendee(eventId, attendee);
    }

    function confirmAllAttendees(bytes32 eventId) external {
        CreateEvent memory myEvent = idToEvent[eventId];
        require(msg.sender == myEvent.eventOwner, "Not Authorized");

        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++) {
            confirmAttendee(eventId, myEvent.confirmedRSVPs[i]);
        }
    }

    function withdrawUnclaimedDeposits(bytes32 eventId) external {
        CreateEvent memory myEvent = idToEvent[eventId];

        require(!myEvent.paidOut, "Alread paid");

        require(
            block.timestamp >= myEvent.eventTimestamp + 7 days,
            "Too Early"
        );

        require(msg.sender == myEvent.eventOwner, "Must be event owner");

        uint256 unclaimed = myEvent.confirmedRSVPs.length -
            myEvent.claimedRSVPs.length;

        uint256 payout = unclaimed * myEvent.deposit;

        myEvent.paidOut = true;

        (bool sent, ) = msg.sender.call{value: payout}("");

        if (!sent) {
            myEvent.paidOut = false;
        }

        require(sent, "Failed to send Ether");
        emit DepositsPaidOut(eventId);
    }
}
