// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AritohamTypes.sol";

/**
 * AritohamDataStore
 * -------------
 * Write side. Only the main ARITOHAM contract (`core`) can call the record* functions.
 * Each record* function matches one event of the main contract:
 *
 *   UserRegistered            -> recordRegistration
 *   StakeCreated              -> recordStake
 *   TokensPurchased           -> recordPurchase
 *   TokensSold                -> recordSell
 *   DirectIncomeDistributed   -> recordDirectIncome
 *   StakeRoiClaimed           -> recordRoiClaim
 *   GenerationIncomeDistributed -> recordGenerationIncome
 *   RewardIncomeUpdated       -> recordRewardIncome
 *   RankIncentiveUpdated      -> recordRankIncentive
 *   DaoEligibleSet            -> recordDaoEligible
 *   DaoDistributed            -> recordDaoDistributed
 *   DaoRewardCredited         -> recordDaoReward
 *   Withdraw                  -> recordWithdraw
 *
 * Call order does not matter between record* functions, except that recordDaoDistributed
 * must be called BEFORE the recordDaoReward calls of that cycle.
 *
 * NOTE: a contract cannot read its own transaction hash. Each record stores
 * time + block number; the website gets the Txn Hash from the main contract's
 * event logs (match by block number) or from the indexer / explorer API.
 */
