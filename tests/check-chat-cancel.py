"""Exercise the real bundled chat UI and Lua callbacks without running FXServer.

Dependencies: playwright==1.58.0, lupa==2.6 (see docs/chat-escape.md).
Native calls are recorded stubs; actual in-game focus remains a deployment check.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'runtime/chat-test-tools'))
from lupa.lua54 import LuaRuntime
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--chat', type=Path, required=True, help='Unmodified bundled chat directory')
parser.add_argument('--browser', type=Path, help='Chrome/Chromium executable; otherwise Playwright Chromium')
args = parser.parse_args()
chat = args.chat.resolve()
theme = ROOT / 'resources/[tarrant]/tarrant_chat'

for name in ('cl_chat.lua', 'dist/chat.js'):
    print(name, hashlib.sha256((chat / name).read_bytes()).hexdigest())

lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
outbound = []


def plain(value):
    if hasattr(value, 'items'):
        items = dict(value.items())
        if items and set(items) == set(range(1, len(items) + 1)):
            return [plain(items[i]) for i in range(1, len(items) + 1)]
        return {k: plain(v) for k, v in items.items()}
    return value


g.capture_message = lambda data: outbound.append(plain(data))
g.decode_json = lambda data: lua.table_from(json.loads(data), recursive=True)
lua.execute('''
callbacks, commands, handlers, kvp, focusCalls, sent, executed = {}, {}, {}, {}, {}, {}, {}
TerraingridActivate = true
json = {decode = decode_json}
function GetCurrentResourceName() return 'chat' end
function GetConvar(_, fallback) return fallback end
function RegisterNetEvent() end
function AddEventHandler(name, fn) handlers[name] = fn end
function exports() end
function RegisterNUICallback(name, fn) callbacks[name] = fn end
RegisterRawNuiCallback = RegisterNUICallback
function RegisterCommand(name, fn) commands[name] = fn end
function RegisterKeyMapping() end
function GetResourceKvpString(name) return kvp[name] end
function SetResourceKvp(name, value) kvp[name] = value end
function SendNUIMessage(data) capture_message(data) end
function SetNuiFocus(value) focus = value; table.insert(focusCalls, value) end
function SetTextChatEnabled() end
function TriggerServerEvent(...) table.insert(sent, {...}) end
function TriggerEvent(name, ...) if handlers[name] then handlers[name](...) end end
function ExecuteCommand(value) table.insert(executed, value) end
function PlayerId() return 1 end
function GetPlayerName() return 'Browser test' end
function GetNumResources() return 0 end
function IsControlPressed(_, control) assert(control == 245); return pressed end
function IsScreenFadedOut() return false end
function IsPauseMenuActive() return false end
function Wait() coroutine.yield() end
Citizen = {CreateThread = function(fn) thread = coroutine.create(fn) end}
function frame(value)
    pressed = value
    local ok, err = coroutine.resume(thread)
    assert(ok, err)
end
''')
# Standard Lua cannot parse Cfx hash literals. This one is only used for RedM,
# which is not exercised here; the FiveM control remains the original 245.
source = (chat / 'cl_chat.lua').read_text(encoding='utf-8')
lua.execute(source.replace('`INPUT_MP_TEXT_CHAT_ALL`', '0'))
g.frame(False)

with sync_playwright() as pw:
    browser = pw.chromium.launch(
        executable_path=str(args.browser) if args.browser else None, headless=True)
    page = browser.new_page()
    errors, results = [], []
    page.on('pageerror', lambda error: errors.append(str(error)))

    def route_request(route):
        request = route.request
        url = request.url
        if url in ('http://chat/loaded', 'http://chat/chatResult'):
            name = url.rsplit('/', 1)[1]
            body = json.loads(request.post_data or '{}')
            data = {'resource': 'chat', 'body': request.post_data} if name == 'chatResult' else body
            g.callbacks[name](lua.table_from(data, recursive=True), lambda *unused: None)
            if name == 'chatResult':
                results.append(body)
            route.fulfill(body='ok', headers={'Access-Control-Allow-Origin': '*'})
            return
        path = url.removeprefix('http://chat-test/')
        file = theme / path.removeprefix('theme/') if path.startswith('theme/') else (
            chat / path if path.startswith('html/') else chat / 'dist' / path)
        if file.is_file():
            route.fulfill(path=str(file))
        else:
            route.fulfill(status=404, body='Not found')

    page.route('**/*', route_request)
    page.goto('http://chat-test/ui.html')
    page.wait_for_function('document.querySelector(".chat-window") !== null')
    page.wait_for_timeout(100)

    def message(data):
        page.evaluate('data => window.dispatchEvent(new MessageEvent("message", {data}))', data)

    def flush():
        while outbound:
            message(outbound.pop(0))

    def themes(enabled=True):
        message({'type': 'ON_UPDATE_THEMES', 'themes': {'tarrant_chat_cancel': {
            'baseUrl': 'http://chat-test/theme/', 'script': 'cancel.js', 'styleSheet': 'cancel.css',
        }} if enabled else {}})
        page.wait_for_function('enabled => !!window.__tarrantChatCancel === enabled', arg=enabled)

    def mode(name):
        g.commands.toggleChat(0, lua.table_from([name]), '')
        g.frame(False)
        flush()

    def open_chat():
        # Drive the actual Lua T-press/T-release branch, not a substitute UI.
        g.frame(True)
        flush()
        g.frame(False)
        flush()
        page.locator('textarea').wait_for(state='visible')
        page.wait_for_function('document.activeElement === document.querySelector("textarea")')
        assert g.focus is True

    def close_with(key):
        count = len(results)
        page.keyboard.press(key)
        page.wait_for_function('getComputedStyle(document.querySelector(".chat-input .input")).display === "none"')
        # Let the real asynchronous chatResult XHR reach the Lua callback.
        page.wait_for_timeout(100)
        assert len(results) == count + 1, results
        assert g.focus is False, 'Stock Lua callback did not release NUI focus'
        return results[-1]

    def opacity():
        return page.locator('.chat-window').evaluate('(el) => Number(getComputedStyle(el).opacity)')

    flush()
    themes()
    page.clock.install()
    mode('whenactive')
    initial_kvp = plain(g.kvp)
    page.keyboard.press('Escape')
    assert not page.evaluate('document.documentElement.classList.contains("tarrant-chat-cancelled")')
    assert not results, 'Escape outside the chat input must not cancel anything'
    for text in ('', 'cancel this draft'):
        open_chat()
        if text:
            page.keyboard.type(text)
        assert close_with('Escape').get('canceled')
        assert opacity() == 0, 'Escape must hide without a transition'
        assert plain(g.kvp) == initial_kvp, 'Escape changed the saved preference'
        assert not page.locator('textarea').input_value()
        print('PASS T -> ' + ('type -> ' if text else '') + 'ESC: hidden, cancelled, focus released')

    g.handlers['chat:addMessage'](lua.table_from({'args': ['Other player', 'Incoming']}, recursive=True))
    flush()
    assert opacity() == 1
    page.clock.run_for(7100)
    page.wait_for_timeout(1100)  # CSS transition uses real browser time.
    assert opacity() == 0
    print('PASS incoming message after ESC displays and then fades normally')

    open_chat()
    assert opacity() == 1
    page.keyboard.press('q')
    assert opacity() == 1 and page.locator('textarea').input_value() == 'q'
    page.locator('textarea').fill('')
    page.keyboard.type('submitted message')
    assert close_with('Enter')['message'] == 'submitted message'
    assert plain(g.sent)[-1][3] == 'submitted message'
    assert opacity() == 1
    print('PASS reopening with T; Enter submits through stock Lua and retains history')

    open_chat()
    assert close_with('Enter').get('canceled')
    assert opacity() == 1, 'Empty Enter must retain original fade behavior'
    open_chat()
    page.keyboard.type('/example')
    close_with('Enter')
    assert plain(g.executed)[-1] == 'example'
    print('PASS empty Enter and slash-command submission unchanged')

    mode('visible')
    open_chat()
    close_with('Escape')
    assert opacity() == 0 and g.kvp.hideState == '1'
    message({'type': 'ON_MESSAGE', 'message': {'args': ['Visible mode incoming']}})
    assert opacity() == 1
    page.clock.run_for(9000)
    assert opacity() == 1
    mode('hidden')
    open_chat()
    close_with('Escape')
    message({'type': 'ON_MESSAGE', 'message': {'args': ['Hidden mode incoming']}})
    assert opacity() == 0 and g.kvp.hideState == '2'
    print('PASS Visible/Hidden preferences preserved, including incoming-message behavior')

    mode('whenactive')
    themes()  # Chat reinjects theme scripts on resource lifecycle changes.
    themes()
    open_chat()
    close_with('Escape')
    assert opacity() == 0
    themes(False)
    assert not page.evaluate('document.documentElement.classList.contains("tarrant-chat-cancelled")')
    open_chat()
    close_with('Escape')
    assert opacity() == 1
    print('PASS theme reload is idempotent; removal restores stock ESC behavior')
    assert not errors, errors
    browser.close()
    print('All browser/Lua integration checks passed. FiveM natives were stubbed; no server was contacted.')
