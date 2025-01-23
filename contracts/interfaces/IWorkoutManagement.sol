// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IWorkoutManagement {
    struct WorkoutEvent {
        address instructor;
        uint256 participationFee;
        uint256 instructorFee;
        bool instructorFeeClaimed;
        uint256 rewardPool;
        uint256 eventStartTime;
        uint256 eventEndTime;
        uint256 participants;
        uint256 claimedReward;
        mapping(address => bool) hasParticipated;
        mapping(address => bool) hasClaimed;
    }

    event EventCreated(
        uint256 eventId,
        address indexed instructor,
        uint256 eventEndTime
    );
    event UserParticipated(
        uint256 eventId,
        address indexed user,
        uint256 participationFee
    );
    event InstructorFeesClaimed(
        uint256 eventId,
        address indexed recipient,
        uint256 feeAmount
    );
    event TopParticipantsClaimed(
        uint256 eventId,
        address indexed recipient,
        uint256 reward
    );
    event EventCreationFeeUpdated(uint256 newFee);
    event RewardRateUpdated(uint256 newInstructorRate, uint256 newBurningRate);
    event EmergencyWithdraw(
        address indexed admin,
        uint256 amount,
        address indexed recipient
    );

    error InvalidFee(uint256 _fee);
    error EventDoesNotExist(uint256 eventId);
    error ZeroAddress();
    error ZeroAmount();
    error InvalidParticipationFee();
    error InvalidEventStartTime(uint256 provided, uint256 current);
    error InvalidEventEndTime(uint256 provided, uint256 current);
    error EventNotStart(uint256 provided, uint256 current);
    error EventHasEnded(uint256 provided, uint256 current);
    error EventNotCompleted(uint256 provided, uint256 current);
    error InvalidRewardRate(uint256 instructorRate, uint256 burningRate);
    error AlreadyParticipated(address user);
    error InvalidCalculation();
    error InsufficientBalance(uint256 requested, uint256 available);
    error NotEventInstructor(address user, address instructor);
    error FeesAlreadyClaimed(uint256 eventId, address user);
    error RewardAlreadyClaimed(uint256 eventId, address user);
    error InsufficientReward(uint256 participantReward, uint256 rewardPool);

}
