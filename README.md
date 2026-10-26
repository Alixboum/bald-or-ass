# Bald or Ass

You only see a tiny piece of a picture: is it a bald head or a butt?

**Play:** https://baldorass-xpzhrprz.manus.game

Each round shows a small fragment of an image. Click **Bald** or **Ass** (or press **B** / **A**). The full picture is then revealed, framed in green if you were right and red if you were wrong. A game is 10 rounds, balanced 5/5, never more than 2 of the same kind in a row, with new pictures every game. English by default, EN/FR switch on the home screen.

## On-chain (Hemi Mainnet)

Every game starts with one transaction to the `GameCounter` contract, which records the game against the player's wallet. The contract is non-payable: no token, no fee, no ETH sent to it. Players only pay network gas. The leaderboard (games played per wallet) is read directly from the contract.

| | |
|---|---|
| Network | Hemi Mainnet (chain id 43111) |
| Contract | [`0xa5a9dda017ab635fea76706e43dbe2bfeb398559`](https://explorer.hemi.xyz/address/0xa5a9dda017ab635fea76706e43dbe2bfeb398559?tab=contract) |
| Source | [`contracts/src/GameCounter.sol`](contracts/src/GameCounter.sol), Solidity 0.8.24, optimizer 200 runs, EVM paris |
| Verification | [Sourcify exact match](https://repo.sourcify.dev/43111/0xa5a9dda017ab635fea76706e43dbe2bfeb398559) |

Use a burner wallet.

## Reusable mechanic

The rules (`scripts/guess/guess_round.gd`) know nothing about the theme. A theme is a JSON file (`themes/<id>/theme.json`) listing two answer categories, the images and the visible zone of each image. The in-game **Editor mode** lets you draw those zones with the mouse. Add a folder under `themes/` and register it in `themes/index.json` to make a new "X or Y" game.

## Project layout

- `scripts/guess/` - game logic, UI, theme loader, zone editor, Hemi bridge (Godot side)
- `web/hemi_bridge.js` - wallet / JSON-RPC bridge (EIP-1193)
- `contracts/` - Foundry project for `GameCounter` (`forge test`)
- `themes/`, `assets/themes/` - Bald or Ass content
- `test/` - automated tests (`godot --headless --path . res://test/guess_tests.tscn`)

Built with Godot 4 (Web export).

## Credits

- Engine: Godot Engine (MIT)
- Fonts: Figtree, Sora, Noto Sans SC (SIL Open Font License 1.1)
- Pictures: mix of AI-generated images and photos collected online, used for parody. If you own one and want it removed, open an issue.

## License

Code: [MIT](LICENSE). Third-party fonts, engine and photos keep their own terms (see NOTICE).
