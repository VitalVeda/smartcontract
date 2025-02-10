// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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

    // Name of the contract (used for EIP-712 standard)
    string public constant CONTRACT_NAME = "WorkoutManagement";
    // Version of the contract (used for EIP-712 standard)
    string public constant CONTRACT_VERSION = "1.0.0";
    // Divider used to calculate percent for fee distribution
    uint256 public constant RATE_DIVIDER = 100_000;

    // Role assigned to operators with specific permissions
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    // Role assigned to instructors with specific permissions
    bytes32 public constant INSTRUCTOR_ROLE = keccak256("INSTRUCTOR_ROLE");

    // Fee required to create an event
    uint256 public eventCreationFee;
    // Percentage of the joining fee allocated to the instructor
    uint256 public instructorRate;
    // Percentage of the joining fee allocated to burning
    uint256 public burningRate;

    // Address of the workout treasury contract that holds VVFIT from create event
    address public workoutTreasury;
    // VVFIT token contract interface
    IVVFIT public vvfitToken;

    // Counter for the number of events created
    uint256 public eventCount;
    // Mapping of event IDs to WorkoutEvent details
    mapping(uint256 eventId => WorkoutEvent workoutEvent) public events;
    // Mapping of event IDs to boolean values indicating if a salt has been used
    mapping(uint256 salt => bool isUsed) public usedSalt;

    // The typehash for the Claim struct used in the claim process
    // It is used for verifying the integrity and authenticity of the claim data in a signed message
    bytes32 public constant CLAIM_TYPEHASH =
        keccak256(
            "Claim(uint256 eventId,address user,uint256 rewardPercentage,uint256 salt)"
        );

    /**
     * @notice Initializes the contract with the given parameters.
     * @param _vvfitAddress The address of the VVFIT token contract.
     * @param _workoutTreasury The address of the workout treasury where fees are sent.
     * @param _eventCreationFee The fee required to create an event.
     * @param _instructorRate The rate for instructors in the event.
     * @param _burningRate The rate for burning tokens in the event.
     * @dev Grants the DEFAULT_ADMIN_ROLE to the deployer.
     * Reverts if the `_vvfitAddress` is the zero address.
     */
    function initialize(
        address _vvfitAddress,
        address _workoutTreasury,
        uint256 _eventCreationFee,
        uint256 _instructorRate,
        uint256 _burningRate
    ) public initializer {
        if (_vvfitAddress == address(0) || _workoutTreasury == address(0)) {
            revert ZeroAddress();
        }
        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __EIP712_init(CONTRACT_NAME, CONTRACT_VERSION);
        vvfitToken = IVVFIT(_vvfitAddress);
        workoutTreasury = _workoutTreasury;
        eventCreationFee = _eventCreationFee;
        instructorRate = _instructorRate;
        burningRate = _burningRate;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Modifier to check if the event with the specified ID exists.
     * Reverts if the event does not exist (i.e., the event instructor not exists).
     * @param _eventId The ID of the event to check.
     * @notice This modifier is used to ensure that the specified event exists before performing any actions on it.
     */

    modifier eventExists(uint256 _eventId) {
        if (events[_eventId].instructor == address(0)) {
            revert EventDoesNotExist(_eventId);
        }
        _;
    }

    /**
     * @dev Modifier to check if the event has completed.
     * Reverts if the event's end time has not yet passed (i.e., the event is still ongoing).
     * @param _eventId The ID of the event to check.
     * @notice This modifier ensures that the event has finished before performing actions that require the event to be completed.
     */
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

    /**
     * @dev Function to check if an instructor has claim fee from specific event.
     * @param _eventId The ID of the event to check.
     * @return true if the instructor has claimed the fee of event, false otherwise.
     */
    function checkIsInstructorClaim(
        uint256 _eventId,
        address _instructor
    ) external view returns (bool) {
        return events[_eventId].hasClaimed[_instructor];
    }

    /**
     * @dev Function to check if an user has participated in specific event.
     * @param _eventId The ID of the event to check.
     * @return true if the user has participated in the event, false otherwise.
     */
    function checkIsUserParticipated(
        uint256 _eventId,
        address _participant
    ) external view returns (bool) {
        return events[_eventId].hasParticipated[_participant];
    }

    /**
     * @notice Grants the operator role to a specified address.
     * @param _operator The address to be granted the operator role.
     * @dev Reverts if `_operator` is the zero address.
     */
    function grantOperatorRole(
        address _operator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_operator == address(0)) {
            revert ZeroAddress();
        }
        grantRole(OPERATOR_ROLE, _operator);
    }

    /**
     * @notice Grants the instructor role to a specified address.
     * @param _instructor The address to be granted the instructor role.
     * @dev Reverts if `_instructor` is the zero address.
     */
    function grantInstructorRole(
        address _instructor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_instructor == address(0)) {
            revert ZeroAddress();
        }
        grantRole(INSTRUCTOR_ROLE, _instructor);
    }

    /**
     * @notice Creates a new workout event.
     * @param _eventId The unique identifier for the event.
     * @param _participationFee The fee required to participate in the event.
     * @param _eventStartTime The start time of the event (in UNIX timestamp).
     * @param _eventEndTime The end time of the event (in UNIX timestamp).
     * @dev Reverts if `_participationFee` is zero, if the event times are invalid, or if the creation fee cannot be transferred.
     */
    function createEvent(
        uint256 _eventId,
        uint256 _participationFee,
        uint256 _eventStartTime,
        uint256 _eventEndTime
    ) external onlyRole(INSTRUCTOR_ROLE) nonReentrant whenNotPaused {
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
        if (eventCreationFee > 0) {
            vvfitToken.safeTransferFrom(
                msg.sender,
                workoutTreasury,
                eventCreationFee
            );
        }

        // Create the event
        WorkoutEvent storage newEvent = events[_eventId];
        newEvent.instructor = msg.sender;
        newEvent.participationFee = _participationFee;
        newEvent.eventStartTime = _eventStartTime;
        newEvent.eventEndTime = _eventEndTime;
        eventCount++;

        emit EventCreated(_eventId, msg.sender, _eventEndTime);
    }

    /**
     * @notice Allows a user to participate in an event by paying the participation fee.
     * @param eventId The ID of the event to participate in.
     * @dev Reverts if the event has not started, has ended, or if the user has already participated.
     */
    function participateInEvent(
        uint256 eventId
    ) external eventExists(eventId) nonReentrant whenNotPaused {
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
        vvfitToken.safeTransferFrom(msg.sender, address(this), feeAmount);

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

    /**
     * @notice Allows instructors to claim their accumulated fees from multiple events.
     * @param eventId The ID of the event for instructor to claim.
     * @dev Reverts if any event does not exist, is incomplete, or if the caller is not the instructor for an event.
     */
    function instructorClaimFee(
        uint256 eventId
    )
        external
        onlyRole(INSTRUCTOR_ROLE)
        nonReentrant
        whenNotPaused
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
        vvfitToken.safeTransfer(msg.sender, feeAmount);

        emit InstructorFeesClaimed(eventId, msg.sender, feeAmount);
    }

    /**
     * @notice Allows top participants of a workout event to claim their rewards
     * @dev Verifies the signature of the claim and ensures the claim is valid and unique
     *      This function only applies to completed events
     * @param eventId The ID of the workout event for which the reward is being claimed
     * @param rewardPercentage The percentage of the total reward that should be claimed by participant
     * @param salt A unique value to prevent replay attacks
     * @param signature A signed message verifying the claim details
     */
    function topParticipantsClaimReward(
        uint256 eventId,
        uint256 rewardPercentage,
        uint256 salt,
        bytes memory signature
    ) external nonReentrant whenNotPaused eventHasCompleted(eventId) {
        WorkoutEvent storage workoutEvent = events[eventId];
        if (workoutEvent.hasClaimed[msg.sender])
            revert RewardAlreadyClaimed(eventId, msg.sender);

        if (usedSalt[salt]) revert SaltAlreadyUsed(salt);

        // Verify the signature
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    CLAIM_TYPEHASH,
                    eventId,
                    msg.sender,
                    rewardPercentage,
                    salt
                )
            )
        );

        address signer = digest.recover(signature);

        _checkRole(OPERATOR_ROLE, signer);

        // Mark as claimed
        workoutEvent.hasClaimed[msg.sender] = true;
        usedSalt[salt] = true;
        // Calculate reward based on user score
        uint256 reward = _calculateReward(eventId, rewardPercentage);

        // Update pool reward count
        workoutEvent.claimedReward += reward;

        // Transfer reward
        vvfitToken.safeTransfer(msg.sender, reward);

        emit TopParticipantsClaimed(eventId, msg.sender, reward);
    }

    /**
     * @dev Sets the fee required for event creation.
     * @param _newCreationFee The new fee to be set for event creation.
     */
    function setEventCreationFee(
        uint256 _newCreationFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        eventCreationFee = _newCreationFee;
        emit EventCreationFeeUpdated(_newCreationFee);
    }

    /**
     * @dev Sets the reward rates for instructors and burning.
     * @param _instructorRate The percentage of the reward that goes to the instructor (in basis points).
     * @param _burningRate The percentage of the reward that gets burned (in basis points).
     * @notice The sum of instructorRate and burningRate must be less than a predefined constant `RATE_DIVIDER`.
     * @dev Reverts if the sum of rates is invalid.
     */
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
     * @dev Calculates the reward for a user based on their score in an event
     * @param eventId The ID of the event for which the reward is being calculated
     * @param rewardPercentage The percentage of the reward that is distributed to participant
     * @return uint256 The calculated reward for the user
     * @notice Reverts if `totalScores` or `userScore` are zero, or if the calculated reward exceeds the available pool
     */
    function _calculateReward(
        uint256 eventId,
        uint256 rewardPercentage
    ) private view returns (uint256) {
        if (rewardPercentage == 0) {
            revert ZeroAmount();
        }

        uint256 totalReward = events[eventId].rewardPool;

        // Calculate user's share based on their proportion of total winner scores
        uint256 userRewardShare = (totalReward * rewardPercentage) /
            RATE_DIVIDER;

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
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        // Check the contract's token balance
        uint256 contractBalance = vvfitToken.balanceOf(address(this));
        if (amount > contractBalance)
            revert InsufficientBalance(amount, contractBalance);

        // Transfer the tokens to the recipient
        vvfitToken.safeTransfer(recipient, amount);

        emit EmergencyWithdraw(msg.sender, amount, recipient);
    }

    /**
     * @dev Authorizes the upgrade to a new implementation contract.
     * Only the account with the `DEFAULT_ADMIN_ROLE` can authorize the upgrade.
     * @param newImplementation The address of the new implementation contract.
     * @notice This function is required to be called by the `upgradeTo` function in UUPS upgradeable contracts.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
