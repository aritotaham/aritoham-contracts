// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AritohamTypes.sol";
import "./IAritohamDataStore.sol";

/**
 * AritohamDataReaderTeamDao
 * ---------------------
 * Second read contract (kept separate to stay under the 24 KB size limit).
 * DAO Partnership / DAO Payouts / My Direct Team / My Contributing Team screens.
 */
contract AritohamDataReaderTeamDao {
    IAritohamDataStore public immutable store;

    uint256 public constant MAX_PAGE = 100;
    uint256 public constant MAX_SCAN = 5000;
    uint256 public constant SHARE_STEP = 2500e18;
    uint256 public constant LEVELS = 20;

    constructor(address _store) { store = IAritohamDataStore(_store); }

    // ═════════════════════════ view structs ═════════════════════════

    
    struct DaoStatus {
        bool lifetime; bool windowOpen; uint40 activatedAt; uint40 windowEnd;
        uint256 windowDirect; uint256 directTarget; uint256 windowMatching; uint256 matchingTarget; bool qualifiedByWindow;
        uint256 weeklyMatching; uint256 qualifiedShares; uint256 shortfall; uint256 weeklyProgressBps; uint256 estWeeklyPayout;
    }
    struct DaoPayoutItem { uint32 cycle; address wallet; uint40 time; uint256 weeklyMatching; uint256 shares; uint256 shareValue; uint256 payout; }
    struct DaoMemberItem { address wallet; uint32 id; bool lifetime; uint256 weeklyMatching; uint256 nextTierNeeded; uint256 shares; uint256 estReward; }
    struct CycleSummary { uint256 cycle; uint256 totalDeposit; uint256 pool; uint256 members; uint256 totalShares; uint256 valuePerShare; uint40 time; bool paid; }
    struct MemberItem {
        address wallet; uint32 id; uint8 level; uint8 rank; uint40 joinedAt;
        uint256 selfStaked; uint256 directBusiness; uint256 teamBusiness; uint32 directCount; uint32 teamCount; bool daoPartner;
    }
    struct TeamFilter { uint256 level; bool onlyInvested; bool daoOnly; uint256 rank; }   // level 0 = all; rank 255 = all

    // ═════════════════════════ DAO ═════════════════════════

    function getMyDaoStatus(address a) external view returns (DaoStatus memory s) {
        User memory u = store.getUser(a);
        s.lifetime = u.daoLifetime;
        s.activatedAt = u.activatedAt;
        s.windowEnd = u.activatedAt == 0 ? 0 : uint40(uint256(u.activatedAt) + 20 days);
        s.windowOpen = u.activatedAt != 0 && block.timestamp <= s.windowEnd;
        s.windowDirect = u.windowDirect;   s.directTarget = 3000e18;
        s.windowMatching = u.windowMatching; s.matchingTarget = 10000e18;
        s.qualifiedByWindow = u.windowDirect >= 3000e18 || u.windowMatching >= 10000e18;
        s.weeklyMatching = store.weeklyMatching(a);
        s.qualifiedShares = s.weeklyMatching / SHARE_STEP;
        s.shortfall = s.weeklyMatching >= SHARE_STEP ? 0 : SHARE_STEP - s.weeklyMatching;
        uint256 prog = (s.weeklyMatching % SHARE_STEP) * 10000 / SHARE_STEP;
        s.weeklyProgressBps = s.weeklyMatching >= SHARE_STEP ? 10000 : prog;
        s.estWeeklyPayout = s.qualifiedShares * _vps();
    }

    /// DAO Payouts -> Cycle Summary card.
    function getCycleSummary(uint256 cycle) external view returns (CycleSummary memory s) {
        DaoCycle memory c = store.getDaoCycle(cycle);
        s.cycle = cycle;
        s.totalDeposit = store.cycleDeposit(cycle);
        s.pool = c.pool; s.members = c.members; s.totalShares = c.totalShares;
        s.valuePerShare = c.totalShares == 0 ? 0 : uint256(c.pool) / c.totalShares;
        s.time = c.time; s.paid = c.paid;
    }

    /// DAO Payouts -> Previous Distributions table (all wallets of a cycle).
    function getCyclePayouts(uint256 cycle, uint256 offset, uint256 limit) external view returns (DaoPayoutItem[] memory page, uint256 total) {
        total = store.cyclePayoutsLength(cycle);
        uint256 n = _range(total, offset, limit);
        page = new DaoPayoutItem[](n);
        for (uint256 i; i < n; i++) page[i] = _payout(cycle, offset + i);   // payout order = distribution order
    }

    /// DAO Payouts -> My Payouts / My Payout History.
    function getMyDaoPayouts(address a, uint256 offset, uint256 limit) external view returns (DaoPayoutItem[] memory page, uint256 total) {
        total = store.counts(a)[9];
        uint256 n = _range(total, offset, limit);
        page = new DaoPayoutItem[](n);
        for (uint256 i; i < n; i++) {
            (uint32 cyc, uint32 idx) = store.userDaoPayouts(a, total - 1 - offset - i);
            page[i] = _payout(cyc, idx);
        }
    }

    /// Current Cycle Member List.
    function getCycleMembers(uint256 cycle, uint256 offset, uint256 limit) external view returns (DaoMemberItem[] memory page, uint256 total) {
        total = store.eligibleLength(cycle);
        uint256 n = _range(total, offset, limit);
        page = new DaoMemberItem[](n);
        uint256 vps = _vps();
        for (uint256 i; i < n; i++) {
            address w = store.eligibleWallets(cycle, offset + i);
            uint256 wm = store.weeklyMatching(w);
            uint256 sh = wm / SHARE_STEP; if (sh == 0) sh = 1;
            page[i] = DaoMemberItem(w, store.getUser(w).id, store.getUser(w).daoLifetime, wm, SHARE_STEP - (wm % SHARE_STEP), sh, sh * vps);
        }
    }

    // ═════════════════════════ TEAM ═════════════════════════

    /**
     * One function for all team screens:
     *  - My Direct Team:        f.level = 1
     *  - My Contributing Team:  f.level = 0 (or 1..20), f.onlyInvested = true
     * Drill-down: call again with the clicked member's address.
     * Filters: f.daoOnly = DAO Partner toggle, f.rank = 255 for "All Ranks".
     */
    function getTeam(address root, TeamFilter memory f, uint256 offset, uint256 limit) external view returns (MemberItem[] memory page, uint256 total) {
        uint256 maxLevel = (f.level == 0 || f.level > LEVELS) ? LEVELS : f.level;
        (address[] memory q, uint8[] memory lv, uint256 n) = _bfs(root, maxLevel);

        uint256[] memory hit = new uint256[](n);
        for (uint256 i; i < n; i++) {
            if (f.level != 0 && lv[i] != f.level) continue;
            User memory u = store.getUser(q[i]);
            if (f.onlyInvested && u.selfStaked == 0) continue;
            if (f.daoOnly && !u.daoLifetime) continue;
            if (f.rank != 255 && u.rank != f.rank) continue;
            hit[total++] = i;
        }
        uint256 cnt = _range(total, offset, limit);
        page = new MemberItem[](cnt);
        for (uint256 j; j < cnt; j++) page[j] = _member(q[hit[offset + j]], lv[hit[offset + j]]);
    }

    /// Header cards of the team pages.
    function getTeamSummary(address a) external view returns (uint256 directs, uint256 directContribution, uint256 totalMembers, uint256 contributing, uint256 teamBusiness, uint256 visibleLevels) {
        User memory u = store.getUser(a);
        return (u.directCount, u.directBusiness, u.teamCount, u.contributingCount, u.teamBusiness, LEVELS);
    }

    // ═════════════════════════ helpers ═════════════════════════

    function _vps() internal view returns (uint256) {
        uint256 holders = store.lifetimeHolders();
        if (holders == 0) return 0;
        return store.cycleDeposit(store.currentCycle()) * store.daoBps() / 10000 / holders;   // estimate: 1 share per holder
    }

    function _payout(uint256 cycle, uint256 idx) internal view returns (DaoPayoutItem memory p) {
        (address w, uint40 t, uint32 c, uint128 reward, uint128 wm, uint32 sh) = store.cyclePayouts(cycle, idx);
        p = DaoPayoutItem(c, w, t, wm, sh, sh == 0 ? 0 : uint256(reward) / sh, reward);
    }

    function _member(address w, uint8 level) internal view returns (MemberItem memory m) {
        User memory u = store.getUser(w);
        m = MemberItem(w, u.id, level, u.rank, u.registeredAt, u.selfStaked, u.directBusiness, u.teamBusiness, u.directCount, u.teamCount, u.daoLifetime);
    }

    function _bfs(address root, uint256 maxLevel) internal view returns (address[] memory q, uint8[] memory lv, uint256 n) {
        q = new address[](MAX_SCAN);
        lv = new uint8[](MAX_SCAN);
        n = _push(q, lv, 0, root, 1);
        for (uint256 head; head < n; head++) {
            uint8 l = lv[head];
            if (l < maxLevel) n = _push(q, lv, n, q[head], l + 1);
        }
    }

    function _push(address[] memory q, uint8[] memory lv, uint256 n, address parent, uint8 level) internal view returns (uint256) {
        address[] memory kids = store.getDirects(parent);
        for (uint256 i; i < kids.length && n < MAX_SCAN; i++) { q[n] = kids[i]; lv[n] = level; n++; }
        return n;
    }

    function _range(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256 n) {
        if (offset >= total) return 0;
        n = total - offset;
        if (limit > MAX_PAGE) limit = MAX_PAGE;
        if (n > limit) n = limit;
    }
}
