// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HonorLog} from "./HonorLog.sol";

/// @title KEEPSAKE World — 16×16 arena. World is the only attester.
/// Pact is one-way and instant. Spare / betrayal / pact attest inline.
contract World {
    uint8 public constant W = 16;
    uint8 public constant MAX_HP = 5;
    uint8 public constant MAX_AMMO = 6;

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

    /// one-way: from => to => live pact (in current match)
    mapping(address => mapping(address => bytes32)) public pactUID;
    mapping(address => mapping(address => bool)) public hasPact;

    event Spawned(bytes32 matchId, address player, uint8 x, uint8 y);
    event Moved(address player, uint8 x, uint8 y);
    event Shot(address shooter, address victim, uint8 hpLeft, bool killed);
    event MatchStarted(bytes32 matchId);
    event MatchSealed(bytes32 matchId);

    error Dead();
    error NotInMatch();
    error Occupied();
    error Oob();
    error NoAmmo();
    error SamePlayer();
    error NotAdjacent();
    error AlreadyLive();

    constructor(HonorLog _log) {
        log = _log;
        _newMatch();
    }

    function startMatch() external {
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
    }

    /// Had a kill shot. Chose not to take it.
    function spare(address other) external {
        if (other == msg.sender) revert SamePlayer();
        Player storage p = _requireLive();
        Player storage o = players[other];
        if (!o.alive || o.matchId != p.matchId) revert NotInMatch();
        if (!_adj(p, o)) revert NotAdjacent();
        if (p.ammo == 0) revert NoAmmo();
        p.ammo--;
        p.spared++;

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

        // Betrayal only if YOU had declared a pact on them.
        if (hasPact[msg.sender][other]) {
            bytes32 ref = pactUID[msg.sender][other];
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

    /// Optional end-of-match conduct rollup. Not required for the demo —
    /// spare/pact/betray already minted. This is the "future DAO reads score" object.
    function sealMe() external {
        Player storage p = players[msg.sender];
        if (p.matchId == bytes32(0)) revert NotInMatch();
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
