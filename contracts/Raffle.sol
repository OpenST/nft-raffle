// SPDX-License-Identifier: MIT
// Copyright 2021 Mosaic Labs UG, Berlin
pragma solidity ^0.8.0;

import "hardhat/console.sol";

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

    /* Storage */



    /* Constructor */

    constructor() {
    }

}
