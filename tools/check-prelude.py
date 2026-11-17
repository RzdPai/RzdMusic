import io,sys,subprocess
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = os.path.join(ROOT, 'features/player/src/main/ets/source/QuickJsRuntime.ets')
s=io.open(p,encoding='utf-8').read()
i=s.find("const PRELUDE: string = "); assert i>0
o=s.find('`', i); assert o>0
end_key="})();\n`;"
j=s.find(end_key, o); assert j>0
raw=s[o+1:j+len("})();\n")]

# ★ 关键：不能只检查"文件里的原文"，必须模拟 **ArkTS 模板字符串的转义处理**
#   再检查**真正发给 QuickJS 的那段 JS**。2026-11-17 就栽在只查原文：
#   原文 `'\r\n'` 在 TS 模板里变成真实换行 ⇒ 设备上 `SyntaxError: unexpected end of string`，
#   而 `node --check 原文` 却是通过的（原文里 \r\n 是合法的 JS 转义）。
out=[]; k=0
while k < len(raw):
    c=raw[k]
    if c=='\\' and k+1 < len(raw):
        nxt=raw[k+1]
        m={'n':'\n','r':'\r','t':'\t','`':'`','\\':'\\','$':'$',"'":"'",'"':'"','0':'\0'}
        out.append(m.get(nxt, nxt)); k+=2
    else:
        out.append(c); k+=1
emitted=''.join(out)
io.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'qjs-prelude.js'),'w',encoding='utf-8').write(emitted+'\n')
bad=[(n+1,l) for n,l in enumerate(raw.split('\n')) if '`' in l]
print('原文 %d 字符 / 发送给 QuickJS %d 字符；内部反引号行 %d'%(len(raw),len(emitted),len(bad)))
for n,l in bad[:6]: print('  L%d %s'%(n,l.strip()[:90]))
r=subprocess.run(['node','--check',os.path.join(os.path.dirname(os.path.abspath(__file__)), 'qjs-prelude.js')],capture_output=True)
if r.returncode!=0:
    print('❌ 实际发出的 JS 语法错误：')
    print(r.stderr.decode()[:800])
sys.exit(0 if (r.returncode==0 and not bad) else 2)
