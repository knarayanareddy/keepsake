// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title HonorLog — EAS-shaped attestations. World is the only attester.
/// Schema UIDs are keccak of the schema string. Record UID is a hash of the full record.
contract HonorLog {
    struct Attestation {
        bytes32 uid;
        bytes32 schema;
        address attester;
        address subject; // the person the fact is ABOUT
        address other;   // counterparty (pact peer, spared, victim)
        bytes32 matchId;
        uint64 blockNumber;
        bytes32 refUID;  // e.g. Betrayal points at Pact UID
        uint8 kind;      // 1 pact 2 spare 3 betrayal 4 conduct
        uint8 extra;     // hpLeft, score-ish, unused
        bool revoked;
    }

    // kind
    uint8 public constant KIND_PACT = 1;
    uint8 public constant KIND_SPARE = 2;
    uint8 public constant KIND_BETRAYAL = 3;
    uint8 public constant KIND_CONDUCT = 4;

    bytes32 public constant SCHEMA_PACT =
        keccak256("Pact(address partyA,address partyB,bytes32 matchId,uint64 blockNumber)");
    bytes32 public constant SCHEMA_SPARE =
        keccak256("Spare(address savior,address spared,bytes32 matchId,uint8 hpLeft)");
    bytes32 public constant SCHEMA_BETRAYAL =
        keccak256("Betrayal(address traitor,address victim,bytes32 matchId,bytes32 pactUID)");
    bytes32 public constant SCHEMA_CONDUCT =
        keccak256("Conduct(address player,bytes32 matchId,uint16 pactKept,uint16 pactBroken,uint16 spared,int16 score)");

    address public world;
    address public owner;

    mapping(bytes32 => Attestation) public attestations;
    mapping(address => bytes32[]) public ofSubject;
    uint256 public nonce;

    event Attested(
        bytes32 indexed uid,
        bytes32 indexed schema,
        address indexed subject,
        address attester,
        address other,
        bytes32 matchId,
        uint8 kind,
        bytes32 refUID
    );

    error NotWorld();
    error NotOwner();
    error UnknownUID();
    /// @notice `world` is write-once: the attester can never be re-pointed after it is set.
    error WorldAlreadySet();

    constructor() {
        owner = msg.sender;
    }

    /// @notice Write-once. Without the one-shot guard the owner could point `world` at
    ///         an attacker contract and mint any "fact about anyone" (deep dive C3).
    function setWorld(address w) external {
        if (msg.sender != owner) revert NotOwner();
        if (world != address(0)) revert WorldAlreadySet();
        if (w == address(0)) revert NotWorld();
        world = w;
    }

    /// @notice Optional, one-way: give up the right to ever call setWorld again.
    function renounceOwner() external {
        if (msg.sender != owner) revert NotOwner();
        owner = address(0);
    }

    function attest(
        bytes32 schema,
        address subject,
        address other,
        bytes32 matchId,
        uint8 kind,
        uint8 extra,
        bytes32 refUID
    ) external returns (bytes32 uid) {
        if (msg.sender != world) revert NotWorld();
        uid = keccak256(
            abi.encode(
                schema,
                msg.sender,
                subject,
                other,
                matchId,
                block.number,
                refUID,
                kind,
                extra,
                nonce++
            )
        );
        attestations[uid] = Attestation({
            uid: uid,
            schema: schema,
            attester: msg.sender,
            subject: subject,
            other: other,
            matchId: matchId,
            blockNumber: uint64(block.number),
            refUID: refUID,
            kind: kind,
            extra: extra,
            revoked: false
        });
        ofSubject[subject].push(uid);
        emit Attested(uid, schema, subject, msg.sender, other, matchId, kind, refUID);
    }

    function get(bytes32 uid) external view returns (Attestation memory) {
        if (attestations[uid].uid == bytes32(0)) revert UnknownUID();
        return attestations[uid];
    }

    function countOf(address subject) external view returns (uint256) {
        return ofSubject[subject].length;
    }

    function uidAt(address subject, uint256 i) external view returns (bytes32) {
        return ofSubject[subject][i];
    }

    /// @notice Portable primitive: any future contract can call this.
    /// @dev    Returns `attester` so a consumer can require provenance
    ///         (`attester == world`) without a second `get()` call — "verified"
    ///         vs "verified-as-to-provenance". Returns false rather than reverting
    ///         so callers can `if (!ok) revert` in one eth_call.
    function verify(bytes32 uid)
        external
        view
        returns (bool ok, bytes32 schema, address attester, address subject, address other, uint8 kind, bytes32 refUID)
    {
        Attestation memory a = attestations[uid];
        if (a.uid == bytes32(0) || a.revoked) return (false, bytes32(0), address(0), address(0), address(0), 0, bytes32(0));
        return (true, a.schema, a.attester, a.subject, a.other, a.kind, a.refUID);
    }
}
