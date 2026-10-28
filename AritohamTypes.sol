// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Structs shared by AritohamDataStore and AritohamDataReader.

struct User {
    address referrer;          // slot 1
    uint40  registeredAt;
    uint40  activatedAt;       // time of first stake (start of the 20-day DAO window)
    uint8   rank;              // 0 = No Rank, 1..9 = Spark..Emperor
    bool    daoLifetime;       // lifetime DAO share holder
    uint32  id;                // slot 2  (website shows "HWN" + id)
    uint32  directCount;
    uint32  activeDirects;     // directs with total stake >= activeDirectMin
    uint32  teamCount;         // all downline members (up to maxTeamDepth)
    uint32  contributingCount; // downline members who have staked
    uint32  stakeCount;
    uint128 directBusiness;    // slot 3 - stake of level-1 users
    uint128 teamBusiness;      //          stake of full team
    uint128 matchingBusiness;  // slot 4 - stake of users within 20 levels below
    uint128 selfStaked;
    uint128 windowDirect;      // slot 5 - direct business inside own 20-day window
    uint128 windowMatching;    //          matching business inside own 20-day window
}

struct Income {
    uint128 direct;
    uint128 generation;
    uint128 roi;               // "Reward Income" / emission rewards
    uint128 dao;
    uint128 rankReward;        // "Rank Income" (one-time)
    uint128 rankIncentive;     // recurring
}

struct Flow {
    uint128 withdrawnUsd;
    uint128 withdrawnAritoham;
    uint128 soldAritoham;
    uint128 soldUsdt;
    uint128 wInWindow;         // USD withdrawn inside current 24h window
    uint128 sInWindow;         // USD value sold inside current 24h window
    uint40  wStart;
    uint40  sStart;
}

struct RankCfg {
    uint128 selfMinted;
    uint128 matching;
    uint128 reward;            // one-time rank reward ("Income Amount")
    uint32  directs;           // active directs needed
    uint16  incentiveBps;
}

struct DaoCycle {
    uint40  time;
    bool    paid;
    uint32  members;
    uint32  totalShares;
    uint128 pool;
}
