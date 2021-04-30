// SPDX-License-Identifier: MIT
// Copyright 2021 Mosaic Labs UG, Berlin
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title Raffle contract for NFTs
 * @author Benjamin Bollen <ben@mosaiclabs.eu>
 */
contract Raffle {

    /* Constants */

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
       * Distributed. All metadata and all valid transactions
       * that constitute the raffle tickets have been committed.
       * Indexers can compute the precommit root of the raffle.
       * The initial precommit must be presented by the organiser
       * of the raffle.
       * Afterwards competing precommits can be presented.
       */
      Distributed,

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
      Cancelled
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
    IERC20 public token;

    /** Index counts the number of raffles created */
    uint256 public index;

    /** Reward tokenIds keeps a record of all the ERC721 tokenIds
     * for each raffle index.
    * Note that each raffle has a specified ERC721 address.
     */
    mapping(uint256 => uint256[]) public _rewardTokenIds;

    /**
     * Raffles stores essential data and references for the active raffles.
     */
    mapping(uint256 => RaffleData) public raffles;

    /* Modifiers */

    modifier isInCreationPhase(uint256 _index) {
        require(
            raffles[_index].status == RaffleStatus.Created,
            "Raffle must be created and not yet distributed."
        );
        _;
    }

    /* Constructor */

    /**
     * On construction the token contract for the raffle mechanics must be set.
     */
    constructor(IERC20 _token) {
        console.log("Deploying raffle contract with token ", address(_token));
        token = _token;
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

        // Transfer all the NFT rewards into the raffle contract
        // Note, for simplicity this is done during creation, but can be altered
        for (uint64 i = 0; i < _tokenIds.length; i++ ) {

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

    // function addRewards(
    //     uint256 _index,
    //     uint256[] _ids
    // )
    //     external
    //     onlyOrganiser(_index)
    // {

    // }

    // /**
    //  * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
    //  * by `operator` from `from`, this function is called.
    //  *
    //  * It must return its Solidity selector to confirm the token transfer.
    //  * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
    //  *
    //  * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
    //  */
    // function onERC721Received(
    //     address operator,
    //     address from,
    //     uint256 tokenId,
    //     bytes calldata data
    // )
    //     external returns (bytes4)
    // {
    //     return IERC721(this).onERC721Received.selector;
    // }
}
