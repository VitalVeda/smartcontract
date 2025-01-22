// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IWorkoutManagement {
    struct WorkoutEvent {
        address instructor;
        uint256 participationFee;
        uint256 instructorFee;
        uint256 rewardPool;
        uint256 eventStartTime;
        uint256 eventEndTime;
        uint256 participants;
    }

    error InvalidFee(uint256 _fee);
    error EventDoesNotExist(uint256 eventId);
    error ZeroAddress();
    error InvalidParticipationFee();
    error InvalidEventStartTime(uint256 provided, uint256 current);
    error InvalidEventEndTime(uint256 provided, uint256 current);
    error EventNotStart(uint256 provided, uint256 current);
    error EventHasEnded(uint256 provided, uint256 current);
    error InvalidRewardRate(uint256 instructorRate, uint256 burningRate);
    error AlreadyParticipated(address user);
    error InvalidCalculation();
}
