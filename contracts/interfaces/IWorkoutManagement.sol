// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IWorkoutManagement {
    /**
     * @dev Represents a workout event
     * Contains all details related to the event, such as instructor, fees, rewards, participation, and claims
     */
    struct WorkoutEvent {
        address instructor; // Address of the instructor organizing the event
        uint256 participationFee; // Fee required to participate in the event
        uint256 instructorFee; // Fee to be paid to the instructor
        bool instructorFeeClaimed; // Flag to indicate if the instructor's fee has been claimed
        uint256 rewardPool; // Total reward pool for the event participants
        uint256 eventStartTime; // Start time of the event (timestamp)
        uint256 eventEndTime; // End time of the event (timestamp)
        uint256 participants; // Total number of participants in the event
        uint256 claimedReward; // Total rewards that have been claimed by participants
        mapping(address participant => bool isParticipated) hasParticipated; // Mapping to track if a user has participated in the event
        mapping(address instructor => bool isClaimed) hasClaimed; // Mapping to track if instructor has claimed their reward
    }

    // Event emitted when a new workout event is created
    event EventCreated(
        uint256 eventId,
        address indexed instructor,
        uint256 eventEndTime
    );
    // Event emitted when a user participates in a workout event
    event UserParticipated(
        uint256 eventId,
        address indexed user,
        uint256 participationFee
    );
    // Event emitted when the instructor claims their fees from an event
    event InstructorFeesClaimed(
        uint256 eventId,
        address indexed recipient,
        uint256 feeAmount
    );
    // Event emitted when top participants claim their rewards
    event TopParticipantsClaimed(
        uint256 eventId,
        address indexed recipient,
        uint256 reward
    );
    // Event emitted when the event creation fee is updated
    event EventCreationFeeUpdated(uint256 newFee);
    // Event emitted when the reward rate (instructor and burning rates) is updated
    event RewardRateUpdated(uint256 newInstructorRate, uint256 newBurningRate);
    // Event emitted for emergency withdrawal of funds by the admin
    event EmergencyWithdraw(
        address indexed admin,
        uint256 amount,
        address indexed recipient
    );

    // Error thrown when the fee is invalid
    error InvalidFee(uint256 _fee);
    // Error thrown when an event does not exist
    error EventDoesNotExist(uint256 eventId);
    // Error thrown when a zero address is encountered
    error ZeroAddress();
    // Error thrown when a value is zero
    error ZeroAmount();
    // Error thrown when an invalid participation fee is provided
    error InvalidParticipationFee();
    // Error thrown when an invalid event start time is provided
    error InvalidEventStartTime(uint256 provided, uint256 current);
    // Error thrown when an invalid event end time is provided
    error InvalidEventEndTime(uint256 provided, uint256 current);
    // Error thrown when an event has not started yet
    error EventNotStart(uint256 provided, uint256 current);
    // Error thrown when an event has already ended
    error EventHasEnded(uint256 provided, uint256 current);
    // Error thrown when an event has not been completed yet
    error EventNotCompleted(uint256 provided, uint256 current);
    // Error thrown when an invalid reward rate (instructor or burning rate) is provided
    error InvalidRewardRate(uint256 instructorRate, uint256 burningRate);
    // Error thrown when a user has already participated in an event
    error AlreadyParticipated(address user);
    // Error thrown when a calculation fails or produces invalid results
    error InvalidCalculation();
    // Error thrown when a user requests more funds than are available
    error InsufficientBalance(uint256 requested, uint256 available);
    // Error thrown when a user who is not the event instructor tries to perform actions
    error NotEventInstructor(address user, address instructor);
    // Error thrown when the instructor re-claimed their fees
    error FeesAlreadyClaimed(uint256 eventId, address user);
    // Error thrown when participant try to claim the reward that has already been claimed
    error RewardAlreadyClaimed(uint256 eventId, address user);
    // Error thrown when the reward pool is insufficient to cover a participant's reward
    error InsufficientReward(uint256 participantReward, uint256 rewardPool);
    // Error thrown when the provided salt value has already been used
    error SaltAlreadyUsed(uint256 salt);
}
