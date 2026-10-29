// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

abstract contract Pausable is Context {
    bool private _paused;

    event Paused(address account);

    event Unpaused(address account);

    error EnforcedPause();

    error ExpectedPause();

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    error ECDSAInvalidSignature();

    error ECDSAInvalidSignatureLength(uint256 length);

    error ECDSAInvalidSignatureS(bytes32 s);

    function tryRecover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly ("memory-safe") {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    function tryRecoverCalldata(
        bytes32 hash,
        bytes calldata signature
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, calldata slices would work here, but are
            // significantly more expensive (length check) than using calldataload in assembly.
            assembly ("memory-safe") {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    function recoverCalldata(bytes32 hash, bytes calldata signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecoverCalldata(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    function parse(bytes memory signature) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly ("memory-safe") {
            // Check the signature length
            switch mload(signature)
            // - case 65: r,s,v signature (standard)
            case 65 {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098)
            case 64 {
                let vs := mload(add(signature, 0x40))
                r := mload(add(signature, 0x20))
                s := and(vs, shr(1, not(0)))
                v := add(shr(255, vs), 27)
            }
            default {
                r := 0
                s := 0
                v := 0
            }
        }
    }


    function parseCalldata(bytes calldata signature) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly ("memory-safe") {
            // Check the signature length
            switch signature.length
            // - case 65: r,s,v signature (standard)
            case 65 {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098)
            case 64 {
                let vs := calldataload(add(signature.offset, 0x20))
                r := calldataload(signature.offset)
                s := and(vs, shr(1, not(0)))
                v := add(shr(255, vs), 27)
            }
            default {
                r := 0
                s := 0
                v := 0
            }
        }
    }

    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_safeApprove(token, spender, value, false)) {
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }


    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

 
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            mstore(0x60, 0)
        }
    }

    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(spender, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC1363 is IERC20, IERC165 {
    function transferAndCall(address to, uint256 value) external returns (bool);
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);
    function approveAndCall(address spender, uint256 value) external returns (bool);
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

/// @dev Minimal interface for the ARITOHAM token — only the DEX-facing functions.
interface IARITOHAM {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);

    function setBlacklisted(address account, bool status) external;
    function isBlacklisted(address account) external view returns (bool);
    function burnFrom(address account, uint256 value) external;
}

/// @dev Write-side interface of AritohamDataStore. One function per event of this contract.
interface IAritohamDataStoreWriter {
    function recordRegistration(address user, address referrer) external;
    function recordStake(address user, uint256 usdt, uint256 tokens, uint256 stakeIndex) external;
    function recordPurchase(address user, uint256 usdt, uint256 tokens, uint256 price) external;
    function recordSell(address user, uint256 tokenAmount, uint256 payout, uint256 price) external;
    function recordDirectIncome(address user, address referrer, uint256 reward, uint256 minted) external;
    function recordRoiClaim(address user, uint256 stakeIndex, uint256 totalInvestment, uint256 earned, uint256 periodsPassed) external;
    function recordGenerationIncome(address claimer, address receiver, uint256 level, uint256 reward, uint256 base) external;
    function recordRewardIncome(address user, uint256 amount, uint256 rank) external;
    function recordRankIncentive(uint256 id, address user, uint256 amount, uint256 rank, uint256 ts) external;
    function recordDaoEligible(uint256 cycle, address[] calldata wallets, uint256 added) external;
    function recordDaoDistributed(uint256 cycle, uint256 pool, uint256 count) external;
    function recordDaoReward(address wallet, uint256 reward, uint256 shares) external;
    function recordWithdraw(address user, uint256 amount, uint256 tokens, uint256 fee, uint256 price) external;

    function resetRankBusinessDao(address user) external;
}

/// @title ARITOHAMProtocol — investment platform with referral registration, ROI & price mechanics
contract ARITOHAMProtocol is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // ═══════════════════════════════ Types ═══════════════════════════════

    struct User {
        address referrer;
        bool    isRegistered;
        bool    isActive;
        uint256 totalInvestment;
        uint256 totalStaked;
        uint256 totalIncome;
        uint256 balance;
        uint256 remainingCap;
        uint256 totalReferralCount;
        uint256 activeReferralCount;    // directs that have staked (activated)
        uint256 qualifiedReferralCount; // directs whose totalStaked reached GEN_MIN_STAKE; gates levels
        uint256 maxPayout;
        uint256 directIncome;
        uint256 generationIncome;
        uint256 daoIncome;
        uint256 currentRank;
        uint256 rewardIncome;
        uint256 rankIncentive;
        uint256 roiAccrued;
        uint256 totalStakeRoi;
        uint256 lastRoiUpdate; // used to mirror the previous keeper workflow
    }

    struct Stake {
        uint256 totalInvestment;
        uint256 ecosystemFee;
        uint256 tokenPrice;
        uint256 mintedTokens;
        uint256 tokenUsdValue;
        uint256 dailyRoi;
        uint256 totalRoi;
        uint256 totalDays;

        uint256 claimedRoi;
        uint256 startTime;
        uint256 lastClaimTime;
        // Once the user reaches max payout (remainingCap == 0), all running stakes are
        // frozen: `completed` stakes never accrue or pay ROI again, even if a later
        // restake reopens remainingCap. This prevents retroactive ROI on old stakes.
        bool    completed;
    }

    // ═══════════════════════════════ State ═══════════════════════════════

    IERC20  public usdt;
    IARITOHAM   public aritoham;
    address public admin;
    address public chainKeeper;

    // ═══════════════════════════ Data store (NEW) ═══════════════════════════
    /// @notice AritohamDataStore contract. Every action below calls it to persist records.
    IAritohamDataStoreWriter public dataStore;
    /// @notice The address that was registered as root (deployer) in the constructor.
    address public rootUser;
    bool    public storeRootInit;

    // ═══════════════════════════════ Admin multisig (signatures) ═══════════════════════════════

    mapping(address => bool) public isAdminSigner;
    address[] public adminSigners;
    uint256 public minAdminSignatures = 2;
    uint256 public adminSigNonce;

    mapping(address => User)    internal users;   // read via getUser() / getUserFullInfo()
    mapping(address => Stake[]) public userStakes;

    mapping(address => uint256) public dailySellTotal;
    mapping(address => uint256) public sellWindowStart;

    uint256 public totalUsers;
    uint256 public liquidityPool;
    uint256 public totalSupply;    // DEX-internal accounting (updated only by DEX mint/burn)
    uint256 public totalBurnedTokens;
    uint256 public currentPrice;

    /// @dev Monotonic counter mixed into the rank-incentive event id so it is unique
    ///      even for multiple credits in the same block / same timestamp.
    uint256 public rankIncentiveNonce;

    // ═══════════════════════ Dao Partner Program (DAO) ═══════════════════════
    // Virtual pool: 5% of every gross stake accrues here. Off-chain eligibility is written
    // by the chain keeper (wallets + share weights), then split share-proportionally on a daily
    // distribution and credited to each user's withdrawable balance (capped by remainingCap).

    uint256 public daoPoolTotal;        // accruing pool for the CURRENT (accruing) cycle
    uint256 public daoCycle;            // current accruing cycle id (starts at 1)
    uint256 public daoLastCycleStart;   // timestamp the last distribution cycle STARTED (daily guard)

    mapping(uint256 => address[]) private daoWallets;                  // cycle => eligible wallets
    mapping(uint256 => uint256)   public  daoTotalShares;              // cycle => sum of shares
    mapping(uint256 => mapping(address => uint256)) public daoShares;  // cycle => wallet => shares

    // The cycle currently being PAID (frozen snapshot), distinct from the accruing cycle.
    uint256 public daoPayCycle;         // cycle id being distributed (0 = none in progress)
    uint256 public daoPayPool;          // frozen pool for the paying cycle (for events)
    uint256 public daoPayPerShare;      // frozen pool / totalShares
    uint256 public daoPayCursor;        // next wallet index to process (pagination)

    // ═══════════════════════════════ Constants ═══════════════════════════

    uint256 public constant PRICE_PRECISION = 1e18;
    /// @dev Starting / empty-supply price: 0.01 (same 18-decimal scale as `PRICE_PRECISION`).
    uint256 public constant BASE_PRICE = PRICE_PRECISION / 100;

    /// @dev ROI / DAO accrual period — fixed at 24 hours. Use `timeUnit()` everywhere.
    uint256 public constant TIME_UNIT = 1 days;

    uint256 public constant DEFAULT_MAX_PAYOUT_MULTIPLIER  = 2;
    uint256 public constant REFERRAL_MAX_PAYOUT_MULTIPLIER = 3;

    uint256 public constant MIN_BUY      = 10e18;
    uint256 public constant MAX_BUY      = 1000e18;
    uint256 public constant MIN_WITHDRAW = 10e18;
    uint256 public constant MAX_WITHDRAW = 3000e18;
    uint256 public constant BUY_STEP     = 10e18;

    uint256 public constant ECOSYSTEM_FEE_PCT   = 10;
    uint256 public constant MINT_PCT        = 80;    // 80% of post-fee USDT determines token amount
    uint256 public constant SELL_PAYOUT_PCT = 85;
    uint256 public constant DAILY_SELL_LIMIT = 3000e18;

    /// @dev Direct (single-level) referral income: 5% of the buy's mintValue.
    uint256 public constant DIRECT_INCOME_PCT = 5;

    /// @dev Generation income: number of upline levels distributed on each ROI claim.
    uint256 public constant GENERATION_LEVELS = 20;
    /// @dev Each QUALIFIED direct opens 2 generation levels for the referrer
    ///      (1 qualified direct → 2 levels, 10 qualified directs → all 20).
    uint256 public constant LEVELS_PER_ACTIVE_DIRECT = 2;

    /// @dev Minimum cumulative stake ($50) for generation-income eligibility:
    ///      a direct only counts toward opening levels once their `totalStaked` reaches this,
    ///      and an upline earns generation income only if their own `totalStaked` reaches this.
    uint256 public constant GEN_MIN_STAKE = 50e18;

    /// @dev Dao Partner Program: 5% of each gross stake accrues into the shared pool.
    uint256 public constant DAO_PCT = 5;

    address public constant WALLET_WITHDRAW_FEE1 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7;
    address public constant WALLET_WITHDRAW_FEE2 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7;
    address public constant WALLET_WITHDRAW_FEE3 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7;
    address public constant WALLET_WITHDRAW_FEE4 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7;

    // ═══════════════════════ Fixed reward wallets (deposit fee split) ═══════════════════════
    // Percentages are expressed in BPS out of 1000, because ecosystemFee is 10% of deposit.
    uint256 private constant _REWARD_BPS_DENOM = 1000;
    address private constant _REWARD_WALLET_1 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7; // 2.5%
    address private constant _REWARD_WALLET_2 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7; // 2.5%
    address private constant _REWARD_WALLET_3 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7; // 2.5%
    address private constant _REWARD_WALLET_4 = 0xC008B65ABBaED32E055858c8BE391dAA3204b3b7; // 2.5%

    uint256 private constant _REWARD_WALLET_1_BPS = 250;
    uint256 private constant _REWARD_WALLET_2_BPS = 250;
    uint256 private constant _REWARD_WALLET_3_BPS = 250;
    uint256 private constant _REWARD_WALLET_4_BPS = 250;

    // ═══════════════════════════════ Events ══════════════════════════════

    event UserRegistered(address indexed user, address indexed referrer);
    event ChainKeeperUpdated(address indexed previousChainKeeper, address indexed newChainKeeper);
    event DataStoreUpdated(address indexed previousStore, address indexed newStore);
    event TokensPurchased(address indexed user, uint256 usdtAmount, uint256 tokens, uint256 price);
    event TokensSold(address indexed user, uint256 tokens, uint256 usdtPayout, uint256 price);
    event StakeCreated(address indexed user, uint256 amount, uint256 tokens, uint256 index);
    event stakeRewardUpdated(address indexed user, uint256 amount);
    /// @notice Per-stake ROI attribution for one claimRoi call. Emitted once for every stake
    ///         that paid ROI in the claim, so the backend can attribute the reward to a specific
    ///         stake instead of only seeing the aggregate `stakeRewardUpdated`.
    /// @param user        The claimer.
    /// @param stakeIndex  Index of the stake in userStakes[user] that produced this ROI.
    /// @param stakeAmount The stake's original investment (e.g. 100e18 for a $100 stake).
    /// @param roiReward   ROI credited for THIS stake in THIS claim.
    /// @param forPeriods  Whole periods (days; 10-min units in test mode) this reward covers.
    ///                    0 when the stake settled its final remainder on window end.
    event StakeRoiClaimed(
        address indexed user,
        uint256 indexed stakeIndex,
        uint256 stakeAmount,
        uint256 roiReward,
        uint256 forPeriods
    );
    event RankIncentiveUpdated(bytes32 indexed id, address indexed user, uint256 amount, uint256 rank, uint256 timestamp);
    /// @notice Emitted when a user's running stakes are frozen because they restaked after
    ///         already reaching max payout. `count` stakes were marked completed.
    event RunningStakesFrozen(address indexed user, uint256 count);

    event Withdraw(address user, uint256 amount, uint256 tokens, uint256 fee, uint256 price);
    event PriceUpdated(uint256 newPrice, uint256 liquidityPool, uint256 totalSupply);

    event DirectIncomeDistributed(address indexed from, address indexed to, uint256 amount);
    event GenerationIncomeDistributed(address indexed from, address indexed to, uint256 level, uint256 amount);
    event RewardIncomeUpdated(address user, uint256 amount, uint256 rank);
    event DaoEligibleSet(uint256 indexed cycle, uint256 count, uint256 sharesAdded);
    event DaoDistributed(uint256 indexed cycle, uint256 pool, uint256 walletCount);
    event DaoRewardCredited(address indexed user, uint256 amount);
    event EcosystemFeeDistributed(uint256 total, uint256 perWallet);
    event EcosystemFeeDistributedInTokens(uint256 total, uint256 perWallet);
    event AdminSignersUpdated(address[] signers, uint256 minSignatures);
    event OwnershipRenounced(address indexed previousAdmin);

    event UserSystemsReset(address indexed user);
    event TokensBurnedByKeeper(address indexed from, uint256 amount);
    // ═══════════════════════════════ Errors ══════════════════════════════

    error AlreadyRegistered();
    error ReferrerNotRegistered();
    error ReferrerNotActive();
    error NotRegistered();
    error NotActive();
    error NotAdmin();
    error NotChainKeeper();
    error ZeroAddress();
    error InvalidAmount();
    error InsufficientTokens();
    error InsufficientLiquidity();
    error NothingToWithdraw();
    error MaxPayoutReached();
    error LiquidityInvariantBroken();
    error DailySellLimitExceeded();
    error SlippageExceeded();

    error InsufficientBalance();
    // ═══════════════════════════════ Modifiers ═══════════════════════════

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyChainKeeper() {
        if (msg.sender != chainKeeper) revert NotChainKeeper();
        _;
    }

    modifier onlyRegistered() {
        if (!users[msg.sender].isRegistered) revert NotRegistered();
        _;
    }

    modifier onlyActive() {
        if (!users[msg.sender].isActive) revert NotActive();
        _;
    }

    /// @notice Renounce admin ownership permanently (admin becomes address(0)).
    function renounceOwnership() external onlyAdmin {
        address previous = admin;
        admin = address(0);
        emit OwnershipRenounced(previous);
    }

    /// @notice ROI / DAO accrual period — fixed at 24 hours.
    /// @dev Kept as a function (not just the constant) so off-chain consumers that read
    ///      `timeUnit()` continue to work.
    function timeUnit() public pure returns (uint256) {
        return TIME_UNIT;
    }

    // ═══════════════════════════════ Constructor ═════════════════════════

    /// @param _usdt   BEP-20 USDT address (18 decimals on BSC)
    /// @param _aritoham   ARITOHAM token address (must have minter set to this contract)
    /// @param _chainKeeper Trusted off-chain keeper for reward/governance updates
    /// @param _adminSigners Exactly 2 unique signers for `setChainKeeper` (2-of-2)
    /// @param _minAdminSignatures Must be 2 (fixed)
    /// @param _dataStore AritohamDataStore address (deploy it first; then call `store.setCore(thisContract)`)
    constructor(
        address _usdt,
        address _aritoham,
        address _chainKeeper,
        address[] memory _adminSigners,
        uint256 _minAdminSignatures,
        address _dataStore
    ) {
        if (_usdt == address(0) || _aritoham == address(0) || _chainKeeper == address(0) || _dataStore == address(0)) revert ZeroAddress();

        admin  = msg.sender;
        rootUser = msg.sender;
        usdt   = IERC20(_usdt);
        aritoham   = IARITOHAM(_aritoham);
        chainKeeper = _chainKeeper;
        dataStore = IAritohamDataStoreWriter(_dataStore);

        _initAdminSigners(_adminSigners, _minAdminSignatures);

        currentPrice = BASE_PRICE;

        User storage root = users[msg.sender];   // fields not set below default to 0 / false
        root.isRegistered = true;
        root.isActive     = true;
        root.remainingCap = type(uint256).max;
        root.maxPayout    = DEFAULT_MAX_PAYOUT_MULTIPLIER;
        totalUsers = 1;
        daoCycle = 1;
    }

    function _initAdminSigners(address[] memory signers_, uint256 minSigs_) internal {
        require(signers_.length == 2, "Need 2 signers");
        require(minSigs_ == 2, "Need 2 sigs");

        for (uint256 i = 0; i < signers_.length; i++) {
            address s = signers_[i];
            require(s != address(0), "Zero signer");
            require(!isAdminSigner[s], "Already signer");
            isAdminSigner[s] = true;
            adminSigners.push(s);
        }
        minAdminSignatures = 2;
        emit AdminSignersUpdated(adminSigners, minAdminSignatures);
    }

    // ═══════════════════════════ Data store admin (NEW) ═══════════════════════════

    /// @notice Point the protocol at a (new) data store contract.
    function setDataStore(address _dataStore) external onlyAdmin {
        if (_dataStore == address(0)) revert ZeroAddress();
        emit DataStoreUpdated(address(dataStore), _dataStore);
        dataStore = IAritohamDataStoreWriter(_dataStore);
    }

    /// @notice One-time: register the root (deployer) user inside the data store so it gets a user id.
    /// @dev Call AFTER `store.setCore(address(this))`. The constructor cannot do this itself,
    ///      because the store does not know this contract's address yet.
    function initStoreRoot() external onlyAdmin {
        require(!storeRootInit, "Already initialised");
        storeRootInit = true;
        dataStore.recordRegistration(rootUser, address(0));
    }

    // ═══════════════════════════════ Registration ════════════════════════

    /// @notice Register under an existing, active referrer.
    ///         User is NOT activated here — activation happens on first stakeTokens.
    function register(address _referrer) external whenNotPaused {
        if (users[msg.sender].isRegistered) revert AlreadyRegistered();
        if (!users[_referrer].isRegistered) revert ReferrerNotRegistered();
        if (!users[_referrer].isActive)     revert ReferrerNotActive();

        User storage nu = users[msg.sender];   // fresh user: all other fields default to 0 / false
        nu.referrer     = _referrer;
        nu.isRegistered = true;
        nu.maxPayout    = DEFAULT_MAX_PAYOUT_MULTIPLIER;

        unchecked { ++totalUsers; }

        uint256 newRefCount;
        unchecked { newRefCount = ++users[_referrer].totalReferralCount; }

        if (newRefCount == 1) {
            User storage r = users[_referrer];
            uint256 oldMaxPayout = r.maxPayout;
            r.maxPayout = REFERRAL_MAX_PAYOUT_MULTIPLIER;
            // Expand remaining cap by the delta in max payout capacity.
            if (r.totalInvestment != 0) {
                r.remainingCap += r.totalInvestment * (r.maxPayout - oldMaxPayout);
            }
        }

        emit UserRegistered(msg.sender, _referrer);
        dataStore.recordRegistration(msg.sender, _referrer);   // DATA STORE
    }

    // ═══════════════════════════════ Buy Tokens ══════════════════════════

    /// @notice Purchase ARITOHAM tokens with USDT.
    ///         Each buy creates an independent stake (linear daily ROI).
    /// @param usdtAmount   USDT to spend (must be 10–1000, multiple of 10)
    /// @param minTokensOut Minimum tokens expected (slippage guard; pass 0 to skip)
    function stakeTokens(uint256 usdtAmount, uint256 minTokensOut)
        external
        onlyRegistered
        whenNotPaused
        nonReentrant
    {
        if (usdtAmount < MIN_BUY || usdtAmount > MAX_BUY) revert InvalidAmount();
        if (usdtAmount % BUY_STEP != 0) revert InvalidAmount();

        uint256 priceAtMint = currentPrice; // price used for tokens calculation

        // --- interaction: pull USDT (reverts on failure via SafeERC20) ---
        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);

        // --- effects ---
        uint256 ecosystemFee  = (usdtAmount * ECOSYSTEM_FEE_PCT) / 100;
        uint256 remaining = usdtAmount - ecosystemFee;

        // 80% of remaining determines how many tokens to mint;
        // the FULL remaining amount backs liquidity so price rises on every buy.
        uint256 mintValue = (remaining * MINT_PCT) / 100;

        uint256 tokens = (mintValue * PRICE_PRECISION) / priceAtMint;
        if (tokens < minTokensOut) revert SlippageExceeded();

        totalSupply   += tokens;
        liquidityPool += remaining;  // full post-fee amount backs the pool

        _updatePrice();

        // User totals, cap, DAO pool accrual, activation and generation-level qualification.
        _applyStake(msg.sender, usdtAmount);

        // Mint principal tokens to the contract (escrow).
        aritoham.mint(address(this), tokens);

        _distributeDirectIncome(msg.sender, usdtAmount);

        // Pay ecosystem fee after state updates / minting.
        _distributeEcosystemFee(ecosystemFee);

        // Create stake record for self-claimed linear daily ROI.
        uint256 stakeIndex = _pushStake(usdtAmount, ecosystemFee, priceAtMint, tokens, mintValue);

        emit StakeCreated(msg.sender, usdtAmount, tokens, stakeIndex);
        _storeStake(usdtAmount, tokens, stakeIndex);   // DATA STORE

        _checkLiquidityInvariant();

        emit TokensPurchased(msg.sender, usdtAmount, tokens, priceAtMint);
        _storePurchase(usdtAmount, tokens, priceAtMint);   // DATA STORE
    }

    /// @dev User-side bookkeeping of a new stake (split out of stakeTokens to keep stack usage low).
    function _applyStake(address user, uint256 usdtAmount) private {
        User storage u = users[user];
        uint256 stakedBefore = u.totalStaked;

        // If the user has ALREADY reached max payout (remainingCap == 0) at the moment of
        // this new stake, freeze every currently-running stake as `completed`. Those stakes
        // stop accruing/paying ROI permanently — so reopening the cap with this new stake
        // does NOT retroactively pay the old stakes for periods elapsed while capped out.
        // Only this new stake (and any later ones) can earn against the reopened cap.
        if (u.remainingCap == 0) {
            _freezeRunningStakes(user);
        }

        u.totalInvestment += usdtAmount;
        u.totalStaked += usdtAmount;
        u.remainingCap += usdtAmount * u.maxPayout;

        // Dao Partner Program: accrue 5% of the gross stake into the pool (virtual).
        daoPoolTotal += (usdtAmount * DAO_PCT) / 100;

        address ref = u.referrer;

        if (!u.isActive) {
            u.isActive      = true;
            u.lastRoiUpdate = block.timestamp;
            // First activation counts this direct as active for the referrer.
            if (ref != address(0)) {
                unchecked { ++users[ref].activeReferralCount; }
            }
        }

        // Generation-level qualification: the first time this user's cumulative stake
        // crosses GEN_MIN_STAKE ($50), count them as a QUALIFIED direct for their referrer.
        if (
            ref != address(0) &&
            stakedBefore < GEN_MIN_STAKE &&
            u.totalStaked >= GEN_MIN_STAKE
        ) {
            unchecked { ++users[ref].qualifiedReferralCount; }
        }
    }

    /// @dev Append the Stake record for msg.sender and return its index.
    function _pushStake(
        uint256 usdtAmount,
        uint256 ecosystemFee,
        uint256 priceAtMint,
        uint256 tokens,
        uint256 mintValue
    ) private returns (uint256 stakeIndex) {
        Stake[] storage arr = userStakes[msg.sender];
        stakeIndex = arr.length;

        uint256 dailyRoi = (mintValue * 174) / 10000;     // 1.74% of mintValue
        uint256 totalRoi = usdtAmount * 2;                // 2x of gross deposit

        Stake storage st = arr.push();
        st.totalInvestment = usdtAmount;
        st.ecosystemFee    = ecosystemFee;
        st.tokenPrice      = priceAtMint;
        st.mintedTokens    = tokens;
        st.tokenUsdValue   = mintValue;
        st.dailyRoi        = dailyRoi;
        st.totalRoi        = totalRoi;
        st.totalDays       = totalRoi / dailyRoi;         // linear days until totalRoi
        st.startTime       = block.timestamp;
        st.lastClaimTime   = block.timestamp;
        // claimedRoi = 0 and completed = false by default
    }

    /// @dev Thin wrappers keep the external calls out of stakeTokens' crowded stack.
    function _storeStake(uint256 usdtAmount, uint256 tokens, uint256 stakeIndex) private {
        dataStore.recordStake(msg.sender, usdtAmount, tokens, stakeIndex);
    }

    function _storePurchase(uint256 usdtAmount, uint256 tokens, uint256 price) private {
        dataStore.recordPurchase(msg.sender, usdtAmount, tokens, price);
    }

    // ═══════════════════════════════ Sell Tokens ═════════════════════════

    /// @notice Sell ARITOHAM tokens back for USDT.
    ///         User receives 85 % of the USDT value; 15 % stays in the pool.
    ///         Daily sell capped at 1 000 USDT per user.
    function sellTokens(uint256 tokenAmount)
        external
        onlyActive
        whenNotPaused
        nonReentrant
    {
        if (tokenAmount == 0) revert InvalidAmount();
        if (aritoham.balanceOf(msg.sender) < tokenAmount) revert InsufficientTokens();


        uint256 priceAtSell = currentPrice; // execution price (before this trade moves it)
        uint256 usdtValue = (tokenAmount * priceAtSell) / PRICE_PRECISION;
        uint256 payout    = (usdtValue * SELL_PAYOUT_PCT) / 100;

        // Full usdtValue must be covered by the pool; 15% stays as price stabilizer
        if (usdtValue > liquidityPool) revert InsufficientLiquidity();
        if (usdt.balanceOf(address(this)) < payout) revert InsufficientLiquidity();

        // --- 24-hour sell limit ---
        if (block.timestamp >= sellWindowStart[msg.sender] + 1 days) {
            sellWindowStart[msg.sender] = block.timestamp;
            dailySellTotal[msg.sender]  = 0;
        }
        dailySellTotal[msg.sender] += payout;
        if (dailySellTotal[msg.sender] > DAILY_SELL_LIMIT) revert DailySellLimitExceeded();

        // --- effects ---
        totalSupply   -= tokenAmount;
        totalBurnedTokens += tokenAmount;
        liquidityPool -= payout;

        _updatePrice();

        // --- interactions: burn full from user, re-mint retained portion to DEX, then pay USDT ---
        aritoham.burn(msg.sender, tokenAmount);

        usdt.safeTransfer(msg.sender, payout);

        emit TokensSold(msg.sender, tokenAmount, payout, priceAtSell);
        dataStore.recordSell(msg.sender, tokenAmount, payout, priceAtSell);   // DATA STORE
    }

    // ═══════════════════════════════ Direct Income ═══════════════════════

    /// @notice Pay the direct referrer 5% of the buy's mintValue (single level).
    /// @dev Credits into `users[referrer].directIncome` and also increments `totalIncome`
    ///      (for withdrawal caps). Only active referrers are paid, capped by `remainingCap`.
    /// @param user The buyer/payer whose direct `referrer` is credited.
    /// @param baseAmount Base amount in USDT-denominated units (buy `mintValue`).
    function _distributeDirectIncome(address user, uint256 baseAmount) internal {
        if (baseAmount == 0) return;

        address referrer = users[user].referrer;
        if (referrer == address(0)) return;

        User storage up = users[referrer];
        // Only active users get direct income.
        if (!up.isActive) return;

        uint256 reward = (baseAmount * DIRECT_INCOME_PCT) / 100;
        if (reward == 0) return;

        uint256 remainingCap = up.remainingCap;
        if (remainingCap == 0) return;
        if (reward > remainingCap) reward = remainingCap;
        if (reward == 0) return;

        up.directIncome += reward;
        up.totalIncome  += reward;
        up.balance      += reward;
        up.remainingCap  = remainingCap - reward;

        emit DirectIncomeDistributed(user, referrer, reward);
        dataStore.recordDirectIncome(user, referrer, reward, baseAmount);   // DATA STORE
    }

    /// @notice Distribute deposit ecosystem fee across fixed reward wallets.
    /// @dev The provided ratios sum to 10% of the deposit, i.e. 1000 BPS of `ecosystemFee`.
    function _distributeEcosystemFee(uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        uint256 s1 = (amount * _REWARD_WALLET_1_BPS) / _REWARD_BPS_DENOM;
        uint256 s2 = (amount * _REWARD_WALLET_2_BPS) / _REWARD_BPS_DENOM;
        uint256 s3 = (amount * _REWARD_WALLET_3_BPS) / _REWARD_BPS_DENOM;
        uint256 s4 = (amount * _REWARD_WALLET_4_BPS) / _REWARD_BPS_DENOM;

        uint256 distributed = s1 + s2 + s3 + s4;

        usdt.safeTransfer(_REWARD_WALLET_1, s1);
        usdt.safeTransfer(_REWARD_WALLET_2, s2);
        usdt.safeTransfer(_REWARD_WALLET_3, s3);
        usdt.safeTransfer(_REWARD_WALLET_4, s4);

        emit EcosystemFeeDistributed(distributed, 0);
    }

    /// @notice Distribute ecosystem fee in tokens.
    /// @dev Token fees are not routed to reward wallets.
    function _distributeEcosystemFeeInTokens(uint256 amount) internal {
        if (amount == 0) {
            emit EcosystemFeeDistributedInTokens(0, 0);
            return;
        }
        uint256 reward = amount / 4;
        if (reward == 0) {
            emit EcosystemFeeDistributedInTokens(0, 0);
            return;
        }
        IERC20(address(aritoham)).safeTransfer(WALLET_WITHDRAW_FEE1, reward);
        IERC20(address(aritoham)).safeTransfer(WALLET_WITHDRAW_FEE2, reward);
        IERC20(address(aritoham)).safeTransfer(WALLET_WITHDRAW_FEE3, reward);
        IERC20(address(aritoham)).safeTransfer(WALLET_WITHDRAW_FEE4, reward);
        emit EcosystemFeeDistributedInTokens(amount, reward);
    }

    // ═══════════════════════════════ ROI (Self-claim) ════════════════════

    /// @notice Claim accrued linear daily ROI for the caller across all of their stakes.
    /// @dev Decentralized self-claim — no oracle. Each stake accrues independently:
    ///      ROI accrues in whole-day (24h) increments since that stake's `lastClaimTime`,
    ///      so the first day is claimable 24h after staking. Claiming late pays the full
    ///      number of whole days elapsed (e.g. 48h → 2 days, 72h → 3 days). The next 24h
    ///      window restarts from the CLAIM MOMENT, so any sub-24h remainder is forfeited
    ///      (e.g. claiming at 28h pays 1 day and the extra 4h lapses).
    ///      Stakes with <24h since their last claim are skipped — UNLESS the stake has
    ///      reached its `totalDays` window end, in which case it settles its full remaining
    ///      ROI so the user always receives the exact `totalRoi` (2x), with no sub-day
    ///      shortfall from `totalDays` truncation. Final payout is still bounded by
    ///      the user's `remainingCap`.
    /// @dev Mark all not-yet-completed stakes of `user` as `completed`. Called when a user
    ///      restakes while already at max payout (remainingCap == 0): the stakes that were
    ///      running when the cap was reached are done and must never resume paying ROI.
    ///      Already-completed stakes (and stakes whose totalRoi is fully claimed) are left as-is.
    function _freezeRunningStakes(address user) internal {
        Stake[] storage stakes = userStakes[user];
        uint256 frozen;
        for (uint256 i = 0; i < stakes.length; ++i) {
            if (!stakes[i].completed) {
                stakes[i].completed = true;
                unchecked { ++frozen; }
            }
        }
        if (frozen != 0) emit RunningStakesFrozen(user, frozen);
    }

    function claimRoi() external onlyActive  nonReentrant {
        User storage u = users[msg.sender];
        if (u.totalInvestment == 0) revert NothingToWithdraw();

        Stake[] storage stakes = userStakes[msg.sender];
        uint256 totalEarned = 0;
        uint256 remainingCap = u.remainingCap;
        if (remainingCap == 0) revert MaxPayoutReached();

        uint256 unit = timeUnit(); // fixed 24h accrual period

        // Accrue per-stake, capped by each stake's `totalRoi` and `totalDays` window.
        for (uint256 i = 0; i < stakes.length; ++i) {
            Stake storage s = stakes[i];
            // Frozen stakes (user restaked after reaching max payout) never pay ROI again.
            if (s.completed) continue;
            if (s.totalRoi <= s.claimedRoi) continue;

            uint256 stakeEnd = s.startTime + (s.totalDays * unit);
            // Once the window ends, the stake pays out its FULL remaining ROI so the user
            // receives the exact `totalRoi` (2x) — `totalDays` truncation would otherwise
            // leave a sub-day remainder unreachable.
            bool ended = block.timestamp >= stakeEnd;

            uint256 effectiveNow = ended ? stakeEnd : block.timestamp;
            if (!ended && effectiveNow <= s.lastClaimTime) continue;

            // Whole periods (24h, or 10min in test mode) elapsed since this stake's last claim.
            uint256 periodsPassed = effectiveNow > s.lastClaimTime
                ? (effectiveNow - s.lastClaimTime) / unit
                : 0;
            // Skip only if not ended; an ended stake still settles its final remainder
            // even when fewer than one period remains since the last claim.
            if (periodsPassed == 0 && !ended) continue;

            uint256 remaining   = s.totalRoi - s.claimedRoi;
            uint256 grossEarned = periodsPassed * s.dailyRoi;
            // Ended stakes pay all that is left; live stakes pay the elapsed whole days.
            uint256 earned = ended
                ? remaining
                : (grossEarned > remaining ? remaining : grossEarned);
            if (earned == 0) continue;

            if (remainingCap == 0) break;
            if (earned > remainingCap) earned = remainingCap;
            if (earned == 0) break;

            s.claimedRoi += earned;
            // Restart the 24h window from the claim moment — sub-24h remainder is forfeited.
            // (For an ended stake this is past `stakeEnd`, which is harmless: the stake is done.)
            s.lastClaimTime = effectiveNow;
            totalEarned += earned;
            remainingCap -= earned;

            // Per-stake attribution for the backend: which stake paid, how much, for how many days.
            emit StakeRoiClaimed(msg.sender, i, s.totalInvestment, earned, periodsPassed);
            _storeRoi(i, s.totalInvestment, earned, periodsPassed);   // DATA STORE
        }

        if (totalEarned == 0) revert NothingToWithdraw();
        u.roiAccrued += totalEarned;
        u.totalIncome += totalEarned;
        u.balance += totalEarned;
        u.totalStakeRoi += totalEarned;
        u.remainingCap = remainingCap;
        u.lastRoiUpdate = block.timestamp;

        emit stakeRewardUpdated(msg.sender, totalEarned);

        // Distribute generation income to eligible uplines based on the ROI just claimed.
        _distributeGenerationIncome(msg.sender, totalEarned);
    }

    /// @dev Separate function so the external call does not add stack pressure inside claimRoi.
    function _storeRoi(uint256 stakeIndex, uint256 invested, uint256 earned, uint256 periods) private {
        dataStore.recordRoiClaim(msg.sender, stakeIndex, invested, earned, periods);
    }

    /// @dev Per-level generation income in basis points (out of 10000) of the claimer's ROI.
    ///      L1 10% .. L20 0.3%. `pure` lookup — no storage reads.
    ///      level is 1-based (1..20).
    function _generationBps(uint256 level) internal pure returns (uint256) {
        if (level == 1) return 1000;            // 10%
        if (level == 2) return 500;             // 5%
        if (level == 3) return 300;             // 3%
        if (level == 4) return 200;             // 2%
        if (level <= 6) return 150;             // 5–6: 1.5%
        if (level <= 10) return 100;            // 7–10: 1%
        return 30;                              // 11–20: 0.3%
    }

    /// @notice Distribute up to 20 levels of generation income up the referral chain.
    /// @dev Triggered on ROI claim. `level` equals the chain depth (the Nth ancestor is the
    ///      candidate for level N). An ancestor receives level-N income only if eligible:
    ///        - is active and has its own totalStaked >= GEN_MIN_STAKE ($50), and
    ///        - has at least N qualified directs (qualifiedReferralCount * 2 >= level) — a direct
    ///          only counts once ITS totalStaked reaches $50, and
    ///        - has non-zero remainingCap (amount clamped to it).
    ///      If an ancestor is ineligible, that level's income is skipped (not paid, not carried);
    ///      we advance to the next ancestor for the next level. Single upward pass — O(20) max.
    /// @param claimer  The user who just claimed ROI.
    /// @param baseAmount The ROI amount just credited to the claimer (the distribution base).
    function _distributeGenerationIncome(address claimer, uint256 baseAmount) internal {
        if (baseAmount == 0) return;

        address current = users[claimer].referrer;

        for (uint256 level = 1; level <= GENERATION_LEVELS; ++level) {
            if (current == address(0)) break; // chain ended

            User storage up = users[current];
            address next = up.referrer; // cache before any writes

            // Eligibility: active, own stake >= GEN_MIN_STAKE ($50), and enough QUALIFIED
            // directs (each direct must itself have staked >= $50) to unlock this depth.
            if (
                up.isActive &&
                up.totalStaked >= GEN_MIN_STAKE &&
                (up.qualifiedReferralCount * LEVELS_PER_ACTIVE_DIRECT) >= level
            ) {
                uint256 remainingCap = up.remainingCap;
                if (remainingCap != 0) {
                    uint256 reward = (baseAmount * _generationBps(level)) / 10000;
                    if (reward != 0) {
                        if (reward > remainingCap) reward = remainingCap;
                        up.generationIncome += reward;
                        up.totalIncome      += reward;
                        up.balance          += reward;
                        up.remainingCap      = remainingCap - reward;
                        emit GenerationIncomeDistributed(claimer, current, level, reward);
                        dataStore.recordGenerationIncome(claimer, current, level, reward, baseAmount);   // DATA STORE
                    }
                }
            }

            current = next;
        }
    }

    /// @notice Chain keeper promotes a user to a new rank and credits the rank reward.
    /// @dev Rank must strictly increase. rank_id 0 and 1 carry a $0 reward, so they only
    ///      update `currentRank` (no balance change). For rank_id >= 2 the mapped reward
    ///      is credited in full to the user's balance (not capped by remainingCap).
    /// @param user    The user being ranked up.
    /// @param rank_id The new rank id (0-based). Must be greater than the user's current rank.
    function updateRewardIncome(address user, uint256 rank_id) external onlyChainKeeper {
        if (user == address(0)) revert ZeroAddress();
        if (rank_id < 1 || rank_id > 9) revert InvalidAmount();      // ranks are 1..9
        User storage u = users[user];
        if (rank_id <= u.currentRank) revert InvalidAmount();
        u.currentRank = rank_id;

        // Spark (1) and Rise (2) pay $0
        if (rank_id <= 2) {
            emit RewardIncomeUpdated(user, 0, rank_id);
            dataStore.recordRewardIncome(user, 0, rank_id);          // no +1
            return;
        }

        uint256 amount = getRewardAmount(rank_id);
        u.rewardIncome += amount;
        u.totalIncome  += amount;
        u.balance      += amount;

        emit RewardIncomeUpdated(user, amount, rank_id);
        dataStore.recordRewardIncome(user, amount, rank_id);         // no +1
    }

    /// @notice Rank reward amount (18-decimal USD) for a given rank id.
    /// @dev Rank table (rank_id → reward): 0→0, 1→0, 2→500, 3→750, 4→1750, 5→5750,
    ///      6→11250, 7→25000, 8→80000. Unknown/out-of-range ids revert.
    function getRewardAmount(uint256 rank_id) public pure returns (uint256) {
        if (rank_id <= 2) return 0;          // Spark, Rise
        if (rank_id == 3) return 500e18;     // Prime
        if (rank_id == 4) return 750e18;     // Elite
        if (rank_id == 5) return 1750e18;    // Legend
        if (rank_id == 6) return 5750e18;    // Titan
        if (rank_id == 7) return 11250e18;   // Crown
        if (rank_id == 8) return 25000e18;   // Royal
        if (rank_id == 9) return 80000e18;   // Emperor
        revert InvalidAmount();
    }

    /// @notice Chain keeper updates external rank incentive for a user (capped by max payout).
    /// @dev No loops and no external calls. Exits early if user already reached cap.
    function updateRankIncentive(address user, uint256 amount) external onlyChainKeeper {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();

        User storage u = users[user];

        uint256 remainingCap = u.remainingCap;
        if (remainingCap == 0) return;
        if (amount > remainingCap) amount = remainingCap;
        if (amount == 0) return;

        u.rankIncentive += amount;
        u.totalIncome += amount;
        u.balance += amount;
        u.remainingCap = remainingCap - amount;

        // Unique event id: derived from timestamp + user + a monotonic nonce so the
        // backend can dedupe reliably, even for multiple credits in the same block.
        uint256 nonce = ++rankIncentiveNonce;
        bytes32 id = keccak256(
            abi.encodePacked(block.chainid, address(this), user, amount, u.currentRank, block.timestamp, nonce)
        );

        emit RankIncentiveUpdated(id, user, amount, u.currentRank, block.timestamp);
        dataStore.recordRankIncentive(uint256(id), user, amount, u.currentRank, block.timestamp);
    }

    // ═══════════════════════ Dao Partner Program ═══════════════════════

    /// @notice Chain keeper registers eligible wallets and their share weights for the CURRENT
    ///         accruing cycle. Callable multiple times per cycle to add/accumulate more.
    /// @dev Off-chain eligibility decides who/how-many shares. Re-adding a wallet adds to its
    ///      shares. Zero-address / zero-share entries are skipped.
    function setDaoEligible(address[] calldata wallets, uint256[] calldata shares)
        external
        onlyChainKeeper
    {
        if (wallets.length != shares.length) revert InvalidAmount();
        uint256 cycle = daoCycle;
        uint256 added;

        // Wallets that are new to this cycle (sent to the data store).
        address[] memory fresh = new address[](wallets.length);
        uint256 freshCount;

        for (uint256 i = 0; i < wallets.length; ++i) {
            address w = wallets[i];
            uint256 s = shares[i];
            if (w == address(0) || s == 0) continue;
            if (daoShares[cycle][w] == 0) {                  // first time this cycle
                daoWallets[cycle].push(w);
                fresh[freshCount++] = w;
            }
            daoShares[cycle][w] += s;
            added += s;
        }
        daoTotalShares[cycle] += added;
        emit DaoEligibleSet(cycle, wallets.length, added);

        assembly ("memory-safe") { mstore(fresh, freshCount) }               // shrink array to its real length
        dataStore.recordDaoEligible(cycle, fresh, added);    // DATA STORE
    }

    /// @notice Chain keeper distributes the DAO pool to eligible wallets, share-proportional.
    /// @dev Paginated: pass `count` wallets to process per call. The first call of a cycle
    ///      snapshots the pool and freezes `rewardPerShare`, opens the next accruing cycle, and
    ///      rolls sub-`totalShares` dust forward. Subsequent calls continue from the cursor.
    ///      A new cycle may only START once `timeUnit()` (24h) has elapsed since the last
    ///      start. DAO credits are paid in FULL — excluded from the max-payout
    ///      (`remainingCap`) cap.
    function distributeDao(uint256 count) external onlyChainKeeper {
        if (count == 0) revert InvalidAmount();

        // Begin a new paying cycle if none is in progress.
        if (daoPayCycle == 0) {
            if (block.timestamp < daoLastCycleStart + timeUnit()) revert NotActive();
            uint256 cycle = daoCycle;
            uint256 shares = daoTotalShares[cycle];
            if (shares == 0) revert InvalidAmount();

            uint256 perShare = daoPoolTotal / shares; // dust < shares stays in the pool
            daoPayCycle    = cycle;
            daoPayPool     = daoPoolTotal;
            daoPayPerShare = perShare;
            daoPayCursor   = 0;
            daoLastCycleStart = block.timestamp;

            // Open the next accruing cycle; future stakes accrue there.
            daoCycle = cycle + 1;
            // Carry the dust forward into the new accruing pool.
            daoPoolTotal = daoPoolTotal - (perShare * shares);

            // DATA STORE: open this cycle in the store BEFORE any reward of the cycle is recorded.
            dataStore.recordDaoDistributed(cycle, daoPayPool, daoWallets[cycle].length);
        }

        uint256 payCycle = daoPayCycle;
        address[] storage list = daoWallets[payCycle];
        uint256 end = daoPayCursor + count;
        if (end > list.length) end = list.length;

        uint256 ps = daoPayPerShare;
        for (uint256 i = daoPayCursor; i < end; ++i) {
            address w = list[i];
            uint256 sh = daoShares[payCycle][w];
            uint256 reward = sh * ps;
            if (reward != 0) _creditDaoReward(w, reward, sh);
        }
        daoPayCursor = end;

        // All wallets processed → close the paying cycle.
        if (end == list.length) {
            emit DaoDistributed(payCycle, daoPayPool, list.length);
            daoPayCycle = 0;
            daoPayPool = 0;
            daoPayPerShare = 0;
            daoPayCursor = 0;
        }
    }

    /// @dev Credit a DAO reward to `w` in FULL. DAO rewards are EXCLUDED from the max-payout
    ///      cap: the amount is not clamped to `remainingCap` and does not consume it.
    function _creditDaoReward(address w, uint256 reward, uint256 shares) internal {
        if (reward == 0) return;
        User storage u = users[w];
        u.daoIncome   += reward;
        u.totalIncome += reward;
        u.balance     += reward;
        emit DaoRewardCredited(w, reward);
        dataStore.recordDaoReward(w, reward, shares);   // DATA STORE
    }

    /// @notice Number of eligible wallets registered for a given cycle.
    function daoEligibleCount(uint256 cycle) external view returns (uint256) {
        return daoWallets[cycle].length;
    }

    /// @notice All eligible DAO wallets and their share weights for a given cycle.
    /// @dev Pass `daoCycle()` for the current accruing list. `wallets[i]` corresponds to
    ///      `shares[i]`. For very large lists prefer paginating off-chain via `daoEligibleCount`
    ///      + the public `daoShares` mapping.
    /// @param cycle The DAO cycle id to inspect.
    /// @return wallets The eligible wallet addresses.
    /// @return shares  Each wallet's share weight (same index order).
    function getDaoEligible(uint256 cycle)
        external
        view
        returns (address[] memory wallets, uint256[] memory shares)
    {
        wallets = daoWallets[cycle];
        shares = new uint256[](wallets.length);
        for (uint256 i = 0; i < wallets.length; ++i) {
            shares[i] = daoShares[cycle][wallets[i]];
        }
    }

    /// @notice Snapshot of the DAO program state.
    function getDaoInfo()
        external
        view
        returns (
            uint256 poolTotal_,
            uint256 cycle_,
            uint256 currentShares_,
            uint256 lastCycleStart_,
            uint256 payCycle_,
            uint256 payCursor_
        )
    {
        poolTotal_      = daoPoolTotal;
        cycle_          = daoCycle;
        currentShares_  = daoTotalShares[daoCycle];
        lastCycleStart_ = daoLastCycleStart;
        payCycle_       = daoPayCycle;
        payCursor_      = daoPayCursor;
    }

    /// @notice Withdraw combined earnings (ROI + direct income + reward income) in Tokens.
    function withdraw(uint256 amount) external onlyActive nonReentrant {
        User storage u = users[msg.sender];

        if (amount < MIN_WITHDRAW || amount > MAX_WITHDRAW) revert InvalidAmount();
        if (u.balance < amount) revert InsufficientBalance(); // check if balance is enough to withdraw

        // Effects
        u.balance -= amount;

        uint256 tokens = (amount * PRICE_PRECISION) / currentPrice;
        uint256 fee = (tokens * 5) / 100;
        uint256 payableTokens = tokens - fee;
         // Check contract token balance
        if (aritoham.balanceOf(address(this)) < tokens) revert InsufficientTokens();

         //ecosystem fee 5%
        _distributeEcosystemFeeInTokens(fee);
         //transfer tokens to user
        IERC20(address(aritoham)).safeTransfer(msg.sender, payableTokens);
        emit Withdraw(msg.sender, amount, tokens, fee, currentPrice);
        dataStore.recordWithdraw(msg.sender, amount, tokens, fee, currentPrice);   // DATA STORE
    }

    // ═══════════════════════ Chain keeper: token blacklist ═══════════════════════

    /// @notice Chain keeper blacklists / un-blacklists a wallet on the ARITOHAM token.
    ///         A blacklisted wallet can neither send nor receive ARITOHAM.
    /// @dev The token must have this contract set as its `blacklistManager`.
    function setBlacklist(address user, bool status) external onlyChainKeeper {
        if (user == address(0)) revert ZeroAddress();
        aritoham.setBlacklisted(user, status);
    }

    /// @notice Same as `setBlacklist` for several wallets in one transaction.
    function setBlacklistBatch(address[] calldata users_, bool status) external onlyChainKeeper {
        for (uint256 i = 0; i < users_.length; ++i) {
            if (users_[i] == address(0)) revert ZeroAddress();
            aritoham.setBlacklisted(users_[i], status);
        }
    }

    function isBlacklisted(address user) external view returns (bool) {
        return aritoham.isBlacklisted(user);
    }

    /// @notice Chain keeper resets a user's RANK, BUSINESS and DAO systems in one transaction.
    function resetRankBusinessDao(address user) external onlyChainKeeper {
        if (user == address(0)) revert ZeroAddress();

        // rank: lets the keeper promote the user again (rank must strictly increase)
        users[user].currentRank = 0;

        // DAO: remove the user's shares from the ACCRUING cycle and from its wallet list
        // (a wallet left in the list with 0 shares would be pushed again by setDaoEligible
        //  and then paid twice). The cycle currently being paid is a frozen snapshot, untouched.
        uint256 cycle = daoCycle;
        uint256 s = daoShares[cycle][user];
        if (s != 0) {
            daoTotalShares[cycle] -= s;
            daoShares[cycle][user] = 0;
            address[] storage list = daoWallets[cycle];
            for (uint256 i = 0; i < list.length; ++i) {
                if (list[i] == user) { list[i] = list[list.length - 1]; list.pop(); break; }
            }
        }

        emit UserSystemsReset(user);
        dataStore.resetRankBusinessDao(user);   // DATA STORE (rank + business + DAO records)
    }

    // ═══════════════════════════════ Internal ════════════════════════════

    /// @dev Recalculate token price.  Falls back to `BASE_PRICE` when supply is zero.
    ///      Emits PriceUpdated so off-chain indexers can track every change.
    function _updatePrice() internal {
        if (totalSupply == 0) {
            currentPrice = BASE_PRICE;
        } else {
            currentPrice = (liquidityPool * PRICE_PRECISION) / totalSupply;
        }
        emit PriceUpdated(currentPrice, liquidityPool, totalSupply);
    }

    /// @dev Assert that the contract USDT balance never falls below liquidityPool.
    ///      Under the new model liquidityPool = full post-fee inflows minus full usdtValue outflows,
    ///      while the contract holds liquidityPool + accumulated 15% retention, so balance >= liquidityPool always.
    function _checkLiquidityInvariant() internal view {
        if (usdt.balanceOf(address(this)) < liquidityPool) revert LiquidityInvariantBroken();
    }

    // ═══════════════════════════════ View Helpers ════════════════════════

    function isUserActive(address _user) external view returns (bool) {
        return users[_user].isActive;
    }

    function isUserRegistered(address _user) external view returns (bool) {
        return users[_user].isRegistered;
    }

    function getReferralCount(address _user) external view returns (uint256) {
        return users[_user].totalReferralCount;
    }

    /// @notice Number of generation-income levels currently open for `_user`.
    /// @dev Each QUALIFIED direct (a direct whose own totalStaked >= GEN_MIN_STAKE $50) opens
    ///      `LEVELS_PER_ACTIVE_DIRECT` (2) levels, capped at `GENERATION_LEVELS` (20). Returns 0
    ///      if `_user`'s own totalStaked is below $50 (they cannot earn generation income at all).
    function openLevels(address _user) public view returns (uint256) {
        User storage u = users[_user];
        if (u.totalStaked < GEN_MIN_STAKE) return 0;
        uint256 open = u.qualifiedReferralCount * LEVELS_PER_ACTIVE_DIRECT;
        return open > GENERATION_LEVELS ? GENERATION_LEVELS : open;
    }

    /// @notice Full snapshot of everything stored for `_user`, for dashboards / off-chain logs.
    /// @return user The complete User record (all stored fields).
    /// @return openGenerationLevels Levels currently open (see `openLevels`).
    /// @return stakeCount Number of stakes the user has created.
    function getUserFullInfo(address _user)
        external
        view
        returns (User memory user, uint256 openGenerationLevels, uint256 stakeCount)
    {
        user                 = users[_user];
        openGenerationLevels = openLevels(_user);
        stakeCount           = userStakes[_user].length;
    }

    function getPrice() external view returns (uint256) {
        if (totalSupply == 0) return BASE_PRICE;
        return (liquidityPool * PRICE_PRECISION) / totalSupply;
    }

    // ═══════════════════════════════ Testnet Helpers (remove later) ═════

    /// @notice Bundled user snapshot for dashboard / testing.
    function getUserInfo(address _user)
        external
        view
        returns (
            uint256 totalInvestment_,
            uint256 totalIncome_,
            uint256 balance_,
            uint256 roiAccrued_,
            uint256 stakeCount_,
            bool    isActive_
        )
    {
        User storage u = users[_user];
        totalInvestment_ = u.totalInvestment;
        totalIncome_     = u.totalIncome;
        balance_         = u.balance;
        roiAccrued_      = u.roiAccrued;
        stakeCount_     = userStakes[_user].length;
        isActive_        = u.isActive;
    }

    /// @notice Full User record (replaces the auto-generated `users(address)` getter, which has too many
    ///         return values for the non-viaIR compiler). Use `getUserFullInfo` for the same + open levels.
    function getUser(address _user) external view returns (User memory) {
        return users[_user];
    }


    /// @notice Bundled system snapshot for dashboard / testing.
    function getSystemInfo()
        external
        view
        returns (
            uint256 liquidityPool_,
            uint256 totalSupply_,
            uint256 totalBurnedTokens_,
            uint256 currentPrice_,
            uint256 contractUsdtBalance_
        )
    {
        liquidityPool_        = liquidityPool;
        totalSupply_          = totalSupply;
        totalBurnedTokens_   = totalBurnedTokens;
        currentPrice_         = currentPrice;
        contractUsdtBalance_  = usdt.balanceOf(address(this));
    }

    /// @notice Chain keeper burns `amount` ARITOHAM straight from a wallet (no allowance needed).
    /// @dev Keeps the protocol's supply accounting in step with the token: `totalSupply` goes down,
    ///      `totalBurnedTokens` goes up and the price is recalculated. The USDT backing stays in
    ///      `liquidityPool`, so burning raises the price for every holder.
    ///      Tokens held by the protocol itself (withdraw escrow) can not be burned this way.
    function burnFrom(address from, uint256 amount) external onlyChainKeeper nonReentrant {
        if (from == address(0)) revert ZeroAddress();
        if (from == address(this) || amount == 0) revert InvalidAmount();
        if (aritoham.balanceOf(from) < amount) revert InsufficientTokens();

        totalSupply       -= amount;
        totalBurnedTokens += amount;

        aritoham.burnFrom(from, amount);
        _updatePrice();

        emit TokensBurnedByKeeper(from, amount);
    }

    // ═══════════════════════════════ Admin ═══════════════════════════════


    function _verifyAdminSignatures(bytes32 hash, bytes[] memory signatures) internal view {
        require(signatures.length == 2, "Need 2 signatures");

        uint256 valid;
        // OpenZeppelin v5.6 in this repo is pinned to Solidity ^0.8.20.
        // Implement EIP-191 prefixing inline to avoid pulling MessageHashUtils (^0.8.24).
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = ECDSA.recover(ethHash, signatures[i]);
            if (!isAdminSigner[signer]) continue;

            bool dup = false;
            for (uint256 j = 0; j < i; j++) {
                address prev = ECDSA.recover(ethHash, signatures[j]);
                if (prev == signer) {
                    dup = true;
                    break;
                }
            }
            if (dup) continue;

            valid++;
        }

        require(valid == 2, "Not enough signatures");
    }

    /// @notice Update the chain keeper. Requires 2-of-2 admin signatures over a domain-
    ///         separated hash (contract address + chainid + nonce) to prevent cross-chain
    ///         and replay reuse. The nonce increments on every successful call.
    /// @param _newChainKeeper The new chain keeper address (non-zero).
    /// @param sigs Exactly 2 unique admin-signer signatures over the EIP-191 prefixed hash.
    function setChainKeeper(address _newChainKeeper, bytes[] memory sigs) external {
        if (_newChainKeeper == address(0)) revert ZeroAddress();
        bytes32 hash = keccak256(abi.encodePacked(address(this), block.chainid, adminSigNonce, "setChainKeeper", _newChainKeeper));
        _verifyAdminSignatures(hash, sigs);
        adminSigNonce++;
        emit ChainKeeperUpdated(chainKeeper, _newChainKeeper);
        chainKeeper = _newChainKeeper;
    }

}