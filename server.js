import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import express from 'express';
import { z } from 'zod';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

const Alexa = createRequire(import.meta.url)('alexa-remote2');

const PORT = 3000;
const LOGIN_PORT = 3001;
const COOKIE_FILE = new URL('./cookie.json', import.meta.url);
const TOKEN_FILE = new URL('./token.txt', import.meta.url);
const CONFIG_FILE = new URL('./config.json', import.meta.url);

// config.json è facoltativo: senza, valgono le impostazioni per l'Italia e il primo Echo online
const config = {
    defaultEcho: '',
    amazonPage: 'amazon.it',
    alexaServiceHost: 'alexa.amazon.it',
    acceptLanguage: 'it-IT',
    loginLanguage: 'it_IT',
    ...(existsSync(CONFIG_FILE) ? JSON.parse(readFileSync(CONFIG_FILE, 'utf8')) : {}),
};

// Token segreto nell'URL: chi non lo conosce non può usare il server
if (!existsSync(TOKEN_FILE)) writeFileSync(TOKEN_FILE, randomBytes(24).toString('hex'), { mode: 0o600 });
const TOKEN = readFileSync(TOKEN_FILE, 'utf8').trim();

const alexa = new Alexa();
let ready = false;

alexa.on('cookie', () => {
    writeFileSync(COOKIE_FILE, JSON.stringify(alexa.cookieData), { mode: 0o600 });
    console.log('Login Amazon salvato.');
});

alexa.init({
    cookie: existsSync(COOKIE_FILE) ? JSON.parse(readFileSync(COOKIE_FILE, 'utf8')) : undefined,
    proxyOnly: true,
    proxyOwnIp: 'localhost',
    proxyPort: LOGIN_PORT,
    proxyListenBind: '127.0.0.1',
    proxyLogLevel: 'warn',
    amazonPageProxyLanguage: config.loginLanguage,
    amazonPage: config.amazonPage,
    alexaServiceHost: config.alexaServiceHost,
    acceptLanguage: config.acceptLanguage,
    usePushConnection: false,
    cookieRefreshInterval: 7 * 24 * 60 * 60 * 1000,
}, (err) => {
    if (err) {
        console.log(`Alexa non collegata: ${err.message || err}`);
        console.log(`Se serve il login, apri http://localhost:${LOGIN_PORT}`);
        return;
    }
    ready = true;
    console.log(`Alexa collegata: ${echoDevices().map(d => d.accountName).join(', ')}`);
});

const call = (method, ...args) => new Promise((resolve, reject) =>
    alexa[method](...args, (err, body) => err ? reject(err) : resolve(body)));

const echoDevices = () => Object.values(alexa.serialNumbers || {});

function pickEcho(name) {
    const devices = echoDevices();
    name = name || config.defaultEcho;
    if (name) {
        const found = devices.find(d => d.accountName.toLowerCase() === name.toLowerCase());
        if (!found) throw new Error(`Echo "${name}" non trovato. Disponibili: ${devices.map(d => d.accountName).join(', ')}`);
        return found;
    }
    const speakers = devices.filter(d => ['ECHO', 'KNIGHT', 'ROOK'].includes(d.deviceFamily));
    const echo = speakers.find(d => d.online) || speakers[0] || devices[0];
    if (!echo) throw new Error('Nessun dispositivo Echo trovato sull\'account.');
    return echo;
}

const text = (t) => ({ content: [{ type: 'text', text: t }] });

function buildServer() {
    const server = new McpServer({ name: 'alexa', version: '1.0.0' });

    server.registerTool('comando_alexa', {
        description: 'Invia ad Alexa un comando in linguaggio naturale, come se fosse pronunciato a voce (es. "accendi la luce del salotto", "imposta il termostato a 21 gradi"). Usalo per controllare la domotica.',
        inputSchema: {
            comando: z.string().describe('Il comando in italiano, senza la parola "Alexa"'),
            echo: z.string().optional().describe('Nome dell\'Echo che deve eseguirlo (opzionale)'),
        },
    }, async ({ comando, echo }) => {
        const device = pickEcho(echo);
        await call('sendSequenceCommand', device.serialNumber, 'textCommand', comando);
        return text(`Comando "${comando}" inviato a ${device.accountName}.`);
    });

    server.registerTool('lista_dispositivi', {
        description: 'Elenca i dispositivi domotici (luci, prese, termostati...) collegati ad Alexa, con i loro nomi.',
        inputSchema: {},
    }, async () => {
        const devices = await call('getSmarthomeDevicesV2');
        const names = devices
            .map(d => `${d.friendlyName || d.legacyAppliance?.friendlyName} (${d.legacyAppliance?.applianceTypes?.join('/') || 'altro'})`)
            .sort();
        return text(names.join('\n') || 'Nessun dispositivo trovato.');
    });

    server.registerTool('lista_echo', {
        description: 'Elenca i dispositivi Echo dell\'account e se sono online.',
        inputSchema: {},
    }, async () => text(echoDevices()
        .map(d => `${d.accountName} (${d.deviceFamily}, ${d.online ? 'online' : 'offline'})`)
        .join('\n')));

    return server;
}

const app = express();
app.use(express.json());

app.post(`/${TOKEN}/mcp`, async (req, res) => {
    if (!ready) return res.status(503).json({ error: 'Alexa non ancora collegata' });
    const server = buildServer();
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    res.on('close', () => { transport.close(); server.close(); });
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
});

app.listen(PORT, '127.0.0.1', () => console.log(`Server MCP su http://127.0.0.1:${PORT}/<token>/mcp`));
