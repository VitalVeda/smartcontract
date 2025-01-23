// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IWorkoutManagement.sol";
import "./interfaces/IVVFIT.sol";

contract WorkoutManagement is
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    UUPSUpgradeable,
    IWorkoutManagement
{
    using SafeERC20 for IVVFIT;
    using ECDSA for bytes32;

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
    mapping(uint256 => bool) public usedSalt;

    bytes32 private constant CLAIM_TYPEHASH =
        keccak256(
            "Claim(uint256 eventId,address user,uint256 totalScores,uint256 score, uint256 salt)"
        );

    function initialize(
        address _vvfitAddress,
        address _workoutTreasury,
        uint256 _eventCreationFee
    ) public initializer {
        if (_vvfitAddress == address(0)) {
            revert ZeroAddress();
        }
        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __EIP712_init(CONTRACT_NAME, CONTRACT_VERSION);
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

    modifier eventHasCompleted(uint256 _eventId) {
        if (events[_eventId].eventEndTime > block.timestamp) {
            revert EventNotCompleted(
                events[_eventId].eventEndTime,
                block.timestamp
            );
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
        if (workoutEvent.eventEndTime <= block.timestamp) {
            revert EventHasEnded(workoutEvent.eventEndTime, block.timestamp);
        }
        // Check if user already participated
        if (workoutEvent.hasParticipated[msg.sender]) {
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

        workoutEvent.instructorFee += instructorLoyalty;
        workoutEvent.rewardPool += rewardPoolAmount;

        // Add user to the participants list
        workoutEvent.hasParticipated[msg.sender] = true;
        workoutEvent.participants++;

        emit UserParticipated(
            eventId,
            msg.sender,
            workoutEvent.participationFee
        );
    }

    function instructorClaimFee(
        uint256 eventId
    )
        external
        onlyRole(INSTRUCTOR_ROLE)
        whenNotPaused
        nonReentrant
        eventHasCompleted(eventId)
    {
        WorkoutEvent storage workoutEvent = events[eventId];

        // Verify caller is the event instructor
        if (workoutEvent.instructor != msg.sender) {
            revert NotEventInstructor(msg.sender, workoutEvent.instructor);
        }

        // Prevent multiple claims
        if (workoutEvent.instructorFeeClaimed) {
            revert FeesAlreadyClaimed(eventId, msg.sender);
        }

        uint256 feeAmount = workoutEvent.instructorFee;

        // Mark fees as claimed
        workoutEvent.instructorFeeClaimed = true;

        // Transfer fees to instructor
        vvfitToken.transfer(msg.sender, feeAmount);

        emit InstructorFeesClaimed(eventId, msg.sender, feeAmount);
    }

    function topParticipantsClaimReward(
        uint256 eventId,
        uint256 totalScores,
        uint256 userScore,
        uint256 salt,
        bytes memory signature
    ) external whenNotPaused nonReentrant eventHasCompleted(eventId) {
        if (events[eventId].hasClaimed[msg.sender])
            revert RewardAlreadyClaimed(eventId, msg.sender);

        // Verify the signature
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    CLAIM_TYPEHASH,
                    eventId,
                    msg.sender,
                    totalScores,
                    userScore,
                    salt
                )
            )
        );

        address signer = digest.recover(signature);

        _checkRole(OPERATOR_ROLE, signer);

        // Mark as claimed
        events[eventId].hasClaimed[msg.sender] = true;
        usedSalt[salt] = true;
        // Calculate reward based on user score
        uint256 reward = calculateReward(eventId, totalScores, userScore);

        // Update pool reward count
        events[eventId].claimedReward += reward;

        // Transfer reward
        vvfitToken.transfer(msg.sender, reward);

        emit TopParticipantsClaimed(eventId, msg.sender, reward);
    }

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

    function calculateReward(
        uint256 eventId,
        uint256 totalScores,
        uint256 userScore
    ) private view returns (uint256) {
        if (totalScores == 0 || userScore == 0) {
            revert ZeroAmount();
        }

        uint256 totalReward = events[eventId].rewardPool;

        // Calculate user's share based on their proportion of total winner scores
        uint256 userRewardShare = (userScore * totalReward) / totalScores;

        if (userRewardShare + events[eventId].claimedReward > totalReward) {
            revert InsufficientReward(userRewardShare, totalReward);
        }

        return userRewardShare;
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
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        // Check the contract's token balance
        uint256 contractBalance = vvfitToken.balanceOf(address(this));
        if (amount > contractBalance)
            revert InsufficientBalance(amount, contractBalance);

        // Transfer the tokens to the recipient
        vvfitToken.transfer(recipient, amount);

        emit EmergencyWithdraw(msg.sender, amount, recipient);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
