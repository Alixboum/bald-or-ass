// Exercises web/hemi_bridge.js (as inlined, with bytecode) against a local
// anvil node using a fake EIP-1193 wallet. Usage: node tools/test_hemi_bridge.mjs
import fs from 'node:fs';

const RPC = 'http://127.0.0.1:8545';
const html = fs.readFileSync(new URL('../web/loading.html', import.meta.url), 'utf8');
const block = html.split('<!-- HEMI-BRIDGE:START -->')[1].split('<!-- HEMI-BRIDGE:END -->')[0];
const source = block.replace(/^\s*<script>/, '').replace(/<\/script>\s*$/, '');

const rpc = async (method, params = []) => {
  const r = await fetch(RPC, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) });
  const j = await r.json();
  if (j.error) { const e = new Error(j.error.message); e.code = j.error.code; throw e; }
  return j.result;
};
const accounts = await rpc('eth_accounts');
let current = accounts[0];
let rejectNext = false;
const handlers = {};
const memory = new Map();
globalThis.localStorage = { getItem: (k) => memory.get(k) ?? null, setItem: (k, v) => memory.set(k, String(v)) };
globalThis.window = globalThis;
window.addEventListener = () => {};
window.dispatchEvent = () => true;
window.ethereum = {
  on: (name, fn) => { handlers[name] = fn; },
  request: async ({ method, params }) => {
    if (method === 'eth_requestAccounts' || method === 'eth_accounts') return [current];
    if (method === 'eth_sendTransaction' && rejectNext) { rejectNext = false; const e = new Error('User rejected the request.'); e.code = 4001; throw e; }
    return rpc(method, params);
  },
};
localStorage.setItem('baldorass.rpc', RPC);
eval(source);

const call = (op, args = {}) => new Promise((resolve) => window.HemiChain.invoke(op, JSON.stringify(args), (text) => resolve(JSON.parse(text))));
const events = [];
window.HemiChain.listen((text) => events.push(JSON.parse(text)));
let failures = 0;
const check = (cond, label) => { console.log((cond ? 'PASS ' : 'FAIL ') + label); if (!cond) failures++; };

await call('configure', { chain_id: 43111, rpc_url: RPC, explorer_url: 'https://explorer.hemi.xyz', contract: '' });
let r = await call('startGame');
check(!r.ok && r.code === 'no_contract', 'startGame refuses without contract');
r = await call('deploy');
check(r.ok && /^0x[0-9a-f]{40}$/.test(r.data.address), 'deploy returns contract address');
const address = r.data.address;
check(localStorage.getItem('baldorass.contract') === address, 'deployed address remembered');
r = await call('status');
check(r.ok && r.data.contract === address && r.data.account === current.toLowerCase(), 'status sees wallet + contract');
r = await call('leaderboard');
check(r.ok && r.data.total === 0 && r.data.rows.length === 0, 'empty leaderboard');
for (let i = 0; i < 3; i++) { r = await call('startGame'); check(r.ok && /^0x[0-9a-f]{64}$/.test(r.data.hash), `game tx ${i + 1} sent`); }
current = accounts[1];
r = await call('startGame');
check(r.ok, 'second player tx');
rejectNext = true;
r = await call('startGame');
check(!r.ok && r.code === 'rejected', 'rejected tx reported as rejected');
await new Promise((res) => setTimeout(res, 3500));
check(events.filter((e) => e.event === 'confirmed').length === 4, 'four confirmations emitted');
r = await call('leaderboard');
check(r.ok && r.data.total === 4 && r.data.players === 2, 'totals: 4 games, 2 players');
check(r.data.rows[0].address === accounts[0].toLowerCase() && r.data.rows[0].games === 3, 'top player has 3 games');
check(r.data.rows[1].games === 1, 'second player has 1 game');
console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
process.exit(failures ? 1 : 0);
