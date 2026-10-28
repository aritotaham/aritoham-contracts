// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AritohamTypes.sol";
import "./IAritohamDataStore.sol";

/**
 * AritohamDataReader
 * --------------
 * Read side for the website. No state, no writes. Every table function is
 * paginated and returns newest records first: (page, total).
 * Amounts are 18-decimals. Date / Txn-hash / User-ID filters are done by the
 * website (records carry time + blockNo; the Txn Hash comes from event logs).
 */
contract AritohamDataReader {
    IAritohamDataStore public immutable store;

    uint256 public constant MAX_PAGE = 100;
    uint256 public constant MAX_SCAN = 5000;      // max downline members scanned in one call
    uint256 public constant SHARE_STEP = 2500e18;
    uint256 public constant LEVELS = 20;

    constructor(address _store) { store = IAritohamDataStore(_store); }

    // ═════════════════════════ view structs ═════════════════════════

    struct IncomeView { uint256 direct; uint256 reward; uint256 generation; uint256 dao; uint256 rankIncome; uint256 rankIncentive; uint256 total; uint256 today; }
    struct BusinessView {
        uint256 directBusiness; uint256 teamBusiness; uint256 matchingBusiness;
        uint256 weeklyMatching; uint256 dailyMatching;
        uint256 directMembers; uint256 activeDirects; uint256 totalMembers; uint256 contributingMembers; uint256 levelEligibility;
        uint256 todayDirectBusiness; uint256 todayTeamBusiness; uint256 todayNewMembers;
    }
    struct RankProgress { uint8 current; string currentName; uint8 next; string nextName; uint256 matchingNow; uint256 matchingTarget; uint256 progressBps; uint256 rewardOnCompletion; }
    struct LimitView { uint256 sellLimit; uint256 sellLeft; uint256 withdrawLimit; uint256 withdrawLeft; uint256 totalWithdrawn; uint256 availableEstimate; }
    struct DaoOverview { uint256 cycle; uint256 contractDeposit; uint256 pool; uint256 lifetimeHolders; uint256 weeklyEligible; uint256 totalShares; uint256 valuePerShare; }
    struct Dashboard {
        uint32 userId; address referrer; uint32 referrerId; uint40 joinedAt;
        uint256 totalMinted; uint256 price;
        IncomeView income; BusinessView business; RankProgress rank; LimitView limits; DaoOverview dao;
    }

    struct PurchaseItem { uint40 time; uint40 blockNo; uint256 usdt; uint256 tokens; uint256 price; uint256 rewardAmount; }
    struct WithdrawItem { uint40 time; uint256 amount; uint256 fee; uint256 tokens; uint256 price; }
    struct SellItem     { uint40 time; uint256 aritoham; uint256 usdt; uint256 price; }
    struct RoiItem      { uint40 time; uint32 stakeIndex; uint32 periods; uint256 base; uint256 earned; uint256 percentBps; }
    struct DirectItem   { uint40 time; address from; uint32 fromId; uint256 minted; uint256 income; uint256 commissionBps; }
    struct GenItem      { uint40 time; address from; uint32 fromId; uint8 level; uint256 base; uint256 income; uint256 percentBps; }
    struct RankItem     { uint40 time; uint8 rank; string rankName; uint64 refId; uint256 amount; }
    struct StakeItem    { uint40 time; uint256 usdt; uint256 tokens; uint256 claimed; uint32 claims; }


    struct RankRow { uint8 rank; string name; uint256 selfMinted; uint256 directs; uint256 matching; uint256 incentiveBps; uint256 incomeAmount; bool achieved; bool next; }

    // ═════════════════════════ DASHBOARD ═════════════════════════

    function getDashboard(address a) external view returns (Dashboard memory d) {
        User memory u = store.getUser(a);
        d.userId = u.id;
        d.referrer = u.referrer;
        d.referrerId = store.getUser(u.referrer).id;
        d.joinedAt = u.registeredAt;
        d.totalMinted = u.selfStaked;
        d.price = store.latestPrice();
        d.income = _incomeView(a);
        d.business = _businessView(a, u);
        d.rank = _rankProgress(u);
        d.limits = _limitView(a, d.income.total);
        d.dao = getDaoOverview();
    }

    /// Hourly price points for the "ARITOHAM Price Movement" chart (last `n` points, oldest first).
    function getPriceHistory(uint256 n) external view returns (uint40[] memory times, uint256[] memory prices) {
        uint256 len = store.pricePointsLength();
        if (n > len) n = len;
        times = new uint40[](n); prices = new uint256[](n);
        for (uint256 i; i < n; i++) (times[i], ) = store.pricePoints(len - n + i);
        for (uint256 i; i < n; i++) { (, uint128 p) = store.pricePoints(len - n + i); prices[i] = p; }
    }

    // ═════════════════════════ PROTOCOL PARTICIPATION / SELL / WITHDRAW ═════════════════════════

    function getParticipationHistory(address a, uint256 offset, uint256 limit) external view returns (PurchaseItem[] memory page, uint256 total) {
        total = store.counts(a)[1];
        uint256 n = _range(total, offset, limit);
        page = new PurchaseItem[](n);
        uint256 ppm = store.dailyRewardPpm();
        for (uint256 i; i < n; i++) {
            (uint40 t, uint40 b, uint128 usd, uint128 tok, uint128 pr) = store.purchases(a, total - 1 - offset - i);
            page[i] = PurchaseItem(t, b, usd, tok, pr, uint256(usd) * ppm / 1e6);
        }
    }

    function getStakes(address a, uint256 offset, uint256 limit) external view returns (StakeItem[] memory page, uint256 total) {
        total = store.counts(a)[0];
        uint256 n = _range(total, offset, limit);
        page = new StakeItem[](n);
        for (uint256 i; i < n; i++) {
            (uint40 t, uint128 usd, uint128 tok, uint128 cl, uint32 c) = store.stakes(a, total - 1 - offset - i);
            page[i] = StakeItem(t, usd, tok, cl, c);
        }
    }

    function getWithdrawHistory(address a, uint256 offset, uint256 limit) external view returns (WithdrawItem[] memory page, uint256 total) {
        total = store.counts(a)[8];
        uint256 n = _range(total, offset, limit);
        page = new WithdrawItem[](n);
        for (uint256 i; i < n; i++) {
            (uint40 t, uint128 amt, uint128 fee, uint128 tok, uint128 pr) = store.withdraws(a, total - 1 - offset - i);
            page[i] = WithdrawItem(t, amt, fee, tok, pr);
        }
    }

    function getSellHistory(address a, uint256 offset, uint256 limit) external view returns (SellItem[] memory page, uint256 total) {
        total = store.counts(a)[7];
        uint256 n = _range(total, offset, limit);
        page = new SellItem[](n);
        for (uint256 i; i < n; i++) {
            (uint40 t, uint128 h, uint128 usd, uint128 pr) = store.sells(a, total - 1 - offset - i);
            page[i] = SellItem(t, h, usd, pr);
        }
    }

    /// Sell Report header: ARITOHAM Sold, USDT Received, 24H Limit Remaining, number of sales.
    function getSellSummary(address a) external view returns (uint256 aritohamSold, uint256 usdtReceived, uint256 limitLeft, uint256 sales) {
        Flow memory f = store.getFlow(a);
        return (f.soldAritoham, f.soldUsdt, _left(f.sStart, f.sInWindow), store.counts(a)[7]);
    }

    // ═════════════════════════ INCOME TABLES ═════════════════════════

    /// Emission Rewards history (+ total claimed for the badge).
    function getEmissionHistory(address a, uint256 offset, uint256 limit) external view returns (RoiItem[] memory page, uint256 total, uint256 totalClaimed) {
        total = store.counts(a)[4];
        totalClaimed = store.getIncome(a).roi;
        uint256 n = _range(total, offset, limit);
        page = new RoiItem[](n);
        for (uint256 i; i < n; i++) {
            (uint40 t, uint32 idx, uint32 per, uint128 base, uint128 earned) = store.roiRecs(a, total - 1 - offset - i);
            page[i] = RoiItem(t, idx, per, base, earned, base == 0 ? 0 : uint256(earned) * 10000 / base);
        }
    }

    function getDirectIncomeHistory(address a, uint256 offset, uint256 limit) external view returns (DirectItem[] memory page, uint256 total, uint256 totalIncome) {
        total = store.counts(a)[2];
        totalIncome = store.getIncome(a).direct;
        uint256 n = _range(total, offset, limit);
        page = new DirectItem[](n);
        for (uint256 i; i < n; i++) {
            (uint40 t, address from, uint128 minted, uint128 inc) = store.directRecs(a, total - 1 - offset - i);
            page[i] = DirectItem(t, from, store.getUser(from).id, minted, inc, minted == 0 ? 0 : uint256(inc) * 10000 / minted);
        }
    }

    function getGenerationHistory(address a, uint256 offset, uint256 limit) external view returns (GenItem[] memory page, uint256 total, uint256 totalIncome) {
        total = store.counts(a)[3];
        totalIncome = store.getIncome(a).generation;
        uint256 n = _range(total, offset, limit);
        page = new GenItem[](n);
        for (uint256 i; i < n; i++) {
            (uint40 t, address from, uint8 lvl, uint128 base, uint128 inc) = store.genRecs(a, total - 1 - offset - i);
            page[i] = GenItem(t, from, store.getUser(from).id, lvl, base, inc, base == 0 ? 0 : uint256(inc) * 10000 / base);
        }
    }

    /// Rank history. incentive = true -> "Rank Incentive" tab, false -> "Rank Reward" tab.
    function getRankHistory(address a, bool incentive, uint256 offset, uint256 limit) external view returns (RankItem[] memory page, uint256 total) {
        total = store.counts(a)[incentive ? 6 : 5];
        uint256 n = _range(total, offset, limit);
        page = new RankItem[](n);
        for (uint256 i; i < n; i++) {
            uint256 idx = total - 1 - offset - i;
            (uint40 t, uint8 r, uint64 ref, uint128 amt) = incentive ? store.rankIncentiveRecs(a, idx) : store.rankRewardRecs(a, idx);
            page[i] = RankItem(t, r, rankName(r), ref, amt);
        }
    }

    /// Rank Incentive Roadmap with achieved / next flags for this user.
    function getRankRoadmap(address a) external view returns (RankRow[9] memory rows) {
        uint8 cur = store.getUser(a).rank;
        for (uint256 r = 1; r <= 9; r++) {
            RankCfg memory c = store.getRankCfg(r);
            rows[r - 1] = RankRow(uint8(r), rankName(r), c.selfMinted, c.directs, c.matching, c.incentiveBps, c.reward, cur >= r, cur + 1 == r);
        }
    }

    // ═════════════════════════ DAO overview (also used by dashboard) ═════════════════════════

    function getDaoOverview() public view returns (DaoOverview memory o) {
        uint256 c = store.currentCycle();
        o.cycle = c;
        o.contractDeposit = store.cycleDeposit(c);
        o.pool = o.contractDeposit * store.daoBps() / 10000;
        o.lifetimeHolders = store.lifetimeHolders();
        o.weeklyEligible = store.eligibleLength(c);
        o.totalShares = o.lifetimeHolders;                       // estimate: 1 share per holder (see notes)
        o.valuePerShare = o.totalShares == 0 ? 0 : o.pool / o.totalShares;
    }

    // ═════════════════════════ helpers ═════════════════════════

    function rankName(uint256 r) public pure returns (string memory) {
        if (r == 1) return "Spark";  if (r == 2) return "Rise";   if (r == 3) return "Prime";
        if (r == 4) return "Elite";  if (r == 5) return "Legend"; if (r == 6) return "Titan";
        if (r == 7) return "Crown";  if (r == 8) return "Royal";  if (r == 9) return "Emperor";
        return "No Rank";
    }

    function _incomeView(address a) internal view returns (IncomeView memory v) {
        Income memory i = store.getIncome(a);
        v.direct = i.direct; v.reward = i.roi; v.generation = i.generation; v.dao = i.dao;
        v.rankIncome = i.rankReward; v.rankIncentive = i.rankIncentive;
        v.total = uint256(i.direct) + i.roi + i.generation + i.dao + i.rankReward + i.rankIncentive;
        v.today = store.dayIncome(a, block.timestamp / 1 days);
    }

    function _businessView(address a, User memory u) internal view returns (BusinessView memory b) {
        uint256 d = block.timestamp / 1 days;
        b.directBusiness = u.directBusiness; b.teamBusiness = u.teamBusiness; b.matchingBusiness = u.matchingBusiness;
        b.weeklyMatching = store.weeklyMatching(a); b.dailyMatching = store.dailyMatching(a);
        b.directMembers = u.directCount; b.activeDirects = u.activeDirects;
        b.totalMembers = u.teamCount; b.contributingMembers = u.contributingCount; b.levelEligibility = LEVELS;
        b.todayDirectBusiness = store.dayDirectBusiness(a, d);
        b.todayTeamBusiness = b.dailyMatching;
        b.todayNewMembers = store.dayNewDirects(a, d);
    }

    function _rankProgress(User memory u) internal view returns (RankProgress memory p) {
        p.current = u.rank; p.currentName = rankName(u.rank);
        p.matchingNow = u.matchingBusiness;
        if (u.rank >= 9) { p.next = 9; p.nextName = rankName(9); p.progressBps = 10000; return p; }
        p.next = u.rank + 1; p.nextName = rankName(p.next);
        RankCfg memory c = store.getRankCfg(p.next);
        p.matchingTarget = c.matching; p.rewardOnCompletion = c.reward;
        p.progressBps = c.matching == 0 ? 0 : _min(10000, uint256(u.matchingBusiness) * 10000 / c.matching);
    }

    function _limitView(address a, uint256 totalIncome) internal view returns (LimitView memory l) {
        Flow memory f = store.getFlow(a);
        l.sellLimit = store.dailyLimit(); l.withdrawLimit = l.sellLimit;
        l.sellLeft = _left(f.sStart, f.sInWindow);
        l.withdrawLeft = _left(f.wStart, f.wInWindow);
        l.totalWithdrawn = f.withdrawnUsd;
        l.availableEstimate = totalIncome > f.withdrawnUsd ? totalIncome - f.withdrawnUsd : 0;
    }

    function _left(uint40 start, uint128 used) internal view returns (uint256) {
        uint256 u = block.timestamp < uint256(start) + 1 days ? used : 0;
        uint256 lim = store.dailyLimit();
        return lim > u ? lim - u : 0;
    }

    function _range(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256 n) {
        if (offset >= total) return 0;
        n = total - offset;
        if (limit > MAX_PAGE) limit = MAX_PAGE;
        if (n > limit) n = limit;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) { return a < b ? a : b; }
}
