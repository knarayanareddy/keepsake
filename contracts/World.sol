// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HonorLog} from "./HonorLog.sol";

/// @title KEEPSAKE World — 16×16 arena. World is the only attester.
/// Pact is one-way and instant. Spare / betrayal / pact attest inline.
contract World {
    uint8 public constant W = 16;
    uint8 public constant MAX_HP = 5;
    uint8 public constant MAX_AMMO = 6;

    /// @notice A `spare` is only a fact if the other player was genuinely in danger:
    ///         at most SPARE_WINDOW hit points left AND still able to shoot back.
    ///         Without this, `spared >= 1` is mintable by clicking a healthy neighbour
    ///         six times (deep dive C1) and the portable primitive means nothing.
    uint8 public constant SPARE_WINDOW = 2;

    HonorLog public immutable log;

    struct Match {
        bool live;
        uint64 startedAt;
        uint32 players;
    }

    struct Player {
        uint8 x;
        uint8 y;
        uint8 hp;
        uint8 ammo;
        bool alive;
        bool joined;
        bytes32 matchId;
        uint16 pactKept;
        uint16 pactBroken;
        uint16 spared;
    }

    bytes32 public currentMatch;
    mapping(bytes32 => Match) public matches;
    mapping(address => Player) public players;

    address public owner;

    /// one-way: from => to => live pact (in current match)
    mapping(address => mapping(address => bytes32)) public pactUID;
    mapping(address => mapping(address => bool)) public hasPact;
    /// which match a pact UID was minted in — a pact never survives the match that made it
    mapping(bytes32 => bytes32) public pactMatch;
    /// a pact that was honoured (they were spared while it was live); revoked if it ends in betrayal
    mapping(bytes32 => bool) public pactHonoured;
    /// one Conduct attestation per (player, match)
    mapping(bytes32 => mapping(address => bool)) public conductSealed;

    event Spawned(bytes32 matchId, address player, uint8 x, uint8 y);
    event Moved(address player, uint8 x, uint8 y);
    event Shot(address shooter, address victim, uint8 hpLeft, bool killed);
    event MatchStarted(bytes32 matchId);
    event MatchSealed(bytes32 matchId);

    error Dead();
    error NotInMatch();
    error Oob();
    error NoAmmo();
    error SamePlayer();
    error NotAdjacent();
    error AlreadyLive();
    /// @notice victim was not actually one swing away from dying, or was unarmed (C1)
    error NotKillShot();
    /// @notice a live pact already exists for this pair (C8: it used to stack + orphan a UID)
    error AlreadyPacted();
    /// @notice conduct already rolled up for this match (C9)
    error AlreadySealed();
    /// @notice match rotation is deployer-only (C5: anyone could brick the live board)
    error NotOwner();

    constructor(HonorLog _log) {
        log = _log;
        owner = msg.sender;
        _newMatch();
    }

    /// @notice Starts a fresh 16x16 match and orphans the old one. Gated: an open
    ///         `startMatch()` lets any wallet on a public testnet freeze every live
    ///         player mid-demo (deep dive C5).
    function startMatch() external {
        if (msg.sender != owner) revert NotOwner();
        _newMatch();
    }

    function _newMatch() internal {
        currentMatch = keccak256(abi.encodePacked(block.number, block.prevrandao, address(this)));
        matches[currentMatch] = Match({live: true, startedAt: uint64(block.number), players: 0});
        emit MatchStarted(currentMatch);
    }

    function spawn() external {
        Player storage p = players[msg.sender];
        if (p.joined && p.matchId == currentMatch && p.alive) revert AlreadyLive();
        uint256 h = uint256(keccak256(abi.encodePacked(msg.sender, currentMatch, block.number)));
        uint8 x = uint8(h % W);
        uint8 y = uint8((h / W) % W);
        p.x = x;
        p.y = y;
        p.hp = MAX_HP;
        p.ammo = MAX_AMMO;
        p.alive = true;
        p.joined = true;
        p.matchId = currentMatch;
        p.pactKept = 0;
        p.pactBroken = 0;
        p.spared = 0;
        matches[currentMatch].players++;
        emit Spawned(currentMatch, msg.sender, x, y);
    }

    function move(int8 dx, int8 dy) external {
        Player storage p = _requireLive();
        int16 nx = int16(uint16(p.x)) + int16(dx);
        int16 ny = int16(uint16(p.y)) + int16(dy);
        if (nx < 0 || ny < 0 || nx >= int16(uint16(W)) || ny >= int16(uint16(W))) revert Oob();
        // chebyshev step of 1
        uint16 adx = dx < 0 ? uint16(uint8(-dx)) : uint16(uint8(dx));
        uint16 ady = dy < 0 ? uint16(uint8(-dy)) : uint16(uint8(dy));
        if (adx > 1 || ady > 1 || (adx + ady) == 0) revert Oob();
        p.x = uint8(uint16(nx));
        p.y = uint8(uint16(ny));
        emit Moved(msg.sender, p.x, p.y);
    }

    /// One-way, instant. A declares trust in B. B never had to agree.
    function pact(address other) external {
        if (other == msg.sender) revert SamePlayer();
        Player storage p = _requireLive();
        Player storage o = players[other];
        if (!o.alive || o.matchId != p.matchId) revert NotInMatch();
        if (!_adj(p, o)) revert NotAdjacent();

        if (_livePact(msg.sender, other, p.matchId) != bytes32(0)) revert AlreadyPacted();

        bytes32 uid = log.attest(
            log.SCHEMA_PACT(),
            msg.sender,
            other,
            p.matchId,
            log.KIND_PACT(),
            0,
            bytes32(0)
        );
        hasPact[msg.sender][other] = true;
        pactUID[msg.sender][other] = uid;
        pactMatch[uid] = p.matchId;
    }

    /// Had a kill shot. Chose not to take it.
    function spare(address other) external {
        if (other == msg.sender) revert SamePlayer();
        Player storage p = _requireLive();
        Player storage o = players[other];
        if (!o.alive || o.matchId != p.matchId) revert NotInMatch();
        if (!_adj(p, o)) revert NotAdjacent();
        if (p.ammo == 0) revert NoAmmo();
        // "had a kill shot" must be true, not just claimed: the victim has to be within
        // SPARE_WINDOW of death and still armed. (deep dive C1)
        if (o.hp > SPARE_WINDOW || o.ammo == 0) revert NotKillShot();
        p.ammo--;
        p.spared++;
        // The score was silently ignoring kept pacts (deep dive C1d / HANDOVER §5).
        // A pact counts as kept when you spared the person you had pledged to —
        // and `pactHonoured` lets a later betrayal of *that* pact take the credit back,
        // so "kept" never coexists with "broke" for the same UID.
        bytes32 honoured = _livePact(msg.sender, other, p.matchId);
        if (honoured != bytes32(0) && !pactHonoured[honoured]) {
            p.pactKept++;
            pactHonoured[honoured] = true;
        }

        log.attest(
            log.SCHEMA_SPARE(),
            msg.sender,
            other,
            p.matchId,
            log.KIND_SPARE(),
            o.hp,
            bytes32(0)
        );
    }

    function shoot(address other) external {
        if (other == msg.sender) revert SamePlayer();
        Player storage p = _requireLive();
        Player storage o = players[other];
        if (!o.alive || o.matchId != p.matchId) revert NotInMatch();
        if (!_adj(p, o)) revert NotAdjacent();
        if (p.ammo == 0) revert NoAmmo();
        p.ammo--;

        // Betrayal only if YOU hold a live pact on them — made in this match, so `refUID`
        // can never dangle into a previous one (deep dive C4).
        bytes32 ref = _livePact(msg.sender, other, p.matchId);
        if (ref != bytes32(0)) {
            log.attest(
                log.SCHEMA_BETRAYAL(),
                msg.sender,
                other,
                p.matchId,
                log.KIND_BETRAYAL(),
                0,
                ref
            );
            hasPact[msg.sender][other] = false;
            delete pactUID[msg.sender][other];
            if (pactHonoured[ref]) {
                pactHonoured[ref] = false;
                if (p.pactKept > 0) p.pactKept--;   // you did not, in the end, keep it
            }
            p.pactBroken++;
        }

        if (o.hp <= 1) {
            o.hp = 0;
            o.alive = false;
            emit Shot(msg.sender, other, 0, true);
        } else {
            o.hp--;
            emit Shot(msg.sender, other, o.hp, false);
        }
    }

    /// Optional end-of-match conduct rollup, once per (player, match). Not required for the demo —
    /// spare/pact/betray already minted. This is the "future DAO reads score" object.
    function sealMe() external {
        Player storage p = players[msg.sender];
        if (p.matchId == bytes32(0)) revert NotInMatch();
        if (conductSealed[p.matchId][msg.sender]) revert AlreadySealed();
        conductSealed[p.matchId][msg.sender] = true;
        int16 score = int16(uint16(p.pactKept)) + int16(uint16(p.spared)) * 2 - int16(uint16(p.pactBroken)) * 3;
        log.attest(
            log.SCHEMA_CONDUCT(),
            msg.sender,
            address(0),
            p.matchId,
            log.KIND_CONDUCT(),
            uint8(uint16(score < 0 ? 0 : uint16(score > 255 ? 255 : uint16(score)))),
            bytes32(0)
        );
        emit MatchSealed(p.matchId);
    }

    /// @dev A pact is live only inside the match that minted it. Stale pacts from a
    ///      previous match must not (a) block a new pact, (b) count as "kept", or
    ///      (c) turn the next shot into a Betrayal with a cross-match refUID (C4).
    function _livePact(address from, address to, bytes32 matchId) internal view returns (bytes32 uid) {
        uid = pactUID[from][to];
        if (uid == bytes32(0) || pactMatch[uid] != matchId) return bytes32(0);
    }

    /// @notice Read-only provenance for the UI / any future consumer: the live pact
    ///         between `from` and `to` right now, or bytes32(0).
    function livePact(address from, address to) external view returns (bytes32) {
        Player storage p = players[from];
        if (!p.joined || p.matchId != currentMatch || !p.alive) return bytes32(0);
        return _livePact(from, to, currentMatch);
    }

    function _requireLive() internal view returns (Player storage p) {
        p = players[msg.sender];
        if (!p.joined || p.matchId != currentMatch) revert NotInMatch();
        if (!p.alive) revert Dead();
    }

    function _adj(Player storage a, Player storage b) internal view returns (bool) {
        uint8 dx = a.x > b.x ? a.x - b.x : b.x - a.x;
        uint8 dy = a.y > b.y ? a.y - b.y : b.y - a.y;
        return dx <= 1 && dy <= 1 && !(dx == 0 && dy == 0);
    }

    function viewPlayer(address a) external view returns (Player memory) {
        return players[a];
    }
}
