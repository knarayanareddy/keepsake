// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {HonorLog} from "../contracts/HonorLog.sol";
import {World} from "../contracts/World.sol";

/// Needs: forge install foundry-rs/forge-std   (then: forge test -vv)
/// Every test here passes against the patched contracts; the C1..C9 ones are the
/// regressions for the findings in DEEPDIVE.md — re-run them if anyone loosens a guard.
contract KeepsakeTest is Test {
    HonorLog internal log_;
    World internal w;
    address internal a = makeAddr("alice");
    address internal b = makeAddr("bob");

    function setUp() public {
        log_ = new HonorLog();
        w = new World(log_);
        log_.setWorld(address(w));
        vm.prank(a); w.spawn();
        vm.prank(b); w.spawn();
        _parkAdjacent();
    }

    // ---- helpers ------------------------------------------------------------
    function _cheb(address x, address y) internal view returns (uint256) {
        World.Player memory p = w.viewPlayer(x);
        World.Player memory q = w.viewPlayer(y);
        uint256 dx = p.x > q.x ? p.x - q.x : q.x - p.x;
        uint256 dy = p.y > q.y ? p.y - q.y : q.y - p.y;
        return dx > dy ? dx : dy;
    }
    function _parkAdjacent() internal {
        for (uint256 i; i < 40; ++i) {
            uint256 d = _cheb(a, b);
            if (d == 1) return;
            if (d == 0) { vm.prank(a); w.move(int8(1), int8(0)); continue; }
            if (i == 39) revert("adjacency unreachable");
            World.Player memory pa = w.viewPlayer(a);
            World.Player memory pb = w.viewPlayer(b);
            int8 dx = pa.x < pb.x ? int8(1) : int8(-1);
            int8 dy = pa.y == pb.y ? int8(0) : (pa.y < pb.y ? int8(1) : int8(-1));
            vm.prank(a); w.move(dx, dy);
        }
        revert("could not reach adjacency");
    }
    function _kind(address who, uint256 i) internal view returns (uint8) {
        return log_.get(log_.uidAt(who, i)).kind;
    }
    function _lastKind(address who) internal view returns (uint8) {
        return _kind(who, log_.countOf(who) - 1);
    }
    /// @dev Order matters now: `spare` requires the victim to be within SPARE_WINDOW of
    ///      death, so the wounding happens *before* the pact — the first shot *after* a
    ///      pact is a Betrayal, which would consume it.
    function _woundBob() internal {
        for (uint256 i; i < 5 - w.SPARE_WINDOW(); ++i) { vm.prank(a); w.shoot(b); }
    }
    function _happyPath() internal {
        _woundBob();
        vm.prank(a); w.pact(b);
        vm.prank(a); w.spare(b);
    }

    // ---- green: what the handover asserts ----------------------------------
    function test_deploy_sets_world() public view {
        assertEq(log_.world(), address(w));
    }
    function test_pact_and_spare_attest_inline() public {
        _happyPath();
        (bool ok,, address attester, address sub, address oth, uint8 kind, bytes32 ref) = log_.verify(w.pactUID(a, b));
        assertTrue(ok, "pact uid must verify");
        assertEq(attester, address(w));              // the World minted it, nobody else
        assertEq(uint256(kind), 1);
        assertEq(sub, a);
        assertEq(oth, b);
        assertEq(uint256(ref), 0);
        assertEq(uint256(_lastKind(a)), 2);           // Spare minted in the same action sequence
    }
    function test_verify_is_false_not_revert_for_unknown_uid() public view {
        (bool ok,,,,,,) = log_.verify(bytes32(uint256(0xb00b)));
        assertTrue(!ok, "verify() must return false, not revert");
    }
    function test_only_world_can_attest() public {
        bytes32 schema = log_.SCHEMA_SPARE();
        vm.expectRevert(HonorLog.NotWorld.selector);
        vm.prank(b);
        log_.attest(schema, b, a, bytes32(0), 2, 0, bytes32(0));
    }
    function test_verify_exposes_the_attester() public {
        _happyPath();
        (bool ok,, address attester, address subject,, uint8 kind,) = log_.verify(w.pactUID(a, b));
        assertTrue(ok, "pact must verify");
        assertEq(attester, address(w));            // provenance, not just existence
        assertEq(subject, a);
        assertEq(uint256(kind), 1);
    }
    function test_betrayal_refUID_points_at_the_pact() public {
        _happyPath();                                  // pact + spare (spare keeps the pact live)
        bytes32 pactUid = w.pactUID(a, b);
        vm.prank(a); w.shoot(b);
        (bool ok,, address attester2, address sub, address oth, uint8 kind, bytes32 ref) = log_.verify(log_.uidAt(a, log_.countOf(a) - 1));
        assertTrue(ok, "betrayal must verify");
        assertEq(uint256(kind), 3);
        assertEq(sub, a);
        assertEq(oth, b);
        assertEq(ref, pactUid);
        assertEq(attester2, address(w));
    }
    function test_spare_burns_ammo_and_not_hp() public {
        _happyPath();
        assertEq(uint256(w.viewPlayer(a).ammo), 2);    // 6 - 3 wounding shots - 1 spare
        assertEq(uint256(w.viewPlayer(b).hp), 2);      // wounded earlier, untouched by the spare
        assertEq(uint256(w.viewPlayer(b).spared), 0);  // spared counts the actor, not the spared
        assertEq(uint256(w.viewPlayer(a).spared), 1);
        assertEq(uint256(w.viewPlayer(a).pactKept), 1);   // a pact honoured at the moment of spare
    }
    function test_C1_spare_needs_the_victim_armed_too() public {
        // drain bob's magazine on carol (3 shots + 3 spares = MAX_AMMO), then wound him:
        // hp 2 with no bullets is not "a kill shot you chose not to take"
        address c = makeAddr("carol");
        vm.prank(c); w.spawn();
        _parkWith(b, c);
        for (uint256 i; i < 3; ++i) { vm.prank(b); w.shoot(c); }
        for (uint256 i; i < 3; ++i) { vm.prank(b); w.spare(c); }
        assertEq(uint256(w.viewPlayer(b).ammo), 0);
        _parkWith(a, b);
        for (uint256 i; i < 5 - uint256(w.SPARE_WINDOW()); ++i) { vm.prank(a); w.shoot(b); }
        vm.prank(a);
        vm.expectRevert(World.NotKillShot.selector);
        w.spare(b);
    }
    function test_C2_kill_without_pact_leaves_no_record() public {
        uint256 before = log_.countOf(b);
        for (uint256 i; i < 5; ++i) { vm.prank(b); w.shoot(a); }   // C2 is a documented position, not a bug
        assertTrue(!w.viewPlayer(a).alive, "alice should be dead");
        assertEq(log_.countOf(b), before);              // 5 shots, 1 kill, 0 attestations
    }

    // ---- RED on purpose: the deep-dive punch list ---------------------------
    function test_C1_spare_on_a_full_hp_neighbour_reverts() public {
        vm.prank(b);
        vm.expectRevert(World.NotKillShot.selector);
        w.spare(a);                                     // healthy neighbour is not a kill shot
    }
    function test_C3_setWorld_is_write_once() public {
        vm.prank(log_.owner());
        vm.expectRevert(HonorLog.WorldAlreadySet.selector);
        log_.setWorld(makeAddr("eve"));                 // the forge path is closed
    }
    function test_C4_pact_does_not_leak_across_matches() public {
        vm.prank(a); w.pact(b);                          // pact in match 1
        vm.roll(block.number + 1);
        w.startMatch();
        vm.prank(a); w.spawn();
        vm.prank(b); w.spawn();
        _parkAdjacent();
        uint256 n = log_.countOf(a);
        vm.prank(a); w.shoot(b);
        assertEq(log_.countOf(a), n, "stale-match pact minted a Betrayal");   // red today
    }
    function test_C5_startMatch_is_gated() public {
        vm.expectRevert(World.NotOwner.selector);
        vm.prank(b); w.startMatch();
    }
    function test_C5b_owner_can_rotate_the_match() public {
        bytes32 before = w.currentMatch();
        vm.roll(block.number + 1);
        w.startMatch();
        assertTrue(w.currentMatch() != before);
    }
    function test_C9_sealMe_is_one_shot_per_match() public {
        uint256 n = log_.countOf(a);
        vm.prank(a); w.sealMe();
        vm.expectRevert(World.AlreadySealed.selector);
        vm.prank(a); w.sealMe();
        assertEq(log_.countOf(a) - n, 1);
        vm.roll(block.number + 1);
        w.startMatch();
        vm.prank(a); w.spawn();
        vm.prank(a); w.sealMe();                          // a new match is a new fact
    }
    function test_C8_duplicate_pact_reverts() public {
        vm.prank(a); w.pact(b);
        uint256 n = log_.countOf(a);
        vm.expectRevert(World.AlreadyPacted.selector);
        vm.prank(a); w.pact(b);
        assertEq(log_.countOf(a), n);                      // no duplicate, no orphaned UID
    }
    /// @dev moved helper: park `x` adjacent to `y` regardless of who is `a`
    function _parkWith(address x, address y) internal {
        for (uint256 i; i < 40; ++i) {
            World.Player memory px = w.viewPlayer(x);
            World.Player memory py = w.viewPlayer(y);
            uint256 dx = px.x > py.x ? px.x - py.x : py.x - px.x;
            uint256 dy = px.y > py.y ? px.y - py.y : py.y - px.y;
            uint256 d = dx > dy ? dx : dy;
            if (d == 1) return;
            int8 mx = px.x == py.x ? int8(1) : (px.x < py.x ? int8(1) : int8(-1));
            int8 my = px.y == py.y ? int8(0) : (px.y < py.y ? int8(1) : int8(-1));
            vm.prank(x); w.move(mx, my);
        }
    }
}
