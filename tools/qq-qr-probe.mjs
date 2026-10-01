// QQ 音乐扫码登录接口本地验证探针（只读，不改工程）。
// 验证内容：
//   1) CreateQRCode 拿 qrcodeID；
//   2) MQTT 5 over WSS 连官方入口 mu.y.qq.com:443/ws/handshake，重复多次观察 157/0 的概率；
//   3) 收到 157 + Server Reference(IP:port) 时，验证「照服务端地址重连」是否真的能连上、路径用不用 /ws/handshake；
//   4) 连上后订阅 management.qrcode_login/<id>，确认能拿到 SUBACK 并保持连接。
// 用法: node tools/qq-qr-probe.mjs [轮数]

const LOGIN_ENDPOINT = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
const TME_APP_ID = 'qqmusic';
const CLIENT_TYPE = 19;
const CLIENT_VERSION = 11060000;
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
const ROUNDS = Number(process.argv[2] ?? 6);

const log = (...a) => console.log(...a);

async function createQr() {
  const resp = await fetch(LOGIN_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://y.qq.com',
      'Referer': 'https://y.qq.com/',
      'User-Agent': USER_AGENT
    },
    body: JSON.stringify({
      comm: {},
      req_0: { module: 'music.login.LoginServer', method: 'CreateQRCode', param: { tmeAppID: TME_APP_ID, ct: CLIENT_TYPE, cv: CLIENT_VERSION } }
    })
  });
  const parsed = JSON.parse(await resp.text());
  const d = parsed.req_0?.data;
  if (!d) { log('[HTTP] 无 data'); return undefined; }
  log('[QR] qrcodeID=' + d.qrcodeID + ' expiresIn=' + d.expiresIn);
  return d.qrcodeID;
}

/* ---------- MQTT 5 最小编码 ---------- */
function encVarint(n) { const o = []; do { let b = n % 128; n = Math.floor(n / 128); if (n > 0) b |= 0x80; o.push(b); } while (n > 0); return Buffer.from(o); }
function encString(s) { const b = Buffer.from(s, 'utf8'); return Buffer.concat([Buffer.from([b.length >> 8, b.length & 0xff]), b]); }
function encPair(id, k, v) { return Buffer.concat([Buffer.from([id]), encString(k), encString(v)]); }
function encUtf8(id, v) { return Buffer.concat([Buffer.from([id]), encString(v)]); }

function connectPacket(clientId, qrcodeID) {
  const props = [
    encUtf8(0x15, 'pass'),
    encPair(0x26, 'tmeAppID', TME_APP_ID),
    encPair(0x26, 'business', 'management'),
    encPair(0x26, 'hashTag', qrcodeID),
    encPair(0x26, 'clientTag', 'management.user'),
    encPair(0x26, 'userID', qrcodeID)
  ];
  const propsBuf = Buffer.concat(props);
  const payload = Buffer.concat([
    encString('MQTT'), Buffer.from([5]), Buffer.from([0x02]), Buffer.from([0x00, 0x3c]),
    encVarint(propsBuf.length), propsBuf, encString(clientId)
  ]);
  return Buffer.concat([Buffer.from([0x10]), encVarint(payload.length), payload]);
}

function subscribePacket(topic) {
  const payload = Buffer.concat([Buffer.from([0x00, 0x01]), encString(topic), Buffer.from([0x00])]);
  const body = Buffer.concat([encVarint(0), payload]); // property length = 0
  return Buffer.concat([Buffer.from([0x82]), encVarint(body.length), body]);
}

function parseProps(buf) {
  const out = { serverReference: '', reasonString: '', user: [] };
  let p = 0;
  while (p < buf.length) {
    const id = buf[p++];
    if (id === 0x1c || id === 0x1a) {
      const len = (buf[p] << 8) | buf[p + 1]; p += 2;
      const v = buf.subarray(p, p + len).toString('utf8'); p += len;
      if (id === 0x1c) out.serverReference = v; else out.reasonString = v;
    } else if (id === 0x26) {
      const kl = (buf[p] << 8) | buf[p + 1]; p += 2;
      const k = buf.subarray(p, p + kl).toString('utf8'); p += kl;
      const vl = (buf[p] << 8) | buf[p + 1]; p += 2;
      const v = buf.subarray(p, p + vl).toString('utf8'); p += vl;
      out.user.push(k + '=' + v);
    } else if (id === 0x12) { /* assigned client id, no payload */ }
    else { break; }
  }
  return out;
}

