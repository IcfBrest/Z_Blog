// D-Mail 解锁：口令经 PBKDF2 派生密钥，AES-GCM 解密正文。
// 未解锁时页面里只有密文（服务端只下发载荷），明文在浏览器侧产生。

const STORAGE_KEY = 'sg-dmail';
const te = new TextEncoder();
const td = new TextDecoder();

const toBytes = (b64: string): Uint8Array =>
  Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

async function deriveKey(passphrase: string, salt: Uint8Array, iterations: number): Promise<CryptoKey> {
  const base = await crypto.subtle.importKey('raw', te.encode(passphrase), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt'],
  );
}

/** 解密一个密文载荷；口令错误或载荷被改动都会抛错 */
export async function openPayload(payload: HTMLElement, passphrase: string): Promise<string> {
  const salt = payload.dataset.salt ?? '';
  const iv = payload.dataset.iv ?? '';
  const iterations = Number(payload.dataset.iter ?? 0);
  const cipher = (payload.textContent ?? '').trim();
  if (!salt || !iv || !iterations || !cipher) {
    throw new Error('载荷不完整');
  }
  const key = await deriveKey(passphrase, toBytes(salt), iterations);
  const plain = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: toBytes(iv) },
    key,
    toBytes(cipher),
  );
  return td.decode(plain);
}

function reveal(content: HTMLElement, html: string): void {
  content.innerHTML = html;
  content.removeAttribute('hidden');
  content.setAttribute('data-open', '1');
}

export function initSealed(): void {
  const payload = document.querySelector<HTMLElement>('[data-dmail-sealed]');
  const form = document.querySelector<HTMLFormElement>('[data-sg-dmail-form]');
  const content = document.querySelector<HTMLElement>('[data-sg-dmail-content]');
  const error = document.querySelector<HTMLElement>('[data-sg-dmail-error]');
  if (!payload || !form || !content) return;

  const storageKey = `${STORAGE_KEY}:${location.pathname}`;

  // 会话内记忆：同标签页刷新直接还原，关闭标签页即失效
  const cached = sessionStorage.getItem(storageKey);
  if (cached) {
    reveal(content, cached);
    form.hidden = true;
    return;
  }

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const input = form.querySelector<HTMLInputElement>('input[name="dmail-pass"]');
    const passphrase = input?.value ?? '';
    if (!passphrase) return;
    const submit = form.querySelector<HTMLButtonElement>('button[type="submit"]');
    if (submit) submit.disabled = true;
    if (error) error.hidden = true;
    try {
      const html = await openPayload(payload, passphrase);
      reveal(content, html);
      form.hidden = true;
      try {
        sessionStorage.setItem(storageKey, html);
      } catch {
        /* 隐私模式下写不进去也不影响本次阅读 */
      }
    } catch {
      if (error) {
        error.hidden = false;
        error.textContent = '口令不正确，这封 D-Mail 无法解析。';
      }
      if (input) {
        input.value = '';
        input.focus();
      }
    } finally {
      if (submit) submit.disabled = false;
    }
  });
}
