// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IWorkoutManagement.sol";
import "./interfaces/IVVFIT.sol";

contract WorkoutManagement is
    Pausable,
    AccessControl,
    ReentrancyGuard,
    IWorkoutManagement
{
    using SafeERC20 for IVVFIT;

    string public constant CONTRACT_NAME = "Workout Management";
    string public constant CONTRACT_VERSION = "1.0.0";
    // Divider used to calculate percent for fee distribution
    uint256 public constant RATE_DIVIDER = 100_000;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant INSTRUCTOR_ROLE = keccak256("INSTRUCTOR_ROLE");

    uint256 eventCreationFee;
    uint256 instructorRate;
    uint256 burningRate;

    address public workoutTreasury;
    IVVFIT public vvfitToken; // VVFIT token contract interface

    uint256 public eventCount;
    mapping(uint256 => WorkoutEvent) public events;
    mapping(uint256 => mapping(address => bool)) public userParticipated; // User participation status

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
    event EventCompleted(uint256 eventId);
    event EventCreationFeeUpdated(uint256 newFee);
    event RewardRateUpdated(uint256 newInstructorRate, uint256 newBurningRate);
    event EmergencyWithdraw(
        address indexed admin,
        uint256 amount,
        address indexed recipient
    );

    constructor(
        address _vvfitAddress,
        address _workoutTreasury,
        uint256 _eventCreationFee
    ) {
        if (_vvfitAddress == address(0)) {
            revert ZeroAddress();
        }
        vvfitToken = IVVFIT(_vvfitAddress);
        workoutTreasury = _workoutTreasury;
        eventCreationFee = _eventCreationFee;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier eventExists(uint256 _eventId) {
        if (_eventId >= eventCount) {
            revert EventDoesNotExist(_eventId);
        }
        _;
    }

    /// @notice Emergency pause
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpause
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function grantOperatorRole(
        address _instructor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_instructor == address(0)) {
            revert ZeroAddress();
        }
        grantRole(OPERATOR_ROLE, _instructor);
    }

    function grantInstructorRole(
        address _instructor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_instructor == address(0)) {
            revert ZeroAddress();
        }
        grantRole(INSTRUCTOR_ROLE, _instructor);
    }

    function createEvent(
        uint256 _participationFee,
        uint256 _eventStartTime,
        uint256 _eventEndTime
    ) external onlyRole(INSTRUCTOR_ROLE) whenNotPaused nonReentrant {
        if (_participationFee == 0) {
            revert InvalidParticipationFee();
        }

        if (_eventEndTime <= block.timestamp) {
            revert InvalidEventEndTime(_eventEndTime, block.timestamp);
        }

        if (_eventEndTime <= _eventStartTime) {
            revert InvalidEventStartTime(_eventStartTime, _eventEndTime);
        }

        // Transfer the creation fee to the contract
        vvfitToken.transferFrom(msg.sender, workoutTreasury, eventCreationFee);
        uint256 eventId = eventCount;
        // Create the event
        WorkoutEvent storage newEvent = events[eventId];
        newEvent.instructor = msg.sender;
        newEvent.participationFee = _participationFee;
        newEvent.eventStartTime = _eventStartTime;
        newEvent.eventEndTime = _eventEndTime;
        eventCount++;

        emit EventCreated(eventId, msg.sender, _eventEndTime);
    }

    function participateInEvent(
        uint256 eventId
    ) external eventExists(eventId) whenNotPaused nonReentrant {
        WorkoutEvent storage workoutEvent = events[eventId];
        // Check event hasn't started
        if (block.timestamp < workoutEvent.eventStartTime) {
            revert EventNotStart(workoutEvent.eventStartTime, block.timestamp);
        }
        // Check event hasn't ended
        if (workoutEvent.eventEndTime < block.timestamp) {
            revert EventHasEnded(workoutEvent.eventEndTime, block.timestamp);
        }
        // Check if user already participated
        if (userParticipated[eventId][msg.sender]) {
            revert AlreadyParticipated(msg.sender);
        }

        uint256 feeAmount = workoutEvent.participationFee;
        // Calculate amounts
        uint256 burnAmount = (feeAmount * burningRate) / RATE_DIVIDER;
        uint256 instructorLoyalty = (feeAmount * instructorRate) / RATE_DIVIDER;
        uint256 rewardPoolAmount = feeAmount - burnAmount - instructorLoyalty;

        // Validate calculations
        if (rewardPoolAmount > feeAmount) {
            revert InvalidCalculation();
        }

        // Transfer the participation fee to the contract an distribute fees
        vvfitToken.transferFrom(msg.sender, address(this), feeAmount);

        vvfitToken.burn(burnAmount);

        vvfitToken.transfer(workoutEvent.instructor, instructorLoyalty);

        workoutEvent.rewardPool += rewardPoolAmount;

        // Add user to the participants list
        userParticipated[eventId][msg.sender] = true;
        workoutEvent.participants++;

        emit UserParticipated(
            eventId,
            msg.sender,
            workoutEvent.participationFee
        );
    }

    function instructorClaimFee(
        uint256 eventId
    ) external onlyRole(INSTRUCTOR_ROLE) whenNotPaused nonReentrant {}

    function topParticipantsClaimReward(
        uint256 eventId
    ) external whenNotPaused nonReentrant {}

    function setEventCreationFee(
        uint256 _newCreationFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        eventCreationFee = _newCreationFee;
        emit EventCreationFeeUpdated(_newCreationFee);
    }

    function setRewardRate(
        uint256 _instructorRate,
        uint256 _burningRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_instructorRate + _burningRate >= RATE_DIVIDER) {
            revert InvalidRewardRate(_instructorRate, _burningRate);
        }
        instructorRate = _instructorRate;
        burningRate = _burningRate;
        emit RewardRateUpdated(_instructorRate, _burningRate);
    }

    /**
     * @notice Allows an admin to withdraw tokens from the contract in case of an emergency.
     * @param amount The amount of tokens to withdraw.
     * @param recipient The address to receive the withdrawn tokens.
     */
    function emergencyWithdraw(
        uint256 amount,
        address recipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, "Withdraw amount must be greater than zero");
        if (recipient == address(0)) revert ZeroAddress();

        // Check the contract's token balance
        uint256 contractBalance = vvfitToken.balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient contract balance");

        // Transfer the tokens to the recipient
        vvfitToken.transfer(recipient, amount);

        emit EmergencyWithdraw(msg.sender, amount, recipient);
    }
}
