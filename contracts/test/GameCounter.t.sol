// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {GameCounter} from "../src/GameCounter.sol";

interface Vm {
    function prank(address) external;
}

/// Minimal tests without external libraries (forge runs every test* function).
contract GameCounterTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    GameCounter private counter;

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);

    function setUp() public {
        counter = new GameCounter();
    }

    function testStartsEmpty() public view {
        require(counter.totalGames() == 0, "total");
        require(counter.playerCount() == 0, "players");
        (address[] memory a, uint256[] memory c) = counter.players(0, 10);
        require(a.length == 0 && c.length == 0, "empty page");
    }

    function testCountsGamesPerPlayer() public {
        vm.prank(ALICE);
        counter.startGame();
        vm.prank(ALICE);
        counter.startGame();
        vm.prank(BOB);
        counter.startGame();
        require(counter.gamesPlayed(ALICE) == 2, "alice");
        require(counter.gamesPlayed(BOB) == 1, "bob");
        require(counter.totalGames() == 3, "total");
        require(counter.playerCount() == 2, "distinct players");
        (address[] memory a, uint256[] memory c) = counter.players(0, 10);
        require(a.length == 2 && a[0] == ALICE && a[1] == BOB, "order");
        require(c[0] == 2 && c[1] == 1, "counts");
    }

    function testPagination() public {
        for (uint160 i = 1; i <= 5; i++) {
            vm.prank(address(i));
            counter.startGame();
        }
        (address[] memory a,) = counter.players(3, 10);
        require(a.length == 2 && a[0] == address(4), "tail page");
        (a,) = counter.players(1, 2);
        require(a.length == 2 && a[0] == address(2) && a[1] == address(3), "middle page");
        (a,) = counter.players(9, 2);
        require(a.length == 0, "past end");
        (a,) = counter.players(2, type(uint256).max);
        require(a.length == 3, "overflow-safe limit");
    }
}
