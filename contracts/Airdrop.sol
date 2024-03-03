// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

//import {VRFCoordinatorV2Interface} from "@chainlink/contracts@0.8.0/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
//import {VRFConsumerBaseV2} from "@chainlink/contracts@0.8.0/src/v0.8/vrf/VRFConsumerBaseV2.sol";
//import "contracts/Airdrop/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./IERC20.sol";
import "./Err.sol";


contract Airdrop is VRFConsumerBaseV2 {

    address owner;
    IERC20 immutable erc20;
    VRFCoordinatorV2Interface COORDINATOR;
    uint8 private constant NAME_MAX_LENGTH = 20;
    bool public winnersSelected;
    bool public airdropDistributed;


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
    Participant[] public  allParticipants;
    Participant[] public prizes;
    Participant[] public winners;


    enum Selection {
        HEAD,
        TAIL
    }
    enum Status {
        REGULAR,
        PRIZE,
        WINNER
    }

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
        uint256 sentTime;
        uint256 resultTime;
    }

    struct Participant {
        address userAddress;
        string name;
        uint256 registeredAt;
        Selection[] userGuesses;
        uint256 score;
        bool isRegistered;
        Status status;
    }

    mapping(address => Participant) public forPrize;
    mapping(address => uint256) public userRequestIds;
    mapping(address => Participant) public participants;
    mapping(uint256 => RequestStatus) public s_requests;
    mapping(address => uint256) public  balances;


    event GamePlayed(uint256 requestId, uint32 numWords, Selection[] guesses);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event Result(address participant, uint256 _score, bool fulfilled);
    event Registered(address participant, bool success);
    event SelectWinners(Participant[] winners, bool success);
    event Airdrops(uint256 totalNumOfParticipants, uint256 totalAirdropsDistributed);
    event ClaimAirdrop(address claimer, uint256 _amount);

    function onlyOwner() private view  {
        if (msg.sender != owner) revert Err.ONLY_OWNER_IS_ALLOWED();
    }

    //SEPOLIA COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
    constructor(uint64 subscriptionId, address erc20Contract) VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) {
        COORDINATOR = VRFCoordinatorV2Interface(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        s_subscriptionId = subscriptionId;
        erc20 = IERC20(erc20Contract);
        owner = msg.sender;
    }

    function checkAddressZero() private view {
        if (msg.sender == address(0)) revert Err.ADDRESS_ZERO_NOT_ALLOWED();
    }

    function nameLength(string memory _name) private pure {
        if (bytes(_name).length < 1) revert Err.NAME_CANNOT_BE_EMPTY();
        if (bytes(_name).length > NAME_MAX_LENGTH) revert Err.NAME_TOO_LONG();
    }

    function registration(string memory _name) external { //done
        checkAddressZero();
        nameLength(_name);

        if (participants[msg.sender].userAddress != address(0)) revert Err.YOU_HAVE_ALREADY_REGISTERED();

        Participant storage _participant = participants[msg.sender];
        _participant.name = _name;
        _participant.userAddress = msg.sender;
        _participant.registeredAt = block.timestamp;
        _participant.isRegistered = true;

        allParticipants.push(_participant);

        emit Registered(msg.sender, true);
    }

    function userParticipateInGame(Selection[] memory _guesses) external returns (uint256 requestId) {
        if (!participants[msg.sender].isRegistered) revert Err.YOU_ARE_NOT_REGISTERED();
        requestId = COORDINATOR.requestRandomWords(keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, numWords);

        participants[msg.sender].userGuesses = _guesses;
        participants[msg.sender].status = Status.REGULAR;
        allParticipants.push(participants[msg.sender]);
        userRequestIds[msg.sender] = requestId;

        RequestStatus storage _requestStatus = s_requests[requestId];
        _requestStatus.exists = true;
        _requestStatus.sentTime = block.timestamp;

        requestIds.push(requestId);
        emit GamePlayed(requestId, numWords, _guesses);

        return requestId;
    }

    //this is the function chainlink will call when the random numbers are ready
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        if (!s_requests[_requestId].exists) revert Err.REQUEST_NOT_FOUND();

        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        s_requests[_requestId].resultTime = block.timestamp;

        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getReturnedRandomNumbers(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords) {
        if (!s_requests[_requestId].fulfilled) revert Err.RESULT_IS_NOT_READY();

        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function getParticipantResult() external {
        uint256 _requestId = userRequestIds[msg.sender];
        if (_requestId == 0) revert Err.YOU_HAVE_NOT_PARTICIPATED();

        RequestStatus memory _request = s_requests[_requestId];
        if (!_request.fulfilled) revert Err.RESULT_IS_NOT_READY();

        uint256[] memory _randNum = _request.randomWords;

        Participant memory _participant = participants[msg.sender];
        uint256 _score = _participant.score;

        for (uint256 i = 0; i < _randNum.length; i++) {

            Selection selection = _randNum[i] % 2 == 0 ? Selection.HEAD : Selection.TAIL;

            if (selection == _participant.userGuesses[i]) {
                _score = _score + 1;
            }
        }

        participants[msg.sender].score = _score;

        if (_score > 2) {
            participants[msg.sender].status = Status.PRIZE;
            forPrize[msg.sender] = participants[msg.sender];
            prizes.push(participants[msg.sender]);
            allParticipants.push(participants[msg.sender]);
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


    function selectWinnersFromPool() external {
        onlyOwner();
        if (prizes.length < 10) revert Err.MAX_POOL_NOT_REACHED();
        // (chainlink num + i) % lengthOfArray => this will gice you a number within the array and that number should be passed in as index to get your winners
        /*
       call the requestIds array and use the index number of the array to get a requestId
       use the requestId to get to get RequestStatus
       the array in that RequestStatus, use the current loop index to fetch the random number in the array
       */
        for (uint256 i = 0; i < (prizes.length / 2); i++) {

            uint256 _requestId = requestIds[i];
            uint256 _rand = s_requests[_requestId].randomWords[i];

            uint256 index = (_rand + i) % prizes.length;

            Participant storage _participant = prizes[index];
            _participant.status = Status.WINNER;

            allParticipants.push(_participant);
        }

        winnersSelected = true;

        emit SelectWinners(winners, true);
    }

    function distributeAirdrops() external {
        onlyOwner();
        if (!winnersSelected) revert Err.WINNERS_ARE_NOT_SELECTED_YET();

        uint256 noOfParticipants = allParticipants.length;
        uint256 totalPrize;

        for (uint256 i = 0; i < noOfParticipants; i++) {
            uint256 airdrop;
            uint256 score = allParticipants[i].score;
            address _participant = allParticipants[i].userAddress;

            if (allParticipants[i].status == Status.WINNER) airdrop = 100000 * score;
            else if (allParticipants[i].status == Status.PRIZE) airdrop = 50000 * score;
            else if (allParticipants[i].status == Status.REGULAR) airdrop = 10000 * score;
            else airdrop = 1000 * score;


            balances[_participant] = airdrop;
            erc20.approve(_participant, airdrop);
            totalPrize = totalPrize + airdrop;
        }
        airdropDistributed = true;

        emit Airdrops(noOfParticipants, totalPrize);
    }

    function getTokenBalance() external view returns (uint256) {
        checkAddressZero();
        if (!airdropDistributed) revert Err.YOU_DO_NOT_HAVE_BALANCE_YET();
        if (!participants[msg.sender].isRegistered) revert Err.YOU_ARE_NOT_REGISTERED();

        return balances[msg.sender];
    }


    function claimAirdrop() external {
        checkAddressZero();
        if (!participants[msg.sender].isRegistered) revert Err.YOU_DO_NOT_QUALIFY_FOR_THIS_AIRDROP();

        uint256 _amount = balances[msg.sender];

        if (erc20.transferFrom(address(this), msg.sender, _amount)) {
            emit ClaimAirdrop(msg.sender, _amount);
        } else revert Err.COULD_NOT_BE_CLAIMED__TRY_AGAIN_LATER();
    }
}
