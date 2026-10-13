const DATABASE_NAME = 'realtime-salary-private-vault';
const STORE_NAME = 'encrypted-records';
const SESSION_KEY_NAME = 'realtime-salary-session-key';
const DATABASE_VERSION = 1;

interface EncryptedRecord {
  id: string;
  version: 1;
  iv: string;
  ciphertext: string;
  updatedAt: string;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  bytes.forEach((byte) => { binary += String.fromCharCode(byte); });
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function getSessionCryptoKey(): Promise<CryptoKey> {
  let rawKey = sessionStorage.getItem(SESSION_KEY_NAME);
  if (!rawKey) {
    const generated = crypto.getRandomValues(new Uint8Array(32));
    rawKey = bytesToBase64(generated);
    sessionStorage.setItem(SESSION_KEY_NAME, rawKey);
  }
  return crypto.subtle.importKey('raw', base64ToBytes(rawKey), 'AES-GCM', false, ['encrypt', 'decrypt']);
}

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE_NAME, DATABASE_VERSION);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(STORE_NAME)) {
        database.createObjectStore(STORE_NAME, { keyPath: 'id' });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function transact<T>(mode: IDBTransactionMode, action: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  return openDatabase().then((database) => new Promise<T>((resolve, reject) => {
    const transaction = database.transaction(STORE_NAME, mode);
    const request = action(transaction.objectStore(STORE_NAME));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    transaction.oncomplete = () => database.close();
  }));
}

export async function writePrivateRecord<T>(id: string, value: T): Promise<void> {
  const key = await getSessionCryptoKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const plaintext = new TextEncoder().encode(JSON.stringify(value));
  const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, plaintext);
  const record: EncryptedRecord = {
    id,
    version: 1,
    iv: bytesToBase64(iv),
    ciphertext: bytesToBase64(new Uint8Array(encrypted)),
    updatedAt: new Date().toISOString(),
  };
  await transact('readwrite', (store) => store.put(record));
}

export async function readPrivateRecord<T>(id: string): Promise<T | null> {
  const record = await transact<EncryptedRecord | undefined>('readonly', (store) => store.get(id));
  if (!record) return null;

  try {
    const key = await getSessionCryptoKey();
    const decrypted = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: base64ToBytes(record.iv) },
      key,
      base64ToBytes(record.ciphertext),
    );
    return JSON.parse(new TextDecoder().decode(decrypted)) as T;
  } catch {
    await deletePrivateRecord(id);
    return null;
  }
}

export async function deletePrivateRecord(id: string): Promise<void> {
  await transact('readwrite', (store) => store.delete(id));
}

export async function clearPrivateVault(): Promise<void> {
  await transact('readwrite', (store) => store.clear());
  sessionStorage.removeItem(SESSION_KEY_NAME);
}

export async function migrateLegacyLocalStorage<T>(legacyKey: string, recordId: string): Promise<T | null> {
  const legacyValue = localStorage.getItem(legacyKey);
  if (!legacyValue) return null;

  try {
    const parsed = JSON.parse(legacyValue) as T;
    await writePrivateRecord(recordId, parsed);
    localStorage.removeItem(legacyKey);
    return parsed;
  } catch {
    return null;
  }
}
