// Hemi bridge for the fragment-guess game (inlined into web/loading.html by
// tools/sync_hemi_bridge.py). Exposes window.HemiChain for Godot:
//   HemiChain.invoke(op, argsJson, callback)  -> callback(JSON result)
//   HemiChain.listen(callback)               -> callback(JSON event)
// Results: {"ok": true, "data": ...} or {"ok": false, "code": "...", "message": "..."}.
// Wallets: window.ethereum, or the first EIP-6963 provider announced.
(() => {
  const BYTECODE = '__GAME_COUNTER_BYTECODE__';
  const SEL = {
    startGame: '0xd65ab5f2',
    totalGames: '0x2c4e591b',
    playerCount: '0x302bcc57',
    gamesPlayed: '0x70180bc1',
    players: '0x998f1b80',
  };
  const PAGE = 500;
  const cfg = {
    chainId: 43111,
    rpc: 'https://rpc.hemi.network/rpc',
    explorer: 'https://explorer.hemi.xyz',
    name: 'Hemi',
    contract: '',
  };
  const store = {
    get: (k) => { try { return localStorage.getItem(k) || ''; } catch (e) { return ''; } },
    set: (k, v) => { try { localStorage.setItem(k, v); } catch (e) { /* storage blocked */ } },
  };
  const announced = [];
  window.addEventListener('eip6963:announceProvider', (event) => {
    if (event.detail && event.detail.provider) announced.push(event.detail);
  });
  window.dispatchEvent(new Event('eip6963:requestProvider'));

  const listeners = [];
  let account = '';
  let watching = false;

  const emit = (payload) => {
    const text = JSON.stringify(payload);
    for (const listener of listeners) {
      try { listener(text); } catch (e) { console.error('[hemi] listener failed', e); }
    }
  };
  const provider = () => window.ethereum || (announced[0] && announced[0].provider) || null;
  const chainHex = () => '0x' + Number(cfg.chainId).toString(16);
  const contract = () => cfg.contract || store.get('baldorass.contract');
  const rpcUrl = () => store.get('baldorass.rpc') || cfg.rpc;
  const pad = (hex) => hex.replace(/^0x/, '').toLowerCase().padStart(64, '0');
  const uint = (n) => pad(BigInt(n).toString(16));

  const fail = (code, message) => {
    const error = new Error(message || code);
    error.hemiCode = code;
    return error;
  };
  const classify = (error) => {
    if (error && error.hemiCode) return { code: error.hemiCode, message: error.message };
    const code = error && (error.code ?? (error.data && error.data.code));
    const message = String((error && (error.shortMessage || error.message)) || error || 'Unknown error');
    if (code === 4001 || code === 'ACTION_REJECTED' || /reject|denied|cancel/i.test(message)) return { code: 'rejected', message };
    if (/insufficient funds|exceeds balance|gas required exceeds/i.test(message)) return { code: 'no_funds', message };
    if (code === -32002) return { code: 'pending', message };
    return { code: 'error', message };
  };

  const rpc = async (method, params = []) => {
    const response = await fetch(rpcUrl(), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: Date.now(), method, params }),
    });
    if (!response.ok) throw fail('rpc', 'Hemi RPC HTTP ' + response.status);
    const json = await response.json();
    if (json.error) throw fail('rpc', json.error.message || 'Hemi RPC error');
    return json.result;
  };
  const call = (data) => rpc('eth_call', [{ to: contract(), data }, 'latest']);

  const words = (hex) => {
    const body = hex.replace(/^0x/, '');
    const out = [];
    for (let i = 0; i < body.length; i += 64) out.push(body.slice(i, i + 64));
    return out;
  };

  const watchWallet = (wallet) => {
    if (watching || !wallet || typeof wallet.on !== 'function') return;
    watching = true;
    wallet.on('accountsChanged', (accounts) => {
      account = (accounts && accounts[0]) ? String(accounts[0]).toLowerCase() : '';
      emit({ event: 'account', account });
    });
    wallet.on('chainChanged', (chainId) => emit({ event: 'chain', chainId }));
  };

  const connect = async () => {
    const wallet = provider();
    if (!wallet) throw fail('no_wallet', 'No browser wallet found');
    watchWallet(wallet);
    const accounts = await wallet.request({ method: 'eth_requestAccounts' });
    account = (accounts && accounts[0]) ? String(accounts[0]).toLowerCase() : '';
    if (!account) throw fail('no_account', 'The wallet returned no account');
    return account;
  };

  const ensureChain = async () => {
    const wallet = provider();
    const current = await wallet.request({ method: 'eth_chainId' });
    if (String(current).toLowerCase() === chainHex()) return;
    try {
      await wallet.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: chainHex() }] });
    } catch (error) {
      const code = error && (error.code ?? (error.data && error.data.originalError && error.data.originalError.code));
      if (code !== 4902 && !/unrecognized|not added|unknown chain/i.test(String(error && error.message))) throw error;
      await wallet.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: chainHex(),
          chainName: cfg.name,
          nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
          rpcUrls: [cfg.rpc],
          blockExplorerUrls: [cfg.explorer],
        }],
      });
    }
    const after = await wallet.request({ method: 'eth_chainId' });
    if (String(after).toLowerCase() !== chainHex()) throw fail('wrong_chain', 'Please switch your wallet to Hemi');
  };

  const waitReceipt = async (hash, timeoutMs = 180000) => {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      try {
        const receipt = await rpc('eth_getTransactionReceipt', [hash]);
        if (receipt) return receipt;
      } catch (e) { /* keep polling */ }
      await new Promise((resolve) => setTimeout(resolve, 2500));
    }
    throw fail('timeout', 'Transaction not confirmed yet');
  };

  const sendTx = async (tx) => {
    await connect();
    await ensureChain();
    return provider().request({ method: 'eth_sendTransaction', params: [{ from: account, ...tx }] });
  };

  const ops = {
    configure: async (args) => {
      Object.assign(cfg, {
        chainId: Number(args.chain_id || cfg.chainId),
        rpc: args.rpc_url || cfg.rpc,
        explorer: args.explorer_url || cfg.explorer,
        name: args.network || cfg.name,
        contract: String(args.contract || '').toLowerCase(),
      });
      return ops.status();
    },
    status: async () => {
      const wallet = provider();
      if (wallet && !account) {
        try {
          const accounts = await wallet.request({ method: 'eth_accounts' });
          account = (accounts && accounts[0]) ? String(accounts[0]).toLowerCase() : '';
          watchWallet(wallet);
        } catch (e) { /* not authorised yet */ }
      }
      return { hasWallet: !!wallet, account, contract: contract(), explorer: cfg.explorer, chainId: cfg.chainId };
    },
    connect: async () => ({ account: await connect() }),
    startGame: async () => {
      if (!contract()) throw fail('no_contract', 'The game contract is not deployed yet');
      const hash = await sendTx({ to: contract(), data: SEL.startGame, value: '0x0' });
      waitReceipt(hash).then((receipt) => {
        emit({ event: receipt.status === '0x1' ? 'confirmed' : 'reverted', hash });
      }).catch((error) => emit({ event: 'unconfirmed', hash, message: String(error.message || error) }));
      return { hash, account };
    },
    leaderboard: async () => {
      if (!contract()) throw fail('no_contract', 'The game contract is not deployed yet');
      const rows = [];
      for (let offset = 0; ; offset += PAGE) {
        const w = words(await call(SEL.players + uint(offset) + uint(PAGE)));
        const a = Number(BigInt('0x' + w[0]) / 32n);
        const c = Number(BigInt('0x' + w[1]) / 32n);
        const size = Number(BigInt('0x' + w[a]));
        for (let i = 0; i < size; i++) {
          rows.push({ address: '0x' + w[a + 1 + i].slice(24), games: Number(BigInt('0x' + w[c + 1 + i])) });
        }
        if (size < PAGE) break;
      }
      const total = Number(BigInt(await call(SEL.totalGames)));
      rows.sort((x, y) => y.games - x.games);
      return { rows, total, players: rows.length, account, contract: contract() };
    },
    deploy: async () => {
      const hash = await sendTx({ data: BYTECODE, value: '0x0' });
      emit({ event: 'deploy_sent', hash });
      const receipt = await waitReceipt(hash, 300000);
      if (receipt.status !== '0x1' || !receipt.contractAddress) throw fail('reverted', 'Deployment failed');
      const address = String(receipt.contractAddress).toLowerCase();
      store.set('baldorass.contract', address);
      return { address, hash };
    },
  };

  window.HemiChain = {
    invoke(op, argsJson, callback) {
      let args = {};
      try { args = argsJson ? JSON.parse(argsJson) : {}; } catch (e) { args = {}; }
      const run = ops[op];
      const reply = (payload) => {
        try { callback(JSON.stringify(payload)); } catch (e) { console.error('[hemi] callback failed', e); }
      };
      if (!run) { reply({ ok: false, code: 'unknown_op', message: op }); return; }
      Promise.resolve().then(() => run(args))
        .then((data) => reply({ ok: true, data }))
        .catch((error) => {
          const info = classify(error);
          console.warn('[hemi] ' + op + ' failed:', info.code, info.message);
          reply({ ok: false, ...info });
        });
    },
    listen(callback) { listeners.push(callback); },
  };
})();