function readVarint(buf, pos) { let m = 1, v = 0, i = pos; for (;;) { const b = buf[i++]; v += (b & 0x7f) * m; if ((b & 0x80) === 0) break; m *= 128; } return { v, next: i }; }

async function probe(url, qrcodeID, label, holdMs) {
  return await new Promise((resolve) => {
    const ws = new WebSocket(url, ['mqtt']);
    ws.binaryType = 'arraybuffer';
    let settled = false;
    let gotSuback = false;
    const finish = (r) => { if (settled) return; settled = true; try { ws.close(); } catch (e) { } resolve(r); };
    const timer = setTimeout(() => { log('[' + label + '] 超时'); finish({ ok: false, reason: -1 }); }, 9000);
    ws.onopen = () => {
      ws.send(connectPacket(String(Date.now()) + Math.floor(100 + Math.random() * 899), qrcodeID));
    };
    ws.onmessage = (ev) => {
      const buf = Buffer.from(ev.data instanceof ArrayBuffer ? new Uint8Array(ev.data) : ev.data);
      const type = buf[0] >> 4;
      if (type === 2) {
        const body = buf.subarray(readVarint(buf, 1).next);
        const reason = body[1];
        const pl = readVarint(body, 2);
        const props = parseProps(body.subarray(pl.next, pl.next + pl.v));
        log('[' + label + '] CONNACK reason=' + reason + ' ref="' + props.serverReference + '" user=[' + props.user.join('; ') + ']');
        if (reason === 0) {
          ws.send(subscribePacket('management.qrcode_login/' + qrcodeID));
          log('[' + label + '] 已订阅 management.qrcode_login/<id>，保持 ' + holdMs + 'ms 观察');
          setTimeout(() => { clearTimeout(timer); finish({ ok: true, reason: 0, ref: props.serverReference }); }, holdMs);
        } else {
          // ★ 关键实验：157 之后**不换地址**，就在这条连接上继续订阅，看服务端认不认
          ws.send(subscribePacket('management.qrcode_login/' + qrcodeID));
          log('[' + label + '] reason=' + reason + ' → 仍在此连接上订阅，观察是否收到 SUBACK/PUBLISH');
          setTimeout(() => {
            clearTimeout(timer);
            finish({ ok: false, reason, ref: props.serverReference, sameSocketSuback: gotSuback });
          }, holdMs);
        }
      } else if (type === 9) {
        gotSuback = true;
        log('[' + label + '] ★ SUBACK reason=' + buf[buf.length - 1] + '（说明这条连接是可用的！）');
      } else if (type === 3) {
        log('[' + label + '] PUBLISH(' + buf.length + 'B)');
      }
    };
    ws.onerror = (e) => { log('[' + label + '] socket 错误 ' + (e.message ?? e.type ?? '')); };
    ws.onclose = (e) => { clearTimeout(timer); finish({ ok: false, reason: -2, closeCode: e.code }); };
  });
}

const qrcodeID = await createQr();
if (!qrcodeID) process.exit(1);

log('\n=== A. 连官方入口；若服务端回 157，就在同一条连接上继续订阅（实验：要不要理会 157） ===');
let redirect = '';
for (let i = 1; i <= ROUNDS; i++) {
  const r = await probe('wss://mu.y.qq.com:443/ws/handshake', qrcodeID, 'A' + i, 4000);
  log('    => ok=' + r.ok + ' reason=' + r.reason + ' 同连接收到SUBACK=' + r.sameSocketSuback + (r.ref ? ' ref=' + r.ref : ''));
  if (!r.ok && r.reason === 157 && r.ref && redirect.length === 0) { redirect = r.ref; }
}

log('\n=== B. 服务端给的重定向地址（IP:port）能不能连 ===');
if (redirect.length === 0) {
  log('本轮没抽到 157，跳过');
} else {
  const [host, port] = redirect.split(':');
  const tries = [
    ['WSS+官方握手路径', `wss://${host}:${port}/ws/handshake`],
    ['WSS+根路径', `wss://${host}:${port}/`]
  ];
  for (const [name, url] of tries) {
    const r = await probe(url, qrcodeID, 'B-' + name, 1500);
    log('    => ' + name + ' ok=' + r.ok + ' reason=' + r.reason + (r.closeCode !== undefined ? ' close=' + r.closeCode : ''));
  }
}
process.exit(0);
