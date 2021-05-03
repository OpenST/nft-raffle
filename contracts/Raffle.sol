// SPDX-License-Identifier: MIT
// Copyright 2021 Mosaic Labs UG, Berlin
pragma solidity ^0.8.0;

import "./IERC20Burnable.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title Raffle contract for NFTs
 * @author Benjamin Bollen <ben@mosaiclabs.eu>
 */
contract Raffle {

    /* Constants */

    /**
     * CHALLENGE_WINDOW sets the minimal number of blocks during which
     * the initial or challenger precommits can be challenged or voted upon.
     * For each new precommit, the challenge window is restored in full.
     * Set to 1 hour (300 times 12 second blocks).
     */
    uint256 public constant CHALLENGE_WINDOW = uint256(300);

    /**
     * ENTROPY_WINDOW waits for some blocks to collect future block hashes
     * as a randomizer of the raffle.
     */
    uint256 public constant ENTROPY_WINDOW = uint256(20);

    /**
     * ENTROPY_LENGTH takes three consecutive block hashes to create
     * a randomizer for the raffle.
     */
    uint256 public constant ENTROPY_LENGTH = uint256(3);

    /**
     * NOMINATION_COOLDOWN sets the number of blocks during which
     * entries can be proposed to be sorted as closest to target.
     * Set to 10 minutes (50 times 12 second blocks).
     */
    uint256 public constant NOMINATION_COOLDOWN = uint256(50);

    /**
     * MINIMUM_WEIGHT sets the minimum amount of mechanics token
     * the organiser must provide on creating a new raffle.
     */
    uint256 public constant MINIMUM_WEIGHT = uint256(10**18);

    /**
     * SENTINEL_DISTANCE set to maximum distance.
     */
    uint256 public constant SENTINEL_DISTANCE = uint256(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );

    /**
     * SENTINEL_TICKETS is reserved bytes32 to identify the end of circular list.
     */
    bytes32 public constant SENTINEL_TICKETS = bytes32(
        0x0000000000000000000000000000000000000000000000000000000000000001
    );

    /* Enums */

    /**
     * Raffle status enum
     */
    enum RaffleStatus {
        /**
        * Raffle created. NFT rewards can be added, or taken back by organiser,
        * raffle metadata and data is collected on OST chain.
        */
        Created,

        /**
        * OrganiserPrecommitted. All metadata and all valid transactions
        * that constitute the raffle tickets have been included into blocks.
        * Indexers can compute the precommit root of the raffle.
        * The initial precommit must be presented by the organiser
        * of the raffle.
        * Afterwards the precommit can be challenged and arbiter is left to decide.
        */
        OrganiserPrecommitted,

        /**
        * Precommitted. Wait for future entropy from Ethereum mainnet.
        */
        Precommitted,

        /*
        * Drawn. With new entropy provided by a sequence of Ethereum blockhashes
        * the raffle is now decided. To verify the winners, the elected raffle
        * tickets can now be submitted.
        */
        Drawn,

        /**
        * Cooled down. The elected raffle tickets have been presented, and
        * the beneficiary addresses associated with the elected tickets
        * can be revealed.
        */
        CooledDown,

        /**
        * Awarded. All rewards have been awarded to the beneficiary addresses.
        * This raffle is successfully completed.
        */
        Awarded,

        /**
        * Cancelled. The raffle was cancelled before distribution completed.
        */
        Cancelled,

        /**
         * Proposed precommit was challenged, and raffle handed over to arbiter.
         */
        Challenged
    }

    /* Structs */

    /**
     * Raffle holds essential data and references for the raffle.
     */
    struct RaffleData {
        // Organiser address who initiated organises the raffle
        address organiser;
        // ChainId EIP-155 of where the raffle is distributed
        uint256 chainId;
        // Metadata contract on chain with chainId for indexing
        // all valid raffle tickets
        address metadata;
        // Reward ERC721 NFT token contract
        IERC721 rewardToken;
        // Weight sets the initial amount of OST token by the organiser.
        // All other token costs are relative to this weight for the raffle.
        uint256 weight;
        // Status enum of raffle
        RaffleStatus status;
    }

    /* Storage */

    /**
     * ERC20 token contract used for mechanics.
     * On Ethereum mainnet set to OST @ 0x2c4e8f2d746113d0696ce89b35f0d8bf88e0aeca
     */
    IERC20Burnable public token;

    /**
     * Arbiter is designated to resolve the precommit if the precommit got challenged.
     */
    address public arbiter;

    /**
     * ChainId restriction allows to set the contract to only accept raffles
     * from a preset chainId. This allows the arbiter to restrict about which
     * chains it will accept formulating an opinion over.
     */
    uint256 public chainIdRestriction;

    /** Index counts the number of raffles created */
    uint256 public index;

    /** Reward tokenIds keeps a record of all the ERC721 tokenIds
     * for each raffle index.
    * Note that each raffle has a specified ERC721 address.
     */
    mapping(uint256 => uint256[]) public rewardTokenIds;

    /**
     * Raffles stores essential data and references for the active raffles.
     */
    mapping(uint256 => RaffleData) public raffles;

    /**
     * TimeWindow keeps the block number for the active phase of a raffle
     * when raffle status is
     *  - OrganiserPrecommitted, time window is set to blocknumber + CHALLENGE_WINDOW
     *    after this the raffle can become precommitted.
     *    During this window the precommit can be challenged and the decision
     *    is handed over to the arbiter.
     *  - Precommitted. The time window is set to allow entropy from Ethereum
     *    to happen after a root has been precomitted.
     */
    mapping(uint256 => uint256) public timeWindows;

    /**
     * Precommits stores the precommit as proposed by the raffle organiser.
     */
    mapping(uint256 => bytes32) public precommits;

    /**
     * Challengers keep the addresses of the challenger if a precommit
     * is challenged.
     */
    mapping(uint256 => address) public challengers;

    /**
     * Seeds stores the randomizers seeds as generated during draw.
     */
    mapping(uint256 => bytes32) public seeds;

    /**
     * Nomination count keeps a count of nominated tickets for a raffle index.
     * The nomination count increases until it reaches the amount of tokenIds
     * that are associated to the given raffle. This maximum is present
     * because we only need to keep nominated tickets for each reward.
     */
    mapping(uint256 => uint256) public nominationCount;

    /**
     * Nominations stores the closest tickets thusfar entered into the drawn raffle.
     */
    mapping(uint256 => mapping(bytes32 => bytes32)) public nominations;

    /* Modifiers */

    modifier onlyOrganiser(uint256 _index) {
        require(
            raffles[_index].organiser == msg.sender,
            "Only organiser can call this function."
        );
        _;
    }

    modifier onlyArbiter() {
        require(
            msg.sender == arbiter,
            "Only arbiter can call this function."
        );
        _;
    }

    modifier isInCreationPhase(uint256 _index) {
        require(
            raffles[_index].status == RaffleStatus.Created,
            "Raffle must be created and not yet precommited."
        );
        _;
    }

    modifier isInChallengePhase(uint256 _index) {
        require(
            raffles[_index].status == RaffleStatus.OrganiserPrecommitted,
            "Raffle must have a precommit proposed."
        );
        _;
    }

    modifier hasBeenChallenged(uint256 _index) {
        require(
            raffles[_index].status == RaffleStatus.Challenged,
            "Raffle must have been challenged."
        );
        _;
    }

    modifier isInPrecommittedPhase(uint256 _index) {
        require(
            raffles[_index].status == RaffleStatus.Precommitted,
            "Raffle must have been precommitted."
        );
        _;
    }

    modifier isInDrawnPhase(uint256 _index) {
        require(
            raffles[_index].status == RaffleStatus.Drawn,
            "Raffle must have been drawn."
        );
        _;
    }

    /* Constructor */

    /**
     * On construction the token contract for the raffle mechanics must be set.
     */
    constructor(
        IERC20Burnable _token,
        address _arbiter,
        uint256 _chainIdRestriction
    ) {
        require(
            address(_token) != address(0),
            "The token address cannot be the zero address."
        );
        require(
            _arbiter != address(0),
            "The arbiter address cannot be the zero address."
        );

        console.log("Deploying raffle contract with token ", address(_token));
        token = _token;
        arbiter = _arbiter;

        // restriction can be zero if unrestricted
        chainIdRestriction = _chainIdRestriction;
    }

    /* External Functions */

    function createRaffle(
        uint256 _chainId,
        address _metadata,
        IERC721 _rewardToken,
        uint256[] calldata _tokenIds,
        uint256 _weight
    )
        external
        returns (uint256 index_)
    {
        require(
            _chainId != uint256(0),
            "ChainId provided cannot be zero."
        );
        require(
            _chainId == uint256(chainIdRestriction) ||
            chainIdRestriction == uint256(0),
            "Arbiter will only form an opinion on the restricted chainId."
        );
        require(
            _metadata != address(0),
            "Metadata contract provided cannot be the zero address."
        );
        require(
            address(_rewardToken) != address(0),
            "Reward token address cannot point to the zero address."
        );
        require(
            _weight > MINIMUM_WEIGHT,
            "Weight in token amount must be more or equal to 10**18 aOST."
        );

        // Use current index value to index new raffle
        index_ = index;
        index = index + 1;

        // Transfer the weight in OST to the raffle contract
        token.transferFrom(msg.sender, address(this), _weight);

        uint256[] storage newTokenIds = rewardTokenIds[index_];

        // Transfer all the NFT rewards into the raffle contract
        // Note, for simplicity this is done during creation, but can be altered
        for (uint64 i = 0; i < _tokenIds.length; i++ ) {
            // store the tokenIds that are being assigned to the raffle
            newTokenIds.push(_tokenIds[i]);
            _rewardToken.transferFrom(msg.sender, address(this), _tokenIds[i]);
        }

        // Initiate new raffle data
        RaffleData storage raffle = raffles[index_];

        raffle.organiser = msg.sender;
        raffle.chainId = _chainId;
        raffle.metadata = _metadata;
        raffle.rewardToken = _rewardToken;
        raffle.weight = _weight;
        raffle.status = RaffleStatus.Created;

        return index_;
    }

    /**
     * Cancel raffle can be called by the organiser of a raffle, but only while
     * the status of the raffle is Created, not yet Distributed.
     * On cancelling, the tokenIds the raffle contract owns for this raffle
     * are transferred to the organiser address.
     */
    function cancelRaffle(
        uint256 _index
    )
        external
        onlyOrganiser(_index)
        isInCreationPhase(_index)
    {
        raffles[_index].status = RaffleStatus.Cancelled;

        IERC721 raffleRewardToken = raffles[_index].rewardToken;
        uint256[] storage associatedTokenIds = rewardTokenIds[_index];

        // transfer all tokenIds to organiser
        for (uint256 i = 0; i < associatedTokenIds.length; i++) {
            raffleRewardToken.transferFrom(
                address(this),
                msg.sender,
                associatedTokenIds[i]);
        }

        delete rewardTokenIds[_index];
    }

    /**
     * Organiser can submit a proposal for the root of the raffle.
     * It starts a challenge period where independent observers can challenge
     * the proposed commit, leaving the final decision up to the arbiter.
     */
    function proposePrecommit(
        uint256 _index,
        bytes32 _precommit
    )
        external
        onlyOrganiser(_index)
        isInCreationPhase(_index)
    {
        require(
            _precommit != bytes32(0),
            "Precommit cannot be zero bytes."
        );

        raffles[_index].status = RaffleStatus.OrganiserPrecommitted;

        // store the proposed precommit by the organiser
        precommits[_index] = _precommit;

        // set time window to expire after challenge window;
        timeWindows[_index] = block.number + CHALLENGE_WINDOW;
    }

    /**
     * ChallengePrecommit allows anyone to challenge the precommit
     * presented by the raffle organiser. The challenger must deposit
     * the same weight in the token.
     * The final decision on the precommit is handed over to the arbiter.
     */
    function challengePrecommit(
        uint256 _index
    )
        external
        isInChallengePhase(_index)
    {
        raffles[_index].status = RaffleStatus.Challenged;

        // Pull in the same amount of token as set in weight
        token.transferFrom(msg.sender, address(this),
            raffles[_index].weight);

        challengers[_index] = msg.sender;
    }

    /**
     * Arbitrate in favour of challenger, and present final precommit.
     * Half of weight put forward by organiser is burnt;
     * Half of weight of organiser is awarded to challenger;
     * Challengers' weight returned to challenger.
     */
    function arbitrateRaffeForChallenger(
        uint256 _index,
        bytes32 _decision
    )
        external
        onlyArbiter()
        hasBeenChallenged(_index)
    {
        require(
            _decision != bytes32(0),
            "Decision cannot be zero bytes."
        );
        require(
            _decision != precommits[_index],
            "Decision must differ from organisers precommit."
        );

        raffles[_index].status = RaffleStatus.Precommitted;

        // set the future blockheight at which we can calculate a randomizer
        timeWindows[_index] = block.number + ENTROPY_WINDOW;

        // overwrite precommit for raffle
        precommits[_index] = _decision;

        address challenger = challengers[_index];
        delete challengers[_index];

        uint256 weight = raffles[_index].weight;
        uint256 burnAmount = weight / 2;
        // ensure sum is exact amounts present in balance; under division errors
        uint256 rewardAmount = 2 * weight - burnAmount;
        // burn half the weight
        token.burn(burnAmount);
        // award 3/2 of weight to challenger
        token.transfer(challenger, rewardAmount);
    }

    /**
     * Arbitrate in favour of organisers precommit.
     * Weight put forward by challenger is burnt;
     * weight of organiser is returned to organiser.
     */
    function arbitrateRaffeForOrganiser(
        uint256 _index
    )
        external
        onlyArbiter()
        hasBeenChallenged(_index)
    {
        raffles[_index].status = RaffleStatus.Precommitted;

        // set the future blockheight at which we can calculate a randomizer
        timeWindows[_index] = block.number + ENTROPY_WINDOW;

        delete challengers[_index];

        uint256 weight = raffles[_index].weight;
        // burn the weight from challenger
        token.burn(weight);
        // reimburse weight to organiser
        token.transfer(raffles[_index].organiser, weight);
    }

    /**
     * Precommit can be called when the challenge period of a proposed precommit
     * has passed. It then starts the entropy window to randomize the raffle.
     */
    function precommit(
        uint256 _index
    )
        external
        isInChallengePhase(_index)
    {
        require(
            timeWindows[_index] <= block.number,
            "Minimal challenge period must have expired before precommitting."
        );

        raffles[_index].status = RaffleStatus.Precommitted;

        // set the future blockheight at which we can calculate a randomizer
        timeWindows[_index] = block.number + ENTROPY_WINDOW;
    }

    /**
     * Draw raffle once the future block hashes are known to randomize the raffle.
     * Note that only the last 256 ethereum block hashes are available to the EVM
     * so if too much time has passed, then the raffle must be reshuffled first.
     */
    function drawRaffle(
        uint256 _index
    )
        external
        isInPrecommittedPhase(_index)
    {
        uint256 endBlock = timeWindows[_index];
        uint256 beginBlock = endBlock + uint256(1) - ENTROPY_LENGTH;
        require(
            endBlock < block.number,
            "The entropy window must have passed before raffle can be drawn."
        );
        require(
            beginBlock + uint256(256) >= block.number,
            "The window for accessing the block hashes has passed."
        );

        raffles[_index].status = RaffleStatus.Drawn;

        seeds[_index] = hashBlockSegment(_index, beginBlock);

        timeWindows[_index] = block.number + NOMINATION_COOLDOWN;
    }

    /**
     * Reshuffle allows the raffle to be unblocked if the access window has passed
     * where the EVM can access the fixed blockhashes;
     * reshuffle and draw again within (256 - ENTROPY_LENGTH) blocks window.
     */
    function reshuffleRaffle(
        uint256 _index
    )
        external
        isInPrecommittedPhase(_index)
    {
        uint256 windowPassedBlock = timeWindows[_index] + uint256(256) - ENTROPY_LENGTH;
        require(
            windowPassedBlock < block.number,
            "The drawing window has not yet passed, call draw() instead."
        );

        // reset the future blockheight at which we can calculate a randomizer
        timeWindows[_index] = block.number + ENTROPY_WINDOW;
    }

    function nominateTickets(
        uint256 _index,
        bytes32[] calldata _tickets,
        bytes32 _furtherTicket
    )
        external
        isInDrawnPhase(_index)
    {
        require(
            _tickets.length > 0 &&
            _tickets.length <= rewardTokenIds[_index].length,
            "No more tickets allowed than rewards."
        );
        require(
            nominations[_index][_furtherTicket] != bytes32(0),
            "Further ticket must be nominated."
        );

        bytes32 seed = seeds[_index];

        // Set distance to further ticket
        uint256 dFurtherTicket = SENTINEL_DISTANCE;
        if (_furtherTicket != SENTINEL_TICKETS) {
            dFurtherTicket = distanceToSeed(_furtherTicket, seed);
        }
        bytes32 furtherTicket = _furtherTicket;
        bytes32 nearerTicket = nominations[_index][_furtherTicket];

        for(uint256 i = 0; i < _tickets.length; i++) {
            bytes32 ticket = _tickets[i];
            require(
                ticket != bytes32(0) &&
                ticket != SENTINEL_TICKETS,
                "Ticket cannot be zero bytes or sentinel bytes."
            );
            require(
                nominations[_index][ticket] == bytes32(0),
                "Ticket cannot already be nominated."
            );

            // first calculate distance
            uint256 distanceTicket = distanceToSeed(ticket, seed);

            require(
                distanceTicket < dFurtherTicket,
                "Ticket must be nearer than further away ticket."
            );

            while (nearerTicket != SENTINEL_TICKETS) {
                // continue
            }

        }
    }

    /* Public Functions */

    /**
     * Distance to seed takes a ticket and a seed, first hashes the ticket
     * bytes with the seed, and then calculates the XOR distance to the seed
     * producing a randomised order over the tickets.
     */
    function distanceToSeed(
        bytes32 _ticket,
        bytes32 _seed
    )
        public
        pure
        returns (uint256 distance_)
    {
        distance_ = distance(shuffleTicket(_ticket, _seed), _seed);
    }


    /* Private Functions */

    /**
     * hashBlockSegment will hash together a sequence of blockhashes of length
     * ENTROPY_LENGTH starting at `_beginBlock`, additionally including
     * the raffle index and address of raffle contract to ensure
     * a unique seed for each raffle.
     */
    function hashBlockSegment(
        uint256 _index,
        uint256 _beginBlock
    )
        private
        view
        returns (bytes32 seed_)
    {
        bytes32[] memory seedGenerator = new bytes32[](ENTROPY_LENGTH);
        for (uint256 i = 0; i < ENTROPY_LENGTH; i++) {
            seedGenerator[i] = blockhash(_beginBlock + i);
        }

        seed_ = keccak256(
            abi.encodePacked(
                address(this),
                _index,
                seedGenerator
            )
        );
    }

    /**
     * Shuffle ticket additionally randomises the bits of the tickets,
     * even though strictly speaking the XOR distance measured from
     * a fixed random seed, already randomises the ordering of tickets.
     * But because we only need to hash the nominated tickets, we can
     * additionally randomise the ticket bytes prior to checking the distance
     * to the random seed.
     */
    function shuffleTicket(
        bytes32 _ticket,
        bytes32 _seed
    )
        private
        pure
        returns (bytes32 shuffledTicket_)
    {
        shuffledTicket_ = keccak256(
            abi.encodePacked(
                _ticket,
                _seed
            )
        );
    }

    /**
     * distance returns the XOR distance between two 32 byte values.
     * Beyond satisfying the required distance properties,
     * d(a, . ) is unique, making it useful to sort elements.
     * Additionally XOR is a perfect cypher for a message and key of equal length
     * so if `_a` is random, XOR randomises the ordering of all `_b`.
     * Nonetheless we additionally hash the tickets to randomise their bits as well.
     */
    function distance(bytes32 _a, bytes32 _b)
        private
        pure
        returns (uint256 distance_)
    {
        // return XOR(_a, _b) distance, which has the additional property
        // that for fixed _a, the distance to _b is unique to _b.
        distance_ = uint256(_a ^ _b);
    }
}
