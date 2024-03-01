// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts@0.8.0/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts@0.8.0/src/v0.8/vrf/VRFConsumerBaseV2.sol";
//import {ConfirmedOwner} from "@chainlink/contracts@0.8.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import "contracts/Airdrop/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import "contracts/IERC20.sol";

    error ADDRESS_ZERO_NOT_ALLOWED();
    error ONLY_OWNER();
    error NAME_CANNOT_BE_EMPTY();
    error NAME_TOO_LONG();
    error YOU_ARE_NOT_A_PARTICIPANT();
    error YOU_HAVE_ALREADY_REGISTERED();
    error RESULT_IS_NOT_READY();
    error YOU_HAVE_NOT_PARTICIPATED();
    error YOU_ARE_NOT_REGISTERED();
    error MAX_POOL_NOT_REACHED();


contract Airdrop is VRFConsumerBaseV2, ConfirmedOwner {

    IERC20 immutable erc20;
    VRFCoordinatorV2Interface COORDINATOR;

    bytes32 constant keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    uint32 callbackGasLimit = 200000;

    //the number of blocks before confirmation
    uint16 requestConfirmations = 3;

    // total number of output
    uint32 numWords = 5;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;

    // address private owner;
    uint8 private constant NAME_MAX_LENGTH = 20;
    Participant[] private allParticipants;
    Participant[] private prizes;
    Participant[] private winners;


    enum Selection {
        HEAD, TAIL
    }
    enum Status {
        REGULAR,
        PRIZE,
        WINNER
    }

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    struct Participant {
        address userAddress;
        string name;
        uint256 registeredAt;
        Selection[] userGuesses;
        uint256 requestId;
        uint256 score;
        bool isRegistered;
        Status status;
    }

    mapping(address => Participant) private forPrize;


    mapping(address => uint256) private userRequestIds;
    mapping(address => Participant) public participants;
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    mapping(address => uint256) private balances;


    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event Result(address participant, uint256 _score, bool fulfilled);
    event Registered(address participant, bool success);

    //SEPOLIA COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
    constructor(uint64 subscriptionId, address erc20Contract) VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) ConfirmedOwner(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        s_subscriptionId = subscriptionId;
        erc20 = IERC20(erc20Contract);
    }

    function checkAddressZero() private view {
        if (msg.sender == address(0)) revert ADDRESS_ZERO_NOT_ALLOWED();
    }

    // function onlyOwner() private view {
    //     if (msg.sender != owner) revert ONLY_OWNER();
    // }

    function nameLength(string memory _name) private pure {
        if (bytes(_name).length < 1) revert NAME_CANNOT_BE_EMPTY();
        if (bytes(_name).length > NAME_MAX_LENGTH) revert NAME_TOO_LONG();
    }

    function registration(string memory _name) external {
        checkAddressZero();
        nameLength(_name);

        if (participants[msg.sender].userAddress != address(0)) revert YOU_HAVE_ALREADY_REGISTERED();

        Participant storage _participant = participants[msg.sender];
        _participant.name = _name;
        _participant.userAddress = msg.sender;
        _participant.registeredAt = block.timestamp;
        _participant.isRegistered = true;

        allParticipants.push(_participant);

        emit Registered(msg.sender, true);
    }

    function userParticipateInGame(Selection[] memory _guesses) external returns (uint256 requestId) {
        if (!participants[msg.sender].isRegistered) revert YOU_ARE_NOT_REGISTERED();
        requestId = COORDINATOR.requestRandomWords(keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, numWords);

        participants[msg.sender].userGuesses = _guesses;
        participants[msg.sender].status = Status.REGULAR;
        userRequestIds[msg.sender] = requestId;

        RequestStatus storage _requestStatus = s_requests[requestId];
        _requestStatus.exists = true;

        requestIds.push(requestId);
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    //this is the function chainlink will call when the random numbers are ready
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords) {
        if (!s_requests[_requestId].fulfilled) revert RESULT_IS_NOT_READY();
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function getParticipantResult() external {
        if (userRequestIds[msg.sender] == 0) revert YOU_HAVE_NOT_PARTICIPATED();
        uint256 _requestId = userRequestIds[msg.sender];
        if (!s_requests[_requestId].fulfilled) revert RESULT_IS_NOT_READY();
        require(s_requests[_requestId].exists, "request not found");

        RequestStatus memory _request = s_requests[_requestId];
        uint256[] memory _randNum = _request.randomWords;
        uint256 _score = participants[msg.sender].score;
        Participant memory _participant = participants[msg.sender];

        for (uint256 i = 0; i < _randNum.length; i++) {
            bool _temp = _randNum[i] % 2 == 0;
            Selection _sel = Selection.TAIL;

            if (_temp) _sel = Selection.HEAD;

            if (_sel == _participant.userGuesses[i]) {
                _score = _score + 1;
            }
        }

        participants[msg.sender].score = _score;
        if (_score > 2) {
            participants[msg.sender].status = Status.PRIZE;
            forPrize[msg.sender] = participants[msg.sender];
            prizes.push(participants[msg.sender]);

        }
        emit Result(msg.sender, _score, _request.fulfilled);
    }

    //i will uncomment this later
    // function getParticipant(address _user) external view returns(Participant memory) {
    // checkAddressZero();
    //     Participant memory _participant = participants[_user];
    //     if (_participant.userAddress == address(0)) revert YOU_ARE_NOT_A_PARTICIPANT();
    //     return _participant;
    // }


    function selectWinnersFromPool() external onlyOwner {
        if (prizes.length < 10) revert MAX_POOL_NOT_REACHED();
        // (chainlink num + i) % lengthOfArray => this will gice you a number within the array and that number should be passed in as index to get your winners
        /*
       call the requestIds array and use the index number of the array to get a requestId
       use the requestId to get to get RequestStatus
       the array in that RequestStatus, use the current loop index to fetch the random number in the array
       */
        for (uint256 i = 0; i < 10; i++) {

            uint256 _requestId = requestIds[i];
            uint256 _rand = s_requests[_requestId].randomWords[i];
            uint256 index = (_rand + i) % prizes.length;
            Participant storage _participant = prizes[index];
            _participant.status = Status.WINNER;
            winners.push(_participant);
        }
    }

    function airdrops() external onlyOwner {
        uint numberOfParticipants = allParticipants.length;

        for (uint256 i = 0; i < numberOfParticipants; i++) {

            if (allParticipants[i].status == Status.WINNER) {
                uint256 _prize = 100000 * allParticipants[i].score;
                address _participant = allParticipants[i].userAddress;
                balances[_participant] = _prize;
                erc20.approve(_participant, _prize);
            } else if (allParticipants[i].status == Status.PRIZE) {
                uint256 _prize = 50000 * allParticipants[i].score;
                address _participant = allParticipants[i].userAddress;
                balances[_participant] = _prize;
                erc20.approve(_participant, _prize);

            } else {
                uint256 _prize = 10000 * allParticipants[i].score;
                address _participant = allParticipants[i].userAddress;
                balances[_participant] = _prize;
                erc20.approve(_participant, _prize);
            }
        }
    }

    function claimAirdrop() external {
        uint256 _amount = balances[msg.sender];
        erc20.transferFrom(address(this), msg.sender, _amount);
    }

}