contract AritohamDataStore {
    // ───────────────────────────── access ─────────────────────────────
    error NotOwner();
    error NotCore();
    error AlreadyRegistered();
    error BadStakeIndex();
    error TooLarge();

    address public owner;
    address public core;

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier onlyCore()  { if (msg.sender != core)  revert NotCore();  _; }

    // ───────────────────────────── config ─────────────────────────────
    uint256 public constant LEVELS     = 20;
    uint256 public constant WINDOW     = 20 days;     // DAO lifetime qualification window
    uint256 public constant SHARE_STEP = 2500e18;     // every $2,500 weekly matching = 1 share
    uint256 public constant MAX_RANK   = 9;

    uint256 public maxTeamDepth   = 50;       // gas guard for upline walks (team business / daily matching)
    uint256 public activeDirectMin = 50e18;   // direct counts as "active" from $50
    uint256 public dailyLimit     = 3000e18;  // sell + withdraw limit per rolling 24h
    uint256 public daoBps         = 500;      // 5% of every deposit goes to the DAO pool
    uint256 public dailyRewardPpm = 12530;    // used only to show "Reward Amount" per stake (1.2530%)

    // ───────────────────────────── records ────────────────────────────
    struct StakeRec    { uint40 time; uint128 usdt; uint128 tokens; uint128 claimed; uint32 claims; }
    struct PurchaseRec { uint40 time; uint40 blockNo; uint128 usdt; uint128 tokens; uint128 price; }
    struct DirectRec   { uint40 time; address from; uint128 minted; uint128 income; }
    struct GenRec      { uint40 time; address from; uint8 level; uint128 base; uint128 income; }
    struct RoiRec      { uint40 time; uint32 stakeIndex; uint32 periods; uint128 base; uint128 earned; }
    struct RankRec     { uint40 time; uint8 rank; uint64 refId; uint128 amount; }
    struct SellRec     { uint40 time; uint128 aritoham; uint128 usdt; uint128 price; }
    struct WithdrawRec { uint40 time; uint128 amount; uint128 fee; uint128 tokens; uint128 price; }
    struct DaoPayout   { address wallet; uint40 time; uint32 cycle; uint128 reward; uint128 weeklyMatching; uint32 shares; }
    struct Ptr         { uint32 cycle; uint32 index; }
    struct PricePoint  { uint40 time; uint128 price; }
    struct DayBucket   { uint128 teamAll; uint128 teamL20; }

    // user data
    mapping(address => User)   internal _users;
    mapping(address => Income) internal _income;
    mapping(address => Flow)   internal _flow;
    mapping(uint32  => address) public idToUser;
    mapping(address => address[]) internal _directs;
    uint32  public nextUserId = 1000001;
    uint256 public totalUsers;
    uint256 public totalDeposits;

    // record tables (per user, oldest -> newest)
    mapping(address => StakeRec[])    public stakes;
    mapping(address => PurchaseRec[]) public purchases;
    mapping(address => DirectRec[])   public directRecs;
    mapping(address => GenRec[])      public genRecs;
    mapping(address => RoiRec[])      public roiRecs;
    mapping(address => RankRec[])     public rankRewardRecs;
    mapping(address => RankRec[])     public rankIncentiveRecs;
    mapping(address => SellRec[])     public sells;
    mapping(address => WithdrawRec[]) public withdraws;
    mapping(address => Ptr[])         public userDaoPayouts;

    // time buckets (UTC day = block.timestamp / 1 days)
    mapping(address => mapping(uint256 => DayBucket)) public dayBuckets;       // team business per day
    mapping(address => mapping(uint256 => uint128))   public dayDirectBusiness;
    mapping(address => mapping(uint256 => uint32))    public dayNewDirects;
    mapping(address => mapping(uint256 => uint128))   public dayIncome;

    // ranks
    mapping(uint256 => RankCfg) internal _rankCfg;

    // DAO
    uint256 public currentCycle = 1;
    uint256 public lastDistributedCycle;
    uint256 public lifetimeHolders;
    mapping(uint256 => uint256)   public cycleDeposit;
    mapping(uint256 => DaoCycle)  internal _daoCycles;
    mapping(uint256 => address[]) public eligibleWallets;
    mapping(uint256 => uint256)   public eligibleAdded;
    mapping(uint256 => DaoPayout[]) public cyclePayouts;

    // market chart (one point per hour)
    PricePoint[] public pricePoints;
    uint128 public latestPrice;
    uint256 private _lastPriceHour;

    constructor(address _core) {
        owner = msg.sender;
        core  = _core;
        //          rank selfMinted matching  reward directs incentive%
        _setRank(1, 100e18,  5_000e18,       0e18,  3,  800);   // Spark
        _setRank(2, 200e18,  10_000e18,      0e18,  5, 1000);   // Rise
        _setRank(3, 300e18,  25_000e18,    500e18,  7, 1200);   // Prime
        _setRank(4, 400e18,  50_000e18,    750e18,  9, 1500);   // Elite
        _setRank(5, 500e18,  100_000e18,  1750e18, 11, 1800);   // Legend
        _setRank(6, 600e18,  250_000e18,  5750e18, 12, 2000);   // Titan
        _setRank(7, 700e18,  500_000e18, 11250e18, 13, 2500);   // Crown
        _setRank(8, 800e18,  1_000_000e18, 25000e18, 14, 3000); // Royal
        _setRank(9, 1000e18, 2_500_000e18, 80000e18, 15, 3500); // Emperor
    }

    // ═══════════════════════ WRITE: called by main contract ═══════════════════════

    /// emit UserRegistered(msg.sender, _referrer)
    function recordRegistration(address user, address referrer) external onlyCore {
        User storage u = _users[user];
        if (u.registeredAt != 0) revert AlreadyRegistered();
        u.referrer = referrer;
        u.registeredAt = uint40(block.timestamp);
        u.id = nextUserId++;
        idToUser[u.id] = user;
        totalUsers++;

        if (referrer == address(0)) return;
        _directs[referrer].push(user);
        _users[referrer].directCount++;
        dayNewDirects[referrer][_day()]++;

        address up = referrer;
        for (uint256 i; i < maxTeamDepth && up != address(0); i++) {
            _users[up].teamCount++;
            up = _users[up].referrer;
        }
    }

    /// emit StakeCreated(msg.sender, usdtAmount, tokens, stakeIndex)
    function recordStake(address user, uint256 usdt, uint256 tokens, uint256 stakeIndex) external onlyCore {
        if (stakeIndex != stakes[user].length) revert BadStakeIndex();
        uint128 amt = _u128(usdt);
        User storage u = _users[user];

        bool first = u.selfStaked == 0;
        if (u.activatedAt == 0) u.activatedAt = uint40(block.timestamp);
        uint128 prev = u.selfStaked;
        u.selfStaked = prev + amt;
        u.stakeCount++;

        stakes[user].push(StakeRec(uint40(block.timestamp), amt, _u128(tokens), 0, 0));
        totalDeposits += usdt;
        cycleDeposit[currentCycle] += usdt;

        address ref = u.referrer;
        if (ref == address(0)) return;
        bool crossed = prev < activeDirectMin && u.selfStaked >= activeDirectMin;
        _stakeToReferrer(ref, amt, crossed);
        _stakeToUpline(ref, amt, first);
    }

    /// emit TokensPurchased(msg.sender, usdtAmount, tokens, priceAtMint)
    function recordPurchase(address user, uint256 usdt, uint256 tokens, uint256 price) external onlyCore {
        purchases[user].push(PurchaseRec(uint40(block.timestamp), uint40(block.number), _u128(usdt), _u128(tokens), _u128(price)));
        _touchPrice(price);
    }

    /// emit TokensSold(msg.sender, tokenAmount, payout, priceAtSell)
    function recordSell(address user, uint256 tokenAmount, uint256 payout, uint256 price) external onlyCore {
        sells[user].push(SellRec(uint40(block.timestamp), _u128(tokenAmount), _u128(payout), _u128(price)));
        Flow storage f = _flow[user];
        if (block.timestamp >= uint256(f.sStart) + 1 days) { f.sStart = uint40(block.timestamp); f.sInWindow = 0; }
        f.sInWindow += _u128(payout);   // main contract counts the 85% payout against the 3000 limit
        f.soldAritoham  += _u128(tokenAmount);
        f.soldUsdt  += _u128(payout);
        _touchPrice(price);
    }

    /// emit DirectIncomeDistributed(user, referrer, reward)  + minted = gross stake   (user = who minted, referrer = receiver)
    function recordDirectIncome(address user, address referrer, uint256 reward, uint256 minted) external onlyCore {
        directRecs[referrer].push(DirectRec(uint40(block.timestamp), user, _u128(minted), _u128(reward)));
        _credit(referrer, reward, 0);
    }

    /// emit StakeRoiClaimed(msg.sender, i, totalInvestment, earned, periodsPassed)
    function recordRoiClaim(address user, uint256 stakeIndex, uint256 totalInvestment, uint256 earned, uint256 periodsPassed) external onlyCore {
        StakeRec storage s = stakes[user][stakeIndex];
        s.claimed += _u128(earned);
        s.claims++;
        roiRecs[user].push(RoiRec(uint40(block.timestamp), uint32(stakeIndex), uint32(periodsPassed), _u128(totalInvestment), _u128(earned)));
        _credit(user, earned, 2);
    }

    /// emit GenerationIncomeDistributed(claimer, current, level, reward) + base = total ROI claimed  (current = receiver)
    function recordGenerationIncome(address claimer, address receiver, uint256 level, uint256 reward, uint256 base) external onlyCore {
        genRecs[receiver].push(GenRec(uint40(block.timestamp), claimer, uint8(level), _u128(base), _u128(reward)));
        _credit(receiver, reward, 1);
    }

    /// emit RewardIncomeUpdated(user, amount, currentRank)
    function recordRewardIncome(address user, uint256 amount, uint256 rank) external onlyCore {
        _users[user].rank = uint8(rank);
        rankRewardRecs[user].push(RankRec(uint40(block.timestamp), uint8(rank), 0, _u128(amount)));
        if (amount > 0) _credit(user, amount, 4);
    }

    /// emit RankIncentiveUpdated(id, user, amount, currentRank, timestamp)
    function recordRankIncentive(uint256 id, address user, uint256 amount, uint256 rank, uint256 ts) external onlyCore {
        rankIncentiveRecs[user].push(RankRec(uint40(ts), uint8(rank), uint64(id), _u128(amount)));
        _credit(user, amount, 5);
    }

    /// emit DaoEligibleSet(cycle, wallets.length, added)   (pass the wallets array too)
    function recordDaoEligible(uint256 cycle, address[] calldata wallets, uint256 added) external onlyCore {
        address[] storage list = eligibleWallets[cycle];
        for (uint256 i; i < wallets.length; i++) {
            address w = wallets[i];
            list.push(w);
            if (!_users[w].daoLifetime) { _users[w].daoLifetime = true; lifetimeHolders++; }
        }
        eligibleAdded[cycle] = added;
    }

    /// emit DaoDistributed(payCycle, daoPayPool, list.length)
    function recordDaoDistributed(uint256 cycle, uint256 pool, uint256 count) external onlyCore {
        _daoCycles[cycle] = DaoCycle(uint40(block.timestamp), true, uint32(count), 0, _u128(pool));
        lastDistributedCycle = cycle;
        if (cycle + 1 > currentCycle) currentCycle = cycle + 1;   // new deposits go to the next cycle
    }

    /// emit DaoRewardCredited(w, reward) + shares   (belongs to lastDistributedCycle)
    function recordDaoReward(address wallet, uint256 reward, uint256 shares) external onlyCore {
        uint256 cyc = lastDistributedCycle;
        uint256 wm  = weeklyMatching(wallet);
        uint256 sh  = shares;
        DaoPayout[] storage arr = cyclePayouts[cyc];
        userDaoPayouts[wallet].push(Ptr(uint32(cyc), uint32(arr.length)));
        arr.push(DaoPayout(wallet, uint40(block.timestamp), uint32(cyc), _u128(reward), _u128(wm), uint32(sh)));
        _daoCycles[cyc].totalShares += uint32(sh);
        _credit(wallet, reward, 3);
    }

    /// emit Withdraw(msg.sender, amount, tokens, fee, currentPrice)
    function recordWithdraw(address user, uint256 amount, uint256 tokens, uint256 fee, uint256 price) external onlyCore {
        withdraws[user].push(WithdrawRec(uint40(block.timestamp), _u128(amount), _u128(fee), _u128(tokens), _u128(price)));
        Flow storage f = _flow[user];
        if (block.timestamp >= uint256(f.wStart) + 1 days) { f.wStart = uint40(block.timestamp); f.wInWindow = 0; }
        f.wInWindow    += _u128(amount);
        f.withdrawnUsd += _u128(amount);
        f.withdrawnAritoham += _u128(tokens);
        _touchPrice(price);
    }

    /// Reset ONE user's rank, business and DAO systems in a single call (main contract only).
    /// Referral tree counters (directCount, teamCount, ...) and selfStaked are kept.
    function resetRankBusinessDao(address user) external onlyCore {
        User storage u = _users[user];

        // ── rank ──
        u.rank = 0;
        delete rankRewardRecs[user];
        delete rankIncentiveRecs[user];

        // ── business ──
        u.directBusiness   = 0;
        u.teamBusiness     = 0;
        u.matchingBusiness = 0;
        u.windowDirect     = 0;
        u.windowMatching   = 0;
        uint256 d = _day();
        for (uint256 i; i < 7 && i <= d; i++) {          // today + previous 6 days feed weekly matching
            delete dayBuckets[user][d - i];
            delete dayDirectBusiness[user][d - i];
        }

        // ── DAO ──
        if (u.daoLifetime) {
            u.daoLifetime = false;
            if (lifetimeHolders > 0) lifetimeHolders--;
        }
        if (u.activatedAt != 0) u.activatedAt = uint40(block.timestamp);   // 20-day window restarts now
        delete userDaoPayouts[user];
        address[] storage list = eligibleWallets[currentCycle];            // drop from current cycle list
        for (uint256 i; i < list.length; i++) {
            if (list[i] == user) { list[i] = list[list.length - 1]; list.pop(); break; }
        }

        // ── income totals shown on the website ──
        Income storage inc = _income[user];
        inc.rankReward = 0; inc.rankIncentive = 0; inc.dao = 0;
    }

    // ═══════════════════════ READ (used by AritohamDataReader) ═══════════════════════

    function getUser(address a)   external view returns (User memory)   { return _users[a]; }
    function getIncome(address a) external view returns (Income memory) { return _income[a]; }
    function getFlow(address a)   external view returns (Flow memory)   { return _flow[a]; }
    function getRankCfg(uint256 r) external view returns (RankCfg memory) { return _rankCfg[r]; }
    function getDaoCycle(uint256 c) external view returns (DaoCycle memory) { return _daoCycles[c]; }
    function getDirects(address a) external view returns (address[] memory) { return _directs[a]; }

    function eligibleLength(uint256 c) external view returns (uint256) { return eligibleWallets[c].length; }
    function cyclePayoutsLength(uint256 c) external view returns (uint256) { return cyclePayouts[c].length; }
    function pricePointsLength() external view returns (uint256) { return pricePoints.length; }

    /// [0]stakes [1]purchases [2]directRecs [3]genRecs [4]roiRecs [5]rankReward [6]rankIncentive [7]sells [8]withdraws [9]daoPayouts [10]directs
    function counts(address a) external view returns (uint256[11] memory c) {
        c[0] = stakes[a].length;           c[1] = purchases[a].length;
        c[2] = directRecs[a].length;       c[3] = genRecs[a].length;
        c[4] = roiRecs[a].length;          c[5] = rankRewardRecs[a].length;
        c[6] = rankIncentiveRecs[a].length; c[7] = sells[a].length;
        c[8] = withdraws[a].length;        c[9] = userDaoPayouts[a].length;
        c[10] = _directs[a].length;
    }

    /// Weekly Matching: stake of users within 20 levels below, today + previous 6 UTC days.
    function weeklyMatching(address a) public view returns (uint256 sum) {
        uint256 d = _day();
        for (uint256 i; i < 7 && i <= d; i++) sum += dayBuckets[a][d - i].teamL20;
    }

    /// Daily Matching: stake of ALL users below (up to maxTeamDepth), current UTC day.
    function dailyMatching(address a) public view returns (uint256) {
        return dayBuckets[a][_day()].teamAll;
    }

    // ═══════════════════════ ADMIN ═══════════════════════

    function setCore(address c) external onlyOwner { core = c; }
    function transferOwnership(address o) external onlyOwner { owner = o; }
    function setMaxTeamDepth(uint256 v) external onlyOwner { maxTeamDepth = v; }
    function setActiveDirectMin(uint256 v) external onlyOwner { activeDirectMin = v; }
    function setDailyLimit(uint256 v) external onlyOwner { dailyLimit = v; }
    function setDaoBps(uint256 v) external onlyOwner { daoBps = v; }
    function setDailyRewardPpm(uint256 v) external onlyOwner { dailyRewardPpm = v; }
    function setRank(uint256 r, uint256 self_, uint256 matching, uint256 reward, uint256 directs_, uint256 bps) external onlyOwner {
        _setRank(r, self_, matching, reward, directs_, bps);
    }

    // ═══════════════════════ INTERNAL ═══════════════════════

    function _stakeToReferrer(address ref, uint128 amt, bool crossed) private {
        User storage r = _users[ref];
        r.directBusiness += amt;
        if (crossed) r.activeDirects++;
        if (r.activatedAt != 0 && block.timestamp <= uint256(r.activatedAt) + WINDOW) r.windowDirect += amt;
        dayDirectBusiness[ref][_day()] += amt;
    }

    function _stakeToUpline(address ref, uint128 amt, bool first) private {
        address up = ref;
        uint256 d = _day();
        for (uint256 lvl = 1; lvl <= maxTeamDepth && up != address(0); lvl++) {
            User storage a = _users[up];
            a.teamBusiness += amt;
            if (first) a.contributingCount++;
            DayBucket storage b = dayBuckets[up][d];
            b.teamAll += amt;
            if (lvl <= LEVELS) {
                a.matchingBusiness += amt;
                b.teamL20 += amt;
                if (a.activatedAt != 0 && block.timestamp <= uint256(a.activatedAt) + WINDOW) a.windowMatching += amt;
            }
            up = a.referrer;
        }
    }

    /// kind: 0 direct, 1 generation, 2 roi, 3 dao, 4 rankReward, 5 rankIncentive
    function _credit(address w, uint256 amt, uint8 kind) private {
        uint128 a = _u128(amt);
        Income storage i = _income[w];
        if      (kind == 0) i.direct        += a;
        else if (kind == 1) i.generation    += a;
        else if (kind == 2) i.roi           += a;
        else if (kind == 3) i.dao           += a;
        else if (kind == 4) i.rankReward    += a;
        else                i.rankIncentive += a;
        dayIncome[w][_day()] += a;
    }

    function _touchPrice(uint256 price) private {
        latestPrice = _u128(price);
        uint256 h = block.timestamp / 1 hours;
        if (h != _lastPriceHour) {
            _lastPriceHour = h;
            pricePoints.push(PricePoint(uint40(block.timestamp), _u128(price)));
        }
    }

    function _setRank(uint256 r, uint256 self_, uint256 matching, uint256 reward, uint256 directs_, uint256 bps) private {
        _rankCfg[r] = RankCfg(_u128(self_), _u128(matching), _u128(reward), uint32(directs_), uint16(bps));
    }

    function _day() private view returns (uint256) { return block.timestamp / 1 days; }

    function _u128(uint256 x) private pure returns (uint128) {
        if (x > type(uint128).max) revert TooLarge();
        return uint128(x);
    }
}
