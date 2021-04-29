// SPDX-License-Identifier: MIT
// Copyright 2021 Mosaic Labs UG, Berlin
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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
      // ChainId EIP-155 of where the raffle is distributed
      uint256 chaindId;
      // Metadata contract on chain with chainId for indexing
      // all valid raffle tickets
      address metadata;
      // Organiser address who initiated organises the raffle
      address organiser;
      // Status enum of raffle
      RaffleStatus status;
      // Reward ERC721 NFT token contract
      IERC721 rewardToken;
    }

    /* Storage */

    /**
     * ERC20 token contract used for mechanics.
     * On Ethereum mainnet set to OST @ 0x2c4e8f2d746113d0696ce89b35f0d8bf88e0aeca
     */
    IERC20 public token;

    /**
     * Raffles stores essential data and references for the active raffles.
     */
    mapping(uint256 => RaffleData) public raffles;

    /* Constructor */

    constructor() {
    }

}
