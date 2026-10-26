// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title GameCounter
/// @notice On-chain record of games started, one transaction per game.
///         Reusable for any theme of the fragment-guess game: deploy one
///         counter per game. Holds no funds and has no owner.
contract GameCounter {
    /// Number of games started by each player.
    mapping(address => uint256) public gamesPlayed;

    /// Total number of games started by everyone.
    uint256 public totalGames;

    address[] private _players;

    event GameStarted(address indexed player, uint256 playerGames, uint256 totalGames);

    /// Called by the player's wallet at the start of every game.
    function startGame() external {
        uint256 count = gamesPlayed[msg.sender];
        if (count == 0) {
            _players.push(msg.sender);
        }
        count += 1;
        gamesPlayed[msg.sender] = count;
        uint256 total = totalGames + 1;
        totalGames = total;
        emit GameStarted(msg.sender, count, total);
    }

    /// Number of distinct players.
    function playerCount() external view returns (uint256) {
        return _players.length;
    }

    /// Page of players (in order of first game) with their game counts,
    /// used to build the leaderboard off-chain.
    function players(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory addresses, uint256[] memory counts)
    {
        uint256 length = _players.length;
        if (offset >= length) {
            return (new address[](0), new uint256[](0));
        }
        uint256 size = length - offset;
        if (limit < size) {
            size = limit;
        }
        addresses = new address[](size);
        counts = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            address player = _players[offset + i];
            addresses[i] = player;
            counts[i] = gamesPlayed[player];
        }
    }
}
