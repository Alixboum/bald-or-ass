#!/usr/bin/env bash
# Deploys contracts/src/GameCounter.sol to Hemi mainnet with the dedicated
# deployer wallet and writes the address into config/hemi.json.
# The private key is read from ~/.baldorass/deployer.json (never committed),
# or from DEPLOYER_PRIVATE_KEY.
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RPC="${HEMI_RPC:-https://rpc.hemi.network/rpc}"
KEY="${DEPLOYER_PRIVATE_KEY:-$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.baldorass/deployer.json')))['key'])")}"
FROM="$(cast wallet address --private-key "$KEY")"

[ "$(cast chain-id --rpc-url "$RPC")" = "43111" ] || { echo "RPC is not Hemi mainnet" >&2; exit 1; }
echo "Deployer: $FROM  balance: $(cast balance --ether --rpc-url "$RPC" "$FROM") ETH"

(cd "$ROOT/contracts" && forge build --silent && forge test -q)
python3 "$ROOT/tools/sync_hemi_bridge.py"
BYTECODE="$(cat "$ROOT/contracts/GameCounter.bytecode.txt")"

RECEIPT="$(cast send --rpc-url "$RPC" --private-key "$KEY" --create "$BYTECODE" --json)"
ADDRESS="$(echo "$RECEIPT" | python3 -c "import json,sys;r=json.load(sys.stdin);assert r['status'] in ('0x1',1,'1'),r;print(r['contractAddress'])")"
TX="$(echo "$RECEIPT" | python3 -c "import json,sys;print(json.load(sys.stdin)['transactionHash'])")"
echo "GameCounter deployed at $ADDRESS (tx $TX)"

python3 - "$ROOT/config/hemi.json" "$ADDRESS" "$TX" <<'EOF'
import json, sys
path, address, tx = sys.argv[1:]
config = json.load(open(path))
config["contract"] = address.lower()
config["deploy_tx"] = tx
json.dump(config, open(path, "w"), indent=2)
open(path, "a").write("\n")
EOF
echo "config/hemi.json updated"
